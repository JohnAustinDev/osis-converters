sub aggregateRepeatedEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  &Log("\n\nOrdering glossary divs according to scope in OSIS file \"$osis\".\n");
  my @gdivs = $XPC->findnodes('//osis:div[@type="glossary"]', $xml);
  my $parent = @gdivs[0]->parentNode();
  foreach my $gdiv (@gdivs) {$gdiv->unbindNode();}
  foreach my $gdiv (sort sortGlossaryDivsByScope @gdivs) {$parent->appendChild($gdiv);}
  
  &Log("\nAggregating duplicate keywords in OSIS file \"$osis\".\n\n");
  
  # Find any duplicate entries (case insensitive)
  my @keys = $XPC->findnodes('//osis:seg[@type="keyword"]', $xml);
  my %entries, %duplicates;
  foreach my $k (@keys) {
    my $uck = uc($k->textContent);
    if (!defined($entries{$uck})) {$entries{$uck} = $k;}
    else {
      if (!defined($duplicates{$uck})) {
        push(@{$duplicates{$uck}}, $entries{$uck});
      }
      push(@{$duplicates{$uck}}, $k);
    }
  }
  
  my $count = scalar keys %duplicates;
  if ($count) {
    # create new glossary div to contain all aggregated entries
    my $glossDiv = @{$XPC->findnodes('//osis:div[@type="glossary"]', $xml)}[0]->cloneNode(0);
    $glossDiv->setAttribute('subType', 'x-aggregate');
    @{$XPC->findnodes('//osis:osisText', $xml)}[0]->appendChild($glossDiv);
    
    # cycle through each entry text that has duplicates
    foreach my $uck (keys %duplicates) {
      my $haveKey = 0;
      my $n = 1;
      
      # cycle through each duplicate keyword element
      my @prevGlos;
      foreach my $dk (@{$duplicates{$uck}}) {
        # create new x-duplicate div to mark this duplicate entry
        my $xDupDiv = @{$XPC->findnodes('//osis:div[@type="glossary"]', $xml)}[0]->cloneNode(0);
        $xDupDiv->setAttribute('type', 'x-duplicate-keyword');
        
        # get entry's elements, and read glossary title: $title is first <title type="main">
        my @entry;
        my @titleElem = $XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]/descendant::osis:title[@type="main"][1]', $dk);
        my $title = (@titleElem ? "<lb/>$n) " . @titleElem[0]->textContent . "<lb/>":'');
        my $myGlossary = @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"]', $dk)}[0];
        if (@prevGlos) {foreach my $pg (@prevGlos) {if ($pg->isEqual($myGlossary)) {&Log("WARNING: duplicate keywords within same glossary div: ".$dk->textContent()."\n");}}}
        push (@prevGlos, $myGlossary);
        
        # top element is self or else highest ancestor which contains no other keywords
        my $top = $dk;
        while (@{$XPC->findnodes('./descendant::osis:seg[@type="keyword"]', $top->parentNode())} == 1) {$top = $top->parentNode();}
        push(@entry, $top);
        my @elements = $XPC->findnodes('./following::node()', $top);
        foreach my $e (@elements) {
          # stop on first element that is, or contains, the next keyword, or is not part of the keyword's glossary div
          my @keyword = $XPC->findnodes('./descendant-or-self::osis:seg[@type="keyword"]', $e);
          if (@keyword && !@keyword[0]->isEqual($dk)) {last;}
          my $p = $e->parentNode();
          while ($p && !$p->isEqual($myGlossary)) {$p = $p->parentNode();}
          if (!$p) {last;}
          push(@entry, $e);
        }
        
        # move entry inside x-duplicate div
        $top->parentNode()->insertBefore($xDupDiv, $top);
        foreach my $e (@entry) {$xDupDiv->appendChild($e);}
        
        # peel off any initial container elements from the entry list (these needn't be aggregated)
        if (!@entry[0]->isEqual($dk)) {
          my @descendants = $XPC->findnodes('./descendant::node()', @entry[0]);
          my $x = 0;
          while ($x < @descendants) {
            if (@descendants[$x]->isEqual($dk)) {last;}
            $x++;
          }
          splice(@entry, 0, 1, @descendants[$x..$#descendants]);
        }
        
        # copy and aggregate entry into new glossary div
        foreach my $e (@entry) {
          my $agg = $e->cloneNode(1);
          if ($e->isEqual($dk)) {
            if (!$haveKey) {
              $haveKey = $agg;
              $glossDiv->appendChild($agg);
            }
            $glossDiv->appendChild($XML_PARSER->parse_balanced_chunk($title));
          }
          else {$glossDiv->appendChild($agg);}
        }
        
        $n++;
      }
    }
 
    open(OUTF, ">$osis");
    use XML::LibXML::PrettyPrint;
    XML::LibXML::PrettyPrint->new(
      indent_string => "  ", 
      element => {
        inline   => [qw/hi title header index/],
        block    => [qw/div/],
        compact  => [qw/seg/]
        #preserves_whitespace => [qw/pre script style/],
      }
    )->pretty_print($xml);
    print OUTF $xml->toString();
    close(OUTF);
    
    &Log("REPORT: $count instance(s) of duplicate keywords were found and aggregated:\n");
    foreach my $uck (keys %duplicates) {&Log("$uck\n");}
  }
  else {&Log("REPORT: Entry aggregation isn't needed, all keywords are unique (using case insensitive keyword comparison).\n");}
}

sub getGlossaryScope($) {
  my $e = shift;

  my @glossDiv = $XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]', $e);
  if (!@glossDiv) {return '';}
  my @comment = $XPC->findnodes('./descendant::comment()[1]', @glossDiv[0]);
  if (!@comment) {return '';}
  my $scope = @comment[0]->textContent();
  if ($scope !~ s/^.*?\bscope\s*==\s*(.*?)\s*$/$1/) {return '';}
  return $scope;
}

sub sortGlossaryDivsByScope($$) {
  my $a = shift;
  my $b = shift;
  
  $a = &getGlossaryScope($a); $a =~ s/^([^\.\-]+).*?$/$1/;
  $b = &getGlossaryScope($b); $b =~ s/^([^\.\-]+).*?$/$1/;
  
  my $bookOrderP;
  &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
  $a = ($a && defined($bookOrderP->{$a}) ? $bookOrderP->{$a}:0);
  $b = ($b && defined($bookOrderP->{$b}) ? $bookOrderP->{$b}:0);
  
  return $a <=> $b;
}

# Returns number of filtered divs, or else -1 if all were filtered
sub filterGlossaryToScope($$) {
  my $osis = shift;
  my $scope = shift;
  
  my @removed;
  my @kept;
  
  if ($scope) {
    my $xml = $XML_PARSER->parse_file($osis);
    my @glossDivs = $XPC->findnodes('//osis:div[@type="glossary"][not(@subType="x-aggregate")]', $xml);
    GLOSSLOOP: foreach my $div (@glossDivs) {
      my $divScope = &getGlossaryScope($div);
      
      # keep all glossary divs that don't specify a particular scope
      if (!$divScope) {push(@kept, $divScope); next;}
    
      # keep if any book within the glossary scope matches $scope
      my $bookOrderP; &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
      my $divScopeBookP = &scopeToBooks($divScope, $bookOrderP);
      foreach my $bk (@{$divScopeBookP}) { 
        if (!&myContext($scope, $bk)) {next;}
        push(@kept, $divScope);
        next GLOSSLOOP;
      }
      
      $div->unbindNode();
      push(@removed, $divScope);
    }

    if (@removed == @glossDivs) {return -1;}
    
    &Log("REPORT: Removed ".@removed." of ".@glossDivs." instance(s) of glossary divs outside the scope: $scope (kept: ".join(' ', @kept).", removed: ".join(' ', @removed).")\n");
    
    open(OUTF, ">$osis");
    print OUTF $xml->toString();
    close(OUTF);
  }
  
  &removeAggregateEntries($osis);
  
  return @removed;
}

sub removeDuplicateEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @dels = $XPC->findnodes('//osis:div[@type="x-duplicate-keyword"]', $xml);
  foreach my $del (@dels) {$del->unbindNode();}
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &Log("REPORT: ".@dels." instance(s) of x-duplicate-keyword div removal.\n");
}

sub removeAggregateEntries($) {
  my $osis = shift;

  my $xml = $XML_PARSER->parse_file($osis);
  my @dels = $XPC->findnodes('//osis:div[@type="glossary"][@subType="x-aggregate"]', $xml);
  foreach my $del (@dels) {$del->unbindNode();}
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

1;
