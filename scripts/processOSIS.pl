require("$SCRD/scripts/dict/processGlossary.pl");
require("$SCRD/scripts/addScripRefLinks.pl");
require("$SCRD/scripts/addFootnoteLinks.pl");
require("$SCRD/scripts/bible/addDictLinks.pl");
require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");
require("$SCRD/scripts/bible/addCrossRefs.pl");

# MOD_0.xml is raw converter output
$OSIS = "$TMPDIR/".$MOD."_0.xml";
&runAnyUserScriptsAt("preprocess", \$OSIS);

my $modType = ($MODDRV =~ /LD/ ? 'dict':($MODDRV =~ /Text/ ? 'bible':'childrens_bible'));

%HTMLCONV  = &readConvertTxt(&getDefaultFile('bible/html/convert.txt'));
%EBOOKCONV = &readConvertTxt(&getDefaultFile('bible/eBook/convert.txt'));
$TOCNUMBER = ($EBOOKCONV{'TOC'} ? $EBOOKCONV{'TOC'}:$DEFAULT_TOCNUMBER);
$TITLECASE = ($EBOOKCONV{'TitleCase'} ? $EBOOKCONV{'TitleCase'}:$DEFAULT_TITLECASE);

&runScript("$SCRD/scripts/usfm2osis.py.xsl", \$OSIS);

&Log("Wrote to header: \n".&writeOsisHeader(\$OSIS, $ConfEntryP, \%EBOOKCONV, \%HTMLCONV, NULL)."\n");

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &orderBooksPeriphs(\$OSIS, $VERSESYS, $customBookOrder);
  &runScript("$SCRD/scripts/bible/checkUpdateIntros.xsl", \$OSIS);
  if ($DICTMOD && $addDictLinks && -e "$INPD/$DICTIONARY_WORDS") {
    my $dictosis = &getProjectOsisFile($DICTMOD);
    if ($dictosis) {
      &Warn("$DICTIONARY_WORDS is present and will now be validated against dictionary OSIS file $dictosis which may or may not be up to date.");
      &loadDictionaryWordsXML($dictosis);
    }
    else {
      &loadDictionaryWordsXML();
      &Warn("$DICTIONARY_WORDS is present but there is no companion dictionary OSIS file to validate against.");
    }
  }
}
elsif ($MODDRV =~ /LD/) {

  if (!$ConfEntryP->{'KeySort'}) {
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
  
  if (!$ConfEntryP->{'LangSortOrder'}) {
    &Error("LangSortOrder is missing from config.conf", "
Although this config entry has been replaced by KeySort and is 
deprecated and no longer used by osis-converters, for now it is still 
required to prevent the breaking of older programs. Its value is just 
that of KeySort, but bracketed groups of regular expressions are not 
allowed and must be removed.");
  }
  
  my @keywordDivs = $XPC->findnodes('//osis:div[contains(@type, "x-keyword")]', $XML_PARSER->parse_file($OSIS));
  if (!@keywordDivs[0]) {&runScript("$SCRD/scripts/dict/aggregateRepeatedEntries.xsl", \$OSIS);}
  
  if ($addSeeAlsoLinks) {
    my %params = ('notXPATH_default' => $DICTIONARY_NotXPATH_Default);
    &runXSLT("$SCRD/scripts/dict/writeDictionaryWords.xsl", $OSIS, $DEFAULT_DICTIONARY_WORDS, \%params);
    # write INPD DictionaryWords.txt if needed
    if (-e $DEFAULT_DICTIONARY_WORDS && ! -e "$INPD/$DICTIONARY_WORDS") {
      copy($DEFAULT_DICTIONARY_WORDS, "$INPD/$DICTIONARY_WORDS");
    }
    # write MAINMOD DictionaryWords.txt if needed
    if (&loadDictionaryWordsXML($OSIS) && $MAINMOD && ! -e "$MAININPD/$DICTIONARY_WORDS") {
      copy($DEFAULT_DICTIONARY_WORDS, "$MAININPD/$DICTIONARY_WORDS");
    }
  }
  
  if ($reorderGlossaryEntries) {
    my %params = ('glossaryRegex' => $reorderGlossaryEntries);
    &runScript("$SCRD/scripts/dict/reorderGlossaryEntries.xsl", \$OSIS, \%params);
  }
  
}
else {die "Unhandled ModDrv \"$MODDRV\"\n";}

&writeNoteIDs(\$OSIS, $ConfEntryP);

&writeTOC(\$OSIS);

if ($addScripRefLinks) {
  &runAddScripRefLinks(&getDefaultFile("$modType/CF_addScripRefLinks.txt"), \$OSIS);
  &checkSourceScripRefLinks($OSIS);
}
else {&removeMissingOsisRefs(\$OSIS);}

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

if ($DICTMOD && $MODDRV =~ /Text/ && $addDictLinks) {
  if (!$DWF || ! -e "$INPD/$DICTIONARY_WORDS") {
    &Error("A $DICTIONARY_WORDS file is required to run addDictLinks.pl.", "First run sfm2osis.pl on the companion module \"$DICTMOD\", then copy  $DICTMOD/$DICTIONARY_WORDS to $MAININPD.");
  }
  else {&runAddDictLinks(\$OSIS);}
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks && -e "$INPD/$DICTIONARY_WORDS") {
  &runAddSeeAlsoLinks(\$OSIS);
}

&writeMissingNoteOsisRefsFAST(\$OSIS);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &fitToVerseSystem(\$OSIS, $VERSESYS);
  &checkVerseSystem($OSIS, $VERSESYS);
}

if ($MODDRV =~ /Text/ && $addCrossRefs) {&runAddCrossRefs(\$OSIS);}

&correctReferencesVSYS(\$OSIS);

if ($MODDRV =~ /Text/) {&removeDefaultWorkPrefixesFAST(\$OSIS);}

# Run postprocess.(pl|xsl) if they exist
&runAnyUserScriptsAt("postprocess", \$OSIS);

# If the project includes a glossary, add glossary navigational menus, and if there is a glossary div with scope="INT" also add intro nav menus.
if ($DICTMOD && ! -e "$DICTINPD/navigation.sfm") {
  # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
  my $glossContainsINT = -e "$DICTINPD/CF_usfm2osis.txt" && `grep "scope == INT" "$DICTINPD/CF_usfm2osis.txt"`;

  # Tell the user about the introduction nav menu feature if it's available and not being used
  if ($MAINMOD && !$glossContainsINT) {
    my $biblef = &getProjectOsisFile($MAINMOD);
    if ($biblef) {
      if (@{$XPC->findnodes('//osis:div[@type="introduction"][not(ancestor::div[@type="book" or @type="bookGroup"])]', $XML_PARSER->parse_file($biblef))}[0]) {
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

# Checks occur as late as possible in the flow
if ($MODDRV !~ /LD/ || -e &getProjectOsisFile($MAINMOD)) {
  &checkReferenceLinks($OSIS);
}
else {
  &Error("Glossary links and Bible links in the dictionary module cannot be checked.",
"The Bible module OSIS file must be created before the dictionary 
module OSIS file, so that all reference links can be checked. Create the
Bible module OSIS file, then run this dictionary module again to check 
all references and remove this error.");
}

&checkUniqueOsisIDs($OSIS);
&checkFigureLinks($OSIS);
&checkIntroductionTags($OSIS);

copy($OSIS, $OUTOSIS); 
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
&runXSLT("$SCRD/scripts/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");

&timer('stop');
1;
