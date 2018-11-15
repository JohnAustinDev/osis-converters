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

$maxUnicode = 1103; # Default value: highest Russian Cyrillic Uncode code point

sub goBibleConvChars($\@) {
  my $type = shift;
  my $aP = shift;
  
  undef(%highUnicode);
  my @FROM,
  my @TO;
 
  if (open(INF, "<:encoding(UTF-8)", $GOBIBLE."/".$type."Chars.txt")) {
    while(<INF>) {
      if ($_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        $CHARS = $1;
        for ($i=0; substr($CHARS, $i, 1); $i++) {
          push(@FROM, substr($CHARS, $i, 1));
        }
      }
      if ($_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        $CHARS = $1;
        for ($i=0; substr($CHARS, $i, 1); $i++) {
          push(@TO, substr($CHARS, $i, 1));
        }
      }
      if ($_ =~ /Replace-this-group:\s*(.*?)\s*$/) {
        $CHARS = $1;
        push(@FROM, $CHARS);
      }
      if ($_ =~ /With-this-group:\s*(.*?)\s*$/) {
        $CHARS = $1;
        push(@TO, $CHARS);
      }
      if ($_ =~ /Max-Unicode-Code-Point:\s*(\d+)\s*$/) {$maxUnicode = ($1*1);}
    }
    close(INF);

    &Log("Converting the following chars:\n");
    for ($i=0; $i<@FROM; $i++) {&Log(@FROM[$i]."<>".@TO[$i]."\n");}
  }

  &Log("Converting chars in following files:\n");
  make_path("$TMPDIR/$type");

  foreach my $file (@$aP) {
    open(INF, "<:encoding(UTF-8)", $file) || die "Could not open $file.\n";
    $leaf = $file;
    $leaf =~ s/^.*?([^\\\/]+)$/$1/;
    open(OUTF, ">:encoding(UTF-8)", "$TMPDIR/$type/$leaf") || die "Could not open $TMPDIR/$type/$leaf.\n";

    &Log("$file\n");
    $line = 0;
    while(<INF>) {
      $line++;
      
      # Replace some Unicode chars which might cause problems on some phones
      $c = fromUTF8("…");
      $_ =~ s/$c/\.\.\./g;
      $c = fromUTF8("­"); # remove optional hyphens!
      $_ =~ s/$c//g;
      
      # Replace
      for ($i=0; $i<@FROM; $i++) {
        $r = @FROM[$i];
        $s = @TO[$i];
        $_ =~ s/\Q$r\E/$s/g; # simplify the character set      
      }
      
      # Change jar name if "simple"
      if ($type eq "simple") {$_ =~ s/(^\s*Collection:\s*.*?)\s*$/$1_s\n/;} # change name of collection
      
      WriteGB($_, $file, $line);
    }
    close(OUTF);
    close(INF);
  }
  &Log("\n");

  # Log whether any high Unicode chars
  &Log("Listing of unicode chars higher than $maxUnicode:\n");
  $error = "false";
  foreach $key (keys %highUnicode) {
    if ($type eq "simple") {$error = "true"; &Log(" ".$key." :".$highUnicode{$key}."\n");}
    else {&Log($key." ");}
  }
  if ($type eq "simple") {
    if ($error eq "false") {&Log("Good! No such chars were found.\n");}
    else {&Error("The high code point Unicode chars above were found.",
"You need to add these characters to the GoBible/simpleChars.txt
file, and map them to lower order Unicode characters (below $maxUnicode) 
which look as similar as possible to the original character. Then these 
characters will be replaced when building the 'simple' apps, and will 
not appear as boxes on feature phones.");}
  }
  else {&Log("\n");}
  &Log("\n");
}

sub WriteGB($$$) {
  my $print = shift;
  my $f = shift;
  my $l = shift;
  $f =~ s/^.*?([^\/]+)$/$1/;
  for ($i=0; substr($print, $i, 1); $i++) {
    my $c = substr($print, $i, 1);
    if (ord($c) > $maxUnicode) {$highUnicode{$c} = $highUnicode{$c}.$f.":".$l.":".$i." ";}
  }
  print OUTF $print;
}
;1
