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

# Do a tmp Pretty Print for referencing during the conversion process
my $xml = $XML_PARSER->parse_file($OUTOSIS);
&prettyPrintOSIS($xml);
open(OUTF, ">$TMPDIR/".$MOD."_PrettyPrint.xml");
print OUTF $xml->toString();
close(OUTF);

&checkFigureLinks($OUTOSIS);
&checkReferenceLinks($OUTOSIS);
&checkIntroductionTags($OUTOSIS);
&validateOSIS($OUTOSIS);
&Log("\nend time: ".localtime()."\n");
