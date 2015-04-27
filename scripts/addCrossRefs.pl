# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   REMOVE_REFS_TO_MISSING_BOOKS - If set to "true" then cross 
#       references targetting books which are not included in the 
#       OSIS file will NOT be placed in the OSIS file.
#   SFM book name abbreviations (one per line) are to be listed for
#   those books which should have cross-references inserted into them.
#   If no books are listed, then cross-references will be added to 
#   ALL books in the OSIS file.

$NumNotes = 0;   
$crossRefs = "$SCRD/scripts/CrossReferences/CrossRefs_";
if (!$VERSESYS || $VERSESYS eq "KJV") {$crossRefs .= "KJV.txt";}
else {$crossRefs .= "$VERSESYS.txt";}
if (!-e $crossRefs) {
  &Log("ERROR: Missing cross reference file for \"$VERSESYS\": $crossRefs.\n");
  die;
}

&Log("-----------------------------------------------------\nSTARTING addCrossRefs.pl\n\n");

my $booklist = "";
if (-e $COMMANDFILE) {
  &Log("READING COMMAND FILE \"$COMMANDFILE\"\n");
  &normalizeNewLines($COMMANDFILE);
  &removeRevisionFromCF($COMMANDFILE);
  open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) or die "Could not open command file \"$COMMANDFILE\".\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    if ($_ =~ /^\#/) {next;}
    elsif ($_ =~ /REMOVE_REFS_TO_MISSING_BOOKS:(\s*(.*?)\s*)?$/) {if ($1) {$RemoveIfMissingTarget = $2; next;}}
    elsif ($_ =~ /:/) {next;}
    elsif ($_ =~ /\/(\w+)\.[^\/]+$/) {}
    elsif ($_ =~/^\s*(\w+)\s*$/) {}
    else {next;}
    $booklist .= " " . &getOsisName($1);
  }
  close(COMF);
}

if (!$booklist || $booklist =~ /^\s*$/) {
  $useAllBooks = "true";
  &Log("You are including cross references for ALL books.\n");
}
else {
  $useAllBooks = "false"; 
  &Log("You are including cross references for the following books:\n$booklist\n");
}

&Log("READING OSIS FILE: \"$INPUTFILE\".\n");
use XML::LibXML;
my $xpc = XML::LibXML::XPathContext->new;
my $NS = "http://www.bibletechnologies.net/2003/OSIS/namespace";
$xpc->registerNs('x', $NS);
my $parser = XML::LibXML->new();
my $xml = $parser->parse_file($INPUTFILE);

my %book;
foreach my $b ($xpc->findnodes('//x:div[@type="book"]', $xml)) {
  my $bk = $b->findvalue('./@osisID');
  $book{$bk} = $b;
}

my %verse;
my @verses = $xpc->findnodes('//x:verse', $xml);
foreach my $v (@verses) {
  if ($v->hasChildNodes()) {&Log("ERROR: addCrossRefs.pl expects milestone verse tags\n"); die;}
  my $tt = 'start';
  my $refs = $v->findvalue('./@sID');
  if (!$refs) {
    $tt = 'end';
    $refs = $v->findvalue('./@eID');
  }
  my @osisRefs;
  if ($refs =~ /^([^\.]+\.\d+)\.(\d+)-(\d+)$/) {
    my $bc = $1;
    my $v1 = $2;
    my $v2 = $3;
    for (my $v=$v1; $v<=$v2; $v++) {push(@osisRefs, "$bc.$v");}
  }
  else {@osisRefs = split(/\s+/, $refs);}
  foreach my $ref (@osisRefs) {$verse{$ref}{$tt} = $v;}
}

&Log("READING CROSS REFERENCE FILE \"$crossRefs\".\n");
copy($crossRefs, "$crossRefs.tmp");
&normalizeNewLines("$crossRefs.tmp");
open(NFLE, "<:encoding(UTF-8)", "$crossRefs.tmp") or die "Could not open cross reference file \"$crossRefs.tmp\".\n";
while (<NFLE>) {
  $line++; #if (!($line%100)) {print "$line\n";}
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ !~ /^(norm:|para:)?([^\.]+)\.(\d+)\.(\d+):\s*(<note .*?<\/note>)\s*$/) {&Log("WARNING: Skipping unrecognized line, $line: $_"); next;}
  my $type = $1;
  my $b = $2;
  my $c = $3;
  my $v = $4;
  my $note = $5;
  chop($type);

  if (!defined($book{$b})) {next;} # Skip if this note's book is not in the OSIS file
  
  if (($useAllBooks ne "true") && ($booklist !~ /(^|\s+)$b(\s+|$)/)) {next;}
  
  my $tmp = $note;
  if ($RemoveIfMissingTarget eq "true") {
    while ($tmp =~ s/<reference osisRef="(([^\.]+)\.[^"]+)"><\/reference>//) {
      my $osisRef = $1;
      my $bk = $2;
      if ($booklist =~ /$bk/) {next;}
      $note =~ s/<reference osisRef="osisRef"><\/reference>//;
    }
  }
  
  my $osisID = "$b.$c.$v!crossReference." . ($type eq "para" ? "p":"n");
  my $attribs = "osisRef=\"$b.$c.$v\" osisID=\"$osisID" . ++$REFNUM{$osisID} . "\"";
  $note =~ s/(type="crossReference")/$1 $attribs/;

  # Add reference text: 1, 2, 3 etc.
  my $i = 1;
  my $sp = ",";
  while($note =~ s/(<reference[^>]*>)(<\/reference>)/$1$i$sp$2/i) {$i++;}
  $note =~ s/^(.*)$sp(<\/reference>)(.*?)$/$1$2$3/i;
  
  # target module needs to be used here, but this will break xulsword (as of May 2014) so is postponed!
  #my $bible = ($MOD ? $MOD:"Bible");
  #$note =~ s/(<reference[^>]*osisRef=")/$1$bible:/g;
  
  if ($note !~ /^<note type="crossReference" osisRef="[^\.]+\.\d+\.\d+" osisID="[^\.]+\.\d+\.\d+\!crossReference\.(n|p)\d+"( subType="x-parallel-passage")?>(<reference osisRef="([^\.]+\.\d+(\.\d+)?-?)+">\d+,?<\/reference>)+<\/note>$/) {
    &Log("ERROR: Bad cross reference: \"$note\"\n"); next;
  }

  if (!$verse{"$b.$c.$v"}) {&Log("WARNING: Target not found, trying v+1 for $type:$b.$c.$v\n"); $v++;}
  if (!$verse{"$b.$c.$v"}) {&Log("WARNING: Target+1 not found, trying v+2 for $type:$b.$c.$v\n"); $v++;}
  if (!$verse{"$b.$c.$v"}) {&Log("ERROR: $type:$b.$c.$v: Target not found.\n"); next;}

  my $noteNode = @{$parser->parse_balanced_chunk($note)->childNodes}[0];
  if ($type eq "para") {
    my $nt = @{$xpc->findnodes('following::text()[1]', $verse{"$b.$c.$v"}{'start'})}[0];
    my $ns = "";
    while ($nt) {
      if (my $title = @{$xpc->findnodes('ancestor::x:title', $nt)}[0] || $nt =~ /^\s*$/) {$nt = @{$xpc->findnodes('following::text()[1]', $nt)}[0];}
      elsif (my $note = @{$xpc->findnodes('ancestor::x:note', $nt)}[0]) {$note->parentNode->insertAfter($noteNode, $note); last;}
      elsif (my $reference = @{$xpc->findnodes('ancestor::x:reference', $nt)}[0]) {$reference->parentNode->insertBefore($noteNode, $reference); last;}
      else {$nt->parentNode->insertBefore($noteNode, $nt); last;}
    }
    if ($nt) {$NumNotes++;}
    else {&Log("ERROR: Could not place para note \"$b.$c.$v\"\n");}
  }
  else {
    my $pt = @{$xpc->findnodes('preceding::text()[1]', $verse{"$b.$c.$v"}{'end'})}[0];
    while ($pt) {
      if (my $title = @{$xpc->findnodes('ancestor::x:title', $pt)}[0] || $pt =~ /^\s*$/) {$pt = @{$xpc->findnodes('preceding::text()[1]', $pt)}[0];}
      elsif (my $note = @{$xpc->findnodes('ancestor::x:note', $pt)}[0]) {$note->parentNode->insertAfter($noteNode, $note); last;}
      elsif (my $reference = @{$xpc->findnodes('ancestor::x:reference', $pt)}[0]) {$reference->parentNode->insertAfter($noteNode, $reference); last;}
      else {
        my $punc = '';
        my $txt = $pt->nodeValue();
        if ($txt =~ s/([\.\?\s]+)$//) {
          $punc = $1;
          $pt->setData($txt);
        }
        $pt->parentNode->insertAfter($noteNode, $pt);
        if ($punc) {$noteNode->parentNode->insertAfter(XML::LibXML::Text->new($punc), $noteNode);}
        last;
      }
    }
    if ($pt) {$NumNotes++;}
    else {&Log("ERROR: Could not place norm note \"$b.$c.$v\"\n");}
  }
}
close (NFLE);
unlink("$crossRefs.tmp");

&Log("WRITING OSIS FILE: \"$OUTPUTFILE\".\n");
open(OUTF, ">$OUTPUTFILE");
print OUTF $xml->toString();
close(OUTF);

&Log("REPORT: Placed $NumNotes cross-reference notes.\n");

1;
