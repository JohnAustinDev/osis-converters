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

# Run a Perl function on a set of files as quickly as possible by
# running them in parallel on separate threads. Perl threads caused
# core dumps unless started in the root script and consisting of a 
# system function call.

use strict;
use threads;
use threads::shared;
use File::Spec;
use File::Path qw(make_path remove_tree);

my $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){3}$//; 

my $INPD     = @ARGV[0]; # Absolute path to project input directory
my $LOGF     = @ARGV[1]; # Absolute path to log file
my $TEMP     = @ARGV[2]; # Absolute path to temp directory
my $forkFunc = @ARGV[3]; # Name of the function to run (the function's first arg must be the file path, which will be modified in place)
my $forkArgIndex = 4;    # @ARGV[$forkArgIndex+] = Arguments for each 
# run of the function, which either start with argN:<value> or are file 
# paths. While reading @ARGV[3+] in order, whenever a file path argument 
# or the final argument is encountered, then the latest argN value will 
# be used to run the function on the previous file path.

# Collect the forked function arguments
my @forkCall;
sub saveForkArgs {
  my $callAP = shift;
  my $argvAP = shift;
  
  my ($f, %args);
  my $x = $forkArgIndex;
  while (@{$argvAP}[$x]) {
    my $a = @{$argvAP}[$x];
    if ($a =~ s/^arg(\d+)://)  {$args{$1} = $a;}
    else {
      &pushCall($callAP, $f, \%args);
      $f = $a;
    }
    $x++;
  }
  &pushCall($callAP, $f, \%args);
}
sub pushCall {
  my $aP = shift;
  my $f = shift;
  my $hP = shift;

  if ($f) {
    my %call = ( 'file' => $f );
    foreach my $k (keys %{$hP}) {
      $call{'args'}{$k} = $hP->{$k};
    }
    push(@{$aP}, \%call);
  }
}
&saveForkArgs(\@forkCall, \@ARGV);

# Prepare for the log files and temporary  files which will be generated
my $logdir = $TEMP; $logdir =~ s/[^\/\\]+$/forks/;
if (-e $logdir) {remove_tree($logdir);}
make_path($logdir);
my $tmpdir = $TEMP; $tmpdir =~ s/[^\/\\]+$/fork/;
my $n = 1; while (-e "$tmpdir.$n") {remove_tree("$tmpdir.".$n++);}

# Schedule each call of $forkFunk, keeping CPU near 100%
my $n = 1;
while (@forkCall) {
  my $hP = shift(@forkCall);
  my $forkFile = $hP->{'file'};
  my @forkArgs; foreach my $k (sort keys %{$hP->{'args'}}) {
    push(@forkArgs, $hP->{'args'}{$k});
  }
  
  if (!-e $forkFile) {
    &ErrorBug("Fork file does not exist: $forkFile\n");
    last;
  }

  threads->create(sub {system("\"$SCRD/scripts/functions/fork.pl\" " .
      "\"$INPD\"" . ' ' .
      "\"$logdir/OUT_fork$n.txt\"" . ' ' .
      "\"$forkFunc\"" . ' ' .
      "\"$forkFile\"" . ' ' .
      join(' ', @forkArgs));
  });
  $n++;
  
  while (
    @forkCall && 
    !resourcesAvailable(7, 250000) && 
    threads->list(threads::running)
  ) {};
}
foreach my $th (threads->list()) {$th->join();}

# Copy all forkN log files to LOGFILE.
$n = 1;
while (-e "$logdir/OUT_fork$n.txt") {
  if (open(MLF, "<:encoding(UTF-8)", "$logdir/OUT_fork$n.txt")) {
    if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
      while(<MLF>) {print LGG $_;}
      close(LGG);
    }
    close(MLF);
  }
  else {&Log("ERROR: Could not read log file $logdir/OUT_fork$n.txt\n");}
  $n++;
}

########################################################################
########################################################################

# Return true if CPU idle time and RAM passes requirements. This check
# takes a specific number of seconds to return.
sub resourcesAvailable {
  my $reqIDLE = shift; # percent CPU idle time required
  my $reqRAM =shift;   # RAM required

  my (@fields, %data, $idle);
  foreach my $line (split(/\n/, `vmstat 1 2`)) { # vmstat [options] [delay [count]]
    if    ($line =~ /\bprocs\b/) {next;} # first line is grouping, so drop
    elsif ($line =~ /\bid\b/) {@fields = split(/\s+/, $line);} # field names
    else { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {$data{@fields[$n++]} = $d;}
    }
  }
  
  if (!defined($data{'id'}) || !defined($data{'free'})) {
    print "ERROR: unexpected vmstat output\n";
    return;
  }
  
  my $available = $data{'id'} >= $reqIDLE && $data{'free'} >= $reqRAM;
  
  if ($available) {
    print "CPU idle time: $data{'id'}%, free RAM: ".($data{'free'}/1000000)." GB\n";
  }
  
  return $available;
}

sub Log {
  my $p = shift;
  
  if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
    print LGG $p; close(LGG);
  }
  else {print $p;}
}

1;
