# MOD_0.xml is raw converter output
&runXSLT("$SCRD/scripts/xslt/usfm2osis.py.xsl", "$TMPDIR/".$MOD."_0.xml", "$TMPDIR/".$MOD."_0a.xml");

$CONVERT_TXT = (-e "$INPD/eBook/convert.txt" ? "$INPD/eBook/convert.txt":(-e "$INPD/../eBook/convert.txt" ? "$INPD/../eBook/convert.txt":''));
%EBOOKCONV = ($CONVERT_TXT ? &ebookReadConf($CONVERT_TXT):());
my $projectBible;
my $projectGlossary;
&writeOsisHeaderWork("$TMPDIR/".$MOD."_0a.xml", $ConfEntryP, \%EBOOKCONV, \$projectBible, \$projectGlossary);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  require("$SCRD/scripts/fitToVerseSystem.pl");
  &orderBooksPeriphs("$TMPDIR/".$MOD."_0a.xml", $VERSESYS, $customBookOrder);
  &runXSLT("$SCRD/scripts/xslt/checkUpdateIntros.xsl", "$TMPDIR/".$MOD."_0a.xml", "$TMPDIR/".$MOD."_1.xml");
}
elsif ($MODDRV =~ /LD/) {
  &runXSLT("$SCRD/scripts/xslt/aggregateRepeatedEntries.xsl", "$TMPDIR/".$MOD."_0a.xml", "$TMPDIR/".$MOD."_1.xml");
  my %params = ('notXPATH_default' => $DICTIONARY_NotXPATH_Default);
  &runXSLT("$SCRD/scripts/xslt/writeDictionaryWords.xsl", "$TMPDIR/".$MOD."_1.xml", $DEFAULT_DICTIONARY_WORDS, \%params);
  require("$SCRD/scripts/processGlossary.pl");
  &loadDictionaryWordsXML(1);
  &compareToDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml");
}
else {die "Unhandled ModDrv \"$MODDRV\"\n";}
&writeNoteIDs("$TMPDIR/".$MOD."_1.xml", $ConfEntryP);
&writeTOC("$TMPDIR/".$MOD."_1.xml");
my $osisDocString = $XML_PARSER->parse_file("$TMPDIR/".$MOD."_1.xml")->toString();
$osisDocString =~ s/\n+/\n/gm;
open(OUTF, ">$TMPDIR/".$MOD."_1.xml");
print OUTF $osisDocString;
close(OUTF);
# MOD_1.xml has books/intros re-ordered, header/intro-tags updated, and glossaries pre-processed

if ($addScripRefLinks ne '0' && -e "$INPD/CF_addScripRefLinks.txt") {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_1a.xml");
  if ($addFootnoteLinks ne '0' && -e "$INPD/CF_addFootnoteLinks.txt") {
    require("$SCRD/scripts/addFootnoteLinks.pl");
    &addFootnoteLinks("$TMPDIR/".$MOD."_1a.xml", "$TMPDIR/".$MOD."_2.xml");
  }
  else {move("$TMPDIR/".$MOD."_1a.xml", "$TMPDIR/".$MOD."_2.xml");}
}
else {copy("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");}
# MOD_2.xml is after addScripRefLinks.pl

if ($MODDRV =~ /Text/ && $addDictLinks ne '0' && -e "$INPD/$DICTIONARY_WORDS") {
  if (!$DWF) {&Log("ERROR: $DICTIONARY_WORDS is required to run addDictLinks.pl. Copy it from companion dictionary project.\n"); die;}
  require("$SCRD/scripts/addDictLinks.pl");
  &addDictLinks("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks ne '0' && -e "$INPD/$DICTIONARY_WORDS") {
  require("$SCRD/scripts/addSeeAlsoLinks.pl");
  &addSeeAlsoLinks("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");
}
else {copy("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");}
# MOD_3.xml is after addDictLinks.pl or addSeeAlsoLinks.pl

if ($MODDRV =~ /Text/) {
  my $success = 0;
  if ($addCrossRefs ne '0') {
    require("$SCRD/scripts/addCrossRefs.pl");
    $success = &addCrossRefs("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);
  }
  if (!$success) {copy("$TMPDIR/".$MOD."_3.xml", $OUTOSIS); }
}
else {copy("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);}

&normalizeRefsIds($OUTOSIS);
if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  &fitToVerseSystem($OUTOSIS, $VERSESYS);
}
&correctReferencesVSYS($OUTOSIS, $projectBible, $ConfEntryP);
# MOD.xml is after addCrossRefs.pl

# Run postprocess.(pl|xsl) if they exist
&userXSLT("$INPD/postprocess.xsl", $OUTOSIS, "$OUTOSIS.out");
copy("$OUTOSIS.out", $OUTOSIS);
unlink("$OUTOSIS.out");
if (-e "$INPD/postprocess.pl") {
  &Log("\nRunning OSIS postprocess.pl\n", 1);
  my $cmd = "$INPD/postprocess.pl " . &escfile($OUTOSIS);
  &shell($cmd);
}

# Checks occur as late as possible in the flow
&checkReferenceLinks($OUTOSIS);

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
  &runXSLT("$SCRD/scripts/xslt/glossaryNavMenu.xsl", $OUTOSIS, "$OUTOSIS.out", \%params);
  copy("$OUTOSIS.out", $OUTOSIS);
  unlink("$OUTOSIS.out");
  
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

&checkFigureLinks($OUTOSIS);
&checkIntroductionTags($OUTOSIS);
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
&runXSLT("$SCRD/scripts/xslt/prettyPrint.xsl", $OUTOSIS, "$TMPDIR/".$MOD."_PrettyPrint.xml");

&Log("\nend time: ".localtime()."\n");
