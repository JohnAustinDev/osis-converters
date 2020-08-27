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

my $CURRENT_RAM :shared = 0;

#&Log("\nDEBUG: forks.pl ARGV=\n".join("\n", map(decode('utf8', $_), @ARGV))."\n");

my $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){3}$//; 

my $INPD     = @ARGV[0]; # Absolute path to project input directory
my $LOGF     = @ARGV[1]; # Absolute path to log file
my $REQU     = @ARGV[2]; # Absolute path of caller's perl script
my $SCNM     = @ARGV[3]; # SCRIPT_NAME to use for forks.pl conf() context
my $forkFunc = @ARGV[4]; # Name of the function to run
my $forkArgIndex = 5;    # @ARGV[$forkArgIndex+] = Arguments for each 
# call of the function, with the form argN:<value>. While reading the
# arguments in order, when arg1 or the final argument is encountered, 
# any last set of arguments will be used to call the function. Each argN
# will persist for every subsequent call, until it is changed!

# Collect the forked function arguments
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
      if ($n eq '1') {
        &pushCall($callAP, \%args, $ram);
      }
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

my $caller = $REQU; $caller =~ s/^.*?\/([^\/]+)\.pl$/$1/;
my $tmpdir = $LOGF; $tmpdir =~ s/(?<=\/)[^\/]+$/tmp/;
my $tmpsub = "$SCNM.$caller";

# Manually delete all previous fork temp directories, because otherwise
# a larger number of forks having been previously run would be left 
# partially outdated, corrupting the aggregated log file.
my $n = 1;
my $forkdir = "$tmpdir/$tmpsub.fork_".$n;
while (-e $forkdir) {
  remove_tree($forkdir); 
  $forkdir = "$tmpdir/$tmpsub.fork_".++$n;
}

# Schedule each call of $forkFunk, keeping CPU near 100%
my $n = 1; my $of = @forkCall;
while (@forkCall) {
  my $hP = shift(@forkCall);
  my @forkArgs; foreach my $a (sort keys %{$hP->{'args'}}) {
    push(@forkArgs, $hP->{'args'}{$a});
  }

  if ($hP->{'ramkb'}) {$CURRENT_RAM += $hP->{'ramkb'};}
  print "\nSTARTING FORK $tmpsub $n/$of\n";
  threads->create(sub {
    system("\"$SCRD/scripts/functions/fork.pl\" " .
      "\"$INPD\"" . ' ' .
      "\"$tmpdir/$tmpsub.fork_$n/OUT_${SCNM}_fork.txt\"" . ' ' .
      "\"$SCNM\"" . ' ' .
      "\"$REQU\"". ' ' .
      "\"$forkFunc\"" . ' ' .
      join(' ', map(&escarg($_), @forkArgs)));
      
      $CURRENT_RAM -= $hP->{'ramkb'};
    });
  $n++;
  
  while (
    @forkCall && 
    !resourcesAvailable(7, ($CURRENT_RAM + @forkCall[0]->{'ramkb'})) && 
    threads->list(threads::running)
  ) {};
}
foreach my $th (threads->list()) {$th->join();}

# Copy all fork log files to LOGFILE.
my $n = 1;
my $forkdir = "$tmpdir/$tmpsub.fork_".$n;
while (-e $forkdir) {
  my $forklog = "$forkdir/OUT_${SCNM}_fork.txt";
  if (open(MLF, "<:encoding(UTF-8)", $forklog)) {
    if (open(LGG, ">>:encoding(UTF-8)", $LOGF)) {
      while(<MLF>) {print LGG $_;}
      close(LGG);
    }
    close(MLF);
  }
  $forkdir = "$tmpdir/$tmpsub.fork_".++$n;
}

########################################################################
########################################################################

# Return true if CPU idle time and RAM passes requirements. This check
# takes a specific number of seconds to return.
my $MIN_RAM = 1000000; # need at least this kB of free RAM to start another fork
my $MSG_LAST;
sub resourcesAvailable {
  my $reqIDLE = shift; # percent CPU idle time required
  my $reqRAM = shift;  # RAM required in kB
  
  if ($reqRAM < $MIN_RAM) {$reqRAM = $MIN_RAM;}

  my (%data, @fields);
  my $r = ($REQU =~ /osis2pubs/ ? 5:1); # seconds between vmstat checks
  foreach my $line (split(/\n/, `vmstat $r 2`)) { # vmstat [options] [delay [count]]
    if    ($line =~ /procs/) {next;} # first line is grouping, so drop
    elsif ($line =~ /id/) {@fields = split(/\s+/, $line);} # field names
    else { # field data
      my $n = 0;
      foreach my $d (split(/\s+/, $line)) {$data{'vmstat'}{@fields[$n++]} = $d;}
    }
  }
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
# THE FOLLOWING SUBS ARE ALSO DEFINED IN common_opsys.pl

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
