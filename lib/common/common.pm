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

# All code here is expected to be run on a Linux Ubuntu 14 to 18 or 
# compatible operating system having all osis-converters dependencies 
# already installed.

use strict;

our ($MAININPD, $MOD, $OUTDIR, $READLAYER, $SCRIPT, $SCRD, 
    $SWORD_VERSE_SYSTEMS, $TMPDIR, $WRITELAYER, $XML_PARSER, $XPC, 
    %DOCUMENT_CACHE);

our $MAX_UNICODE = 1103; # Default value: highest Russian Cyrillic Uncode code point
our $UPPERCASE_DICTIONARY_KEYS = 1;
our $SFM2ALL_SEPARATE_LOGS = 1;
    
require("$SCRD/lib/common/block.pm");
require("$SCRD/lib/common/cb.pm");
require("$SCRD/lib/common/config.pm");
require("$SCRD/lib/common/context.pm");
require("$SCRD/lib/common/defaults.pm");
require("$SCRD/lib/common/dict.pm");
require("$SCRD/lib/common/header.pm");
require("$SCRD/lib/common/image.pm");
require("$SCRD/lib/common/init.pm");
require("$SCRD/lib/common/osis.pm");
require("$SCRD/lib/common/osisID.pm");
require("$SCRD/lib/common/refs.pm");
require("$SCRD/lib/common/scope.pm");
require("$SCRD/lib/common/scripts.pm");
require("$SCRD/lib/common/split.pm");
require("$SCRD/lib/common/toc.pm");

sub osis_converters {
  my $script = shift;
  my $project_dir = shift; # THIS MUST BE AN ABSOLUTE PATH!
  my $logfile = shift;
  
  my $cmd = &escfile($script)." ".&escfile($project_dir).($logfile ? " ".&escfile($logfile):'');
  &Log("\n\n\nRUNNING OSIS_CONVERTERS:\n$cmd\n", 1);
  &Log("########################################################################\n", 1);
  &Log("########################################################################\n", 1);
  system($cmd.($logfile ? " 2>> ".&escfile($logfile):''));
}

# Return 1 if there is an Internet connection or 0 of there is not. This
# test may take time, so cache the result for the remainder of the script.
our $HAVEINTERNET;
sub haveInternet {

  if (!defined($HAVEINTERNET)) {
    my $r = &shell('bash -c "echo -n > /dev/tcp/8.8.8.8/53"', 3, 1);
    $HAVEINTERNET = ($r =~ /no route to host/i ? 0:1);
  }
  
  return $HAVEINTERNET;
}

# Caches files from a URL, or if the $listingAP array pointer is 
# provided, a listing of files at the URL (without actually downloading 
# the files). The path to the local cache is returned. If $listingAP 
# pointer is provided, it will be set to the array of file paths. The 
# $depth value is the directory recursion level. If the cache was last 
# updated more than $updatePeriod hours ago, the cache will first be 
# updated. Directories in the $listingAP listing end with '/'. For 
# $listingAP to work, the URL must target an Apache server directory 
# where html listing is enabled.
sub getURLCache {
  my $name = shift;  # local .osis-converters subdirectory to update
  my $url = shift;   # URL to read from
  my $depth = shift; # max subdirectory depth of URL cache
  my $updatePeriod = shift; # hours between updates (0 updates always)
  my $listingAP = shift; # Do not download any files, just write a file listing here.
  
  if (!$name) {&ErrorBug("Subdir cannot be empty.", 1);}
  
  my $pp = "~/.osis-converters/URLCache/$name";
  my $p = &expandLinuxPath($pp);
  if (! -e $p) {make_path($p);}
  my $pdir = $url; $pdir =~ s/^.*?([^\/]+)\/?$/$1/; # URL directory name
  
  # This function may take significant time to complete, and other  
  # threads may try to access the cache before it is ready. So BlockFile  
  # is used to limit the cache to one thread at a time.
  my $blockFile = BlockFile->new("$p/../$name-blocked.txt");

  # Check last time this subdirectory was updated
  if ($updatePeriod && -e "$p/../$name-updated.txt") {
    my $lastTime;
    if (open(TXT, $READLAYER, "$p/../$name-updated.txt")) {
      while(<TXT>) {if ($_ =~ /^epoch=(.*?)$/) {$lastTime = $1;}}
      close(TXT);
    }
    if ($lastTime) {
      my $now = DateTime->now()->epoch();
      my $delta = sprintf("%.2f", ($now-$lastTime)/3600);
      if ($delta < $updatePeriod) {
        if ($listingAP) {&wgetReadFilePaths($p, $listingAP, $p);}
        &Note("Using local cache directory $pp");
        return $p;
      }
    }
  }
  
  if (!&haveInternet()) {
    if ($listingAP) {&wgetReadFilePaths($p, $listingAP, $p);}
    &Note("Using local cache directory $pp");
    &Error(
"No Internet connection, and cached files are invalid.", 
"Connected to the Internet and then rerun the conversion.");
    return $p;
  }
  
  # Refresh the subdirectory contents from the URL.
  &Log("\n\nPlease wait while I update $pp...\n", 2);
  my $success = 0;
  if ($p && $url) {
    if (!-e $p) {mkdir($p);}
    my $net = Net::Ping->new;
    my $d = $url; $d =~ s/^https?\:\/\/([^\/]+).*?$/$1/;
    my $r; try {$r = $net->ping($d, 5);} catch {$r = 0;};
    if ($r) {
      # Download files
      if (!$listingAP) {
        $url =~ s/\/$//; # downloads should never end with /
        shell("cd '$p' && wget -r --level=$depth -np -nd --quiet -erobots=off -N -A '*.*' -R '*.html*' '$url'", 3);
        $success = &wgetSyncDel($p);
      }
      # Otherwise return a listing
      else {
        $url =~ s/(?<!\/)$/\//; # listing URLs should always end in /
        my $cdir = $url; $cdir =~ s/^https?\:\/\/[^\/]+\/(.*?)\/$/$1/; my @cd = split(/\//, $cdir); $cdir = @cd-1; # url path depth
        if ($p !~ /\/\.osis-converters\//) {die;} remove_tree($p); make_path($p);
        &shell("cd '$p' && wget -r --level=$depth -np -nH --quiet -erobots=off --restrict-file-names=nocontrol --cut-dirs=$cdir --accept index.html -X $pdir $url", 3);
        $success = &wgetReadFilePaths($p, $listingAP, $p);
      }
    }
  }
  
  if ($success) {
    &Note("Updated local cache directory $pp from URL $url");
    
    # Save time of this update
    if (open(TXT, $WRITELAYER, "$p/../$name-updated.txt")) {
      print TXT "localtime()=".localtime()."\n";
      print TXT "epoch=".DateTime->now()->epoch()."\n";
      close(TXT);
    }
  }
  else {
    &Error("Failed to update $pp from $url.", "That there is an Internet connection and that $url is a valid URL.");
  }
  
  return $p;
}

# Delete any local files that were not just downloaded by wget
sub wgetSyncDel {
  my $p = shift;
  
  my $success = 0;
  $p =~ s/\/\s*$//;
  if ($p !~ /\/\Q.osis-converters\E\//) {return 0;} # careful with deletes
  my $dname = $p; $dname =~ s/^.*\///;
  my $html = $XML_PARSER->load_html(location  => "$p/$dname.tmp", recover => 1);
  if ($html) {
    $success++;
    my @files = $html->findnodes('//tr//a');
    my @files = map($_->textContent() , @files);
    opendir(PD, $p) or &ErrorBug("Could not open dir $p", 1);
    my @locfiles = readdir(PD); closedir(PD);
    foreach my $lf (@locfiles) {
      if (-d "$p/$lf") {next;}
      my $del = 1; foreach my $f (@files) {if ($f eq $lf) {$del = 0;}}
      if ($del) {unlink("$p/$lf");}
    }
  }
  else {&ErrorBug("The $dname.tmp HTML was undreadable: $p/$dname.tmp");}
  shell("cd '$p' && rm -f *.tmp", 3);
  
  return $success;
}

# Recursively read $wgetdir directory that contains the wget result 
# of reading an apache server directory, and add paths of listed files 
# and directories to the $filesAP array pointer. All directories will
# end with a '/'.
sub wgetReadFilePaths {
  my $wgetdir = shift; # directory containing the wget result of reading an apache server directory
  my $filesAP = shift; # the listing of subdirectories on the server
  my $root = shift; # root of recursive search
  
  if (!opendir(DIR, $wgetdir)) {
    &ErrorBug("Could not open $wgetdir");
    return 0;
  }
  
  my $success = 1;
  my @subs = readdir(DIR);
  closedir(DIR);
  
  foreach my $sub (@subs) {
    $sub = decode_utf8($sub);
    if ($sub =~ /^\./ || $sub =~ /(robots\.txt\.tmp)/) {next;}
    elsif (-d "$wgetdir/$sub") {
      my $save = "$wgetdir/$sub/"; $save =~ s/^\Q$root\E\/[^\/]+/./;
      push(@{$filesAP}, $save);
      #&Debug("Found folder: $save\n", 1);
      $success &= &wgetReadFilePaths("$wgetdir/$sub", $filesAP, $root);
      next;
    }
    elsif ($sub ne 'index.html') {
      &ErrorBug("Encountered unexpected file $sub in $wgetdir.");
      $success = 0;
      next;
    }
    my $html = $XML_PARSER->load_html(location  => "$wgetdir/$sub", recover => 1);
    if (!$html) {&ErrorBug("Could not parse $wgetdir/$sub"); $success = 0; next;}
    foreach my $a ($html->findnodes('//tr/td/a')) {
      my $icon = @{$a->findnodes('preceding::img[1]/@src')}[0];
      if ($icon->value =~ /\/(folder|back)\.gif$/) {next;}
      my $save = "$wgetdir/".decode_utf8($a->textContent()); $save =~ s/^\Q$root\E\/[^\/]+/./;
      if ($save ne ".") {
        push(@{$filesAP}, $save);
        #&Debug("Found file: $save\n", 1);
      }
    }
  }
  
  return $success;
}

sub readParatextReferenceSettings {

  my @files = split(/\n/, &shell("find \"$MAININPD/sfm\" -type f -exec grep -q \"<RangeIndicator>\" {} \\; -print", 3, 1));
  my $settingsFilePATH;
  my $settingsFileXML;
  foreach my $file (@files) {
    if ($file && -e $file && -r $file) {
      &Note("Reading Settings.xml file: $file", 1);
      $settingsFilePATH = $file;
      last;
    }
  }
  if ($settingsFilePATH) {$settingsFileXML = $XML_PARSER->parse_file($settingsFilePATH);}

  # First set the defaults
  my %settings = (
    'RangeIndicator' => '-', 
    'SequenceIndicator' => ',', 
    'ReferenceFinalPunctuation' => '.', 
    'ChapterNumberSeparator' => '; ', 
    'ChapterRangeSeparator' => decode('utf8', '—'), 
    'ChapterVerseSeparator' => ':',
    'BookSequenceSeparator' => '; '
  );
  
  # Now overwrite defaults with anything in settingsFileXML
  foreach my $k (sort keys %settings) {
    my $default = $settings{$k};
    if ($settingsFileXML) {
      my $kv = @{$XPC->findnodes("$k", $settingsFileXML)}[0];
      if ($kv && $kv->textContent) {
        my $v = $kv->textContent;
        &Note("<>Found localized Scripture reference settings in $settingsFilePATH");
        if ($v ne $default) {
          &Note("Setting Paratext $k from '".$settings{$k}."' to '$v' according to $settingsFilePATH");
          $settings{$k} = $v;
        }
      }
    }
  }
  
  #&Debug("Paratext settings = ".Dumper(\%settings)."\n", 1); 
  
  return \%settings;
}

# Convert entire OSIS file to Normalization Form C (formed by canonical 
# decomposition followed by canonical composition) or another form.
sub normalizeUnicode {
  my $osisP = shift;
  my $normalizationType = shift;
  
  if ($normalizationType =~ /true/i) {$normalizationType = 'NFC';}
  
  no strict 'refs';
  if (!defined(&$normalizationType)) {
    &Error("Unknown Unicode normalization type: $normalizationType", 
"Change NormalizeUnicode in config.conf to true, false, NFD, 
NFC, NFKD, NFKC or FCD. See https://perldoc.perl.org/Unicode/Normalize.html 
for an explanation of the differences.");
    return;
  }
  
  my $output = &temporaryFile($$osisP, '', 1);
  
  open(ISF, $READLAYER, $$osisP);
  open(OSF, $WRITELAYER, $output);
  while (<ISF>) {print OSF &$normalizationType($_);}
  close(OSF);
  close(ISF);
  
  $$osisP = $output;
}

# Converts cases using special translations
sub lc2 {return &uc2(shift, 1);}
sub uc2 {
  my $t = shift;
  my $tolower = shift;
  
  # Form for $i: a->A b->B c->C ...
  our $SPECIAL_CAPITALS;
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

my %CANON_CACHE;
sub getCanon {
  my $vsys = shift;
  my $canonPP = shift;     # hash pointer: OSIS-book-name => Array (base 0!!) containing each chapter's max-verse number
  my $bookOrderPP = shift; # hash pointer: OSIS-book-name => position (Gen = 1, Rev = 66)
  my $testamentPP = shift; # hash pointer: OSIS-nook-name => 'OT' or 'NT'
  my $bookArrayPP = shift; # array pointer: OSIS-book-names in verse system order starting with index 1!!
  
  if (!$CANON_CACHE{$vsys}) {
    if (!&isValidVersification($vsys)) {
      &Error("Not a valid versification system: $vsys".
"Must be one of: ($SWORD_VERSE_SYSTEMS)");
      return;
    }
    
    my $vk = new Sword::VerseKey();
    $vk->setVersificationSystem($vsys);
    
    for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
      my ($t, $bkt);
      if ($bk < $vk->bookCount(1)) {$t = 1; $bkt = ($bk+1);}
      else {$t = 2; $bkt = (($bk+1) - $vk->bookCount(1));}
      $CANON_CACHE{$vsys}{'bookOrder'}{$bkname} = ($bk+1);
      $CANON_CACHE{$vsys}{'testament'}{$bkname} = ($t == 1 ? "OT":"NT");
      my $chaps = [];
      for (my $ch = 1; $ch <= $vk->chapterCount($t, $bkt); $ch++) {
        # Note: CHAPTER 1 IN ARRAY IS INDEX 0!!!
        push(@{$chaps}, $vk->verseCount($t, $bkt, $ch));
      }
      $CANON_CACHE{$vsys}{'canon'}{$bkname} = $chaps;
    }
    @{$CANON_CACHE{$vsys}{'bookArray'}} = ();
    foreach my $bk (sort keys %{$CANON_CACHE{$vsys}{'bookOrder'}}) {
      @{$CANON_CACHE{$vsys}{'bookArray'}}[$CANON_CACHE{$vsys}{'bookOrder'}{$bk}] = $bk;
    }
  }
  
  if ($canonPP)     {$$canonPP     = \%{$CANON_CACHE{$vsys}{'canon'}};}
  if ($bookOrderPP) {$$bookOrderPP = \%{$CANON_CACHE{$vsys}{'bookOrder'}};}
  if ($testamentPP) {$$testamentPP = \%{$CANON_CACHE{$vsys}{'testament'}};}
  if ($bookArrayPP) {$$bookArrayPP = \@{$CANON_CACHE{$vsys}{'bookArray'}};}

  return $vsys;
}

sub isValidVersification {
  my $vsys = shift;
  
  my $vsmgr = Sword::VersificationMgr::getSystemVersificationMgr();
  my $vsyss = $vsmgr->getVersificationSystems();
  foreach my $vsys (@$vsyss) {if ($vsys->c_str() eq $vsys) {return 1;}}
  
  return 0;
}

sub changeNodeText {
  my $node = shift;
  my $new = shift;

  foreach my $r ($node->childNodes()) {$r->unbindNode();}
  if ($new) {$node->appendText($new)};
}

sub getModuleOutputDir {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  
  if ($OUTDIR && ! -d $OUTDIR) {
    $OUTDIR = undef;
    &Error("OUTDIR is not an existing directory.", 
"OUTDIR has been set to a non-existent directory in:\n" . &findConf('OUTDIR') . "\n" .
"Change it to the path of a directory where output files can be written.");
  }
  
  my $moddir;
  if ($OUTDIR) {$moddir = "$OUTDIR/$mod";}
  else {
    my $parentDir = "$MAININPD/..";
    if ($mod =~ /^(.*?)DICT$/) {$moddir = "$parentDir/$1/$mod/output";}
    else {$moddir = "$parentDir/$mod/output";}
  }

  return $moddir;
}

# Returns the path to mod's OSIS file if it exists or '' if not. Upon
# failure, $reportFunc will be called with a failure message.
sub getModuleOsisFile {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  my $reportFunc = shift;
  
  my $mof = &getModuleOutputDir($mod)."/$mod.xml";
  if ($reportFunc eq 'quiet' || -e $mof) {return $mof;}
  
  if ($reportFunc) {
    no strict "refs";
    &$reportFunc("$mod OSIS file does not exist: $mof");
  }
  
  return '';
}

sub checkIntroductionTags {
  my $inosis = shift;

  my $parser = XML::LibXML->new('line_numbers' => 1);
  my $xml = $parser->parse_file($inosis);
  my @warnTags = $XPC->findnodes('//osis:div[@type="majorSection"][not(ancestor::osis:div[@type="book"])]', $xml);
  #my @warnTags = $XPC->findnodes('//osis:title[not(ancestor-or-self::*[@subType="x-introduction"])][not(parent::osis:div[contains(@type, "ection")])]', $xml);
  foreach my $t (@warnTags) {
    my $tag = $t;
    $tag =~ s/^[^<]*?(<[^>]*?>).*$/$1/s;
    &Error("The non-introduction tag on line: ".$t->line_number().", \"$tag\" was used in an introduction. This could trigger a bug in osis2mod.cpp, dropping introduction text.", 'Replace this tag with the proper \imt introduction title tag.');
  }
}

sub checkCharacters {
  my $osis = shift;
  
  open(OSIS, $READLAYER, $osis) || die;
  my %characters;
  while(<OSIS>) {
    foreach my $c (split(/(\X)/, $_)) {if ($c =~ /^[\n ]$/) {next;} $characters{$c}++;}
  }
  close(OSIS);
  
  my $numchars = keys %characters; my $chars = ''; my %composed;
  foreach my $c (sort { ord($a) <=> ord($b) } keys %characters) {
    my $n=0; foreach my $chr (split(//, $c)) {$n++;}
    if ($n > 1) {$composed{$c} = $characters{$c};}
    $chars .= $c;
  }
  &Report("Characters used in OSIS file:\n$chars($numchars chars)");
  
  # Report composed characters
  my @comp; foreach my $c (sort { 
      ($composed{$b} <=> $composed{$a} ? $composed{$b} <=> $composed{$a} : $a cmp $b)
    } keys %composed) {
    push(@comp, "$c(".$composed{$c}.')');
  }
  &Report("<-Extended grapheme clusters used in OSIS file: ".(@comp ? join(' ', @comp):'none'));
  
  # Report rarely used characters
  my $rc = 20;
  my @rare; foreach my $c (
    sort { ( !($characters{$a} <=> $characters{$b}) ? 
             ord($a) <=> ord($b) :
             $characters{$a} <=> $characters{$b} ) 
         } keys %characters) {
    if ($characters{$c} >= $rc) {next;}
    push(@rare, $c);
  }
  &Report("<-Characters occuring fewer than $rc times in OSIS file (least first): ".(@rare ? join(' ', @rare):'none'));
  
  # Check for high order Unicode character replacements needed for GoBible/simpleChars.txt
  my %allChars; for my $c (split(//, $chars)) {$allChars{$c}++;}
  my @from; my @to; &readReplacementChars(&getDefaultFile("bible/GoBible/simpleChars.txt"), \@from, \@to);
  foreach my $chr (sort { ord($a) <=> ord($b) } keys %allChars) {
    if (ord($chr) <= $MAX_UNICODE) {next;}
    my $x; for ($x=0; $x<@from; $x++) {
      if (@from[$x] eq $chr) {&Note("High Unicode character found ( > $MAX_UNICODE): ".ord($chr)." '$chr' <> '".@to[$x]."'"); last;}
    }
    if (@from[$x] ne $chr) {
      &Note("High Unicode character found ( > $MAX_UNICODE): ".ord($chr)." '$chr' <> no-replacement");
      &Warn("<-There is no simpleChars.txt replacement for the high Unicode character: '$chr'", 
      "This character, and its low order replacement, may be added to: $SCRIPT/defaults/bible/GoBible/simpleChars.txt to remove this warning.");
    }
  }
}

sub readReplacementChars {
  my $replacementsFile = shift;
  my $fromAP = shift;
  my $toAP = shift;

  if (open(INF, $READLAYER, $replacementsFile)) {
    while(<INF>) {
      if ($fromAP && $_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$fromAP}, substr($chars, $i, 1));
        }
      }
      if ($toAP && $_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$toAP}, substr($chars, $i, 1));
        }
      }
      if ($fromAP && $_ =~ /Replace-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$fromAP}, $chars);
      }
      if ($toAP && $_ =~ /With-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$toAP}, $chars);
      }
    }
    close(INF);
  }
}

# copies a directoryʻs contents to a possibly non existing destination directory
sub copy_dir {
  my $id = shift;
  my $od = shift;
  my $overwrite = shift; # merge with existing directories and overwrite existing files
  my $noRecurse = shift; # don't recurse into subdirs
  my $keep = shift; # a regular expression matching files to be copied (null means copy all)
  my $skip = shift; # a regular expression matching files to be skipped (null means skip none). $skip overrules $keep

  if (!-e $id || !-d $id) {
    &Error("copy_dir: Source does not exist or is not a direcory: $id");
    return 0;
  }
  if (!$overwrite && -e $od) {
    &Error("copy_dir: Destination already exists: $od");
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
    if (!$noRecurse && -d $if) {&copy_dir($if, $of, $overwrite, $noRecurse, $keep, $skip);}
    elsif ($skip && $if =~ /$skip/) {next;}
    elsif (!$keep || $if =~ /$keep/) {
			if ($overwrite && -e $of) {unlink($of);}
			copy($if, $of);
		}
  }
  return 1;
}

# Copies files from each default directory, starting with lowest to 
# highest priority, and merging files each time.
sub copy_dir_with_defaults {
  my $dir = shift;
  my $dest = shift;
  my $keep = shift;
  my $skip = shift;
  
  my $isDefaultDest; # not sure what this is - 'use strict' caught it
  
  for (my $x=3; $x>=($isDefaultDest ? 2:1); $x--) {
    my $defDir = &getDefaultFile($dir, $x);
    if (!$defDir) {next;}
    # Never copy a directory over itself
    my ($dev1, $ino1) = stat $defDir;
    my ($dev2, $ino2) = stat $dest;
    if ($dev1 eq $dev2 && $ino1 eq $ino2) {next;}
    &copy_dir($defDir, $dest, 1, 0, $keep, $skip);
  }
}

sub fromUTF8 {
  my $c = shift;

  $c = decode("utf8", $c);
  utf8::upgrade($c);
  return $c;
}

sub is_usfm2osis {
  my $osis = shift;

  my $usfm2osis = 0;
  if (!open(TEST, $READLAYER, "$osis")) {&Error("is_usfm2osis could not open $osis", '', 1);}
  while(<TEST>) {if ($_ =~ /<!--[^!]*\busfm2osis.py\b/) {$usfm2osis = 1; last;}}
  close(TEST);
  if ($usfm2osis) {&Log("\n--- OSIS file was created by usfm2osis.py.\n");}
  return $usfm2osis;
}

# make a zipped copy of a module
sub zipModule {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  chdir($moddir);
  my $result = &shell($cmd, 3); # capture result so that output lines can be sorted before logging
  chdir($SCRD);
  &Log("$cmd\n", 1); my @lines = split("\n", $result); $result = join("\n", sort @lines); &Log($result, 1);
}

sub getDivTitle {
  my $glossdiv = shift;
  
  my $telem = @{$XPC->findnodes('(descendant::osis:title[@type="main"][1] | descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n)[1]', $glossdiv)}[0];
  if (!$telem) {return '';}
  
  my $title = $telem->textContent();
  $title =~ s/^(\[[^\]]*\])+//g;
  return $title;
}

sub oc_stringHash {
  my $s = shift;

  use Digest::MD5 qw(md5 md5_hex md5_base64);
  return substr(md5_hex(encode('utf8', $s)), 0, 4);
}

# XSLT has an uncontrollable habit of creating huge numbers of WARNINGS, 
# so only print the first of each.
sub LogXSLT {
  my $log = shift;
  
  my (%seen, $last);
  foreach my $l (split(/^/, $log)) {
    if ($l =~ /^WARNING:/) {
      if (exists($seen{$l})) {next;}
      $seen{$l}++;
    }
    
    if ($l eq $last) {next;}
    
    &Log($l);
    $last = $l;
  }
}

# Take an input file path and return the path of a new temporary file, 
# which is sequentially numbered and does not already exist. If $outname
# is provided, that name will be used for the tmp file, or, if $levelup
# is provided, then the caller $levelup levels up will be used (default
# is one level up).
sub temporaryFile {
  my $path = shift;
  my $outname = shift;
  my $levelup = shift;
  
  if (!$outname) {
    $levelup = ($levelup ? $levelup:1);
    $outname = (caller($levelup))[3]; 
    $outname =~ s/^.*\:{2}//;
  }
  
  my $dir = $path;
  my $file = ($dir =~ s/^(.*?)\/([^\/]+)$/$1/ ? $2:'');
  if (!$file) {&ErrorBug("Could not parse temporaryFile file: '$path'", 1);}
  my $ext = ($file =~ s/^(.*?)\.([^\.]+)$/$1/ ? $2:'');
  if (!$ext) {&ErrorBug("Could not parse temporaryFile ext: '$path'", 1);}
  
  opendir(TDIR, $TMPDIR) || &ErrorBug("Could not open temporaryFile dir $TMPDIR", 1);
  my @files = readdir(TDIR);
  closedir(TDIR);
  
  my $n = 0;
  foreach my $f (@files) {
    if (-d "$TMPDIR/$f") {next;}
    if ($f =~ /^(\d+)_/) {
      my $nf = $1; $nf =~ s/^0+//; $nf = (1*$nf);
      if ($nf > $n) {$n = $nf;}
    }
  }
  $n++;
  
  my $p = sprintf("%s/%02i_%s.%s", $TMPDIR, $n, $outname, $ext);
  
  if (-e $p) {
    &ErrorBug("Temporary file exists: $p", 1);
  }

  return $p;
}

# If $path_or_pointer is a path, $xml is written to it. If it is a 
# pointer, then temporaryFile(pointed-to) will be written, and the 
# pointer will be updated to that new path. If $outname or $levelup is
# provided, they will be passed to temporaryFile().
sub writeXMLFile {
  my $xml = shift;
  my $path_or_pointer = shift;
  my $outname = shift;
  my $levelup = shift;
  
  if (!$levelup) {$levelup = 1;}
  
  my $output;
  if (!ref($path_or_pointer)) {
    $output = $path_or_pointer;
  }
  else {
    $output = &temporaryFile($$path_or_pointer, $outname, (1+$levelup));
    $$path_or_pointer = $output;
  }
  
  if (open(XML, ">$output")) {
    $DOCUMENT_CACHE{$output} = '';
    print XML $xml->toString();
    close(XML);
  }
  else {&ErrorBug("Could not open XML file for writing: '$output'", 1);}
}

1;
