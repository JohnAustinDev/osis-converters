#! /usr/bin/perl

use strict; 

# Update the ReadMe.md page

BEGIN { # allows subs to be replaced
  use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/lib/common/bootstrap.pm";
}

open(INF, ">:encoding(UTF-8)", "../ReadMe.md") || die;

print INF &help();

close(INF);

# These subs redefine subs from help.pm to output md markup.
sub helpList {
  my $listheadAP = shift;
  my $listAP = shift;
  
  my $r;
  
  if (!$listheadAP->[0] && !$listheadAP->[1]) {
    foreach my $row (@{$listAP}) {
      $r .= $row->[0] . ': ' . $row->[1] . "\n";
    }
    $r .= "\n";
    return $r;
  }
  
  $r .= &esc($listheadAP->[0]) . ' | ' . 
        &esc($listheadAP->[1]) . "\n";
        
  $r .= '-' x length($listheadAP->[0]) . ' | ' . 
        '-' x length($listheadAP->[1]) . "\n";
                    
  foreach my $row (@{$listAP}) {
    my $e = $row->[0]; my $d = $row->[1];
    if ($e !~ /^[\(\*]/) {$e = '**' . $e . '**';}
    $d =~ s/HELP\(([^\)]+)\)/&help($1,undef,1,1)/eg;
    $r .= &esc($e) . ' | ' . &para(&esc($d), undef, undef, undef, 1, 1);
  }
  $r .= "\n";
  
  return $r;
}

sub helpLink {
  return shift;
}

sub esc {
  my $t = shift;
  
  $t =~ s/\|/\\|/g;
  return $t;
}

sub format {
  my $text = &helpLink(shift);
  my $type = shift;
  
  my @args; if ($type =~ s/:(.+)$//) {@args = split(/,/, $1);}
  
  if ($type eq 'title') {
    return "\n# $text \n";
  }
  elsif ($type eq 'heading') {
    return "\n## $text \n";
  }
  elsif ($type eq 'sub-heading') {
    return "\n### $text \n";
  }
  elsif ($type eq 'para') {
    return &para($text, @args);
  }
  
  return $text;
}

sub para {
  my $t = &helpLink(shift);
  my $indent = shift; if (!defined($indent)) {$indent = 0;}
  my $left   = shift; if (!defined($left))   {$left   = 0;}
  my $width  = shift; if (!defined($width))  {$width  = 72;}
  my $noBlankLine = shift;
  my $noNewlines = shift;
  
  $t =~ s/\s*\n\s*/ /g;
  $t =~ s/(^\s*|\s*$)//g;
  if (!$noNewlines) {
    $t =~ s/(\s*\\b\s*)/\n/g;
  }
  else {
    $t =~ s/(\s*\\b\s*)/ /g;
  }
  
  my $r = $t;
  
  $r .= "\n";
  if (!$noBlankLine) {$r .= "\n";}
  
  return $r;
}
