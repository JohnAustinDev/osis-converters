sub aggregateRepeatedEntries($) {
  my $osis = shift;
  
  &Log("\n\nAggregating duplicate keywords in glosary OSIS file \"$osis\".\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @keys = $XPC->findnodes('//osis:seg[@type="keyword"]', $xml);
  
  # Find any duplicate entries (case insensitive)
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
      foreach my $dk (sort sortKeywordElementsByBook @{$duplicates{$uck}}) {
        # create new x-duplicate div to mark this duplicate entry
        my $xDupDiv = @{$XPC->findnodes('//osis:div[@type="glossary"]', $xml)}[0]->cloneNode(0);
        $xDupDiv->setAttribute('type', 'x-duplicate-keyword');
        
        # get entry's elements and metadata
        my @entry;
        my @titleElem = $XPC->findnodes('./parent::osis:div[@type="glossary"]/following::osis:title[1]', $dk);
        my $title = (@titleElem ? ' (' . @titleElem[0]->textContent . ')':'');
        my $context = &getGlossaryContext($dk);
        my $myGlossary = @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"]', $dk)}[0];
        
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
            $glossDiv->appendChild($XML_PARSER->parse_balanced_chunk("<lb/>$n)$title: "));
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
  else {&Log("REPORT: Entry aggregation isn't needed, all keywords are unique (case insensitive keyword comparison).\n");}
}

sub getGlossaryContext($) {
  my $dk = shift;
  my @contextAttr = $XPC->findnodes('./parent::osis:div[@type="glossary"]/@context', $dk);
  return (@contextAttr ? @contextAttr[0]->getValue():'');
}

sub sortKeywordElementsByBook($$) {
  my $a = shift;
  my $b = shift;
  
  $a = &getGlossaryContext($a); $a =~ s/^([^\.\-]+).*?$/$1/;
  $b = &getGlossaryContext($b); $b =~ s/^([^\.\-]+).*?$/$1/;
  
  my $bookOrderP;
  &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
  $a = ($a && defined($bookOrderP->{$a}) ? $bookOrderP->{$a}:0);
  $b = ($b && defined($bookOrderP->{$b}) ? $bookOrderP->{$b}:0);
  
  return $a <=> $b;
}

sub filterGlossaryToScope($$) {
  my $osis = shift;
  my $scope = shift;
  
  if ($scope) {
    my $xml = $XML_PARSER->parse_file($osis);
    my @gloss = $XPC->findnodes('//osis:div[@type="glossary"]', $xml);
    my $success = 0;
    my @removed;
    foreach my $glos (@gloss) {
      if (!$glos->hasAttribute('context') || &myContext($scope, $glos->getAttribute('context'))) {
        $success = 1;
        next;
      }
      $glos->unbindNode();
      push(@removed, $glos->getAttribute('context'));
    }
    
    &Log("REPORT: ".@removed." instance(s) of glossary divs which didn't match scope \"$scope\"".(@removed ? ':':'.')."\n");
    foreach my $r (@removed) {&Log("<div type='glossary' scope='$r'>\n");}

    if (!$success) {return 0;}
    
    open(OUTF, ">$osis");
    print OUTF $xml->toString();
    close(OUTF);
  }
  
  &removeAggregateEntries($osis);
  
  return 1;
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
  
  &Log("REPORT: ".@dels." instance(s) of aggregate glossary div removal.\n");
}

1;
