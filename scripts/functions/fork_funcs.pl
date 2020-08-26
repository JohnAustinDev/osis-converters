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
our ($TMPDIR);

# Script specific functions used to save and retrieve data of forks.pl 

# addScripRefLinks
# Global variables and assembleFunc()
our (
  $various_forkP, 
  $UnhandledWords_forkP, 
  $fixDone_forkP, 
  $missedLeftRefs_forkP, 
  $noDigitRef_forkP, 
  $noOSISRef_forkP, 
  $Types_forkP
);
our (
  %various, 
  %UnhandledWords, 
  %fixDone, 
  %missedLeftRefs, 
  %noDigitRef, 
  %noOSISRef, 
  %Types
);
our @addScripRefLinks_json = (
  'various', 
  'UnhandledWords', 
  'fixDone', 
  'missedLeftRefs', 
  'noDigitRef', 
  'noOSISRef',
  'Types'
);
our (
  $CheckRefs,
  $numUnhandledWords,
  $numMissedLeftRefs,
  $numNoDigitRef,
  $numNoOSISRef,
  $newLinks
);
sub addScripRefLinks_assembleFunc {
  
  $CheckRefs         .= $various_forkP->{'CheckRefs'};
  $numUnhandledWords += $various_forkP->{'numUnhandledWords'};
  $numMissedLeftRefs += $various_forkP->{'numMissedLeftRefs'};
  $numNoDigitRef     += $various_forkP->{'numNoDigitRef'};
  $numNoOSISRef      += $various_forkP->{'numNoOSISRef'};
  $newLinks          += $various_forkP->{'newLinks'};

  &assembleValues('concat', 'UnhandledWords');
  &assembleValues('concat', 'missedLeftRefs');
  &assembleValues('concat', 'noDigitRef');
  &assembleValues('concat', 'noOSISRef');
  
  &assembleValues('sum', 'fixDone');
  &assembleValues('sum', 'Types');
}

# addDictLinks
# Global variables and assembleFunc()
our (
  $LINK_OSISREF_forkP,
  $MATCHES_USED_forkP,
  $EntryHits_forkP,
  $EXPLICIT_GLOSSARY_HASH_forkP,
);
our (
  %LINK_OSISREF,
  %MATCHES_USED,
  %EntryHits,
  %EXPLICIT_GLOSSARY_HASH,
);
our @addDictLinks_json = (
  'LINK_OSISREF',
  'MATCHES_USED',
  'EntryHits',
  'EXPLICIT_GLOSSARY_HASH',
);
our @EXPLICIT_GLOSSARY;
sub addDictLinks_assembleFunc {
  
  &assembleValues('sum', 'LINK_OSISREF');
  &assembleValues('sum', 'MATCHES_USED');
  &assembleValues('sum', 'EntryHits');
  
  foreach my $i (sort keys %{$EXPLICIT_GLOSSARY_HASH_forkP}) {
    push(@EXPLICIT_GLOSSARY, $EXPLICIT_GLOSSARY_HASH_forkP->{$i});
  }
}

# osis2pubs
# Global variables and assembleFunc()
our $CONV_REPORT_forkP;
our %CONV_REPORT;
our @osis2pubs_json = ('CONV_REPORT');
sub osis2pubs_assembleFunc {

  &assembleValues('concat', 'CONV_REPORT');
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
      print DAT encode_json(\%{$h});
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
  my $tmp = $TMPDIR; $tmp =~ s/[^\/\\]+$//;
  my $n = 1;
  while (-d "$tmp/fork.$n") {
    no strict "refs";
    &readVarsJSON(\@$json, $tmp, $n);
    &$assembleFunc();
    $n++;
  }
}

# Read a list of JSON files into variables
sub readVarsJSON {
  my $varsAP = shift;
  my $dir = shift;
  my $n = shift;
  
  my $json = JSON::XS->new;

  if (opendir(FORKS, "$dir/fork.$n")) {
    foreach my $f (@{$varsAP}) {
      my $varname = $f.'_forkP';
      if (open(JSON, $READLAYER, "$dir/fork.$n/$f.json")) {
        no strict "refs";
        $$varname = $json->decode(<JSON>);
        close(JSON);
      }
      else {&ErrorBug("runAddScripRefLinks couldn't open $dir/fork.$n/$f\n", 1);}
    }
  }
  else {&ErrorBug("runAddScripRefLinks Couldn't open dir '$dir'", 1);}
}

# Add or concatentate data from the JSON hash back to the global hash of the given name.
sub assembleValues {
  my $how = shift;
  my $name = shift;

  no strict "refs";
  &assembleValues2($how, \%$name, ${$name.'_forkP'});
}

# Sum or concatenate the values of fork hash leaf keys to a data hash.
sub assembleValues2 {
  my $how = shift;
  my $dataP = shift;
  my $forkP = shift;
  
  foreach my $k (keys %{$forkP}) {
    if (ref($forkP->{$k})) {
      if (!defined($dataP->{$k})) {$dataP->{$k} = {};}
      &assembleValues2($how, $dataP->{$k}, $forkP->{$k});
    }
    elsif ($how eq 'sum')    {$dataP->{$k} += $forkP->{$k};}
    elsif ($how eq 'concat') {$dataP->{$k} .= $forkP->{$k};}
  }
}

# Put a normal argument list into the form required by forks.pl 
# (starting as argument $n).
sub getForkArgs {
  my $n = shift;
  
  if ($n != int($n)) {
    &Log("ERROR: getForkArgs first argument must be an integer.\n");
  }
  
  return ' '.join(' ', map(&escarg('arg'.$n++.":$_"), @_));
}

1;
