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
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
$OT_BOOKS = "1Chr 1Kgs 1Sam 2Chr 2Kgs 2Sam Amos Dan Deut Eccl Esth Exod Ezek Ezra Gen Hab Hag Hos Isa Judg Jer Job Joel Jonah Josh Lam Lev Mal Mic Nah Neh Num Obad Prov Ps Ruth Song Titus Zech Zeph";
$NT_BOOKS = "1Cor 1John 1Pet 1Thess 1Tim 2Cor 2John 2Pet 2Thess 2Tim 3John Acts Col Eph Gal Heb Jas John Jude Luke Matt Mark Phlm Phil Rev Rom Titus";
$DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb or self::osis:hi]";
$DICTIONARY_WORDS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
$DICTIONARY_WORDS = "DictionaryWords.xml";
$UPPERCASE_DICTIONARY_KEYS = 1;
$NOCONSOLELOG = 1;

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

  &checkAndWriteDefaults($INPD);
  
  $CONFFILE = "$INPD/config.conf";
  
  if (!-e $CONFFILE) {
    &Log("ERROR: Could not find or create a \"$CONFFILE\" file.
\"$INPD\" may not be an osis-converters project directory.
A project directory must, at minimum, contain an \"sfm\" subdirectory.
\n".encode("utf8", $LogfileBuffer)."\n");
    die;
  }
  
  &setOUTDIR($INPD);
  
  $AUTOMODE = ($LOGFILE ? 1:0);
  if (!$LOGFILE) {$LOGFILE = "$OUTDIR/OUT_$SCRIPT_NAME.txt";}
  if (!$AUTOMODE && -e $LOGFILE) {unlink($LOGFILE);}
  
  &initOutputFiles($SCRIPT_NAME, $INPD, $OUTDIR, $AUTOMODE);
  
  &setConfGlobals(&updateConfData(&readConf($CONFFILE)));
  
  # if all dependencies are not met, this asks to run in Vagrant
  &checkDependencies($SCRD, $SCRIPT, $INPD, $quiet);
  
  # init non-standard Perl modules now...
  use Sword;
  use HTML::Entities;
  &initLibXML();
  
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
}


sub setOUTDIR($) {
  my $inpd = shift;
  
  if (-e "/home/vagrant") {
    if (-e "/home/vagrant/OUTDIR" && `mountpoint /home/vagrant/OUTDIR` =~ /is a mountpoint/) {
      $OUTDIR = "/home/vagrant/OUTDIR"; # Vagrant share
    }
    else {$OUTDIR = '';}
  }

  if (!$OUTDIR) {$OUTDIR = "$inpd/output";}
  else {
    my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
    $OUTDIR =~ s/[\\\/]\s*$//; # remove any trailing slash
    $OUTDIR .= '/'.$sub;
  }
  if (!-e $OUTDIR) {make_path($OUTDIR);}
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
    &Log("ERROR: Missing namespace declaration in: \"$INPD/$DICTIONARY_WORDS\", continuing with default!\nAdd 'xmlns:dw=\"$DICTIONARY_WORDS_NAMESPACE\"' to root element of \"$INPD/$DICTIONARY_WORDS\" to remove this error.\n\n");
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
  if ($delete && !$automode && !-e "/home/vagrant") {
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
    if (-e "/home/vagrant" && $$p) {
      if (!$quiet) {
        if ($p eq 'MODULETOOLS_BIN') {&Log("NOTE: Using network share to \$$p in paths.pl while running in Vagrant.\n");}
        else {&Log("WARN: Ignoring \$$p in paths.pl while running in Vagrant.\n");}
      }
      $$p = '';
    }
    my $home = `echo \$HOME`; chomp($home);
    if ($p eq 'GO_BIBLE_CREATOR' && !$$p) {$$p = "$home/.osis-converters/GoBibleCreator.245";} # Default location
    if ($p eq 'MODULETOOLS_BIN' && !$$p) {$$p = "$home/.osis-converters/src/Module-tools/bin";} # Default location
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
  @allowed = ('onlyNewTestament', 'onlyOldTestament', 'context', 'notContext', 'multiple', 'osisRef', 'notXPATH', 'version');
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
  %USFM; &scanUSFM("$dir/sfm", \%USFM);
  
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
      foreach my $f (keys %{$USFM{$type}}) {
      
        # peripherals need a target location in the OSIS file added to their ID
        if ($USFM{$type}{$f}{'peripheralID'}) {
          print CFF "\n# Use location == <xpath> to place this peripheral in the proper location in the OSIS file\n";
          if (defined($ID_TYPE_MAP{$USFM{$type}{$f}{'peripheralID'}})) {
            print CFF "EVAL_REGEX(PERIPH):s/^(\\\\id ".$USFM{$type}{$f}{'peripheralID'}.".*)\$/\$1 ";
          }
          else {
            print CFF "EVAL_REGEX(PERIPH):s/^(\\\\id )".$USFM{$type}{$f}{'peripheralID'}."(.*)\$/\$1FRT\$2 ";
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

        my $r = File::Spec->abs2rel($f, $dir); if ($r !~ /^\./) {$r = './'.$r;}
        print CFF "RUN:$r\n";
        
        if ($USFM{$type}{$f}{'peripheralID'}) {print CFF "EVAL_REGEX(PERIPH):\n\n";}
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
      if (!open (CONV, ">>encoding(UTF-8)", "$dir/eBook/convert.txt")) {&Log("ERROR: Could not open \"$dir/eBook/convert.txt\"\n"); die;}
      print CONV "Language=".$confdataP->{'Lang'}."\n";
      print CONV "Publisher=".$confdataP->{'CopyrightHolder'}."\n";
      print CONV "Title=".$confdataP->{'Description'}."\n";
      # sort books to versification order just to make them easier to manually check/update
      my ($canonP, $bookOrderP, $testamentP);
      &getCanon(($confdataP->{'Versification'} ? $confdataP->{'Versification'}:'KJV'), \$canonP, \$bookOrderP, \$testamentP);
      foreach my $f (sort {$bookOrderP->{$USFM{'bible'}{$a}{'osisBook'}} <=> $bookOrderP->{$USFM{'bible'}{$b}{'osisBook'}}} keys %{$USFM{'bible'}}) {
        print CONV $USFM{'bible'}{$f}{'osisBook'}.'='.$USFM{'bible'}{$f}{'h'}."\n";
      }
      close(CONV);
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
      &Log("WARNING: SFM file \"$f\" has no ID and is being SKIPPED!\n");
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


sub getOsisName($$) {
  my $bnm = shift;
  my $quiet = shift;
  
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


# Copy inosis to outosis, while pruning books according to scope. 
# If any bookGroup is left with no books in it, then the entire bookGroup 
# element (including its introduction if there is one) is dropped.
# If a pruned book contains a peripheral which also pertains to a kept 
# book, that peripheral is moved to the first kept book, so as to retain 
# the peripheral.
sub pruneFileOSIS($$$$) {
  my $inosis = shift;
  my $outosis = shift;
  my $scope = shift;
  my $vsys = shift;
  
  my $typeRE = '^('.join('|', keys(%PERIPH_TYPE_MAP_R), keys(%ID_TYPE_MAP_R)).')$';
  $typeRE =~ s/\-/\\-/g;
  
  my $inxml = $XML_PARSER->parse_file($inosis);
  
  my $bookOrderP;
  if (&getCanon($vsys, NULL, \$bookOrderP, NULL)) {
    my @lostIntros;
    my %scopeBookNames = map { $_ => 1 } @{&scopeToBooks($scope, $bookOrderP)};
    # remove books not in scope
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
    foreach my $bk (@books) {
      my $id = $bk->getAttribute('osisID');
      if (!exists($scopeBookNames{$id})) {
        my @divs = $XPC->findnodes('./osis:div[@type]', $bk);
        foreach my $div (@divs) {
          if ($div->getAttribute('type') !~ /$typeRE/i) {next;}
          push(@lostIntros, $div);
        }
        $bk->unbindNode();
      }
    }
    # remove bookGroup if it has no books left (even if it contains other peripheral material)
    my @emptyBookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"][not(osis:div[@type="book"])]', $inxml);
    foreach my $ebg (@emptyBookGroups) {$ebg->unbindNode();}
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
          &Log("NOTE: Moved peripheral: $t1 to $t2\n");
          next INTRO;
        }
      }
    }
  }
  else {&Log("ERROR: Failed to read vsys \"$vsys\", not pruning books in OSIS file!\n");}
  
  open(OUTF, ">$outosis");
  print OUTF $inxml->toString();
  close(OUTF);
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
    my $glossContext; my $glossScopeP;
    if (@isGlossary) {
      $glossContext = @{$XPC->findnodes("./preceding::".$KEYWORD."[1]", @tn[0])}[0]->textContent();
      $glossScopeP = &scopeToBooks(&getEntryScope(@tn[0]), $bookOrderP);
      &addDictionaryLinks(\@tn, $glossContext, $glossScopeP);
    }
    else {
      &addDictionaryLinks(\@tn);
    }
    if ($before eq $g->parentNode->toString()) {
      &Log("ERROR: Failed to convert explicit glossary index: $g\n\tText Node=".@tn[0]->data."\n".(@isGlossary ? "\tGlossary Context=$glossContext\n\tGlossary Scope=".join("_", @{$glossScopeP})."\n":'')."\n");
      $ExplicitGlossary{$gl}{"Failed"}++;
      next;
    }
    $ExplicitGlossary{$gl}{&decodeOsisRef(@{$XPC->findnodes("preceding::reference[1]", $g)}[0]->getAttribute("osisRef"))}++;
    $g->parentNode->removeChild($g);
  }
}


# Add dictionary links as described in $DWF to the nodes pointed to 
# by $eP array pointer. Expected node types are element or text.
sub addDictionaryLinks(\@$\@) {
  my $eP = shift; # array of nodes (NOTE: node children are not touched)
  my $entry = shift; # should be NULL if not adding SeeAlso links
  my $glossaryScopeP = shift; # array of books, should be NULL if not adding SeeAlso links

  if ($entry) {
    my $entryOsisRef = &entry2osisRef($MOD, $entry);
    if (!$NoOutboundLinks{'haveBeenRead'}) {
      foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', $DWF)) {
        foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
      }
      $NoOutboundLinks{'haveBeenRead'}++;
    }
    if ($NoOutboundLinks{$entryOsisRef}) {return;}
  }
  
  foreach my $node (@$eP) {
    my @textchildren;
    my $container = ($node->nodeType == 3 ? $node->parentNode():$node);
    if ($node->nodeType == 3) {push(@textchildren, $node);}
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
          if ($part =~ /<reference.*?<\/reference[^>]*>/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $textchild, $entry, $glossaryScopeP)) {$done = 0;}
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
# reference tags are inserted, and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$\@) {
  my $textP = shift;
  my $textNode = shift;
  my $entry = shift; # for SeeAlso links only
  my $glossaryScopeP = shift; # for SeeAlso links only

  my $matchedPattern = '';
  
  if (!@MATCHES) {@MATCHES = $XPC->findnodes("//dw:match", $DWF);}
  
  my $context;
  my $multiples_context;
  if ($entry) {$context = $entry; $multiples_context = $entry;}
  else {
    $context = &bibleContext($textNode);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &myContext('ot', $context);
  my $contextIsNT = &myContext('nt', $context);
  my @contextNote = $XPC->findnodes("ancestor::osis:note", $textNode);
  
  my $a;
  foreach my $m (@MATCHES) {
#@DICT_DEBUG = ($context, @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent()); @DICT_DEBUG_THIS = ("Gen.49.10.10", decode("utf8", "АҲД САНДИҒИ"));
    &dbg(sprintf("Context: %16s\nMatch: %s\nEntry: %s\nNode: %s\nNodeType: %s = ", $context, $m, $entry, $textNode, $textNode->parentNode()->nodeType));
    if ($entry && &matchInEntry($m, $entry)) {&dbg("00\n"); next;} # never add glossary links to self
    if (!$contextIsOT && &attributeIsSet('onlyOldTestament', $m)) {&dbg("10\n"); next;}
    if (!$contextIsNT && &attributeIsSet('onlyNewTestament', $m)) {&dbg("20\n"); next;}
    if (!&attributeIsSet('multiple', $m)) {
      if (@contextNote > 0) {if ($MULTIPLES{$m->unique_key . ',' .@contextNote[$#contextNote]->unique_key}) {&dbg("35\n"); next;}}
      elsif ($MULTIPLES{$m->unique_key}) {&dbg("40\n"); next;}
    }
    my @tst = $XPC->findnodes(&getAttribute('notXPATH', $m), $textNode);
    if (@tst && @tst[0]) {&dbg("45\n"); next;}
    if ($a = &getAttribute('context', $m)) {
      my $gs = scalar(@{$glossaryScopeP}); my $ic = &myContext($a, $context); my $igc = ($gs && &myGlossaryContext($a, $glossaryScopeP));
      if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {&dbg("50\n"); next;}
    }
    if ($a = &getAttribute('notContext', $m)) {if (&myContext($a, $context)) {&dbg("60\n"); next;}}
    if ($a = &getAttribute('withString', $m)) {if (!$ReportedWithString{$m}) {&Log("ERROR: \"withString\" attribute is no longer supported. Remove it from: $m\n"); $ReportedWithString{$m} = 1;}}
    
    my $p = $m->textContent;
    
    if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {&Log("ERROR: Bad match regex: \"$p\"\n"); &dbg("80\n"); next;}
    my $pm = $1; my $pf = $2;
    
    # handle PUNC_AS_LETTER word boundary matching issue
    if ($PUNC_AS_LETTER) {$pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;}
    
    # handle xml decodes
    $pm = decode_entities($pm);
    
    # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
    my $t = $$textP;
    my $i = $pf =~ s/i//;
    $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;
    if ($i) {$t = &uc2($t);}
    if ($pf =~ /(\w+)/) {&Log("ERROR: Regex flag \"$1\" not supported in \"".$m->textContent."\"");}
   
    # finally do the actual MATCHING...
    if ($t !~ /$pm/) {$t =~ s/\n/ /g; &dbg("\"$t\" is not matched by: /$pm/\n"); next;}
      
    my $is = $-[$#+];
    my $ie = $+[$#+];
    
    # if a (?'link'...) named group 'link' exists, use it instead
    if (defined($+{'link'})) {
      my $i; for ($i=0; $i <= $#+; $i++) {if ($$i eq $+{'link'}) {last;}}
      $is = $-[$i];
      $ie = $+[$i];
    }
    
    &dbg("LINKED: $pm\n$t\n$is, $ie, ".$+{'link'}.".\n");
    $matchedPattern = $m->textContent;
    
    my $osisRef = @{$XPC->findnodes('ancestor::dw:entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
    my $name = @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent;
    my $attribs = "osisRef=\"$osisRef\" type=\"".($MODDRV =~ /LD/ ? 'x-glosslink':'x-glossary')."\"";
    my $match = substr($$textP, $is, ($ie-$is));
    
    substr($$textP, $ie, 0, "</reference>");
    substr($$textP, $is, 0, "<reference $attribs>");
    
    # record stats...
    $EntryHits{$name}++;
    
    my $logContext = $context;
    $logContext =~ s/\..*$//; # keep book/entry only
    $EntryLink{&decodeOsisRef($osisRef)}{$logContext}++;
    
    my $dict;
    foreach my $sref (split(/\s+/, $osisRef)) {
      if (!$sref) {next;}
      my $e = &osisRef2Entry($sref, \$dict);
      $Replacements{$e.": ".$match.", ".$dict}++;
    }

    if (@contextNote > 0) {$MULTIPLES{$m->unique_key . ',' .@contextNote[$#contextNote]->unique_key}++;}
    else {$MULTIPLES{$m->unique_key}++;}
    last;
  }
 
  return $matchedPattern;
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


sub getAttribute($$) {
  my $a = shift;
  my $m = shift;
  
  my @r = $XPC->findnodes("ancestor-or-self::*[\@$a][1]", $m);
  
  return (@r ? @r[0]->getAttribute($a):0);
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


# return context if context is a part of $test, else 0
# $context may be a dictionary entry or a special Bible range - see bibleContext()
# $test can be:
#   keyword - return context IF it is part of keyword's scope
#   encoded osisRef - return context IF it is within scope of osisRef (which may include multiple ranges)
# else return 0
sub myContext($$) {
  my $test = shift;
  my $context = shift;

  my $test2 = $test;
  if ($test eq 'ot') {$test2 = $OT_BOOKS;}
  elsif ($test eq 'nt') {$test2 = $NT_BOOKS;}
  foreach my $t (split(/\s+/, $test2)) {
    if ($t =~ /^\s*$/) {next;}
    if (!$REF_SEG_CACHE{$t}) {$REF_SEG_CACHE{$t} = &osisRefSegment2array($t);}
    foreach my $e (@{$REF_SEG_CACHE{$t}}) {
      foreach my $refs (&context2array($context)) {
        if ($refs =~ /\Q$e\E/i) {
          return $context;
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

# return special Bible context reference for $elem:
# Gen.0.0.0 = intro
# Gen.1.0.0 = intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext($$) {
  my $elem = shift;
  my $noerror = shift;
  
  my $context = '';
  
  # must have book to have context
  my @bk = $XPC->findnodes('ancestor-or-self::osis:div[@type=\'book\'][@osisID][1]', $elem);
  my $bk = (@bk ? @bk[0]->getAttribute('osisID'):'');

  my @c;
  if (@bk && $bk) {
    # find most specific osisID associated with elem (assumes milestone end tags have no osisID attribute)
    @c = $XPC->findnodes('ancestor-or-self::osis:verse[@osisID][1]', $elem);
    
    if (!@c) {
      @c = $XPC->findnodes('preceding::osis:verse[@osisID][1]', $elem);
      if (@c && @c[0]->getAttribute('osisID') !~ /^\Q$bk.\E/) {@c = ();}
    }

    if (!@c) {@c = $XPC->findnodes('ancestor-or-self::osis:chapter[@osisID][1]', $elem);}
    
    if (!@c) {
      @c = $XPC->findnodes('preceding::osis:chapter[@osisID][1]', $elem);
      if (@c && @c[0]->getAttribute('osisID') !~ /^\Q$bk.\E/) {@c = ();}
    }
    
    if (!@c) {@c = @bk;}
  }
  
  # get context from most specific osisID
  if (@c) {
    my $id = @c[0]->getAttribute('osisID');
    $context = ($id ? $id:"unk.0.0.0");
    if ($id =~ /^\w+$/) {$context .= ".0.0.0";}
    elsif ($id =~ /^\w+\.\d+$/) {$context .= ".0.0";}
    elsif ($id =~ /^\w+\.\d+\.(\d+)$/) {$context .= ".$1";}
    elsif ($id =~ /^(\w+\.\d+\.\d+) .*\w+\.\d+\.(\d+)$/) {$context = "$1.$2";}
  }
  else {
    if (!$noerror) {&Log("ERROR: Could not determine context of \"$elem\"\n");}
    return 0;
  }
  
  return $context;
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


# return a valid array of non-range references from a single osisRef segment 
# which may contain a range. An osisRef segment may contain a single hyphen, 
# but no spaces. Returned refs are DECODED osisRefs. An ERROR is thrown 
# if an invalid book or reference is found.
sub osisRefSegment2array($) {
  my $osisRef = shift;
  
  my @refs = ();

  if ($osisRef !~ /^(.*?)\-(.*)$/) {
    if (!&validOsisRefSegment($osisRef, $VERSESYS)) {return \@refs;}
    my $mod;
    push(@refs, &osisRef2Entry($osisRef, \$mod, 1));
    return (\@refs); # returns decoded osisRef
  }
  my $r1 = $1; my $r2 = $2;
  
  my ($b1, $c1, $v1);
  if (!&validOsisRefSegment($r1, $VERSESYS, \$b1, \$c1, \$v1)) {return \@refs;}
  my ($b2, $c2, $v2);
  if (!&validOsisRefSegment($r2, $VERSESYS, \$b2, \$c2, \$v2)) {return \@refs;}

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


# Check an osisRef segment (cannot contain "-") against the verse system or dictionary words
sub validOsisRefSegment($$\$\$\$) {
  my $osisRef = shift;
  my $vsys = shift;
  my $bP = shift;
  my $cP = shift;
  my $vP = shift;
  
  my $b; if (!$bP) {$bP = \$b;}
  my $c; if (!$cP) {$cP = \$c;}
  my $v; if (!$vP) {$vP = \$v;}
  
  if ($osisRef !~ /^([\w\d]+)(\.(\d+)(\.(\d+))?)?$/) {
    my @tst = $XPC->findnodes("//dw:entry[\@osisRef='$osisRef']", $DWF);
    if (@tst && @tst[0]) {return 1;}
    &Log("ERROR: unknown osisRef: \"$osisRef\"\n");
    return 0;
  }
  $$bP = $1;
  $$cP = ($2 ? $3:0);
  $$vP = ($4 ? $5:0);
  
  if ($OT_BOOKS !~ /\b$$bP\b/ && $NT_BOOKS !~ /\b$$bP\b/) {
    &Log("ERROR: Unrecognized OSIS book: \"$$bP\"\n");
    return 0;
  }
  
  my ($canonP, $bookOrderP, $bookArrayP);
  &getCanon($VERSESYS, \$canonP, \$bookOrderP, NULL, \$bookArrayP);
  
  if ($$cP != 0 && ($$cP < 0 || $$cP > @{$canonP->{$$bP}})) {
    &Log("ERROR: Chapter is not in verse system $vsys: \"$$bP.$$cP\"\n");
    return 0;
  }
  
  if ($$vP != 0 && ($$vP < 0 || $$vP > @{$canonP->{$$bP}}[$$cP-1])) {
    &Log("ERROR: Verse is not in verse system $vsys: \"$$bP.$$cP.$$vP\"\n");
    return 0;
  }
  
  return 1;
}


# Check all reference links, and report any errors
sub checkDictReferences($) {
  my $in_file = shift;
  
  my %replaceList;
  
  &Log("\nCHECKING DICTIONARY REFERENCE OSISREF TARGETS IN $in_file...\n");
  if (!open(INF, "<:encoding(UTF-8)", $in_file)) {&Log("ERROR: Could not check $in_file.\n"); die;}
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
        if ($DWF) {
          my @entry = $XPC->findnodes('//dw:entry[@osisRef=\''.$sref.'\']', $DWF);
          if (!@entry) {
            $errors++;
            &Log("ERROR: line $line: osisRef \"$sref\" not found in dictionary words file\n");
          }
        }
      }
    }
  }
  close(INF);
  if (!$DWF && $total) {&Log("REPORT: WARNING, $total dictionary links COULT NOT BE CHECKED without a $DICTIONARY_WORDS file.n");}
  else {&Log("REPORT: $total dictionary links found and checked. ($errors unknown or missing targets)\n");}
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
  &Log("REPORT: Glossary entries that were explicitly marked in the SFM: (". (scalar keys %ExplicitGlossary) . " instances)\n");
  my $mxl = 0; foreach my $eg (sort keys %ExplicitGlossary) {if (length($eg) > $mxl) {$mxl = length($eg);}}
  foreach my $eg (sort keys %ExplicitGlossary) {
    my @txt;
    foreach my $tg (sort keys %{$ExplicitGlossary{$eg}}) {push(@txt, $tg." (".$ExplicitGlossary{$eg}{$tg}.")");}
    &Log(sprintf("%-".$mxl."s was linked to %s", $eg, join(", ", @txt)) . "\n");
  }
  
  my $total = 0;
  foreach my $osisRef (sort keys %EntryHits) {$total += $EntryHits{$osisRef};}
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//dw:entry/dw:name/text()', $DWF);
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
  my %ematch;
  foreach my $rep (sort keys %Replacements) {
    &Log("$rep, ".$Replacements{$rep}."\n");
    if ($rep !~ /^(.*?): (.*?), (\w+)$/) {&Log("ERROR: Bad rep match \"$rep\"\n"); next;}
    $ematch{"$3:$1"}{$2} += $Replacements{$rep};
  }
  &Log("\n\n");

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
    foreach my $as (sort {$ematch{$ent}{$b} <=> $ematch{$ent}{$a}} keys %{$ematch{$ent}}) {
      $asp .= $as."(".$ematch{$ent}{$as}.") ";
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
    
    $p .= sprintf("%3i links to %-".$mkl."s as %-".$mas."s in %s\n", $t, $ent, $kas{$ent}, $ctxp);
  }
  &Log("REPORT: Links created: ($gt instances)\n$p");
  
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
 
  if ($osis && $customPreprocessorDirName) {
    my $preprocessor = "$INPD/$customPreprocessorDirName/preprocess.xsl";
    if (-e $preprocessor) {
      &Log("\n--- Running Pre-Processor XSLT...\n");
      
      my $outtmp = $out;
      if ($outtmp !~ s/^(.*?\/)([^\/]+)$/$1preprocessed_$2/) {&Log("ERROR: No substitution: \"$out\"\n"); die;}
      my $cmd = "saxonb-xslt -xsl:" . &escfile($preprocessor) . " -s:" . &escfile($osis) . " -o:" . &escfile($outtmp);
      &Log("$cmd\n");
      system($cmd);
      
      $osis = $outtmp;
    }
  }

  if ($osis) {
    &Log("\n--- Running XSLT...\n");
    if (! -e $xsl) {&Log("ERROR: Could not locate required XSL file: \"$xsl\"\n"); die;}
  }

  my $cmd = "saxonb-xslt -xsl:" . ($osis ? &escfile($xsl) . " -s:" . &escfile($osis) . " -o:" . &escfile($out):'');
  
  if ($cmd && $osis) {
    &Log("$cmd\n");
    system($cmd);
  }
  
  return $cmd;
}


# Convert an "id" to an array of osisIDs, where the id is from an  
# eID or sID attribute, which can apparently be anything unique. So 
# only a common subset is handled here.
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
  &Log($cmd, 1);
  `$cmd`;
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


# Look for the named companion's config.conf directory, or return null if not found
sub findCompanionDirectory($) {
  my $comp = shift;
  if (!$comp || $comp !~ /^\S+/) {return NULL;}
  
  my $path = "$INPD/$comp";
  if (! -e "$path/config.conf") {$path = "$INPD/../$comp";}
  if (! -e "$path/config.conf") {$path = "$INPD/../../$comp";}
  if (! -e "$path/config.conf") {return NULL;}
  
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


sub updateOsisHeader($) {
  my $osis = shift;
  
  &Log("\nUpdating work and companion work elements in OSIS header:\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  my @uds = ('osisRefWork', 'osisIDWork');
  foreach my $ud (@uds) {
    my @orw = $XPC->findnodes('//osis:osisText[@'.$ud.']', $xml);
    if (!@orw || @orw > 1) {&Log("ERROR: The osisText element's $ud is not being updated to \"$MOD\"\n");}
    else {
      &Log("Updated $ud=\"$MOD\"\n");
      @orw[0]->setAttribute($ud, $MOD);
    }
  }
  
  # Remove any unknown work elements
  @keep = ($MOD, split(/\s*,\s*/, $ConfEntryP->{'Companion'}));
  my %keep = map { $_ => 1 } @keep;
  foreach my $we (@{$XPC->findnodes('//*[local-name()="work"]', $xml)}) {
    if ($keep{$we->getAttribute('osisWork')}) {next;}
    &Log("WARNING: Removing un-applicable work element:".$we."\n");
    $we->unbindNode();
  }
  
  # Add work element for self
  &updateWorkElement($MOD, $ConfEntryP, $xml);
  
  # Add work element for any companion(s)
  if ($ConfEntryP->{'Companion'}) {
    my @comps = split(/\s*,\s*/, $ConfEntryP->{'Companion'});
    foreach my $comp (@comps) {
      my $path = &findCompanionDirectory($comp);
      if (!$path) {
        &Log("ERROR: Could not locate Companion \"$comp\" conf from \"$INPD\"\n");
        next;
      }
      &updateWorkElement($comp, &readConf("$path/config.conf"), $xml);
    }
  }
  
  if (open(OUTF, ">$osis")) {
    print OUTF $xml->toString();
    close(OUTF);
  }
  else {&Log("ERROR: Could not open \"$osis\" to add osisWorks to header!\n");}
}


sub updateWorkElement($\%$) {
  my $mod = shift;
  my $confP = shift;
  my $xml = shift;
  
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  
  # get or create the work element
  my $work;
  my @ws = $XPC->findnodes('./*[local-name()="work"][@osisWork="'.$mod.'"]', $header);
  if (@ws) {$work = @ws[0];}
  else {
    $work = $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work osisWork=\"$mod\"></work>"), NULL);
  }

  # add type field
  if (!@{$XPC->findnodes('./*[local-name()="type"]', $work)}) {
    my $type;
    if    ($confP->{'ModDrv'} =~ /LD/)   {$type = "<type type=\"x-glossary\">Glossary</type>";}
    elsif ($confP->{'ModDrv'} =~ /Text/) {$type = "<type type=\"x-bible\">Bible</type>";}
    elsif ($confP->{'ModDrv'} =~ /RawGenBook/ && $mod =~ /CB$/i) {$type = "<type type=\"x-childrens-bible\">Children's Bible</type>";}
    elsif ($confP->{'ModDrv'} =~ /Com/) {$type = "<type type=\"x-commentary\">Commentary</type>";}
    if ($type) {
      $work->insertAfter($XML_PARSER->parse_balanced_chunk($type), NULL);
    }
  }

  my $w = $work->toString(); 
  $w =~ s/\n//g;
  &Log("Updated: $w\n");
}


$IS_SEG_INLINE  = sub {my $n = shift; if ($n->nodeName ne 'seg') {return undef;} return ($n->getAttribute('type') ne 'keyword');};
$IS_SEG_COMPACT = sub {my $n = shift; if ($n->nodeName ne 'seg') {return undef;} return ($n->getAttribute('type') eq 'keyword');};
sub prettyPrintOSIS($) {
  my $osisDoc = shift;
  
  use XML::LibXML::PrettyPrint;
  
  my @preserveWhiteSpace = qw(a abbr catchWord date divineName foreign hi index inscription lb mentioned milestone name note q reference salute signed speaker titlePage transChange w);
  
  my @inline = ('header', $IS_SEG_INLINE);
  push(@inline, @preserveWhiteSpace);
  
  my $pp = XML::LibXML::PrettyPrint->new(
    element => {
      #block    => [elements-are-block-by-default],
      inline   => \@inline, # inline elements also preserve whitespace
      compact  => [qw/title caption l item/, $IS_SEG_COMPACT], # compact does NOT preserve whitespace
      #preserve_whitespace => \@preserveWhiteSpace
    }
  );
  
  $pp->pretty_print($osisDoc, -2);
  
  return $osisDoc;
}


sub validateOSIS($) {
  my $osis = shift;
  
  # validate new OSIS file against schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ".&escfile($XMLLINT."xmllint")." --noout --schema \"$OSISSCHEMA\" ".&escfile($osis)." 2>> ".&escfile($LOGFILE);
  &Log("$cmd\n");
  system($cmd);
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
  
  if ((!$NOCONSOLELOG && $flag != -1) || $flag >= 1 || $p =~ /error/i) {
    print encode("utf8", $p);
  }
  
  if ($flag == 2) {return;}
  
  # encode these local file paths
  my @paths = ('INPD', 'OUTDIR', 'SWORD_BIN', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2', 'GO_BIBLE_CREATOR', 'CALIBRE', 'SCRD');
  foreach my $path (@paths) {
    if (!$$path) {next;}
    my $rp = $$path;
    $rp =~ s/[\/\\]+$//;
    $p =~ s/\Q$rp\E/\$$path/g;
  }
  
  if (!$LOGFILE) {$LogfileBuffer .= $p; return;}

  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
  if ($LogfileBuffer) {print LOGF $LogfileBuffer; $LogfileBuffer = '';}
  print LOGF $p;
  close(LOGF);
}

1;
