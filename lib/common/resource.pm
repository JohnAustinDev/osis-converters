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

# Return true if CPU idle time and free RAM both surpass argument
# values. This function also waits a specific number of seconds before
# it returns.
our $RESOURCE_MSG_LAST;
our $RAM_SAFE = 80000; # absolute minimum KB RAM that must be available to return true.
sub resourcesAvailable {
  my $reqIDLE = shift;   # percent CPU idle time required
  my $reqRAMarg = shift; # free RAM required in KB or percent-total-ram as x%
  my $caller = shift;    # name of calling script

  my (%data, @fields);
  # 'vmstat' for CPU data
  my $r = ($caller && $caller =~ /osis2pubs/ ? 5:1); # seconds for vmstat check
  foreach my $line (split(/\n/, &shell("vmstat $r 2", 3))) { # vmstat [options] [delay [count]]
    $line =~ s/(^\s+|\s+$)//g;
    if    ($line =~ /^procs\s+/) {next;} # first line is grouping, so drop
    elsif ($line =~ /^r\s+/) {@fields = split(/\s+/, $line);} # field names
    else { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {$data{'vmstat'}{@fields[$n++]} = $d;}
    }
  }
  # 'free' for RAM data
  foreach my $line (split(/\n/, &shell("free", 3))) {
    if ($line =~ /available/) {@fields = split(/\s+/, $line);} # field names
    elsif ($line =~ /^Mem:/) { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {
        $data{'free'}{@fields[$n++]} = $d;
      }
    }
  }
  
  # Get actual RAM that is required to be available.
  my $reqRAM = $reqRAMarg =~ /^(\d+)%$/ ? ($1 / 100) * $data{'free'}{'total'} : $reqRAMarg;
  if (!($reqRAM > 0)) {$reqRAM = 0;}
  $reqRAM += $RAM_SAFE;
  
  my $idle = $data{'vmstat'}{'id'};
  my $ramkb = $data{'free'}{'available'};
  
  if (!defined($idle) || !defined($ramkb)) {
    &Log("ERROR: unexpected idle ($idle) or ramkb ($ramkb) output\n");
    return;
  }
  
  my $available = $idle >= $reqIDLE && $ramkb >= $reqRAM;
  
  my $msg;
  if (!$available) {
    if ($idle < $reqIDLE) {
      $msg = "$caller is waiting for available CPU ($idle% < $reqIDLE%)...\n";
    }
    else {
      $msg = sprintf("$caller is waiting for available RAM %.1f GB < %.1f GB)...\n", 
      $ramkb/1000000, $reqRAM/1000000);
    }
  }
  if ($msg && $msg ne $RESOURCE_MSG_LAST) {
    print $msg; $RESOURCE_MSG_LAST = $msg;
  }
  
  return $available;
}
