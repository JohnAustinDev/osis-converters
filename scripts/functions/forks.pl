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

# Run a Perl multi-call function as quickly as possible by running it in 
# parallel on separate threads. Perl threads caused core dumps unless 
# started in the root script and consisting of a system function call.

use strict;
use threads;
use threads::shared;
use File::Spec;
use File::Path qw(make_path remove_tree);
use Encode;

my $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){3}$//; 

my $INPD     = @ARGV[0]; # Absolute path to project input directory
my $LOGF     = @ARGV[1]; # Absolute path to log file
my $TEMP     = @ARGV[2]; # Absolute path to temp directory
my $forkReq  = @ARGV[3]; # Relative path to required perl file (may be null)
my $forkFunc = @ARGV[4]; # Name of the function to run (the function's first arg must be the file path, which will be modified in place)
my $forkArgIndex = 5;    # @ARGV[$forkArgIndex+] = Arguments for each 
# call of the function, with the form argN:<value>. While reading the
# arguments in order, when arg1 or the final argument is encountered, 
# any last set of arguments will be used to call the function. Any argN
# will persist for every subsequent call, until it is changed!

# Collect the forked function arguments
my @forkCall;
sub saveForkArgs {
  my $callAP = shift;
  my $argvAP = shift;
  
  my %args;
  my $x = $forkArgIndex;
  while (defined(@{$argvAP}[$x])) {
    my $a = decode('utf8', @{$argvAP}[$x++]);
    if ($a =~ s/^arg(\d+)://)  {
      my $n = $1;
      if ($n eq '1') {
        &pushCall($callAP, \%args);
      }
      $args{$n} = $a;
    }
    else {&Log("ERROR: Bad fork argument $a\n");}
  }
  &pushCall($callAP, \%args);
}
sub pushCall {
  my $aP = shift;
  my $hP = shift;
  
  if (!defined($hP->{1})) {return;}

  my %call;
  foreach my $n (keys %{$hP}) {
    $call{sprintf('%03i', $n)} = $hP->{$n};
  }
  push(@{$aP}, \%call);
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
  my @forkArgs; foreach my $a (sort keys %{$hP}) {
    push(@forkArgs, $hP->{$a});
  }

  threads->create(sub {system("\"$SCRD/scripts/functions/fork.pl\" " .
    "\"$INPD\"" . ' ' .
    "\"$logdir/OUT_fork$n.txt\"" . ' ' .
    "\"$forkReq\"". ' ' .
    "\"$forkFunc\"" . ' ' .
    join(' ', map(&escarg($_), @forkArgs))
  )});
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
    &Log("ERROR: unexpected vmstat output\n");
    return;
  }
  
  my $available = $data{'id'} >= $reqIDLE && $data{'free'} >= $reqRAM;
  
  if ($available) {
    print "CPU idle time: $data{'id'}%, free RAM: ".($data{'free'}/1000000)." GB\n";
  }
  
  return $available;
}

########################################################################
# THE FOLLOWING SUBS ARE ALSO DEFINED IN common_opsys.pl

sub escarg {
  my $n = shift;
  
  $n =~ s/(?<!\\)(["])/\\$1/g;
  return '"'.$n.'"';
}

sub Log {
  my $p = shift;
  
  my $console = ($p =~ /ERROR/);
  if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
    print LGG $p; close(LGG);
  }
  else {$console++;}
  
  if ($console) {print encode('utf8', $p);}
}

1;
