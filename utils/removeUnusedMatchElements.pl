#!/usr/bin/perl

@ARGV[1] = 'none'; # no log file, just print to screen
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/scripts/bootstrap.pl";

$dwfPath = "$INPD/$DICTIONARY_WORDS";

$alog = "$MOD_OUTDIR/OUT_sfm2osis_$MOD.txt";
$msg = "Rerun sfm2osis.pl on $MOD to create a new log file, and then rerun this script on $MOD.";
if (!open(OUT, "<:encoding(UTF-8)", $alog)) {
  &Error("The log file $alog is required to run this script.", $msg, 1);
}

&Note("Reading log file:\n$alog");
while(<OUT>) {
  if ($_ =~ /^\S+ REPORT: Unused match elements in DictionaryWords\.xml: \((\d+) instances\)/) {
    $expected = $1;
    $state = 1;
    next;
  }
  if (!$state) {next;}
  if ($_ !~ /^(.*?)\s+(<match[^>]*>.*?<\/match>)\s*$/) {
    if ($state == 2) {$state = 0;}
    next;
  }
  $state = 2;
  my $osisRef = $1; my $m = $2;
  $osisRef = "$DICTMOD:$osisRef";
  if (!$unusedMatches{$osisRef}) {$unusedMatches{$osisRef} = ();}
  push(@{$unusedMatches{$osisRef}}, $m);
}
close(OUT);
if (!%unusedMatches) {&Log("\nThere are no unused match elements to remove. Exiting...\n"); exit;}

&Note("Modifying DictionaryWords.xml:\n$dwfPath\n");
$count = 0;
$xml = $XML_PARSER->parse_file($dwfPath);
@matchElements = $XPC->findnodes("//dw:match", $xml);
foreach my $osisRef (keys %unusedMatches) {
  # Because of chars like ' xpath had trouble finding unusedMatch, but this munge does it:
  foreach $unusedMatch (@{$unusedMatches{$osisRef}}) {
    my $ingoingCount = $count;
    foreach $m (@matchElements) {
      if ($m eq 'unbound' || $m->toString() ne $unusedMatch) {next;}
      my $entry = @{$XPC->findnodes("./ancestor::dw:entry[1]", $m)}[0];
      if ($entry->getAttribute('osisRef') ne $osisRef) {next;}
      $m->unbindNode(); $count++; $m = 'unbound';
    }
    if ($ingoingCount == $count) {
      &Error("Match element \"$unusedMatch\" could not be located in DictionaryWords.xml.", $msg, 1);
    }
  }
}
if (!$count) {&Error("Did not locate any unused match elements.", $msg, 1);}
elsif ($count != $expected) {&Error("Did not find $expected unused match elements. Instead found $count", $msg, 1);}
else {&Note("All $expected unused match elements were located.");}

move($dwfPath, "$dwfPath.old");

&writeXMLFile($xml, $dwfPath);

&Report("Removed $count unused match elements from $dwfPath.");

1;
