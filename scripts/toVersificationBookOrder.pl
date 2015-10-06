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

sub toVersificationBookOrder($$) {
  my $vsys = shift;
  my $osis = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nOrdering books in \"$osis\" according to versification = $vsys\n");

  my %canon;
  my %bookOrder;
  my %testament;
  
  if (!&getCanon($vsys, \%canon, \%bookOrder, \%testament)) {
    &Log("ERROR: Not re-ordering books in OSIS file!\n");
    return;
  }
  
  my $xml = $XML_PARSER->parse_file($osis);

  # remove all books
  my @books = @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bk (@books) {
    $bk = $bk->parentNode()->removeChild($bk);
  }
  
  # remove bookGroups (if any)
  my $bookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
  foreach my $bookGroup (@bookGroups) {$bookGroup->parentNode()->removeChild($bookGroup);}
  
  # create empty bookGroups
  my @bookGroups;
  push(@bookGroups, XML::LibXML::Element->new("div"));
  push(@bookGroups, @bookGroups[0]->cloneNode());
  foreach my $bookGroup (@bookGroups) {$bookGroup->setAttribute('type', 'bookGroup');}
    
  # place all books back in canon order
  foreach my $v11nbk (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %bookOrder) {
    foreach my $bk (@books) {
      if (!$bk || $bk->findvalue('./@osisID') ne $v11nbk) {next;}
      my $i = ($testament{$v11nbk} eq 'OT' ? 0:1);
      @bookGroups[$i]->appendChild($bk);
      $bk = '';
      last;
    }
  }
  
  foreach my $bk (@books) {
    if ($bk ne '') {&Log("ERROR: Book \"$bk\" not found in $vsys Canon\n");}
  }
  
  my $osisText = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  foreach my $bookGroup (@bookGroups) {$osisText->appendChild($bookGroup);}
  
  # Don't check that all books/chapters/verses are included in this 
  # OSIS file, but DO insure that all verses are in sequential order 
  # without any skipping (required by GoBible Creator).
  my @verses = $XPC->findnodes('//osis:verse[@osisID]', $xml);
  my $lastbkch = '';
  my $vcounter;
  foreach my $verse (@verses) {
    my $insertBefore = 0;
    my $osisID = $verse->getAttribute('osisID');
    if ($osisID !~ /^([^\.]+\.\d+)\.(\d+)/) {&Log("ERROR: Can't read vfirst \"$v\"\n");}
    my $bkch = $1;
    my $vfirst = (1*$2);
    if ($bkch ne $lastbkch) {$vcounter = 1;}
    $lastbkch = $bkch;
    foreach my $v (split(/\s+/, $osisID)) {
      if ($v !~ /^\Q$bkch\E\.(\d+)(\-(\d+))?$/) {&Log("ERROR: Can't read v \"$v\" in \"$osisID\"\n");}
      my $vv1 = (1*$1);
      my $vv2 = ($3 ? (1*$3):$vv1);
      for (my $vv = $vv1; $vv <= $vv2; $vv++) {
        if ($vcounter > $vv) {&Log("ERROR: Verse number goes backwards \"$osisID\"\n");}
        while ($vcounter < $vv) {
          $insertBefore++; $vcounter++;
        }
        $vcounter++;
      }
    }
    while ($insertBefore--) {
      my $r = $bkch.'.'.($vfirst-$insertBefore-1);
      &Log("WARNING: Inserting empty verse: \"$r\". Check if the previous verse element\nholds multiple verses, and if so, fix the USFM \\v tag using EVAL_REGEX.\n");
      my $empty = $XML_PARSER->parse_balanced_chunk("<verse osisID=\"$r\" sID=\"$r\"/>.<verse eID=\"$r\"/>\n");
      $verse->parentNode->insertBefore($empty, $verse);
    }
  }
  
  my $t = $xml->toString();
  
  # removed books left a \n dangling, so remove it too
  $t =~ s/\n+/\n/gm;
  
  open(OUTF, ">$osis");
  print OUTF $t;
  close(OUTF);
}
1;
