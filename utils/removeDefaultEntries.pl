#!/usr/bin/perl

my $projdir = "../../Texts";
my $skip;

our $SCRIPT_NAME = 'convert';

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/lib/common/bootstrap.pm";

our $MAINMOD = "DEFAULT";
my %def = %{&readConfFile("$projdir/defaults/defaults.conf")};

foreach my $c (split(/\n/, &shell("find '$projdir' -name config.conf", 3))) {
  if (!&shell("grep '\\[system\\]' \"$c\"", 3, 1)) {next;}
  
  my %conf = %{&readConfFile($c)};
  
  my $mod = $conf{'MAINMOD'};
  if (!$mod) {die;}
  if ($mod =~ /^($skip)$/i) {next;}
  
  foreach my $dk (sort keys %def) {
    my $mk = $dk;
    if ($mk !~ s/^DEFAULT\+/$mod+/) {next;}
    
    my $e = $dk; $e =~ s/^.*?\+//;
    
    if ($def{$dk} && $def{$dk} eq $conf{$mk}) {
      #print "SAME: $mod $dk\n";
    }
    elsif ($def{$dk} && $conf{$mk} && $def{$dk} ne $conf{$mk}) {
      print "
$mod
$e: $def{$dk} (DEFAULT)
$e: $conf{$mk} ($mod)\n";
    }
  }
}


