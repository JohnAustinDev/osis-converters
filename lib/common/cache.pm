# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

1;
