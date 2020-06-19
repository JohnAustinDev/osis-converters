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
my $TOSCRIPT = shift;

if (!open(CCT, "<:encoding(UTF-8)", $CCT)) {
  die "Could not open $CCT";
}

if ($TOSCRIPT && open(SCR, ">:encoding(UTF-8)", $TOSCRIPT)) {
print SCR "#!/usr/bin/perl

my \$USAGE = \"$TOSCRIPT inFile outFile\";

use strict; use utf8;
binmode(STDERR, \":utf8\"); binmode(STDOUT, \":utf8\");
my \$INFILE = shift; my \$OUTFILE = shift;
if (!open(INF,  \"<:encoding(UTF-8)\", \$INFILE) ||
    !open(OUTF, \">:encoding(UTF-8)\", \$OUTFILE))
{
  print \"\\nUsage: \$USAGE\\n\\n\";
  exit;
}

";
}
else {
  $TOSCRIPT = '';
}

# Read CCT replacements
my (%REPLACEMENTS, %STORES, $parsing);
while(<CCT>) {
  if ($TOSCRIPT && $_ =~ /^c (.*)$/) {
    print SCR "\t" x ($parsing-1)."# $1\n";
  }
  
  # Parse the CCT table
  if ($_ =~ s/^begin\s*>\s*//) {$parsing++;}
  
  my ($from, $to);
  if (!$parsing || $_ =~ /^c / || $_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^store\((\d+)\)\s+(["'])(.*?)\2\s+endstore/) {
    $STORES{"s$1"} = "[$3]";
    if ($TOSCRIPT) {
      print SCR "my \$s$1 = \"[$3]\";\n";
    }
  }
  elsif ($_ =~ /^(["'])(.*?)\1\s*(?:(fol|prec)\((\d+)\)\s*)?>\s*(["'])(.*?)\5\s*(?:c .*)?$/) {
    my $f = $2; my $ins = $3; my $store = $4; $to = $6;
    if ($parsing == 1) {
      print SCR "
while(<INF>) {
";
      $parsing++;
    }
    
    if ($ins eq 'prec') {
      $from = "(?<=\$s$store)\Q$f\E";
    }
    elsif ($ins eq 'fol') {
      $from="\Q$f\E(?=\$s$store)";
    }
    elsif (!$ins) {
      $from="\Q$f\E";
    }
    else {
      die "Instruction '$ins' not implemented: $CCT line $.:\n$_";
    }
    
    $REPLACEMENTS{"$.:$from"} = "\Q$to\E";
    if ($TOSCRIPT) {
      print SCR "\ts/$from/\Q$to\E/g;\n";
    }
  }
  else {
    die "Failed to parse $CCT line $.:\n$_";
  }
}
close(CCT);
if ($TOSCRIPT) {
  print SCR "
  print OUTF \$_;
}
close(INF);
close(OUTF);
";
  close(SCR);
}

# Sort replacements
my (@FROM, @TO, %USED);
foreach my $k (sort {&repsort($a, $b)} keys %REPLACEMENTS) {
  my $k2 = $k; $k2 =~ s/^\d+://;
  push(@FROM, $k2); push(@TO, $REPLACEMENTS{$k});
  print "'$k2' = '".$REPLACEMENTS{$k}."'\n";
  $USED{"s/$k2/$REPLACEMENTS{$k}/"} = 0;
}

if (!open(OUTF, ">:encoding(UTF-8)", $OUTFILE)) {
  die "Could not open $OUTFILE for writing";
}

#&strictCCT($INFILE);
&fastCCT($INFILE);


foreach my $s (sort { $USED{$b} <=> $USED{$a} } keys %USED) {
  print sprintf("%10i %s\n", $USED{$s}, $s);
}

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
    if (!($. % 100)) {print "line $.\n";}
    
    for (my $x = 0; $x < @FROM; $x++) {
      if ($_ =~ s/@FROM[$x]/@TO[$x]/g) {
        $USED{"s/@FROM[$x]/@TO[$x]/"}++;
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
    if (!($. % 100)) {print "line $.\n";}
    my $out;
    
    my $end = length($_);
    my $x = 0;
    while ($x < $end) {
      my $y = 0;
      while ($y < @FROM) {
        if ($_ =~ /^.{$x}(@FROM[$y])/) {
          $out .= @TO[$y];
          $x += length($1);
          $USED{"s/@FROM[$y]/@TO[$y]/"}++;
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

  
