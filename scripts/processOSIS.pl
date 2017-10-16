copy("$TMPDIR/".$MOD."_0.xml", "$TMPDIR/".$MOD."_1.xml");
# MOD_0.xml is raw converter output

&writeOsisHeaderWork("$TMPDIR/".$MOD."_1.xml", $ConfEntryP);

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  require("$SCRD/scripts/toVersificationBookOrder.pl");
  &toVersificationBookOrder($VERSESYS, "$TMPDIR/".$MOD."_1.xml");
  require("$SCRD/scripts/checkUpdateIntros.pl");
  &checkUpdateIntros("$TMPDIR/".$MOD."_1.xml");
}
elsif ($MODDRV =~ /LD/) {
  require("$SCRD/scripts/processGlossary.pl");
  &aggregateRepeatedEntries("$TMPDIR/".$MOD."_1.xml");
  &writeDefaultDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml");
  &loadDictionaryWordsXML(1);
  &compareToDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml");
  &writeEntryOsisIDs("$TMPDIR/".$MOD."_1.xml");
}
&writeFootnoteIDs("$TMPDIR/".$MOD."_1.xml", $ConfEntryP);
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
# MOD.xml is after addCrossRefs.pl

# Run postprocess.(pl|xsl) if they exist
if (-e "$INPD/postprocess.xsl") {
  &Log("\nRunning OSIS postprocess.xsl\n", 1);
  my $cmd = "saxonb-xslt -xsl:" . &escfile("$INPD/postprocess.xsl") . " -s:" . &escfile($OUTOSIS) . " -o:" . &escfile("$OUTOSIS.out");
  &Log("$cmd\n");
  system($cmd);
  unlink($OUTOSIS);
  copy("$OUTOSIS.out", $OUTOSIS);
}

if (-e "$INPD/postprocess.pl") {
  &Log("\nRunning OSIS postprocess.pl\n", 1);
  my $cmd = "$INPD/postprocess.pl " . &escfile($OUTOSIS);
  &Log($cmd."\n");
  system($cmd);
}

# Checks occur as late as possible in the flow
&checkReferenceLinks($OUTOSIS);

# After checking references, if the project includes a glossary, add glossary navigational menus, and if there is a glossary div with osisRef="INT" also add intro nav menus.
my $osis = $XML_PARSER->parse_file($OUTOSIS);
my $projectGlossary = @{$XPC->findnodes('//osis:header/osis:work[child::osis:type[@type="x-glossary"]]/@osisWork', $osis)}[0];
my $projectBible = @{$XPC->findnodes('//osis:header/osis:work[child::osis:type[@type="x-bible"]]/@osisWork', $osis)}[0];
if ($projectBible && $projectGlossary && !(-e "$INPD/navigation.sfm" || -e "$INPD/".$projectGlossary->value."/navigation.sfm")) {
  # Create the Introduction menus whenever the project glossary contains a glossary wth scope == INT
  my $gloss = "$INPD/".($MODDRV =~ /Text/ ? $projectGlossary->value.'/':'')."CF_usfm2osis.txt";
  my $glossContainsINT = `grep "scope == INT" $gloss`;

  # Tell the user about the introduction nav menu feature if it's available and not being used
  if (!$glossContainsINT) {
    my $biblef = &getProjectOsisFile($projectBible->value);
    if ($biblef) {
      if (@{$XPC->findnodes('//osis:div[@type="introduction"][not(ancestor::div[@type="book" or @type="bookGroup"])]', $XML_PARSER->parse_file($biblef))}[0]) {
        my $bmod = $projectBible->value; my $gmod = $projectGlossary->value;
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

  &Log("\nRunning glossaryNavMenu.xsl to add glossary navigation menus".($glossContainsINT ? ", and introduction menus,":'')." to OSIS file.\n", 1);
  my $cmd = "saxonb-xslt -xsl:" . &escfile("$SCRD/scripts/xslt/glossaryNavMenu.xsl") . " -s:" . &escfile($OUTOSIS) . " -o:" . &escfile("$OUTOSIS.out") . ($glossContainsINT ? " osisRefIntro='INT'":'') . " 2>&1";
  &Log("$cmd\n");
  my $out = `$cmd`; $out =~ s/&#(\d+);/my $r = chr($1);/eg;
  &Log("$out\n");
  unlink($OUTOSIS);
  copy("$OUTOSIS.out", $OUTOSIS);
  
  my $css = "$INPD/".($MODDRV =~ /Text/ ? $projectGlossary->value.'/':'')."sword/css";
  if (!-e $css) {
    &Log("
WARNING: For the navigation menu to look best in SWORD, you should use 
         glossary module css. Here is how it can be done:
         1) Edit \"".$projectGlossary->value."/config.conf\" to add the config entry: \"PreferredCSSXHTML=swmodule.css\"
         2) Open or create the css file: \"$css/swmodule.css\"
         3) Add the following css: \".x-navmenu .x-prevnext-link span {font-size:3em; text-decoration:none;}\"\n");
  }
  
}

&checkFigureLinks($OUTOSIS);
&checkIntroductionTags($OUTOSIS);
&validateOSIS($OUTOSIS);

# Do a tmp Pretty Print for referencing during the conversion process
my $xml = $XML_PARSER->parse_file($OUTOSIS);
&prettyPrintOSIS($xml);
open(OUTF, ">$TMPDIR/".$MOD."_PrettyPrint.xml");
print OUTF $xml->toString();
close(OUTF);

&Log("\nend time: ".localtime()."\n");
