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

use strict;

our ($XPC, $XML_PARSER, %OSIS_ABBR);

# Return the scope of an OSIS file. The '-' continuation operator will
# be used when possible to shorten the scope length, but it can only be
# used (or interpereted) knowing $vsys. For verses outside $vsys, the 
# OSIS book abbreviation will be appended to the scope in 
# defaultOsisIndex() order.
sub getScope {
  my $osis = shift; # can be osis file OR xml node
  my $vsys = shift;
  
  my $xml = (ref($osis) ? $osis:$XML_PARSER->parse_file($osis));
  my $osisf = (ref($osis) ? 'xml document node':'osis file');
  
  my $scope = "";
  
  $vsys = ($vsys ? $vsys:&getVerseSystemOSIS($xml));
  if (!$vsys) {
    &ErrorBug("Could not determine versification of $osisf.", 1);
    return;
  }

  &Log("\n\nDETECTING SCOPE: Versification=$vsys\n");

  my %ids;
  foreach my $bk ($XPC->findnodes('//osis:div[@type="book"][@osisID]', $xml)) {
    foreach my $vs ($XPC->findnodes('descendant::osis:verse[@osisID]', $bk)) {
      foreach my $id (split(/\s+/, $vs->getAttribute('osisID'))) {
        $ids{$id}++;
      }
    }
  }
  
  $scope = &versesToScope(\%ids, $vsys);

  &Log("Scope is: $scope\n");
 
  return $scope;
}

# Return a scope value compiled from a hash of verse osisIDs. Book 
# osisIDs of non-verse-system books may also be included in the hash
# to be appended to the scope (other book osisIDs are ignored).
sub versesToScope {
  my $versesP = shift;
  my $vsys = shift;
    
  my $canonP; my $bookOrderP; my $testamentP;
  &getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP);
  
  my $scope = '';

  # assemble the scope conf entry for this text
  my $s = "";
  my $hadLastV = 0;
  my $lastCheckedV = "";
  my ($canbkFirst, $canbkLast);
  foreach my $bk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$canonP}) {
    if (!$canbkFirst) {$canbkFirst = $bk;}
    $canbkLast = $bk;
    for (my $ch=1; $ch<=@{$canonP->{$bk}}; $ch++) {
      for (my $vs=1; $vs<=$canonP->{$bk}->[$ch-1]; $vs++) {

        # record scope unit start
        if (!$hadLastV && $versesP->{"$bk.$ch.$vs"}) {
          $s .= " $bk.$ch.$vs";          
        }
        # record scope unit end
        if ($hadLastV && !$versesP->{"$bk.$ch.$vs"}) {
          $s .= "-$lastCheckedV";
        }
        $hadLastV = $versesP->{"$bk.$ch.$vs"};
        $lastCheckedV = "$bk.$ch.$vs";
        delete($versesP->{"$bk.$ch.$vs"});
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
  my @scopes = ( $scope );
  
  # Now include any other OSIS books outside of the verse system
  my %other;
  foreach (keys %{$versesP}) {
    s/^([^\.]+)\..*?$/$1/; 
    if (!defined($canonP->{$_}) && defined($OSIS_ABBR{$_})) {
      $other{$_}++;
    } 
  }
  foreach (sort { &defaultOsisIndex($a) <=> &defaultOsisIndex($b) } 
           keys %other) {push(@scopes, $_);}
 
  return join(' ', @scopes);
}

sub recordEmptyVerses {
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

# Convert a scope to an array of OSIS book abbreviations. The order of
# books in the list is defaultOsisIndex order. 
sub scopeToBooks {
  my $scope = shift;
  my $vsys = shift;
  
  if (!$vsys) {
    &ErrorBug("Unknown vsys '$vsys' in scopeToBooks", 1);
    return;
  }
  
  my $bookOrderP; &getCanon($vsys, undef, \$bookOrderP, undef);
  
  my @scopes = split(/[\s_]+/, $scope);
  foreach (@scopes) { s/(?<=\w)[\.\d]+//g; } # keep only the book parts
  
  my %books;
  foreach my $s (@scopes) {
    if ($s !~ /^(.*?)\-(.*)$/) {$books{$s}++; next;}
    my $bks = $1; my $bke = $2;
    $books{$bks}++; $books{$bke}++;
    my $continue = 0;
    foreach my $v11nbk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$bookOrderP}) {
      if ($v11nbk eq $bks) {$continue++;}
      if ($continue) {$books{$v11nbk}++;}
      if ($v11nbk eq $bke) {$continue = 0;}
    }
  }
  
  my @bookList = (sort { &defaultOsisIndex($a) <=> &defaultOsisIndex($b) } keys %books);
  
  return \@bookList;
}

# Returns 1 if $book is included in $scope, 0 otherwise.
sub bookInScope {
  my $book = shift;
  my $scope = shift;
  my $vsys = shift;
  
  foreach (@{&scopeToBooks($scope, $vsys)}) {
    if ($_ eq $book) {return 1;}
  }
  
  return 0;
}

# Return a scope from an array pointer to OSIS book names
sub booksToScope {
  my $booksAP = shift;
  my $vsys = shift;
  
  if (!$vsys) {
    &ErrorBug("Unknown vsys '$vsys' in booksToScope", 1);
    return;
  }
  
  my $canonP; my $bookOrderP; my $testamentP;
  &getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP);
  
  my %verses;
  foreach my $bk (@{$booksAP}) {
    if (!ref($canonP->{$bk})) {
      # NOTE: a book as key will only work for books outside of $vsys 
      if ($OSIS_ABBR{$bk}) {$verses{$bk}++;}
      else {&Error("booksToScope is dropping unrecognized book $bk.");}
      next;
    }
    for (my $ch=1; $ch<=@{$canonP->{$bk}}; $ch++) {
      for (my $vs=1; $vs<=$canonP->{$bk}[$ch-1]; $vs++) {
        $verses{"$bk.$ch.$vs"}++;
      }
    }
  }
  
  return &versesToScope(\%verses, $vsys);
}

1;
