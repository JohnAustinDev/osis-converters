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

use JSON::XS;
our $TMPDIR;

# Script specific functions used to save and retrieve data of forks.pl 

# addScripRefLinks
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
}

# addDictLinks
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

# osis2pubs
# Global variables to be aggregated, and assembleFunc()
our %CONV_REPORT;
our @osis2pubs_json = ('%CONV_REPORT');
sub osis2pubs_assembleFunc {

  &assemble('concat', '%CONV_REPORT');
}


########################################################################
########################################################################

# Called by fork.pl child threads to save their results to JSON files.
sub saveForkData {
  my $caller = shift;
  
  my $json = $caller.'_json';

  no strict "refs";
  foreach my $h (@$json) {
    if (open(DAT, ">$TMPDIR/$h.json")) {
      my $v = $h; my $t = ($v =~ s/^(%|@|\$)// ? $1:'');
      if    ($t eq '%') {print DAT encode_json(\%{$v});}
      elsif ($t eq '@') {print DAT encode_json(\@{$v});}
      elsif ($t eq '$') {
        my @tmp = ( ${$v} );
        print DAT encode_json(\@tmp);
      }
      else {&ErrorBug("saveForkData JSON name must start with %, @ or \$: '$h'\n", 1);}
    }
    else {&ErrorBug("saveForkData $caller couldn't open $TMPDIR/$h.json\n", 1);}
  }
}

# Called by the main thread to reassemble data from all child threads.
sub reassembleForkData {
  my $caller = shift;
  
  my $json = $caller.'_json';
  my $assembleFunc = $caller.'_assembleFunc';

  # Reassemble the data saved by the separate forks
  my $n = 1;
  while (-d "$TMPDIR.fork_$n") {
    my $dir = "$TMPDIR.fork_".$n++;
    
    no strict "refs";
    &readVarsJSON(\@$json, $dir);
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

# Add or concatentate data from the JSON hash back to the global hash of the given name.
sub assemble {
  my $how = shift;
  my $var = shift;
  
  my $name = $var;
  my $type = ($name =~ s/^(%|@|\$)// ? $1:'');

  my $forkP; { no strict "refs"; $forkP = ${$name.'_forkP'}; }
  
  if ($type eq '$') {
    if    ($how eq 'sum')    {${$name} += $$forkP;}
    elsif ($how eq 'concat') {${$name} .= $$forkP;}
    else {&ErrorBug("assemble bad scalar operation: '$how'\n");}
  }
  elsif ($how ne 'push') {
    # Hash globals
    &assemble2($how, \%$name, $forkP);
  }
  else {
    # Array globals
    push(@$name, @{$forkP});
  }
}

# Sum, concatenate or push the values of fork hash leaf keys to a global hash variable.
sub assemble2 {
  my $how = shift;
  my $dataP = shift;
  my $forkP = shift;
 
  foreach my $k (keys %{$forkP}) {
    if (ref($forkP->{$k}) eq 'HASH') {
      if (!defined($dataP->{$k})) {$dataP->{$k} = {};}
      &assemble2($how, $dataP->{$k}, $forkP->{$k});
    }
    elsif (ref($forkP->{$k}) eq 'ARRAY') {
      if (!defined($dataP->{$k})) {$dataP->{$k} = [];}
      if (ref($dataP->{$k}) eq 'ARRAY') {
        push(@{$dataP->{$k}}, @{$forkP->{$k}});
      }
      else {&ErrorBug("assemble2 unmatched data structure $how, $dataP->{$k}", 1);}
    }
    elsif ($how eq 'sum')    {$dataP->{$k} += $forkP->{$k};}
    elsif ($how eq 'concat') {$dataP->{$k} .= $forkP->{$k};}
  }
}

# Put a normal argument list into the form required by forks.pl 
# (starting as argument $n).
sub getForkArgs {
  
  my $n = 1;
  if (@_[0] =~ /^\Qstarts-with-arg:\E(\d+)/) {$n = $1; shift;}
  
  return ' '.join(' ', map(&escarg('arg'.$n++.":$_"), @_));
}

1;
