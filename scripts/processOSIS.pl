require("$SCRD/scripts/bible/fitToVerseSystem.pl");
if ($MODDRV =~ /LD/) {require("$SCRD/scripts/dict/processGlossary.pl");}

my $modType = ($MODDRV =~ /LD/ ? 'dict':($MODDRV =~ /Text/ ? 'bible':'childrens_bible'));

# MOD_0.xml is raw converter output
$OSIS = "$TMPDIR/".$MOD."_0.xml";
&runScript("$SCRD/scripts/usfm2osis.py.xsl", \$OSIS);

$c = &getDefaultFile('bible/html/convert.txt');
%HTMLCONV = ($c ? &readConvertTxt($c):());
$c = &getDefaultFile('bible/eBook/convert.txt');
%EBOOKCONV = ($c ? &readConvertTxt($c):());
my $projectBible;
my $projectGlossary;
&Log("Wrote to header: \n".&writeOsisHeader(\$OSIS, $ConfEntryP, \%EBOOKCONV, \%HTMLCONV, NULL, \$projectBible, \$projectGlossary)."\n");

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &orderBooksPeriphs(\$OSIS, $VERSESYS, $customBookOrder);
  &runScript("$SCRD/scripts/bible/checkUpdateIntros.xsl", \$OSIS);
  if (-e "$INPD/$DICTIONARY_WORDS") {
    my $dictosis = ($projectGlossary ? &getProjectOsisFile($projectGlossary):'');
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
  &runScript("$SCRD/scripts/dict/aggregateRepeatedEntries.xsl", \$OSIS);
  my %params = ('notXPATH_default' => $DICTIONARY_NotXPATH_Default);
  &runXSLT("$SCRD/scripts/dict/writeDictionaryWords.xsl", $OSIS, $DEFAULT_DICTIONARY_WORDS, \%params);
  if (! -e "$INPD/$DICTIONARY_WORDS" && -e $DEFAULT_DICTIONARY_WORDS) {
    copy($DEFAULT_DICTIONARY_WORDS, "$INPD/$DICTIONARY_WORDS");
  }
  if (&loadDictionaryWordsXML($OSIS) && $projectBible && -e "$INPD/../../$projectBible" && ! -e "$INPD/../../$projectBible/$DICTIONARY_WORDS") {
    copy($DEFAULT_DICTIONARY_WORDS, "$INPD/../../$projectBible/$DICTIONARY_WORDS");
  }
}
else {die "Unhandled ModDrv \"$MODDRV\"\n";}

&writeNoteIDs(\$OSIS, $ConfEntryP);

&writeTOC(\$OSIS);

if ($addScripRefLinks) {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &runAddScripRefLinks(&getDefaultFile("$modType/CF_addScripRefLinks.txt"), \$OSIS);
  &checkSourceScripRefLinks($OSIS, $projectBible);
}

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
      require("$SCRD/scripts/addFootnoteLinks.pl");
      &runAddFootnoteLinks($CF_addFootnoteLinks, \$OSIS);
    }
    else {&Error("CF_addFootnoteLinks.txt is missing", 
"Remove or comment out SET_addFootnoteLinks in CF_usfm2osis.txt if your 
translation does not include links to footnotes. If it does include 
links to footnotes, then add and configure a CF_addFootnoteLinks.txt 
file to convert footnote references in the text into working hyperlinks.");}
  }
}

if ($MODDRV =~ /Text/ && $addDictLinks) {
  if (!$DWF || ! -e "$INPD/$DICTIONARY_WORDS") {
    &Error("A $DICTIONARY_WORDS file is required to run addDictLinks.pl.", "First run sfm2osis.pl on the companion module \"$projectGlossary\", then copy  $projectGlossary/$DICTIONARY_WORDS to $INPD.");
  }
  else {
    require("$SCRD/scripts/bible/addDictLinks.pl");
    &runAddDictLinks(\$OSIS);
  }
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks && -e "$INPD/$DICTIONARY_WORDS") {
  require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");
  &runAddSeeAlsoLinks(\$OSIS);
}

&writeMissingNoteOsisRefsFAST(\$OSIS);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &fitToVerseSystem(\$OSIS, $VERSESYS);
}

if ($MODDRV =~ /Text/ && $addCrossRefs) {
  require("$SCRD/scripts/bible/addCrossRefs.pl");
  &runAddCrossRefs(\$OSIS);
}

&correctReferencesVSYS(\$OSIS, $projectBible);

if ($MODDRV =~ /Text/) {&removeDefaultWorkPrefixesFAST(\$OSIS);}

# Run postprocess.(pl|xsl) if they exist
&runAnyUserScriptsAt("postprocess", \$OSIS);

# Checks occur as late as possible in the flow
&checkReferenceLinks($OSIS);

# After checking references, if the project includes a glossary, add glossary navigational menus, and if there is a glossary div with scope="INT" also add intro nav menus.
if ($projectBible && !(-e "$DICTINPD/navigation.sfm")) {
  # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
  my $glossContainsINT = ($projectGlossary ? `grep "scope == INT" "$DICTINPD/CF_usfm2osis.txt"`:'');

  # Tell the user about the introduction nav menu feature if it's available and not being used
  if ($projectGlossary && !$glossContainsINT) {
    my $biblef = &getProjectOsisFile($projectBible);
    if ($biblef) {
      if (@{$XPC->findnodes('//osis:div[@type="introduction"][not(ancestor::div[@type="book" or @type="bookGroup"])]', $XML_PARSER->parse_file($biblef))}[0]) {
        my $bmod = $projectBible; my $gmod = $projectGlossary;
        &Note(
"Module $bmod contains module introduction material (located before 
the first bookGroup, which applies to the entire module). It appears 
you have not duplicated this material in the glossary. This introductory 
material could be more useful if copied into glossary module $gmod. 
Typically this is done by including the INT USFM file in the glossary 
with scope INT and using an EVAL_REGEX to turn the headings into 
glossary keys. A menu system will then automatically be created to make 
the introduction material available in every book and keyword. Just add 
code something like this to $gmod/CF_usfm2osis.txt: 
EVAL_REGEX(./INT.SFM):s/^[^\\n]+\\n/\\\\id GLO scope == INT\\n/ 
EVAL_REGEX(./INT.SFM):s/^\\\\(?:imt|is) (.*?)\\s*\$/\\\\k \$1\\\\k*/gm 
RUN:./INT.SFM");
      }
    }
  }

  &Log("\n");
  &Note("Running glossaryNavMenu.xsl to add GLOSSARY NAVIGATION menus".($glossContainsINT ? ", and INTRODUCTION menus,":'')." to OSIS file.", 1);
  %params = ($glossContainsINT ? ('introScope' => 'INT'):());
  &runScript("$SCRD/scripts/navigationMenu.xsl", \$OSIS, \%params);
}

&checkFigureLinks($OSIS);
&checkIntroductionTags($OSIS);

copy($OSIS, $OUTOSIS); 
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
&runXSLT("$SCRD/scripts/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");

&timer('stop');
1;
