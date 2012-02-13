# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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

sub fillEmptyVerses($$$) {
  my $vsys = shift;
  my $osis = shift;
  my $tmpdir = shift;
  
  my $emptyHolder = "";
  my $scope = "";
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nAPPENDING MISSING & NON-CANONICAL EMPTY VERSES:\n");

  my %canon;
  my %bookOrder;
  my %allbooks;
  my %missingVerses;
  my %bookIntro;
  
  if (&getCanon($vsys, \%canon, \%bookOrder)) {
    # discover missing books
    open(OSIS, "<:encoding(UTF-8)", $osis) || die "Could not open $osis\n";
    while(<OSIS>) {
      if ($_ =~ /<div type="book" osisID="([^\"]*)">/) {$allbooks{$1}++;}
    }
    close(OSIS);

    open(OSIS, "<:encoding(UTF-8)", $osis) || die "Could not open $osis\n";
    open(OUTF, ">:encoding(UTF-8)", "$tmpdir/tmp.xml");
    my $canonBKs = 0;
    my $bk, $ch, $vs;
    my $tb, $tc, $tv;
    my $intro;
    my $BUFF;
    while(<OSIS>) {
      if ($_ =~ /<div type="book" osisID="([^\"]*)">/) {
        $bk = $1;
        if (!$canon{$bk}) {&Log("ERROR: Unrecognized book name $bk\n");}
        $intro = "capture:";
      }
      if ($_ =~ /<chapter osisID="\w+\.([^\"]*)">/) {
        $ch = $1;
        if ($ch > @{$canon{$bk}}) {&Log("ERROR: Unrecognized chapter $bk $ch\n");}
        if ($intro) {
          $intro =~ s/^.*?<div type="book"[^>]*>(.*)$/$1/;
          if ($intro !~ /^\s*$/) {
            if ($ch == 1) {$bookIntro{$bk} = $intro;}
            else {&Log("ERROR: Chapter $ch introduction not supported (must be before chapter 1)\n");}
          }
          $intro = "";
        }
      }
      if ($_ =~ /<verse sID="\w+\.\w+\.([^\"]*)"/) {
        $vs = $1;
        $vs =~ s/\d+\-//;
        if ($vs > $canon{$bk}->[$ch-1]) {&Log("ERROR: Unrecognized verse $bk $ch:$vs\n");}
      }
      if ($intro) {$intro .= $_;}
      
      # each addition is on a one line div for easy removal
       
      # append missing books in canon
      if ($_ =~ /^<div type="bookGroup">/ && !$canonBKs) {
        $canonBKs = 1;
        foreach my $k (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %canon) {
          $tb = $k;
          if (&isCanon($vsys, $tb,$tc,$tv) && !$allbooks{$tb}) {
            &Log("Appending empty book $tb\n");
            $_ = $_.&emptyBook($vsys, $tb, $tc, $tv, $canon{$tb}, \%emptyVerses);
          }
        }
        foreach my $k (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %canon) {
          $tb = $k;
          if (!&isCanon($vsys, $tb,$tc,$tv) && !$allbooks{$tb}) {
            &Log("Appending non-canonical book $tb\n");
            $_ = $_.&emptyBook($vsys, $tb, $tc, $tv, $canon{$tb}, \%emptyVerses);
          }
        }
      }
      
      # append missing chapters in book
      if ($bk && $ch && $_ =~ /<\/div>/ && $canon{$bk} && @{$canon{$bk}} != $ch) {
        my $emp = "";
        for (my $i=($ch+1); $i <= @{$canon{$bk}}; $i++) {
          $tb=$bk; $tc=$i;
          &Log("Appending ".(&isCanon($vsys, $tb,$tc,$tv) ? "empty":"non-canonical")." chapter $bk $i\n");
          $emp .= &wrapDiv($vsys, "<chapter osisID=\"$bk.$i\">".&emptyVerses("$bk.$i.1-".$canon{$bk}->[$i-1], \%emptyVerses)."</chapter>", $tb, $tc, $tv);
        }
        $BUFF = $emp.$BUFF;
        $ch = @{$canon{$bk}}; # set chapter to current, so we don't ever append same chap again
      }
      
      # append missing verses in chapter
      if ($bk && $ch && $_ =~ /<\/chapter>/ && $canon{$bk}->[$ch-1] != $vs) {
        $tb=$bk; $tc=$ch; $tv=($vs+1);
        &Log("Appending ".(&isCanon($vsys, $tb,$tc,$tv) ? "empty":"non-canonical")." verse(s) $bk $ch:".$tv.($canon{$bk}->[$ch-1]==$tv ? "":"-".$canon{$bk}->[$ch-1])."\n");
        $_ = &wrapDiv($vsys, &emptyVerses("$bk.$ch.".$tv."-".$canon{$bk}->[$ch-1], \%emptyVerses), $tb, $tc, $tv).$_;
      }

      if ($BUFF) {print OUTF $BUFF;}
      $BUFF = $_;
    }
    print OUTF $BUFF;
    close(OSIS);
    close(OUTF);

    unlink($osis);
    rename("$tmpdir/tmp.xml", $osis);
    
    # assemble the scope conf entry for this text
    my $s = "";
    my $hadLastV = 0;
    my $lastCheckedV = "";
    my $canbkFirst, $canbkLast;
    foreach my $bk (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %canon) {
      if (!$canbkFirst) {$canbkFirst = $bk;}
      $canbkLast = $bk;
      for (my $ch=1; $ch<=@{$canon{$bk}}; $ch++) {
        for (my $vs=1; $vs<=$canon{$bk}->[$ch-1]; $vs++) {
          # record scope unit start
          if (!$hadLastV && !$emptyVerses{"$bk.$ch.$vs"}) {
            $s .= " $bk.$ch.$vs";          
          }
          # record scope unit end
          if ($hadLastV && $emptyVerses{"$bk.$ch.$vs"}) {
            $s .= "-$lastCheckedV";
          }
          $hadLastV = !$emptyVerses{"$bk.$ch.$vs"};
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
      if ($b2 ne $b1 || ($b2 eq $b1 && ($c2==@{$canon{$b2}} && $v2==$canon{$b2}->[$c2-1]))) {
        if ($v1 == 1) {
          if ($c1 == 1) {$sub .= "$b1";}
          else {$sub .= "$b1.$c1";}
        }
        else {$sub .= "$b1.$c1.$v1";}
      }
      elsif ($c2 != $c1) {
        if ($v1==1) {
          if ($c1==1) {$c1 = 0;}
          $sub .= "$b1.$c1";
        }
        else {$sub .= "$b1.$c1.$v1";}
      }
      else {$sub .= "$b1.$c1.$v1";}
      
      # simplify scope unit end
      if ($b1 ne $b2 || ($b1 eq $b2 && ($c1==1 && $v1==1))) {
        if ($v2 == $canon{$b2}->[$c2-1]) {
          if ($c2 == @{$canon{$b2}}) {$sub .= "-$b2";}
          else {$sub .= "-$b2.$c2";}
        }
        else {$sub .= "-$b2.$c2.$v2";}
      }
      elsif ($c1 != $c2) {
        if ($v2 == $canon{$b2}->[$c2-1]) {$sub .= "-$b2.$c2";}
        else {$sub .= "-$b2.$c2.$v2";}
      }
      else {$sub .= "-$b2.$c2.$v2";}
      
      $sub =~ s/^(\w+)-(\g1)/$1/;
     
      $scope .= $sep.$sub;
      $sep = " ";
    }
    if ($s !~ /^\s*$/) {&Log("ERROR: While processing scope \"$s\"\n");}
    if ($scope eq "$canbkFirst-$canbkLast") {$scope = "";}
  }
  else {&Log("ERROR: Not filling empty verses in OSIS file!\n");}
 
  return $scope;
}

########################################################################
########################################################################
# This function returns false if the selection is not considered 
# canonical according to the translation itself, even though it
# is included in the SWORD versification system.
sub isCanon($$$$) {
  my $vsys = shift;
  my $tb = shift;
  my $tc = shift;
  my $tv = shift;
  
  my $isCanon = 1;
  
  if ($vsys eq "Synodal") {
    # The following books/chapters/verses are in the Synodal verse system
    # but are not part of the Protestant Canon.
    if (";1Esd;2Esd;Jdt;EpJer;Bar;Wis;1Macc;2Macc;3Macc;Sir;PrMan;Tob;" =~ /;$tb;/) {$isCanon = 0;}
    if ($tb eq "Josh" && $tc==24 && $tv >=34 && $tv <=36) {$isCanon = 0;}
    if ($tb eq "Ps" && $tc==151) {$isCanon = 0;}
    if ($tb eq "Prov" && $tc==4 && $tv >=28 && $tv <=29) {$isCanon = 0;}
    if ($tb eq "Prov" && $tc==13 && $tv==26) {$isCanon = 0;}
    if ($tb eq "Prov" && $tc==18 && $tv==25) {$isCanon = 0;}
    if ($tb eq "Dan" && $tc==3 && $tv >=34 && $tv <=100) {$isCanon = 0;}
    if ($tb eq "Dan" && ($tc==13 || $tc==14)) {$isCanon = 0;}
  }
  
  return $isCanon;
}

sub wrapDiv($$$$$) {
  my $vsys = shift;
  my $towrap = shift;
  my $tb = shift;
  my $tc = shift;
  my $tv = shift;
  my $text = "<div type=\"".(&isCanon($vsys,$tb,$tc,$tv) ? "x-$vsys-empty":"x-$vsys-non-canonical")."\">$towrap<\/div>\n";
  return $text;
}

sub emptyVerses($\%) {
  my $id = shift;
  my $eP = shift;
  
  my $text = "<verse sID=\"$id\" osisID=\"";
  if ($id !~ /^(.*?\.)(\d+)(-(\d+))?$/) {die "Could not understand \"$id\" in getVerses\n";}
  my $ref = $1;
  my $st = 1*$2;
  my $en = 1*$4;
  if ($3 eq "") {$en = $st;}
  my $sep = "";
  while ($st <= $en) {$text = $text.$sep."$ref$st"; $st++; $sep = " ";}
  
  $text = $text."\"\/>$emptyHolder<verse eID=\"$id\"\/>";
  &recordEmptyVerses($id, $eP);
  return $text
}

sub emptyBook($$$$\@\%) {
  my $vsys = shift;
  my $tb = shift;
  my $tc = shift;
  my $tv = shift;
  my $a = shift;
  my $eP = shift;
  
  my $ret = "<div type=\"book\" osisID=\"$tb\">";
  for (my $i=0; $i<@$a; $i++) {
    my $vm = $a->[$i];
    $ret = $ret."<chapter osisID=\"$tb.".($i+1)."\"><verse sID=\"$tb.".($i+1).".1-$vm\" osisID=\"";
    my $sep = "";
    for (my $v=1; $v<=$vm; $v++) {$ret = $ret.$sep."$tb.".($i+1).".$v"; $sep = " ";}
    $ret = $ret."\"/>$emptyHolder<verse eID=\"$tb.".($i+1).".1-".$vm."\"/></chapter>";
    &recordEmptyVerses("$tb.".($i+1).".1-".$vm, $eP);
  }
  $ret = $ret."</div>";
  return &wrapDiv($vsys, $ret, $tb, $tc, $tv);
}

sub recordEmptyVerses($\%) {
  my $id = shift;
  my $eP = shift;
  if ($id !~ /^([^\.]+)\.(\d+)\.(\d+)(-(\d+))?$/) {&Log("ERROR: Could not understand \"$id\" in recordEmptyVerses\n"); return;}
  my $bk = $1;
  my $ch = $2;
  my $v1 = $3;
  my $v2 = $5;
  if (!$v2) {$v2 = $v1;}
  for (my $v=$v1; $v<=$v2; $v++) {$eP->{"$bk.$ch.$v"}++;}
}

1;
