#!/usr/bin/perl
#
# A Perl CCT implementation created for the Uzbek Consistent Change Table
#
# Usage:
#   consistent_changes.pl inFile changes.cct outFile
#

use strict;
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

TOP:
my $INFILE = shift;
my $CCT = shift;
my $OUTFILE = shift;

if (!open(CCT, "<:encoding(UTF-8)", $CCT)) {
  die "Could not open $CCT";
}

# Read CCT replacements
my (%REPLACEMENTS, $parsing);
while(<CCT>) {
  no strict "refs"; 
  
  # Parse the CCT table
  if ($_ =~ s/^begin\s*>\s*//) {$parsing++;}
  
  if (!$parsing || $_ =~ /^c / || $_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^store\((\d+)\)\s+(["'])(.*?)\2\s+endstore/) {
    ${"s$1"} = "[$3]";
  }
  elsif ($_ =~ /^(["'])(.*?)\1\s*(?:(fol|prec)\((\d+)\)\s*)?>\s*(["'])(.*?)\5\s*(?:c .*)?$/) {
    my $from = $2; my $ins = $3; my $store = $4; my $to = $6;
    if ($ins eq 'prec') {
      $REPLACEMENTS{"$.:(?<=".${"s$store"}.")\Q$from\E"} = $to;
    }
    elsif ($ins eq 'fol') {
      $REPLACEMENTS{"$.:\Q$from\E(?=".${"s$store"}.')'} = $to;
    }
    elsif (!$ins) {
      $REPLACEMENTS{"$.:\Q$from\E"} = $to;
    }
    else {
      die "Instruction '$ins' not implemented: $CCT line $.:\n$_";
    }
  }
  else {
    die "Failed to parse $CCT line $.:\n$_";
  }
}
close(CCT);

# &writeReplacements('uzbek.pl');

# Sort replacements
my (@FROM, @TO);
foreach my $k (sort {&repsort($a, $b)} keys %REPLACEMENTS) {
  my $k2 = $k; $k2 =~ s/^\d+://;
  push(@FROM, $k2); push(@TO, $REPLACEMENTS{$k});
  print "'$k2' = '".$REPLACEMENTS{$k}."'\n";
}

if (!open(OUTF, ">:encoding(UTF-8)", $OUTFILE)) {
  die "Could not open $OUTFILE for writing";
}

#&strictCCT($INFILE);
&fastCCT($INFILE);

close(OUTF);
########################################################################

# This is ten thousand times faster than cct() but does not strictly
# follow the CCT way of matching left to right. 
sub fastCCT {
  my $inf = shift;
  
  if (!open(INF, "<:encoding(UTF-8)", $inf)) {
    die "Could not open $inf for reading";
  }

  print "Progress...\n";
  while (<INF>) {
    if (!($. % 10)) {print "line $.\n";}
    
    for (my $x = 0; $x < @FROM; $x++) {
      if ($_ =~ s/@FROM[$x]/@TO[$x]/g) {
        print "s/@FROM[$x]/@TO[$x]/g = $_";
      }
    }
    
    print OUTF $_;
  }
  close(INF);
}

# CCT implentation has separate 'checking' and 'performing' steps for 
# each replacement. The 'checking' order is determined per repsort().
# However, 'performing' always proceeds from first char to last, and the
# 'performed' replacement must include the current character.
sub strictCCT {
  my $inf = shift;
  
  if (!open(INF, "<:encoding(UTF-8)", $inf)) {
    die "Could not open $inf for reading";
  }

  print "Progress...\n";
  while (<INF>) {
    if (!($. % 10)) {print "line $.\n";}
    my $out;
    
    my $end = length($_);
    my $x = 0;
    while ($x < $end) {
      my $y = 0;
      while ($y < @FROM) {
        if ($_ =~ /^.{$x}(@FROM[$y])/) {
          $out .= @TO[$y];
          $x += length($1);
          last;
        }
        $y++;
      }
      if ($y == @FROM) {
        $out .= substr($_, $x, 1);
        $x++;
      }
    }
    
    print OUTF $out;
  }
  close(INF);
}

sub writeReplacements {
  my $script = shift;
  
  if (open(SCR, ">:encoding(UTF-8)", $script)) {
    open(ME, "<:encoding(UTF-8)", $0) or die;
    while(<ME>) {if (/^TOP\:/) {last;} print SCR $_;}
    close(ME);
    foreach my $k (sort {&repsort($a, $b)} keys %REPLACEMENTS) {
      my $re = $k; $re =~ s/^\d+://;
      my $rep = $REPLACEMENTS{$k};
      print SCR "s/$re/$rep/g\n";
    }
  }
}

# Sorting is a critical step. Order is determined as follows:
# - Longest match first. Instructions (any|cont) count as one char and
#   instructions (fol|prec) count as 1/10th of a char.
# - When the same 'length', use the lowest line number first.
sub repsort {
  my $a = shift;
  my $b = shift;
  
  my $an = ($a =~ s/^(\d+):// ? int($1):0);
  my $bn = ($b =~ s/^(\d+):// ? int($1):0);
  if (!$an || !$bn) {die "repsort found no line number: $a, $b";}
    
  my $alen = 0; my $blen = 0;
  if ($a =~ s/\(\?<?=.*?\)//) {$alen = 0.1;}
  if ($b =~ s/\(\?<?=.*?\)//) {$blen = 0.1;}
  if ($a =~ s/\(.*?\)//) {$alen = 1;}
  if ($b =~ s/\(.*?\)//) {$blen = 1;}
  
  $alen += length($a);
  $blen += length($b);
  
  my $r = $blen <=> $alen;
  return ($r ? $r:$an <=> $bn);
}

  
