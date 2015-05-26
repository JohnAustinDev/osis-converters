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
use File::Find; 
use Cwd;
use XML::LibXML;
use HTML::Entities;

$XPC = XML::LibXML::XPathContext->new;
$XPC->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
$XML_PARSER = XML::LibXML->new();
$KEYWORD = "osis:seg[\@type='keyword']"; # XPath expression matching dictionary entries in OSIS source
$OSISSCHEMA = "osisCore.2.1.1.xsd";
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
$OT_BOOKS = "1Chr 1Kgs 1Sam 2Chr 2Kgs 2Sam Amos Dan Deut Eccl Esth Exod Ezek Ezra Gen Hab Hag Hos Isa Judg Jer Job Joel Jonah Josh Lam Lev Mal Mic Nah Neh Num Obad Prov Ps Ruth Song Titus Zech Zeph";
$NT_BOOKS = "1Cor 1John 1Pet 1Thess 1Tim 2Cor 2John 2Pet 2Thess 2Tim 3John Acts Col Eph Gal Heb Jas John Jude Luke Matt Mark Phlm Phil Rev Rom Titus";
$DICTLINK_SKIPNAMES= "reference|figure|title|note|name";
$DICTIONARY_WORDS = "DictionaryWords.xml";
$UPPERCASE_DICTIONARY_KEYS = 1;
$NOCONSOLELOG = 1;

# Get our current osis-converters revision number
$GITHEAD = `git rev-parse HEAD`;

sub init($) {
  $SCRIPT = shift;
  
  $SCRIPT =~ s/^.*[\\\/]([^\\\/]+)\.pl$/$1/;
  
  if ($INPD) {
    $INPD =~ s/[\\\/]\s*$//;
    if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  }
  else {
    print "\nusage: $SCRIPT.pl [Project_Directory]\n\n";
    die;
  }
  if (!-e $INPD) {
    print "Project_Directory \"$INPD\" does not exist. Exiting.\n";
    die;
  }

  &initPaths();
  
  $LOGFILE = "$OUTDIR/OUT_$SCRIPT.txt";
  
  $TMPDIR = "$OUTDIR/tmp/$SCRIPT";
  if (-e $TMPDIR) {remove_tree($TMPDIR);}
  make_path($TMPDIR);

  $CONFFILE = "$INPD/config.conf";
  if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}

  &setConfGlobals(&updateConfData(&readConf($CONFFILE)));
  
  if (-e "$INPD/$DICTIONARY_WORDS") {$DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");}
  
  my @outs = ($LOGFILE);
  if ($SCRIPT =~ /^(osis2osis|sfm2osis|html2osis)$/i) {
    $OUTOSIS = "$OUTDIR/$MOD.xml"; push(@outs, $OUTOSIS);
  }
  if ($SCRIPT =~ /^(osis2sword|imp2sword)$/i) {
    $OUTZIP = "$OUTDIR/$MOD.zip"; push(@outs, $OUTZIP);
    $SWOUT = "$OUTDIR/sword"; push(@outs, $SWOUT);
  }
  if ($SCRIPT =~ /^osis2GoBible$/i) {
    $GBOUT = "$OUTDIR/GoBible/$MOD"; push(@outs, $GBOUT);
  }
  if ($SCRIPT =~ /^osis2ebooks$/i) {
    $EBOUT = "$OUTDIR/eBooks"; push(@outs, $EBOUT);
  }
  if ($SCRIPT =~ /^sfm2imp$/i) {
    $OUTIMP = "$OUTDIR/$MOD.imp"; push(@outs, $OUTIMP);
  }

  my $delete;
  foreach my $outfile (@outs) {if (-e $outfile) {$delete .= "$outfile\n";}}
  if ($delete) {
    print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
    $in = <>; 
    if ($in !~ /^\s*y\s*$/i) {exit;} 
  }
  foreach my $outfile (@outs) {
    if (-e $outfile) {
      if (!-d $outfile) {unlink($outfile);}
      else {
        remove_tree($outfile);
        make_path($outfile);
      }
    }
  }
  
  if ($SWORDBIN && $SWORDBIN !~ /[\\\/]$/) {$SWORDBIN .= "/";}
  
  &Log("osis-converters rev: $GITHEAD\n\n");
  &Log("\n-----------------------------------------------------\nSTARTING $SCRIPT.pl\n\n");
}


sub initPaths() {
  chdir($SCRD);
  $PATHFILE = "$SCRD/CF_paths.txt";
  if (open(PTHS, "<:encoding(UTF-8)", $PATHFILE)) {
    while(<PTHS>) {
      if ($_ =~ /^SWORD_BIN:\s*(.*?)\s*$/) {if ($1) {$SWORD_BIN = $1;}}
      if ($_ =~ /^XMLLINT:\s*(.*?)\s*$/) {if ($1) {$XMLLINT = $1;}}
      if ($_ =~ /^GO_BIBLE_CREATOR:\s*(.*?)\s*$/) {if ($1) {$GOCREATOR = $1;}}
      if ($_ =~ /^OUTDIR:\s*(.*?)\s*$/) {if ($1) {$OUTDIR = $1;}}
      if ($_ =~ /^USFM2OSIS:\s*(.*?)\s*$/) {if ($1) {$USFM2OSIS = $1;}}
    }
    close(PTHS);
    
    if ($GOCREATOR && $GOCREATOR =~ /^\./) {$GOCREATOR = File::Spec->rel2abs($GOCREATOR);}
    if ($SWORD_BIN && $SWORD_BIN =~ /^\./) {$SWORD_BIN = File::Spec->rel2abs($SWORD_BIN);}
    if ($SWORD_BIN && $SWORD_BIN !~ /[\\\/]$/) {$SWORD_BIN .= "/";}
    if ($XMLLINT && $XMLLINT =~ /^\./) {$XMLLINT = File::Spec->rel2abs($XMLLINT);}
    if ($XMLLINT && $XMLLINT !~ /[\\\/]$/) {$XMLLINT .= "/";}
    if ($OUTDIR && $OUTDIR =~ /^\./) {$OUTDIR = File::Spec->rel2abs($OUTDIR);}
    if ($USFM2OSIS && $USFM2OSIS =~ /^\./) {$USFM2OSIS = File::Spec->rel2abs($USFM2OSIS);}
    
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
    print PTHS "# Set GO_BIBLE_CREATOR to the Go Bible Creator directory\n# if you are using osis2GoBible.pl.\n";
    print PTHS "GO_BIBLE_CREATOR:\n\n";
    print PTHS "# Set USFM2OSIS to the repotemplate/bin directory\n# if you are using usfm2osis.py.\n";
    print PTHS "USFM2OSIS:\n\n";
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


# Write $conf file by starting with $starterConf and appending necessary 
# entries from %entryValue after it has been updated according to the module source.
# Also creates module directory if it doesn't exist, so that it's ready for writing.
sub writeConf($\%$$) {
  my $starterConf = shift;
  my $entryValueP = shift;
  my $moduleSource = shift;
  my $conf = shift;
  
  $entryValueP = &updateConfData($entryValueP, $moduleSource);
  
  my $starterP = &readConf($starterConf);
  
  my $moddir = $conf;
  if ($moddir =~ s/([\\\/][^\\\/]+){2}$// && !-e "$moddir/mods.d") {
    make_path("$moddir/mods.d");
  }
 
  copy($starterConf, $conf);

  my %used;
  open(CONF, ">>:encoding(UTF-8)", $conf) || die "Could not open conf $conf\n";
  print CONF "\n\n#Autogenerated by osis-converters:\n";
  foreach my $e (sort keys %{$entryValueP}) {
    if ($starterP->{$e}) {
      if ($starterP->{$e} eq $entryValueP->{$e}) {next;}
      else {&Log("ERROR: Conflicting entry: \"$e\" in config.conf. Remove this entry.");}
    }
    foreach my $val (split(/<nx\/>/, $entryValueP->{$e})) {
      if ($val eq '' || $used{"$e$val"}) {next;}
      print CONF $e."=".$val."\n";
      $used{"$e$val"}++;
    }
  }
  close(CONF);

  my $entryValueP = &readConf($conf);
  
  my $realPath = &dataPath2RealPath($entryValueP->{'DataPath'});
  if (!-e "$moddir/$realPath") {make_path("$moddir/$realPath");}

  return $entryValueP;
}


# Update certain conf %entryValue data according to the module's source file
sub updateConfData(\%$) {
  my $entryValueP = shift;
  my $moduleSource = shift;
  
	my $dp;
  my $moddrv = $entryValueP->{"ModDrv"};
  my $mod = $entryValueP->{'ModuleName'};
	if    ($moddrv eq "RawText") {$dp = "./modules/texts/rawtext/".lc($mod)."/";}
	elsif ($moddrv eq "zText") {$dp = "./modules/texts/ztext/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom") {$dp = "./modules/comments/rawcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom4") {$dp = "./modules/comments/rawcom4/".lc($mod)."/";}
	elsif ($moddrv eq "zCom") {$dp = "./modules/comments/zcom/".lc($mod)."/";}
	elsif ($moddrv eq "HREFCom") {$dp = "./modules/comments/hrefcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawFiles") {$dp = "./modules/comments/rawfiles/".lc($mod)."/";}
	elsif ($moddrv eq "RawLD") {$dp = "./modules/lexdict/rawld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawLD4") {$dp = "./modules/lexdict/rawld4/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "zLD") {$dp = "./modules/lexdict/zld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawGenBook") {$dp = "./modules/genbook/rawgenbook/".lc($mod)."/".lc($mod);}
	else {
		&Log("ERROR: ModDrv \"".$entryValueP->{"ModDrv"}."\" is unrecognized.\n");
		die;
	}
	if ($entryValueP->{"DataPath"}) {
		if ($entryValueP->{"DataPath"} ne $dp) {
			&Log("ERROR: DataPath is \"".$entryValueP->{"DataPath"}."\" expected \"$dp\". Remove bad DataPath entry from config.conf.\n");
			die;
		}
	}
  else {$entryValueP->{"DataPath"} = $dp;}

  my $type = 'genbook';
  if ($moddrv =~ /LD/) {$type = 'dictionary';}
  elsif ($moddrv =~ /Text/) {$type = 'bible';}
  elsif ($moddrv =~ /Com/) {$type = 'commentary';}
  
  $entryValueP->{"Encoding"} = "UTF-8";
  $entryValueP->{"SourceType"} = 'OSIS'; # Wait until TEI filters are available to change this to: ($IS_usfm2osis && $moddrv =~ /LD/ ? 'TEI':'OSIS');
 
  if ($entryValueP->{"SourceType"} eq "OSIS") {
    my $osisVersion = $OSISSCHEMA;
    $osisVersion =~ s/(\s*osisCore\.|\.xsd\s*)//ig;
    $entryValueP->{"OSISVersion"} = $osisVersion;
    
    if ($type eq 'bible' || $type eq 'commentary') {
      $entryValueP->{'GlobalOptionFilter'} .= "<nx/>OSISFootnotes<nx/>OSISHeadings<nx/>OSISScripref";
      if (open(OSIS, "<:encoding(UTF-8)", $moduleSource)) {
        while(<OSIS>) {
          if ($_ =~ /<reference [^>]*type="x-glossary"/) {
            $entryValueP->{'GlobalOptionFilter'} .= "<nx/>OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On\n";
            last;
          }
        }
        close(OSIS);
      
        # get scope
        if ($type eq 'bible' || $type eq 'commentary') {
          require("$SCRD/scripts/getScope.pl");
          $entryValueP->{'Scope'} = &getScope($entryValueP->{'Versification'}, $moduleSource);
        }
      }
    }
  }
  else {
    $entryValueP->{"OSISVersion"} = '';
    $entryValueP->{'GlobalOptionFilter'} =~ s/<nx\/>OSIS.*?(?=(<|$))//g;
  }
  
  if ($type eq 'dictionary') {
    $entryValueP->{'SearchOption'} = "IncludeKeyInSearch";
    # The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
    if ($UPPERCASE_DICTIONARY_KEYS) {$entryValueP->{'CaseSensitiveKeys'} = "true";}
  }
  
  my @tm = localtime(time);
  $entryValueP->{'SwordVersionDate'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  
  return $entryValueP;
}


# Reads a conf file and returns a hash of its contents.
sub readConf($) {
  my $conf = shift;
  
  my %entryValue;
  open(CONF, "<:encoding(UTF-8)", $conf) || die "Could not open $conf\n";
  while(<CONF>) {
    if ($_ =~ /^\s*(.*?)\s*=\s*(.*?)\s*$/) {
      if ($entryValue{$1} ne '') {$entryValue{$1} .= "<nx/>".$2;}
      else {$entryValue{$1} = $2;}
    }
    if ($_ =~ /^\s*\[(.*?)\]\s*$/) {$entryValue{'ModuleName'} = $1;}
  }
  close(CONF);

  if (!$entryValue{"ModuleName"}) {
		&Log("ERROR: Module name must be specified at top of config.conf like: [MYMOD]\n");
		die;
	}
  
  if (!$entryValue{"ModDrv"}) {
		&Log("ERROR: ModDrv must be specified in config.conf.\n");
		die;
	}
  
  return \%entryValue;
}


sub setConfGlobals(\%) {
  my $entryValueP = shift;

  # Globals (mostly for brevity)
  $ConfEntryP = $entryValueP;
  $MOD = $ConfEntryP->{'ModuleName'};
  $MODLC = lc($MOD);
  $MODDRV = $ConfEntryP->{'ModDrv'};
  $VERSESYS = $ConfEntryP->{'Versification'};
  
  $MODPATH = &dataPath2RealPath($entryValueP->{"DataPath"});
  
  return $entryValueP;
}


sub dataPath2RealPath($) {
  my $datapath = shift;
  $MODPATH =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $MODPATH =~ s/[\\\/]\s*$//; # remove ending slash
  $MODPATH =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
  return $datapath;
}


# Formerly there was an addRevisionToCF function which wrote the SVN rev
# into the CF_ files. But this caused these input files to be rev-ed even
# when there were no changes to the file settings. This was really a
# bother. So, the rev is now written to the LOG file, and the 
# function below is used to remove the old SVN rev from the CF_ files
# if it's there. 
sub removeRevisionFromCF($) {
  my $f = shift;
  
  my $changed = 0;
  my $msg = "# osis-converters rev-";
  if (open(RCMF, "<:encoding(UTF-8)", $f)) {
    open(OCMF, ">:encoding(UTF-8)", "$f.tmp") || die "ERROR: Could not open \"$f.tmp\".\n";
    my $l = 0;
    while(<RCMF>) {
      $l++;
      if ($l == 1 && $_ =~ /\Q$msg\E(\d+)/) {
        $changed = 1;
        next;
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
sub uc2($) {
  my $t = shift;
  
  # Form for $i: a->A b->B c->C ...
  if ($SPECIAL_CAPITALS) {
    my $r = $SPECIAL_CAPITALS;
    $r =~ s/(^\s*|\s*$)//g;
    my @trs = split(/\s+/, $r);
    for (my $i=0; $i < @trs; $i++) {
      my @tr = split(/->/, $trs[$i]);
      $t =~ s/$tr[0]/$tr[1]/g;
    }
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
  my $testamentP = shift;
  
  my $INFILE = "$SCRD/scripts/Canon/canon".($VSYS && $VSYS ne "KJV" ? "_".lc($VSYS):"").".h";
  my $inOT, $inNT, $inVM;
  my $vsys = "unset";
  my %bookLongName, %bookChapters, %bookTest;
  my @VM;
  my $booknum = 1;

  # Collect canon information from header file
  copy($INFILE, "$INFILE.tmp");
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
        if ($testamentP) {$testamentP->{$bk} = ($inOT ? "OT":"NT");}
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


sub sortSearchTermKeys($$) {
  my $aa = shift;
  my $bb = shift;
  
  while ($aa =~ /["\s]+(<[^>]*>\s*)+$/) {$aa =~ s/["\s]+(<[^>]*>\s*)+$//;}
  while ($bb =~ /["\s]+(<[^>]*>\s*)+$/) {$bb =~ s/["\s]+(<[^>]*>\s*)+$//;}
  
  length($bb) <=> length($aa)
}


# add dictionary links as described in $DWF to all elements pointed to 
# by $eP array pointer.
sub addDictionaryLinks(\@$) {
  my $eP = shift; # array of elements (NOTE: element children are not touched)
  my $entry = shift; # should be NULL if not adding SeeAlso links

  if ($entry) {
    my $entryOsisRef = &entry2osisRef($MOD, $entry);
    if (!$NoOutboundLinks{'haveBeenRead'}) {
      foreach my $n ($XPC->findnodes('descendant-or-self::entry[@noOutboundLinks=\'true\']', $DWF)) {
        foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
      }
      $NoOutboundLinks{'haveBeenRead'}++;
    }
    if ($NoOutboundLinks{$entryOsisRef}) {return;}
  }
  
  foreach my $elem (@$eP) {
    if ($MODDRV =~ /LD/ && $XPC->findnodes("self::$KEYWORD", $elem)) {next;}
    my @textchildren = $XPC->findnodes('child::text()', $elem);
    my $text, matchedPattern;
    foreach my $textchild (@textchildren) {
      $text = $textchild->data();
      my $done;
      do {
        $done = 1;
        my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
        foreach my $part (@parts) {
          if ($part =~ /<reference.*?<\/reference[^>]*>/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $elem, $entry)) {$done = 0;}
        }
        $text = join('', @parts);
      } while(!$done);
      $textchild->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($text), $textchild);
      $textchild->unbindNode();
    }
  }
}


# Searches and replaces $$tP text for a single dictionary link, according 
# to the $DWF file, and logs any result. If a match is found, the proper 
# reference tags are inserted,and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$) {
  my $tP = shift;
  my $elem = shift;
  my $entry = shift; # for SeeAlso links only
  
  if ($$tP =~ /^\s*$/) {return '';}
  
  my $matchedPattern = '';
  my $dbg;
  
  if (!@MATCHES) {@MATCHES = $XPC->findnodes("//match", $DWF);}
  
  my $context;
  my $multiples_context;
  if ($entry) {$context = $entry; $multiples_context = $entry;}
  else {
    $context = &bibleContext($elem);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &myContext('ot', $context);
  my $contextIsNT = &myContext('nt', $context);
  
  my $a;
  foreach my $m (@MATCHES) {
    &dbg(sprintf("%16s %10s = ", $context, $elem->localName));
    if ($entry && &matchInEntry($m, $entry)) {&dbg("00\n"); next;}
    if (!$contextIsOT && &attributeIsSet('onlyOldTestament', $m)) {&dbg("10\n"); next;}
    if (!$contextIsNT && &attributeIsSet('onlyNewTestament', $m)) {&dbg("20\n"); next;}
    if ($elem->localName eq 'hi' && !&attributeIsSet('highlight', $m)) {&dbg("30\n"); next;}
    if ($MULTIPLES{$m->unique_key} && !&attributeIsSet('multiple', $m)) {&dbg("40\n"); next;}
    if ($a = &getAttribute('context', $m)) {if (!&myContext($a, $context)) {&dbg("50\n"); next;}}
    if ($a = &getAttribute('notContext', $m)) {if (&myContext($a, $context)) {&dbg("60\n"); next;}}
    if ($a = &getAttribute('withString', $m)) {if (!&haveString($a, $context, $elem)) {&dbg("70\n"); next;}}
    
    my $p = $m->textContent;
    
    if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {&Log("ERROR: Bad match regex: \"$p\"\n"); &dbg("80\n"); next;}
    my $pm = $1; my $pf = $2;
    
    # handle PUNC_AS_LETTER word boundary matching issue
    if ($PUNC_AS_LETTER) {$pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;}
    
    # handle xml decodes
    $pm = decode_entities($pm);
    
    # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
    my $t = $$tP;
    my $i = $pf =~ s/i//;
    $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? uc2($2):$2);/ge;
    if ($i) {$t = uc2($t);}
    if ($pf =~ /(\w+)/) {&Log("ERROR: Regex flag \"$1\" not supported in \"".$m->textContent."\"");}
   
    # finally do the actual MATCHING...
    if ($t !~ /$pm/) {&dbg("-\n"); next;}
      
    my $is = $-[$#+];
    my $ie = $+[$#+];
    
    # if a (?'link'...) named group 'link' exists, use it instead
    if (defined($+{'link'})) {
      my $i; for ($i=0; $i <= $#+; $i++) {if ($$i eq $+{'link'}) {last;}}
      $is = $-[$i];
      $ie = $+[$i];
    }
    
    &dbg("$pm\n$t\n$is, $ie, ".$+{'link'}.".\n");
    $matchedPattern = $m->textContent;
    
    my $osisRef = @{$XPC->findnodes('ancestor::entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
    my $name = @{$XPC->findnodes('preceding-sibling::name[1]', $m)}[0]->textContent;
    my $attribs = "osisRef=\"$osisRef\" type=\"".($MODDRV =~ /LD/ ? 'x-glosslink':'x-glossary')."\"";
    my $match = substr($$tP, $is, ($ie-$is));
    
    substr($$tP, $ie, 0, "</reference>");
    substr($$tP, $is, 0, "<reference $attribs>");
    
    # record stats...
    $EntryHits{$name}++;
    
    my $logContext = $context;
    $logContext =~ s/\..*$//; # keep book/entry only
    $EntryLink{"links in $logContext to ".&decodeOsisRef($osisRef)}++;
    
    my $dict;
    foreach my $sref (split(/\s+/, $osisRef)) {
      my $e = &osisRef2Entry($sref, \$dict);
      $Replacements{$e.": ".$match.", ".$dict}++;
    }

    $MULTIPLES{$m->unique_key}++;
    last;
  }
 
  return $matchedPattern;
}


sub matchInEntry($$) {
  my $m = shift;
  my $entry = shift;
  
  my $osisRef = @{$XPC->findnodes('ancestor::entry[1]', $m)}[0]->getAttribute('osisRef');
  foreach my $ref (split(/\s+/, $osisRef)) {
    if (&osisRef2Entry($ref) eq $entry) {return 1;}
  }
  return 0;
}


sub osisRef2Entry($\$$) {
  my $osisRef = shift;
  my $modP = shift;
  my $loose = shift;
  
  if ($osisRef !~ /^(\w+):(.*)$/) {
    if ($loose) {return &decodeOsisRef($osisRef);}
    &Log("ERROR: problem with osisRef \"$osisRef\"\n");
  }
  if ($modP) {$$modP = $1;}
  return &decodeOsisRef($2);
}


sub entry2osisRef($$) {
  my $mod = shift;
  my $ref = shift;
  return $mod.":".encodeOsisRef($ref);
}


sub attributeIsSet($$) {
  my $a = shift;
  my $m = shift;
  
  return scalar(@{$XPC->findnodes("ancestor-or-self::*[\@$a][1][\@$a='true']", $m)});
}


sub getAttribute($$) {
  my $a = shift;
  my $m = shift;
  
  my @r = $XPC->findnodes("ancestor-or-self::*[\@$a][1]", $m);
  
  return (@r ? @r[0]->getAttribute($a):0);
}


sub dbg($) {
  my $p = shift;
  if ($DEBUG) {&Log($p);}
}


# return context if context is a part of $test, else 0
# $context may be a dictionary entry or a special Bible range - see bibleContext()
# $test can be:
#   keyword - return context IF it is part of keyword's scope
#   encoded osisRef - return context IF it is within scope of osisRef (which may include multiple ranges)
# else return 0
sub myContext($$) {
  my $test = shift;
  my $context = shift;

  my $mod;
  my $test2 = $test;
  if ($test eq 'ot') {$test2 = $OT_BOOKS;}
  elsif ($test eq 'nt') {$test2 = $NT_BOOKS;}
  foreach my $t (split(/\s+/, $test2)) {
    if ($t =~ /^\s*$/) {next;}
    my $e = &osisRef2Entry($t, \$mod, 1);
    foreach my $refs (&context2array($context)) {
      if ($refs =~ /\Q$e\E/i) {return $context;}
    }
  }
  
  return 0;
}


sub haveString($$$) {
  my $s = shift;
  my $context = shift;
  my $elem = shift;
 
  &Log("ERROR: \"withString\" is not implemented yet\n");
  return 0;
}


# return special Bible reference for $elem:
# Gen.0.0.0 = intro
# Gen.1.0.0 = intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext($) {
  my $elem = shift;
  
  my $context = '';
  my @c = $XPC->findnodes('preceding::osis:verse[@osisID][1]', $elem);
  if (!@c) {@c = $XPC->findnodes('preceding::osis:chapter[@osisID][1]', $elem);}
  if (!@c) {@c = $XPC->findnodes('ancestor-or-self::osis:chapter[@osisID][1]', $elem);}
  if (!@c) {@c = $XPC->findnodes('ancestor-or-self::osis:div[@type=\'book\'][@osisID][1]', $elem);}
  if (@c) {
    my $id = @c[0]->getAttribute('osisID');
    $context = ($id ? $id:"unk.0.0.0");
    if ($id =~ /^\w+$/) {$context .= ".0.0.0";}
    elsif ($id =~ /^\w+\.\d+$/) {$context .= ".0.0";}
    elsif ($id =~ /^\w+\.\d+\.(\d+)$/) {$context .= ".$1";}
    elsif ($id =~ /^(\w+\.\d+\.\d+) .*\w+\.\d+\.(\d+)$/) {$context = "$1.$2";}
  }
  else {&Log("ERROR: Could not determine context of \"$elem\"\n"); return 0;}
  
  return $context;
}


# return array of refs from context, since context may be a bibleContext 
# covering a range of verses. Returned refs are NOT encoded osisRefs.
sub context2array($) {
  my $context = shift;
  
  my @refs;
  if ($context =~ /^(\w+\.\d+)\.(\d+)\.(\d+)$/) {
    my $bc = $1;
    my $v1 = $2;
    my $v2 = $3;
    for (my $i = $v1; $i <= $v2; $i++) {push(@refs, "$bc.$i");}
  }
  else {push(@refs, $context);}
  
  return @refs;
}


# Check all reference links, and report any errors
sub checkDictReferences($) {
  my $in_file = shift;
  
  my %replaceList;
  
  &Log("\nCHECKING DICTIONARY REFERENCE OSISREF TARGETS IN $in_file...\n");
  open(INF, "<:encoding(UTF-8)", $in_file) || die "ERROR: Could not check $in_file.\n";
  my $line = 0;
  my $total = 0;
  my $errors = 0;
  while(<INF>) {
    $line++;
    while ($_ =~ s/(<reference\b[^>]*type="(x-glossary|x-glosslink)"[^>]*>)//) {
      my $r = $1;

      $total++;
      if ($r !~ /<reference [^>]*osisRef="([^\"]+)"/) {
        $errors++;
        &Log("ERROR: line $line: missing osisRef in glossary link \"$r\".\n");
        next;
      }
      my $osisRef = $1;
      
      my @srefs = split(/\s+/, $osisRef);
      foreach my $sref (@srefs) {
        my @entry = $XPC->findnodes('//entry[@osisRef=\''.$sref.'\']', $DWF);
        if (!@entry) {
          $errors++;
          &Log("ERROR: line $line: osisRef \"$sref\" not found in dictionary words file\n");
        }
      }
    }
  }
  close(INF);
  &Log("REPORT: $total dictionary links found and checked. ($errors unknown or missing targets)\n");
}


# Print log info for a word file
sub logDictLinks() {
  my $total = 0;
  foreach my $osisRef (sort keys %EntryHits) {$total += $EntryHits{$osisRef};}
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//entry/name/text()', $DWF);
  my %entriesH; foreach my $e (@entries) {$entriesH{$e}++;}
  foreach my $e (sort keys %entriesH) {
    my $match = 0;
    foreach my $dh (keys %EntryHits) {
      if ($e eq $dh) {$match = 1;}
    }
    if (!$match) {$nolink .= $e."\n"; $numnolink++;}
  }
  
  &Log("\n\n");
  &Log("REPORT: Glossary entries from $DICTIONARY_WORDS which have no links in the text: ($numnolink instances)\n");
  if ($nolink) {
    &Log("NOTE: You may want to link to these entries using a different word or phrase. To do this, edit the\n");
    &Log("$DICTIONARY_WORDS file.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  &Log("\n");
  
  &Log("REPORT: Words/phrases converted into links using $DICTIONARY_WORDS: ($total instances)\n");
  &Log("NOTE: The following list must be looked over carefully. Glossary entries are matched\n"); 
  &Log("in the text using the match elements in the $DICTIONARY_WORDS file.\n");
  &Log("\n");
  &Log("GLOSSARY_ENTRY: LINK_TEXT, MODNAME(s), NUMBER_OF_LINKS\n");
  foreach my $rep (sort keys %Replacements) {
    &Log("$rep, ".$Replacements{$rep}."\n");
  }
  &Log("\n\n");
  
  $n = 0; foreach my $k (keys %EntryLink) {$n += $EntryLink{$k};}
  &Log("REPORT: Links created: ($n instances)\n");
  foreach my $k (sort keys %EntryLink) {&Log(sprintf("%3i %s\n", $EntryLink{$k}, $k));}
}


sub dictWordsHeader() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!--
  Use the following attributes to control link placement:
  onlyNewTestament=\"true|false\"
  onlyOldTestament=\"true|false\"
  context=\"space separated list of osisRefs, or osisRef-encoded dictionary entries in which to create links (default is all)\"
  notContext=\"space separated list of osisRefs, or osisRef-encoded dictionary entries in which not to create links (default is none)\"
  withString=\"limit matches to verses or entries which also contain this literal string\"
  highlight=\"true|false: allow links within bold, italic or other highlighted text (default is false)\"
  multiple=\"true|false: allow more than one identical link per entry or chapter (default is false)\"

  Entry elements may contain the following attributes:
  <entry osisRef=\"osisRef location(s) of this entry's source target(s)\"
         noOutboundLinks=\"true|false: set true if entry should not contain any see-also links\">

  Match patterns can be any perl match regex. The entire match (if there 
  are no capture groups), or the last matching group, or else a group 
  named 'link', will become the link's inner text.
  
  IMPORTANT: 
  for case insensitive matches to work, all case insensitive text MUST be 
  surrounded by the \\Q...\\E quote operators, and the /i regex flag must 
  be included. Any other case related Perl constructs will not always work.

-->\n";
}


sub writeDictionaryWordsXML($$) {
  my $in_file = shift;
  my $out_xml = shift;
  
  my @keywords = &getDictKeys($in_file);
  
  my %keys; foreach my $k (@keywords) {$keys{$k}++;}
  open(DWORDS, ">:encoding(UTF-8)", $out_xml) or die "Could not open $out_xml";
  print DWORDS &dictWordsHeader();
  print DWORDS "
<dictionaryWords version=\"1.0\">
<div highlight=\"false\" multiple=\"false\">\n";
  foreach my $k (sort {length($b) <=> length($a)} keys %keys) {
    print DWORDS "
  <entry osisRef=\"".&entry2osisRef($MOD, $k)."\">
    <name>".$k."</name>
    <match>/\\b(\\Q".$k."\\E)\\b/i</match>
  </entry>\n";
  }
  print DWORDS "
</div>
</dictionaryWords>";
  close(DWORDS);
  
  &checkEntryNames(\@keywords);
  
  # if there is no project dictionary words file, create it
  if (! -e "$INPD/$DICTIONARY_WORDS") {copy($out_xml, "$INPD/$DICTIONARY_WORDS");}
  $DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
}


# check that the entries in an imp or osis file are included in the
# dictionaryWords file. If the difference is only in capitalization,
# which occurs when converting from DictionaryWords.txt to DictionaryWords.xml,
# then fix these.
sub checkDictionaryWordsXML($) {
  my $imp_or_osis = shift;
  
  my $dw_file = "$INPD/$DICTIONARY_WORDS";
  &Log("\n--- CHECKING ENTRIES IN: $imp_or_osis FOR INCLUSION IN: $DICTIONARY_WORDS\n", 1);
  
  my $update = 0;
  
  my @sourceEntries = &getDictKeys($imp_or_osis);
  
  my @dwfEntries = $XPC->findnodes('//entry[@osisRef]/@osisRef', $DWF);
  
  my $allmatch = 1; my $mod;
  foreach my $es (@sourceEntries) {
    my $match = 0;
    foreach my  $edr (@dwfEntries) {
      my $ed = &osisRef2Entry($edr->value, \$mod);
      if ($es eq $ed) {$match = 1; last;}
      elsif (uc2($es) eq uc2($ed)) {
        $match = 1;
        $update++;
        $edr->setValue(entry2osisRef($mod, $es));
        my $name = @{$XPC->findnodes('../child::name[1]/text()', $edr)}[0];
        if (uc2($name) ne uc2($es)) {&Log("ERROR: \"$name\" does not corresponding to \"$es\" in osisRef \"$edr\" of $DICTIONARY_WORDS\n");}
        else {$name->setData($es);}
        last;
      }
    }
    if (!$match) {&Log("ERROR: Missing entry \"$es\" in $DICTIONARY_WORDS\n"); $allmatch = 0;}
  }
  
  if ($update) {
    open(OUTF, ">$dw_file.tmp") or die "Could not open $DICTIONARY_WORDS.tmp\n";
    print OUTF $DWF->toString();
    close(OUTF);
    unlink($dw_file); rename("$dw_file.tmp", $dw_file);
    &Log("NOTE: Updated $update entries in $dw_file\n");
    
    $DWF = $XML_PARSER->parse_file($dw_file);
  }
  
  if ($allmatch) {&Log("All entries are included.\n");}
  
}


sub getDictKeys($) {
  my $in_file = shift;
  
  my @keywords;
  if ($in_file =~ /\.(xml|osis)$/i) {
    my $xml = $XML_PARSER->parse_file($in_file);
    $mod = @{$XPC->findnodes('//osis:osisText/@osisIDWork', $xml)}[0]->textContent();
    @keywords = $XPC->findnodes('//osis:seg[@type="keyword"]', $xml);
    foreach my $kw (@keywords) {$kw = $kw->textContent();}
  }
  else {
    open(IMPIN, "<:encoding(UTF-8)", $in_file) or die "Could not open IMP $in_file";
    while (<IMPIN>) {
      if ($_ =~ /^\$\$\$\s*(.*?)\s*$/) {push(@keywords, $1);}
    }
    close(IMPIN);
  }
  
  return @keywords;
}


# report various info about the entries in a dictionary
sub checkEntryNames(\@) {
  my $entriesP = shift;
  
  foreach my $name (@$entriesP) {$entries{$name}++;}
  
  foreach my $e (keys %entries) {
    if ($entries{$e} > 1) {
      &Log("ERROR: Entry \"$e\" appears more than once. These must be merged.\n"); 
      die;
    }
  }

  my $total = 0;
  my %instances;
  foreach my $e1 (keys %entries) {
    foreach my $e2 (keys %entries) {
      if ($e1 eq $e2) {next;}
      my $euc1 = &uc2($e1);
      my $euc2 = &uc2($e2); 
      if ($euc1 =~ /\Q$euc2\E/) {
        $total++;
        $instances{"\"$e1\" contains \"$e2\"\n"}++;
      }
    }
  }
  &Log("\nREPORT: Glossary entry names which are repeated in other entry names: ($total instances)\n");
  if ($total) {
    &Log("NOTE: Topics covered by these entries may overlap or be repeated.\n");
    foreach my $i (sort keys %instances) {&Log($i);}
  }

  $total = 0;
  undef(%instances); my %instances;
  foreach my $e (keys %entries) {
    if ($e =~ /(-|,|;|\[|\()/) {
      $total++;
      $instances{"$e\n"}++;
    }
  }
  &Log("\nREPORT: Compound glossary entry names: ($total instances)\n");
  if ($total) {
    &Log("NOTE: Multiple <match> elements may be added to $DICTIONARY_WORDS to match each part.\n");
    foreach my $i (sort keys %instances) {&Log($i);}
  }
}


# copies a directory to a possibly non existing destination directory
sub copy_dir($$$$) {
  my $id = shift;
  my $od = shift;
  my $overwrite = shift; # merge with existing directories and overwrite existing files
  my $noRecurse = shift; # don't recurse into subdirs
  my $keep = shift; # a regular expression matching files to be copied (null means copy all)
  my $skip = shift; # a regular expression matching files to be skipped (null means skip none). $skip overrules $keep

  if (!-e $id || !-d $id) {
    &Log("ERROR copy_dir: Source does not exist or is not a direcory: $id\n");
    return 0;
  }
  if (!$overwrite && -e $od) {
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
    if (!$noRecurse && -d $if) {&copy_dir($if, $of, $noRecurse, $keep, $skip);}
    elsif ($skip && $if =~ /$skip/) {next;}
    elsif (!$keep || $if =~ /$keep/) {
			if ($overwrite && -e $of) {unlink($of);}
			copy($if, $of);
		}
  }
  return 1;
}


# deletes files recursively without touching dirs
sub delete_files($) {
  my $dir = shift;
  my $success = 0;
  if (!opendir(CHDIR, $dir)) {return 0;}
  my @listing = readdir(CHDIR);
  closedir(CHDIR);
  foreach my $entry (@listing) {
    if ($entry =~ /^\.+$/) {next;}
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


sub is_usfm2osis($) {
  my $osis = shift;
  my $usfm2osis = 0;
  open(TEST, "<$osis") || die "Could not open $osis\n";
  while(<TEST>) {if ($_ =~ /<!--[^!]*\busfm2osis.py\b/) {$usfm2osis = 1; last;}}
  close(TEST);
  if ($usfm2osis) {&Log("\n--- OSIS file was created by usfm2osis.py.\n");}
  return $usfm2osis;
}


sub usfm2osisXSLT($$$) {
  my $osis = shift;
  my $xsl = shift;
  my $out = shift;

  &Log("\n--- Running XSLT...\n");
  if (! -e $xsl) {&Log("ERROR: Could not locate required XSL file: \"$xsl\"\n"); die;}
  else {
    my $cmd = '';
    if ("$^O" =~ /MSWin32/i) {
      # http://www.microsoft.com/en-us/download/details.aspx?id=21714
      $cmd = "msxsl.exe " . &escfile($osis) . " " . &escfile($xsl) . " -o " . &escfile($out);
    }
    elsif ("$^O" =~ /linux/i) { 
      $cmd = "saxonb-xslt -xsl:" . &escfile($xsl) . " -s:" . &escfile($osis) . " -o:" . &escfile($out);
    }
    else {
      &Log("ERROR: an XSLT 2.0 converter has not been chosen yet for this operating system.");
    }
    if ($cmd) {
      &Log("$cmd\n");
      system($cmd);
    }
  }
}


sub id2refs($) {
  my $osisID = shift;
  my @refs;
  if ($osisID =~ /^([^\.]+\.\d+)\.(\d+)-(\d+)$/) {
    my $bc = $1;
    my $v1 = $2;
    my $v2 = $3;
    for (my $v=$v1; $v<=$v2; $v++) {push(@refs, "$bc.$v");}
  }
  elsif ($osisID =~ /^([^\.]+\.\d+\.\d+(\s|$))+/) {
    @refs = split(/\s+/, $osisID);
  }
  else {&Log("ERROR Bad id \"$osisID\"\n");}
  
  return @refs;
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


sub copy_images_to_module($$) {
	my $imgFile = shift;
  my $dest = shift;
  
	&Log("\n--- COPYING $MOD image(s) \"$imgFile\"\n");
	if (-d $imgFile) {
		my $imagePaths = "INCLUDE IMAGE PATHS.txt";
		&copy_dir($imgFile, "$dest/images", 1, 0, 0, quotemeta($imagePaths));
		if (-e "$imgFile/$imagePaths") { # then copy any additional images located in $imagePaths file
			open(IIF, "<$imgFile/$imagePaths") || die "Could not open \"$imgFile/$imagePaths\"\n";
			while (<IIF>) {
				if ($_ =~ /^\s*#/) {next;}
				chomp;
				if ($_ =~ /^\./) {$_ = "$imgFile/$_";}
				if (-e $_) {&copy_images_to_module($_, $dest);}
				else {&Log("ERROR: Image directory listed in \"$imgFile/$imagePaths\" was not found: \"$_\"\n");}
			}
			close(IIF);
		}
	}
	else {
		if (-e "$dest/images/$imgFile") {unlink("$dest/images/$imgFile");} 
		copy($imgFile, "$dest/images");
	}
}


sub writeInstallSizeToConf($$) {
  my $modpath = shift;
  my $conf = shift;
  
  $installSize = 0;             
  find(sub { $installSize += -s if -f $_ }, $modpath);
  open(CONF, ">>:encoding(UTF-8)", $conf) || die "Could not append to conf $conf\n";
  print CONF "\nInstallSize=$installSize\n";
  close(CONF);
}


# make a zipped copy of a module
sub zipModule($$) {
  my $moddir = shift;
  my $zipfile = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  if ("$^O" =~ /MSWin32/i) {
    my $cmd = "7za a -tzip ".&escfile($zipfile)." -r ".&escfile("$moddir\\*");
    &Log($cmd, 1);
    `$cmd`;
  }
  else {
    my $orig = `pwd`; chomp($orig);
    chdir($moddir);
    my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
    &Log($cmd, 1);
    `$cmd`;
    chdir($orig);
  }
}


# I could not find a way to get XML::LibXML::DocumentFragment->toString()
# to STOP converting high-order unicode characters to entities when 
# serializing attributes. But regular documents, with proper declarations, 
# don't have this problem. So here is a solution.
sub fragmentToString($$) {
  my $doc_frag = shift;
  my $rootTag = shift;
  
  my $rootTagName = $rootTag;
  if ($rootTagName !~ s/^\s*<(\w+).*$/$1/) {&Log("ERROR: Bad tag \"$rootTag\" in fragmentToString()\n");}
  
  my $dom = XML::LibXML::Document->new("1.0", "UTF-8");
  $dom->insertBefore($doc_frag, NULL);
  my $doc = $dom->toString();
  
  # remove xml declaration
  if ($doc !~ s/^\s*<\?xml[^>]*\?>[\s\n]*//) {&Log("ERROR: problem removing xml declaration \"$doc\" fragmentToString()\n");}
  
  # remove root tags
  if ($doc !~ s/(^$rootTag|<\/$rootTagName>[\s\n]*$)//g) {&Log("ERROR: problem removing root tags \"$doc\" fragmentToString()\n");} 
  
  return $doc;
}


sub validateOSIS($) {
  my $osis = shift;
  
  # validate new OSIS file against schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  $cmd = ("$^O" =~ /linux/i ? "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ":'');
  $cmd .= $XMLLINT."xmllint --noout --schema \"http://www.bibletechnologies.net/$OSISSCHEMA\" ".&escfile($osis)." 2>> ".&escfile($LOGFILE);
  &Log("$cmd\n");
  system($cmd);
  &Log("END OSIS VALIDATION\n");
}

# -1 = only log file (ignore $NOCONSOLELOG)
#  0 = log file (+ console if !$NOCONSOLELOG)
#  1 = log file + console
#  2 = only console
sub Log($$) {
  my $p = shift; # log message
  my $h = shift; # -1 = hide from console, 1 = show in console, 2 = only console
  
  # remove file paths
  $p =~ s/(\Q$INPD\E|\Q$OUTDIR\E)\/?//g;
  
  if ((!$NOCONSOLELOG && $h!=-1) || $h>=1 || $p =~ /error/i) {print encode("utf8", "$p");}
  if ($LOGFILE && $h!=2) {
    open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
    print LOGF $p;
    close(LOGF);
  }
}

1;
