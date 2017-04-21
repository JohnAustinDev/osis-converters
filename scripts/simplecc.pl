#!/usr/bin/perl

# usage: simplecc.pl input-file cc-table output-file

# Support running simplecc as a stand alone script
sub myLog {if (defined(&Log)) {&Log(@_);} else {print @_[0];}}
if (@ARGV == 3) {&simplecc(@ARGV[0], @ARGV[1], @ARGV[2]);}

# A simple Constant Changes implementation to apply a very basic CC table using Perl
%CCDATA;

sub simplecc_convert($$) {
  my $t = shift;
  my $cct = shift;
  
  if (!$CCDATA{$cct}) {&readcc($cct);}
  
  foreach my $k (sort {substr($b, 0, 6) <=> substr($a, 0, 6)} keys %{$CCDATA{$cct}}) {
    my $m = $k; $m =~ s/^\d{6}//;
    my $r = $CCDATA{$cct}{$k};
    my $R = uc($r);
    $t =~ s/\Q$m\E(?=\p{Uppercase})/$R/g;
    $t =~ s/\Q$m\E/$r/g;
  }
  
  return $t;
}

sub simplecc($$$) {
  my $ccin = shift;
  my $cctable = shift;
  my $ccout = shift;
  
  &myLog("Applying CC Table: \"$ccin\" \"$cctable\" \"$ccout\"\n");
  
  if (!$CCDATA{$cctable}) {&readcc($cctable);}

  if ($ccin =~ /\.xml$/i) {
    use XML::LibXML;
    $XPC = XML::LibXML::XPathContext->new;
    $XPC->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
    $XML_PARSER = XML::LibXML->new('line_numbers' => 1);
    my $xml = $XML_PARSER->parse_file($ccin);
    
    # TODO: Add dictionary link support!

    my @was;
    if ($MOD && $sourceProject) {
      # Update OSIS file's module name
      &myLog("Converting moduleName...\n", 2);
      @was = $XPC->findnodes('//osis:osisText[@osisIDWork="'.$sourceProject.'"]/@osisIDWork', $xml);
      push(@was, $XPC->findnodes('//osis:work[@osisWork="'.$sourceProject.'"]/@osisWork', $xml));
      foreach my $wa (@was) {$wa->setValue($MOD);}
    
      # Update Scripture references
      &myLog("Converting osisRef=\"".$sourceProject.":...\n", 2);
      my @srefs = $XPC->findnodes('//*[starts-with(@osisRef, "'.$sourceProject.':")]/@osisRef', $xml);
      foreach my $wa (@srefs) {
        my $ud = $wa->getValue();
        $ud =~ s/^\Q$sourceProject:/$MOD:/;
        $wa->setValue($ud);
      }
    }
    if (!@was) {&myLog("ERROR: Did not update module name in \"$ccout\"\n");}
    
    &myLog("Reading text & attribute nodes...\n", 2);
    my @nodes = $XPC->findnodes('//text()', $xml);
    push(@nodes, $XPC->findnodes('//*[not(self::osis:div)][@n]/@n', $xml));
    &myLog("Converting text & attribute nodes...\n", 2);
    my %ndata;
    my $l=0;
    foreach my $node (@nodes) {
      $l = $node->line_number(); if (($l%1000) == 0 && !$reported_line{$l}) {&myLog("line $l ...\n", 2); $reported_line{$l}++;}
      if ($node->nodeType() == 3) { # Text nodes
        my $ud = $node->data();
        utf8::upgrade($ud);
        $node->setData(&simplecc_convert($ud, $cctable));
      }
      elsif ($node->nodeType() == 2) { # Attribute nodes
        my $ud = $node->getValue();
        utf8::upgrade($ud);
        $node->setValue(&simplecc_convert($ud, $cctable));
      }
      else {&myLog("ERROR: Unhandled node type\n");}
    }
    
    open(OUT, ">$ccout") || die;
    print OUT $xml->toString();
    close(OUT);
  }
  else {
    open(OUT, ">encoding(UTF-8)", "$ccout") || die;
    open(IN, "<encoding(UTF-8)", "$ccin") || die;
    print OUT &simplecc_convert(join('', <IN>), $cctable);
    close(IN);
    close(OUT);
  }
}

sub readcc($) {
  my $cctable = shift;
  
  open (CC, "<encoding(UTF-8)", "$cctable") || die;
  while(<CC>) {
    if ($_ =~ /^(c|begin|store)/ || $_ =~ /^\s*$/) {next;}
    elsif (/^\s*["'](.*?)["']\s*>\s*["'](.*?)["']\s*(c\s+|$)/) {$CCDATA{$cctable}{sprintf("%06i%s", $., $1)} = $2;}
    else {print "Unhandled line: $_\n";}
  }
  close(CC);
}

1;
