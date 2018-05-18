require("$SCRD/scripts/perl/bible/fitToVerseSystem.pl");
if ($MODDRV =~ /LD/) {require("$SCRD/scripts/perl/dict/processGlossary.pl");}

# MOD_0.xml is raw converter output
$OSIS = "$TMPDIR/".$MOD."_0.xml";
&runScript("$SCRD/scripts/xslt/usfm2osis.py.xsl", \$OSIS);

$CONVERT_TXT = (-e "$INPD/eBook/convert.txt" ? "$INPD/eBook/convert.txt":(-e "$INPD/../eBook/convert.txt" ? "$INPD/../eBook/convert.txt":''));
%EBOOKCONV = ($CONVERT_TXT ? &ebookReadConf($CONVERT_TXT):());
my $projectBible;
my $projectGlossary;
&writeOsisHeader(\$OSIS, $ConfEntryP, \%EBOOKCONV, \$projectBible, \$projectGlossary);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &orderBooksPeriphs(\$OSIS, $VERSESYS, $customBookOrder);
  &runScript("$SCRD/scripts/xslt/bible/checkUpdateIntros.xsl", \$OSIS);
}
elsif ($MODDRV =~ /LD/) {
  &runScript("$SCRD/scripts/xslt/dict/aggregateRepeatedEntries.xsl", \$OSIS);
  my %params = ('notXPATH_default' => $DICTIONARY_NotXPATH_Default);
  &runXSLT("$SCRD/scripts/xslt/dict/writeDictionaryWords.xsl", $OSIS, $DEFAULT_DICTIONARY_WORDS, \%params);
  &loadDictionaryWordsXML(1);
  &compareToDictionaryWordsXML($OSIS);
}
else {die "Unhandled ModDrv \"$MODDRV\"\n";}

&writeNoteIDs(\$OSIS, $ConfEntryP);

&writeTOC(\$OSIS);

if ($addScripRefLinks ne '0' && -e "$INPD/CF_addScripRefLinks.txt") {
  require("$SCRD/scripts/perl/addScripRefLinks.pl");
  &addScripRefLinks(\$OSIS);
  &checkScripRefLinks($OSIS, $projectBible);
  if ($addFootnoteLinks ne '0' && -e "$INPD/CF_addFootnoteLinks.txt") {
    require("$SCRD/scripts/perl/addFootnoteLinks.pl");
    &addFootnoteLinks(\$OSIS);
  }
}

if ($MODDRV =~ /Text/ && $addDictLinks ne '0' && -e "$INPD/$DICTIONARY_WORDS") {
  if (!$DWF) {&Log("ERROR: $DICTIONARY_WORDS is required to run addDictLinks.pl. Copy it from companion dictionary project.\n"); die;}
  require("$SCRD/scripts/perl/bible/addDictLinks.pl");
  &addDictLinks(\$OSIS);
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks ne '0' && -e "$INPD/$DICTIONARY_WORDS") {
  require("$SCRD/scripts/perl/dict/addSeeAlsoLinks.pl");
  &addSeeAlsoLinks(\$OSIS);
}

&writeMissingNoteOsisRefsFAST(\$OSIS);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &fitToVerseSystem(\$OSIS, $VERSESYS);
}

if ($MODDRV =~ /Text/ && $addCrossRefs ne '0') {
  require("$SCRD/scripts/perl/bible/addCrossRefs.pl");
  &addCrossRefs(\$OSIS);
}

&correctReferencesVSYS(\$OSIS, $projectBible);

if ($MODDRV =~ /Text/) {&removeDefaultWorkPrefixesFAST(\$OSIS);}

# Run postprocess.(pl|xsl) if they exist
&runAnyUserScriptsAt("postprocess", \$OSIS);

# Checks occur as late as possible in the flow
&checkReferenceLinks($OSIS);

# After checking references, if the project includes a glossary, add glossary navigational menus, and if there is a glossary div with scope="INT" also add intro nav menus.
if ($projectBible && $projectGlossary && !(-e "$INPD/navigation.sfm" || -e "$INPD/".$projectGlossary."/navigation.sfm")) {
  # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
  my $gloss = "$INPD/".($MODDRV =~ /Text/ ? $projectGlossary.'/':'')."CF_usfm2osis.txt";
  my $glossContainsINT = `grep "scope == INT" $gloss`;

  # Tell the user about the introduction nav menu feature if it's available and not being used
  if (!$glossContainsINT) {
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
  &runScript("$SCRD/scripts/xslt/navigationMenu.xsl", \$OSIS, \%params);
  
  my $css = "$INPD/".($MODDRV =~ /Text/ ? $projectGlossary.'/':'')."sword/css";
  if ($MODDRV =~ /LD/ && (!-e "$INPD/sword/css/swmodule.css" || !&shell("grep PreferredCSSXHTML \"$INPD/config.conf\"", 3))) {
    &Log("
WARNING: For the navigation menu to look best in SWORD, you should use 
         glossary module css. Here is how it may be done:
         1) Edit \"$MOD/config.conf\" to add the config entry: \"PreferredCSSXHTML=swmodule.css\"
         2) Open or create the css file: \"$MOD/sword/css/swmodule.css\"
         3) Add the css: ".&shell("cat \"$SCRD/defaults/dict/sword/css/swmodule.css\"", 3)."\n");
  }
}

&checkFigureLinks($OSIS);
&checkIntroductionTags($OSIS);

copy($OSIS, $OUTOSIS); 
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
&runXSLT("$SCRD/scripts/xslt/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");

&Log("\nend time: ".localtime()."\n");
