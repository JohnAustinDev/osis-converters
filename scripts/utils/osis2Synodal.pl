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

$emptyHolder = "";

&Log("\n\nAPPENDING MISSING & NON-CANONICAL VERSES:\n");

&getCanon(\%canon, "Synodal");

# discover missing books
open(OSIS, "<:encoding(UTF-8)", $OSISFILE) || die "Could not open $OSISFILE\n";
while(<OSIS>) {
  if ($_ =~ /<div type="book" osisID="([^\"]*)">/) {$allbooks .= ";$1;";}
}
close(OSIS);

open(OSIS, "<:encoding(UTF-8)", $OSISFILE) || die "Could not open $OSISFILE\n";
open(OUTF, ">:encoding(UTF-8)", "$TMPDIR/tmp.xml");
while(<OSIS>) {
  if ($_ =~ /<div type="book" osisID="([^\"]*)">/) {
    $bk = $1;
    if (!$canon{$bk}) {&Log("ERROR: Unrecognized book name $bk\n");}
  }
  if ($_ =~ /<chapter osisID="\w+\.([^\"]*)">/) {
    $ch = $1;
    if ($ch > @{$canon{$bk}}) {&Log("ERROR: Unrecognized chapter $bk $ch\n");}
  }
  if ($_ =~ /<verse sID="\w+\.\w+\.([^\"]*)"/) {
    $vs = $1;
    $vs =~ s/\d+\-//;
    if ($vs > $canon{$bk}->[$ch-1]) {&Log("ERROR: Unrecognized verse $bk $ch:$vs\n");}
  }
  
  # each addition is on a one line div for easy removal
   
  # append missing books in canon
  if ($_ =~ /^<div type="bookGroup">/ && !$canonBKs) {
    $canonBKs = 1;
    foreach $k (sort keys %canon) {
      $b = $k;
      if (&isCanon($b,$c,$v) && $allbooks !~ /;$b;/) {
        &Log("Appending ".(&isCanon($b,$c,$v) ? "empty":"non-canonical")." book $b\n");
        $_ = $_.&emptyBook($b, $canon{$b});
      }
    }
    foreach $k (sort keys %canon) {
      $b = $k;
      if (!&isCanon($b,$c,$v) && $allbooks !~ /;$b;/) {
        &Log("Appending ".(&isCanon($b,$c,$v) ? "empty":"non-canonical")." book $b\n");
        $_ = $_.&emptyBook($b, $canon{$b});
      }
    }
  }
  
  # append missing chapters in book
  if ($bk && $ch && $_ =~ /<\/div>/ && $canon{$bk} && @{$canon{$bk}} != $ch) {
    $emp = "";
    for ($i=($ch+1); $i <= @{$canon{$bk}}; $i++) {
      $b=$bk; $c=$i;
      &Log("Appending ".(&isCanon($b,$c,$v) ? "empty":"non-canonical")." chapter $bk $i\n");
      $emp .= &wrapDiv("<chapter osisID=\"$bk.$i\">".&emptyVerses("$bk.$i.1-".$canon{$bk}->[$i-1])."</chapter>");
    }
    $BUFF = $emp.$BUFF;
    $ch = @{$canon{$bk}}; # set chapter to current, so we don't ever append same chap again
  }
  
  # append missing verses in chapter
  if ($bk && $ch && $_ =~ /<\/chapter>/ && $canon{$bk}->[$ch-1] != $vs) {
    $b=$bk; $c=$ch; $v=($vs+1);
    &Log("Appending ".(&isCanon($b,$c,$v) ? "empty":"non-canonical")." verse(s) $bk $ch:".$v.($canon{$bk}->[$ch-1]==$v ? "":"-".$canon{$bk}->[$ch-1])."\n");
    $_ = &wrapDiv(&emptyVerses("$bk.$ch.".$v."-".$canon{$bk}->[$ch-1])).$_;
  }

  if ($BUFF) {print OUTF $BUFF;}
  $BUFF = $_;
}
print OUTF $BUFF;
close(OSIS);
close(OUTF);

unlink($OSISFILE);
rename("$TMPDIR/tmp.xml", $OSISFILE);

# The following books/chapters/verses are in the Synodal verse system
# but are not part of the Protestant Canon.
sub isCanon($$$) {
  my $b = shift;
  my $c = shift;
  my $v = shift;
  my $isCanon = 1;
  if (";1Esd;2Esd;Jdt;EpJer;Bar;Wis;1Macc;2Macc;3Macc;Sir;PrMan;Tob;" =~ /;$b;/) {$isCanon = 0;}
  if ($b eq "Josh" && $c==24 && $v >=34 && $v <=36) {$isCanon = 0;}
  if ($b eq "Ps" && $c==151) {$isCanon = 0;}
  if ($b eq "Prov" && $c==4 && $v >=28 && $v <=29) {$isCanon = 0;}
  if ($b eq "Prov" && $c==13 && $v==26) {$isCanon = 0;}
  if ($b eq "Prov" && $c==18 && $v==25) {$isCanon = 0;}
  if ($b eq "Dan" && $c==3 && $v >=34 && $v <=100) {$isCanon = 0;}
  if ($b eq "Dan" && ($c==13 || $c==14)) {$isCanon = 0;}
  return $isCanon;
}

sub wrapDiv($) {
  my $towrap = shift;
  my $text = "<div type=\"".(&isCanon($b,$c,$v) ? "x-Synodal-empty":"x-Synodal-non-canonical")."\">$towrap<\/div>\n";
  return $text;
}

sub emptyVerses($) {
  my $id = shift;
  my $text = "<verse sID=\"$id\" osisID=\"";
  if ($id !~ /^(.*?\.)(\d+)(-(\d+))?$/) {die "Could not understand \"$id\" in getVerses\n";}
  my $ref = $1;
  my $st = 1*$2;
  my $en = 1*$4;
  if ($3 eq "") {$en = $st;}
  my $sep = "";
  while ($st <= $en) {$text = $text.$sep."$ref$st"; $st++; $sep = " ";}
  
  $text = $text."\"\/>$emptyHolder<verse eID=\"$id\"\/>";
  return $text
}

sub emptyBook($\@) {
  my $bk = shift;
  my $a = shift;
  my $ret = "<div type=\"book\" osisID=\"$bk\">";
  for (my $i=0; $i<@$a; $i++) {
    my $vm = $a->[$i];
    $ret = $ret."<chapter osisID=\"$bk.".($i+1)."\"><verse sID=\"$bk.".($i+1).".1-$vm\" osisID=\"";
    my $sep = "";
    for (my $v=1; $v<=$vm; $v++) {$ret = $ret.$sep."$bk.".($i+1).".$v"; $sep = " ";}
    $ret = $ret."\"/>$emptyHolder<verse eID=\"$bk.".($i+1).".1-".$vm."\"/></chapter>";
  }
  $ret = $ret."</div>";
  return &wrapDiv($ret);
}
