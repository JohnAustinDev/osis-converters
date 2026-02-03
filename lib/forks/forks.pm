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

our $INPD         = @ARGV[0]; # Absolute path to project input directory
our $LOGFILE      = @ARGV[1]; # Absolute path to log file of main thread
our $SCRIPT_NAME  = @ARGV[2]; # SCRIPT_NAME for forks.pm conf() context
my  $forkRequire  = @ARGV[3]; # Absolute path of perl script of caller
my  $forkFunc     = @ARGV[4]; # Name of the function to run
my  $forkArgIndex = 5;  # @ARGV[$forkArgIndex+] = Arguments for each 
# call of the function, with the form argN:<value>. While reading the
# arguments in order, when arg1 or the final argument is encountered, 
# any last set of arguments will be used to call the function. So each 
# argN will persist for every subsequent call, until it is changed. The
# only other form allowed is ramkb:N which tells forks.pm how much
# memory must be available before a fork can be started in parallel. 
# Note: forks.pm always keeps at least one fork running, regardless of
# CPU or memory availability.

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/lib/common/bootstrap.pm";

our $DEBUG;
if ($DEBUG) {
  &Log("\nforks.pm ".join(' ', map("'".decode('utf8', $_)."'", @ARGV))."\n");
}

# Initialization already passed with the caller, but need to get $TMPDIR.
require "$SCRD/lib/common/common.pm";
require "$SCRD/lib/common/resource.pm";
&set_project_globals();
&set_system_globals();
&set_system_default_paths();
our $MOD_OUTDIR = &getModuleOutputDir();
our $TMPDIR = &initTMPDIR();

require("$SCRD/lib/forks/fork_funcs.pm");

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

my $caller = &caller($forkRequire);
my $forkDirName = $caller.'.fork';
my $forkLogName = "LOG_${caller}_fork.txt";

my $fatal :shared = 0;
foreach my $e (glob(&escglob("$TMPDIR/$forkDirName/*"))) {
  &Log("ERROR: forks.pm fork tmp directory already exists: $e\n");
  $fatal = 1;
}

# Schedule each call of $forkFunk, keeping CPU near 100% by running
# forks in parallel when there is RAM available.
my $n = 1; my $of = @forkCall;
my @threads;
while ($fatal == 0 && @forkCall) {
  my $hP = shift(@forkCall);
  my @forkArgs; foreach my $a (sort keys %{$hP->{'args'}}) {
    push(@forkArgs, $hP->{'args'}{$a});
  }

  print "\nSTARTING FORK $forkDirName $n/$of\n";
  push(@threads, threads->create(
    sub {
      my $forkLogFile = "$TMPDIR/$forkDirName/fork_$n/$forkLogName";
      my $exitStatus = system("\"$SCRD/lib/forks/fork.pm\" " .
        "\"$INPD\"" . ' ' .
        "\"$forkLogFile\"" . ' ' .
        "\"$SCRIPT_NAME\"" . ' ' .
        "\"$forkRequire\"". ' ' .
        "\"$forkFunc\"" . ' ' .
        join(' ', map(&escarg($_), @forkArgs)));
       $exitStatus = $exitStatus >> 8;
      if ($exitStatus != 0) {$fatal = $exitStatus;}
    }));
  $n++;
  
  while (
    @forkCall && 
    !resourcesAvailable(7, @forkCall[0]->{'ramkb'}, $forkRequire) && 
    threads->list(threads::running)
  ) {};
}
foreach my $th (@threads) {$th->join();}

# Copy finished fork log files back to the main thread's LOGFILE. This
# must be done after all log files have been generated, so they can be
# reassembled in the correct order!
foreach my $td (@{&forkTmpDirs($caller)}) {
  if (-e "$td/$forkLogName") {
    if (open(MLF, "<:encoding(UTF-8)", "$td/$forkLogName")) {
      if (open(LGG, ">>:encoding(UTF-8)", $LOGFILE)) {
        while(<MLF>) {print LGG $_;}
        close(LGG);
      }
      else {&Log("ERROR: forks.pm cannot open $LOGFILE for appending.\n");}
      close(MLF);
    }
    else {&Log("ERROR: forks.pm cannot open $td/$forkLogName for reading.\n");}
  }
  
  if (-s "$td/LOG_stderr.txt") {
    if (open(MLF, "<:encoding(UTF-8)", "$td/LOG_stderr.txt")) {
      if (open(LGG, ">>:encoding(UTF-8)", $LOGFILE)) {
        print LGG "\nERROR: File '$td/LOG_stderr.txt' contains:\n";
        while(<MLF>) {print LGG $_;}
        close(LGG);
      }
      else {&Log("ERROR: forks.pm cannot open $LOGFILE for appending.\n");}
      close(MLF);
    }
    else {&Log("ERROR: forks.pm cannot open $td/LOG_stderr.txt for reading.\n");}
  }
}
if ($fatal) {exit $fatal;}

1;
