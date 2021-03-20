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

our ($XPC, $XML_PARSER, %OSIS_ABBR, @VERSE_SYSTEMS, $MOD_OUTDIR, 
    $TMPDIR, $WRITELAYER);

# Return the scope of the entire contents of an OSIS file. The '-' 
# continuation operator will be used to shorten the scope string length 
# (so it is only possible to interperet the resulting scope string using 
# the SWORD verse system of $osis). That verse system will be written to
# $vsysP pointer if provided. By default, the returned scope will 
# describe each and every verse present in $osis, except for any verses 
# which lie outside of $vsys (these cannot use '-' continuation and 
# would always result in unacceptably long scope strings). So for verses 
# outside $vsys, only their OSIS book abbreviation is appended to the 
# scope string, in defaultOsisIndex() order. But if $bookScope is set, 
# the scope string lists just the books contained in $osis (regardless 
# of which chapters/verses are contained in those books).
sub getScopeXML {
  my $osis = shift; # can be osis file OR xml node
  my $bookScope = shift;
  my $vsysP = shift;
  
  my $xml = (ref($osis) ? $osis : $XML_PARSER->parse_file($osis));
  
  # Normally getOsisVersification reads the osis header to find the
  # vsys, but before the header is written, $vsysP can be used to
  # supply the vsys.
  my $vsys = ( ref($vsysP) && &checkVerseSystemName($$vsysP) ? 
               $$vsysP : &getOsisVersification($xml) );
  if (!$vsys) {
    my $osisf = (ref($osis) ? 'xml document node':'osis file');
    &ErrorBug("Could not determine versification of $osisf.", 1);
    return;
  }
  if (ref($vsysP)) {$$vsysP = $vsys;}

  &Log("\n\nDETECTING SCOPE: Versification=$vsys\n");
  
  my $scope;
  
  if ($bookScope) {
    return &booksToScope(
      [ map( $_->value, 
             $XPC->findnodes('//osis:div[@type="book"]/@osisID', $xml)
      )], $vsys);
  }

  my %ids;
  foreach my $bk ($XPC->findnodes(
      '//osis:div[@type="book"][@osisID]', $xml)) {
    foreach my $vs ($XPC->findnodes(
        'descendant::osis:verse[@osisID]', $bk)) {
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
  &swordVsys($vsys, \$canonP, \$bookOrderP, \$testamentP);
  
  my $scope = '';

  # assemble the scope conf entry for this text
  my $s = "";
  my $hadLastV = 0;
  my $lastCheckedV = "";
  my ($canbkFirst, $canbkLast);
  foreach my $bk ( sort { $bookOrderP->{$a} <=> $bookOrderP->{$b} } 
                   keys %{$canonP} ) {
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
    if ($b2 ne $b1 || ( $b2 eq $b1 && 
                        $c2 == @{$canonP->{$b2}} && 
                        $v2 == $canonP->{$b2}->[$c2-1] )) {
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
  if ($s !~ /^\s*$/) {
    &ErrorBug("While processing scope: $s !~ /^\s*\$/\n");
  }
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

  if ($id !~ /^([^\.]+)\.(\d+)\.(\d+)(-(\d+))?$/) {
    &ErrorBug(
"Could not parse id: $id !~ /^([^\.]+)\.(\d+)\.(\d+)(-(\d+))?\$/");
    return;
  }
  my $bk = $1;
  my $ch = $2;
  my $v1 = $3;
  my $v2 = $5;
  if (!$v2) {$v2 = $v1;}
  for (my $v=$v1; $v<=$v2; $v++) {$eP->{"$bk.$ch.$v"}++;}
}

# Convert a scope to an array of OSIS book abbreviations. The order of
# books in the returned list is defaultOsisIndex order. 
sub scopeToBooks {
  my $scope = shift;
  my $vsys = shift;
  
  if (!$vsys) {
    &ErrorBug("Unknown vsys '$vsys' in scopeToBooks", 1);
    return;
  }
  
  my $bookOrderP; &swordVsys($vsys, undef, \$bookOrderP, undef);
  
  my @scopes = split(/[\s_]+/, $scope);
  foreach (@scopes) { s/(?<=\w)[\.\d]+//g; } # keep only the book parts
  
  my %books;
  foreach my $s (@scopes) {
    if ($s !~ /^(.*?)\-(.*)$/) {$books{$s}++; next;}
    my $bks = $1; my $bke = $2;
    $books{$bks}++; $books{$bke}++;
    my $continue = 0;
    foreach my $v11nbk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} 
                        keys %{$bookOrderP}) {
      if ($v11nbk eq $bks) {$continue++;}
      if ($continue) {$books{$v11nbk}++;}
      if ($v11nbk eq $bke) {$continue = 0;}
    }
  }
  
  my @bookList = 
      ( sort { &defaultOsisIndex($a) <=> &defaultOsisIndex($b) }
        keys %books );
  
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
  &swordVsys($vsys, \$canonP, \$bookOrderP, \$testamentP);
  
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

# Uses the Sword Perl module to populate the given pointers with data 
# describing a particular SWORD verse system. Returns $vsys if
# successful or undef upon failure. For making this same information 
# available to XSLT, see swordVsysXML().
#
# $canonP     - Hash with osisbk => Array (starting with index 0) 
#               containing each chapter's max-verse number.
#
# $bookOrderP - Hash with osisbk => position (Gen = 1, Rev = 66) to get
#               the order of books in the system.
#
# $testamentP - Hash with osisbk => 'OT' or 'NT' to get the 
#               testament(s) available in a system. NOTE: SWORD verse 
#               systems only contain OT and NT, however osis-converters 
#               supports other bookGroups in addition (see OSIS_GROUP).
#
# $bookAP     - Array (starting with index 1) with osisbk abbreviations 
#               in verse system order.
my %CANON_CACHE;
sub swordVsys {
  my $vsys = shift;
  my $canonP = shift;     # hash pointer
  my $bookOrderP = shift; # hash pointer
  my $testamentP = shift; # hash pointer
  my $bookAP = shift;     # array pointer
  
  if (!$CANON_CACHE{$vsys}) {
  
    if (!checkVerseSystemName($vsys)) {return;}
    
    my $vk = new Sword::VerseKey();
    $vk->setVersificationSystem($vsys);
    
    for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
      my ($t, $bkt);
      if ($bk < $vk->bookCount(1)) {$t = 1; $bkt = ($bk+1);}
      else {$t = 2; $bkt = (($bk+1) - $vk->bookCount(1));}
      $CANON_CACHE{$vsys}{'bookOrder'}{$bkname} = ($bk+1);
      $CANON_CACHE{$vsys}{'testament'}{$bkname} = ($t == 1 ? "OT":"NT");
      my $chaps = [];
      for (my $ch = 1; $ch <= $vk->chapterCount($t, $bkt); $ch++) {
        # Note: CHAPTER 1 IN ARRAY IS INDEX 0!!!
        push(@{$chaps}, $vk->verseCount($t, $bkt, $ch));
      }
      $CANON_CACHE{$vsys}{'canon'}{$bkname} = $chaps;
    }
    @{$CANON_CACHE{$vsys}{'bookArray'}} = ();
    foreach my $bk (sort keys %{$CANON_CACHE{$vsys}{'bookOrder'}}) {
      @{ $CANON_CACHE{$vsys}{'bookArray'} }
       [ $CANON_CACHE{$vsys}{'bookOrder'}{$bk} ] = $bk;
    }
  }
  
  if ($canonP) {
    $$canonP     = \%{ $CANON_CACHE{$vsys}{'canon'} };
  }
  if ($bookOrderP) {
    $$bookOrderP = \%{ $CANON_CACHE{$vsys}{'bookOrder'} };
  }
  if ($testamentP) {
    $$testamentP = \%{ $CANON_CACHE{$vsys}{'testament'} };
  }
  if ($bookAP) {
    $$bookAP     = \@{ $CANON_CACHE{$vsys}{'bookArray'} };
  }

  return $vsys;
}

# Writes an XML file to outdir/tmp/versification/$vsys.xml containing
# the $vsys SWORD verse system. This tmp file provides XSLT with 
# a complete SWORD verse system description. Returns 1 on success or 
# undef on failure. For making this same information avalable to Perl, 
# see swordVsys(). NOTE: If the tmp file already exists, 1 is returned
# without recreating it, since SWORD verse system descriptions don't
# change and the tmp directory is cleared before each run.
sub swordVsysXML {
  my $vsys = shift;
  
  if (!checkVerseSystemName($vsys)) {return;}
  
  my $outfile = "$MOD_OUTDIR/tmp/versification/$vsys.xml";
  if (-e $outfile) {return 1;}
  
  # Read the entire verse system using SWORD
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setIndex(0);
  $vk->normalize();
  my (%sdata, $lastIndex, %bks);
  do {
    $lastIndex = $vk->getIndex;
    if ($vk->getOSISRef() !~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      &ErrorBug(
"Problem reading SWORD versekey osisRef: ".$vk->getOSISRef(), 1);
    }
    else {
      $bks{$1}++; 
      my $b = sprintf("%03i:%s", scalar keys %bks, $1);
      my $c = sprintf("%03i", $2);
      my $v = sprintf("%03i", $3);
      my $g = &defaultOsisIndex($1, 2); 
      $sdata{$g}{$b}{$c}{$v}++;
    }
    $vk->increment();
  } while ($vk->getIndex ne $lastIndex);
  
  # Prepare the output directory
  if (! -e "$MOD_OUTDIR/tmp") {
    &ErrorBug("TMPDIR does not exist: $TMPDIR.");
    return;
  }
  if (! -e "$MOD_OUTDIR/tmp/versification") {
    mkdir "$MOD_OUTDIR/tmp/versification";
  }
  
  # Write the XML file
  if (!open(VOUT, $WRITELAYER, $outfile)) {
    &ErrorBug("Could not write verse system to $outfile.");
    return;
  }
  print VOUT 
'<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" ' .
'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' .
'xsi:schemaLocation="http://www.bibletechnologies.net/2003/OSIS/namespace ' .
'http://www.crosswire.org/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd"> 
<osisText osisRefWork="'.$vsys.'" osisIDWork="'.$vsys.'"> 
<header> 
  <work osisWork="'.$vsys.'">
    <title>CrossWire SWORD Verse System '.$vsys.'</title> 
    <refSystem>Bible.'.$vsys.'</refSystem>
  </work>
</header>
';
  foreach my $gk (sort keys %sdata) {
    print VOUT "<div type=\"bookGroup\">\n";
    foreach my $bk (sort keys %{$sdata{$gk}}) {
      my $b = $bk; $b =~ s/^\d+://;
      print VOUT "  <div type=\"book\" osisID=\"$b\">\n";
      foreach my $ck (sort keys %{$sdata{$gk}{$bk}}) {
        my $c = $ck; $c =~ s/^0+//;
        print VOUT "    <chapter osisID=\"$b.$c\">\n";
        foreach my $vk (sort keys %{$sdata{$gk}{$bk}{$ck}}) {
          my $v = $vk; $v =~ s/^0+//;
          print VOUT "      <verse osisID=\"$b.$c.$v\"/>\n";
        }
        print VOUT "    </chapter>\n";
      }
      print VOUT "  </div>\n";
    }
    print VOUT "</div>\n";
  }
  print VOUT
'</osisText>
</osis>';
  close(VOUT);
  
  return 1;
}

# Returns 1 if $vsys is a valid versification name, or undef otherwise.
sub checkVerseSystemName {
  my $vsys = shift;
  
  my $vsre = join('|', @VERSE_SYSTEMS);
  if ($vsys !~ /($vsre)/) {
    &Error("Not a valid osis-converters versification system: $vsys".
           "Must be one of: ".join(', ', @VERSE_SYSTEMS));
    return;
  }
  
  my $svre = join('|', &swordVersificationSystems());
  if ($vsys !~ /($svre)/) {
    &Error("Not a valid SWORD versification system: $vsys".
           "Must be one of: ($svre)");
    return;
  }
    
  return 1;
}

# Return a list of versification systems that are defined by SWORD.
sub swordVersificationSystems {
  my $vsys = shift;
  
  my $vsmgr = Sword::VersificationMgr::getSystemVersificationMgr();
  my $vsyss = $vsmgr->getVersificationSystems();

  return map($_->c_str(), @$vsyss);
}


1;
