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
$GITHEAD = `git rev-parse HEAD 2>tmp.txt`; unlink("tmp.txt");

sub init($) {
  $SCRIPT = shift;
  $SCRIPT =~ s/^.*[\\\/]([^\\\/]+)\.pl$/$1/;
  
  if (!$INPD) {$INPD = "."};
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  $INPD =~ s/[\\\/](sfm|GoBible|eBook)$//; # allow using a subdir as project dir
  if (!-e $INPD) {
    print "Project directory \"$INPD\" does not exist. Exiting.\n";
    exit;
  }
  chdir($SCRD); # had to wait until absolute $INPD was set by rel2abs
  
  if (!-e "$SCRD/paths.pl") {
    if (!open(PATHS, ">$SCRD/paths.pl")) {&Log("Could not open \"$SCRD/paths.pl\". Exiting.\n"); die;}
    print PATHS "1;\n";
    close(PATHS);
  }
  require "$SCRD/paths.pl";

  &checkAndWriteDefaults($INPD, $SCRIPT);
  
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
  if (!$LOGFILE) {$LOGFILE = "$OUTDIR/OUT_$SCRIPT.txt";}
  if (!$AUTOMODE && -e $LOGFILE) {unlink($LOGFILE);}
  
  &initOutputFiles($INPD, $OUTDIR, $AUTOMODE);
  
  &setConfGlobals(&updateConfData(&readConf($CONFFILE)));
  
  # if all dependencies are not met, this asks to run in Vagrant
  &checkDependencies($SCRD, $SCRIPT, $INPD);
  
  # init non-standard Perl modules now...
  use Sword;
  use HTML::Entities;
  &initLibXML();
  
  $TMPDIR = "$OUTDIR/tmp/$SCRIPT";
  if (-e $TMPDIR) {remove_tree($TMPDIR);}
  make_path($TMPDIR);
  
  if (-e "$INPD/$DICTIONARY_WORDS") {$DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");}
  
  &Log("osis-converters rev: $GITHEAD\n\n");
  &Log("\n-----------------------------------------------------\nSTARTING $SCRIPT.pl\n\n");
}


sub setOUTDIR($) {
  my $inpd = shift;
  
  if (-e "/home/vagrant") {
    if (-e "/home/vagrant/OUTDIR") {$OUTDIR = "/home/vagrant/OUTDIR";} # Vagrant share
    else {$OUTDIR = '';}
  }
  
  if ($OUTDIR) {
    my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
    $OUTDIR =~ s/[\\\/]\s*$//; # remove any trailing slash
    $OUTDIR .= '/'.$sub;
    if (!-e $OUTDIR) {make_path($OUTDIR);}
  }
  else {
    $OUTDIR = $inpd;
    &Log("\nWARNING: Output directory \$OUTDIR is not specified- will use inputs directory.\n", 1);
    &Log("NOTE: Specify an output directory by adding:\n\$OUTDIR = '/path/to/outdir';\nto paths.pl.\n\n", 1);
  }
}


sub initOutputFiles($$$) {
  my $inpd = shift;
  my $outdir = shift;
  my $automode = shift;
  
  my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
  
  my @outs;
  if ($SCRIPT =~ /^(osis2osis|sfm2osis|html2osis)$/i) {
    $OUTOSIS = "$outdir/$sub.xml"; push(@outs, $OUTOSIS);
  }
  if ($SCRIPT =~ /^(osis2sword|imp2sword)$/i) {
    $OUTZIP = "$outdir/$sub.zip"; push(@outs, $OUTZIP);
    $SWOUT = "$outdir/sword"; push(@outs, $SWOUT);
  }
  if ($SCRIPT =~ /^osis2GoBible$/i) {
    $GBOUT = "$outdir/GoBible/$sub"; push(@outs, $GBOUT);
  }
  if ($SCRIPT =~ /^osis2ebooks$/i) {
    $EBOUT = "$outdir/eBooks"; push(@outs, $EBOUT);
  }
  if ($SCRIPT =~ /^sfm2imp$/i) {
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
sub checkDependencies($$$) {
  my $scrd = shift;
  my $script = shift;
  my $inpd = shift;

  my %path;
  $path{'SWORD_BIN'}{'msg'} = "Install CrossWire's SWORD tools, or specify the path to them by adding:\n\$SWORD_BIN = '/path/to/directory';\nto osis-converters/paths.pl\n";
  $path{'XMLLINT'}{'msg'} = "Install xmllint, or specify the path to xmllint by adding:\n\$XMLLINT = '/path/to/directory'\nto osis-converters/paths.pl\n";
  $path{'GO_BIBLE_CREATOR'}{'msg'} = "Install GoBible Creator as ~/.osis-converters/GoBibleCreator.245, or specify the path to it by adding:\n\$GO_BIBLE_CREATOR = '/path/to/directory';\nto osis-converters/paths.pl\n";
  $path{'REPOTEMPLATE_BIN'}{'msg'} = "Install CrossWire\'s repotemplate git repo as ~/.osis-converters/src/repotemplate, or specify the path to it by adding:\n\$REPOTEMPLATE_BIN = '/path/to/bin';\nto osis-converters/paths.pl\n";
  $path{'XSLT2'}{'msg'} = "Install the required program.\n";
  $path{'CALIBRE'}{'msg'} = "Install Calibre by following the documentation: osis-converters/eBooks/osis2ebook.docx.\n";
  
  foreach my $p (keys %path) {
    if (-e "/home/vagrant" && $$p) {
      if ($p eq 'REPOTEMPLATE_BIN') {&Log("NOTE: Using network share to \$$p in paths.pl while running in Vagrant.\n");}
      else {&Log("WARN: Ignoring \$$p in paths.pl while running in Vagrant.\n");}
      $$p = '';
    }
    my $home = `echo \$HOME`; chomp($home);
    if ($p eq 'GO_BIBLE_CREATOR' && !$$p) {$$p = "$home/.osis-converters/GoBibleCreator.245";} # Default location
    if ($p eq 'REPOTEMPLATE_BIN' && !$$p) {$$p = "$home/.osis-converters/src/repotemplate/bin";} # Default location
    if ($$p) {
      if ($p =~ /^\./) {$$p = File::Spec->rel2abs($$p);}
      $$p =~ s/[\\\/]+\s*$//;
      $$p .= "/";
    }
  }
  
  $path{'SWORD_BIN'}{'test'} = [&escfile($SWORD_BIN."osis2mod"), "You are running osis2mod"];
  $path{'XMLLINT'}{'test'} = [&escfile($XMLLINT."xmllint"), "Usage"];
  $path{'REPOTEMPLATE_BIN'}{'test'} = [&escfile($REPOTEMPLATE_BIN."usfm2osis.py"), "Usage"];
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
      &Log("\nERROR: Dependency not found: \"".$path{$p}{'test'}[0]."\"\n", 1);
      $failMes .= "NOTE: ".$path{$p}{'msg'}."\n";
    }
  }
  if ($failMes) {
    if (!-e "/home/vagrant") {
      print "\n";
      if ("$^O" =~ /linux/i) {
        print "You are running in Linux and can meet all osis-converter dependencies either \n";
        print "by using Vagrant and Virtualbox or else by running or following the\n";
        print "VagrantProvision.sh script as root.\n";
      }
      print "Do you want to use Vagrant and Virtualbox\nto automatically meet all dependencies? (Y/N):"; 
      $in = <>; 
      if ($in =~ /^\s*y\s*$/i) {
        if (!&vagrantInstalled()) {exit;}
        if (!open(PATHS, ">>$scrd/paths.pl")) {die;}
        print PATHS "\$VAGRANT = 1;\n1;\n";
        close(PATHS);
        &startVagrant($scrd, $script, $inpd);
        exit;
      }
    }
    &Log("\n$failMes", 1);
    exit;
  }
}


sub initLibXML() {
  use XML::LibXML;
  $XPC = XML::LibXML::XPathContext->new;
  $XPC->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
  $XPC->registerNs('tei', 'http://www.crosswire.org/2013/TEIOSIS/namespace');
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
sub checkAndWriteDefaults($$) {
  my $dir = shift;
  my $script = shift;

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
  my $type = (exists($USFM{'bible'}) && $confdataP->{'ModuleName'} !~ /DICT$/ ? 'bible':0);
  if (!$type) {$type = (exists($USFM{'dictionary'}) && $confdataP->{'ModuleName'} =~ /DICT$/ ? 'dictionary':0);}
  if (!$type) {$type = 'other';}
  
  # ModDrv
  if ($type eq 'bible') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'zText', 1);}
  if ($type eq 'dictionary') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'RawLD4', 1);}
  if ($type eq 'other') {&setConfFileValue("$dir/config.conf", 'ModDrv', 'RawGenBook', 1);}
 
  # Companion
  my $companion;
  if ($type eq 'bible' && exists($USFM{'dictionary'})) {
    $companion = $confdataP->{'ModuleName'}.'DICT';
    if (!-e "$dir/$companion") {
      make_path("$dir/$companion");
      &checkAndWriteDefaults("$dir/$companion", $script);
    }
    else {&Log("WARNING: Companion directory \"$dir/$companion\" already exists, skipping defaults check for it.\n");}
  }
  my $parent = $dir; $parent =~ s/^.*?[\\\/]([^\\\/]+)[\\\/][^\\\/]+\s*$/$1/;
  if ($type eq 'dictionary' && $confdataP->{'ModuleName'} eq $parent.'DICT') {$companion = $parent;}
  if ($companion) {
    &setConfFileValue("$dir/config.conf", 'Companion', $companion, ', ');
  }
  
  # CF_usfm2osis.txt
  if (&copyDefaultFiles($dir, '.', 'CF_usfm2osis.txt')) {
    if (!open (CFF, ">>$dir/CF_usfm2osis.txt")) {&Log("ERROR: Could not open \"$dir/CF_usfm2osis.txt\"\n"); die;}
    foreach my $f (keys %{$USFM{$type}}) {
      my $r = File::Spec->abs2rel($f, $dir); if ($r !~ /^\./) {$r = './'.$r;}
      print CFF "RUN:$r\n";
    }
    close(CFF);
  }
  
  # CF_addScripRefLinks.txt
  &copyDefaultFiles($dir, '.', 'CF_addScripRefLinks.txt');
  
  if ($type eq 'bible') {
    $confdataP = &readConf("$dir/config.conf"); # need a re-read after above modifications
  
    # GoBible
    if ($script =~ /^(osis2GoBible|sfm2all)$/i) {
      if (&copyDefaultFiles($dir, 'GoBible', 'collections.txt, icon.png, normalChars.txt, simpleChars.txt, ui.properties')) {
        if (!open (COLL, ">>encoding(UTF-8)", "$dir/GoBible/collections.txt")) {&Log("ERROR: Could not open \"$dir/GoBible/collections.txt\"\n"); die;}
        print COLL "Info: (".$confdataP->{'Version'}.") ".$confdataP->{'Description'}."\n";
        print COLL "Application-Name: ".$confdataP->{'Abbreviation'}."\n";
        my %canon;
        my %bookOrder;
        my %testament;
        if (&getCanon($confdataP->{'Versification'}, \%canon, \%bookOrder, \%testament)) {
          my $col = ''; my $colot = ''; my $colnt = '';
          foreach my $v11nbk (sort {$bookOrder{$a} <=> $bookOrder{$b}} keys %bookOrder) {
            foreach my $f (keys %{$USFM{'bible'}}) {
              if ($USFM{'bible'}{$f}{'osisBook'} ne $v11nbk) {next;}
              my $b = "Book: $v11nbk\n";
              $col .= $b;
              if ($testament{$v11nbk} eq 'OT') {$colot .= $b;}
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
    }
    
    # eBooks
    if ($script =~ /^(osis2ebooks|sfm2all)$/i) {
      if (&copyDefaultFiles($dir, 'eBook', 'convert.txt')) {
        if (!open (CONV, ">>encoding(UTF-8)", "$dir/eBook/convert.txt")) {&Log("ERROR: Could not open \"$dir/eBook/convert.txt\"\n"); die;}
        print CONV "Language=".$confdataP->{'Lang'}."\n";
        print CONV "Publisher=".$confdataP->{'CopyrightHolder'}."\n";
        print CONV "Title=".$confdataP->{'Description'}."\n";
        foreach my $f (keys %{$USFM{'bible'}}) {
          print CONV $USFM{'bible'}{$f}{'osisBook'}.'='.$USFM{'bible'}{$f}{'h'}."\n";
        }
        close(CONV);
      }
    }
  }
  
  return 1;
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
    foreach my $k (keys %{$sfmInfoP}) {
      $sfmP->{$sfmInfoP->{'type'}}{$f} = $sfmInfoP;
    }
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
        if (substr($id, 0, 3) ne substr($i, 0, 3)) {&Log("WARNING: ambiguous is tags: \"$id\", \"$i\"\n");}
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
    if ($_ =~ /^\\(c|ie)/) {last;}
  }
  close(SFM);
  
  if ($id =~ /^\s*(\w{3}).*$/) {
    my $shortid = $1;
    $info{'doConvert'} = 1;
    my $osisBook = &getOsisName($shortid, 1);
    if ($osisBook) {
      $info{'osisBook'} = $osisBook;
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /(GLO|DIC)/i) {
      $info{'type'} = 'dictionary';
    }
    else {
      $info{'type'} = 'other';
      if ($id !~ /CB/) {$info{'doConvert'} = 0;} # right now osis-converters only handles Children's Bibles
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
  
  $cmd = &escfile("$SCRD/$script.pl")." ".&escfile($project_dir).($logfile ? " ".&escfile($logfile):'');
  &Log("\n\n\nRUNNING OSIS_CONVERTERS SCRIPT:\n$cmd\n", 1);
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
        my $vers = @vers[0]->value; $vers =~ s/^.*osisCore\.([\d\.]+)\.xsd$/$1/i;
        &setConfValue($entryValueP, 'OSISVersion', $vers, 1);
      }
      if ($XPC->findnodes("//osis:reference[\@type='x-glossary']", $moduleSourceXML)) {
        &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On', 'additional');
      }
      
      # get scope
      if ($type eq 'bible' || $type eq 'commentary') {
        require("$SCRD/scripts/getScope.pl");
        &setConfValue($entryValueP, 'Scope', &getScope($entryValueP->{'Versification'}, $moduleSource), 1);
      }
    }
  }

  if ($entryValueP->{"SourceType"} eq "OSIS") {
    if ($type eq 'bible' || $type eq 'commentary') {
      &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISFootnotes', 'additional');
      &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISHeadings', 'additional');
      &setConfValue($entryValueP, 'GlobalOptionFilter', 'OSISScripref', 'additional');
    }
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


sub getCanon($\%\%\%) {
  my $VSYS = shift;
  my $canonP = shift;     # hash pointer: OSIS-book-name => Array (base 0) containing each chapter's max-verse number
  my $bookOrderP = shift; # hash pointer: OSIS-book-name => position (Gen = 1, Rev = 66)
  my $testamentP = shift; # hash pointer: OSIS-nook-name => 'OT' or 'NT'
  
  if (!&isValidVersification($VSYS)) {return 0;}
  
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($VSYS);
  
  for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
    my $t, $bkt;
    if ($bk < $vk->bookCount(1)) {$t = 1; $bkt = ($bk+1);}
    else {$t = 2; $bkt = (($bk+1) - $vk->bookCount(1));}
    $bookOrderP->{$bkname} = ($bk+1);
    $testamentP->{$bkname} = ($t == 1 ? "OT":"NT");
    my $chaps = [];
    for (my $ch = 1; $ch <= $vk->chapterCount($t, $bkt); $ch++) {
      push(@{$chaps}, $vk->verseCount($t, $bkt, $ch));
    }
    $canonP->{$bkname} = $chaps;
  }
  
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


# Add dictionary links as described in $DWF to the nodes pointed to 
# by $eP array pointer. Expected node types are element or text.
sub addDictionaryLinks(\@$) {
  my $eP = shift; # array of nodes (NOTE: node children are not touched)
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
  
  foreach my $node (@$eP) {
    my @textchildren;
    my $container = ($node->nodeType == 3 ? $node->parentNode():$node);
    if ($node->nodeType == 3) {push(@textchildren, $node);}
    else {@textchildren = $XPC->findnodes('child::text()', $container);}
    if ($MODDRV =~ /LD/ && $XPC->findnodes("self::$KEYWORD", $container)) {next;}
    my $text, $matchedPattern;
    foreach my $textchild (@textchildren) {
      $text = $textchild->data();
      my $done;
      do {
        $done = 1;
        my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
        foreach my $part (@parts) {
          if ($part =~ /<reference.*?<\/reference[^>]*>/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $node, $entry)) {$done = 0;}
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
sub addDictionaryLink(\$$$) {
  my $tP = shift;
  my $node = shift;
  my $entry = shift; # for SeeAlso links only
  
  my $container = ($node->nodeType == 3 ? $node->parentNode():$node);
  
  &dbg(sprintf("tP=%s\nelem=%s\nentry=%s\n", $$tP, $node, $entry), $entry);
  
  if ($$tP =~ /^\s*$/) {return '';}
  
  my $matchedPattern = '';
  my $dbg;
  
  if (!@MATCHES) {@MATCHES = $XPC->findnodes("//match", $DWF);}
  
  my $context;
  my $multiples_context;
  if ($entry) {$context = $entry; $multiples_context = $entry;}
  else {
    $context = &bibleContext($node);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &myContext('ot', $context);
  my $contextIsNT = &myContext('nt', $context);
  
  my $a;
  foreach my $m (@MATCHES) {
    &dbg(sprintf("%16s %10s = ", $context, (($node->nodeType == 3) ? 'text':'<'.$node->localName.'>')), $entry);
    if ($entry && &matchInEntry($m, $entry)) {&dbg("00\n", $entry); next;}
    if (!$contextIsOT && &attributeIsSet('onlyOldTestament', $m)) {&dbg("10\n", $entry); next;}
    if (!$contextIsNT && &attributeIsSet('onlyNewTestament', $m)) {&dbg("20\n", $entry); next;}
    if ($container->localName eq 'hi' && !&attributeIsSet('highlight', $m)) {&dbg("30\n", $entry); next;}
    if ($MULTIPLES{$m->unique_key} && !&attributeIsSet('multiple', $m)) {&dbg("40\n", $entry); next;}
    if ($a = &getAttribute('context', $m)) {if (!&myContext($a, $context)) {&dbg("50\n", $entry); next;}}
    if ($a = &getAttribute('notContext', $m)) {if (&myContext($a, $context)) {&dbg("60\n", $entry); next;}}
    if ($a = &getAttribute('withString', $m)) {if (!&haveString($a, $context, $container)) {&dbg("70\n", $entry); next;}}
    
    my $p = $m->textContent;
    
    if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {&Log("ERROR: Bad match regex: \"$p\"\n"); &dbg("80\n", $entry); next;}
    my $pm = $1; my $pf = $2;
    
    # handle PUNC_AS_LETTER word boundary matching issue
    if ($PUNC_AS_LETTER) {$pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;}
    
    # handle xml decodes
    $pm = decode_entities($pm);
    
    # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
    my $t = $$tP;
    my $i = $pf =~ s/i//;
    $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;
    if ($i) {$t = &uc2($t);}
    if ($pf =~ /(\w+)/) {&Log("ERROR: Regex flag \"$1\" not supported in \"".$m->textContent."\"");}
   
    # finally do the actual MATCHING...
    if ($t !~ /$pm/) {$t =~ s/\n/ /g; &dbg("\"$t\" is not matched by: /$pm/\n", $entry); next;}
      
    my $is = $-[$#+];
    my $ie = $+[$#+];
    
    # if a (?'link'...) named group 'link' exists, use it instead
    if (defined($+{'link'})) {
      my $i; for ($i=0; $i <= $#+; $i++) {if ($$i eq $+{'link'}) {last;}}
      $is = $-[$i];
      $ie = $+[$i];
    }
    
    &dbg("LINKED: $pm\n$t\n$is, $ie, ".$+{'link'}.".\n", $entry);
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
      if (!$sref) {next;}
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
  my $e = shift;
  
  my $debug_entry = ''; #decode('utf8', "Pygamber");
  
  if ($DEBUG || ($debug_entry && $e eq $debug_entry)) {
    &Log($p);
  }
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
          my @entry = $XPC->findnodes('//entry[@osisRef=\''.$sref.'\']', $DWF);
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
  For case insensitive matches using /i to work, all text MUST be surrounded 
  by the \\Q...\\E quote operators. Any other case related Perl constructs 
  will not always work.

-->\n";
}


sub writeDictionaryWordsXML($$) {
  my $in_file = shift;
  my $out_xml = shift;
  
  my @keywords = &getDictKeys($in_file);
  
  my %keys; foreach my $k (@keywords) {$keys{$k}++;}
  if (!open(DWORDS, ">:encoding(UTF-8)", $out_xml)) {&Log("ERROR: Could not open $out_xml"); die;}
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
  
  # if there is no project dictionary words file, then create it
  if (! -e "$INPD/$DICTIONARY_WORDS") {copy($out_xml, "$INPD/$DICTIONARY_WORDS");}
  $DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # if companion has no dictionary words file, then create it too
  foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
    if (!-e "$INPD/../../$companion") {
      &Log("WARNING: Companion project \"$companion\" of \"$MOD\" could not be located to copy $DICTIONARY_WORDS.\n");
      next;
    }
    if (!-e "$INPD/../../$companion/$DICTIONARY_WORDS") {copy ($out_xml, "$INPD/../../$companion/$DICTIONARY_WORDS");}
  }
}


# check that the entries in an imp or osis dictionary source file are included in 
# the global dictionaryWords file. If the difference is only in capitalization,
# which occurs when converting from DictionaryWords.txt to DictionaryWords.xml,
# then fix these, and update the dictionaryWords file.
sub compareToDictWordsFile($) {
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
      elsif (&uc2($es) eq &uc2($ed)) {
        $match = 1;
        $update++;
        $edr->setValue(entry2osisRef($mod, $es));
        my $name = @{$XPC->findnodes('../child::name[1]/text()', $edr)}[0];
        if (&uc2($name) ne &uc2($es)) {&Log("ERROR: \"$name\" does not corresponding to \"$es\" in osisRef \"$edr\" of $DICTIONARY_WORDS\n");}
        else {$name->setData($es);}
        last;
      }
    }
    if (!$match) {&Log("ERROR: Missing entry \"$es\" in $DICTIONARY_WORDS\n"); $allmatch = 0;}
  }
  
  if ($update) {
    if (!open(OUTF, ">$dw_file.tmp")) {&Log("ERROR: Could not open $DICTIONARY_WORDS.tmp\n"); die;}
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
  
  my %entries;
  foreach my $name (@$entriesP) {$entries{$name}++;}
  
  foreach my $e (keys %entries) {
    if ($entries{$e} > 1) {
      &Log("ERROR: Entry \"$e\" appears more than once. These must be merged.\n"); 
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


sub osisXSLT($$$) {
  my $osis = shift;
  my $xsl = shift;
  my $out = shift;

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


sub emptyvss($) {
  my $dir = shift;
  
  my %canon;
  my %bookOrder;
  my %testament;
  if (!&getCanon($ConfEntryP->{'Versification'}, \%canon, \%bookOrder, \%testament)) {
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
    foreach my $bk (keys %bookOrder) {
      my $whole = @{$canon{$bk}}.":".@{$canon{$bk}}[@{$canon{$bk}}-1];
      if ($r =~ s/^([^\n]+)\s1\:1\-\1\s\Q$whole\E\n//m) {$missingBKs .= $bk." ";}
    }
    &Log("$r\nEntire missing books: ".($missingBKs ? $missingBKs:'none')."\nEND EMPTYVSS OUTPUT\n", -1);
  }
  else {&Log("ERROR: Could not check for empty verses. Sword tool \"emptyvss\" could not be found. It may need to be compiled locally.");}
}


sub validateOSIS($) {
  my $osis = shift;
  
  # validate new OSIS file against schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ".&escfile($XMLLINT."xmllint")." --noout --schema \"http://www.bibletechnologies.net/$OSISSCHEMA\" ".&escfile($osis)." 2>> ".&escfile($LOGFILE);
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
  my @paths = ('SCRD', 'INPD', 'OUTDIR', 'SWORD_BIN', 'XMLLINT', 'REPOTEMPLATE_BIN', 'XSLT2', 'GO_BIBLE_CREATOR', 'CALIBRE');
  foreach my $path (@paths) {
    if (!$$path || $$path =~ /^(\/home)?\/vagrant/) {next;}
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
