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
use File::Spec;
use File::Copy;
use File::Path qw(make_path remove_tree);

$OSISSCHEMA = "osisCore.2.1.1.xsd";
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");

# Get our current osis-converters revision number
if ("$^O" =~ /MSWin32/i) {
  $SVNREV = "SubWCRev \"".__FILE__."\" 2>&1";
  $SVNREV = `$SVNREV`;
  if ($SVNREV && $SVNREV =~ /^Updated to revision\s*(\d+)\s*$/mi) {$SVNREV = $1;}
  else {$SVNREV = "";} 
}
else {
  $SVNREV = "svn info ".__FILE__." 2>&1";
  $SVNREV = `$SVNREV`;
  if ($SVNREV && $SVNREV =~ /^Revision:\s*(\d+)\s*$/mi) {$SVNREV = $1;}
  else {$SVNREV = "";}
}

sub initPaths() {
  chdir($SCRD);
  $PATHFILE = "$SCRD/CF_paths.txt";
  if (open(PTHS, "<:encoding(UTF-8)", $PATHFILE)) {
    while(<PTHS>) {
      if ($_ =~ /^SWORD_PATH:\s*(.*?)\s*$/) {if ($1) {$SWORD_PATH = $1;}}
      if ($_ =~ /^SWORD_BIN:\s*(.*?)\s*$/) {if ($1) {$SWORD_BIN = $1;}}
      if ($_ =~ /^XMLLINT:\s*(.*?)\s*$/) {if ($1) {$XMLLINT = $1;}}
      if ($_ =~ /^GO_BIBLE_CREATOR:\s*(.*?)\s*$/) {if ($1) {$GOCREATOR = $1;}}
      if ($_ =~ /^OUTDIR:\s*(.*?)\s*$/) {if ($1) {$OUTDIR = $1;}}
    }
    close(PTHS);
    
    if ($GOCREATOR && $GOCREATOR =~ /^\./) {$GOCREATOR = File::Spec->rel2abs($GOCREATOR);}
    if ($SWORD_PATH && $SWORD_PATH =~ /^\./) {$SWORD_PATH = File::Spec->rel2abs($SWORD_PATH);}
    if ($SWORD_BIN && $SWORD_BIN =~ /^\./) {$SWORD_BIN = File::Spec->rel2abs($SWORD_BIN);}
    if ($SWORD_BIN && $SWORD_BIN !~ /[\\\/]$/) {$SWORD_BIN .= "/";}
    if ($XMLLINT && $XMLLINT =~ /^\./) {$XMLLINT = File::Spec->rel2abs($XMLLINT);}
    if ($XMLLINT && $XMLLINT !~ /[\\\/]$/) {$XMLLINT .= "/";}
    if ($OUTDIR && $OUTDIR =~ /^\./) {$OUTDIR = File::Spec->rel2abs($OUTDIR);}
    
    if ($OUTDIR) {
      $OUTDIR =~ s/\/\s*$//; # remove any trailing slash
      $INPD =~ /([^\/]+)([\/\.]*\s*)?$/;
      my $dn = $1;
      if (!$dn) {$dn = "OUTPUT";}
      $OUTDIR .= "/".$dn; # use input directory name as this output subdirectory
      if (!-e $OUTDIR) {make_path($OUTDIR);}
    }
    else {
      $OUTDIR = $INPD;
    }
  }
  else {
    open(PTHS, ">:encoding(UTF-8)", $PATHFILE) || die "Could not open $PATHFILE.\n";
    print PTHS "# With this command file, you may set paths which are used by\n# osis-converters scripts.\n\n";
    print PTHS "# You may set SWORD_PATH to a directory where module copies\n# will then be made.\n";
    print PTHS "SWORD_PATH:\n\n";
    print PTHS "# Set GO_BIBLE_CREATOR to the Go Bible Creator directory\n# if you are using osis2GoBible.pl.\n";
    print PTHS "GO_BIBLE_CREATOR:\n\n";
    print PTHS "# Set SWORD_BIN to the directory where SWORD tools (osis2mod,\n# emptyvss mod2zmod) are located, unless already in your PATH.\n";
    print PTHS "SWORD_BIN:\n\n";
    print PTHS "# Set XMLLINT to the xmllint executable's directory if\n# it's not in your PATH.\n";
    print PTHS "XMLLINT:\n\n";
    print PTHS "# Set OUTDIR to the directory where output files should go.\nDefault is the inputs directory.\n";
    print PTHS "OUTDIR:\n\n";
    close(PTHS);
  }
  
  if (!-e $OUTDIR) {$OUTDIR = $INPD; $OUTDIR_IS_INDIR = 1;}
}

# osis-converters runs in both Linux and Windows, and input files
# may use different newlines than the current op-sys uses. So 
# all input files should be normalized. This also means any input 
# files on SVN need to be copied first, then normalized, then used.
sub normalizeNewLines($) {
  my $f = shift;
  
  my $d = "Windows to Linux";
  if ("$^O" =~ /MSWin32/i) {$d = "Linux to Windows";}
  
  if(open(NFRS, "<:encoding(UTF-8)", $f)) {
    open(NFRT, ">:encoding(UTF-8)", "$f.tmp") || die "ERROR: Unable to open \"$f.tmp\".\n";
    while(<NFRS>) {
      $_ =~ tr/\x{feff}//d;
      $_ =~ s/([\r\n]*)$//;
      $_ .= "\n";
      print NFRT $_;
    }
    close(NFRS);
    close(NFRT);
    if (-s $f != -s "$f.tmp") {
      &Log("INFO: Converting newlines from $d: \"$f\".\n");
      unlink($f);
      move("$f.tmp", $f);
    }
    else {unlink("$f.tmp");}
  }
  else {&Log("ERROR: Could not open $f while trying to normalize newlines from $d.\n");}
}

sub addRevisionToCF($) {
  my $f = shift;
  
  if ($SVNREV) {
    my $changed = 0;
    my $msg = "# osis-converters rev-";
    if (open(RCMF, "<:encoding(UTF-8)", $f)) {
      open(OCMF, ">:encoding(UTF-8)", "$f.tmp") || die "ERROR: Could not open \"$f.tmp\".\n";
      my $l = 0;
      while(<RCMF>) {
        $l++;
        if ($l == 1) {
          if ($_ =~ s/\Q$msg\E(\d+)/$msg$SVNREV/) {
            if ($1 != $SVNREV) {$changed = 1;}
          }
          else {$changed = 1; $_ = "$msg$SVNREV\n$_";}
        }
        print OCMF $_;
      }
      close(RCMF);
      close(OCMF);
      
      if ($changed) {
        unlink($f);
        move("$f.tmp", $f);
      }
      else {unlink("$f.tmp");}
    }
    else {&Log("ERROR: Could not add revision to command file.\n");}
  }
  else {&Log("ERROR: SVN revision unknown.\n");}
}

sub getInfoFromConf($) {
  my $conf = shift;
  undef(%ConfEntry);
  &normalizeNewLines($conf);
  open(CONF, "<:encoding(UTF-8)", $conf) || die "Could not open $conf\n";
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
  else {&Log("ERROR: Unrecognized Bookname:\"$bnm\"!\n");}

  return $bookName;
}

sub getCanon($\%\%) {
  my $VSYS = shift;
  my $canonP = shift;
  my $bookOrderP = shift;
  
  my $INFILE = "$SCRD/scripts/Canon/canon".($VSYS && $VSYS ne "KJV" ? "_".lc($VSYS):"").".h";
  my $inOT, $inNT, $inVM;
  my $vsys = "unset";
  my %bookLongName, %bookChapters, %bookTest;
  my @VM;
  my $booknum = 1;

  # Collect canon information from header file
  copy($INFILE, "$INFILE.tmp");
  &normalizeNewLines("$INFILE.tmp");
  if (open(INF, "<:encoding(UTF-8)", "$INFILE.tmp")) {
    while(<INF>) {
      # do some error checking
      if ($inOT + $inNT + $inVM > 1) {&Lof("ERROR: Missed data end.\n");}
      if ($vsys ne "unset"  && (($vsys && $vsys !~ /^\Q$VSYS\E$/i) || (!$vsys && $VSYS !~ /^KJV$/i))) {
        &Log("ERROR: Verse system may be incorrectly specified (\"$vsys\" != \"$VSYS\")\n");
      }
      
      # capture data
      if ($_ =~ /^\s*\/\//) {next;}
      elsif ($_ =~ /^\s*struct\s+sbook\s+otbooks(_(\w+))?\[\]\s*=\s*\{/) {$inOT = 1; $vsys = $2;}
      elsif ($_ =~ /^\s*struct\s+sbook\s+ntbooks(_(\w+))?\[\]\s*=\s*\{/) {$inNT = 1; $vsys = $2;}
      elsif ($_ =~ /^int\s+vm(_(\w+))?\[\]\s*=\s*\{/) {$inVM = 1; $vsys = $2;}
      elsif (($inOT || $inNT) && $_ =~ /\{\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*(\d+)\s*\}/) {
        my $bln = $1;
        my $bk = $2;
        my $nch = $4;
        $bookLongName{$bk} = $bln;
        $bookChapters{$bk} = $nch;
        $bookOrderP->{$bk} = $booknum++;
        $bookTest{$bk} = ($inOT ? "OT":"NT");
      }
      elsif ($inVM) {
        my $copy = $_;
        $copy =~ s/(^\s*|\s*$|\};\s*$)//g;
        my @vc = split(/\s*,\s*/, $copy);
        if (!$vc[@vc-1]) {pop(@vc);}
        push(@VM, @vc);
      }

      # find data end
      if ($_ =~ /\};/) {
        $inOT = 0;
        $inNT = 0;
        $inVM = 0;
      }
    }
    close(INF);

    # save canon info
    my $vmi = 0;
    foreach my $bk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$bookOrderP}) {
      $newarray = [];
#&Log("$bk = ");
      for (my $i=0; $i<$bookChapters{$bk}; $i++) {
#&Log($VM[$vmi].", ");
        if ($VM[$vmi] !~ /^\d+$/) {&Log("ERROR: Canon data is not a number \"".$VM[$vmi]."\".\n");}
        push(@{$newarray}, $VM[$vmi++]);
      }
      $canonP->{$bk} = $newarray;
#&Log("\n");
    }

    if ($vmi != @VM) {&Log("ERROR: Data count mismatch: ".($vmi-1)." (".$VM[$vmi-1].") != ".(@VM-1)." (".$VM[@VM-1].").\n");}
  }
  else {
    &Log("ERROR: Could not open canon file \"$INFILE.tmp\".\n");
    return 0;
  }
  unlink("$INFILE.tmp");
  
  return 1;
}

sub readGlossWordFile($$\@\%\%) {
  my $wordfile = shift;
  my $dictname = shift;
  my $wordsP = shift;        # Array containing all glossary entries
  my $dictsForWordP = shift; # Dictionaries associated with each glossary entry
  my $searchTermsP = shift;  # Hash of all search terms and their targets

  # Read words and search terms from a word file...
  &normalizeNewLines($wordfile);
  open(WORDS, "<:encoding(UTF-8)", $wordfile) or die "ERROR: Didn't locate \"$wordfile\" specified in $COMMANDFILE.\n";
  &Log("\nREADING GLOSSARY FILE \"$wordfile\".\n");
  my $line=0;
  while (<WORDS>) {
    $line++;
    $_ =~ s/^\s*(.*?)\s*$/$1/;
    if    ($_ =~ /^DE(\d+):(.*?)$/i) {
      if (!defined($$wordsP[$1])) {
        $$wordsP[$1]=$2;
        $dictsForWordP->{$2}=$dictname;
      }
      else {&Log("ERROR: Skipped redefinition in \"$wordfile\", line $line: \"$_\"\n");}
    }
    elsif ($_ =~ /^DL(\d+):(.*?)$/i) {$searchTermsP->{$2} = $$wordsP[$1];}
    elsif ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^\s*#/) {next;}
    else {&Log("WARNING 001, $wordfile line $line: Unhandled entry $_.\n");}
  }
  close (WORDS);
}

sub sortSearchTermKeys($$) {
  my $aa = shift;
  my $bb = shift;
  
  while ($aa =~ /["\s]+<[^>]*>\s*$/) {$aa =~ s/["\s]+<[^>]*>\s*$//;}
  while ($bb =~ /["\s]+<[^>]*>\s*$/) {$bb =~ s/["\s]+<[^>]*>\s*$//;}
  
  length($bb) <=> length($aa)
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
  foreach my $searchTerm (sort {&sortSearchTermKeys($a, $b);} keys %$searchTermsP) {
if ($line == $DEBUG) {&Log("Line $line: searchTerm=$searchTerm\n");}
    my $entry = $searchTermsP->{$searchTerm};
    my $dictnames = $dictsForWordP->{$entry};
    my $saveSearchTerm = $searchTerm;
    my $sflags = "i";
    if ($useSkipList && $$skipListP =~ /(^|;)\Q$saveSearchTerm\E;/) {next;}

    my $done = 0;
    while ($searchTerm =~ s/\s*<([^>]*)>\s*$//) {
      my $handled = 0;
      my $instruction = $1;
      my $mustContain, $onlyBooks;
      if ($instruction =~ /^\s*verse must contain "(.*)"\s*$/) {
        $mustContain = $1;
        if ($$lnP !~ /$mustContain/) {$done = 1; last;}
        $handled = 1;
      }
      if ($instruction =~ /^\s*only New Testament\s*$/i) {
        $instruction = "only book(s):1Cor,1John,1Pet,1Thess,1Tim,2Cor,2John,2Pet,2Thess,2Tim,3John,Acts,Col,Eph,Gal,Heb,Jas,John,Jude,Luke,Matt,Mark,Phlm,Phil,Rev,Rom,Titus";
      }
      if ($instruction =~ /^\s*only Old Testament\s*$/i) {
        $instruction = "only book(s):1Chr,1Kgs,1Sam,2Chr,2Kgs,2Sam,Amos,Dan,Deut,Eccl,Esth,Exod,Ezek,Ezra,Gen,Hab,Hag,Hos,Isa,Judg,Jer,Job,Joel,Jonah,Josh,Lam,Lev,Mal,Mic,Nah,Neh,Num,Obad,Prov,Ps,Ruth,Song,Titus,Zech,Zeph";
      }
      if ($instruction =~ /^\s*only book\(s\)\:\s*(.*)\s*$/i) {
        $onlyBooks = $1;
        if ($onlyBooks !~ /(^|,)\s*$bookName\s*(,|$)/) {$done = 1; last;}
        if ($notVerse) {$done = 1; last;} # If only book is specified, limit to verses only
        $handled = 1;
      }
      if ($instruction =~ /^\s*not in book\(s\)\:\s*(.*)\s*$/i) { 
        my $notInBooks = $1;
        if ($notInBooks =~ /(^|,)\s*$bookName\s*(,|$)/) {$done = 1; last;}
        $handled = 1;
      }
      if ($instruction =~ /^\s*case sensitive\s*$/i) {
        $sflags = "";
        $handled = 1;
      }
      if (!$handled) {
        if (!defined($AddGlossLinkCommandErrors{$instruction})) {
          &Log("ERROR: Unhandled DictionaryWords.txt instruction: \"$instruction\"\n");
        }
        $AddGlossLinkCommandErrors{$instruction}++;
      }
    }
    if ($done) {next;}
    
    # Strip off any " at beginning of searchTerm for backward compatibility
    $searchTerm =~ s/^"//; #"
    # Search words with only quote at end match no suffixes
    my $suffix=".*?";
    if ($searchTerm =~ s/"\s*$//) {$suffix = "";}
    my $osisRef = $dictnames;
    my $encentry = &encodeOsisRef($entry);
    $osisRef =~ s/;/:$encentry /g;
    $osisRef .= ":$encentry";
    my $attribs = $referenceType."osisRef=\"$osisRef\"";

#if (!defined($AlreadyShowedThis{$saveSearchTerm})) {&Log("REPLACING in $bookName($notVerse): " . $saveSearchTerm . ", " . $searchTerm . ", suffix=" . $suffix . ", sflags=" . $sflags . ".\n");}
#$AlreadyShowedThis{$saveSearchTerm}++;

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
  
  my $total = 0;
  foreach my $n (keys %replaceList) {$total += $replaceList{$n};}
  &Log("\nREPORT: Listing of broken glossary targets which have been adjusted: ($total instances)\n");
  if ($total) {
    &Log("NOTE: These references were targetting non-existent glossary entries, but their targets\n");
    &Log("have now been replaced with the closest matching target which does exist. These \n");
    &Log("replacements should be checked for correctness. Any Adjustments can be enforced \n");
    &Log("using DictionaryWords.txt.\n");
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
  my $wordFileP = shift;    # hash of glossary names and corresponding word files
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
          &readGlossWordFile("$INPD/".$wordFileP->{$name}, $name, $Data{"$name:words"}, $Data{"$name:dictsForWord"}, $Data{"$name:searchTerms"});
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

  my $total = 0;
  foreach my $rep (sort keys %$rP) {$total += $rP->{$rep};}
  
  my $nolink = "";
  my $numnolink = 0;
  foreach my $dl (@$wP) {
    if (!$dl) {next;}
    my $match = 0;
    foreach my $dh (keys %$hP) {
      if ($dl eq $dh) {$match=1;}
    }
    if ($match == 0) {$nolink .= "$dl\n"; $numnolink++;}
  }
  
  &Log("\n");
  &Log("REPORT: Glossary entries from $wf which have no links in the text: ($numnolink instances)\n");
  if ($nolink) {
    &Log("NOTE: You may want to link to these entries using a different word or phrase. To do this, edit the\n");
    &Log("$wf file. Find the line with DLxx:<the_entry> and change the word or phrase there \n");
    &Log("to what you want to match in the text. Also see note below.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  &Log("\n");
  
  &Log("REPORT: Words/phrases converted into links using $wf: ($total instances)\n");
  &Log("NOTE: The following list must be looked over carefully. Glossary entries are matched\n"); 
  &Log("in the text using the \"DLxx\" listings in the $wf file. By default,  \n"); 
  &Log("these are case insensitive and any word ending in the text is matched. This means a \n");
  &Log("listing like \"DL15:to\" will match \"to\", \"Tom\", \"tomorrow\", and \"together\" and\n");
  &Log("all these words will be linked to the glossary entry DE15:<entry>. This is probably \n");
  &Log("not what was intended. So here are ways to control what is matched:\n");
  &Log("\n");
  &Log("    DL20:Tom\"                                Do not match any word endings\n");
  &Log("    DL45:Asia <case sensitive>               Match becomes case sensitive\n");
  &Log("    DL23:Samuel <only book(s): 1Sam, 2Sam>   Match only in listed books/entries\n");
  &Log("    DL73:Adam <verse must contain \"Eve\">     Match only in certain verses/entries\n");
  &Log("    DL11:(be)?love(ed)?                      Any Perl regular expression\n");
  &Log("\n");
  &Log("    Multiple DL lines may reference a single DE line. So all DL01 instances will be matched \n");
  &Log("    and will target DE01. A \"#\" at the beginning of a line is a comment line.\n");
  &Log("\n");
  &Log("GLOSSARY_ENTRY: LINK_TEXT, MODNAME(s), NUMBER_OF_LINKS\n");
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
    if ($fs[$i] =~ /^\.svn/) {next;}
    my $if = "$id/".$fs[$i];
    my $of = "$od/".$fs[$i];
    if (-d $if) {&copy_dir($if, $of);}
    else {copy($if, $of);}
  }
  return 1;
}

# deletes files recursively without touching dirs or anything in .svn
sub delete_files($) {
  my $dir = shift;
  my $success = 0;
  if (!opendir(CHDIR, $dir)) {return 0;}
  my @listing = readdir(CHDIR);
  closedir(CHDIR);
  foreach my $entry (@listing) {
    if ($entry =~ /^(\.+|\.svn)$/) {next;}
    if (-d "$dir/$entry") {$success &= delete_files("$dir/$entry");}
    unlink("$dir/$entry");
  }
  
  return $success;
}

sub fromUTF8($) {
  my $c = shift;
  $c = decode("utf8", $c);
  utf8::upgrade($c);
  return $c;
}

sub escfile($) {
  my $n = shift;
  
  if ("$^O" =~ /MSWin32/i) {$n = "\"".$n."\"";}
  else {$n =~ s/([ \(\)])/\\$1/g;}
  return $n;
}

$ProgressTotal = 0;
$ProgressTime = 0;
sub logProgress($$) {
  my $msg = shift;
  my $ln = shift;
  
  my $t = time;
  my $tleft = 0;
  if ($ln == -1) {
      $ProgressTime = time;
      $ProgressTotal = 0;
      copy($msg, "$msg.progress.tmp");
      if (open(PRGF, "<:encoding(UTF-8)", "$msg.progress.tmp")) {
        while(<PRGF>) {$ProgressTotal++;}
        close(PRGF);
      }
      unlink("$msg.progress.tmp");
      return;
  }
  elsif ($ln) {$tleft = ((($t-$ProgressTime)/$ln)*($ProgressTotal-$ln));}

  &Log("-> $msg", 2);
  if ($tleft) {&Log(sprintf(" (eta: %dmin %dsec)\n", ($tleft/60), ($tleft%60)), 2);}
  else {&Log("\n", 2);}
}

sub Log($$) {
  my $p = shift; # log message
  my $h = shift; # -1 = hide from console, 1 = show in console, 2 = only console
  if ((!$NOCONSOLELOG && $h!=-1) || $h>=1 || $p =~ /error/i) {print encode("utf8", "$p");}
  if ($LOGFILE && $h!=2) {
    open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
    print LOGF $p;
    close(LOGF);
  }
}

1;
