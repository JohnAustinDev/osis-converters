&updateOsisHeader("$TMPDIR/".$MOD."_0.xml");

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  require("$SCRD/scripts/toVersificationBookOrder.pl");
  &toVersificationBookOrder($VERSESYS, "$TMPDIR/".$MOD."_0.xml");
  require("$SCRD/scripts/checkUpdateIntros.pl");
  &checkUpdateIntros("$TMPDIR/".$MOD."_0.xml");
}
# MOD_0.xml is raw converter output (with books/intros re-ordered and header/intro-tags updated)

# pretty print output of OSIS converter
my $xml = $XML_PARSER->parse_file("$TMPDIR/".$MOD."_0.xml");
&prettyPrintOSIS($xml);
open(OUTF, ">$TMPDIR/".$MOD."_1.xml");
print OUTF $xml->toString();
close(OUTF);

if ($MODDRV =~ /LD/) {
  require("$SCRD/scripts/processGlossary.pl");
  &aggregateRepeatedEntries("$TMPDIR/".$MOD."_1.xml");
  &writeDefaultDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml", "$OUTDIR/DictionaryWords_autogen.xml");
  &loadDictionaryWordsXML("$OUTDIR/DictionaryWords_autogen.xml");
  &compareToDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml");
}
# MOD_1.xml is PrettyPrint, and glossaries have been aggregated

if ($addScripRefLinks ne '0' && -e "$INPD/CF_addScripRefLinks.txt") {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");
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

&checkDictReferences($OUTOSIS);
&checkIntroductionTags($OUTOSIS);
&validateOSIS($OUTOSIS);
