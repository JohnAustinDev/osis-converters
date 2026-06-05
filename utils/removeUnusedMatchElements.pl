#!/usr/bin/perl

@ARGV[1] = 'none'; # no log file, just print to screen
use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/lib/common/bootstrap.pm"; &init(shift, shift);

my $dwfPath = "$INPD/CF_addDictLinks.xml";
my $alog = "$MOD_OUTDIR/LOG_sfm2osis.txt";

if (!open(OUT, $READLAYER, $alog)) {
  &Error(
    "The log file $alog is required to run this script.",
    "Rerun sfm2osis on $MOD to create a new log file, and then rerun this script.",
    1
  );
}
if (! -e "$dwfPath") {
  &Error(
    "The CF_addDictLinks.xml file '$dwfPath' is required to run this script.",
    "The project must have a CF_addDictLinks.xml file.",
    1
  );
}

&Note("Reading log file: $alog");
my ($expected, $state, %unusedMatches);
while(<OUT>) {
  if ($_ =~ /^\S+ REPORT: Unused match elements in CF_addDictLinks\.xml: \((\d+) instances\)/) {
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
  my $osisRef = $1; my $matchText = $2;
  if (!$unusedMatches{$osisRef}) {$unusedMatches{$osisRef} = ();}
  push(@{$unusedMatches{$osisRef}}, $matchText);
}
close(OUT);
if (!%unusedMatches) {
  &Log("\nNo unused match elements were found removal. Exiting...\n");
  exit;
}
&Note("Removing " . scalar(keys %unusedMatches) . " unused match elements from $dwfPath.");

&Note("Modifying: $dwfPath\n");
my $count = 0;
my $xml = $XML_PARSER->parse_file($dwfPath);
my @matchElements;
foreach my $m (@{$XPC->findnodes("//dw:match", $xml)}) {
  my %mh;
  $mh{'match'} = $m;
  $mh{'entry'} = @{$XPC->findnodes("./ancestor::dw:entry[1]", $m)}[0];
  push(@matchElements, \%mh);
}
foreach my $osisRef (sort keys %unusedMatches) {
  # Because of chars like ' xpath had trouble finding matchText, so compare
  # strings:
  foreach my $matchText (@{$unusedMatches{$osisRef}}) {
    my $ingoingCount = $count;
    foreach my $hP (@matchElements) {
      if (
        $hP->{'unbound'} ||
        ($hP->{'match'}->toString() ne $matchText) ||
        ($hP->{'entry'}->getAttribute('osisRef') ne $osisRef)
      ) {
        next;
      }
      $hP->{'match'}->unbindNode();
      $hP->{'unbound'}++;
      $count++;
    }
    if ($ingoingCount == $count) {
      &Error("Match element '$matchText' could not be located in $dwfPath.", $msg, 1);
    }
  }
}
if (!$count) {
  &Error("Did not locate any unused match elements.", $msg, 1);
}
elsif ($count != $expected) {
  &Error("Did not find $expected unused match elements. Instead found $count", $msg, 1);
}
else {
  &Note("All $expected unused match elements were located.");
}

move($dwfPath, "$dwfPath.old");

&writeXMLFile($xml, $dwfPath);

&Report("Removed $count unused match elements from $dwfPath.");

1;
