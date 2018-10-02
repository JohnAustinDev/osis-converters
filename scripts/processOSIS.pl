require("$SCRD/scripts/bible/fitToVerseSystem.pl");
if ($MODDRV =~ /LD/) {require("$SCRD/scripts/dict/processGlossary.pl");}

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
      &Log("WARNING: $DICTIONARY_WORDS is present and will now be validated against dictionary OSIS file $dictosis which may or may not be up to date.\n");
      &loadDictionaryWordsXML($dictosis);
    }
    else {
      &loadDictionaryWordsXML();
      &Log("WARNING: $DICTIONARY_WORDS is present but there is no companion dictionary OSIS file to validate against.\n");
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

my $asrl = &getDefaultFile(($MODDRV =~ /LD/ ? 'dict':'bible').'/CF_addScripRefLinks.txt');
if ($addScripRefLinks ne '0' && $asrl) {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks($asrl, \$OSIS);
  &checkScripRefLinks($OSIS, $projectBible);
  if ($addFootnoteLinks ne '0' && -e "$INPD/CF_addFootnoteLinks.txt") {
    require("$SCRD/scripts/addFootnoteLinks.pl");
    &addFootnoteLinks(\$OSIS);
  }
}

if ($MODDRV =~ /Text/ && $addDictLinks ne '0') {
  if (!$DWF || ! -e "$INPD/$DICTIONARY_WORDS") {&Log("ERROR: $DICTIONARY_WORDS is required to run addDictLinks.pl. Copy it from companion dictionary project.\n"); die;}
  require("$SCRD/scripts/bible/addDictLinks.pl");
  &addDictLinks(\$OSIS);
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks ne '0' && -e "$INPD/$DICTIONARY_WORDS") {
  require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");
  &addSeeAlsoLinks(\$OSIS);
}

&writeMissingNoteOsisRefsFAST(\$OSIS);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &fitToVerseSystem(\$OSIS, $VERSESYS);
}

if ($MODDRV =~ /Text/ && $addCrossRefs ne '0') {
  require("$SCRD/scripts/bible/addCrossRefs.pl");
  &addCrossRefs(\$OSIS);
}

&correctReferencesVSYS(\$OSIS, $projectBible);

if ($MODDRV =~ /Text/) {&removeDefaultWorkPrefixesFAST(\$OSIS);}

# Run postprocess.(pl|xsl) if they exist
&runAnyUserScriptsAt("postprocess", \$OSIS);

# Checks occur as late as possible in the flow
&checkReferenceLinks($OSIS);

# After checking references, if the project includes a glossary, add glossary navigational menus, and if there is a glossary div with scope="INT" also add intro nav menus.
if ($projectBible && !(-e "$INPD/navigation.sfm" || -e "$INPD/".$projectGlossary."/navigation.sfm")) {
  # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
  my $gloss = ($projectGlossary ? "$INPD/".($MODDRV =~ /Text/ ? $projectGlossary.'/':'')."CF_usfm2osis.txt":'');
  my $glossContainsINT = ($projectGlossary ? `grep "scope == INT" $gloss`:'');

  # Tell the user about the introduction nav menu feature if it's available and not being used
  if ($projectGlossary && !$glossContainsINT) {
    my $biblef = &getProjectOsisFile($projectBible);
    if ($biblef) {
      if (@{$XPC->findnodes('//osis:div[@type="introduction"][not(ancestor::div[@type="book" or @type="bookGroup"])]', $XML_PARSER->parse_file($biblef))}[0]) {
        my $bmod = $projectBible; my $gmod = $projectGlossary;
        &Log("
NOTE: Module $bmod contains <div type=\"introduction\"> material and it 
      appears you have not duplicated that material in the glossary. This \
      introductory material could be more useful if copied into glossary \
      module $gmod. This can easily be done by including the INT USFM file \
      in the glossary with scope INT and using an EVAL_REGEX to turn the \
      headings into glossary keys. A menu system will then automatically \
      be created to make the introduction material available in every \
      book and keyword. Just add code like this to $gmod/CF_usfm2osis.txt: \
EVAL_REGEX(./INT.SFM):s/^[^\\n]+\\n/\\\\id GLO scope == INT\\n/ \
EVAL_REGEX(./INT.SFM):s/^\\\\(?:imt|is) (.*?)\\s*\$/\\\\k \$1\\\\k*/gm \
RUN:./INT.SFM\n");
      }
    }
  }

  &Log("\nNOTE: Running glossaryNavMenu.xsl to add GLOSSARY NAVIGATION menus".($glossContainsINT ? ", and INTRODUCTION menus,":'')." to OSIS file.\n", 1);
  %params = ($glossContainsINT ? ('introScope' => 'INT'):());
  &runScript("$SCRD/scripts/navigationMenu.xsl", \$OSIS, \%params);
}

&checkFigureLinks($OSIS);
&checkIntroductionTags($OSIS);

copy($OSIS, $OUTOSIS); 
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
&runXSLT("$SCRD/scripts/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");

&Log("\nend time: ".localtime()."\n");
