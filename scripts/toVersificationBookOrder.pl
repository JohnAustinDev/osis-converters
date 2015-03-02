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

sub toVersificationBookOrder($$$) {
  my $vsys = shift;
  my $osis = shift;
  my $tmpdir = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nOrdering books in OSIS file according to versification = $vsys\n");

  my %canon;
  my %bookOrder;
  my %allbooks;
  
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
      elsif ($_ =~ /<verse osisID="[^"]*\.(\d+)">/) {
        $vs = $1;
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
            &Log("Missing book $tb\n");
            $_ = $_.&emptyBook($vsys, $tb, $tc, $tv, $canon{$tb}, \%emptyVerses);
          }
        }
        foreach my $k (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %canon) {
          $tb = $k;
          if (!&isCanon($vsys, $tb,$tc,$tv) && !$allbooks{$tb}) {
            &Log("Missing non-canonical book $tb\n");
            $_ = $_.&emptyBook($vsys, $tb, $tc, $tv, $canon{$tb}, \%emptyVerses);
          }
        }
      }
      
      # append missing chapters in book
      if ($finishedChapter && $bk && $ch && $_ =~ /<\/div>/ && $canon{$bk} && @{$canon{$bk}} != $ch) {
        my $emp = "";
        for (my $i=($ch+1); $i <= @{$canon{$bk}}; $i++) {
          $tb=$bk; $tc=$i;
          &Log("Missing ".(&isCanon($vsys, $tb,$tc,$tv) ? "empty":"non-canonical")." chapter $bk $i\n");
          $emp .= &wrapDiv($vsys, "<chapter osisID=\"$bk.$i\">".&emptyVerses("$bk.$i.1-".$canon{$bk}->[$i-1], \%emptyVerses)."</chapter>", $tb, $tc, $tv);
        }
        $BUFF = $emp.$BUFF;
        $ch = @{$canon{$bk}}; # set chapter to current, so we don't ever append same chap again
      }
      $finishedChapter = ($_ =~ /<\/chapter>/); # end of book must be encoded as: </chapter>\n</div>
      
      # append missing verses in chapter
      if ($bk && $ch && $_ =~ /<\/chapter>/ && $canon{$bk}->[$ch-1] != $vs) {
        $tb=$bk; $tc=$ch; $tv=($vs+1);
        &Log("Missing ".(&isCanon($vsys, $tb,$tc,$tv) ? "empty":"non-canonical")." verse(s) $bk $ch:".$tv.($canon{$bk}->[$ch-1]==$tv ? "":"-".$canon{$bk}->[$ch-1])."\n");
        $_ = &wrapDiv($vsys, &emptyVerses("$bk.$ch.".$tv."-".$canon{$bk}->[$ch-1], \%emptyVerses), $tb, $tc, $tv).$_;
      }

      if ($BUFF) {print OUTF $BUFF;}
      $BUFF = $_;
    }
    print OUTF $BUFF;
    close(OSIS);
    close(OUTF);

		# The following lines are commented out becuase we no longer want to modify 
		# the input OSIS file, but just generate INFO and Scope.
    #unlink($osis);
    #rename("$tmpdir/tmp.xml", $osis);

  }
  else {&Log("ERROR: Not re-ordering books in OSIS file!\n");}
}

1;
