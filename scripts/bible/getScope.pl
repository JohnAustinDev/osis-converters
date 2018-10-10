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

sub getScope($$) {
  my $osis = shift; # can be osis file OR xml node
  my $vsys = shift;
  
  my $xml = (ref($osis) ? $osis:$XML_PARSER->parse_file($osis));
  
  my $scope = "";
  
  $vsys = ($vsys ? $vsys:&getVerseSystemOSIS($xml));
  if (!$vsys) {&ErrorBug("Could not determine versification of ".(ref($osis) ? 'osis document':$osis).".");}

  &Log("\n\nDETECTING SCOPE: Versification=$vsys\n");

  my $canonP;
  my $bookOrderP;
  my $testamentP;
  
  if (&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP)) {
    my @verses = $XPC->findnodes('//osis:verse', $xml);
    foreach my $v (@verses) {
      my $osisID = $v->findvalue('./@osisID');
      @osisID = split(/\s+/, $osisID);
      foreach my $id (@osisID) {$haveVerse{$id}++;}
    }

    # assemble the scope conf entry for this text
    my $s = "";
    my $hadLastV = 0;
    my $lastCheckedV = "";
    my $canbkFirst, $canbkLast;
    foreach my $bk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$canonP}) {
      if (!$canbkFirst) {$canbkFirst = $bk;}
      $canbkLast = $bk;
      for (my $ch=1; $ch<=@{$canonP->{$bk}}; $ch++) {
        for (my $vs=1; $vs<=$canonP->{$bk}->[$ch-1]; $vs++) {

          # record scope unit start
          if (!$hadLastV && $haveVerse{"$bk.$ch.$vs"}) {
            $s .= " $bk.$ch.$vs";          
          }
          # record scope unit end
          if ($hadLastV && !$haveVerse{"$bk.$ch.$vs"}) {
            $s .= "-$lastCheckedV";
          }
          $hadLastV = $haveVerse{"$bk.$ch.$vs"};
          $lastCheckedV = "$bk.$ch.$vs";
        }
      }
    }
    if ($hadLastV) {$s .= "-$lastCheckedV";}

    # simplify each scope segment as much as possible
    my $sep = "";
    while ($s =~ s/^ ([^\.]+)\.(\d+)\.(\d+)-([^\.]+)\.(\d+)\.(\d+)//) {
      my $b1=$1;
      my $c1=$2;
      my $v1=$3;
      my $b2=$4;
      my $c2=$5;
      my $v2=$6;
      
      my $sub = "";
      # simplify scope unit start
      if ($b2 ne $b1 || ($b2 eq $b1 && ($c2==@{$canonP->{$b2}} && $v2==$canonP->{$b2}->[$c2-1]))) {
        if ($v1 == 1) {
          if ($c1 == 1) {$sub .= "$b1";}
          else {$sub .= "$b1.$c1";}
        }
        else {$sub .= "$b1.$c1.$v1";}
      }
      elsif ($c2 != $c1) {
        if ($v1==1) {
          #if ($c1==1) {$c1 = 0;}
          $sub .= "$b1.$c1";
        }
        else {$sub .= "$b1.$c1.$v1";}
      }
      else {$sub .= "$b1.$c1.$v1";}
      
      # simplify scope unit end
      if ($b1 ne $b2 || ($b1 eq $b2 && ($c1==1 && $v1==1))) {
        if ($v2 == $canonP->{$b2}->[$c2-1]) {
          if ($c2 == @{$canonP->{$b2}}) {$sub .= "-$b2";}
          else {$sub .= "-$b2.$c2";}
        }
        else {$sub .= "-$b2.$c2.$v2";}
      }
      elsif ($c1 != $c2) {
        if ($v2 == $canonP->{$b2}->[$c2-1]) {$sub .= "-$b2.$c2";}
        else {$sub .= "-$b2.$c2.$v2";}
      }
      else {$sub .= "-$b2.$c2.$v2";}
      
      $sub =~ s/^(\w+)-(\g1)/$1/;
     
      $scope .= $sep.$sub;
      $sep = " ";
    }
    if ($s !~ /^\s*$/) {&ErrorBug("While processing scope: $s !~ /^\s*\$/\n");}
    #if ($scope eq "$canbkFirst-$canbkLast") {$scope = "";}
  }
  else {&ErrorBug("Could not check scope in OSIS file because getCanon failed.");}
  
  &Log("Scope is: $scope\n");
 
  return $scope;
}

sub recordEmptyVerses($\%) {
  my $id = shift;
  my $eP = shift;
  if ($id !~ /^([^\.]+)\.(\d+)\.(\d+)(-(\d+))?$/) {&ErrorBug("Could not parse id: $id !~ /^([^\.]+)\.(\d+)\.(\d+)(-(\d+))?\$/"); return;}
  my $bk = $1;
  my $ch = $2;
  my $v1 = $3;
  my $v2 = $5;
  if (!$v2) {$v2 = $v1;}
  for (my $v=$v1; $v<=$v2; $v++) {$eP->{"$bk.$ch.$v"}++;}
}

sub scopeToBooks($\%) {
  my $scope = shift;
  my $bookOrderP = shift;
  
  if (!$bookOrderP) {die;}
  
  my @scopes = split(/\s+/, $scope);
  my $i = 0;
  my $keep = '';
  
  my @bookList;
  foreach my $v11nbk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$bookOrderP}) {
    my $cs = @scopes[$i];
    $cs =~ s/(^|\-|\s)([^\.]+)\.[^\-]+/$1$2/g; # remove any chapter/verse parts
    my $bks =$cs;
    my $bke = $bks;
    if ($bks =~ s/\-(.*)$//) {$bke = $1;}

    if ($v11nbk =~ /^$bks$/i) {$keep = $bke;}
    if ($keep) {push(@bookList, $v11nbk);}
    if ($v11nbk =~ /^$keep$/i) {$keep = ''; $i++;}
  }
  return \@bookList;
}

1;
