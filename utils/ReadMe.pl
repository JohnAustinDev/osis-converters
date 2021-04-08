#! /usr/bin/perl

use strict; 

# Update osis-converters ReadMe.md

BEGIN { # allow subs to be redefined
  our $SCRIPT_NAME = 'convert';
  use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//; require "$SCRD/lib/common/bootstrap.pm";
}

our $SCRD;

open(INF, ">:encoding(UTF-8)", "$SCRD/ReadMe.md") || die;

print INF "# osis-converters
Ubuntu 16 or 18 dependencies may be installed with `sudo ./provision.sh`. Other operating systems, including MS-Windows and MacOS, require [Vagrant](https://www.vagrantup.com/downloads), [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Perl](https://www.activestate.com/products/perl/downloads/); then osis-converters will start its own virtual machine.\n";
print INF &help();

close(INF);

########################################################################
########################################################################

# Redefine subs from help.pm to output md markup.
sub helpList {
  my $listheadAP = shift;
  my $listAP = shift;
  
  my $r;
  
  # Collapse no-heading lists
  if (!$listheadAP->[0] && !$listheadAP->[1]) {
    foreach my $row (@{$listAP}) {
      $r .= $row->[0] . ': ' . &para(&helpTags($row->[1]), 0, 0, 0, 1) . "\n";
    }
    $r .= "\n";
    return $r;
  }
  
  # Heading
  $r .= &esc($listheadAP->[0]) . ' | ' . 
        &helpTags(&esc($listheadAP->[1])) . "\n";
        
  $r .= '-' x length($listheadAP->[0]) . ' | ' . 
        '-' x length(&helpTags($listheadAP->[1])) . "\n";
  
  # Rows
  foreach my $row (@{$listAP}) {
    my $e = $row->[0];
    $e =~ s/(<[^>]*>)/`$1`/g;
    if ($e !~ /^[\(\*]/) {$e = '**' . $e . '**';}
    $r .= &esc($e) . ' | ' . &esc(&para($row->[1], 0, 0, 0, 1));
  }
  $r .= "\n";
  
  return $r;
}

sub esc {
  my $t = shift;
  
  $t =~ s/\|/\\|/g;
  return $t;
}

sub helpTags {
  my $t = shift;
  
  # Copy of help: HELP(<script>;<heading>;[<key>])
  # These are done first since they add raw &help() text which may 
  # include other tags.
  $t =~ s/HELP\((.*?)\)/&help($1,1,1)/seg;
  
  # Local file paths: PATH(<encoded-path>?)
  $t =~ s/PATH\((.*?)\)/
    my $p = $1; 
    my $e; 
    my $r = &const($p,\$e); 
    '`' . &helpPath($e ? $r : &shortPath($r)) . '`'/seg;
    
  # Reference to help: HELPREF(blah)
  $t =~ s/HELPREF\((.*?)\)/&helpRef($1)/seg;
  
  # Hyperlinks: [text](href)
  $t =~ s/\[([^\]]*)\]\(([^\)]+)\)/my $r=($1 ? "[$1]($2)":"[$2]($2)")/seg;
 
  return $t;
}

sub format {
  my $text = &helpTags(shift);
  my $type = shift;
  
  if (!$text) {return;}
  
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
  my $t = &helpTags(shift);
  my $indent = shift; if (!defined($indent)) {$indent = 0;}
  my $left   = shift; if (!defined($left))   {$left   = 0;}
  my $width  = shift; if (!defined($width))  {$width  = 72;}
  my $noBlankLine = shift;
  
  $t =~ s/\s*\n\s*/ /g;
  $t =~ s/(^\s*|\s*$)//g;
  $t =~ s/(\s*\\b\s*)/<br \/>/g;

  my $r = $t;
  
  $r .= "\n";
  if (!$noBlankLine) {$r .= "\n";}
  
  return $r;
}
