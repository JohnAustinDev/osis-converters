#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2020 John Austin (gpl.programs.info@gmail.com)
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

use strict;
use JSON::XS;
use File::Path qw(make_path remove_tree);

our ($READLAYER, $NO_FORKS, $TMPDIR, $SCRIPT_NAME, $DEBUG);

# Script specific functions used to save and retrieve data of forks.pm.
# This file should be included in files that call forks.pm.

# addScripRefLinks.pm
# Global variables to be aggregated, and assembleFunc()
our (
  $CheckRefs,
  $numUnhandledWords,
  $numMissedLeftRefs,
  $numNoDigitRef,
  $numNoOSISRef,
  $newLinks,
  %UnhandledWords, 
  %missedLeftRefs, 
  %noDigitRef, 
  %noOSISRef, 
  %fixDone, 
  %Types,
  %asrlworks,
);
our @addScripRefLinks_json = (
  '$CheckRefs',
  '$numUnhandledWords',
  '$numMissedLeftRefs',
  '$numNoDigitRef',
  '$numNoOSISRef',
  '$newLinks',
  '%UnhandledWords', 
  '%missedLeftRefs', 
  '%noDigitRef', 
  '%noOSISRef',
  '%fixDone', 
  '%Types',
  '%asrlworks',
);
sub addScripRefLinks_assembleFunc {
  
  &assemble('concat', '$CheckRefs');
  &assemble('sum',    '$numUnhandledWords');
  &assemble('sum',    '$numMissedLeftRefs')
  &assemble('sum',    '$numNoDigitRef')
  &assemble('sum',    '$numNoOSISRef')
  &assemble('sum',    '$newLinks')
  &assemble('concat', '%UnhandledWords');
  &assemble('concat', '%missedLeftRefs');
  &assemble('concat', '%noDigitRef');
  &assemble('concat', '%noOSISRef');
  &assemble('sum',    '%fixDone');
  &assemble('sum',    '%Types');
  &assemble('sum',    '%asrlworks');
}

# addDictLinks.pm
# Global variables to be aggregated, and assembleFunc()
our (
  %LINK_OSISREF,
  %MATCHES_USED,
  %EntryHits,
  @EXPLICIT_GLOSSARY,
);
our @addDictLinks_json = (
  '%LINK_OSISREF',
  '%MATCHES_USED',
  '%EntryHits',
  '@EXPLICIT_GLOSSARY',
);
sub addDictLinks_assembleFunc {
  
  &assemble('sum',  '%LINK_OSISREF');
  &assemble('sum',  '%MATCHES_USED');
  &assemble('sum',  '%EntryHits');
  &assemble('push', '@EXPLICIT_GLOSSARY');
}

# osis2pubs.pm
# Global variables to be aggregated, and assembleFunc()
our %CONV_REPORT;
our @osis2pubs_json = ('%CONV_REPORT');
sub osis2pubs_assembleFunc {

  &assemble('concat', '%CONV_REPORT');
}


########################################################################
########################################################################

# Called by fork.pm child threads to save their results to JSON files.
# NOTE: $TMPDIR here is that of the fork script.
sub saveForkData {
  my $caller = &caller(shift);
  
  if ($NO_FORKS =~ /\b(1|true|$caller)\b/) {return;}
  
  my $json = $caller.'_json';

  no strict "refs";
  if (@$json) {
    foreach my $h (@$json) {
      if (open(DAT, ">$TMPDIR/$h.json")) {
        my $v = $h; my $t = ($v =~ s/^(%|@|\$)// ? $1:'');
        if    ($t eq '%') {print DAT encode_json(\%{$v});}
        elsif ($t eq '@') {print DAT encode_json(\@{$v});}
        elsif ($t eq '$') {
          my @tmp = ( ${$v} );
          print DAT encode_json(\@tmp);
        }
        else {&ErrorBug("JSON name must start with %, @ or \$: '$h'\n", 1);}
      }
      else {&ErrorBug("$caller couldn't open $TMPDIR/$h.json\n", 1);}
    }
  }
  else {&ErrorBug("missing \@$json array in ".__FILE__."\n", 1);}
}

# Called by the main thread to reassemble data from all child threads.
# NOTE: $TMPDIR and $SCRIPT_NAME here are those of the main thread.
sub reassembleForkData {
  my $caller = &caller(shift);
  
  if ($NO_FORKS =~ /\b(1|true|$caller)\b/) {return;}
  
  my $json = $caller.'_json';
  my $assembleFunc = $caller.'_assembleFunc';

  # Reassemble the data saved by the separate forks
  foreach my $td (@{&forkTmpDirs($caller)}) {
    no strict "refs";
    &readVarsJSON(\@$json, $td);
    &$assembleFunc();
  }
}

# Read a list of JSON files into <name>_forkP pointer variables.
sub readVarsJSON {
  my $varsAP = shift;
  my $dir = shift;
  
  my $json = JSON::XS->new;

  if (opendir(FORKS, $dir)) {
    foreach my $f (@{$varsAP}) {
      my $varname = $f.'_forkP';
      my $t = ($varname =~ s/^(%|@|\$)// ? $1:'');
      if (open(JSON, $READLAYER, "$dir/$f.json")) {
        no strict "refs";
        my $pointer = $json->decode(<JSON>);
        if ($t eq '$') {
          my $tmp = @{$pointer}[0];
          ${$varname} = \$tmp;
        }
        else {${$varname} = $pointer;}
        close(JSON);
      }
      else {&ErrorBug("readVarsJSON couldn't open $dir/$f.json\n", 1);}
    }
  }
  else {&ErrorBug("readVarsJSON Couldn't open dir '$dir'", 1);}
}

# Add or concatentate data from the JSON hash back to the global variable of the given name.
sub assemble {
  my $how = shift;
  my $var = shift;
  
  my $name = $var;
  my $type = ($name =~ s/^(%|@|\$)// ? $1:'');

  my $forkP; { no strict "refs"; $forkP = ${$name.'_forkP'}; }
  
  no strict "refs";
  if ($type eq '$') {
    # Scalar globals
    if    ($how eq 'sum')    {${$name} += $$forkP;}
    elsif ($how eq 'concat') {${$name} .= $$forkP;}
    else {&ErrorBug("assemble bad scalar operation: '$how'\n");}
  }
  elsif ($how ne 'push') {
    # Hash globals
    &assembleHash($how, \%$name, $forkP);
  }
  else {
    # Array globals
    push(@$name, @{$forkP});
  }
}

# Sum, concatenate or push the values of fork hash leaf keys to a global hash variable.
sub assembleHash {
  my $how = shift;
  my $dataP = shift;
  my $forkP = shift;
 
  foreach my $k (keys %{$forkP}) {
    if (ref($forkP->{$k}) eq 'HASH') {
      if (!defined($dataP->{$k})) {$dataP->{$k} = {};}
      &assembleHash($how, $dataP->{$k}, $forkP->{$k});
    }
    elsif (ref($forkP->{$k}) eq 'ARRAY') {
      if (!defined($dataP->{$k})) {$dataP->{$k} = [];}
      if (ref($dataP->{$k}) eq 'ARRAY') {
        push(@{$dataP->{$k}}, @{$forkP->{$k}});
      }
      else {&ErrorBug("assembleHash unmatched data structure $how, $dataP->{$k}", 1);}
    }
    elsif ($how eq 'sum')    {$dataP->{$k} += $forkP->{$k};}
    elsif ($how eq 'concat') {$dataP->{$k} .= $forkP->{$k};}
  }
}

sub forkTmpDirs {
  my $caller = &caller(shift);
  
  my $forkTmp = "$TMPDIR/$caller.fork";
  
  my @dirs;
  
  my $n = 1; 
  while (-e $forkTmp.'/fork_'.$n) {push(@dirs, $forkTmp.'/fork_'.$n++);}
  
  return \@dirs;
}

# Put a normal argument list into the form required by forks.pm 
sub getForkArgs {
  
  # Each argument persists until changed, so constants can be loaded
  # by a separate getForkArgs(starts-with-arg:N, ...) call before the 
  # function's regular getForkArgs calls. This allows constants to be 
  # included with every function call without adding them repeatedly.
  my $n = 1;
  if (@_[0] =~ /^\Qstarts-with-arg:\E(\d+)/) {$n = $1; shift;}
  
  return ' '.join(' ', map(&escarg('arg'.$n++.":$_"), @_));
}

sub caller {
  my $path = shift;
  
  $path =~ s/^.*?\/([^\/\.]+)(\.[^\/\.]+)?$/$1/;
  
  return $path;
}

# Any fork exit codes which are to abort should be listed below.
sub handleAbort {
  my $exitCode = shift;
  my $forkFunc = shift;
  my $forkRequire = shift;
  
  $exitCode = $exitCode >> 8; # remove Perl wait status of system() call
  
  if ($exitCode == 2) {
    &ErrorBug("forkFunc '$forkFunc' does not exist in '$forkRequire'.\n", 1);
  } elsif ($exitCode == 255) {
    &Error("forkFunc '$forkFunc' abort error.\n", '', 1);
  }
}

1;
