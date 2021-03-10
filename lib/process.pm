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

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, 
    $TMPDIR, $NO_OUTPUT_DELETE, $DEBUG, $OSIS, $XPC, $XML_PARSER, 
    $READLAYER, $DICTIONARY_NotXPATH_Default, $OSISSCHEMA, $MOD_OUTDIR);

# Initialized in /lib/sfm2osis.pm
our $sourceProject;

require("$SCRD/lib/addFootnoteLinks.pm");
require("$SCRD/lib/addScripRefLinks.pm");
require("$SCRD/lib/addTOC.pm");
require("$SCRD/lib/applyPeriphInstructions.pm");
require("$SCRD/lib/bible/fitToVerseSystem.pm");
require("$SCRD/lib/bible/addCrossRefLinks.pm");
require("$SCRD/lib/bible/addDictLinks.pm");
require("$SCRD/lib/dict/addDictLinks.pm");

# This sub expects an OSIS input file produced by usfm2osis.py
sub processOSIS {
  my $inosis = shift;
  
  # Return if previous tmp files are to be used for debugging
  if ($NO_OUTPUT_DELETE) {return;}

  # Run user supplied preprocess.pl and/or preprocess.xsl if present
  &runAnyUserScriptsAt("preprocess", \$OSIS);

  my $modType = (&conf('ModDrv') =~ /LD/   ? 'dict' :
                (&conf('ModDrv') =~ /Text/ ? 'bible' :
                (&conf('ModDrv') =~ /Com/  ? 'commentary' : 
                'childrens_bible')));

  # Apply any fixups needed to usfm2osis.py output which are 
  # osis-converters specific
  &runScript("$SCRD/lib/usfm2osis.py.xsl", \$OSIS);

  &Log("Wrote to header: \n" . &writeOsisHeader(\$OSIS) . "\n");
  
  if (&conf('NormalizeUnicode')) {
    &normalizeUnicode(\$OSIS, &conf('NormalizeUnicode'));
  }
  
  # Bible OSIS: re-order books and periphs according to CF_sfm2osis.txt
  if ($modType eq 'bible') {
  
    &orderBooks(\$OSIS, &conf('Versification'), &conf('CustomBookOrder'));
    
    &applyVsysMissingVTagInstructions(\$OSIS);
    
    &applyPeriphInstructions(\$OSIS);
    
    &write_osisIDs(\$OSIS);
    
    &runScript("$SCRD/lib/bible/checkUpdateIntros.xsl", \$OSIS);   
  }
  
  # Dictionary OSIS: aggregate repeated entries (required for SWORD) and 
  # re-order entries if desired.
  elsif ($modType eq 'dict') {
    &applyPeriphInstructions(\$OSIS);
    
    if (!@{$XPC->findnodes('//osis:div[contains(@type, "x-keyword")]', 
        $XML_PARSER->parse_file($OSIS))}[0]) {
        
      &runScript("$SCRD/lib/dict/aggregateRepeatedEntries.xsl", \$OSIS);
      
    }
    
    &write_osisIDs(\$OSIS);
    
    if (&conf('ReorderGlossaryEntries')) {
      &runScript("$SCRD/lib/dict/reorderGlossaryEntries.xsl", 
              \$OSIS, 
              { 'glossaryRegex' => &conf('ReorderGlossaryEntries'), });
    }
    
    # create default CF_addDictLinks.xml files
    &runXSLT("$SCRD/lib/dict/CF_addDictLinks.xsl", 
              $OSIS, 
              "$MOD_OUTDIR/CF_addDictLinks.dict.xml", 
              { 'output' => "$MOD_OUTDIR/CF_addDictLinks.dict.xml",
                'notXPATH_default' => $DICTIONARY_NotXPATH_Default, });

    &runXSLT("$SCRD/lib/dict/CF_addDictLinks.xsl", 
              $OSIS, 
              "$MOD_OUTDIR/CF_addDictLinks.bible.xml",
              { 'output' => "$MOD_OUTDIR/CF_addDictLinks.bible.xml",
                'notXPATH_default' => $DICTIONARY_NotXPATH_Default,
                'anyEnding' => 'true', });
  }
  
  # Children's Bible OSIS: specific to osis-converters Children's Bibles
  elsif ($modType eq 'childrens_bible') {
  
    &runScript("$SCRD/lib/genbook/childrensBible.xsl", \$OSIS);
    
    &write_osisIDs(\$OSIS);
    
    &checkAdjustCBImages(\$OSIS);
  }
  
  else {&Error("Unhandled modType: (".&conf('ModDrv').")", '', 1);}
  
  # Copy new CF_addDictLinks.xml if needed
  if ($modType eq 'dict' && 
      -e "$MOD_OUTDIR/CF_addDictLinks.dict.xml" && 
      ! -e "$DICTINPD/CF_addDictLinks.xml") {
      
    copy("$MOD_OUTDIR/CF_addDictLinks.dict.xml", 
        "$DICTINPD/CF_addDictLinks.xml");
        
    &Note("Copying default CF_addDictLinks.xml ".
      "CF_addDictLinks.dict.xml to $DICTINPD/CF_addDictLinks.xml");
  }
  if ($modType eq 'dict' && 
      -e "$MOD_OUTDIR/CF_addDictLinks.bible.xml" && 
      ! -e "$MAININPD/CF_addDictLinks.xml") {
      
    copy("$MOD_OUTDIR/CF_addDictLinks.bible.xml", 
         "$MAININPD/CF_addDictLinks.xml");
         
    &Note("Copying default CF_addDictLinks.xml ".
      "CF_addDictLinks.bible.xml to $MAININPD/CF_addDictLinks.xml");
  }
  
  # Check CF_addDictLinks.xml
  my $hasDWF;
  if ($modType eq 'bible' && $DICTMOD && 
          -e "$MAININPD/CF_addDictLinks.xml") {
    $hasDWF++;
  }
  elsif ($modType eq 'dict' && 
          -e "$DICTINPD/CF_addDictLinks.xml") {
    $hasDWF++;
    
    if (&getDWF('main', 1)) {&checkDWF($OSIS, &getDWF('main', 1));}
    
    if (&getDWF('dict', 1)) {&checkDWF($OSIS, &getDWF('dict', 1));}
  }
  

  # Add any missing Table of Contents milestones and titles as required 
  # for eBooks, html etc.
  &addTOC(\$OSIS, $modType);
  
  # Run again to add osisID's to new TOC milestones
  &write_osisIDs(\$OSIS); 

  # Parse Scripture references from the text and check them
  if (&conf('AddScripRefLinks')) {
  
    &addScripRefLinks($modType, \$OSIS);
    
    &adjustAnnotateRefs(\$OSIS);
    
    &checkMarkSourceScripRefLinks($OSIS);
  }
  else {&removeMissingOsisRefs(\$OSIS);}

  # Parse links to footnotes if a text includes them
  if (&conf('AddFootnoteLinks')) {
    if (&conf('AddScripRefLinks')) {
      my $CF_addFootnoteLinks = 
        &getDefaultFile("$modType/CF_addFootnoteLinks.txt", -1);
        
      if ($CF_addFootnoteLinks) {
        &addFootnoteLinks($CF_addFootnoteLinks, \$OSIS);
      }
      else {&Error("CF_addFootnoteLinks.txt is missing", 
"Remove or comment out SET_addFootnoteLinks in CF_sfm2osis.txt if your 
translation does not include links to footnotes. If it does include 
links to footnotes, then add and configure a CF_addFootnoteLinks.txt 
file to convert footnote references in the text into working hyperlinks.");}
    }
    else {
      &Error(
"AddScripRefLinks must be 'true' if AddFootnoteLinks is 
'true'. Footnote links will not be parsed.", 
"Change these values in confg.conf. If you want to parse footnote 
links, you need to parse Scripture references also.");
    }
  }

  # Parse glossary references from Bible and Dict modules 
  if ($modType eq 'bible' && $DICTMOD && &conf('AddDictLinks')) {
  
    if ($hasDWF) {&addDictLinks(\$OSIS);}
    
    else {
      &Error(
"A CF_addDictLinks.xml file is required to run addDictLinks.", 
"First run sfm2osis on the companion module \"$DICTMOD\", then 
copy  $DICTMOD/CF_addDictLinks.xml to $MAININPD.");
    }
  }
  elsif ($modType eq 'dict' && &conf('AddDictLinks')) {
  
    if ($hasDWF) {&addDictLinks2Dict(\$OSIS);}
    
    else {
      &ErrorBug(
"A CF_addDictLinks.xml file is required to run addDictLinks2Dict.");
    }
  }

  # Every note should have an osisRef pointing to where the note refers
  &writeMissingNoteOsisRefsFAST(\$OSIS);

  # Fit the custom verse system into a known fixed verse system and then 
  # check against it.
  if ($modType eq 'bible') {
  
    &fitToVerseSystem(\$OSIS, &conf('Versification'));
    
    &checkVerseSystem($OSIS, &conf('Versification'));
  }

  # Add external cross-referenes to Bibles
  if ($modType eq 'bible' && &conf('AddCrossRefLinks')) {
    &addCrossRefLinks(\$OSIS);
  }

  # If there are differences between the custom and fixed verse systems, 
  # then some references need to be updated
  if ($modType eq 'bible' || $modType eq 'dict') {
    &correctReferencesVSYS(\$OSIS);
  }
  
  if ($modType eq 'bible') {
    &removeDefaultWorkPrefixesFAST(\$OSIS);
  }

  # If the project includes a glossary, add glossary navigational menus, 
  # and if 'feature == INT' is used, then add intro nav menus as well.
  if ($DICTMOD) {
  
    # Create the Introduction menus whenever the project glossary 
    # contains a 'feature == INT' glossary 
    my $glossContainsINT = -e "$DICTINPD/CF_sfm2osis.txt" && 
      &shell("grep \"feature == INT\" \"$DICTINPD/CF_sfm2osis.txt\"", 3, 1);

    # Tell the user about the introduction nav menu feature if it's 
    # available and not being used
    if ($MAINMOD && !$glossContainsINT) {
      my $biblef = &getModuleOsisFile($MAINMOD);
      if ($biblef) {
        if (@{$XPC->findnodes('//osis:div[not(@resp="x-oc")]
            [@type="introduction"]
            [not(ancestor::div[@type="book" or @type="bookGroup"])]'
            , $XML_PARSER->parse_file($biblef))}[0]) {
          &Log("\n");
          &Warn(
"Module $MAINMOD contains module introduction material (located before 
the first bookGroup, which applies to the entire module). It appears 
you have not duplicated this material in the glossary. This introductory 
material could be more useful if copied into glossary module $DICTMOD. 
This is done by including the USFM file in both the Bible and glossary 
with feature == INT and in the glossary using an EVAL_REGEX to turn 
the headings into glossary keys. A menu system will then automatically 
be created to make the introduction material available in every book and 
keyword. EX.: Add code something like this to $DICTMOD/CF_sfm2osis.txt: 
EVAL_REGEX(./INT.SFM):s/^[^\\n]+\\n/\\\\id GLO feature == INT\\n/ 
EVAL_REGEX(./INT.SFM):s/^\\\\(?:imt|is) (.*?)\\s*\$/\\\\m \\\\k \$1\\\\k*/gm 
RUN:./INT.SFM");
        }
      }
    }

    &Log("\n");
    my @navmenus = $XPC->findnodes('//osis:list[@subType="x-navmenu"]'
        , $XML_PARSER->parse_file($OSIS));
    if (!@navmenus[0]) {
      &Note(
"Running navigationMenu.xsl to add GLOSSARY NAVIGATION menus" . 
($glossContainsINT ? ", and INTRODUCTION menus,":'') .
" to OSIS file.", 1);
      my $result = 
        &runScript("$SCRD/lib/navigationMenu.xsl", \$OSIS, '', 3);
      my %chars; 
      my $r = $result; 
      while ($r =~ s/KeySort.*? is missing the character "(\X)//) {
        $chars{$1}++;
      }
      if (scalar keys %chars) {&Error(
"KeySort config entry is missing ".(scalar keys %chars) .
" character(s): ".join('', sort keys %chars));}
      &Log($result);
    }
    else {
      &Warn("This OSIS file already has " .
        @navmenus." navmenus and so this step will be skipped!");
    }
  }

  # Add any cover images to the OSIS file
  if ($modType ne 'dict') {&addCoverImages(\$OSIS);}
  
  # Normalize the whitespace within the OSIS file
  &runScript("$SCRD/lib/whitespace.xsl", \$OSIS);
  
  # Run user supplied postprocess.pl and/or postprocess.xsl if present
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &runChecks($modType);
  
  # Copy final OSIS file to output destination
  copy($OSIS, &outdir()."/$MOD.xml"); 
  
  # Validate the output OSIS file using the $OSISSCHEMA schema
  &validateOSIS(&outdir()."/$MOD.xml");
}


# This sub expects an OSIS input file produced by sfm2osis
sub reprocessOSIS {
  my $modname = shift;
  my $sourceProject = shift;
  
  # Return if previous tmp files are to be used for debugging
  if ($NO_OUTPUT_DELETE) {return;}

  # Run user supplied preprocess.pl and/or preprocess.xsl if present
  &runAnyUserScriptsAt("preprocess", \$OSIS);

  my $modType = (&conf('ModDrv') =~ /LD/   ? 'dict' :
                (&conf('ModDrv') =~ /Text/ ? 'bible' :
                (&conf('ModDrv') =~ /Com/  ? 'commentary' :
                'childrens_bible')));

  &Log("Wrote to header: \n".&writeOsisHeader(\$OSIS)."\n");
  
  if (&conf('NormalizeUnicode')) {
    &normalizeUnicode(\$OSIS, &conf('NormalizeUnicode'));
  }

  if ($modType eq 'dict' && &conf('ReorderGlossaryEntries')) {
  
    &runScript("$SCRD/lib/dict/reorderGlossaryEntries.xsl", 
              \$OSIS, 
              { 'glossaryRegex' => &conf('ReorderGlossaryEntries')}, );
  }

  &checkVerseSystem($OSIS, &conf('Versification'));

  # Add any cover images to the OSIS file
  if ($modType ne 'dict') {&addCoverImages(\$OSIS, 1);}
  
  # Normalize the whitespace within the OSIS file
  &runScript("$SCRD/lib/whitespace.xsl", \$OSIS); 

  # Run user supplied postprocess.pl and/or postprocess.xsl if present
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &runChecks($modType);
  
  # Check osis file for unintentional occurrences of sourceProject code
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
      &Error(
"Found source project code $1 in $MOD: $l", 
"The osis2osis transliterator method is failing to convert this reference.");
    }
    close(TEST);
    &Report("Found $n occurrence(s) of source project code in $MOD.\n");
  }
  else {
    &ErrorBug("Could not open source OSIS $OSIS\n", 1);
  }
  
  # Copy final OSIS file to output destination
  copy($OSIS, &outdir()."/$MOD.xml");
  
  # Validate the output OSIS file using the $OSISSCHEMA schema
  &validateOSIS(&outdir()."/$MOD.xml");
}

1;
