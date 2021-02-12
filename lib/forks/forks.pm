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

# Run a Perl function many times as quickly as possible by running in 
# parallel on separate threads. Perl threads caused core dumps unless 
# started in the root script and consisting of a system function call.

use strict;
use threads;
use threads::shared;
use File::Spec;
use File::Path qw(make_path remove_tree);
use Encode;

my $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){3}$//;

require("$SCRD/lib/forks/fork_funcs.pm");

my $INPD     = @ARGV[0]; # Absolute path to project input directory
my $LOGF     = @ARGV[1]; # Absolute path to log file of main thread
my $SCNM     = @ARGV[2]; # SCRIPT_NAME to use for forks.pm conf() context
my $REQU     = @ARGV[3]; # Absolute path of perl script of caller
my $forkFunc = @ARGV[4]; # Name of the function to run
my $forkArgIndex   = 5;  # @ARGV[$forkArgIndex+] = Arguments for each 
# call of the function, with the form argN:<value>. While reading the
# arguments in order, when arg1 or the final argument is encountered, 
# any last set of arguments will be used to call the function. So each 
# argN will persist for every subsequent call, until it is changed. The
# only other form allowed is ramkb:N which tells forks.pm how much
# memory must be available before a fork can be started in parallel. 
# Note: forks.pm always keeps at least one fork running, regardless of
# CPU or memory availability.

&Log("\nforks.pm ".join(' ', map("'".decode('utf8', $_)."'", @ARGV))."\n");

our $RAM_SAFE = 80000; # required KB RAM to be left available before starting any parallel fork.

# Collect the fork function arguments for each call
my @forkCall;
sub saveForkArgs {
  my $callAP = shift;
  my $argvAP = shift;
  
  my (%args, $ram);
  my $x = $forkArgIndex;
  while (defined(@{$argvAP}[$x])) {
    my $a = decode('utf8', @{$argvAP}[$x++]);
    if ($a =~ s/^arg(\d+)://)  {
      my $n = $1;
      if ($n eq '1') {&pushCall($callAP, \%args, $ram);}
      $args{$n} = $a;
    }
    elsif ($a =~ s/^ramkb:(\d+)$//) {$ram = $1;}
    else {&Log("ERROR: Bad fork argument $a\n");}
  }
  &pushCall($callAP, \%args, $ram);
}
sub pushCall {
  my $aP = shift;
  my $hP = shift;
  my $ram = shift;
  
  if (!defined($hP->{1})) {return;}

  my %call = ( 'ramkb' => $ram );
  foreach my $n (keys %{$hP}) {
    $call{'args'}{sprintf('%03i', $n)} = $hP->{$n};
  }
  push(@{$aP}, \%call);
}
&saveForkArgs(\@forkCall, \@ARGV);

my $caller = &pathToCaller($REQU);
my $forkName = "$SCNM.$caller.fork_";
my $forkLog = "OUT_${SCNM}_fork.txt";
my $tmpdir = $LOGF; $tmpdir =~ s/(?<=\/)[^\/]+$/tmp\/$forkName/;

# Delete any old temporary directories for this fork ($DEBUG leaves them)
foreach my $td (@{&forkTmpDirs($tmpdir, $SCNM, $caller)}) {
  remove_tree($td);
}

# Schedule each call of $forkFunk, keeping CPU near 100% by running
# forks in parallel when there is RAM available.
my $n = 1; my $of = @forkCall;
while (@forkCall) {
  my $hP = shift(@forkCall);
  my @forkArgs; foreach my $a (sort keys %{$hP->{'args'}}) {
    push(@forkArgs, $hP->{'args'}{$a});
  }

  print "\nSTARTING FORK $forkName$n/$of\n";
  threads->create(sub {
    system("\"$SCRD/lib/forks/fork.pm\" " .
      "\"$INPD\"" . ' ' .
      "\"$tmpdir$n/$forkLog\"" . ' ' .
      "\"$SCNM\"" . ' ' .
      "\"$REQU\"". ' ' .
      "\"$forkFunc\"" . ' ' .
      join(' ', map(&escarg($_), @forkArgs)));
    });
  $n++;
  
  while (
    @forkCall && 
    !resourcesAvailable(7, @forkCall[0]->{'ramkb'}) && 
    threads->list(threads::running)
  ) {};
}
foreach my $th (threads->list()) {$th->join();}

# Copy finished fork log files to the main thread's LOGFILE.
foreach my $td (@{&forkTmpDirs($tmpdir, $SCNM, $caller)}) {
  if (!-e "$td/$forkLog") {next;}
  
  if (open(MLF, "<:encoding(UTF-8)", "$td/$forkLog")) {
    if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
      while(<MLF>) {print LGG $_;}
      close(LGG);
    }
    else {&Log("ERROR: forks.pm cannot open $LOGF for appending.\n");}
    close(MLF);
  }
  else {&Log("ERROR: forks.pm cannot open $td/$forkLog for reading.\n");}
}

########################################################################
########################################################################

# Return true if CPU idle time and RAM passes requirements. This check
# takes a specific number of seconds to return.
our $MSG_LAST;
sub resourcesAvailable {
  my $reqIDLE = shift; # percent CPU idle time required
  my $reqRAM = shift;  # KB of free RAM required
  
  $reqRAM += $RAM_SAFE;

  my (%data, @fields);
  # 'vmstat' for CPU data
  my $r = ($REQU =~ /osis2pubs/ ? 5:1); # seconds for vmstat check
  foreach my $line (split(/\n/, `vmstat $r 2`)) { # vmstat [options] [delay [count]]
    if    ($line =~ /procs/) {next;} # first line is grouping, so drop
    elsif ($line =~ /id/) {@fields = split(/\s+/, $line);} # field names
    else { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {$data{'vmstat'}{@fields[$n++]} = $d;}
    }
  }
  # 'free' for RAM data
  foreach my $line (split(/\n/, `free`)) {
    if ($line =~ /available/) {@fields = split(/\s+/, $line);} # field names
    elsif ($line =~ /^Mem:/) { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {
        $data{'free'}{@fields[$n++]} = $d;
      }
    }
  }
  
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
      $msg = "Waiting for CPU ($idle% < $reqIDLE%)...\n";
    }
    else {
      $msg = sprintf("Waiting for RAM %.1f GB < %.1f GB)...\n", 
      $ramkb/1000000, $reqRAM/1000000);
    }
  }
  if ($msg && $msg ne $MSG_LAST) {print $msg; $MSG_LAST = $msg;}
  
  return $available;
}

########################################################################
# THE FOLLOWING SUBS ARE ALSO DEFINED IN common_opsys.pm

sub escarg {
  my $n = shift;
  
  $n =~ s/(?<!\\)(["])/\\$1/g;
  return '"'.$n.'"';
}

sub Log {
  my $p = shift;
  
  my $console = ($p =~ /(DEBUG|ERROR)/);
  if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
    print LGG $p; close(LGG);
  }
  else {$console++;}
  
  if ($console) {print encode('utf8', $p);}
}

1;
