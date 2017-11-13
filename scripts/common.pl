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
use File::Find;
use Cwd;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

$KEYWORD = "osis:seg[\@type='keyword']"; # XPath expression matching dictionary entries in OSIS source
$OSISSCHEMA = "http://www.crosswire.org/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd";
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
$FNREFSTART = "<reference type=\"x-note\" osisRef=\"TARGET\">";
$FNREFEND = "</reference>";
$FNREFEXT = "!note.n";
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
$OT_BOOKS = "1Chr 1Kgs 1Sam 2Chr 2Kgs 2Sam Amos Dan Deut Eccl Esth Exod Ezek Ezra Gen Hab Hag Hos Isa Judg Jer Job Joel Jonah Josh Lam Lev Mal Mic Nah Neh Num Obad Prov Ps Ruth Song Titus Zech Zeph";
$NT_BOOKS = "1Cor 1John 1Pet 1Thess 1Tim 2Cor 2John 2Pet 2Thess 2Tim 3John Acts Col Eph Gal Heb Jas John Jude Luke Matt Mark Phlm Phil Rev Rom Titus";
@USFM2OSIS_PY_SPECIAL_BOOKS = ('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other');
$DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb or self::osis:hi]";
$DICTIONARY_WORDS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
$DICTIONARY_WORDS = "DictionaryWords.xml";
$UPPERCASE_DICTIONARY_KEYS = 1;
$NOCONSOLELOG = 1;
$HOME_DIR = `echo \$HOME`; chomp($HOME_DIR);

require("$SCRD/scripts/getScope.pl");
require("$SCRD/scripts/toVersificationBookOrder.pl");

sub init($) {
  my $quiet = shift;
  
  if (!$INPD) {$INPD = "."};
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  $INPD =~ s/[\\\/](sfm|GoBible|eBook)$//; # allow using a subdir as project dir
  if (!-e $INPD) {
    print "Project directory \"$INPD\" does not exist. Exiting.\n";
    exit;
  }
  chdir($SCRD); # had to wait until absolute $INPD was set by rel2abs

  $GITHEAD = `git rev-parse HEAD 2>tmp.txt`; unlink("tmp.txt");
  
  $SCRIPT_NAME = $SCRIPT; $SCRIPT_NAME =~ s/^.*\/([^\/]+)\.[^\/\.]+$/$1/;
  
  if (!-e "$SCRD/paths.pl") {
    if (!open(PATHS, ">$SCRD/paths.pl")) {&Log("Could not open \"$SCRD/paths.pl\". Exiting.\n"); die;}
    print PATHS "1;\n";
    close(PATHS);
  }
  require "$SCRD/paths.pl";
  
  &initLibXML();
  
  # Read BookNames.xml, if available
  if (-e "$INPD/sfm/BookNames.xml") {
    my $bknames = $XML_PARSER->parse_file("$INPD/sfm/BookNames.xml");
    my @bkelems = $XPC->findnodes('//book[@code]', $bknames);
    if (@bkelems[0]) {
      &Log("NOTE: Reading localized book names from \"$INPD/sfm/BookNames.xml\"\n");
    }
    foreach my $bkelem (@bkelems) {
      my $bk = getOsisName($bkelem->getAttribute('code'), 1);
      if (!$bk) {next;}
      $BOOKNAMES{$bk}{'abbr'} = $bkelem->getAttribute('abbr');
      $BOOKNAMES{$bk}{'short'} = $bkelem->getAttribute('short');
      $BOOKNAMES{$bk}{'long'} = $bkelem->getAttribute('long');
    }
  }

  &checkAndWriteDefaults($INPD);
  
  $CONFFILE = "$INPD/config.conf";
  
  if (!-e $CONFFILE) {
    &Log("ERROR: Could not find or create a \"$CONFFILE\" file.
\"$INPD\" may not be an osis-converters project directory.
A project directory must, at minimum, contain an \"sfm\" subdirectory.
\n".encode("utf8", $LogfileBuffer)."\n");
    die;
  }
  
  $OUTDIR = &getOUTDIR($INPD);
  if (!-e $OUTDIR) {make_path($OUTDIR);}
  
  $AUTOMODE = ($LOGFILE ? 1:0);
  if (!$LOGFILE) {$LOGFILE = "$OUTDIR/OUT_$SCRIPT_NAME.txt";}
  if (!$AUTOMODE && -e $LOGFILE) {unlink($LOGFILE);}
  
  &initOutputFiles($SCRIPT_NAME, $INPD, $OUTDIR, $AUTOMODE);
  
  &setConfGlobals(&updateConfData(&readConf($CONFFILE)));
  
  if ($SCRIPT_NAME !~ /osis2ebook/) {&Log("start time: ".localtime()."\n");}
      
  # if all dependencies are not met, this asks to run in Vagrant
  &checkDependencies($SCRD, $SCRIPT, $INPD, $quiet);
  
  $TMPDIR = "$OUTDIR/tmp/$SCRIPT_NAME";
  if (-e $TMPDIR) {remove_tree($TMPDIR);}
  make_path($TMPDIR);
  
  if (!$quiet) {
    &Log("osis-converters git rev: $GITHEAD\n\n");
    &Log("\n-----------------------------------------------------\nSTARTING $SCRIPT_NAME.pl\n\n");
  }
  
  $DEFAULT_DICTIONARY_WORDS = "$OUTDIR/DictionaryWords_autogen.xml";
  if (-e "$INPD/$DICTIONARY_WORDS") {
    &loadDictionaryWordsXML();
    if (&validateDictionaryXML($DWF) && !$quiet) {
      &Log("$INPD/$DICTIONARY_WORDS has no unrecognized elements or attributes.\n\n");
    }
  }
  
  if ($ConfEntryP->{'Font'}) {&checkFont($ConfEntryP->{'Font'});}
  
  my $spaces = `find $INPD/images -type f -name "* *" -print`;
  if ($spaces) {
    &Log("\nERROR: Image filenames must not contain spaces:\n$spaces\n");
  }
}

sub checkFont($) {
  my $font = shift;
  
  # After this routine is run, font features can use "if ($FONT)" to check 
  # font support, and can use FONT_FILES whenever fonts files are needed.
  
  %FONT_FILES;
  
  if ($FONTS && -e "/vagrant") {
    open(CSH, "<$SCRD/Vagrantfile") || die "Could not open Vagrantfile";
    while(<CSH>) {
      if ($_ =~ /config\.vm\.synced_folder\s+"([^"]*)"\s*,\s*"([^"]*INDIR_ROOT[^"]*)"/) {
        $SHARE_HOST = $1;
        $SHARE_VIRT = $2;
      }
    }
    $FONTS = File::Spec->abs2rel($FONTS, $SHARE_HOST);
    $FONTS = File::Spec->rel2abs($FONTS, $SHARE_VIRT);
  }

  if ($FONTS && ! -e $FONTS) {
    &Log("ERROR: paths.pl specifies FONTS as \"$FONTS\" but this path does not exist! FONTS will be unset!\n");
    $FONTS = '';
  }

  if ($FONTS) {
    # The Font value is a font internal name, which may have multiple font files associated with it.
    # Font files should be named according to the excpectations below.
    opendir(DIR, $FONTS);
    my @fonts = readdir(DIR);
    closedir(DIR);
    my %styles = ('R' => 'regular', 'B' => 'bold', 'I' => 'italic');
    foreach my $f (@fonts) {
      if ($f =~ /^\./) {next;}
      if ($f =~ /^(.*?)(\-([ribRIB]))?\.([^\.]+)$/) {
        my $n = $1; my $t = ($2 ? $3:'R'); my $ext = $4;
        if ($n eq $font) {
          $FONT_FILES{$font}{$f}{'style'} = $styles{uc($t)};
          $FONT_FILES{$font}{$f}{'ext'} = $ext;
        }
      }
      else {&Log("\nWARNING: Font \"$f\" file name could not be parsed. Ignoring...\n\n");}
    }
    if (scalar(%FONT_FILES)) {
      foreach my $f (sort keys(%{$FONT_FILES{$font}})) {
        &Log("NOTE: Using font file \"$f\" as ".$FONT_FILES{$font}{$f}{'style'}." font for \"$font\".\n\n");
      }
    }
    else {
      &Log("ERROR: No font file(s) for \"$font\" were found in \"$FONTS\"\n");
    }
  }
  else {
    &Log("\nWARNING: The config.conf specifies font \"$font\", but no FONTS directory has been specified in $SCRD/paths.pl. Therefore, this setting will be ignored!\n\n");
  }
}

sub getOUTDIR($) {
  my $inpd = shift;
  
  my $outdir = $OUTDIR;
  
  if (-e "/vagrant") {
    if (-e "$HOME_DIR/OUTDIR" && `mountpoint $HOME_DIR/OUTDIR` =~ /is a mountpoint/) {
      $outdir = "$HOME_DIR/OUTDIR"; # Vagrant share
    }
    else {$outdir = '';}
  }

  if (!$outdir) {$outdir = "$inpd/output";}
  else {
    my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
    $outdir =~ s/[\\\/]\s*$//; # remove any trailing slash
    $outdir .= '/'.$sub;
  }

  return $outdir;
}

# returns true on success
sub loadDictionaryWordsXML($) {
  my $companionsAlso = shift;
  
  if (-e $DEFAULT_DICTIONARY_WORDS && ! -e "$INPD/$DICTIONARY_WORDS") {
    copy($DEFAULT_DICTIONARY_WORDS, "$INPD/$DICTIONARY_WORDS");
  }
  if (! -e "$INPD/$DICTIONARY_WORDS") {return 0;}
  $DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # check for old DWF markup and update
  my @tst = $XPC->findnodes('//dw:div', $DWF);
  if (!@tst || !@tst[0]) {
    &Log("ERROR: Missing namespace declaration in: \"$INPD/$DICTIONARY_WORDS\", continuing with default!\nAdd 'xmlns=\"$DICTIONARY_WORDS_NAMESPACE\"' to root element of \"$INPD/$DICTIONARY_WORDS\" to remove this error.\n\n");
    my @ns = $XPC->findnodes('//*', $DWF);
    foreach my $n (@ns) {$n->setNamespace($DICTIONARY_WORDS_NAMESPACE, 'dw', 1);}
  }
  my @tst = $XPC->findnodes('//*[@highlight]', $DWF);
  if (@tst && @tst[0]) {
    &Log("ERROR: Ignoring outdated attribute: \"highlight\" found in: \"$INPD/$DICTIONARY_WORDS\"\nRemove the \"highlight\" attribute and use the more powerful notXPATH attribute instead.\n\n");
  }
  my @tst = $XPC->findnodes('//*[@notXPATH]', $DWF);
  if (!@tst || !@tst[0]) {
    &Log("ERROR: Required attribute: \"notXPATH\" was not found in \"$INPD/$DICTIONARY_WORDS\", continuing with default setting!\nAdd 'notXPATH=\"$DICTIONARY_NotXPATH_Default\"' to \"$INPD/$DICTIONARY_WORDS\" to remove this error.\n\n");
    @{$XPC->findnodes('//*', $DWF)}[0]->setAttribute("notXPATH", $DICTIONARY_NotXPATH_Default);
  }
  my @tst = $XPC->findnodes('//*[@withString]', $DWF);
  if (@tst && @tst[0]) {&Log("ERROR: \"withString\" attribute is no longer supported. Remove it from: $DICTIONARY_WORDS\n");}


  if (!my $companionsAlso) {return 1;}
  
  # if companion has no dictionary words file, then create it too
  foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
    if (!-e "$INPD/../../$companion") {
      &Log("WARNING: Companion project \"$companion\" of \"$MOD\" could not be located to copy $DICTIONARY_WORDS.\n");
      next;
    }
    if (!-e "$INPD/../../$companion/$DICTIONARY_WORDS") {copy ($DEFAULT_DICTIONARY_WORDS, "$INPD/../../$companion/$DICTIONARY_WORDS");}
  }
  
  return 1;
}


sub initOutputFiles($$$$) {
  my $script_name = shift;
  my $inpd = shift;
  my $outdir = shift;
  my $automode = shift;
  
  my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
  
  my @outs;
  if ($script_name =~ /^(osis2osis|sfm2osis|html2osis|cbsfm2osis)$/i) {
    $OUTOSIS = "$outdir/$sub.xml"; push(@outs, $OUTOSIS);
  }
  if ($script_name =~ /^(osis2sword|imp2sword)$/i) {
    $OUTZIP = "$outdir/$sub.zip"; push(@outs, $OUTZIP);
    $SWOUT = "$outdir/sword"; push(@outs, $SWOUT);
  }
  if ($script_name =~ /^osis2GoBible$/i) {
    $GBOUT = "$outdir/GoBible/$sub"; push(@outs, $GBOUT);
  }
  if ($script_name =~ /^osis2ebooks$/i) {
    $EBOUT = "$outdir/eBook"; push(@outs, $EBOUT);
  }
  if ($script_name =~ /^sfm2imp$/i) {
    $OUTIMP = "$outdir/$sub.imp"; push(@outs, $OUTIMP);
  }

  my $delete;
  foreach my $outfile (@outs) {if (-e $outfile) {$delete .= "$outfile\n";}}
  if ($delete && !$automode && !-e "/vagrant") {
    print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
    $in = <>; 
    if ($in !~ /^\s*y\s*$/i) {exit;} 
  }
  foreach my $outfile (@outs) {
    my $isDir = ($outfile =~ /\.[^\\\/\.]+$/ ? 0:1);
    if (-e $outfile) {
      if (!$isDir) {unlink($outfile);}
      else {remove_tree($outfile);}
    }
    if ($isDir) {make_path($outfile);}
  }
}


# Check if dependencies are met and if not, suggest to use Vagrant
sub checkDependencies($$$$) {
  my $scrd = shift;
  my $script = shift;
  my $inpd = shift;
  my $quiet = shift;

  my %path;
  $path{'SWORD_BIN'}{'msg'} = "Install CrossWire's SWORD tools, or specify the path to them by adding:\n\$SWORD_BIN = '/path/to/directory';\nto osis-converters/paths.pl\n";
  $path{'XMLLINT'}{'msg'} = "Install xmllint, or specify the path to xmllint by adding:\n\$XMLLINT = '/path/to/directory'\nto osis-converters/paths.pl\n";
  $path{'GO_BIBLE_CREATOR'}{'msg'} = "Install GoBible Creator as ~/.osis-converters/GoBibleCreator.245, or specify the path to it by adding:\n\$GO_BIBLE_CREATOR = '/path/to/directory';\nto osis-converters/paths.pl\n";
  $path{'MODULETOOLS_BIN'}{'msg'} = "Install CrossWire\'s Module-tools git repo as ~/.osis-converters/src/Module-tools, or specify the path to it by adding:\n\$MODULETOOLS_BIN = '/path/to/bin';\nto osis-converters/paths.pl\n";
  $path{'XSLT2'}{'msg'} = "Install the required program.\n";
  $path{'CALIBRE'}{'msg'} = "Install Calibre by following the documentation: osis-converters/eBooks/osis2ebook.docx.\n";
  
  foreach my $p (keys %path) {
    if (-e "/vagrant" && $$p) {
      if (!$quiet) {
        if ($p eq 'MODULETOOLS_BIN') {&Log("NOTE: Using network share to \$$p in paths.pl while running in Vagrant.\n");}
        else {&Log("WARN: Ignoring \$$p in paths.pl while running in Vagrant.\n");}
      }
      $$p = '';
    }
    if ($p eq 'GO_BIBLE_CREATOR' && !$$p) {$$p = "$HOME_DIR/.osis-converters/GoBibleCreator.245";} # Default location
    if ($p eq 'MODULETOOLS_BIN' && !$$p) {$$p = "$HOME_DIR/.osis-converters/src/Module-tools/bin";} # Default location
    if ($$p) {
      if ($p =~ /^\./) {$$p = File::Spec->rel2abs($$p);}
      $$p =~ s/[\\\/]+\s*$//;
      $$p .= "/";
    }
  }
  
  $path{'SWORD_BIN'}{'test'} = [&escfile($SWORD_BIN."osis2mod"), "You are running osis2mod"];
  $path{'XMLLINT'}{'test'} = [&escfile($XMLLINT."xmllint"), "Usage"];
  $path{'MODULETOOLS_BIN'}{'test'} = [&escfile($MODULETOOLS_BIN."usfm2osis.py"), "Usage"];
  $path{'XSLT2'}{'test'} = [&osisXSLT(), "Usage"];
  $path{'GO_BIBLE_CREATOR'}{'test'} = ["java -jar ".&escfile($GO_BIBLE_CREATOR."GoBibleCreator.jar"), "Usage"];
  $path{'CALIBRE'}{'test'} = ["ebook-convert", "Usage"];
  
  my $failMes = '';
  foreach my $p (keys %path) {
    if (!exists($path{$p}{'test'})) {next;}
    my $pass = 0;
    system($path{$p}{'test'}[0]." >".&escfile("tmp.txt"). " 2>&1");
    if (!open(TEST, "<tmp.txt")) {&Log("ERROR: could not read test output \"$SCRD/tmp.txt\". Exiting.\n"); die;}
    my $res = $path{$p}{'test'}[1];
    while (<TEST>) {if ($_ =~ /\Q$res\E/i) {$pass = 1; last;}}
    close(TEST); unlink("tmp.txt");
    if (!$pass) {
      &Log("\nERROR: Dependency not found or is failing usage test: \"".$path{$p}{'test'}[0]."\"\n", 1);
      $failMes .= "NOTE: ".$path{$p}{'msg'}."\n";
    }
    elsif ($p eq 'MODULETOOLS_BIN') {
      $MODULETOOLS_GITHEAD = `git --git-dir="$MODULETOOLS_BIN../.git" --work-tree="$MODULETOOLS_BIN../" rev-parse HEAD 2>tmp.txt`; unlink("tmp.txt");
      if (!$quiet) {&Log("Module-tools git rev: $MODULETOOLS_GITHEAD");}
    }
  }
  if ($failMes) {
    &Log("\n$failMes", 1);
    exit;
  }
}


sub validateDictionaryXML($) {
  my $dwf = shift;
  
  my @entries = $XPC->findnodes('//dw:entry[@osisRef]', $dwf);
  foreach my $entry (@entries) {
    my @dicts = split(/\s+/, $entry->getAttribute('osisRef'));
    foreach my $dict (@dicts) {
      if ($dict !~ s/^(\w+):.*$/$1/) {&Log("ERROR: osisRef \"$dict\" in \"$INPD/$DefaultDictWordFile\" has no target module\n");}
    }
  }
  
  my $success = 1;
  my $x = "//*";
  my @allowed = ('dictionaryWords', 'div', 'entry', 'name', 'match');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badElem = $XPC->findnodes($x, $dwf);
  if (@badElem) {
    foreach my $ba (@badElem) {
      &Log("\nERROR: Bad DictionaryWords.xml element: \"".$ba->localname()."\"\n\n");
      $success = 0;
    }
  }
  
  $x = "//*[local-name()!='dictionaryWords'][local-name()!='entry']/@*";
  @allowed = ('onlyNewTestament', 'onlyOldTestament', 'context', 'notContext', 'multiple', 'osisRef', 'XPATH', 'notXPATH', 'version', 'dontLink', 'notExplicit', 'onlyExplicit');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Log("\nERROR: Bad DictionaryWords.xml attribute: \"".$ba->localname()."\"\n\n");
      $success = 0;
    }
  }
  
  $x = "//dw:entry/@*";
  push(@allowed, ('osisRef', 'noOutboundLinks'));
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Log("\nERROR: Bad DictionaryWords.xml entry attribute: \"".$ba->localname()."\"\n\n");
      $success = 0;
    }
  }
  
  return $success;
}


sub initLibXML() {
  use Sword;
  use HTML::Entities;
  use XML::LibXML;
  $XPC = XML::LibXML::XPathContext->new;
  $XPC->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
  $XPC->registerNs('tei', 'http://www.crosswire.org/2013/TEIOSIS/namespace');
  $XPC->registerNs('dw', $DICTIONARY_WORDS_NAMESPACE);
  $XML_PARSER = XML::LibXML->new();
}


# If the project config.conf file exists, or if the sfm subdirectory does 
# not exist, this routine does nothing. Otherwise pertinent non-existing 
# project input files are copied from the first defaults directory 
# found in the following order:
#
# - $INPD../defaults
# - $INPD../../defaults
# - osis-converters/defaults
#
# and then entries are added to each new input file as applicable.
# Returns 0 if no action was taken, 1 otherwise.
sub checkAndWriteDefaults($) {
  my $dir = shift;

  # config.conf and sfm file information
  if ((!-e "$dir/sfm" && !%USFM) || !&copyDefaultFiles($dir, '.', 'config.conf', 1)) {return 0;}

  my $mod = $dir;
  $mod =~ s/^.*?([^\\\/]+)$/$1/;
  $mod = uc($mod);
  
  &Log("CREATING DEFAULT FILES FOR PROJECT \"$mod\"\n", 1);
  
  &setConfFileValue("$dir/config.conf", 'ModuleName', $mod, 1);
  &setConfFileValue("$dir/config.conf", 'Abbreviation', $mod, 1);
  
  # read my new conf
  my $confdataP = &readConf("$dir/config.conf");
  
  # read sfm files
  $SCAN_USFM_SKIPPED = '';
  %USFM; &scanUSFM("$dir/sfm", \%USFM);
  if ($SCAN_USFM_SKIPPED) {&Log("$SCAN_USFM_SKIPPED\n");}
  
  # get my type
  my $type = (exists($USFM{'dictionary'}) && $confdataP->{'ModuleName'} =~ /DICT$/ ? 'dictionary':0);
  if (!$type) {$type = ($confdataP->{'ModuleName'} =~ /^\w\w\w\w?CB$/ ? 'childrens_bible':0);}
  if (!$type) {$type = (exists($USFM{'bible'}) ? 'bible':0);}
  if (!$type) {$type = 'other';}
  
  # ModDrv
  if ($type eq 'dictionary') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'RawLD4', 1);}
  if ($type eq 'childrens_bible') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'RawGenBook', 1);}
  if ($type eq 'bible') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'zText', 1);}
  if ($type eq 'other') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'RawGenBook', 1);}
 
  # Companion
  my $companion;
  if (($type eq 'bible' || $type eq 'childrens_bible') && exists($USFM{'dictionary'})) {
    $companion = $confdataP->{'ModuleName'}.'DICT';
    if (!-e "$dir/$companion") {
      make_path("$dir/$companion");
      &checkAndWriteDefaults("$dir/$companion");
    }
    else {&Log("WARNING: Companion directory \"$dir/$companion\" already exists, skipping defaults check for it.\n");}
  }
  my $parent = $dir; $parent =~ s/^.*?[\\\/]([^\\\/]+)[\\\/][^\\\/]+\s*$/$1/;
  if ($type eq 'dictionary' && $confdataP->{'ModuleName'} eq $parent.'DICT') {$companion = $parent;}
  if ($companion) {
    &setConfFileValue("$dir/config.conf", 'Companion', $companion, ', ');
  }

  if ($type eq 'childrens_bible') {
    # SFM_Files.txt
    if (!open (SFMFS, ">encoding(UTF-8)", "$dir/SFM_Files.txt")) {&Log("ERROR: Could not open \"$dir/SFM_Files.txt\"\n"); die;}
    foreach my $f (sort keys %{$USFM{'childrens_bible'}}) {
      $f =~ s/^.*[\/\\]//;
      print SFMFS "sfm/$f\n";
    }
    close(SFMFS);
  }
  else {
    # CF_usfm2osis.txt
    if (&copyDefaultFiles($dir, '.', 'CF_usfm2osis.txt')) {
      if (!open (CFF, ">>$dir/CF_usfm2osis.txt")) {&Log("ERROR: Could not open \"$dir/CF_usfm2osis.txt\"\n"); die;}
      foreach my $f (sort keys %{$USFM{$type}}) {
        my $r = File::Spec->abs2rel($f, $dir); if ($r !~ /^\./) {$r = './'.$r;}
        
        # peripherals need a target location in the OSIS file added to their ID
        if ($USFM{$type}{$f}{'peripheralID'}) {
          print CFF "\n# Use location == <xpath> to place this peripheral in the proper location in the OSIS file\n";
          if (defined($ID_TYPE_MAP{$USFM{$type}{$f}{'peripheralID'}})) {
            print CFF "EVAL_REGEX($r):s/^(\\\\id ".$USFM{$type}{$f}{'peripheralID'}.".*)\$/\$1 ";
          }
          else {
            print CFF "EVAL_REGEX($r):s/^(\\\\id )".$USFM{$type}{$f}{'peripheralID'}."(.*)\$/\$1FRT\$2 ";
          }
          my $xpath = "location == osis:header";
          if (@{$USFM{$type}{$f}{'periphType'}}) {
            foreach my $periphType (@{$USFM{$type}{$f}{'periphType'}}) {
              my $osisMap = &getOsisMap($periphType);
              if (!$osisMap) {next;}
              $xpath .= ", \"$periphType\" == ".$osisMap->{'xpath'};
            }
          }
          $xpath =~ s/([\@\$])/\\$1/g;
          print CFF $xpath;
          print CFF "/m\n";
        }

        print CFF "RUN:$r\n";
      }
      close(CFF);
    }
  }
  
  # CF_addScripRefLinks.txt
  &copyDefaultFiles($dir, '.', 'CF_addScripRefLinks.txt');
  
  if ($type eq 'bible') {
    $confdataP = &readConf("$dir/config.conf"); # need a re-read after above modifications
  
    # GoBible
    if (&copyDefaultFiles($dir, 'GoBible', 'collections.txt, icon.png, normalChars.txt, simpleChars.txt, ui.properties')) {
      if (!open (COLL, ">>encoding(UTF-8)", "$dir/GoBible/collections.txt")) {&Log("ERROR: Could not open \"$dir/GoBible/collections.txt\"\n"); die;}
      print COLL "Info: (".$confdataP->{'Version'}.") ".$confdataP->{'Description'}."\n";
      print COLL "Application-Name: ".$confdataP->{'Abbreviation'}."\n";
      my $canonP;
      my $bookOrderP;
      my $testamentP;
      if (&getCanon($confdataP->{'Versification'}, \$canonP, \$bookOrderP, \$testamentP)) {
        my $col = ''; my $colot = ''; my $colnt = '';
        foreach my $v11nbk (sort {$bookOrderP->{$a} <=> $bookOrderP->{$b}} keys %{$bookOrderP}) {
          foreach my $f (keys %{$USFM{'bible'}}) {
            if ($USFM{'bible'}{$f}{'osisBook'} ne $v11nbk) {next;}
            my $b = "Book: $v11nbk\n";
            $col .= $b;
            if ($testamentP->{$v11nbk} eq 'OT') {$colot .= $b;}
            else {$colnt .= $b;}
          }
        }
        my $colhead = "Collection: ".lc($confdataP->{'ModuleName'});
        if ($col) {print COLL "$colhead\n$col\n";}
        if ($colot && $colnt) {
          print COLL $colhead."ot\n$colot\n";
          print COLL $colhead."nt\n$colnt\n";
        }
      }
      else {&Log("ERROR: Could not get versification for \"".$confdataP->{'Versification'}."\"\n");}
      close(COLL);
    }
    
    # eBooks
    if (&copyDefaultFiles($dir, 'eBook', 'convert.txt')) {
      #if (!open (CONV, ">>encoding(UTF-8)", "$dir/eBook/convert.txt")) {&Log("ERROR: Could not open \"$dir/eBook/convert.txt\"\n"); die;}
      #close(CONV);
    }
  }
  
  return 1;
}


sub getOsisMap($) {
  my $pt = shift;

  my $name = $PERIPH_TYPE_MAP{$pt};
  if (!$name) {&Log("ERROR: Unrecognized peripheral name \"$pt\"\n"); return NULL;}
  if ($name eq 'introduction') {$name = $PERIPH_SUBTYPE_MAP{$pt};}

  my $xpath = 'osis:div[@type="book"]'; # default is introduction to first book
  foreach my $t (keys %USFM_DEFAULT_PERIPH_TARGET) {
    if ($pt !~ /^($t)$/i) {next;}
    $xpath = $USFM_DEFAULT_PERIPH_TARGET{$t};
    last;
  }
  my %h = ( 'name' => $name, 'xpath' => $xpath );
  return \%h;
}


# If any filename in filenames does not exist in subdir of dest, copy its default file. 
# Return 1 if all files were missing and were successfully created.
sub copyDefaultFiles($$$$) {
  my $dest = shift;
  my $subdir = shift;
  my $filenames = shift;
  my $nowarn = shift;
  
  my $created = 1;
  
  my @filenames = split(/\s*,\s*/, $filenames);
  
  if (!-e "$dest/$subdir") {make_path("$dest/$subdir");}
  
  foreach my $filename (@filenames) {
    if (!$filename) {next;}
    my $starter = &getDefaultFile("$subdir/$filename");
    if ($starter && !-e "$dest/$subdir/$filename") {&copy($starter, "$dest/$subdir/$filename");}
    else {
      if (!$nowarn) {&Log("WARNING: \"$dest/$subdir/$filename\" already exists, skipping defaults check for it.\n");}
      $created = 0;
    }
  }
  
  return $created;
}

sub copyFont($$$$$) {
  my $fontname = shift;
  my $fontdir = shift;
  my $fontP = shift;
  my $outdir = shift;
  my $dontRenameRegularFile = shift;
  
  &Log("\n--- COPYING font \"$fontname\"\n");
  
  $outdir =~ s/\/\s*$//;
  `mkdir -p "$outdir"`;
  
  my $copied = 0;
  foreach my $f (keys %{$fontP->{$fontname}}) {
    my $fdest = $f;
    if (!$dontRenameRegularFile && $fontP->{$fontname}{$f}{'style'} eq 'regular') {
      $fdest =~ s/^.*\.([^\.]+)$/$fontname.$1/;
    }
    &copy("$fontdir/$f", "$outdir/$fdest");
    $copied++;
    &Log("NOTE: Copied font \"$outdir/$fdest\"\n");
  }
  
  &Log("REPORT $MOD: Copied \"$copied\" font file(s) to \"$outdir\".\n\n");
}


# Copy all images found in the OSIS or TEI file from projdir to outdir. 
# If any images are copied, 1 is returned, otherwise 0;
sub copyReferencedImages($$$) {
  my $osis_or_tei = shift;
  my $projdir = shift;
  my $outdir = shift;
  
  &Log("\n--- COPYING images in \"$osis_or_tei\"\n");
  
  $projdir =~ s/\/\s*$//;
  $outdir =~ s/\/\s*$//;
  
  my %copied;
  
  my $xml = $XML_PARSER->parse_file($osis_or_tei);
  my @images = $XPC->findnodes('//*[local-name()="figure"]/@src', $xml);
  foreach my $image (@images) {
    my $i = $image->getValue();
    if ($copied{"$outdir/$i"}) {next;}
    if ($i !~ s/^\.\///) {
      &Log("ERROR copyReferencedImages: Image src path \"$i\" should be relative path (should begin with '.').\n");
    }
    if (!$projdir || !$outdir) {
      &Log("ERROR copyReferencedImages: Images exist in \"$osis_or_tei\" but a directory path is empty: projdir=\"$projdir\", outdir=\"$outdir\".\n");
      next;
    }
    if (!-e $projdir) {
      &Log("ERROR copyReferencedImages: Missing project directory \"$projdir\".\n");
      next;
    }
    if (!-e "$projdir/$i") {
      &Log("ERROR copyReferencedImages: Image \"$i\" not found in \"$projdir/$i\"!\n");
      next;
    }
    if (-e "$outdir/$i" && !$copied{"$outdir/$i"}) {
      &Log("WARNING copyReferencedImages: Multiple modules reference image \"$outdir/$i\". Only the last version copied of this image will appear everywhere in the final output.\n");
    }
    my $ofile = "$outdir/$i";
    my $odir = $ofile; $odir =~ s/\/[^\/]*$//;
    if (!-e $odir) {`mkdir -p "$odir"`;}
    
    &copy("$projdir/$i", "$ofile");
    $copied{"$outdir/$i"}++;
    &Log("NOTE: Copied image \"$ofile\"\n");
  }
  
  &Log("REPORT $MOD: Copied \"".scalar(keys(%copied))."\" images to \"$outdir\".\n\n");
  return scalar(keys(%copied));
}


sub getDefaultFile($) {
  my $filename = shift;
  
  my $d1 = "$SCRD/defaults";
  my $d2 = "$INPD/../defaults";
  if (!-e $d2) {"$INPD/../../defaults";}
  
  my $starter;
  if (-e "$d2/$filename") {$starter = "$d2/$filename";}
  elsif (-e "$d1/$filename") {$starter = "$d1/$filename";}
  
  if (!$starter) {&Log("ERROR: problem locating default \"$filename\"\n"); die;}
  
  return $starter;
}


sub scanUSFM($\%) {
  my $sfm_dir = shift;
  my $sfmP = shift;
  
  if (!opendir(SFMS, $sfm_dir)) {
    &Log("WARNING: unable to read default sfm directory: \"$sfm_dir\"\n");
    return;
  }
  
  my @sfms = readdir(SFMS); closedir(SFMS);
  
  foreach my $sfm (@sfms) {
    if ($sfm =~ /^\./) {next;}
    my $f = "$sfm_dir/$sfm";
    if (-d $f) {&scanUSFM($f, $sfmP); next;}
    my $sfmInfoP = &scanUSFM_file($f);
    if (!$sfmInfoP->{'doConvert'}) {next;}
    $sfmP->{$sfmInfoP->{'type'}}{$f} = $sfmInfoP;
  }
}

sub scanUSFM_file($) {
  my $f = shift;
  
  my %info;
  
  &Log("Scanning SFM file: \"$f\"\n");
  
  if (!open(SFM, "<:encoding(UTF-8)", $f)) {&Log("ERROR: could not read \"$f\"\n"); die;}
  my $id;
  my @tags = ('h', 'imt', 'is', 'mt');
  while(<SFM>) {
    if ($_ =~ /^\W*?\\id \s*(.*?)\s*$/) {
      my $i = $1; 
      if ($id) {
        if (substr($id, 0, 3) ne substr($i, 0, 3)) {&Log("WARNING: ambiguous id tags: \"$id\", \"$i\"\n");}
        next;
      }
      $id = $i;
      &Log("NOTE: id is $id\n");
    }
    foreach my $t (@tags) {
      if ($_ =~ /^\\($t\d*) \s*(.*?)\s*$/) {
        if ($info{$t}) {&Log("NOTE: ignoring SFM $1 intro tag which is \"".$2."\"\n"); next;}
        $info{$t} = $2;
      }
    }
    if ($_ =~ /^\\periph\s+(.*?)\s*$/) {
      my $pt = $1;
      if (!@{$info{'periphType'}}) {$info{'periphType'} = [];}
      push(@{$info{'periphType'}}, $pt);
    }
    if ($_ =~ /^\\(c|ie)/) {last;}
  }
  close(SFM);
  
  if ($id =~ /^\s*(\w{2,3}).*$/) {
    my $shortid = $1;
    $info{'doConvert'} = 1;
    my $osisBook = &getOsisName($shortid, 1);
    if ($osisBook) {
      $info{'osisBook'} = $osisBook;
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /^(FRT|INT|OTH)$/i) {
      $info{'type'} = 'bible';
      $info{'peripheralID'} = $id;
    }
    elsif ($id =~ /(GLO|DIC|BAK|CNC|TDX|NDX)/i) {
      $info{'type'} = 'dictionary';
    }
    elsif ($id =~ /^(PREPAT|SHM[NO]T|CB|NT|OT|FOTO)$/i) { # Strange IDs associated with Children's Bibles
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /^\s*(\w{3})\b/) {
      $info{'peripheralID'} = $1;
      $info{'type'} = 'bible'; # This has some kind of SFM-like id, so just treat it like a Bible peripheral
    }
    # others are currently unhandled by osis-converters
    else {
      $info{'type'} = 'other';
      $info{'doConvert'} = 0;
      $SCAN_USFM_SKIPPED .= "WARNING: SFM file \"$f\" has no ID and is being SKIPPED!\n";
    }
    &Log("NOTE:");
    foreach my $k (sort keys %info) {&Log(" $k=[".$info{$k}."]");}
    &Log("\n");
  }
  
  &Log("\n");
  
  return \%info;
}


# Checks, and optionally updates, a param in conf file and returns 1 if value is there, otherwise 0.
sub setConfFileValue($$$$) {
  my $conf = shift;
  my $param = shift;
  my $value = shift;
  my $flag = shift; # see &setConfValue()
  
  my $confEntriesP = &readConf($conf);
  
  if (!&setConfValue($confEntriesP, $param, $value, $flag)) {
    &Log("WARNING: \"$param\" does not have value \"$value\" in \"$conf\"\n"); 
    return;
  }
  
  if ($flag eq "0") {return;}
  
  &writeConf($conf, $confEntriesP);
}


# Checks, and optionally updates, a param in confEntriesP.
# Returns 1 if the value is there, otherwise 0.
# Flag values are:
# 0 = check-only 
# 1 = overwrite existing
# 2 = don't modify existing
# "additional" = append additional param
# string = append to existing param with string separator
sub setConfValue($$$$) {
  my $confEntriesP = shift;
  my $param = shift;
  my $value = shift;
  my $flag = shift;
 
  my $sep = '';
  if ($flag ne "0" && $flag ne "1" && $flag ne "2") {
    if ($flag eq 'additional') {$sep = "<nx/>";}
    else {$sep = $flag;}
  }
  
  if ($confEntriesP->{$param} && $confEntriesP->{$param} =~ /(^|\Q$sep\E)\Q$value\E(\Q$sep\E|$)/) {return 1;}
  if (!$confEntriesP->{$param} && !$value) {return 1;}
  
  if ($flag eq "0" || ($flag eq "2" && $confEntriesP->{$param})) {return 0;}
  
  if ($flag eq "1") {$confEntriesP->{$param} = $value;}
  elsif (!$confEntriesP->{$param}) {$confEntriesP->{$param} = $value;}
  else {$confEntriesP->{$param} .= $sep.$value;}
  
  return 1;
}


sub osis_converters($$$) {
  my $script = shift;
  my $project_dir = shift;
  my $logfile = shift;
  
  my $cmd = &escfile($script)." ".&escfile($project_dir).($logfile ? " ".&escfile($logfile):'');
  &Log("\n\n\nRUNNING OSIS_CONVERTERS:\n$cmd\n", 1);
  &Log("########################################################################\n", 1);
  &Log("########################################################################\n", 1);
  system($cmd.($logfile ? " 2>> ".&escfile($logfile):''));
}


# Write $conf file by starting with $starterConf (if provided) and 
# writing necessary entries from %entryValue (after it has been 
# updated according to the module source if provided). If $conf is in 
# a mods.d directory, it also creates the module directory if it doesn't 
# exist, so that it's ready for writing.
sub writeConf($\%$$) {
  my $conf = shift;
  my $entryValueP = shift;
  my $starterConf = shift;
  my $moduleSource = shift;
  
  if ($moduleSource) {$entryValueP = &updateConfData($entryValueP, $moduleSource);}
  
  my $confdir = $conf; $confdir =~ s/([\\\/][^\\\/]+){1}$//;
  if (!-e $confdir) {make_path($confdir);}
  
  my $moddir;
  if ($confdir =~ /[\\\/]mods\.d$/) {
    $moddir = $confdir; $moddir =~ s/([\\\/][^\\\/]+){1}$//;
  }
  
  my $starterP;
  if ($starterConf) {
    $starterP = &readConf($starterConf);
    copy($starterConf, $conf);
  }
  elsif (-e $conf) {unlink($conf);}

  my %used;
  open(CONF, ">>:encoding(UTF-8)", $conf) || die "Could not open conf $conf\n";
  if ($starterConf) {print CONF "\n\n#Autogenerated by osis-converters:\n";}
  else {print CONF "[".$entryValueP->{'ModuleName'}."]\n"; $entryValueP->{'ModuleName'} = '';}
  foreach my $e (sort keys %{$entryValueP}) {
    if ($starterP && $starterP->{$e}) {
      if ($starterP->{$e} eq $entryValueP->{$e}) {next;} # this also skips ModuleName and other non-real conf entries, or else throws an error
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
  
  if ($moddir) {
    my $realPath = &dataPath2RealPath($entryValueP->{'DataPath'});
    if (!-e "$moddir/$realPath") {make_path("$moddir/$realPath");}
  }
  
  return $entryValueP;
}


# Update certain conf %entryValue data according to the module's source file
sub updateConfData(\%$) {
  my $entryValueP = shift;
  my $moduleSource = shift;
  
  if (!$entryValueP->{"ModDrv"}) {
		&Log("ERROR: ModDrv must be specified in config.conf.\n");
		die;
	}
  
  if ($entryValueP->{"Versification"}) {
    if (!&isValidVersification($entryValueP->{"Versification"})) {
      &Log("ERROR: Unrecognized versification system \"".$entryValueP->{"Versification"}."\".\n");
    }
  }
  
	my $dp;
  my $moddrv = $entryValueP->{"ModDrv"};
  my $mod = $entryValueP->{'ModuleName'};
	if    ($moddrv eq "RawText") {$dp = "./modules/texts/rawtext/".lc($mod)."/";}
  elsif ($moddrv eq "RawText4") {$dp = "./modules/texts/rawtext4/".lc($mod)."/";}
	elsif ($moddrv eq "zText") {$dp = "./modules/texts/ztext/".lc($mod)."/";}
	elsif ($moddrv eq "zText4") {$dp = "./modules/texts/ztext4/".lc($mod)."/";}
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
	}
  # At this time (Jan 2017) JSword does not yet support zText4
  if ($moddrv =~ /^(raw)(text|com)$/i || $moddrv =~ /^rawld$/i) {
    my $msg = "ERROR: ModDrv \"".$moddrv."\" should be changed to \"".$moddrv."4\" in config.conf.\n";
    if (!$AlreadyReported{$msg}) {&Log($msg);}
    $AlreadyReported{$msg}++;
  }
  &setConfValue($entryValueP, 'DataPath', $dp, 1);

  my $type = 'genbook';
  if ($moddrv =~ /LD/) {$type = 'dictionary';}
  elsif ($moddrv =~ /Text/) {$type = 'bible';}
  elsif ($moddrv =~ /Com/) {$type = 'commentary';}
  
  if (!&setConfValue($entryValueP, 'Encoding', "UTF-8", 2)) {
    &Log("ERROR: Only UTF-8 encoding is supported by osis-converters\n");
  }
  
  if ($moduleSource) {
    my $moduleSourceXML = $XML_PARSER->parse_file($moduleSource);
    my $sourceType = ($XPC->findnodes('tei:TEI', $moduleSourceXML) ? 'TEI':'OSIS');
    
    if ($sourceType eq 'TEI') {
      &setConfValue($entryValueP, 'LangSortOrder', &getLangSortOrder($moduleSourceXML), 2);
    }
    
    &setConfValue($entryValueP, 'SourceType', $sourceType, 2); # '2' allows config.conf to enforce SourceType
    if ($entryValueP->{"SourceType"} !~ /^(OSIS|TEI)$/) {&Log("ERROR: Only OSIS and TEI are supported by osis-converters\n");}
    if ($entryValueP->{"SourceType"} eq 'TEI') {&Log("WARNING: Some front-ends may not fully support TEI yet\n");}
    
    if ($entryValueP->{"SourceType"} eq 'OSIS') {
      my @vers = $XPC->findnodes('//osis:osis/@xsi:schemaLocation', $moduleSourceXML);
      if (!@vers || !@vers[0]->value) {
        if ($sourceType eq 'OSIS') {&Log("ERROR: Unable to determine OSIS version from \"$moduleSource\"\n");}
      }
      else {
        my $vers = @vers[0]->value; $vers =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
        &setConfValue($entryValueP, 'OSISVersion', $vers, 1);
      }
      if ($XPC->findnodes("//osis:reference[\@type='x-glossary']", $moduleSourceXML)) {
        &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On', 'additional');
      }
      
      # get scope
      if ($type eq 'bible' || $type eq 'commentary') {
        &setConfValue($entryValueP, 'Scope', &getScope($entryValueP->{'Versification'}, $moduleSource), 1);
      }
    }
  }

  if ($entryValueP->{"SourceType"} eq "OSIS") {
    &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISFootnotes', 'additional');
    &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISHeadings', 'additional');
    &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISScripref', 'additional');
  }
  else {
    &setConfValue($entryValueP, 'OSISVersion', '', 1);
    $entryValueP->{'GlobalOptionFilter'} =~ s/(<nx\/>)?OSIS[^<]*(?=(<|$))//g;
  }
  
  if ($type eq 'dictionary') {
    &setConfValue($entryValueP, 'SearchOption', 'IncludeKeyInSearch', 1);
    # The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
    if ($UPPERCASE_DICTIONARY_KEYS) {&setConfValue($entryValueP, 'CaseSensitiveKeys', 'true', 1);}
  }
  
  my @tm = localtime(time);
  &setConfValue($entryValueP, 'SwordVersionDate', sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]), 1);
  
  return $entryValueP;
}


# Reads a conf file and returns a hash of its contents.
sub readConf($) {
  my $conf = shift;
  
  my %entryValue;
  if (!open(CONF, "<:encoding(UTF-8)", $conf)) {&Log("ERROR: Could not open $conf\n"); die;}
  my $contiuation;
  while(<CONF>) {
    if    ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^\s*\[(.*?)\]\s*$/) {$entryValue{'ModuleName'} = $1; next;}
    elsif ($_ =~ /^\s*(.*?)\s*=\s*(.*?)\s*$/) {
      my $entry = $1; my $value = $2;
      if ($entryValue{$entry} ne '') {$entryValue{$entry} .= "<nx/>".$value;}
      else {$entryValue{$entry} = $value;}
      $continuation = ($_ =~ /\\\n/ ? $entry:'');
    }
    else {
      chomp;
      if ($continuation) {$entryValue{$continuation} .= "\n$_";}
      $continuation = ($_ =~ /\\$/ ? $continuation:'');
    }
  }
  close(CONF);

  if (!$entryValue{"ModuleName"}) {
		&Log("ERROR: Module name must be specified at top of config.conf like: [MYMOD]\n");
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


sub getLangSortOrder($) {
  my $tei = shift;
  
  my $res = '';
  my @entries = $XPC->findnodes('//tei:entryFree/@n', $tei);
  my $last = '';
  foreach my $e (@entries) {
    my $l = substr($e->value, 0, 1);
    if (&uc2($l) eq $last) {next;}
    $res .= &uc2($l).&lc2($l);
    $last = &uc2($l);
  }
  if ($res) {&Log("INFO: LangSortOrder=$res\n");}
  else {&Log("WARNING: Could not determine LangSortOrder\n");}
  return $res;
}


sub dataPath2RealPath($) {
  my $datapath = shift;
  $datapath =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $datapath =~ s/[\\\/]\s*$//; # remove ending slash
  $datapath =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
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
    if (!open(OCMF, ">:encoding(UTF-8)", "$f.tmp")) {&Log("ERROR: Could not open \"$f.tmp\".\n"); die;}
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

  # Apparently \p{L} and \p{N} work different in different regex implementations.
  # So some schema checkers don't validate high order Unicode letters.
  $r =~ s/(.)/my $x = (ord($1) > 1103 ? "_".ord($1)."_":$1)/eg;
  
  $r =~ s/([^\p{L}\p{N}_])/my $x="_".ord($1)."_"/eg;
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


# Converts cases using special translations
sub lc2($) {return &uc2(shift, 1);}
sub uc2($$) {
  my $t = shift;
  my $tolower = shift;
  
  # Form for $i: a->A b->B c->C ...
  if ($SPECIAL_CAPITALS) {
    my $r = $SPECIAL_CAPITALS;
    $r =~ s/(^\s*|\s*$)//g;
    my @trs = split(/\s+/, $r);
    for (my $i=0; $i < @trs; $i++) {
      my @tr = split(/->/, $trs[$i]);
      if ($tolower) {
        $t =~ s/$tr[1]/$tr[0]/g;
      }
      else {
        $t =~ s/$tr[0]/$tr[1]/g;
      }
    }
  }

  $t = ($tolower ? lc($t):uc($t));

  return $t;
}

# Returns the OSIS book name from a Paratext or OSIS bookname. Or  
# returns nothing if argument is neither.
sub getOsisName($$) {
  my $bnm = shift;
  my $quiet = shift;
  
  # If it's already an OSIS book name, just return it
  if (!$AllBooksRE) {$AllBooksRE = join('|', @OT_BOOKS, @NT_BOOKS);}
  if ($bnm =~ /^($AllBooksRE)$/) {return $bnm;}
  
  my $bookName = "";
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
  elsif (!$quiet) {&Log("ERROR: Unrecognized Bookname:\"$bnm\"!\n");}

  return $bookName;
}

sub getCanon($\%\%\%\@) {
  my $vsys = shift;
  my $canonPP = shift;     # hash pointer: OSIS-book-name => Array (base 0!!) containing each chapter's max-verse number
  my $bookOrderPP = shift; # hash pointer: OSIS-book-name => position (Gen = 1, Rev = 66)
  my $testamentPP = shift; # hash pointer: OSIS-nook-name => 'OT' or 'NT'
  my $bookArrayPP = shift; # array pointer: OSIS-book-names in verse system order starting with index 1!!
  
  if (! %{$CANON_CACHE{$vsys}}) {
    if (!&isValidVersification($vsys)) {return 0;}
    
    my $vk = new Sword::VerseKey();
    $vk->setVersificationSystem($vsys);
    
    for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
      my $t, $bkt;
      if ($bk < $vk->bookCount(1)) {$t = 1; $bkt = ($bk+1);}
      else {$t = 2; $bkt = (($bk+1) - $vk->bookCount(1));}
      $CANON_CACHE{$vsys}{'bookOrder'}{$bkname} = ($bk+1);
      $CANON_CACHE{$vsys}{'testament'}{$bkname} = ($t == 1 ? "OT":"NT");
      my $chaps = [];
      for (my $ch = 1; $ch <= $vk->chapterCount($t, $bkt); $ch++) {
        # NOTE: CHAPTER 1 IN ARRAY IS INDEX 0!!!
        push(@{$chaps}, $vk->verseCount($t, $bkt, $ch));
      }
      $CANON_CACHE{$vsys}{'canon'}{$bkname} = $chaps;
    }
  }
  
  @{$CANON_CACHE{$vsys}{'bookArray'}} = ();
  foreach my $bk (keys %{$CANON_CACHE{$vsys}{'bookOrder'}}) {
    @{$CANON_CACHE{$vsys}{'bookArray'}}[$CANON_CACHE{$vsys}{'bookOrder'}{$bk}] = $bk;
  }
  
  if ($canonPP)     {$$canonPP     = \%{$CANON_CACHE{$vsys}{'canon'}};}
  if ($bookOrderPP) {$$bookOrderPP = \%{$CANON_CACHE{$vsys}{'bookOrder'}};}
  if ($testamentPP) {$$testamentPP = \%{$CANON_CACHE{$vsys}{'testament'}};}
  if ($bookArrayPP) {$$bookArrayPP = \@{$CANON_CACHE{$vsys}{'bookArray'}};}

  return 1;
}


sub isValidVersification($) {
  my $vsys = shift;
  
  my $vsmgr = Sword::VersificationMgr::getSystemVersificationMgr();
  my $vsyss = $vsmgr->getVersificationSystems();
  foreach my $vsys (@$vsyss) {if ($vsys->c_str() eq $vsys) {return 1;}}
  
  return 0;
}


sub sortSearchTermKeys($$) {
  my $aa = shift;
  my $bb = shift;
  
  while ($aa =~ /["\s]+(<[^>]*>\s*)+$/) {$aa =~ s/["\s]+(<[^>]*>\s*)+$//;}
  while ($bb =~ /["\s]+(<[^>]*>\s*)+$/) {$bb =~ s/["\s]+(<[^>]*>\s*)+$//;}
  
  length($bb) <=> length($aa)
}


# Copy inosis to outosis, while pruning books according to scope. Any
# changes made during the process are noted in the log file with a NOTE.
#
# If any bookGroup is left with no books in it, then the entire bookGroup 
# element (including its introduction if there is one) is dropped.
#
# If a pruned book contains a peripheral which also pertains to a kept 
# book, that peripheral is moved to the first kept book, so as to retain 
# the peripheral.
#
# If there is only one bookGroup left, the remaining one will lose its 
# TOC milestone to so as to reduce an unnecessary TOC level.
#
# If the ebookTitleP is non-empty, its value will be used as the ebook 
# title, otherwise the ebook title will be taken from the OSIS file, but 
# appended to it will be the list of books remaining after filtering IF 
# any were filtered out. The final ebook title will then be written to  
# the outosis file.
#
# The ebookPartTitleP is overwritten by the list of books left after
# filtering, or else the ebook title itself if no books were filtered out.
sub pruneFileOSIS($$$$$\$\$) {
  my $inosis = shift;
  my $outosis = shift;
  my $scope = shift;
  my $vsys = shift;
  my $bookTitleTocNum = shift;
  my $ebookTitleP = shift;
  my $ebookPartTitleP= shift;
  
  my $typeRE = '^('.join('|', keys(%PERIPH_TYPE_MAP_R), keys(%ID_TYPE_MAP_R)).')$';
  $typeRE =~ s/\-/\\-/g;
  
  my $inxml = $XML_PARSER->parse_file($inosis);
  
  my $bookOrderP;
  my $booksFiltered = 0;
  if (&getCanon($vsys, NULL, \$bookOrderP, NULL)) {
    my @lostIntros;
    my %scopeBookNames = map { $_ => 1 } @{&scopeToBooks($scope, $bookOrderP)};
    # remove books not in scope
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
    my @filteredBooks;
    foreach my $bk (@books) {
      my $id = $bk->getAttribute('osisID');
      if (!exists($scopeBookNames{$id})) {
        my @divs = $XPC->findnodes('./osis:div[@type]', $bk);
        foreach my $div (@divs) {
          if ($div->getAttribute('type') !~ /$typeRE/i) {next;}
          push(@lostIntros, $div);
        }
        $bk->unbindNode();
        push(@filteredBooks, $id);
        $booksFiltered++;
      }
    }
    if (@filteredBooks) {
      &Log("NOTE: Filtered \"".scalar(@filteredBooks)."\" books that were outside of scope \"$scope\".\n", 1);
    }
    # remove bookGroup if it has no books left (even if it contains other peripheral material)
    my @emptyBookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"][not(osis:div[@type="book"])]', $inxml);
    my $msg = 0;
    foreach my $ebg (@emptyBookGroups) {$ebg->unbindNode(); $msg++;}
    if ($msg) {
      &Log("NOTE: Filtered \"$msg\" bookGroups which contained no books.\n", 1);
    }
    # move each lost book intro to the first applicable book, or leave it out if there is no applicable book
    my @remainingBooks = $XPC->findnodes('.//osis:osisText//osis:div[@type="book"]', $inxml);
    INTRO: foreach my $intro (reverse(@lostIntros)) {
      my $introBooks = &scopeToBooks($intro->getAttribute('osisRef'), $bookOrderP);
      if (!@{$introBooks}) {next;}
      foreach $introbk (@{$introBooks}) {
        foreach my $remainingBook (@remainingBooks) {
          if ($remainingBook->getAttribute('osisID') ne $introbk) {next;}
          $remainingBook->insertBefore($intro, $remainingBook->firstChild);
          my $t1 = $intro; $t1 =~ s/>.*$/>/s;
          my $t2 = $remainingBook; $t2 =~ s/>.*$/>/s;
          &Log("NOTE: Moved peripheral: $t1 to $t2\n", 1);
          next INTRO;
        }
      }
    }
  }
  else {&Log("ERROR: Failed to read vsys \"$vsys\", not pruning books in OSIS file!\n");}
  
  # remove the TOC entry from the bookGroup, unless there are other bookGroups, to prevent unnecessary TOC levels
  my @grps = $XPC->findnodes('//osis:div[@type="bookGroup"]', $inxml);
  if (scalar(@grps) == 1 && @grps[0]) {
    my @ms = $XPC->findnodes('child::osis:milestone[starts-with(@type, "x-usfm-toc")] | child::*[1][not(self::osis:div[@type="book"])]/osis:milestone[starts-with(@type, "x-usfm-toc")]', @grps[0]);
    if (@ms && @ms[0]) {
      @ms[0]->unbindNode();
      my $n = (@ms[0]->getAttribute('n') ? @ms[0]->getAttribute('n'):'NO-TITLE');
      &Log("NOTE: Removed TOC milestone from bookGroup titled \"$n\" because there is only one bookGroup in the OSIS file.\n", 1);
    }
  }
  
  # determine titles
  my $osisTitle = @{$XPC->findnodes('//osis:type[@type="x-bible"][1]/ancestor::osis:work[1]//osis:title[1]', $inxml)}[0];
  if (!$$ebookTitleP) {$$ebookTitleP = $osisTitle->textContent;}
  if ($booksFiltered) {
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
    my @bookNames;
    foreach my $b (@books) {
      my @t = $XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.$bookTitleTocNum.'"]/@n', $b);
      if (@t[0]) {push(@bookNames, @t[0]->getValue());}
    }
    $$ebookPartTitleP = join(', ', @bookNames);
  }
  else {$$ebookPartTitleP = $$ebookTitleP;}
  if ($booksFiltered) {$$ebookTitleP .= ": $$ebookPartTitleP";}
  if ($$ebookTitleP ne $osisTitle->textContent) {
    foreach my $c ($osisTitle->childNodes()) {$c->unbindNode();}
    $osisTitle->appendText($$ebookTitleP);
    &Log('NOTE: Updated OSIS title to "'.$osisTitle->textContent."\"\n", 1);
  }
  
  open(OUTF, ">$outosis");
  print OUTF $inxml->toString();
  close(OUTF);
}

# Filter out Scripture reference links that are outside the scope of scripRefOsis
sub filterScriptureReferences($$) {
  my $osis = shift;
  my $scripRefOsis = shift;
  
  my $osis1 = $osis; $osis1 =~ s/^.*\///; my $scripRefOsis1 = $scripRefOsis; $scripRefOsis1 =~ s/^.*\///;
  &Log("\nFiltering Scripture references in \"$osis1\" that target outside \"$scripRefOsis1\".\n", 1);
  my %filteredBooks;
  my $total = 0;
  
  my $scripRefXml = $XML_PARSER->parse_file($scripRefOsis);
  my @booknames = $XPC->findnodes('//osis:div[@type="book"]/@osisID', $scripRefXml);
  my %scopeBookNames;
  foreach my $bn (@booknames) {$scopeBookNames{$bn->getValue()}++;}
  my $refWork = @{$XPC->findnodes('//osis:osisText/@osisIDWork', $scripRefXml)}[0]->getValue();
  
  my $xml = $XML_PARSER->parse_file($osis);
  my $osisRefWork = @{$XPC->findnodes('//osis:osisText/@osisRefWork', $xml)}[0]->getValue();
  my @links = $XPC->findnodes('//osis:reference[@osisRef and not(@type="x-glosslink" or @type="x-glossary")]', $xml);
  foreach my $link (@links) {
    if ($link->getAttribute('osisRef') =~ /^(([^\:]+?):)?([^\.]+)(\.|$)/) {
      my $book = $3;
      my $work = ($1 ? $2:$osisRefWork);
      if ($work eq $refWork && exists($scopeBookNames{$book})) {next;}
      $link->setAttribute('subType', 'x-not-found');
      $total++;
      $filteredBooks{$book}++;
      #&Log("Filtered: \"$work\", \"$book\"\n", 1);
    }
  }
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &Log("$MOD REPORT: \"$total\" Scripture references filtered. (targeting ".keys(%filteredBooks)." different books)\n\n", 1);
  return $total;
}

# Filter out glossary reference links that are outside the scope of glossRefOsis
sub filterGlossaryReferences($\@$) {
  my $osis = shift;
  my $glossRefOsisP = shift;
  my $filterNavMenu = shift;
  
  my @glossRefOsis1;
  my %refsInScope;
  foreach my $refxml (@{$glossRefOsisP}) {
    my $refxml1 = $refxml; $refxml1 =~ s/^.*\///; push(@glossRefOsis1, $refxml1);
    my $glossRefXml = $XML_PARSER->parse_file($refxml);
    my $work = @{$XPC->findnodes('//osis:osisText/@osisIDWork', $glossRefXml)}[0]->getValue();
    my @osisIDs = $XPC->findnodes('//osis:seg[@type="keyword"]/@osisID', $glossRefXml);
    my %ids;
    foreach my $osisID (@osisIDs) {
      my $id = $osisID->getValue();
      $id =~ s/^(\Q$work\E)://;
      $ids{$id}++;
    }
    $refsInScope{$work} = \%ids;
  }
  
  my $osis1 = $osis; $osis1 =~ s/^.*\///; 
  &Log("\nFiltering glossary references in \"$osis1\"".(@glossRefOsis1[0] ? " that target outside \"".join(", ", @glossRefOsis1)."\"":'').".\n", 1);
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # filter out x-navmenu lists if they aren't wanted
  if ($filterNavMenu) {
    my @navs = $XPC->findnodes('//osis:list[@subType="x-navmenu"]', $xml);
    foreach my $nav (@navs) {if ($nav) {$nav->unbindNode();}}
  }
  
  # filter out references outside our scope
  my @links = $XPC->findnodes('//osis:reference[@osisRef and (@type="x-glosslink" or @type="x-glossary")]', $xml);
  my @total; my $total = 0;
  foreach my $link (@links) {
    if ($link->getAttribute('osisRef') =~ /^(([^\:]+?):)?(.+)$/) {
      my $osisRef = $3;
      my $work = ($1 ? $2:@{$XPC->findnodes('//osis:osisText/@osisRefWork', $xml)}[0]->getValue());
      if (exists($refsInScope{$work}{$osisRef})) {next;}
      my @children = $link->childNodes();
      foreach my $child (@children) {$link->parentNode()->insertBefore($child, $link);}
      $link->unbindNode();
      $total{$osisRef}++;
      $total++;
    }
  }
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &Log("$MOD REPORT: \"$total\" glossary references filtered:\n", 1);
  foreach my $r (keys %total) {
    &Log(&decodeOsisRef($r)."\n");
  }
  return $total;
}


sub convertExplicitGlossaryElements(\@) {
  my $indexElementsP = shift;
  
  my $bookOrderP; &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);

  foreach my $g (@{$indexElementsP}) {
    my $before = $g->parentNode->toString();
    my $gl = $g->getAttribute("level1");
    my @tn = $XPC->findnodes("preceding::text()[1]", $g);
    if (@tn != 1 || @tn[0]->data !~ /\Q$gl\E$/) {
      &Log("ERROR: Could not locate preceding text node for explicit glossary entry \"$g\".\n");
      $ExplicitGlossary{$gl}{"Failed"}++;
      next;
    }
    # adjust @tn so index target is a separate text node
    my $tn0 = @tn[0];
    my $tn0v = $tn0->data; $tn0v =~ s/\Q$gl\E$//;
    $tn0->setData($tn0v);
    @tn[0] = XML::LibXML::Text->new($gl);
    $tn0->parentNode->insertAfter(@tn[0], $tn0);
    my @isGlossary = $XPC->findnodes('ancestor::osis:div[@type="glossary"]', @tn[0]);
    &addDictionaryLinks(\@tn, 1, (@isGlossary && @isGlossary[0]));
    if ($before eq $g->parentNode->toString()) {
      &Log("ERROR: Failed to convert explicit glossary index: $g\n\tText Node=".@tn[0]->data."\n");
      $ExplicitGlossary{$gl}{"Failed"}++;
      next;
    }
    $ExplicitGlossary{$gl}{&decodeOsisRef(@{$XPC->findnodes("preceding::reference[1]", $g)}[0]->getAttribute("osisRef"))}++;
    $g->parentNode->removeChild($g);
  }
}


# Add dictionary links as described in $DWF to the nodes pointed to 
# by $eP array pointer. Expected node types are element or text.
sub addDictionaryLinks(\@$$) {
  my $eP = shift; # array of text-nodes or text-node parent elements (NOTE: node element child elements are not touched)
  my $isExplicit = shift; # true if the node was marked in the text as a glossary link
  my $isGlossary = shift; # true if the node is in a glossary (See-Also linking)
  
  my $bookOrderP;
  foreach my $node (@$eP) {
    my $glossaryContext;
    my $glossaryScopeP;
    
    if ($isGlossary) {
      if (!$bookOrderP) {
        &getCanon(&getBibleVersificationFromNode($node), NULL, \$bookOrderP, NULL)
      }
      $glossaryContext = &decodeOsisRef(&glossaryContext($node));
      if (!$glossaryContext) {next;}
      $glossaryScopeP = &scopeToBooks(&getEntryScope($node), $bookOrderP);
      if (!$NoOutboundLinks{'haveBeenRead'}) {
        foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', $DWF)) {
          foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
        }
        $NoOutboundLinks{'haveBeenRead'}++;
      }
      if ($NoOutboundLinks{&entry2osisRef($MOD, $glossaryContext)}) {return;}
    }
  
    my @textchildren;
    my $container = ($node->nodeType == XML::LibXML::XML_TEXT_NODE ? $node->parentNode():$node);
    if ($node->nodeType == XML::LibXML::XML_TEXT_NODE) {push(@textchildren, $node);}
    else {@textchildren = $XPC->findnodes('child::text()', $container);}
    if ($MODDRV =~ /LD/ && $XPC->findnodes("self::$KEYWORD", $container)) {next;}
    my $text, $matchedPattern;
    foreach my $textchild (@textchildren) {
      $text = $textchild->data();
      if ($text =~ /^\s*$/) {next;}
      my $done;
      do {
        $done = 1;
        my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
        foreach my $part (@parts) {
          if ($part =~ /<reference.*?<\/reference[^>]*>/ || $part =~ /^[\s\n]*$/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $textchild, $isExplicit, $glossaryContext, $glossaryScopeP)) {$done = 0;}
        }
        $text = join('', @parts);
      } while(!$done);
      $text =~ s/<reference [^>]*osisRef="REMOVE_LATER"[^>]*>(.*?)<\/reference>/$1/g;
      
      # sanity check
      my $check = $text;
      $check =~ s/<[^>]*>//g;
      if ($check ne $textchild->data()) {
        &Log("ERROR addDictionaryLinks: Bible text was changed during glossary linking!!\nBEFORE=".$textchild->data()."\nAFTER =$check\n");
      }
      
      $text =~ s/(^|\s)&(\s|$)/&amp;/g;
      $textchild->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($text), $textchild);
      $textchild->unbindNode();
    }
  }
}

sub getBibleVersificationFromNode($) {
  my $node = shift;

  my $vsys = @{$XPC->findnodes('//osis:work/osis:type[@type="x-bible"]/following-sibling::osis:refSystem', $node)}[0]->textContent();
  $vsys =~ s/^Bible.//i;
  return $vsys;
}

sub getModFromNode($) {
  my $node = shift;

  return @{$XPC->findnodes('//osis:osisText', $node)}[0]->getAttribute('osisIDWork');
}

# Get any OSIS file header value, where:
#   name = name of the work element whose value is wanted
#   node = any node in the file
#   mod = (optional) work whose value is wanted. Default is SELF (not any companion).
#   attribsP = (optional) pointer to hash of work element attribs and values of the work element whose value is wanted
sub getOSISHeaderValueFromNode($$$$) {
  my $name = shift;
  my $node = shift;
  my $mod = shift;
  my $attribsP = shift;
  
  $mod = ($mod ? $mod:&getModFromNode($node));
  
  my $xpath = '//osis:header/osis:work[@osisWork="'.$mod.'"]/osis:'.$name.'';
  if ($attribsP) {
    my @atts;
    foreach my $a (sort keys %{$attribsP}) {
      push(@atts, '@'.$a.'="'.$attribsP->{$a}.'"');
    }
    if (@atts) {$xpath .= '['.join(' and ', @atts).']';}
  }
  
  my @r = $XPC->findnodes($xpath, $node);
  
  if (!@r || !@r[0]) {
    &Log("ERROR getOSISHeaderValueFromNode: No value found (xpath=\"$xpath\", node=\"$node\")\n");
    return '';
  }
  elsif (@r > 1) {
    &Log("WARNING getOSISHeaderValueFromNode: Multiple possible values found but returning only first (xpath=\"$xpath\", node=\"$node\")\n");
  }
  
  return @r[0]->textContent;
}

sub getProjectOsisFile($) {
  my $mod = shift;

  my $osis = '';
  
  # self
  if ($mod eq $MOD) {
    $osis = "$OUTDIR/$MOD.xml";
    return (-e $osis ? $osis:'');
  }
  
  my $dir = $OUTDIR; $dir =~ s/\b$MOD\b/$mod/;
  
  # explicit output location
  if (-e "$dir/$mod.xml") {$osis = "$dir/$mod.xml";}
  # Bible looking for dict
  elsif (-e "$INPD/$mod/output/$mod.xml") {$osis = "$INPD/$mod/output/$mod.xml";}
  # dict looking for Bible
  elsif (-e "$INPD/../output/$mod.xml") {$osis = "$INPD/../output/$mod.xml";}
  # not found
  elsif (!$GETPROJECTOSISFILE_WARN{$mod}) {
    &Log("WARNING: Output project OSIS file \"$mod\" could not be found.\n");
    $GETPROJECTOSISFILE_WARN{$mod}++;
  }
  return $osis;
}


# Searches and replaces $$tP text for a single dictionary link, according 
# to the $DWF file, and logs any result. If a match is found, the proper 
# reference tags are inserted, and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$$\@) {
  my $textP = shift;
  my $textNode = shift;
  my $isExplicit = shift; # true if the node was marked in the text as a glossary link
  my $glossaryContext = shift; # for SeeAlso links only
  my $glossaryScopeP = shift; # for SeeAlso links only

  my $matchedPattern = '';
  
  # Cache match related info
  if (!@MATCHES) {
    my @ms = $XPC->findnodes("//dw:match", $DWF);
    my @ns = $XPC->findnodes("//dw:name", $DWF);
    foreach my $m (@ms) {
      my %minfo;
      $minfo{'node'} = $m;
      $minfo{'notExplicit'} = &attributeIsSet('notExplicit', $m);
      $minfo{'onlyExplicit'} = &attributeIsSet('onlyExplicit', $m);
      $minfo{'onlyOldTestament'} = &attributeIsSet('onlyOldTestament', $m);
      $minfo{'onlyNewTestament'} = &attributeIsSet('onlyNewTestament', $m);
      $minfo{'multiple'} = &attributeIsSet('multiple', $m);
      $minfo{'dontLink'} = &attributeIsSet('dontLink', $m);
      $minfo{'context'} = &getScopedAttribute('context', $m);
      $minfo{'notContext'} = &getScopedAttribute('notContext', $m);
      $minfo{'notXPATH'} = &getScopedAttribute('notXPATH', $m);
      $minfo{'XPATH'} = &getScopedAttribute('XPATH', $m);
      $minfo{'osisRef'} = @{$XPC->findnodes('ancestor::dw:entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
      $minfo{'name'} = @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent;
      foreach my $n (@ns) {
        if (!&matchInEntry($m, $n->textContent)) {next;}
        $minfo{'inEntries'}{$n->textContent}++;
      }
      
      # test match pattern, so any errors with it can be found right away
      if ($m->textContent !~ /(?<!\\)\(.*(?<!\\)\)/) {
        &Log("ERROR: Skipping match \"$m\" becauase it is missing capture parentheses!\n");
        next;
      }
      my $test = "testme"; my $is; my $ie;
      if (&glossaryMatch(\$test, $m, \$is, \$ie) == 2) {next;}
      
      push(@MATCHES, \%minfo);
    }
  }
  
  my $context;
  my $multiples_context;
  if ($glossaryContext) {$context = $glossaryContext; $multiples_context = $glossaryContext;}
  else {
    $context = &bibleContext($textNode);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &myContext('OT', $context);
  my $contextIsNT = &myContext('NT', $context);
  my @contextNote = $XPC->findnodes("ancestor::osis:note", $textNode);
  
  my $a;
  foreach my $m (@MATCHES) {
    my $removeLater = $m->{'dontLink'};
#@DICT_DEBUG = ($context, @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m->{'node'})}[0]->textContent()); @DICT_DEBUG_THIS = ("Gen.49.10.10", decode("utf8", "АҲД САНДИҒИ"));
#@DICT_DEBUG = ($textNode); @DICT_DEBUG_THIS = (decode("utf8", "Ким мени севса ўшани севаман,"));
#&dbg("\nMatch: ".$m->{'node'}->textContent."\n"); foreach my $k (keys %{$m}) {if ($k !~ /^(node|inEntries)$/) {&dbg("\t\t$k = ".$m->{$k}."\n");}} &dbg("\n");
    &dbg(sprintf("\nNode(type %s, %s): %s\nText: %s\nMatch: %s\n", $textNode->parentNode()->nodeType, $context, $textNode, $$textP, $m->{'node'}));
    
    # Explicitly marked phrases should always be linked, unless match is designated as notExplicit="true"
    if ($isExplicit) {
      if ($m->{'notExplicit'}) {&dbg("00\n"); next;}
    }
    else {
      if ($m->{'onlyExplicit'}) {&dbg("01\n"); next;}
      if ($glossaryContext && $m->{'inEntries'}{$glossaryContext}) {&dbg("05\n"); next;} # never add glossary links to self
      if (!$contextIsOT && $m->{'onlyOldTestament'}) {&dbg("filtered at 10\n"); next;}
      if (!$contextIsNT && $m->{'onlyNewTestament'}) {&dbg("filtered at 20\n"); next;}
      if (!$m->{'multiple'}) {
        if (@contextNote > 0) {if ($MULTIPLES{$m->{'node'}->unique_key . ',' .@contextNote[$#contextNote]->unique_key}) {&dbg("filtered at 35\n"); next;}}
        # $removeLater disallows links within any phrase that was previously skipped as a multiple.
        # This helps prevent matched, but unlinked, phrases inadvertantly being torn into smaller, likely irrelavent, entry links.
        elsif ($MULTIPLES{$m->{'node'}->unique_key}) {&dbg("filtered at 40\n"); $removeLater = 1;}
      }
      if ($m->{'context'}) {
        my $gs = scalar(@{$glossaryScopeP}); my $ic = &myContext($m->{'context'}, $context); my $igc = ($gs ? &myGlossaryContext($m->{'context'}, $glossaryScopeP):0);
        if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {&dbg("filtered at 50\n"); next;}
      }
      if ($m->{'notContext'}) {
        if (&myContext($m->{'notContext'}, $context)) {&dbg("filtered at 60\n"); next;}
      }
      if ($m->{'XPATH'}) {
        my @tst = $XPC->findnodes($m->{'XPATH'}, $textNode);
        if (!@tst || !@tst[0]) {&dbg("filtered at 70\n"); next;}
      }
      if ($m->{'notXPATH'}) {
        @tst = $XPC->findnodes($m->{'notXPATH'}, $textNode);
        if (@tst && @tst[0]) {&dbg("filtered at 80\n"); next;}
      }
    }
    
    my $is; my $ie;
    if (&glossaryMatch($textP, $m->{'node'}, \$is, \$ie)) {next;}
    if ($is == $ie) {
      &Log("ERROR: Match result was zero width!: \"".$m->{'node'}->textContent."\"\n");
      next;
    }
    
    $MatchesUsed{$m->{'node'}->unique_key}++;
    $matchedPattern = $m->{'node'}->textContent;
    my $osisRef = ($removeLater ? 'REMOVE_LATER':$m->{'osisRef'});
    my $attribs = "osisRef=\"$osisRef\" type=\"".($MODDRV =~ /LD/ ? 'x-glosslink':'x-glossary')."\"";
    my $match = substr($$textP, $is, ($ie-$is));
    
    substr($$textP, $ie, 0, "</reference>");
    substr($$textP, $is, 0, "<reference $attribs>");
    
    if (!$removeLater) {
      # record hit...
      $EntryHits{$m->{'name'}}++;
      
      my $logContext = $context;
      $logContext =~ s/\..*$//; # keep book/entry only
      $EntryLink{&decodeOsisRef($m->{'osisRef'})}{$logContext}++;
      
      my $dict;
      foreach my $sref (split(/\s+/, $m->{'osisRef'})) {
        if (!$sref) {next;}
        my $e = &osisRef2Entry($sref, \$dict);
        $Replacements{$e.": ".$match.", ".$dict}++;
      }

      if (@contextNote > 0) {$MULTIPLES{$m->{'node'}->unique_key . ',' .@contextNote[$#contextNote]->unique_key}++;}
      else {$MULTIPLES{$m->{'node'}->unique_key}++;}
    }
    
    last;
  }
 
  return $matchedPattern;
}

# Look for a single match $m in $$textP and set its start/end positions
# if one is found. Returns 0 if a match was found; or else 1 if no 
#  match was found, or 2 on error.
sub glossaryMatch(\$$\$\$) {
  my $textP = shift;
  my $m = shift;
  my $isP = shift;
  my $ieP = shift;
  
  my $p = $m->textContent;
  if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {
    &Log("ERROR: Bad match regex: \"$p\"\n");
    &dbg("80\n");
    return 2;
  }
  my $pm = $1; my $pf = $2;
  
  # handle PUNC_AS_LETTER word boundary matching issue
  if ($PUNC_AS_LETTER) {
    $pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;
  }
  
  # handle xml decodes
  $pm = decode_entities($pm);
  
  # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
  my $t = $$textP;
  my $i = $pf =~ s/i//;
  $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;
  if ($i) {
    $t = &uc2($t);
  }
  if ($pf =~ /(\w+)/) {
    &Log("ERROR: Regex flag \"$1\" not supported in \"".$m->textContent."\"");
  }
 
  # finally do the actual MATCHING...
  &dbg("pattern matching ".($t !~ /$pm/ ? "failed!":"success!").": \"$t\" =~ /$pm/\n"); 
  if ($t !~ /$pm/) {
    return 1;
  }

  $$isP = $-[$#+];
  $$ieP = $+[$#+];
  
  # if a (?'link'...) named group 'link' exists, use it instead
  if (defined($+{'link'})) {
    my $i;
    for ($i=0; $i <= $#+; $i++) {
      if ($$i eq $+{'link'}) {last;}
    }
    $$isP = $-[$i];
    $$ieP = $+[$i];
  }
  
  &dbg("LINKED: $pm\n$t\n$$isP, $$ieP, ".$+{'link'}.".\n");
  
  return 0;
}

# Takes the context or notContext attribute value from DWF and determines
# whether it is a Paratext reference list or not. If it is, it's converted
# to a valid osisRef. If there are any errors, the value is returned unchanged.
sub contextAttribute2osisRefAttribute($) {
  my $val = shift;
  
  if ($CONVERTED_P2O{$val}) {return $CONVERTED_P2O{$val};}
  
  my @parts;
  @parts = split(/\s*,\s*/, $val);
  my $reportParatextWarnings = (($val =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1) ? 1:0) || (scalar(@parts) > 3));
  foreach my $part (@parts) {
    if ($part =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1)) {next;}
    if ($reportParatextWarnings) {
      &Log("WARNING: Attribute part \"$part\" might be a failed Paratext reference in \"$val\".\n");
    }
    return $val;
  }
  
  my $p1; my $p2;
  my @osisRefs = ();
  foreach my $part (@parts) {
    my @pOsisRefs = ();
    
    # book-book (assumes Paratext and OSIS verse system's book orders are the same)
    if ($part =~ /^([\d\w]\w\w)\s*\-\s*([\d\w]\w\w)$/) {
      my $bk1 = $1; my $bk2 = $2;
      $bk1 = &getOsisName($bk1, 1);
      $bk2 = &getOsisName($bk2, 1);
      if (!$bk1 || !$bk2) {
        &Log("ERROR contextAttribute2osisRefAttribute: Bad Paratext book name(s) \"$part\" of \"$val\"!\n");
        return $val;
      }
      push(@pOsisRefs, "$bk1-$bk2");
    }
    else {
      my $bk;
      my $bkP;
      my $ch;
      my $chP;
      my $vs;
      my $vsP;
      my $lch;
      my $lchP;
      my $lvs;
      # book ch-ch
      if ($part =~ /^([\d\w]\w\w)\s+(\d+)\s*\-\s*(\d+)$/) {
        $bk = $1;
        $ch = $2;
        $lch = $3;
        $bkP = 1;
      }
      # book, book ch, book ch:vs, book ch:vs-lch-lvs, book ch:vs-lvs
      elsif ($part !~ /^([\d\w]\w\w)(\s+(\d+)(\:(\d+)(\s*\-\s*(\d+)(\:(\d+))?)?)?)?$/) {
        &Log("ERROR contextAttribute2osisRefAttribute: Bad Paratext reference \"$part\" of \"$val\"!\n");
        return $val;
      }
      $bk = $1;
      $bkP = $2;
      $ch = $3;
      $chP = $4;
      $vs = $5;
      $vsP = $6;
      $lch = $7;
      $lchP = $8;
      $lvs = $9;
      
      if ($vsP && !$lchP) {$lvs = $lch; $lch = '';}
      
      my $bk = &getOsisName($bk, 1);
      if (!$bk) {
        &Log("ERROR contextAttribute2osisRefAttribute: Unrecognized Paratext book \"$bk\" of \"$val\"!\n");
        return $val;
      }
      
      if (!$bkP) {
        push(@pOsisRefs, $bk);
      }
      elsif (!$chP) {
        if ($lch) {
          for (my $i=$ch; $i<=$lch; $i++) {
            push(@pOsisRefs, "$bk.$i");
          }
        }
        push(@pOsisRefs, "$bk.$ch");
      }
      elsif (!$vsP) {
        push(@pOsisRefs, "$bk.$ch.$vs");
      }
      elsif (!$lchP) {
        push(@pOsisRefs, "$bk.$ch.$vs".($lvs != $vs ? "-$bk.$ch.$lvs":''));
      }
      else {
        my $canonP;
        # Bug warning - this assumes $VERSESYS is verse system of osisRef  
        &getCanon($VERSESYS, \$canonP, NULL, NULL, NULL);
        my $ch1lv = ($lch == $ch ? $lvs:@{$canonP->{$bk}}[($ch-1)]);
        push(@pOsisRefs, "$bk.$ch.$vs".($ch1lv != $vs ? "-$bk.$ch.$ch1lv":''));
        if ($lch != $ch) {
          if (($lch-$ch) >= 2) {
            push(@pOsisRefs, "$bk.".($ch+1).(($lch-1) != ($ch+1) ? "-$bk.".($lch-1):''));
          }
          push(@pOsisRefs, "$bk.$lch.1".($lvs != 1 ? "-$bk.$lch.$lvs":''));
        }
      }
    }
    
    push(@osisRefs, @pOsisRefs);
    my $new = join(' ', @pOsisRefs);
    my $len = length($part);
    if ($len < length($new)) {$len = length($new);}
    $p1 .= sprintf("%-".$len."s ", $part);
    $p2 .= sprintf("%-".$len."s ", $new);
  }
  
  my $ret = join(' ', @osisRefs);
  if ($ret ne $val) {
    $CONVERTED_P2O{$val} = $ret;
    &Log("NOTE: Converted Paratext context attribute to OSIS:\n\tParatext: $p1\n\tOSIS:     $p2\n\n");
  }
  
  return $ret;
}


sub matchInEntry($$) {
  my $m = shift;
  my $entry = shift;
  
  my $osisRef = @{$XPC->findnodes('ancestor::dw:entry[1]', $m)}[0]->getAttribute('osisRef');
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


# Scoped attributes are hierarchical and cummulative. They occur in both
# positive and negative (not) forms. A positive attribute cancels any
# negative forms of that attribute occuring higher in the hierarchy.
sub getScopedAttribute($$) {
  my $a = shift;
  my $m = shift;
  
  my $ret = '';
  
  my $positive = ($a =~ /^not(.*?)\s*$/ ? lcfirst($1):$a);
  if ($positive =~ /^xpath$/i) {$positive = uc($positive);}
  my $negative = ($a =~ /^not/ ? $a:'not'.ucfirst($a));
    
  my @r = $XPC->findnodes("ancestor-or-self::*[\@$positive or \@$negative]", $m);
  if (@r && @r[0]) {
    my @ps; my @ns;
    foreach my $re (@r) {
      my $p = $re->getAttribute($positive);
      if ($p) {
        if ($positive eq 'context') {$p = &contextAttribute2osisRefAttribute($p);}
        push(@ps, $p);
        @ns = ();
      }
      my $n = $re->getAttribute($negative);
      if ($n) {
        if ($positive eq 'context') {$n = &contextAttribute2osisRefAttribute($n);}
        push(@ns, $n);
      }
    }
    my $retP = ($a eq $positive ? \@ps:\@ns);
    if (@{$retP} && @{$retP}[0]) {
      $ret = join(($a =~ /XPATH/ ? '|':' '), @{$retP});
    }
  }
  
  return $ret;
}


sub dbg($$) {
  my $p = shift;
  
#for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {&Log(@DICT_DEBUG_THIS[$i]." ne ".@DICT_DEBUG[$i]."\n", 1);}
  
  if (!@DICT_DEBUG_THIS) {return 0;}
  for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {
    if (@DICT_DEBUG_THIS[$i] ne @DICT_DEBUG[$i]) {return 0;}
  }
  
  &Log($p);
  return 1;
}


# return context if any part of context is a part of $test, else 0
# $context may be a dictionary entry or a special Bible range - see bibleContext()
# $test can be:
#   keyword - return context IF it is part of keyword's scope
#   encoded osisRef - return context IF it is within scope of osisRef (which may include multiple ranges)
# else return 0
sub myContext($$) {
  my $test = shift;
  my $context = shift;

  my $test2 = $test;
  if ($test eq 'OT') {
    if ($context =~ /^TESTAMENT_INTRO\.0\./) {return $context;}
    $test2 = $OT_BOOKS;
  }
  elsif ($test eq 'NT') {
    if ($context =~ /^TESTAMENT_INTRO\.1\./) {return $context;}
    $test2 = $NT_BOOKS;
  }
  foreach my $testPart (split(/\s+/, $test2)) {
    if ($testPart =~ /^\s*$/) {next;}
    if (!$REF_SEG_CACHE{$testPart}) {$REF_SEG_CACHE{$testPart} = &osisRef2array($testPart);}
    foreach my $testSegment (@{$REF_SEG_CACHE{$testPart}}) {
      foreach my $contextSegment (&context2array($context)) {
        my $xTestSegmentAfterBK = $testSegment;
        if ($xTestSegmentAfterBK =~ s/^xALL(?=\.)//) {
          if (!$AllBooksRE) {$AllBooksRE = join('|', @OT_BOOKS, @NT_BOOKS);}
          if ($contextSegment =~ /^($AllBooksRE)\Q$xTestSegmentAfterBK\E/i) {return $context;}
        }
        else {
          # is this contextSegment part of this testSegment?
          if ($contextSegment =~ /\Q$testSegment\E/i) {return $context;}
        }
      }
    }
  }

  return 0;
}

sub myGlossaryContext($\@) {
  my $test = shift;
  my $contextP = shift;
 
  foreach my $c (@{$contextP}) {
    if (&myContext($test, $c)) {return $c;}
  }
  
  return 0;
}

# return special Bible context reference for $node:
# BIBLE_INTRO.0.0.0 = Bible intro
# TESTAMENT_INTRO.0.0.0 = Old Testament intro
# TESTAMENT_INTRO.1.0.0 = New Testament intro
# Gen.0.0.0 = Gen book intro
# Gen.1.0.0 = Gen chapter 1 intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext($) {
  my $node = shift;
  
  my $context = '';
  
  # get book
  my @bk = $XPC->findnodes('ancestor-or-self::osis:div[@type=\'book\'][@osisID][1]', $node);
  my $bk = (@bk ? @bk[0]->getAttribute('osisID'):'');
  
  # no book means we might be a Bible or testament introduction (or else an entirely different type of OSIS file)
  if (!$bk) {
    my $refSystem = &getOSISHeaderValueFromNode('refSystem', $node);
    if ($refSystem !~ /^Bible/) {
      &Log("ERROR bibleContext: OSIS file is not a Bible \"$refSystem\" for node \"$node\"\n");
      return '';
    }
    my @tst = $XPC->findnodes('ancestor-or-self::osis:div[@type=\'bookGroup\'][1]', $node);
    if (@tst && @tst[0]) {
      return "TESTAMENT_INTRO.".(0+@{$XPC->findnodes('preceding::osis:div[@type=\'bookGroup\']', @tst[0])}).".0.0";
    }
    return "BIBLE_INTRO.0.0.0";
  }

  my @e;
  if (@bk && $bk) {
    # find most specific osisID associated with elem (assumes milestone verse/chapter tags and end tags which have no osisID attribute)
    my @v = $XPC->findnodes('preceding::osis:verse[@osisID][1]', $node);
    if (@v && @v[0]->getAttribute('osisID') !~ /^\Q$bk.\E/) {@v = ();}

    my @c = $XPC->findnodes('preceding::osis:chapter[@osisID][1]', $node);
    if (@c && @c[0]->getAttribute('osisID') !~ /^\Q$bk.\E/) {@c = ();}
    
    # if we have verse and chapter, but verse is not within chapter, use chapter instead
    if (@v && @v[0]) {
      if (@c && @c[0]) {
        my $bkch;
        if (@v[0]->getAttribute('osisID') =~ /^([^\.]*\.[^\.]*)(\.|$)/) {
          $bkch = $1;
        }
        if (!$bkch || @c[0]->getAttribute('osisID') !~ /^\Q$bkch\E(\.|$)/) {
          @e = @c;
        }
      }
      if (!@e) {@e = @v;}
    }
    else {@e = @c;}
    
    if (!@e || !@e[0]) {@e = @bk;}
  }
  
  # get context from most specific osisID
  if (@e) {
    my $id = @e[0]->getAttribute('osisID');
    $context = ($id ? $id:"unk.0.0.0");
    if ($id =~ /^\w+$/) {$context .= ".0.0.0";}
    elsif ($id =~ /^\w+\.\d+$/) {$context .= ".0.0";}
    elsif ($id =~ /^\w+\.\d+\.(\d+)$/) {$context .= ".$1";}
    elsif ($id =~ /^(\w+\.\d+\.\d+) .*\w+\.\d+\.(\d+)$/) {$context = "$1.$2";}
  }
  else {
    &Log("ERROR: Could not determine context of \"$node\"\n");
    return 0;
  }
  
  return $context;
}

# return special Glossary context reference for $node:
# BEFORE_keyword = Node is not part of any keyword but next one is keyword
# keyword = Node is part of keyword's entry
sub glossaryContext($) {
  my $node = shift;
  
  # is node in a type div?
  my @typeXPATH; foreach my $sb (@USFM2OSIS_PY_SPECIAL_BOOKS) {push(@typeXPATH, "\@type='$sb'");}
  my $typeDiv = @{$XPC->findnodes('./ancestor::osis:div['.join(' or ', @typeXPATH).'][last()]', $node)}[0];
  if (!$typeDiv) {return '';}

  # get preceding keyword
  my $prevkw = @{$XPC->findnodes('preceding::osis:seg[@type="keyword"][1]', $node)}[0];
  
  if ($prevkw) {
    foreach my $kw ($XPC->findnodes('.//osis:seg[@type="keyword"]', $typeDiv)) {
      if ($kw->isSameNode($prevkw)) {
        if (!$prevkw->getAttribute('osisID')) {
          &Log("ERROR glossaryContext: Previous keyword has no osisID \"$prevkw\"\n");
        }
        return $prevkw->getAttribute('osisID');
      }
    }
  }
  
  # if not, then use BEFORE
  my $nextkw = @{$XPC->findnodes('following::osis:seg[@type="keyword"]', $node)}[0];
  if (!$nextkw) {return "BEFORE_unknown";}
  
  if (!$nextkw->getAttribute('osisID')) {
    &Log("ERROR glossaryContext: Next keyword has no osisID \"$nextkw\"\n");
    return '';
  }
  return 'BEFORE_'.$nextkw->getAttribute('osisID');
}


# return array of single verse osisRefs from context, since context may 
# be a bibleContext covering a range of verses. Returned refs are NOT
# encoded osisRefs.
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


# return a valid array of non-hyphenated osisRef segments from a singular 
# osisRef, which may contain a hyphen, but no spaces. Returned refs are 
# DECODED osisRefs. An ERROR is thrown if an invalid book or reference 
# is found.
sub osisRef2array($) {
  my $osisRef = shift;
  
  my @refs = ();
  
  if ($osisRef eq 'OT') {$osisRef = "Gen-Mal"; push(@refs, "TESTAMENT_INTRO.0");}
  elsif ($osisRef eq 'NT') {$osisRef = "Matt-Rev"; push(@refs, "TESTAMENT_INTRO.1");}

  if ($osisRef !~ /^(.*?)\-(.*)$/) {
    if (!&validOsisRefSegment($osisRef)) {return \@refs;}
    my $mod;
    push(@refs, &osisRef2Entry($osisRef, \$mod, 1));
    return (\@refs); # returns decoded osisRef
  }
  my $r1 = $1; my $r2 = $2;
  
  my ($b1, $c1, $v1);
  if (!&validOsisRefSegment($r1, '', \$b1, \$c1, \$v1)) {return \@refs;}
  my ($b2, $c2, $v2);
  if (!&validOsisRefSegment($r2, '', \$b2, \$c2, \$v2)) {return \@refs;}

  my ($canonP, $bookOrderP, $bookArrayP);
  &getCanon($VERSESYS, \$canonP, \$bookOrderP, NULL, \$bookArrayP);

  # iterate from starting verse?
  if ($v1 > 0) {
    my $ve = (($b1 eq $b2 && $c1==$c2) ? $v2:@{$canonP->{$b1}}[$c1-1]);
    for (my $v=$v1; $v<=$ve; $v++) {push(@refs, "$b1.$c1.$v");}
  }
  # iterate from starting chapter?
  if ($c1 > 0) {
    my $ce = ($b1 eq $b2 ? ($v2>0 ? ($c2-1):$c2):@{$canonP->{$b1}});
    for (my $c=($v1>0 ? ($c1+1):$c1); $c<=$ce; $c++) {push(@refs, "$b1.$c");}
  }
  # iterate from starting book?
  if ($b1 ne $b2) {
    my $bs = ($c1>0 ? $bookOrderP->{$b1}+1:$bookOrderP->{$b1});
    my $be = ($c2>0 ? $bookOrderP->{$b2}-1:$bookOrderP->{$b2});
    for (my $b=$bs; $b<=$be; $b++) {push(@refs, @{$bookArrayP}[$b]);}
    # iterate to ending chapter?
    if ($c2 > 0) {
      for (my $c=1; $c<=($v2>0 ? $c2-1:$c2); $c++) {push(@refs, "$b2.$c");}
    }
  }
  # iterate to ending verse?
  if ($v2 > 0 && !($b1 eq $b2 && $c1==$c2)) {
    for (my $v=1; $v<=$v2; $v++) {push(@refs, "$b2.$c2.$v");}
  }

  return \@refs;
}


# Check an osisRef segment (which cannot contain "-") against the verse system or dictionary words.
# Returns 0 if invalid, 1 if valid, or -1 if it cannot be determined
my %VALIDATE_OSISREF_CACHE;
sub validOsisRefSegment($$\$\$\$\$\$) {
  my $osisRef = shift;
  my $osis = shift;    # optional OSIS file root node, but without it some refs cannot be validated
  my $bP = shift;      # optional book return
  my $cP = shift;      # optional chapter return
  my $vP = shift;      # optional verse return
  my $modP = shift;    # optional module return
  my $typeP = shift;   # optional type return
  my $extP = shift;    # optional extension return

  my $b; if (!$bP) {$bP = \$b;}
  my $c; if (!$cP) {$cP = \$c;}
  my $v; if (!$vP) {$vP = \$v;}
  my $mod; if (!$modP) {$modP = \$mod;}
  my $type; if (!$typeP) {$typeP = \$type;}
  my $ext; if (!$extP) {$extP = \$ext;}
  
  $validValue = 1; # is either 1 or -1, and is returned only if possibly valid
  
  if ($osisRef =~ s/!(.*)$//) {
    $$extP = $1;
  }
  
  if ($osisRef =~ s/^([\w\d]+)\://) {
    $$modP = $1;
  }
  elsif ($osis) {
    if ($VALIDATE_REF_MOD{$osis->unique_key}) {
      $$modP = $VALIDATE_REF_MOD{$osis->unique_key};
    }
    else {
      $$modP = @{$XPC->findnodes('//osis:osisText', $osis)}[0]->getAttribute('osisRefWork');
      if (!$$modP) {
        &Log("ERROR validOsisRefSegment: OSIS file osisText element doesn't have an osisRefWork attribute.\n");
      }
    }
    
    $VALIDATE_REF_MOD{$osis->unique_key} = $$modP;
  }
  
  if ($$extP) {
    if ($osis && $$modP && $$modP eq &getModFromNode($osis)) {
      if (!@{$XPC->findnodes('//*[@osisID="'.$osisRef.'!'.$$extP.'"]', $osis)}) {
        &Log("ERROR validOsisRefSegment: Reference target osisID \"$osisRef!$$extP\" does not exist.\n");
        return 0;
      }
    }
    elsif ($OSISID_FOOTNOTE{"$$modP:$osisRef!$$extP"}) {$validValue = 1;}
    else {$validValue = -1;}
  }
  
  my $vsys = ($$modP =~ /DICT$/ ? "Dict.$$modP":"Bible.$VERSESYS"); # default, unless osis is provided
  if ($osis) {
    if ($VALIDATE_REF_VSYS{$$modP}) {$vsys = $VALIDATE_REF_VSYS{$$modP};}
    else {
      my @refSystem = $XPC->findnodes('//osis:work[@osisWork="'.$$modP.'"]//osis:refSystem', $osis);
      if (!@refSystem || !@refSystem[0]) {
        &Log("ERROR validOsisRefSegment: OSIS file does not specify refSystem of \"$$modP\"!\n");
      }
      else {$vsys = @refSystem[0]->textContent;}
    
      $VALIDATE_REF_VSYS{$$modP} = $vsys;
    }
  }
  $vsys =~ s/^([^\.]+)\.//;
  $$typeP = $1;
    
  if ($$typeP eq 'Dict') {
    # don't complain if this is a NAVMENU keyword which is missing from DictionaryWords.xml
    if ($$modP && !$VALIDATE_OSISREF_CACHE{$$modP}) {
      my $file = &getProjectOsisFile($$modP);
      if ($file) {$VALIDATE_OSISREF_CACHE{$$modP} = $XML_PARSER->parse_file($file);}
    }
    if ($VALIDATE_OSISREF_CACHE{$$modP}) {
      my @kw = $XPC->findnodes("//osis:seg[\@type='keyword'][\@osisID='$osisRef']", $VALIDATE_OSISREF_CACHE{$$modP});
      if (@kw && @kw[0] && @{$XPC->findnodes('ancestor::osis:div[@type="glossary"][@osisRef="NAVMENU"]', @kw[0])}[0]) {return 1;}
    }
    if (!$DWF) {return -1;}
    my @tst = $XPC->findnodes("//dw:entry[\@osisRef='$$modP:$osisRef']", $DWF);
    if (!@tst || !@tst[0]) {
      &Log("ERROR validOsisRefSegment: Entry with osisRef=\"$$modP:$osisRef\" was not found in DictionaryWords.xml file.\n");
      return 0;
    }
    
    return $validValue;
  }
  
  if ($osisRef !~ /^([\w\d]+)(\.(\d+)(\.(\d+))?)?$/) {
    &Log("ERROR validOsisRefSegment: Bad Bible reference \"$osisRef\"\n");
    return 0;
  }
   
  $$bP = $1;
  $$cP = ($2 ? $3:0);
  $$vP = ($4 ? $5:0);
  
  if ($osisRef =~ /^BIBLE_INTRO(\.0(\.0)?)?$/) {
    $$cP = 0;
    $vP = 0;
    return $validValue;
  }
  
  if ($osisRef =~ /^TESTAMENT_INTRO\.(0|1)(\.0)?$/) {
    $$cP = $1;
    $vP = 0;
    return $validValue;
  }
  
  if ($osisRef =~ /^xALL\./) {return $validValue;} # xALL is allowed as matching any book
  
  if ($OT_BOOKS !~ /\b$$bP\b/ && $NT_BOOKS !~ /\b$$bP\b/) {
    &Log("ERROR: Unrecognized OSIS book: \"$$bP\"\n");
    return 0;
  }
  
  my ($canonP, $bookOrderP, $bookArrayP);
  &getCanon($vsys, \$canonP, \$bookOrderP, NULL, \$bookArrayP);
  
  if ($$cP != 0 && ($$cP < 0 || $$cP > @{$canonP->{$$bP}})) {
    &Log("ERROR: Chapter is not in verse system $vsys: \"$$bP.$$cP\"\n");
    return 0;
  }
  
  if ($$vP != 0 && ($$vP < 0 || $$vP > @{$canonP->{$$bP}}[$$cP-1])) {
    &Log("ERROR: Verse is not in verse system $vsys: \"$$bP.$$cP.$$vP\"\n");
    return 0;
  }
  
  return $validValue;
}


# Check all reference links, and report any errors. This CANNOT USE
# splitOSIS() even though it's slow, since targets are checked.
sub checkReferenceLinks($) {
  my $in_osis = shift;
  
  undef(%VALIDATE_OSISREF_CACHE);
  
  &Log("\nCHECKING REFERENCE OSISREF TARGETS IN $in_osis...\n");
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  
  my @links = $XPC->findnodes('//osis:reference', $osis);
  
  my %linkcount = ('gloss' => 0, 'scrip' => 0, 'unknown' => 0);
  my %errors = ('gloss' => 0, 'scrip' => 0);
  foreach my $l (@links) {
    my $linktype = ($l->getAttribute('type') =~ /^(\Qx-glossary\E|\Qx-glosslink\E)$/ ? 'gloss':'scrip');
    
    $linkcount{$linktype}++;
    
    if (!$l->textContent || $l->textContent =~ /^[\s\n]*$/) {
      &Log("ERROR Reference link \"$l\" has no text content!\n");
      $errors{$linktype}++;
    }
    
    my $osisRef = $l->getAttribute('osisRef');
    if (!$osisRef) {
      &Log("ERROR: Reference link \"$l\" is missing osisRef attribute!\n");
      $errors{$linktype}++;
      next;
    }
    
    my @srefs1 = split(/\s+/, $osisRef);
    foreach my $sref1 (@srefs1) {
      my @srefs = split(/\-/, $sref1);
      my $m = (@srefs[0] =~ s/^([\w\d]+\:)// ? $1:'');
      foreach my $sref (@srefs) {
        my $type; my $mod;
        my $isValid = &validOsisRefSegment("$m$sref", $osis, '', '', '', \$mod, \$type);
        if ($isValid == 0) {
          &Log("ERROR: Invalid osisRef segment \"$sref\" in link \"$l\"\n");
          $errors{$linktype}++;
        }
        elsif ($isValid == -1) {
          &Log("WARNING: Could not validate: $l\n");
          $linkcount{'unknown'}++;
        }
        elsif ($type eq 'Dict' && $linktype ne 'gloss') {
          &Log("ERROR: Glossary reference has unexpected type=\"".$l->getAttribute('type')."\" in link \"$l\"\n");
          $errors{$linktype}++;
        }
      }
    }
  }

  &Log("$MOD REPORT: \"".$linkcount{'gloss'}."\" Glossary links checked. (".$errors{'gloss'}." unknown or missing targets)\n");
  &Log("$MOD REPORT: \"".$linkcount{'scrip'}."\" Scripture reference links checked. (".$errors{'scrip'}." unknown or missing targets)\n");
  &Log("$MOD REPORT: \"".$linkcount{'unknown'}."\" Indeterminent reference links whose targets may or may not be missing.\n");
  &Log("$MOD REPORT: \"".@links."\" Grand total reference links.\n");
}

sub checkFigureLinks($) {
  my $in_osis = shift;
  
  &Log("\nCHECKING OSIS FIGURE TARGETS IN $in_osis...\n");
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  my @links = $XPC->findnodes('//osis:figure', $osis);
  my $errors = 0;
  foreach my $l (@links) {
    my $tag = $l; $tag =~ s/^(<[^>]*>).*$/$1/s;
    my $src = $l->getAttribute('src');
    if (!$src) {
      &Log("ERROR: Figure \"$tag\" has no src target!\n");
      $errors++;
      next;
    }
    if (! -e "$INPD/$src") {
      &Log("ERROR checkFigureLinks: Figure \"$tag\" src target does not exist!\n");
      $errors++;
    }
    if ($src != /^\.\/images\//) {
      &Log("ERROR checkFigureLinks: Figure \"$tag\" src target is outside of \"./images\" directory. This image may not appear in e-versions!\n");
    }
  }

  &Log("$MOD REPORT: \"".@links."\" figure targets found and checked. ($errors unknown or missing targets)\n");
}

sub checkIntroductionTags($) {
  my $inosis = shift;
  my $parser = XML::LibXML->new('line_numbers' => 1);
  my $xml = $parser->parse_file($inosis);
  my @warnTags = $XPC->findnodes('//osis:div[@type="majorSection"][not(ancestor::osis:div[@type="book"])]', $xml);
  #my @warnTags = $XPC->findnodes('//osis:title[not(ancestor-or-self::*[@subType="x-introduction"])][not(parent::osis:div[contains(@type, "ection")])]', $xml);
  foreach my $t (@warnTags) {
    my $tag = $t;
    $tag =~ s/^[^<]*?(<[^>]*?>).*$/$1/s;
    &Log("ERROR: Tag on line: ".$t->line_number().", \"$tag\" was used in an introduction that could trigger a bug in osis2mod.cpp, dropping introduction text.\n");
  }
}

# Print log info for a word file
sub logDictLinks() {
  &Log("\n\n");
  &Log("$MOD REPORT: Glossary entries that were explicitly marked in the SFM: (". (scalar keys %ExplicitGlossary) . " instances)\n");
  my $mxl = 0; foreach my $eg (sort keys %ExplicitGlossary) {if (length($eg) > $mxl) {$mxl = length($eg);}}
  foreach my $eg (sort keys %ExplicitGlossary) {
    my @txt;
    foreach my $tg (sort keys %{$ExplicitGlossary{$eg}}) {push(@txt, $tg." (".$ExplicitGlossary{$eg}{$tg}.")");}
    &Log(sprintf("%-".$mxl."s was linked to %s", $eg, join(", ", @txt)) . "\n");
  }
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//dw:entry/dw:name/text()', $DWF);
  my %entriesH; foreach my $e (@entries) {
    my @ms = $XPC->findnodes('./ancestor::dw:entry[1]//dw:match', $e);
    $entriesH{(!@ms || !@ms[0] ? '(no match rules) ':'').$e}++;
  }
  foreach my $e (sort keys %entriesH) {
    my $match = 0;
    foreach my $dh (keys %EntryHits) {
      my $xe = $e; $xe =~ s/^No <match> element(s)\://g;
      if ($xe eq $dh) {$match = 1;}
    }
    if (!$match) {$nolink .= $e."\n"; $numnolink++;}
  }
  
  &Log("\n\n");
  &Log("$MOD REPORT: Glossary entries from $DICTIONARY_WORDS which have no links in the text: ($numnolink instances)\n");
  if ($nolink) {
    &Log("NOTE: You may want to link to these entries using a different word or phrase. To do this, edit the\n");
    &Log("$DICTIONARY_WORDS file.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  &Log("\n");
  
  my @matches = $XPC->findnodes('//dw:match', $DWF);
  my %unused;
  my $total = 0;
  my $mlen = 0;
  foreach my $m (@matches) {
    if ($MatchesUsed{$m->unique_key}) {next;}
    my @name = $XPC->findnodes('./preceding-sibling::dw:name[1]', $m);
    if (@name && @name[0]) {
    if (!$unused{@name[0]->textContent}) {$unused{@name[0]->textContent} = ();}
      push(@{$unused{@name[0]->textContent}}, $m->toString());
      if (length(@name[0]->textContent) > $mlen) {$mlen = length(@name[0]->textContent);}
      $total++;
    }
    else {&Log("ERROR: No <name> for <match> \"$m\" in $DICTIONARY_WORDS\n");}
  }
  &Log("$MOD REPORT: Unused match elements in $DICTIONARY_WORDS: ($total instances)\n");
  foreach my $k (sort keys %unused) {
    foreach my $m (@{$unused{$k}}) {
      &Log(sprintf("%-".$mlen."s %s\n", $k, $m));
    }
  }
  
  my %ematch;
  foreach my $rep (sort keys %Replacements) {
    if ($rep !~ /^(.*?): (.*?), (\w+)$/) {&Log("ERROR: Bad rep match \"$rep\"\n"); next;}
    $ematch{"$3:$1"}{$2} += $Replacements{$rep};
  }

  # get fields and their lengths
  my %kl;
  my %kas;
  my $mkl = 0;
  my $mas = 0;
  foreach my $ent (sort keys %EntryLink) {
    if (length($ent) > $mkl) {$mkl = length($ent);}
    my $t = 0; foreach my $ctx (keys %{$EntryLink{$ent}}) {$t += $EntryLink{$ent}{$ctx};}
    $kl{$ent} = $t;
    
    my $asp = '';
    if (!$ematch{$ent}) {&Log("ERROR: missing ematch key \"$ent\"\n");}
    my $st = $ent; $st =~ s/^\w*\://;
    foreach my $as (sort {$ematch{$ent}{$b} <=> $ematch{$ent}{$a}} keys %{$ematch{$ent}}) {
      my $tp = ($st eq $as ? '':(lc($st) eq lc($as) ? '':'*'));
      $asp .= $as."(".$ematch{$ent}{$as}."$tp) ";
    }
    if (length($asp) > $mas) {$mas = length($asp);}
    $kas{$ent} = $asp;
  }

  # print out the report
  my $gt = 0;
  my $p = '';
  foreach my $ent (sort {$kl{$b} <=> $kl{$a}} keys %kl) {
    my $t = 0;
    my $ctxp = '';
    foreach my $ctx (sort {$EntryLink{$ent}{$b} <=> $EntryLink{$ent}{$a}} keys %{$EntryLink{$ent}}) {
      $t  += $EntryLink{$ent}{$ctx};
      $gt += $EntryLink{$ent}{$ctx};
      $ctxp .= $ctx."(".$EntryLink{$ent}{$ctx}.") ";
    }
    
    $p .= sprintf("%4i links to %-".$mkl."s as %-".$mas."s in %s\n", $t, $ent, $kas{$ent}, $ctxp);
  }
  &Log(" \
NOTE: The following listing should be looked over to be sure text is \
correctly linked to the glossary. Glossary entries are matched in the \
text using the match elements found in the $DICTIONARY_WORDS file. \
\n");
  &Log("$MOD REPORT: Links created: ($gt instances)\n* is textual difference other than capitalization\n$p");
  
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
  
  $n =~ s/([ \(\)])/\\$1/g;
  return $n;
}


sub is_usfm2osis($) {
  my $osis = shift;
  my $usfm2osis = 0;
  if (!open(TEST, "<$osis")) {&Log("ERROR: Could not open $osis\n"); die;}
  while(<TEST>) {if ($_ =~ /<!--[^!]*\busfm2osis.py\b/) {$usfm2osis = 1; last;}}
  close(TEST);
  if ($usfm2osis) {&Log("\n--- OSIS file was created by usfm2osis.py.\n");}
  return $usfm2osis;
}


sub osisXSLT($$$$) {
  my $osis = shift;
  my $xsl = shift;
  my $out = shift;
  my $customPreprocessorDirName = shift;
 
  if (!$osis) {return 'saxonb-xslt';} # for dependency checker
  
  if ($customPreprocessorDirName) {
    my $preprocessor = "$INPD/$customPreprocessorDirName/preprocess.xsl";
    if (-e $preprocessor) {
      &Log("\n--- Running Pre-Processor XSLT...\n");
      
      my $outtmp = $out;
      if ($outtmp !~ s/^(.*?\/[^\/]+)(\.[^\.]*)$/$1_custom$2/) {&Log("ERROR: No substitution: \"$out\"\n"); die;}
      my $cmd = "saxonb-xslt -ext:on -xsl:" . &escfile($preprocessor) . " -s:" . &escfile($osis) . " -o:" . &escfile($outtmp);
      &Log("$cmd\n");
      system($cmd);
      
      $osis = $outtmp;
    }
  }

  my $cmd;
  if ($xsl) {
    &Log("\n--- Running XSLT...\n");
    if (! -e $xsl) {&Log("ERROR: Could not locate required XSL file: \"$xsl\"\n"); die;}
    $cmd = "saxonb-xslt -ext:on -xsl:" . ($osis ? &escfile($xsl) . " -s:" . &escfile($osis) . " -o:" . &escfile($out):'');
  }
  else {
    $cmd = 'cp '.&escfile($osis).' '.&escfile($out);
  }
  
  &Log("$cmd\n");
  system($cmd);
  
  return $cmd;
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
  my $conf = shift;
  my $modpath = shift;
  
  $installSize = 0;             
  find(sub { $installSize += -s if -f $_ }, $modpath);
  open(CONF, ">>:encoding(UTF-8)", $conf) || die "Could not append to conf $conf\n";
  print CONF "\nInstallSize=$installSize\n";
  close(CONF);
}


# make a zipped copy of a module
sub zipModule($$) {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  chdir($moddir);
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  &shell($cmd, 1);
  chdir($SCRD);
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


# Look for the named companion's config.conf directory, or return '' if not found
sub findCompanionDirectory($) {
  my $comp = shift;

  if (!$comp || $comp !~ /^\S+/) {return '';}
  
  my $path = "$INPD/$comp";
  if (! -e "$path/config.conf") {$path = "$INPD/../$comp";}
  if (! -e "$path/config.conf") {$path = "$INPD/../../$comp";}
  if (! -e "$path/config.conf") {return '';}

  return $path;
}


sub emptyvss($) {
  my $dir = shift;
  
  my $canonP;
  my $bookOrderP;
  my $testamentP;
  if (!&getCanon($ConfEntryP->{'Versification'}, \$canonP, \$bookOrderP, \$testamentP)) {
    &Log("ERROR: Could not check for empty verses. Cannot read versification \"".$ConfEntryP->{'Versification'}."\"\n");
    return;
  }
  
  &Log("\n--- TESTING FOR EMPTY VERSES\n");
  
  $cmd = &escfile($SWORD_BIN."emptyvss")." 2>&1";
  $cmd = `$cmd`;
  if ($cmd =~ /usage/i) {
    chdir($dir);
    $cmd = &escfile($SWORD_BIN."emptyvss")." $MOD >> ".&escfile("$TMPDIR/emptyvss.txt");
    system($cmd);
    chdir($SCRD);
    
    &Log("BEGIN EMPTYVSS OUTPUT\n", -1);
    my $r = 'failed';
    if (open(INF, "<$TMPDIR/emptyvss.txt")) {
      my $lb, $lc, $lv;
      $r = '';
      while (<INF>) {
        if ($_ !~ /^\s*(.*?)(\d+)\:(\d+)\s*$/) {next;}
        my $b = $1; my $c = (1*$2); my $v = (1*$3);
        if ($lb) {
          my $skip = 0;
          if ($b eq $lb && $c == $lc && $v == ($lv+1)) {$skip = 1;}
          if ($b eq $lb && $c == ($lc+1) && $v == 1) {$skip = 1;}
          if (!$skip) {$r .= "-$lb$lc:$lv\n$b$c:$v";}
        }
        else {$r = "$b$c:$v";}
        $lb = $b; $lc = $c; $lv = $v;
      }
      if ($lb) {$r .= "-$lb$lc:$lv\n";}
      close(INF);
    }
    $r =~ s/^(.*)-(\1)$/$1/mg;
    
    # report entire missing books separately
    my $missingBKs = '';
    foreach my $bk (keys %{$bookOrderP}) {
      my $whole = @{$canonP->{$bk}}.":".@{$canonP->{$bk}}[@{$canonP->{$bk}}-1];
      if ($r =~ s/^([^\n]+)\s1\:1\-\1\s\Q$whole\E\n//m) {$missingBKs .= $bk." ";}
    }
    &Log("$r\nEntire missing books: ".($missingBKs ? $missingBKs:'none')."\nEND EMPTYVSS OUTPUT\n", -1);
  }
  else {&Log("ERROR: Could not check for empty verses. Sword tool \"emptyvss\" could not be found. It may need to be compiled locally.");}
}


sub writeOsisHeaderWork($) {
  my $osis = shift;
  my $confP = shift;
  
  &Log("\nWriting work and companion work elements in OSIS header:\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # What type of document is this?
  my $type;
  if    ($confP->{'ModDrv'} =~ /LD/)   {$type = 'x-glossary';}
  elsif ($confP->{'ModDrv'} =~ /Text/) {$type = 'x-bible';}
  elsif ($confP->{'ModDrv'} =~ /RawGenBook/ && $mod =~ /CB$/i) {$type = 'x-childrens-bible';}
  elsif ($confP->{'ModDrv'} =~ /Com/) {$type = 'x-commentary';}
  
  # Both osisIDWork and osisRefWork defaults are set to the current work.
  # However, the osisRefWork default isn't normally important since   
  # references generated by osis-converters include the work in each osisRef.
  my @uds = ('osisRefWork', 'osisIDWork');
  foreach my $ud (@uds) {
    my @orw = $XPC->findnodes('//osis:osisText[@'.$ud.']', $xml);
    if (!@orw || @orw > 1) {&Log("ERROR: The osisText element's $ud is not being updated to \"$MOD\"\n");}
    else {
      &Log("Updated $ud=\"$MOD\"\n");
      @orw[0]->setAttribute($ud, $MOD);
      #if ($type eq 'x-bible') {@orw[0]->setAttribute('canonical', 'true');}
    }
  }
  
  # Remove any work elements
  foreach my $we (@{$XPC->findnodes('//*[local-name()="work"]', $xml)}) {
    $we->unbindNode();
  }
  
  # Search for any ISBN number(s) in osis file
  my @isbns;
  my $isbn;
  my @tns = $XPC->findnodes('//text()', $xml);
  foreach my $tn (@tns) {
    if ($tn =~ /\bisbn (number|\#|no\.?)?([\d\-]+)/i) {
      $isbn = $2;
      push(@isbns, $isbn);
    }
  }
  $isbn = join(', ', @isbns);
  
  # Add work element for self
  my %workAttributes = ('osisWork' => $MOD);
  my %workElements;
  &getOSIS_Work(\%workElements, $confP, $isbn);
  # CAUTION: The workElements indexes must correlate to their assignment in getOSIS_Work()
  if ($workElements{'100:type'}{'textContent'} eq 'Bible') {
    $workElements{'190:scope'}{'textContent'} = &getScope($confP->{'Versification'}, $osis);
  }
  &writeWorkElement(\%workAttributes, \%workElements, $xml);
  
  # Add work element for any companion(s)
  if ($ConfEntryP->{'Companion'}) {
    my @comps = split(/\s*,\s*/, $ConfEntryP->{'Companion'});
    foreach my $comp (@comps) {
      my $path = &findCompanionDirectory($comp);
      if (!$path) {
        &Log("ERROR: Could not locate Companion \"$comp\" conf from \"$INPD\"\n");
        next;
      }
      my %compWorkAttributes = ('osisWork' => $comp);
      my %compWorkElements;
      &getOSIS_Work(\%compWorkElements, &readConf("$path/config.conf"), $isbn);
      &writeWorkElement(\%compWorkAttributes, \%compWorkElements, $xml);
    }
  }
  
  if (open(OUTF, ">$osis")) {
    print OUTF $xml->toString();
    close(OUTF);
  }
  else {&Log("ERROR: Could not open \"$osis\" to add osisWorks to header!\n");}
}


sub getOSIS_Work($$$) {
  my $osisWorkP = shift;
  my $confP = shift;
  my $isbn = shift;
  
  my @tm = localtime(time);
  my %type;
  if    ($confP->{'ModDrv'} =~ /LD/)   {$type{'type'} = 'x-glossary'; $type{'textContent'} = 'Glossary';}
  elsif ($confP->{'ModDrv'} =~ /Text/) {$type{'type'} = 'x-bible'; $type{'textContent'} = 'Bible';}
  elsif ($confP->{'ModDrv'} =~ /RawGenBook/ && $mod =~ /CB$/i) {$type{'type'} = 'x-childrens-bible'; $type{'textContent'} = 'Children\'s Bible';}
  elsif ($confP->{'ModDrv'} =~ /Com/) {$type{'type'} = 'x-commentary'; $type{'textContent'} = 'Commentary';}
  my $idf = ($type{'type'} eq 'x-glossary' ? 'Dict':($type{'type'} eq 'x-childrens-bible' ? 'GenBook':($type{'type'} eq 'x-commentary' ? 'Comm':'Bible')));
  my $refSystem = "Bible.".$confP->{'Versification'};
  if ($type{'type'} eq 'x-glossary') {$refSystem = "Dict.".$confP->{'ModuleName'};}
  if ($type{'type'} eq 'x-childrens-bible') {$refSystem = "Book".$confP->{'ModuleName'};}
  my $isbnID = $isbn;
  $isbnID =~ s/[\- ]//g;
  if ($isbnID && length($isbnID) != 13) {&Log("ERROR: ISBN number \"$isbn\" is not 13 digits!\n");}
  
  # map conf info to OSIS Work elements:
  # element order seems to be important for passing OSIS schema validation for some reason (hence the ordinal prefix)
  $osisWorkP->{'000:title'}{'textContent'} = $confP->{'Abbreviation'};
  &mapLocalizedElem(30, 'subject', 'Description', $confP, $osisWorkP);
  $osisWorkP->{'040:date'}{'textContent'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  $osisWorkP->{'040:date'}{'event'} = 'eversion';
  &mapLocalizedElem(50, 'description', 'About', $confP, $osisWorkP);
  $osisWorkP->{'058:description'}{'textContent'} = $confP->{'Version'};
  $osisWorkP->{'058:description'}{'type'} = 'x-Version';
  &mapLocalizedElem(60, 'publisher', 'CopyrightHolder', $confP, $osisWorkP);
  &mapLocalizedElem(70, 'publisher', 'CopyrightContactAddress', $confP, $osisWorkP);
  &mapLocalizedElem(80, 'publisher', 'CopyrightContactEmail', $confP, $osisWorkP);
  &mapLocalizedElem(90, 'publisher', 'ShortPromo', $confP, $osisWorkP);
  $osisWorkP->{'100:type'} = \%type;
  $osisWorkP->{'110:format'}{'textContent'} = 'text/xml';
  $osisWorkP->{'110:format'}{'type'} = 'x-MIME';
  $osisWorkP->{'120:identifier'}{'textContent'} = $isbnID;
  $osisWorkP->{'120:identifier'}{'type'} = 'ISBN';
  $osisWorkP->{'121:identifier'}{'textContent'} = "$idf.".$confP->{'ModuleName'};
  $osisWorkP->{'121:identifier'}{'type'} = 'OSIS';
  $osisWorkP->{'130:source'}{'textContent'} = ($isbn ? "ISBN: $isbn":'');
  $osisWorkP->{'140:language'}{'textContent'} = $confP->{'Lang'};
  &mapLocalizedElem(170, 'rights', 'Copyright', $confP, $osisWorkP);
  &mapLocalizedElem(180, 'rights', 'DistributionNotes', $confP, $osisWorkP);
  $osisWorkP->{'220:refSystem'}{'textContent'} = $refSystem;

# From OSIS spec, valid work elements are:
#    '000:title' => '',
#    '010:contributor' => '',
#    '020:creator' => '',
#    '030+:subject' => '',
#    '040:date' => '',
#    '050+:description' => '',
#    '060-090+:publisher' => '',
#    '100:type' => '',
#    '110:format' => '',
#    '120-121:identifier' => '',
#    '130:source' => '',
#    '140:language' => '',
#    '150:relation' => '',
#    '160:coverage' => '',
#    '170-180+:rights' => '',
#    '190:scope' => '',
#    '200:castList' => '',
#    '210:teiHeader' => '',
#    '220:refSystem' => ''
  
  return;
}

sub mapLocalizedElem($$$$$) {
  my $index = shift;
  my $workElement = shift;
  my $confEntry = shift;
  my $confP = shift;
  my $osisWorkP = shift;
  
  foreach my $k (sort {length($a) <=> length($b)} keys %{$confP}) {
    if ($k !~ /^$confEntry(_([\w\-]+))?$/) {next;}
    my $lang = ($1 ? $2:'');
    $osisWorkP->{sprintf("%03i:%s", $index, $workElement)}{'textContent'} = $confP->{$k};
    $osisWorkP->{sprintf("%03i:%s", $index, $workElement)}{'type'} = "x-$k";
    if ($lang) {
      $osisWorkP->{sprintf("%03i:%s", $index, $workElement)}{'xml:lang'} = $lang;
    }
    $index++;
    if (($index % 10) == 6) {&Log("ERROR mapLocalizedConf: Too many \"$workElement\" language variants.\n");}
  }
}


sub writeWorkElement($$$) {
  my $attributesP = shift;
  my $elementsP = shift;
  my $xml = shift;
  
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  $header->appendTextNode("\n");
  my $work = $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work></work>"), NULL);
  
  # If an element would have no textContent, the element is not written
  foreach my $a (sort keys %{$attributesP}) {$work->setAttribute($a, $attributesP->{$a});}
  foreach my $e (sort keys %{$elementsP}) {
  if (!$elementsP->{$e}{'textContent'}) {next;}
   $work->appendTextNode("\n  ");
    my $er = $e;
    $er =~ s/^\d+\://;
    my $elem = $work->insertAfter($XML_PARSER->parse_balanced_chunk("<$er></$er>"), NULL);
    foreach my $a (sort keys %{$elementsP->{$e}}) {
      if ($a eq 'textContent') {$elem->appendTextNode($elementsP->{$e}{$a});}
      else {$elem->setAttribute($a, $elementsP->{$e}{$a});}
    }
    $work->appendTextNode("\n");
  }
  $header->appendTextNode("\n");
  
  my $w = $work->toString(); 
  $w =~ s/\n+/\n/g;
  &Log("Wrote to header: \n$w\n");
}

sub writeFootnoteIDs() {
  my $osis = shift;
  my $confP = shift;
  
  my $type;
  if    ($confP->{'ModDrv'} =~ /LD/)   {$type = 'x-glossary';}
  elsif ($confP->{'ModDrv'} =~ /Text/) {$type = 'x-bible';}
  else {return;}
  
  &Log("\nWriting footnote osisIDs:\n", 1);
  
  my @files = &splitOSIS($osis);
  foreach my $file (@files) {
    my $xml = $XML_PARSER->parse_file($file);
    
    my $myMod = &getModFromNode($xml);
    
    my @allFootnotes = $XPC->findnodes('//osis:note[@placement="foot"]', $xml);
    foreach my $f (@allFootnotes) {
      my $osisID;
      
      if ($type eq 'x-bible') {
        $osisID = &bibleContext($f);
        if ($osisID !~ s/^(\w+\.\d+\.\d+)\.\d+$/$1/) {
          &Log("ERROR: Bad context for footnote osisID: \"$osisID\"\n");
          next;
        }
      }
      else {$osisID = &glossaryContext($f);}
      
      # Reserve and write an osisID for each footnote. 
      my $n = 1;
      my $id = "$myMod:$osisID$FNREFEXT$n";
      while ($OSISID_FOOTNOTE{$id}) {$n++; $id = "$myMod:$osisID$FNREFEXT$n";}
      $OSISID_FOOTNOTE{$id}++;
      
      if ($f->getAttribute('osisID') && $f->getAttribute('osisID') ne "$osisID$FNREFEXT$n") {
        &Log("WARNING: Overwriting footnote osisID \"".$f->getAttribute('osisID')."\" with \"$osisID$FNREFEXT$n\"\n");
      }

      $f->setAttribute('osisID', "$osisID$FNREFEXT$n");
    }
    
    open(OUTF, ">$file") or die "addFootnoteLinks could not open splitOSIS file: \"$file\".\n";
    print OUTF $xml->toString();
    close(OUTF);
  }
  
  &joinOSIS($osis);
}


# Check for TOC entries, and write as much book TOC information as possible
sub writeTOC($) {
  my $osis = shift;
  
  &Log("\nChecking Table Of Content tags (these tags dictate the TOC of eBooks)...\n");
  
  my %ebookconv;
  if (-e "$INPD/eBook/convert.txt") {%ebookconv = &ebookReadConf("$INPD/eBook/convert.txt");}
  my $toc = ($ebookconv{'TOC'} ? $ebookconv{'TOC'}:2);
  &Log("NOTE: Using \"\\toc$toc\" USFM tags to determine eBook TOC.\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  my @tocTags = $XPC->findnodes('//osis:milestone[@n][starts-with(@type, "x-usfm-toc")]', $xml);
  
  if (@tocTags) {
    &Log("NOTE: Found ".scalar(@tocTags)." table of content milestone tags:\n");
    foreach my $t (@tocTags) {
      &Log($t->toString()."\n");
    }
  }
  
  # Insure there are as many as possible TOC entries for each book
  my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bk (@bks) {
    for (my $t=1; $t<=3; $t++) {
      # Is there a TOC entry if this type? If not, add one if we know what it should be
      my @e = $XPC->findnodes('./osis:milestone[@n][@type="x-usfm-toc'.$t.'"] | ./*[1][self::osis:div]/osis:milestone[@n][@type="x-usfm-toc'.$t.'"]', $bk);
      if (@e && @e[0]) {next;}
      
      if ($t eq $toc && !$WRITETOC_MSG) {
        &Log("
  WARNING: At least one book (".$bk->getAttribute('osisID').") is missing a \\toc$toc USFM tag. These \\toc tags are being used to \
          generate the eBook table of contents. If your eBook TOCs do not render with proper book \
          names and/or hierarchy, then you must add \\toc$toc tags to the USFM using EVAL_REGEX. \
          Or, if you wish to use a different \\toc tag, you must add a TOC=N config setting to: \
          $MOD/eBook/convert.txt (where N is the \\toc tag number you wish to use.)\n\n");
        $WRITETOC_MSG++;
      }
      
      my $name;
      my $type;
      
      # Try and get the book name from BookNames.xml
      if (%BOOKNAMES) {
        my @attrib = ('', 'long', 'short', 'abbr');
        $name = $BOOKNAMES{$bk->getAttribute('osisID')}{@attrib[$t]};
        if ($name) {$type = @attrib[$t];}
      }
      
      # Otherwise try and get the default TOC from the first applicable title
      if (!$name && $t eq $toc) {
        my @title = $XPC->findnodes('./osis:title[@type="runningHead"]', $bk);
        if (!@title || !@title[0]) {
          @title = $XPC->findnodes('./osis:title[@type="main"]', $bk);
        }
        if (!@title || !@title[0]) {
          $name = $bk->getAttribute("osisID");
          $type = "osisID";
          &Log("ERROR writeTOC: Could not locate book name for \"$name\" in OSIS file.\n");
        }
        else {$name = @title[0]->textContent; $type = 'title';}
      }
      
      if ($name) {
        my $tag = "<milestone type=\"x-usfm-toc$t\" n=\"$name\"/>";
        &Log("Note: Inserting $type \\toc$t into \"".$bk->getAttribute('osisID')."\" as $tag\n");
        $bk->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $bk->firstChild);
      }
    }
  }
  
  open(OUTF, ">$osis") or die "writeTOC could not open file: \"$osis\".\n";
  print OUTF $xml->toString();
  close(OUTF);
}

sub ebookReadConf($) {
  my $convtxt = shift;
  
  my %conv;
  if (open(CONV, "<encoding(UTF-8)", $convtxt)) {
    while(<CONV>) {
      if ($_ =~ /^#/) {next;}
      elsif ($_ =~ /^([^=]+?)\s*=\s*(.*?)\s*$/) {$conv{$1} = $2;}
    }
    close(CONV);
  }
  else {&Log("ERROR: Could not read ebookReadConf \"$convtxt\"\n"); die;}
  
  return %conv;
}


# Split an OSIS file into separate book OSIS files, plus 1 non-book OSIS 
# file (one that contains everything else). This is intended for use with 
# joinOSIS to allow parsing smaller files for a big speedup. The only 
# assumption this routine makes is that bookGroup elements contain non-book 
# (intro) material only at the beginning (never between or after book 
# elements). If there are no book divs, everything is put in other.osis.
sub splitOSIS($) {
  my $in_osis = shift;
  
  &Log("\nsplitOSIS: ".&encodePrintPaths($in_osis).":\n", 2);
  
  my @return;
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (-e $tmp) {remove_tree($tmp);}
  make_path($tmp);
  
  my @books; 
  my %bookGroup;
  
  my $xml = $XML_PARSER->parse_file($in_osis);
  my @bookElements = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  my $isBible = (@bookElements && @bookElements[0]);
  
  if ($isBible) {
    # Get books, remove them all, and save all remaining stuff as other.osis
    foreach my $book (@bookElements) {
      my $osisID = $book->getAttribute('osisID');
      push(@books, $osisID);
      $bookGroup{$osisID} = scalar(@{$XPC->findnodes('preceding::osis:div[@type="bookGroup"]', $book)});
      if (!$bookGroup{$osisID}) {$bookGroup{$osisID} = 0;}
      $book->unbindNode();
    }
  }
  
  push(@return, "$tmp/other.osis");
  open(OUTF, ">".@return[$#return]) or die "splitOSIS could not open ".@return[$#return]."\n";
  print OUTF $xml->toString();
  close(OUTF);
  
  if (!$isBible) {return @return;}
  
  # Prepare an osis file which has only a single book in it
  $xml = $XML_PARSER->parse_file($in_osis);
  
  # remove books, except the first book (doing this before removing outside material speeds things up a huge amount!)
  my @bookElements = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $book (@bookElements) {
    if (@books[0] && $book->getAttribute('osisID') ne @books[0]) {$book->unbindNode();}
  }
  
  # remove all material outside of the book
  my @dels1 = $XPC->findnodes('//osis:div[@type="book" and @osisID="'.@books[0].'"]/preceding::node()', $xml);
  my @dels2 = $XPC->findnodes('//osis:div[@type="book" and @osisID="'.@books[0].'"]/following::node()', $xml);
  foreach my $del (@dels1) {$del->unbindNode();}
  foreach my $del (@dels2) {$del->unbindNode();}
  
  # Now save separate osis files for each book, encoding their order and bookGroup in the file-name
  my $bookGroup = @{$XPC->findnodes('//osis:div[@type="bookGroup"]', $xml)}[0];
  my $x = 0;
  do {
    my $bk = @books[$x];
    
    if ($x) {
      foreach my $book (@bookElements) {if ($book->getAttribute('osisID') eq $bk) {$bookGroup->appendChild($book);}}
    }
    
    push(@return, sprintf("%s/%02i %i %s.osis", $tmp, $x, $bookGroup{$bk}, $bk));
    open(OUTF, ">".@return[$#return]) or die "splitOSIS could not open ".@return[$#return]."\n";
    print OUTF $xml->toString();
    close(OUTF);
    
    foreach my $book (@bookElements) {if ($book->getAttribute('osisID') eq $bk) {$book->unbindNode();}}
    
    $x++;
  } while ($x < @books);
  
  return @return;
}
sub joinOSIS($) {
  my $out_osis = shift;
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (!-e $tmp) {die "No splitOSIS tmp directory! \"$tmp\"\n";}
  
  opendir(JOSIS, $tmp) || die "joinOSIS could not open splitOSIS tmp directory \"$tmp\"\n";
  my @files = readdir(JOSIS);
  closedir(JOSIS);
  
  if (!-e "$tmp/other.osis") {die "joinOSIS must have file \"$tmp/other.osis\"!\n";}
  $xml = $XML_PARSER->parse_file("$tmp/other.osis");
  
  foreach my $f (sort @files) {
    if ($f eq "other.osis" || $f =~ /^\./) {next;}
    if ($f !~ /^(\d+) (\d+) (.*?)\.osis$/) {
      &Log("ERROR: joinOSIS bad file name \"$f\"\n");
    }
    my $x = $1;
    my $bookGroup = $2;
    my $bk = $3;
    $bkxml = $XML_PARSER->parse_file("$tmp/$f");
    my @bookNode = $XPC->findnodes('//osis:div[@type="book"]', $bkxml);
    if (@bookNode != 1) {
      &Log("ERROR: joinOSIS file \"$f\" does not have just a single book!\n");
    }
    my @bookGroupNode = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
    if (!@bookGroupNode || !@bookGroupNode[$bookGroup]) {
      &Log("ERROR: bookGroup \"$bookGroup\" for joinOSIS file \"$f\" not found!\n");
    }
    @bookGroupNode[$bookGroup]->appendChild(@bookNode[0]);
  }
  
  open(OUTF, ">$out_osis") or die "joinOSIS could not open \"$out_osis\".\n";
  print OUTF $xml->toString();
  close(OUTF);
}


# Normalize all osisRef and osisID attributes
sub normalizeRefsIds($) {
  my $osis = shift;
  
  &Log("\nNormalizing osisRef and osisID attributes in OSIS file \"$osis\".\n");
  
  my @files = &splitOSIS($osis);
  
  my %stats = ('osisRef'=>0, 'osisID'=>0);
  
  # check that OSIS refSystem is supported
  my $refSystem;
  foreach my $file (@files) {
    if ($file !~ /other\.osis$/) {next;}
    my $xml = $XML_PARSER->parse_file($file);
    $refSystem = &getOSISHeaderValueFromNode('refSystem', $xml);
    if ($refSystem !~ /^(Bible|Dict)/) {
      &Log("ERROR normalizeRefsIds: Not yet supporting refSystem \"$refSystem\"\n");
      return;
    }
    last;
  }
  
  foreach my $file (@files) {
    &Log("$file\n", 2);
    my $xml = $XML_PARSER->parse_file($file);
    &writeNoteOsisRefs($xml, $refSystem);
    &normalizeRefsAndIds($xml, $refSystem, \%stats);
    open(OUTF, ">$file") or die "normalizeRefsIds could not open splitOSIS file: \"$file\".\n";
    print OUTF $xml->toString();
    close(OUTF);
  }
  
  &joinOSIS($osis);
  
  &Log("$MOD REPORT: Removed \"".$stats{'osisRef'}."\" redundant Work prefixes from osisRef attributes.\n");
  &Log("$MOD REPORT: Removed \"".$stats{'osisID'}."\" redundant Work prefixes from osisID attributes.\n");
}

sub writeNoteOsisRefs($$) {
  my $xml = shift;
  my $refSystem = shift;
  
  my @notes = $XPC->findnodes('//osis:note[not(@osisRef)]', $xml);
  
  foreach my $note (@notes) {
    my $osisRef;
    
    if ($refSystem =~ /^Bible/) {
      # get notes's context
      my $con_bc = &bibleContext($note);
      $con_bc =~ s/\.([^\.]+)\.([^\.]+)$//;
      my $con_vf = $1;
      my $con_vl = $2;
      
      # let annotateRef override context if it makes sense
      my $aror;
      my @rs = $XPC->findnodes('descendant::osis:reference[1][@type="annotateRef" and @osisRef]', $note);
      if (@rs && @rs[0]) {
        $aror = @rs[0]->getAttribute('osisRef');
        $aror =~ s/^[\w\d]+\://;
        if ($aror =~ /^([^\.]+\.\d+)(\.(\d+)(-\1\.(\d+))?)?$/) {
          my $ref_bc = $1; my $ref_vf = $3; my $ref_vl = $5;
          if (!$ref_vf) {$ref_vf = 0;}
          if (!$ref_vl) {$ref_vl = $ref_vf;}
          if ($con_bc ne $ref_bc || $ref_vl < $con_vf || $ref_vf > $con_vl) {
            &Log("WARNING writeNoteOsisRefs: Note's annotateRef \"".@rs[0]."\" is outside note's context \"$con_bc.$con_vf.$con_vl\"\n");
            $aror = '';
          }
        }
        else {
          &Log("WARNING writeNoteOsisRefs: Unexpected annotateRef osisRef found \"".@rs[0]."\"\n");
          $aror = '';
        }
      }
      
      $osisRef = ($aror ? $aror:"$con_bc.$con_vf".($con_vl != $con_vf ? "-$con_bc.$con_vl":''));
    }
    
    elsif ($refSystem =~ /^Dict/) {
      $osisRef = &glossaryContext($note);
    }
    
    else {return;}

    $note->setAttribute('osisRef', $osisRef);
  }
}

sub normalizeRefsAndIds($$\%) {
  my $xml = shift;
  my $refSystem = shift;
  my $statsP = shift;
  
  # normalize osisRefs
  my @osisRefs = $XPC->findnodes("//*[substring(\@type,1,7)!='x-gloss']/\@osisRef", $xml);
  my $osisRefWork = @{$XPC->findnodes('//osis:osisText/@osisRefWork', $xml)}[0]->getValue();
  my $normedOR = 0;
  foreach my $osisRef (@osisRefs) {
    if ($osisRef->getValue() !~ /^$osisRefWork\:/) {next;}
    $new = $osisRef->getValue();
    $new =~ s/^$osisRefWork\://;
    $osisRef->setValue($new);
    $statsP->{'osisRef'}++;
  }
  
  # normalize osisIDs
  if ($refSystem =~ /^Bible/) { # non-Bibles have always included the work prefix in every osisID, so let's keep them
    my @osisIDs = $XPC->findnodes('//@osisID', $xml);
    my $osisIDWork = @{$XPC->findnodes('//osis:osisText/@osisIDWork', $xml)}[0]->getValue();
    my $normedID = 0;
    foreach my $osisID (@osisIDs) {
      if ($osisID->getValue() !~ /^$osisIDWork\:/) {next;}
      $new = $osisID->getValue();
      $new =~ s/^$osisIDWork\://;
      $osisID->setValue($new);
      $statsP->{'osisID'}++;
    }
  }
}


sub validateOSIS($) {
  my $osis = shift;
  
  # validate new OSIS file against OSIS schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ".&escfile($XMLLINT."xmllint")." --noout --schema \"$OSISSCHEMA\" ".&escfile($osis)." 2>&1";
  &Log("$cmd\n");
  my $res = `$cmd`;
  &Log("$res\n");
  
  # Generate error if file fails to validate
  if (!$res || $res =~ /^\s*$/) {
    &Log("ERROR: \"$osis\" validation problem. No success or failure message was returned from the xmllint validator!\n");
  }
  elsif ($res !~ /^\Q$osis validates\E$/) {
    &Log("ERROR: \"$osis\" does not validate! See message(s) above.\n");
  }
  
  &Log("END OSIS VALIDATION\n");
}

# Log to console and logfile. $flag can have these values:
# -1 = only log file
#  0 = log file (+ console unless $NOCONSOLELOG is set)
#  1 = log file + console (ignoring $NOCONSOLELOG)
#  2 = only console
sub Log($$) {
  my $p = shift; # log message
  my $flag = shift;
  
  $p =~ s/&#(\d+);/my $r = chr($1);/eg;
  
  if ((!$NOCONSOLELOG && $flag != -1) || $flag >= 1 || $p =~ /error/i) {
    print encode("utf8", $p);
  }
  
  if ($flag == 2) {return;}
  
  $p = &encodePrintPaths($p);
  
  if (!$LOGFILE) {$LogfileBuffer .= $p; return;}

  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
  if ($LogfileBuffer) {print LOGF $LogfileBuffer; $LogfileBuffer = '';}
  print LOGF $p;
  close(LOGF);
}

sub encodePrintPaths($) {
  my $t = shift;
  
  # encode these local file paths
  my @paths = ('INPD', 'OUTDIR', 'SWORD_BIN', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2', 'GO_BIBLE_CREATOR', 'CALIBRE', 'SCRD');
  foreach my $path (@paths) {
    if (!$$path) {next;}
    my $rp = $$path;
    $rp =~ s/[\/\\]+$//;
    $t =~ s/\Q$rp\E/\$$path/g;
  }
  return $t;
}

sub shell($$) {
  my $cmd = shift;
  my $flag = shift; # same as Log flag
  
  &Log("\n$cmd\n", $flag);
  my $result = decode('utf8', `$cmd 2>&1`);
  &Log($result."\n", $flag);
  
  return $result;
}

1;
