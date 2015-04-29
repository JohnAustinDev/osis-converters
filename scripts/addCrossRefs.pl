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

&Log("-----------------------------------------------------\nSTARTING addCrossRefs.pl\n\n");

$Booklist = "";
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
    $Booklist .= " " . &getOsisName($1);
  }
  close(COMF);
}

if (!$Booklist || $Booklist =~ /^\s*$/) {
  $UseAllBooks = "true";
  &Log("You are including cross references for ALL books.\n");
}
else {
  $UseAllBooks = "false"; 
  &Log("You are including cross references for the following books:\n$Booklist\n");
}

########################################################################
&Log("READING OSIS FILE: \"$INPUTFILE\".\n");
use XML::LibXML;
$XPC = XML::LibXML::XPathContext->new;
$NS = "http://www.bibletechnologies.net/2003/OSIS/namespace";
$XPC->registerNs('osis', $NS);
$PARSER = XML::LibXML->new();
$OSIS = $PARSER->parse_file($INPUTFILE);

%Book;
foreach my $b ($XPC->findnodes('//osis:div[@type="book"]', $OSIS)) {
  my $bk = $b->findvalue('./@osisID');
  $Book{$bk} = $b;
}

%Verse;
my @verses = $XPC->findnodes('//osis:verse', $OSIS);
foreach my $v (@verses) {
  if ($v->hasChildNodes()) {&Log("ERROR: addCrossRefs.pl expects milestone verse tags\n"); die;}
  my $tt = 'start';
  my $id = $v->findvalue('./@sID');
  if (!$id) {
    $tt = 'end';
    $id = $v->findvalue('./@eID');
  }
  my @osisRefs = id2refs($id);
  foreach my $ref (@osisRefs) {$Verse{$ref}{$tt} = $v;}
}

########################################################################
my $CrossRefFile = (!$VERSESYS ? "KJV":$VERSESYS);
my @try = (
  "$INPD/../Cross_References/$CrossRefFile.xml",
  "$INPD/../../Cross_References/$CrossRefFile.xml",
  "$SCRD/scripts/CrossReferences/$CrossRefFile.xml",
  "$SCRD/scripts/CrossReferences/CrossRefs_$CrossRefFile.txt"
);
foreach my $t (@try) {if (-e $t) {$CrossRefFile = $t; last}}
if (! -e $CrossRefFile) {&Log("ERROR: Could not locate Cross Reference source file.\n"); die;}
my $f = $CrossRefFile; $f =~ s/^.*?([^\/]+)$/$1/;
&Log("READING CROSS REFERENCE FILE \"$f\".\n");

# XML is the prefered source type (TXT is deprecated)
if ($CrossRefFile =~ /\.xml$/) {
  $NoteXML = $PARSER->parse_file($CrossRefFile);
  my @notes = $XPC->findnodes('//osis:note', $NoteXML);
  # combine all matching notes within a verse
  my %osisRefs;
  my @matchAttribs = ('osisRef', 'type', 'subType');
  for (my $i=0; $i<@notes; $i++) {
    my $key = '';
    foreach my $a (@matchAttribs) {$key .= @notes[$i]->findvalue("./\@$a");}
    if (defined($osisRefs{$key})) {
      foreach my $ref (@notes[$i]->childNodes()) {@notes[$osisRefs{$key}]->insertAfter($ref, undef);}
      @notes[$i] = NULL;
    }
    else {$osisRefs{$key} = $i;}
  }
  foreach my $note (@notes) {
    if (ref($note) ne "XML::LibXML::Element") {next;}
    # place note in first verse of multi-verse osisRef spans
    my @refs = &id2refs($note->findvalue('./@osisRef'));
    if (@refs > 1) {
      my $osisRef = @{$XPC->findnodes('./@osisRef', $note)}[0];
      $osisRef->setValue(@refs[0]);
      my $osisID = @{$XPC->findnodes('./@osisID', $note)}[0];
      my $val = $osisID->getValue();
      $val =~ s/^[^\!]*?(?=(\!|$))//;
      $osisID->setValue(@refs[0] . $val);
    }
    @refs[0] =~ /^([^\.]+)\.(\d+)\.(\d+)$/; my $b = $1; my $c = $2; my $v = $3;
    if (&filterNote($note, $b)) {next;}
    if (!$Verse{"$b.$c.$v"}) {&Log("ERROR: $b.$c.$v: Target verse not found.\n"); next;}
    &insertNote($note, \%{$Verse{"$b.$c.$v"}});
  }
}
else {
  copy($CrossRefFile, "$CrossRefFile.tmp");
  &normalizeNewLines("$crossRefs.tmp");
  open(NFLE, "<:encoding(UTF-8)", "$CrossRefFile.tmp") or die "Could not open cross reference file \"$CrossRefFile.tmp\".\n";
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

    if (&filterNote(\$note, $b)) {next;}
    
    my $osisID = "$b.$c.$v!crossReference." . ($type eq "para" ? "p":"n");
    my $attribs = "osisRef=\"$b.$c.$v\" osisID=\"$osisID" . ++$REFNUM{$osisID} . "\"";
    $note =~ s/(type="crossReference")/$1 $attribs/;
    
    if ($note !~ /^<note type="crossReference" osisRef="[^\.]+\.\d+\.\d+" osisID="[^\.]+\.\d+\.\d+\!crossReference\.(n|p)\d+"( subType="x-parallel-passage")?>(<reference osisRef="([^\.]+\.\d+(\.\d+)?-?)+"><\/reference>)+<\/note>$/) {
      &Log("ERROR: Bad cross reference: \"$note\"\n"); next;
    }

    if (!$Verse{"$b.$c.$v"}) {&Log("ERROR: $type:$b.$c.$v: Target not found.\n"); next;}

    &insertNote(@{$PARSER->parse_balanced_chunk($note)->childNodes}[0], \%{$Verse{"$b.$c.$v"}});
  }
  close (NFLE);
  unlink("$CrossRefFile.tmp");
}

########################################################################
&Log("WRITING NEW OSIS FILE: \"$OUTPUTFILE\".\n");
open(OUTF, ">$OUTPUTFILE");
print OUTF $OSIS->toString();
close(OUTF);

&Log("REPORT: Placed $NumNotes cross-reference notes.\n");

1;

########################################################################
########################################################################
sub insertNote($\$) {
  my $noteP = shift;
  my $verseP = shift;
  
  # add non-localized readable reference text (required by some front ends)
  my @refs = $XPC->findnodes("osis:reference", $noteP);
  for (my $i=0; $i<@refs; $i++) {
    # target module needs to be used here, but this will break xulsword (as of May 2014) so is postponed!
    #my $osisRef = @{$XPC->findnodes('./@osisRef', @refs[$i])}[0];
    #my $new = $osisRef->getValue();
    #$new =~ s/^Bible:/$MOD:/;
    #$osisRef->setValue($new);
    @refs[$i]->insertAfter(XML::LibXML::Text->new(sprintf("%i%s", $i+1, ($i==@refs-1 ? '':','))), undef);
  }
  
  # make markup pretty
  my $strip = $noteP->toString();
  $strip =~ s/[\n\s]+(<[^>]*>)/$1/g;
  $noteP = @{$PARSER->parse_balanced_chunk($strip)->childNodes}[0];
  
  # insert in the right place
  if ($noteP->toString() =~ /x-parallel-passage/) {
    my $nt = @{$XPC->findnodes('following::text()[1]', $verseP->{'start'})}[0];
    my $ns = "";
    while ($nt) {
      if (my $title = @{$XPC->findnodes('ancestor::osis:title', $nt)}[0] || $nt =~ /^\s*$/) {$nt = @{$XPC->findnodes('following::text()[1]', $nt)}[0];}
      elsif (my $note = @{$XPC->findnodes('ancestor::osis:note', $nt)}[0]) {$note->parentNode->insertAfter($noteP, $note); last;}
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $nt)}[0]) {$reference->parentNode->insertBefore($noteP, $reference); last;}
      else {$nt->parentNode->insertBefore($noteP, $nt); last;}
    }
    if ($nt) {$NumNotes++;}
    else {&Log("ERROR: Could not place para note \"".$noteP->toString()."\"\n");}
  }
  else {
    my $pt = @{$XPC->findnodes('preceding::text()[1]', $verseP->{'end'})}[0];
    while ($pt) {
      if (my $title = @{$XPC->findnodes('ancestor::osis:title', $pt)}[0] || $pt =~ /^\s*$/) {$pt = @{$XPC->findnodes('preceding::text()[1]', $pt)}[0];}
      elsif (my $note = @{$XPC->findnodes('ancestor::osis:note', $pt)}[0]) {$note->parentNode->insertAfter($noteP, $note); last;}
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $pt)}[0]) {$reference->parentNode->insertAfter($noteP, $reference); last;}
      else {
        my $punc = '';
        my $txt = $pt->nodeValue();
        if ($txt =~ s/([\.\?\s]+)$//) {
          $punc = $1;
          $pt->setData($txt);
        }
        $pt->parentNode->insertAfter($noteP, $pt);
        if ($punc) {$noteP->parentNode->insertAfter(XML::LibXML::Text->new($punc), $noteP);}
        last;
      }
    }
    if ($pt) {$NumNotes++;}
    else {&Log("ERROR: Could not place norm note \"".$noteP->toString()."\"\n");}
  }
}

sub filterNote($$) {
  my $nP = shift;
  my $b = shift;

  if (!defined($Book{$b})) {return 1;} # Skip if this note's book is not in the OSIS file
  
  if (($UseAllBooks ne "true") && ($Booklist !~ /\b$b\b/)) {return 1;}
  
  if ($RemoveIfMissingTarget eq "true") {
    my $tmp = (ref($nP) eq "XML::LibXML::Element" ? $nP->toString():$$nP);
    while ($tmp =~ s/(<reference[^>]*osisRef=")(([^\.]+)\.[^"]+)("[^>]*>.*?<\/reference>)//) {
      my $p1 = $1;
      my $p2 = $2;
      my $bk = $3;
      my $p3 = $4;
      if ($Booklist =~ /\b$bk\b/) {next;}
      if (ref($nP) eq "XML::LibXML::Element") {
        my $rem = @{$XPC->findnodes("reference[\@osisRef='$p2']", $nP)}[0];
        $rem->unbindNode();
      }
      else {if ($$nP !~ s/\Q$p1$p2$p3\E//) {&Log("ERROR: Problem filtering note $$np\n");}}
    }
  }
  
  return 0;
}
