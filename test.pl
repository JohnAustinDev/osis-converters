#!/usr/bin/perl

use strict;

sub test {
  print @_[0]."\n";
  print @_[1]."\n";
  
  my $aP = shift;
  my $hP = shift;
  print "$aP\n";
  print "$hP\n";
}

my @a = ('a', 'b');
my %h = { 'a' => 1, 'b' => 1 };

print "A: ".\@a."\n";
print "A: ".\%h."\n";

test \@a, \%h;



1;
