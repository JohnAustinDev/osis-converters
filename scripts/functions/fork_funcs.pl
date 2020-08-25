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

# Functions used to save and retrieve data of forks.pl 

use JSON::XS;

our ($TMPDIR);

# Global variables and assembleFunc for addScripRefLinks.pl
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
  $various, 
  $UnhandledWords, 
  $fixDone, 
  $missedLeftRefs, 
  $noDigitRef, 
  $noOSISRef, 
  $Types
);
our @addScripRefLinks_data = (
  'various', 
  'UnhandledWords', 
  'fixDone', 
  'missedLeftRefs', 
  'noDigitRef', 
  'noOSISRef',
  'Types'
);
sub addScripRefLinks_assembleFunc {
  
  $CheckRefs         .= $various_forkP->{'CheckRefs'};
  $numUnhandledWords += $various_forkP->{'numUnhandledWords'};
  $numMissedLeftRefs += $various_forkP->{'numMissedLeftRefs'};
  $numNoDigitRef     += $various_forkP->{'numNoDigitRef'};
  $numNoOSISRef      += $various_forkP->{'numNoOSISRef'};
  $newLinks          += $various_forkP->{'newLinks'};

  &concatValues(\%UnhandledWords, $UnhandledWords_forkP);
  &concatValues(\%missedLeftRefs, $missedLeftRefs_forkP);
  &concatValues(\%noDigitRef,    $noDigitRef_forkP);
  &concatValues(\%noOSISRef,     $noOSISRef_forkP);
  
  &sumValues(\%fixDone,  $fixDone_forkP);
  &sumValues(\%Types, $Types_forkP);
}

# Global variables and assembleFunc for addDictLinks.pl
our ($LINK_OSISREF_forkP, $EXPLICIT_GLOSSARY_HASH_forkP);
our (%LINK_OSISREF, %EXPLICIT_GLOSSARY_HASH);
our @addDictLinks_data = ('LINK_OSISREF', 'EXPLICIT_GLOSSARY_HASH');
our @EXPLICIT_GLOSSARY;
sub addDictLinks_assembleFunc {

  foreach my $k1 (keys %{$LINK_OSISREF_forkP}) {
    foreach my $k2 (keys %{$LINK_OSISREF_forkP->{$k1}}) {
      if ($k2 eq 'total') {
        $LINK_OSISREF{$k1}{$k2} += $LINK_OSISREF_forkP->{$k1}{$k2};
        next;
      }
      foreach my $k3 (keys %{$LINK_OSISREF_forkP->{$k1}{$k2}}) {
        $LINK_OSISREF{$k1}{$k2}{$k3} += $LINK_OSISREF_forkP->{$k1}{$k2}{$k3};
      }
    }
  }
  
  foreach my $i (sort keys %{$EXPLICIT_GLOSSARY_HASH_forkP}) {
    push(@EXPLICIT_GLOSSARY, $EXPLICIT_GLOSSARY_HASH_forkP->{$i});
  }
}

########################################################################
########################################################################


# Called by fork.pl child threads to save their results to JSON files.
sub saveForkData {
  my $caller = shift;
  
  my $data = $caller.'_data';

  no strict "refs";
  foreach my $h (@$data) {
    if (open(DAT, ">$TMPDIR/$h.json")) {
      print DAT encode_json(\%{$h});
    }
    else {&ErrorBug("saveForkData $caller couldn't open $TMPDIR/$h.json\n", 1);}
  }
}

# Called by the main thread to reassemble data from all child threads.
sub reassembleForkData {
  my $caller = shift;
  
  my $data = $caller.'_data';
  my $assembleFunc = $caller.'_assembleFunc';

  # Reassemble the data saved by the separate forks
  my $tmp = $TMPDIR; $tmp =~ s/[^\/\\]+$//;
  my $n = 1;
  while (-d "$tmp/fork.$n") {
    no strict "refs";
    &readVarsJSON(\@$data, $tmp, $n);
    &$assembleFunc();
    $n++;
  }
}

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

sub concatValues {
  my $dataP = shift;
  my $forkP = shift;
  
  foreach my $k (keys %{$forkP}) {
    if (!$forkP->{$k}) {next;}
    $dataP->{$k} .= $forkP->{$k};
  }
}

sub sumValues {
  my $dataP = shift;
  my $forkP = shift;
  
  foreach my $k (keys %{$forkP}) {
    if (ref($forkP->{$k})) {
      foreach my $k2 (keys %{$forkP->{$k}}) {
        $dataP->{$k}{$k2} += $forkP->{$k}{$k2};
      }
    }
    else {$dataP->{$k} += $forkP->{$k};}
  }
}

1;
