require("$SCRD/scripts/dict/processGlossary.pl");
require("$SCRD/scripts/addScripRefLinks.pl");
require("$SCRD/scripts/addFootnoteLinks.pl");
require("$SCRD/scripts/bible/addDictLinks.pl");
require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");
require("$SCRD/scripts/bible/addCrossRefs.pl");

# This script expects a usfm2osis.py produced OSIS input file
sub runProcessOSIS($) {
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
    &orderBooksPeriphs(\$OSIS, &conf('Versification'), $customBookOrder);
    &runScript("$SCRD/scripts/bible/checkUpdateIntros.xsl", \$OSIS);   
  }
  # Dictionary OSIS: aggregate repeated entries (required for SWORD) and re-order entries if desired
  elsif ($modType eq 'dict') {
    if (!&conf('KeySort')) {
      &Error("KeySort is missing from config.conf", '
This required config entry facilitates correct sorting of glossary 
keys. EXAMPLE:
KeySort = AaBbDdEeFfGgHhIijKkLlMmNnOoPpQqRrSsTtUuVvXxYyZz[Gʻ][gʻ][Sh][sh][Ch][ch][ng]ʻʼ{\\[}{\(}{\\{}
This entry allows sorting in any desired order by character collation. 
Square brackets are used to separate any arbitrary JDK 1.4 case  
sensitive regular expressions which are to be treated as single 
characters during the sort comparison. Likewise, curly brackets should 
be used around any similar regular expression(s) which are to be ignored  
during the sort comparison. Every other square or curly bracket must be 
escaped by backslash. This means the string to ignore all brackets or 
parenthesis would be: {\[\\[\\]\\{\\}\(\)\]}');
    }
    
    if (!&conf('LangSortOrder')) {
      &Error("LangSortOrder is missing from config.conf", "
Although this config entry has been replaced by KeySort and is 
deprecated and no longer used by osis-converters, for now it is still 
required to prevent the breaking of older programs. Its value is just 
that of KeySort, but bracketed groups of regular expressions are not 
allowed and must be removed.");
    }
    
    my @keywordDivs = $XPC->findnodes('//osis:div[contains(@type, "x-keyword")]', $XML_PARSER->parse_file($OSIS));
    if (!@keywordDivs[0]) {&runScript("$SCRD/scripts/dict/aggregateRepeatedEntries.xsl", \$OSIS);}
    
    # write default DictionaryWords.xml templates
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
    $DWF = &loadDictionaryWordsXML($OSIS);
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

  # Every note tag needs a unique osisID assigned to it, as do some other elements
  &writeOsisIDs(\$OSIS);

  # Add any missing Table of Contents milestones and titles as required for eBooks, html etc.
  &writeTOC(\$OSIS, $modType);

  # Parse Scripture references from the text and check them
  if ($addScripRefLinks) {
    &runAddScripRefLinks($modType, \$OSIS);
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
  if ($modType eq 'bible') {
    &correctReferencesVSYS(\$OSIS);
    &removeDefaultWorkPrefixesFAST(\$OSIS);
  }

  # If the project includes a glossary, add glossary navigational menus, and if there is also a glossary div with scope="INT" add intro nav menus as well.
  if ($DICTMOD && ! -e "$DICTINPD/navigation.sfm") {
    # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
    my $glossContainsINT = -e "$DICTINPD/CF_usfm2osis.txt" && `grep "scope == INT" "$DICTINPD/CF_usfm2osis.txt"`;

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
Typically this is done by including the INT USFM file in the glossary 
with scope INT and using an EVAL_REGEX to turn the headings into 
glossary keys. A menu system will then automatically be created to make 
the introduction material available in every book and keyword. Just add 
code something like this to $DICTMOD/CF_usfm2osis.txt: 
EVAL_REGEX(./INT.SFM):s/^[^\\n]+\\n/\\\\id GLO scope == INT\\n/ 
EVAL_REGEX(./INT.SFM):s/^\\\\(?:imt|is) (.*?)\\s*\$/\\\\k \$1\\\\k*/gm 
RUN:./INT.SFM");
        }
      }
    }

    &Log("\n");
    my @navmenus = $XPC->findnodes('//osis:list[@subType="x-navmenu"]', $XML_PARSER->parse_file($OSIS));
    if (!@navmenus[0]) {
      &Note("Running glossaryNavMenu.xsl to add GLOSSARY NAVIGATION menus".($glossContainsINT ? ", and INTRODUCTION menus,":'')." to OSIS file.", 1);
      %params = ($glossContainsINT ? ('introScope' => 'INT'):());
      &runScript("$SCRD/scripts/navigationMenu.xsl", \$OSIS, \%params);
    }
    else {&Warn("This OSIS file already has ".@navmenus." navmenus and so this step will be skipped!");}
  }

  # Add any cover images to the OSIS file
  if ($modType ne 'dict') {&addCoverImages(\$OSIS);}
  
  # Run user supplied postprocess.pl and/or postprocess.xsl if present (these are run before adding the nav-menus which are next)
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &checkAndValidate($modType);

  # Do a tmp Pretty Print for debug referencing during the conversion process
  &runXSLT("$SCRD/scripts/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");
}


sub checkAndValidate($) {
  my $modType = shift;
  
  undef($DOCUMENT_CACHE); &getModNameOSIS($XML_PARSER->parse_file($OSIS)); # reset cache
  
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

  copy($OSIS, $OUTOSIS); 
  &validateOSIS($OUTOSIS);
}


# This script expects a sfm2osis.pl produced OSIS input file
sub runReprocessOSIS($) {
  my $modname = shift;
  
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

  # Run user supplied postprocess.pl and/or postprocess.xsl if present (these are run before adding the nav-menus which are next)
  &runAnyUserScriptsAt("postprocess", \$OSIS);

  # Checks are done now, as late as possible in the flow
  &checkAndValidate($modType);

  # Do a tmp Pretty Print for debug referencing during the conversion process
  &runXSLT("$SCRD/scripts/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/$modname_PrettyPrint.xml");
}

1;
