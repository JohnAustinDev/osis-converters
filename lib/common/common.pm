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

use DateTime;
use Data::Dumper;
use HTML::Entities;
use Unicode::Normalize;
use Net::Ping;
use Sword;
use Try::Tiny;
use XML::LibXML;

our ($MAININPD, $MOD, $READLAYER, $SCRIPT, $SCRD, $TMPDIR, $WRITELAYER, 
    $XPC, %DOCUMENT_CACHE);

our $MAX_UNICODE = 1103; # Highest Russian Cyrillic Uncode code point
our $SFM2ALL_SEPARATE_LOGS = 1;
    
require("$SCRD/lib/common/cb.pm");
require("$SCRD/lib/common/cache.pm");
require("$SCRD/lib/common/check.pm");
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

# Return 1 if there is an Internet connection or 0 of there is not. 
# This test may take time, so cache the result for the remainder of 
# the script.
our $HAVEINTERNET;
sub haveInternet {

  if (!defined($HAVEINTERNET)) {
    my $r = &shell('bash -c "echo -n > /dev/tcp/8.8.8.8/53"', 3, 1);
    $HAVEINTERNET = ($r =~ /no route to host/i ? 0:1);
  }
  
  return $HAVEINTERNET;
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
"Set NormalizeUnicode in config.conf to:
(true|false|NFD|NFC|NFKD|NFKC|FCD).
See https://perldoc.perl.org/Unicode/Normalize.html for an explanation 
of these normalization types.");
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

# Replace the child nodes of an element with a single text node (or with
# nothing if $new is empty).
sub changeNodeText {
  my $element = shift;
  my $new = shift;

  foreach my $r ($element->childNodes()) {$r->unbindNode();}
  if ($new) {$element->appendText($new)};
}

# Returns the path to a mod's output OSIS file, if it exists, or undef 
# if not. Upon failure, $reportFunc, if provided, will be called with a 
# failure message.
sub getModuleOsisFile {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  my $reportFunc = shift;
  
  my $mof = &getModuleOutputDir($mod)."/$mod.xml";
  if ($reportFunc eq 'quiet' || -e $mof) {return $mof;}
  
  if ($reportFunc) {
    no strict "refs";
    &$reportFunc("$mod OSIS file does not exist: $mof");
  }
  
  return;
}

# Copies a directoryʻs contents to a possibly non existing destination 
# directory
sub copy_dir {
  my $id = shift;
  my $od = shift;
  my $overwrite = shift; # merge with existing directories and 
                         # overwrite existing files
  my $noRecurse = shift; # don't recurse into subdirs
  my $keep = shift; # a regular expression matching files to be copied 
                    # (null means copy all)
  my $skip = shift; # a regular expression matching files to be skipped 
                    # (null means skip none). $skip overrules $keep

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
  make_path("$od");

  for(my $i=0; $i < @fs; $i++) {
    if ($fs[$i] =~ /^\.+$/) {next;}
    my $if = "$id/".$fs[$i];
    my $of = "$od/".$fs[$i];
    if (!$noRecurse && -d $if) {
      &copy_dir($if, $of, $overwrite, $noRecurse, $keep, $skip);
    }
    elsif ($skip && $if =~ /$skip/) {next;}
    elsif (!$keep || $if =~ /$keep/) {
			if ($overwrite && -e $of) {unlink($of);}
			copy($if, $of);
		}
  }
  return 1;
}

# Make a zipped copy of a module.
sub zipModule {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  chdir($moddir);
  
  # capture result so that output lines can be sorted before logging
  my $result = &shell($cmd); 
  chdir($SCRD);
  
  my @lines = split("\n", $result); 
  $result = join("\n", sort @lines); 
  &Log($result, 1);
}

# Return the title of a div. The title is the first main title, or the
# first TOC milestone title, whichever comes first.
sub getDivTitle {
  my $glossdiv = shift;
  
  my $telem = @{$XPC->findnodes('(
    descendant::osis:title[@type="main"][1] | 
    descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n
  )[1]', $glossdiv)}[0];
  if (!$telem) {return '';}

  return &nTitle($telem->textContent());
}

# Return a 4 character hash from any string.
sub oc_stringHash {
  my $s = shift;

  use Digest::MD5 qw(md5 md5_hex md5_base64);
  return substr(md5_hex(encode('utf8', $s)), 0, 4);
}

# Return the first xml tag of an element or a string.
sub pTag {
  my $in = shift;
  
  if (ref($in) =~ /element/i) {$in = $in->toString();}
  
  if ($in =~ /(<[^>]+>)/) {return $1;}
  
  return;
}

# Return the title part of an n attribute value (that is minus any [...] 
# instructions). Optionally, also write those instructions to $instP, if 
# provided.
sub nTitle {
  my $n = shift;
  my $instP = shift;
  
  if    (ref($n) =~ /attr/i)    {$n = $n->value;}
  elsif (ref($n) =~ /element/i) {$n = $n->getAttribute('n');}
 
  if ($n =~ s/^((?:\[[^\]]*\])+)(.*?)$/$2/) {
    if (ref($instP)) {$$instP = $1;}
  }
  
  return $n;
}

# XSLT has an uncontrollable habit of creating huge numbers of WARNINGS.
# This takes XSLT output and returns a filtered version keeping only the 
# first occurence of each warning.
sub logXSLT {
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
  if (!$file) {
    &ErrorBug("Could not parse temporaryFile file: '$path'", 1);
  }
  my $ext = ($file =~ s/^(.*?)\.([^\.]+)$/$1/ ? $2:'');
  if (!$ext) {
    &ErrorBug("Could not parse temporaryFile ext: '$path'", 1);
  }
  
  opendir(TDIR, $TMPDIR) || 
    &ErrorBug("Could not open temporaryFile dir $TMPDIR", 1);
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
