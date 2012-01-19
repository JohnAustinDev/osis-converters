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

use Encode;
use File::Copy;
use File::Path qw(make_path remove_tree);

$OSISSCHEMA = "osisCore.2.1.1.xsd";
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");


sub getInfoFromConf($) {
  my $conf = shift;
  open(CONF, "<:encoding(UTF-8)", "$conf") || die "Could not open $conf\n";
  while(<CONF>) {
    if ($_ =~ /^\s*(.*?)\s*=\s*(.*?)\s*$/) {
      if ($ConfEntry{$1} ne "") {$ConfEntry{$1} = $ConfEntry{$1}."<nx>".$2;}
      else {$ConfEntry{$1} = $2;}
    }
    if ($_ =~ /^\s*\[(.*?)\]\s*$/) {$MOD = $1; $MODLC = lc($MOD);}
  }
  close(CONF);

  # short var names
  $REV = $ConfEntry{"Version"};
  $VERSESYS = $ConfEntry{"Versification"};
  $LANG = $ConfEntry{"Lang"};
  $MODPATH = $ConfEntry{"DataPath"};
  $MODPATH =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $MODPATH =~ s/[\\\/]\s*$//; # remove ending slash
  $MODPATH =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
}

sub encodeOsisRef($) {
  my $r = shift;
  my $rep = decode("utf8", "–"); #  Condsidered by perl as \w but not accepted by schema?
  utf8::upgrade($rep);
  $r =~ s/([$rep])/my $x="_".ord($1)."_"/eg;
  $r =~ s/(\W)/my $x="_".ord($1)."_"/eg;
  $r =~ s/;/ /g;
  return $r;
}

sub decodeOsisRef($) {
  my $r = shift;
  while ($r =~ /(_(\d+)_)/) {
    my $rp = quotemeta($1);
    my $n = $2;
    $r =~ s/$rp/my $ret = chr($n);/e;
  }
  return $r;
}

# Converts to upper case using special translations
sub suc($$) {
  my $t = shift;
  my $i = shift;
  
  # Form for $i: a->A b->B c->C ...
  $i =~ s/(^\s*|\s*$)//g;
  my @trs = split(/\s+/, $i);
  for (my $i=0; $i < @trs; $i++) {
    my @tr = split(/->/, $trs[$i]);
    $t =~ s/$tr[0]/$tr[1]/g;
  }

  $t = uc($t);

  return $t;
}

sub getOsisName($) {
  my $bnm = shift;
  my $bookName = "";
  $bnm =~ tr/a-z/A-Z/;
     if ($bnm eq "1CH") {$bookName="1Chr";}
  elsif ($bnm eq "1CO") {$bookName="1Cor";}
  elsif ($bnm eq "1JN") {$bookName="1John";}
  elsif ($bnm eq "1KI") {$bookName="1Kgs";}
  elsif ($bnm eq "1PE") {$bookName="1Pet";}
  elsif ($bnm eq "1SA") {$bookName="1Sam";}
  elsif ($bnm eq "1TH") {$bookName="1Thess";}
  elsif ($bnm eq "1TI") {$bookName="1Tim";}
  elsif ($bnm eq "2CH") {$bookName="2Chr";}
  elsif ($bnm eq "2COR"){$bookName="2Cor";}
  elsif ($bnm eq "2CO") {$bookName="2Cor";}
  elsif ($bnm eq "2JN") {$bookName="2John";}
  elsif ($bnm eq "2KI") {$bookName="2Kgs";}
  elsif ($bnm eq "2PE") {$bookName="2Pet";}
  elsif ($bnm eq "2SA") {$bookName="2Sam";}
  elsif ($bnm eq "2TH") {$bookName="2Thess";}
  elsif ($bnm eq "2TI") {$bookName="2Tim";}
  elsif ($bnm eq "3JN") {$bookName="3John";}
  elsif ($bnm eq "ACT") {$bookName="Acts";}
  elsif ($bnm eq "AMO") {$bookName="Amos";}
  elsif ($bnm eq "COL") {$bookName="Col";}
  elsif ($bnm eq "DAN") {$bookName="Dan";}
  elsif ($bnm eq "DEU") {$bookName="Deut";}
  elsif ($bnm eq "ECC") {$bookName="Eccl";}
  elsif ($bnm eq "EPH") {$bookName="Eph";}
  elsif ($bnm eq "EST") {$bookName="Esth";}
  elsif ($bnm eq "EXO") {$bookName="Exod";}
  elsif ($bnm eq "EZK") {$bookName="Ezek";}
  elsif ($bnm eq "EZR") {$bookName="Ezra";}
  elsif ($bnm eq "GAL") {$bookName="Gal";}
  elsif ($bnm eq "GEN") {$bookName="Gen";}
  elsif ($bnm eq "HAB") {$bookName="Hab";}
  elsif ($bnm eq "HAG") {$bookName="Hag";}
  elsif ($bnm eq "HEB") {$bookName="Heb";}
  elsif ($bnm eq "HOS") {$bookName="Hos";}
  elsif ($bnm eq "ISA") {$bookName="Isa";}
  elsif ($bnm eq "JAS") {$bookName="Jas";}
  elsif ($bnm eq "JDG") {$bookName="Judg";}
  elsif ($bnm eq "JER") {$bookName="Jer";}
  elsif ($bnm eq "JHN") {$bookName="John";}
  elsif ($bnm eq "JOB") {$bookName="Job";}
  elsif ($bnm eq "JOL") {$bookName="Joel";}
  elsif ($bnm eq "JON") {$bookName="Jonah";}
  elsif ($bnm eq "JOS") {$bookName="Josh";}
  elsif ($bnm eq "JUD") {$bookName="Jude";}
  elsif ($bnm eq "LAM") {$bookName="Lam";}
  elsif ($bnm eq "LEV") {$bookName="Lev";}
  elsif ($bnm eq "LUK") {$bookName="Luke";}
  elsif ($bnm eq "MAL") {$bookName="Mal";}
  elsif ($bnm eq "MAT") {$bookName="Matt";}
  elsif ($bnm eq "MIC") {$bookName="Mic";}
  elsif ($bnm eq "MRK") {$bookName="Mark";}
  elsif ($bnm eq "NAM") {$bookName="Nah";}
  elsif ($bnm eq "NEH") {$bookName="Neh";}
  elsif ($bnm eq "NUM") {$bookName="Num";}
  elsif ($bnm eq "OBA") {$bookName="Obad";}
  elsif ($bnm eq "PHM") {$bookName="Phlm";}
  elsif ($bnm eq "PHP") {$bookName="Phil";}
  elsif ($bnm eq "PROV") {$bookName="Prov";}
  elsif ($bnm eq "PRO") {$bookName="Prov";}
  elsif ($bnm eq "PSA") {$bookName="Ps";}
  elsif ($bnm eq "REV") {$bookName="Rev";}
  elsif ($bnm eq "ROM") {$bookName="Rom";}
  elsif ($bnm eq "RUT") {$bookName="Ruth";}
  elsif ($bnm eq "SNG") {$bookName="Song";}
  elsif ($bnm eq "TIT") {$bookName="Titus";}
  elsif ($bnm eq "ZEC") {$bookName="Zech";}
  elsif ($bnm eq "ZEP") {$bookName="Zeph";}
  else {print "ERROR: Unrecognized Bookname:\"$bnm\"!\n";}

  return $bookName;
}

sub getCanon(\%$) {
  my $canonP = shift;
  my $caname = shift;

  if ($caname eq "Synodal") {
    # non-canonical books
    # Prayer of Manasses
    $canonP->{"PrMan"} = [(12)];
    # I Esdras
    $canonP->{"1Esd"} = [(58, 31, 24, 63, 70, 34, 15, 92, 55)];
    # Tobit
    $canonP->{"Tob"} = [(22, 14, 17, 21, 22, 18, 17, 21, 6, 13, 18, 22, 18, 15)];
    # Judith
    $canonP->{"Jdt"} = [(16, 28, 10, 15, 24, 21, 32, 36, 14, 23, 23, 20, 20, 19, 14, 25)];
    # Wisdom
    $canonP->{"Wis"} = [(16, 24, 19, 20, 24, 27, 30, 21, 19, 21, 27, 28, 19, 31, 19, 29, 20, 25, 21)];
    # Sirach
    $canonP->{"Sir"} = [(30, 18, 31, 35, 18, 37, 39, 22, 23, 34, 34, 18, 32, 27, 20, 31, 31, 33, 28, 31, 31, 31, 37, 37, 29, 27, 33, 30, 31, 27, 37, 25, 33, 26, 23, 29, 34, 39, 42, 32, 29, 26, 36, 27, 31, 23, 31, 28, 18, 31, 38)];
    # Epistle of Jeremiah
    $canonP->{"EpJer"} = [(72)];
    # Baruch
    $canonP->{"Bar"} = [(22, 35, 38, 37, 9)];
    # I Maccabees
    $canonP->{"1Macc"} = [(64, 70, 60, 61, 68, 63, 50, 32, 73, 89, 74, 53, 53, 49, 41, 24)];
    # II Maccabees
    $canonP->{"2Macc"} = [(36, 33, 40, 50, 27, 31, 42, 36, 29, 38, 38, 45, 26, 46, 39)];
    # III Maccabees
    $canonP->{"3Macc"} = [(25, 24, 22, 16, 36, 37, 20)];
    # II Esdras
    $canonP->{"2Esd"} = [(40, 48, 36, 52, 56, 59, 70, 63, 47, 60, 46, 51, 58, 48, 63, 78)];

    # canonical books
    # Genesis
    $canonP->{"Gen"} = [(31, 25, 24, 26, 32, 22, 24, 22, 29, 32, 32, 20, 18, 24, 21, 16, 27, 33, 38, 18, 34, 24, 20, 67, 34, 35, 46, 22, 35, 43, 55, 32, 20, 31, 29, 43, 36, 30, 23, 23, 57, 38, 34, 34, 28, 34, 31, 22, 33, 26)];
    # Exodus
    $canonP->{"Exod"} = [(22, 25, 22, 31, 23, 30, 25, 32, 35, 29, 10, 51, 22, 31, 27, 36, 16, 27, 25, 26, 36, 31, 33, 18, 40, 37, 21, 43, 46, 38, 18, 35, 23, 35, 35, 38, 29, 31, 43, 38)];
    # Leviticus
    $canonP->{"Lev"} = [(17, 16, 17, 35, 19, 30, 38, 36, 24, 20, 47, 8, 59, 56, 33, 34, 16, 30, 37, 27, 24, 33, 44, 23, 55, 46, 34)];
    # Numbers
    $canonP->{"Num"} = [(54, 34, 51, 49, 31, 27, 89, 26, 23, 36, 35, 15, 34, 45, 41, 50, 13, 32, 22, 29, 35, 41, 30, 25, 18, 65, 23, 31, 39, 17, 54, 42, 56, 29, 34, 13)];
    # Deuteronomy
    $canonP->{"Deut"} = [(46, 37, 29, 49, 33, 25, 26, 20, 29, 22, 32, 32, 18, 29, 23, 22, 20, 22, 21, 20, 23, 30, 25, 22, 19, 19, 26, 68, 29, 20, 30, 52, 29, 12)];
    # Joshua
    $canonP->{"Josh"} = [(18, 24, 17, 24, 16, 26, 26, 35, 27, 43, 23, 24, 33, 15, 63, 10, 18, 28, 51, 9, 45, 34, 16, 36)];
    # Judges
    $canonP->{"Judg"} = [(36, 23, 31, 24, 31, 40, 25, 35, 57, 18, 40, 15, 25, 20, 20, 31, 13, 31, 30, 48, 25)];
    # Ruth
    $canonP->{"Ruth"} = [(22, 23, 18, 22)];
    # I Samuel
    $canonP->{"1Sam"} = [(28, 36, 21, 22, 12, 21, 17, 22, 27, 27, 15, 25, 23, 52, 35, 23, 58, 30, 24, 43, 15, 23, 28, 23, 44, 25, 12, 25, 11, 31, 13)];
    # II Samuel
    $canonP->{"2Sam"} = [(27, 32, 39, 12, 25, 23, 29, 18, 13, 19, 27, 31, 39, 33, 37, 23, 29, 33, 43, 26, 22, 51, 39, 25)];
    # I Kings
    $canonP->{"1Kgs"} = [(53, 46, 28, 34, 18, 38, 51, 66, 28, 29, 43, 33, 34, 31, 34, 34, 24, 46, 21, 43, 29, 53)];
    # II Kings
    $canonP->{"2Kgs"} = [(18, 25, 27, 44, 27, 33, 20, 29, 37, 36, 21, 21, 25, 29, 38, 20, 41, 37, 37, 21, 26, 20, 37, 20, 30)];
    # I Chronicles
    $canonP->{"1Chr"} = [(54, 55, 24, 43, 26, 81, 40, 40, 44, 14, 47, 40, 14, 17, 29, 43, 27, 17, 19, 8, 30, 19, 32, 31, 31, 32, 34, 21, 30)];
    # II Chronicles
    $canonP->{"2Chr"} = [(17, 18, 17, 22, 14, 42, 22, 18, 31, 19, 23, 16, 22, 15, 19, 14, 19, 34, 11, 37, 20, 12, 21, 27, 28, 23, 9, 27, 36, 27, 21, 33, 25, 33, 27, 23)];
    # Ezra
    $canonP->{"Ezra"} = [(11, 70, 13, 24, 17, 22, 28, 36, 15, 44)];
    # Nehemiah
    $canonP->{"Neh"} = [(11, 20, 32, 23, 19, 19, 73, 18, 38, 39, 36, 47, 31)];
    # Esther
    $canonP->{"Esth"} = [(22, 23, 15, 17, 14, 14, 10, 17, 32, 3)];
    # Job
    $canonP->{"Job"} = [(22, 13, 26, 21, 27, 30, 21, 22, 35, 22, 20, 25, 28, 22, 35, 22, 16, 21, 29, 29, 34, 30, 17, 25, 6, 14, 23, 28, 25, 31, 40, 22, 33, 37, 16, 33, 24, 41, 35, 27, 26, 17)];
    # Psalms
    $canonP->{"Ps"} = [(6, 12, 9, 9, 13, 11, 18, 10, 39, 7, 9, 6, 7, 5, 11, 15, 51, 15, 10, 14, 32, 6, 10, 22, 12, 14, 9, 11, 13, 25, 11, 22, 23, 28, 13, 40, 23, 14, 18, 14, 12, 5, 27, 18, 12, 10, 15, 21, 23, 21, 11, 7, 9, 24, 14, 12, 12, 18, 14, 9, 13, 12, 11, 14, 20, 8, 36, 37, 6, 24, 20, 28, 23, 11, 13, 21, 72, 13, 20, 17, 8, 19, 13, 14, 17, 7, 19, 53, 17, 16, 16, 5, 23, 11, 13, 12, 9, 9, 5, 8, 29, 22, 35, 45, 48, 43, 14, 31, 7, 10, 10, 9, 26, 9, 10, 2, 29, 176, 7, 8, 9, 4, 8, 5, 6, 5, 6, 8, 8, 3, 18, 3, 3, 21, 26, 9, 8, 24, 14, 10, 7, 12, 15, 21, 10, 11, 9, 14, 9, 6, 7)];
    # Proverbs
    $canonP->{"Prov"} = [(33, 22, 35, 29, 23, 35, 27, 36, 18, 32, 31, 28, 26, 35, 33, 33, 28, 25, 29, 30, 31, 29, 35, 34, 28, 28, 27, 28, 27, 33, 31)];
    # Ecclesiastes
    $canonP->{"Eccl"} = [(18, 26, 22, 17, 19, 12, 29, 17, 18, 20, 10, 14)];
    # Song of Solomon
    $canonP->{"Song"} = [(16, 17, 11, 16, 16, 12, 14, 14)];
    # Isaiah
    $canonP->{"Isa"} = [(31, 22, 25, 6, 30, 13, 25, 22, 21, 34, 16, 6, 22, 32, 9, 14, 14, 7, 25, 6, 17, 25, 18, 23, 12, 21, 13, 29, 24, 33, 9, 20, 24, 17, 10, 22, 38, 22, 8, 31, 29, 25, 28, 28, 25, 13, 15, 22, 26, 11, 23, 15, 12, 17, 13, 12, 21, 14, 21, 22, 11, 12, 19, 12, 25, 24)];
    # Jeremiah
    $canonP->{"Jer"} = [(19, 37, 25, 31, 31, 30, 34, 22, 26, 25, 23, 17, 27, 22, 21, 21, 27, 23, 15, 18, 14, 30, 40, 10, 38, 24, 22, 17, 32, 24, 40, 44, 26, 22, 19, 32, 21, 28, 18, 16, 18, 22, 13, 30, 5, 28, 7, 47, 39, 46, 64, 34)];
    # Lamentations
    $canonP->{"Lam"} = [(22, 22, 66, 22, 22)];
    # Ezekiel
    $canonP->{"Ezek"} = [(28, 10, 27, 17, 17, 14, 27, 18, 11, 22, 25, 28, 23, 23, 8, 63, 24, 32, 14, 49, 32, 31, 49, 27, 17, 21, 36, 26, 21, 26, 18, 32, 33, 31, 15, 38, 28, 23, 29, 49, 26, 20, 27, 31, 25, 24, 23, 35)];
    # Daniel
    $canonP->{"Dan"} = [(21, 49, 100, 34, 31, 28, 28, 27, 27, 21, 45, 13, 64, 42)];
    # Hosea
    $canonP->{"Hos"} = [(11, 23, 5, 19, 15, 11, 16, 14, 17, 15, 12, 14, 15, 10)];
    # Joel
    $canonP->{"Joel"} = [(20, 32, 21)];
    # Amos
    $canonP->{"Amos"} = [(15, 16, 15, 13, 27, 14, 17, 14, 15)];
    # Obadiah
    $canonP->{"Obad"} = [(21)];
    # Jonah
    $canonP->{"Jonah"} = [(16, 11, 10, 11)];
    # Micah
    $canonP->{"Mic"} = [(16, 13, 12, 13, 15, 16, 20)];
    # Nahum
    $canonP->{"Nah"} = [(15, 13, 19)];
    # Habakkuk
    $canonP->{"Hab"} = [(17, 20, 19)];
    # Zephaniah
    $canonP->{"Zeph"} = [(18, 15, 20)];
    # Haggai
    $canonP->{"Hag"} = [(15, 23)];
    # Zechariah
    $canonP->{"Zech"} = [(21, 13, 10, 14, 11, 15, 14, 23, 17, 12, 17, 14, 9, 21)];
    # Malachi
    $canonP->{"Mal"} = [(14, 17, 18, 6)];
    # Matthew
    $canonP->{"Matt"} = [(25, 23, 17, 25, 48, 34, 29, 34, 38, 42, 30, 50, 58, 36, 39, 28, 27, 35, 30, 34, 46, 46, 39, 51, 46, 75, 66, 20)];
    # Mark
    $canonP->{"Mark"} = [(45, 28, 35, 41, 43, 56, 37, 38, 50, 52, 33, 44, 37, 72, 47, 20)];
    # Luke
    $canonP->{"Luke"} = [(80, 52, 38, 44, 39, 49, 50, 56, 62, 42, 54, 59, 35, 35, 32, 31, 37, 43, 48, 47, 38, 71, 56, 53)];
    # John
    $canonP->{"John"} = [(51, 25, 36, 54, 47, 71, 53, 59, 41, 42, 57, 50, 38, 31, 27, 33, 26, 40, 42, 31, 25)];
    # Acts
    $canonP->{"Acts"} = [(26, 47, 26, 37, 42, 15, 60, 40, 43, 48, 30, 25, 52, 28, 41, 40, 34, 28, 40, 38, 40, 30, 35, 27, 27, 32, 44, 31)];
    # James
    $canonP->{"Jas"} = [(27, 26, 18, 17, 20)];
    # I Peter
    $canonP->{"1Pet"} = [(25, 25, 22, 19, 14)];
    # II Peter
    $canonP->{"2Pet"} = [(21, 22, 18)];
    # I John
    $canonP->{"1John"} = [(10, 29, 24, 21, 21)];
    # II John
    $canonP->{"2John"} = [(13)];
    # III John
    $canonP->{"3John"} = [(15)];
    # Jude
    $canonP->{"Jude"} = [(25)];
    # Romans
    $canonP->{"Rom"} = [(32, 29, 31, 25, 21, 23, 25, 39, 33, 21, 36, 21, 14, 26, 33, 24)];
    # I Corinthians
    $canonP->{"1Cor"} = [(31, 16, 23, 21, 13, 20, 40, 13, 27, 33, 34, 31, 13, 40, 58, 24)];
    # II Corinthians
    $canonP->{"2Cor"} = [(24, 17, 18, 18, 21, 18, 16, 24, 15, 18, 32, 21, 13)];
    # Galatians
    $canonP->{"Gal"} = [(24, 21, 29, 31, 26, 18)];
    # Ephesians
    $canonP->{"Eph"} = [(23, 22, 21, 32, 33, 24)];
    # Philippians
    $canonP->{"Phil"} = [(30, 30, 21, 23)];
    # Colossians
    $canonP->{"Col"} = [(29, 23, 25, 18)];
    # I Thessalonians
    $canonP->{"1Thess"} = [(10, 20, 13, 18, 28)];
    # II Thessalonians
    $canonP->{"2Thess"} = [(12, 17, 18)];
    # I Timothy
    $canonP->{"1Tim"} = [(20, 15, 16, 16, 25, 21)];
    # II Timothy
    $canonP->{"2Tim"} = [(18, 26, 17, 22)];
    # Titus
    $canonP->{"Titus"} = [(16, 15, 15)];
    # Philemon
    $canonP->{"Phlm"} = [(25)];
    # Hebrews
    $canonP->{"Heb"} = [(14, 18, 19, 16, 14, 20, 28, 13, 28, 39, 40, 29, 25)];
    # Revelation of John
    $canonP->{"Rev"} = [(20, 29, 22, 11, 14, 17, 17, 13, 21, 11, 19, 17, 18, 20, 8, 21, 18, 24, 21, 15, 27, 21)];
  }
  else {return 0;}
  
  return 1;
}

sub readGlossWordFile($$\@\%\%) {
  my $wordfile = shift;
  my $dictname = shift;
  my $wordsP = shift;        # Array containing all glossary entries
  my $dictsForWordP = shift; # Dictionaries associated with each glossary entry
  my $searchTermsP = shift;  # Hash of all search terms and their targets

  # Read words and search terms from a word file...
  open(WORDS, "<:encoding(UTF-8)", $wordfile) or die "ERROR: Didn't locate \"$wordfile\" specified in $COMMANDFILE.\n";
  &Log("\nReading glossary file \"$wordfile\".\n");
  my $line=0;
  while (<WORDS>) {
    $line++;
    $_ =~ s/^\s*(.*?)\s*$/$1/;
    if    ($_ =~ /^DE(\d+):(.*?)$/i) {
      $$wordsP[$1]=$2;
      $dictsForWordP->{$2}=$dictname;
    }
    elsif ($_ =~ /^DL(\d+):(.*?)$/i) {$searchTermsP->{$2} = $$wordsP[$1];}
    elsif ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^\s*#/) {next;}
    else {&Log("WARNING 001, $wordfile line $line: Unhandled entry $_.\n");}
  }
  close (WORDS);
}

# Searches a bit of text for a single dictionary link, starting with longest
# search terms first. If a match is found, the proper link tag is inserted,
# and 1 is returned. Otherwise 0 is returned and the input text is unmodified.
sub addGlossLink(\$\%\%\%\%$\$$$$) {
  my $lnP = shift;           # pointer to text to modify
  my $dictsForWordP = shift; # pointer to dictsForWord hash
  my $searchTermsP = shift;  # pointer to searchTerms hash
  my $reportListP = shift;   # pointer to hash of replacement reports
  my $entryCountP = shift;   # pointer to hash of entries and their counts
  my $useSkipList = shift;   # set to use skip list to skip certain search terms
  my $skipListP = shift;     # list of search terms to skip
  my $referenceType = shift; # new reference's type (null means no type)
  my $bookName = shift;      # name of book (sometimes used to filter)
  my $notVerse = shift;      # "not a verse" flag (sometimes used to filter)

  if ($referenceType) {$referenceType = "type=\"$referenceType\" ";}
  
if ($line == $DEBUG) {&Log("Line $line: lnP=$$lnP, useSkipList=$useSkipList, skipList=$$skipListP\n");}
  my $linkAdded = 0;
  foreach my $searchTerm (sort {length($b) <=> length($a)} keys %$searchTermsP) {
if ($line == $DEBUG) {&Log("Line $line: searchTerm=$searchTerm\n");}
    my $entry = $searchTermsP->{$searchTerm};
    my $dictnames = $dictsForWordP->{$entry};
    my $saveSearchTerm = $searchTerm;
    my $sflags = "i";
    if ($useSkipList && $$skipListP =~ /(^|;)\Q$saveSearchTerm\E;/) {next;}
    if ($searchTerm =~ s/\s*(<.*>)\s*//) {
      my $instruction = $1;
      my $mustContain, $onlyBooks;
      if ($instruction =~ /verse must contain "(.*)"/) {
        $mustContain = $1;
        if ($$lnP !~ /$mustContain/) {next;}
      }
      if ($instruction =~ /only book\(s\):"\s*(.*)\s*"/) {
        $onlyBooks = $1;
        if ($onlyBooks !~ /(^|,)\s*$bookName\s*(,|$)/) {next;}
        if ($notVerse) {next;} # If only book is specified, limit to verses only
      }
      if ($instruction =~ /<case sensitive>/) {$sflags = "";}
    }
    # Strip off any " at beginning of searchTerm for backward compatibility
    $searchTerm =~ s/^"//; #"
    # Search words with only quote at end match no suffixes
    my $suffix="";
    if ($searchTerm !~ s/"$//) {$suffix = ".*?";} #pspad comment "
    my $osisRef = $dictnames;
    my $encentry = &encodeOsisRef($entry);
    $osisRef =~ s/;/:$encentry /g;
    $osisRef .= ":$encentry";
    my $attribs = $referenceType."osisRef=\"$osisRef\"";
    if ($sflags eq "") {
      if ($$lnP =~ s/(^|\W)($searchTerm$suffix)([^$PAL]|$)/$1<reference $attribs>$2<\/reference>$3/) {
        if ($reportListP) {$reportListP->{"$entry: $2, $dictnames"}++;}
        if ($entryCountP) {$entryCountP->{$entry}++;}
        if ($skipListP && $useSkipList) {$$skipListP .= $saveSearchTerm.";";}
        $linkAdded = 1;
        last;
      }
    }
    elsif ($sflags eq "i") {
      my $ln = &suc($$lnP, $SpecialCapitals);
      my $pat = &suc("$searchTerm$suffix", $SpecialCapitals);
if ($line == $DEBUG) {&Log("Line $line: $ln =~ (^|^.*?\W)($pat)([^$PAL]|$)\n");}
      if ($ln =~ /(^|^.*?\W)($pat)([^$PAL]|$)/) {
        my $m1 = $1;
        my $m2 = $2;

        my $m2o = substr($$lnP, length($m1), length($m2));
        substr($$lnP, length($m1)+length($m2), 0, "</reference>");
        substr($$lnP, length($m1), 0, "<reference $attribs>");

        if ($reportListP) {$reportListP->{"$entry: $m2o, $dictnames"}++;}
        if ($entryCountP) {$entryCountP->{$entry}++;}
        if ($skipListP && $useSkipList) {$$skipListP .= $saveSearchTerm.";";}
        $linkAdded = 1;
        last;
      }
    }
  }
if ($line == $DEBUG) {&Log("Line $line: linkAdded=$linkAdded\n");}
  return $linkAdded;
}

# Check all <reference type="$types"> links, and repair if necessary
sub checkGlossReferences($$\%) {
  my $f = shift;         # file to check
  my $types = shift;     # type attributes of references to be checked
  my $wordFileP = shift; # hash of glossary names and correspondng word files

  my %replaceList, %contextList, %errorList;

  &Log("\nChecking all <reference type=\"$types\"> osisRef targets (and fixing bad targets):\n");
  open(INF, "<:encoding(UTF-8)", "$f") || die "ERROR: Could not check $f.\n";
  open(OUTF, ">:encoding(UTF-8)", "$f.tmp") || die "ERROR: Could not write to $f.tmp.\n";
  $line = 0;
  while(<INF>) {
    $line++;
    my $save = $_;

  if ($line == $DEBUG) {&Log("Line $line: Checking <references> in $_\n");}
    my $copy = $save;
    while ($copy =~ s/(<reference[^>]*type="($types)"[^>]*>)//) {
      my $r = $1;
      my $s = $`;
      my $e = $';

      my $n = &checkGlossRef($r, $s, $e, $types, \%AllWordFiles, \%replaceList, \%contextList, \%errorList);
      $r = quotemeta($r);
      if ($save !~ s/$r/$n/) {&Log("ERROR Line $line: Problem replacing reference.\n");}
    }
    print OUTF $save;
  }
  close(INF);
  close(OUTF);
  unlink($f);
  move("$f.tmp", $f);

  foreach my $error (sort keys %errorList) {&Log($errorList{$error});}

  if (%replaceList) {
    &Log("\nLISTING OF FIXED GLOSSARY TARGETS:\n");
    &Log("GLOSSARY_TARGET: PREVIOUS_TARGET, MODNAME(s), NUMBER_CHANGED (CONTEXT IF USED)\n");
    foreach my $rep (sort keys %replaceList) {
      &Log("$rep, $replaceList{$rep}");
      $rep =~ /: (.*?),/;
      if ($contextList{$rep} && $contextList{$rep} ne $1) {&Log(" ($contextList{$rep})\n");}
      else {&Log("\n");}
    }
    &Log("\n\n");
  }
}

# Checks that a given reference's osisRef target(s) actually exist. If
# not, an attempt is made to find correspoding targets which do exist.
# The reference's context in the text is used to help make this determination.
# If a fix is made, the fixed reference start tag is returned, otherwise the
# incoming start tag is returned unchanged.
sub checkGlossRef($$$$\%\%\%) {
  my $r = shift;            # reference start tag to check
  my $pre = shift;          # pre context
  my $pst = shift;          # post context
  my $types = shift;        # type attributes of references to be checked
  my $wordFileP = shift;    # hash of glossary names and correspondng word files
  my $replaceListP = shift; # return hash of replacements
  my $contextListP = shift; # return hash of context used by each replacement
  my $errorListP = shift;   # return hash for errors encountered

if ($line == $DEBUG) {&Log("Line $line: Checking reference $r\n");}
  if ($r =~ /<reference type="($types)" osisRef="([^\"]+)"[^>]*>/) {
    my $origref = $2;
    my $refcopy = $2;

    my $newref = "";
    my $sep = "";
    while ($refcopy =~ s/^\s*([^:]*)\s*:\s*(\S*)//) {
      my $name = $1;
      my $e = $2;

      if (exists($wordFileP->{$name})) {
        my $entry = &decodeOsisRef($e);
        my $oref = "$name:$entry";

        if (!exists($Data{"$name:words"})) {
          $Data{"$name:words"} = [];
          $Data{"$name:dictsForWord"} = {};
          $Data{"$name:searchTerms"} = {};
          &readGlossWordFile($wordFileP->{$name}, $name, $Data{"$name:words"}, $Data{"$name:dictsForWord"}, $Data{"$name:searchTerms"});
        }

        my $widx;
        for ($widx = 0; $widx < @{$Data{"$name:words"}}; $widx++) {
          if (${$Data{"$name:words"}}[$widx] eq $entry) {last;}
        }

        # Is this word not in the wordfile? Then fix it...
        # try and fix the invalid entry by looking for the correct match, using context
        if ($widx == @{$Data{"$name:words"}}) {
          my $entrysave = $entry;

          # put the entry in its proper context and look for a match
          $pre = " ".$pre;
          if ($pre =~ /[^$PAL]([^>]{0,64})$/) {$pre = $1;}
          $pst .= " ";
          $pst =~ s/^.*?<\/reference>//;
          if ($pst =~ /^([^<]{0,64})[^$PAL]/) {$pst = $1;}

          my $tryentrysave = $pre." ".$entry." ".$pst;
          $tryentrysave =~ s/\s+/ /g;

          my $tryentry;
          my $addedLink;
          my $usedTerms = "";
          my %reportList;
          # continue looking for terms until one is found that covers our entry
          while (1) {
            $tryentry = $tryentrysave;
            undef(%reportList);
            $addedLink = &addGlossLink(\$tryentry, $Data{"$name:dictsForWord"}, $Data{"$name:searchTerms"}, \%reportList, NULL, 1, \$usedTerms);

            if (!$addedLink) {last;}

            # check for a correct match (ie matches our entry)
if ($line == $DEBUG) {&Log("Line $line: determining location of $entry in $tryentry\n");}
            if ($tryentry =~ /<reference[^>]*>[^<]*\Q$entry\E[^<]*<\/reference>/) {last;}
          }

          # If we didn't find a link in context, try just the entry alone. This
          # is needed because sometimes the entry is repeated in pre-context
          # text, so the wrong instance of the entry has been matched, with the
          # result that the needed search term was thereafter skipped,
          # leading to the entry itself being missed. This fixes such exceptions.
          if (!$addedLink) {
            $tryentry = $entry;
            undef(%reportList);
            $addedLink = &addGlossLink(\$tryentry, $Data{"$name:dictsForWord"}, $Data{"$name:searchTerms"}, \%reportList);
          }

          if ($addedLink) {
            my $e2 = $tryentry;
            $e2 =~ s/^.*osisRef="[^:]*:([^\"]*)".*$/$1/; # keep only the new (valid) target

            # get the matched text for logging
            my $mt;
            foreach my $k (sort keys %reportList) {
              if ($k !~ s/^[^:]*: (.*), \w+$/$1/) {$mt = "ERROR";}
              else {$mt = $k;}
              last;
            }

            # log the change
            my $k2 = &decodeOsisRef($e2).": ".&decodeOsisRef($e).", $name";
            $replaceListP->{$k2}++;
            if (!exists($contextListP->{$k2})) {$contextListP->{$k2} = $mt;}
            elsif ($contextListP->{$k2} !~ /(^|, )\Q$mt\E(,|$)/) {
              $contextList->{$k2} .= ", $mt";
            }

            $e = $e2; # replace the bad target
          }
          else {
            if (!exists($errorListP->{$entry})) {
              $errorListP->{$entrysave} = "ERROR line $line: invalid glossary reference \"$name:$entrysave\". ($tryentrysave)\n";
            }
          }
        }
      }
      else {&Log("ERROR: no glossary with the name \"$name\".\n");}

      $newref .= "$sep$name:$e";
      $sep = " ";
    }

    # replace the target in the reference start tag, if needed
    if ($newref ne $origref) {
      if (!$newref) {&Log("ERROR Line $line: Could not fix malformed osisRef: \"$origref\".\n");}
      else {
        if ($r =~ s/osisRef="([^\"]*)"/osisRef="$newref"/) {
          &Log("Line $line: Fixed reference target: $1 -> $newref\n");
        }
        else {&Log("ERROR Line $line: Could not replace bad target: $origref -> $newref\n");}
      }
    }
  }
  else {&Log("ERROR: non-standard glossary link \"$r\".\n");}

  return $r;
}

# Print log info for a word file
sub logGlossReplacements($\@\%\%) {
  my $wf = shift; # $currentWordFile
  my $wP = shift; # @words
  my $rP = shift; # %replacements
  my $hP = shift; # %wordHits

  &Log("\nBEGIN LOG FOR $wf...\n");
  &Log("GLOSSARY_ENTRY: LINK, MODNAME(s), NUMBER_OF_LINKS\n");
  foreach my $dl (@$wP) {
    my $match = 0;
    foreach my $dh (keys %$hP) {
      if ($dl eq $dh) {$match=1;}
    }
    if ($match == 0) {&Log("$dl\:\tNO MATCHES!\n");}
  }
  foreach my $rep (sort keys %$rP) {
    &Log("$rep, $rP->{$rep}\n");
  }
  &Log("\n\n");
}

# copies a directory to a non existing destination directory
sub copy_dir($$) {
  my $id = shift;
  my $od = shift;

  if (!-e $id || !-d $id) {
    &Log("ERROR copy_dir: Source does not exist or is not a direcory: $id\n");
    return 0;
  }
  if (-e $od) {
    &Log("ERROR copy_dir: Destination already exists: $od\n");
    return 0;
  }
 
  opendir(DIR, $id) || die "Could not open dir $id\n";
  my @fs = readdir(DIR);
  closedir(DIR);
  make_path($od);

  for(my $i=0; $i < @fs; $i++) {
    if ($fs[$i] =~ /^\.+$/) {next;}
    my $if = "$id/".$fs[$i];
    my $of = "$od/".$fs[$i];
    if (-d $if) {&copy_dir($if, $of);}
    else {copy($if, $of);}
  }
  return 1;
}

sub fromUTF8($) {
  my $c = shift;
  $c = decode("utf8", $c);
  utf8::upgrade($c);
  return $c;
}

sub escfile($) {
  my $n = shift;
  
  if ("$^0" =~ /MSWin32/i) {$n = "\"".$n."\"";}
  else {$n =~ s/([ \(\)])/\\$1/g;}
  return $n;
}

sub Log($$) {
  my $p = shift; # log message
  my $h = shift; # hide from console
  if (!$h && !$NOCONSOLELOG) {print encode("utf8", "$p");}
  open(LOGF, ">>:encoding(UTF-8)", "$LOGFILE") || die "Could not open log file $LOGFILE\n";
  print LOGF $p;
  close(LOGF);
}

1;
