# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

use strict;

our ($WRITELAYER, $APPENDLAYER, $READLAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($NO_OUTPUT_DELETE, $DEBUG, $OSIS, $OUTOSIS, $XPC, $XML_PARSER, 
    $DWF, $DICTIONARY_WORDS, $DEFAULT_DICTIONARY_WORDS, 
    $DICTIONARY_NotXPATH_Default, $OSISSCHEMA);

# Initialized in /scripts/usfm2osis.pl
our ($addScripRefLinks, $addFootnoteLinks, $addDictLinks, $addCrossRefs, 
    $addSeeAlsoLinks, $reorderGlossaryEntries, $customBookOrder, 
    $sourceProject);

require("$SCRD/scripts/addScripRefLinks.pl");
require("$SCRD/scripts/addFootnoteLinks.pl");
require("$SCRD/scripts/bible/addDictLinks.pl");
require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");
require("$SCRD/scripts/bible/addCrossRefs.pl");
require("$SCRD/scripts/applyPeriphInstructions.pl");

# This script expects a usfm2osis.py produced OSIS input file
sub processOSIS {
  my $inosis = shift;
  
  if ($NO_OUTPUT_DELETE) {return;} # after "require"s, then return if previous tmp files are to be used for debugging

  # Run user supplied preprocess.pl and/or preprocess.xsl if present
  &runAnyUserScriptsAt("preprocess", \$OSIS);

  my $modType = (&conf('ModDrv') =~ /LD/ ? 'dict':(&conf('ModDrv') =~ /Text/ ? 'bible':(&conf('ModDrv') =~ /Com/ ? 'commentary':'childrens_bible')));

  # Apply any fixups needed to usfm2osis.py output which are osis-converters specific
  &runScript("$SCRD/scripts/usfm2osis.py.xsl", \$OSIS);

  &Log("Wrote to header: \n".&writeOsisHeader(\$OSIS)."\n");

  # Bible OSIS: re-order books and periphs according to CF_usfm2osis.txt etc.
  if ($modType eq 'bible') {
    &orderBooks(\$OSIS, &conf('Versification'), $customBookOrder);
    &applyVsysMissingVTagInstructions(\$OSIS);
    &applyPeriphInstructions(\$OSIS);
    &write_osisIDs(\$OSIS);
    &runScript("$SCRD/scripts/bible/checkUpdateIntros.xsl", \$OSIS);   
  }
  # Dictionary OSIS: aggregate repeated entries (required for SWORD) and re-order entries if desired
  elsif ($modType eq 'dict') {
    &applyPeriphInstructions(\$OSIS);
    
    if (!@{$XPC->findnodes('//osis:div[contains(@type, "x-keyword")]', $XML_PARSER->parse_file($OSIS))}[0]) {
      &runScript("$SCRD/scripts/dict/aggregateRepeatedEntries.xsl", \$OSIS);
    }
    
    &write_osisIDs(\$OSIS);
    
    # create default DictionaryWords.xml templates
    my %params = ('notXPATH_default' => $DICTIONARY_NotXPATH_Default);
    &runXSLT("$SCRD/scripts/dict/writeDictionaryWords.xsl", $OSIS, $DEFAULT_DICTIONARY_WORDS, \%params);
    $params{'anyEnding'} = 'true';
    &runXSLT("$SCRD/scripts/dict/writeDictionaryWords.xsl", $OSIS, $DEFAULT_DICTIONARY_WORDS.".bible.xml", \%params);
    
    if ($reorderGlossaryEntries) {
      my %params = ('glossaryRegex' => $reorderGlossaryEntries);
      &runScript("$SCRD/scripts/dict/reorderGlossaryEntries.xsl", \$OSIS, \%params);
    }
  }
  # Children's Bible OSIS: specific to osis-converters Children's Bibles
  elsif ($modType eq 'childrens_bible') {
    &runScript("$SCRD/scripts/genbook/childrens_bible/osis2cbosis.xsl", \$OSIS);
    &write_osisIDs(\$OSIS);
    &checkAdjustCBImages(\$OSIS);
  }
  else {die "Unhandled modType (ModDrv=".&conf('ModDrv').")\n";}
  
  # Copy new DictionaryWords.xml if needed
  if ($modType eq 'dict' && -e $DEFAULT_DICTIONARY_WORDS && ! -e "$DICTINPD/$DICTIONARY_WORDS") {
    copy($DEFAULT_DICTIONARY_WORDS, "$DICTINPD/$DICTIONARY_WORDS");
    &Note("Copying default $DICTIONARY_WORDS $DEFAULT_DICTIONARY_WORDS to $DICTINPD/$DICTIONARY_WORDS");
  }
  if ($modType eq 'dict' && -e "$DEFAULT_DICTIONARY_WORDS.bible.xml" && ! -e "$MAININPD/$DICTIONARY_WORDS") {
    copy("$DEFAULT_DICTIONARY_WORDS.bible.xml", "$MAININPD/$DICTIONARY_WORDS");
    &Note("Copying default $DICTIONARY_WORDS $DEFAULT_DICTIONARY_WORDS.bible.xml to $MAININPD/$DICTIONARY_WORDS");
  }
  
  # Load DictionaryWords.xml
  if ($modType eq 'dict' && $addSeeAlsoLinks) {
    our $DWF = &loadDictionaryWordsXML($OSIS);
  }
  elsif ($modType eq 'bible' && $DICTMOD && -e "$MAININPD/$DICTIONARY_WORDS") {
    my $dictosis = &getModuleOsisFile($DICTMOD);
    if ($dictosis && $DEBUG) {
      &Warn("$DICTIONARY_WORDS is present and will now be validated against dictionary OSIS file $dictosis which may or may not be up to date.");
      $DWF = &loadDictionaryWordsXML($dictosis);
    }
    else {
      &Warn("$DICTIONARY_WORDS is present but will not be validated against the DICT OSIS file because osis-converters is not running in DEBUG mode.");
      $DWF = &loadDictionaryWordsXML();
    }
  }

  # Add any missing Table of Contents milestones and titles as required for eBooks, html etc.
  &writeTOC(\$OSIS, $modType);

  # Parse Scripture references from the text and check them
  if ($addScripRefLinks) {
    &runAddScripRefLinks($modType, \$OSIS);
    &adjustAnnotateRefs(\$OSIS);
    &checkSourceScripRefLinks($OSIS);
  }
  else {&removeMissingOsisRefs(\$OSIS);}

  # Parse links to footnotes if a text includes them
  if ($addFootnoteLinks) {
    if (!$addScripRefLinks) {
    &Error("SET_addScripRefLinks must be 'true' if SET_addFootnoteLinks is 'true'. Footnote links will not be parsed.", 
"Change these values in CF_usfm2osis.txt. If you need to parse footnote 
links, you need to parse Scripture references first, using 
CF_addScripRefLinks.txt.");
    }
    else {
      my $CF_addFootnoteLinks = &getDefaultFile("$modType/CF_addFootnoteLinks.txt", -1);
      if ($CF_addFootnoteLinks) {
        &runAddFootnoteLinks($CF_addFootnoteLinks, \$OSIS);
      }
      else {&Error("CF_addFootnoteLinks.txt is missing", 
"Remove or comment out SET_addFootnoteLinks in CF_usfm2osis.txt if your 
translation does not include links to footnotes. If it does include 
links to footnotes, then add and configure a CF_addFootnoteLinks.txt 
file to convert footnote references in the text into working hyperlinks.");}
    }
  }

  # Parse glossary references from Bible and Dict modules 
  if ($DICTMOD && $modType eq 'bible' && $addDictLinks) {
    if (!$DWF || ! -e "$INPD/$DICTIONARY_WORDS") {
      &Error("A $DICTIONARY_WORDS file is required to run addDictLinks.pl.", "First run sfm2osis.pl on the companion module \"$DICTMOD\", then copy  $DICTMOD/$DICTIONARY_WORDS to $MAININPD.");
    }
    else {&runAddDictLinks(\$OSIS);}
  }
  elsif ($modType eq 'dict' && $addSeeAlsoLinks && -e "$DICTINPD/$DICTIONARY_WORDS") {
    &runAddSeeAlsoLinks(\$OSIS);
  }

  # Every note should have an osisRef pointing to where the note refers
  &writeMissingNoteOsisRefsFAST(\$OSIS);

  # Fit the custom verse system into a known fixed verse system and then check against it
  if ($modType eq 'bible') {
    &fitToVerseSystem(\$OSIS, &conf('Versification'));
    &checkVerseSystem($OSIS, &conf('Versification'));
  }

  # Add external cross-referenes to Bibles
  if ($modType eq 'bible' && $addCrossRefs) {&runAddCrossRefs(\$OSIS);}

  # If there are differences between the custom and fixed verse systems, then some references need to be updated
  if ($modType eq 'bible' || $modType eq 'dict') {
    &correctReferencesVSYS(\$OSIS);
  }
  
  if ($modType eq 'bible') {
    &removeDefaultWorkPrefixesFAST(\$OSIS);
  }

  # If the project includes a glossary, add glossary navigational menus, and if the 'feature == INT' feature is being used, then add intro nav menus as well.
  if ($DICTMOD) {
    # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
    my $glossContainsINT = -e "$DICTINPD/CF_usfm2osis.txt" && `grep "feature == INT" "$DICTINPD/CF_usfm2osis.txt"`;

    # Tell the user about the introduction nav menu feature if it's available and not being used
    if ($MAINMOD && !$glossContainsINT) {
      my $biblef = &getModuleOsisFile($MAINMOD);
      if ($biblef) {
        if (@{$XPC->findnodes('//osis:div[not(@resp="x-oc")][@type="introduction"][not(ancestor::div[@type="book" or @type="bookGroup"])]', $XML_PARSER->parse_file($biblef))}[0]) {
          &Log("\n");
          &Note(
"Module $MAINMOD contains module introduction material (located before 
the first bookGroup, which applies to the entire module). It appears 
you have not duplicated this material in the glossary. This introductory 
material could be more useful if copied into glossary module $DICTMOD. 
This is done by including the USFM file in both the Bible and glossary 
with feature == INT and in the glossary using an EVAL_REGEX to turn 
the headings into glossary keys. A menu system will then automatically 
be created to make the introduction material available in every book and 
keyword. EX.: Add code something like this to $DICTMOD/CF_usfm2osis.txt: 
EVAL_REGEX(./INT.SFM):s/^[^\\n]+\\n/\\\\id GLO feature == INT\\n/ 
EVAL_REGEX(./INT.SFM):s/^\\\\(?:imt|is) (.*?)\\s*\$/\\\\k \$1\\\\k*/gm 
RUN:./INT.SFM");
        }
      }
    }

    &Log("\n");
    my @navmenus = $XPC->findnodes('//osis:list[@subType="x-navmenu"]', $XML_PARSER->parse_file($OSIS));
    if (!@navmenus[0]) {
      &Note("Running glossaryNavMenu.xsl to add GLOSSARY NAVIGATION menus".($glossContainsINT ? ", and INTRODUCTION menus,":'')." to OSIS file.", 1);
      my $result = &runScript("$SCRD/scripts/navigationMenu.xsl", \$OSIS, '', 3);
      my %chars; my $r = $result; while ($r =~ s/KeySort.*? is missing the character "(\X)//) {$chars{$1}++;}
      if (scalar keys %chars) {&Error("KeySort config entry is missing ".(scalar keys %chars)." character(s): ".join('', sort keys %chars));}
      &Log($result);
    }
    else {&Warn("This OSIS file already has ".@navmenus." navmenus and so this step will be skipped!");}
  }

  # Add any cover images to the OSIS file
  if ($modType ne 'dict') {&addCoverImages(\$OSIS);}
  
  &runScript("$SCRD/scripts/whitespace.xsl", \$OSIS); 
  
  # Run user supplied postprocess.pl and/or postprocess.xsl if present (these are run before adding the nav-menus which are next)
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &runChecks($modType);
  
  copy($OSIS, $OUTOSIS); 
  
  &validateOSIS($OUTOSIS);
}


# This script expects a sfm2osis.pl produced OSIS input file
sub reprocessOSIS {
  my $modname = shift;
  my $sourceProject = shift;
  
  if ($NO_OUTPUT_DELETE) {return;} # after "require"s, then return if previous tmp files are to be used for debugging

  # Run user supplied preprocess.pl and/or preprocess.xsl if present
  &runAnyUserScriptsAt("preprocess", \$OSIS);

  my $modType = (&conf('ModDrv') =~ /LD/ ? 'dict':(&conf('ModDrv') =~ /Text/ ? 'bible':(&conf('ModDrv') =~ /Com/ ? 'commentary':'childrens_bible')));

  &Log("Wrote to header: \n".&writeOsisHeader(\$OSIS)."\n");

  if ($modType eq 'dict' && $reorderGlossaryEntries) {
    my %params = ('glossaryRegex' => $reorderGlossaryEntries);
    &runScript("$SCRD/scripts/dict/reorderGlossaryEntries.xsl", \$OSIS, \%params);
  }

  &checkVerseSystem($OSIS, &conf('Versification'));

  # Add any cover images to the OSIS file
  if ($modType ne 'dict') {&addCoverImages(\$OSIS, 1);}
  
  &runScript("$SCRD/scripts/whitespace.xsl", \$OSIS); 

  # Run user supplied postprocess.pl and/or postprocess.xsl if present (these are run before adding the nav-menus which are next)
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &runChecks($modType);
  
  # Check our osis file for unintentional occurrences of sourceProject code
  &Note("Checking OSIS for unintentional source project references...\n");
  if (open(TEST, $READLAYER, $OSIS)) {
    my $osis = join('', <TEST>);
    my $spregex = "\\b($sourceProject"."DICT|$sourceProject)\\b";
    my $n = 0;
    foreach my $l (split(/\n/, $osis)) {
      if ($l !~ /$spregex/) {next;}
      $n++;
      if ($l =~ /AudioCode/) {
        &Note("Intentional reference: $l");
        next;
      }
      &Error("Found source project code $1 in $MOD: $l", 
      "The osis2osis transliterator method is failing to convert this text.");
    }
    close(TEST);
    &Report("Found $n occurrence(s) of source project code in $MOD.\n");
  }
  else {
    &ErrorBug("Could not open source OSIS $OSIS\n", 1);
  }
  
  copy($OSIS, $OUTOSIS);
  
  &validateOSIS($OUTOSIS);
}


sub runChecks {
  my $modType = shift;
  
  our %DOCUMENT_CACHE;
  undef(%DOCUMENT_CACHE); &getModNameOSIS($XML_PARSER->parse_file($OSIS)); # reset cache
  
  if ($modType ne 'dict' || -e &getModuleOsisFile($MAINMOD)) {&checkReferenceLinks($OSIS);}
  else {
  &Error("Glossary links and Bible links in the dictionary module cannot be checked.",
"The Bible module OSIS file must be created before the dictionary 
module OSIS file, so that all reference links can be checked. Create the
Bible module OSIS file, then run this dictionary module again.");
  }
  
  &checkUniqueOsisIDs($OSIS);
  &checkFigureLinks($OSIS);
  &checkIntroductionTags($OSIS);
  &checkCharacters($OSIS);
  if ($DWF) {&checkDictionaryWordsContexts($OSIS, $DWF);}
  if ($modType eq 'childrens_bible') {&checkChildrensBibleStructure($OSIS);}
}


sub validateOSIS {
  my $osis = shift;
  
  # validate new OSIS file against OSIS schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  my $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ".&escfile("xmllint")." --noout --schema \"$OSISSCHEMA\" ".&escfile($osis)." 2>&1";
  &Log("$cmd\n");
  my $res = `$cmd`;
  my $allow = "(element milestone\: Schemas validity )error( \: Element '.*?milestone', attribute 'osisRef'\: The attribute 'osisRef' is not allowed\.)";
  my $fix = $res;
  $fix =~ s/$allow/$1e-r-r-o-r$2/g;
  &Log("$fix\n");
  
  if ($res =~ /failed to load external entity/i) {&Error("The validator failed to load an external entity.", "Maybe there is a problem with the Internet connection, or with one of the input files to the validator.");}
  
  # Generate error if file fails to validate
  my $valid = 0;
  if ($res =~ /^\Q$osis validates\E$/) {$valid = 1;}
  elsif (!$res || $res =~ /^\s*$/) {
    &Error("\"$osis\" validation problem. No success or failure message was returned from the xmllint validator.", "Check your Internet connection, or try again later.");
  }
  else {
    if ($res =~ s/$allow//g) {
      &Note("
      Ignore the above milestone osisRef attribute reports. The schema  
      here apparently deviates from the OSIS handbook which states that 
      the osisRef attribute is allowed on any element. The current usage  
      is both required and sensible.\n");
    }
    if ($res !~ /Schemas validity error/) {
      &Note("All of the above validation failures are being allowed.");
      $valid = 1;
    }
    else {&Error("\"$osis\" does not validate! See message(s) above.");}
  }
  
  &Report("OSIS ".($valid ? 'passes':'fails')." required validation.\nEND OSIS VALIDATION");
}

1;
