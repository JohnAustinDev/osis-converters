sub aggregateRepeatedEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  &Log("\n\nDetecting and applying glossary scopes to OSIS file \"$osis\".\n");
  my @gdivs = $XPC->findnodes('//osis:div[@type="glossary"]', $xml);
  foreach my $gdiv (@gdivs) {
    # look for special comment indicating the glossary osisRef
    my @comment = $XPC->findnodes('./descendant::comment()[1]', $gdiv);
    if (@comment && !$gdiv->getAttribute('osisRef')) {
      my $scope = @comment[0]->textContent();
      if ($scope =~ s/^.*?\bscope\s*==\s*(.*?)\s*$/$1/) {
        $gdiv->setAttribute('osisRef', $scope);
      }
    }
  }
  
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
    my $glossDiv = &createDiv($xml);
    $glossDiv->setAttribute('subType', 'x-aggregate');
    @{$XPC->findnodes('//osis:osisText', $xml)}[0]->appendChild($glossDiv);
    
    # cycle through each entry text that has duplicates
    foreach my $uck (keys %duplicates) {
      my $haveKey = 0;
      my $n = 1;
      
      # cycle through each duplicate keyword element
      my @prevGlos;
      foreach my $dk (sort sortSubEntriesByScope @{$duplicates{$uck}}) {
        # create new x-duplicate div to mark this duplicate entry
        my $xDupDiv = &createDiv($xml);
        $xDupDiv->setAttribute('type', 'x-duplicate-keyword'); # holds entries without unique keyword textContent
        my $xAggDiv = &createDiv($xml);
        $xAggDiv->setAttribute('type', 'x-aggregate-subentry'); # holds individual entries within an aggregate entry
        my $glossScope = &getGlossaryScope($dk);
        if ($glossScope) {$xAggDiv->setAttribute('osisRef', $glossScope);}
        
        # get entry's elements, and read glossary title: $title is first <title type="main">
        my @entry;
        my @titleElem = $XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]/descendant::osis:title[@type="main"][1]', $dk);
        my $title = "<title level=\"2\">$n) " . (@titleElem ? @titleElem[0]->textContent:'') . "</title>";
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
            $xAggDiv->appendChild($XML_PARSER->parse_balanced_chunk($title));
          }
          else {$xAggDiv->appendChild($agg);}
        }
        $glossDiv->appendChild($xAggDiv);
        
        $n++;
      }
    }
    
    &Log("REPORT: $count instance(s) of duplicate keywords were found and aggregated:\n");
    foreach my $uck (keys %duplicates) {&Log("$uck\n");}
  }
  else {&Log("REPORT: 0 instance(s) of duplicate keywords. Entry aggregation isn't needed (according to case insensitive keyword comparison).\n");}

  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

sub getEntryScope($) {
  my $e = shift;

  my @eDiv = $XPC->findnodes('./ancestor-or-self::osis:div[@type="x-aggregate-subentry"]', $e);
  if (@eDiv && @eDiv[0]->getAttribute('osisRef')) {return @eDiv[0]->getAttribute('osisRef');}
  
  return &getGlossaryScope($e);
}

sub getGlossaryScope($) {
  my $e = shift;

  my @glossDiv = $XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]', $e);
  if (!@glossDiv) {return '';}

  return @glossDiv[0]->getAttribute('osisRef');
}

sub sortSubEntriesByScope($$) {
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
  
  if (!$scope) {$scope = 'Gen-Rev';} # This means any non Bible scopes (like SWORD) are filtered out 
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @glossDivs = $XPC->findnodes('//osis:div[@type="glossary"][not(@subType="x-aggregate")]', $xml);
  foreach my $div (@glossDivs) {
    my $divScope = &getGlossaryScope($div);
    
    # keep all glossary divs that don't specify a particular scope
    if (!$divScope) {push(@kept, $divScope); next;}
  
    # keep if any book within the glossary scope matches $scope
    my $bookOrderP; &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
    if (&myGlossaryContext($scope, &scopeToBooks($divScope, $bookOrderP))) {
      push(@kept, $divScope);
      next;
    }
    
    $div->unbindNode();
    push(@removed, $divScope);
  }

    if (@removed == @glossDivs) {return -1;}
    
    &Log("REPORT: Removed ".@removed." of ".@glossDivs." instance(s) of glossary divs outside the scope: $scope (kept: ".join(' ', @kept).", removed: ".join(' ', @removed).")\n");
    
    open(OUTF, ">$osis");
    print OUTF $xml->toString();
    close(OUTF);
  
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

sub dictWordsHeader() {
  return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!--
  IMPORTANT: 
  For case insensitive matches using /match/i to work, ALL text MUST be surrounded 
  by the \\Q...\\E quote operators. If a match is failing, consider this first!
  This is not a normal Perl rule, but is required because Perl doesn't properly handle case for Turkish-like languages.
  
  Use the following attributes to control link placement:
  onlyNewTestament=\"true|false\"
  onlyOldTestament=\"true|false\"
  context=\"space separated list of osisRefs, or osisRef-encoded dictionary entries in which to create links (default is all)\"
  notContext=\"space separated list of osisRefs, or osisRef-encoded dictionary entries in which not to create links (default is none)\"
  highlight=\"true|false: allow links within bold, italic or other highlighted text (default is false)\"
  multiple=\"true|false: allow more than one identical link per entry or chapter (default is false)\"

  Entry elements may contain the following attributes:
  <entry osisRef=\"osisRef location(s) of this entry's source target(s)\"
         noOutboundLinks=\"true|false: set true if entry should not contain any see-also links\">

  Match patterns can be any perl match regex. The entire match (if there 
  are no capture groups), or the last matching group, or else a group 
  named 'link', will become the link's inner text.

-->\n";
}

sub loadDictionaryWordsXML($) {
  my $defaultDWF = shift;
  
  # if there is no project dictionary words file, then create it
  if (! -e "$INPD/$DICTIONARY_WORDS") {copy($defaultDWF, "$INPD/$DICTIONARY_WORDS");}
  $DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # if companion has no dictionary words file, then create it too
  foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
    if (!-e "$INPD/../../$companion") {
      &Log("WARNING: Companion project \"$companion\" of \"$MOD\" could not be located to copy $DICTIONARY_WORDS.\n");
      next;
    }
    if (!-e "$INPD/../../$companion/$DICTIONARY_WORDS") {copy ($defaultDWF, "$INPD/../../$companion/$DICTIONARY_WORDS");}
  }
}

sub writeDefaultDictionaryWordsXML($$) {
  my $in_file = shift; # could be osis or imp
  my $defaultDWF = shift;
  
  my $osis = ($in_file =~ /\.(xml|osis)$/i ? $XML_PARSER->parse_file($in_file):'');
  my @osisKW = ($osis ? $XPC->findnodes('//osis:seg[@type="keyword"][not(ancestor::osis:div[@subType="x-aggregate"])]', $osis):'');
  
  # read keywords. For OSIS files, ignore those marked x-duplicate-keyword (but keep aggregate keywords)
  my @keywords = &getDictKeys($in_file, './ancestor::osis:div[@type="x-duplicate-keyword"]');
  my %keys;
  foreach my $k (@keywords) {
    if ($osis) {
      my @c;
      foreach my $kw (@osisKW) {
        if (uc($kw->textContent()) ne uc($k)) {next;}
        my $gScope = &getGlossaryScope($kw);
        if (!$gScope) {@c = (); last;} # if any keyword has no context, consider this keyword global
        push(@c, $gScope);
      }
      if (@c) {$keys{$k} = join(' ', @c);}
    }
    else {$keys{$k} = '';}
  }
  
  if (!open(DWORDS, ">:encoding(UTF-8)", $defaultDWF)) {&Log("ERROR: Could not open $defaultDWF"); die;}
  print DWORDS &dictWordsHeader();
  print DWORDS "
<dictionaryWords version=\"1.0\">
<div highlight=\"false\" multiple=\"false\">\n";
  my $divEnd;
  my $esp;
  my $currentContext;
  foreach my $k (sort {&sortDictKeys($a, $b, \%keys)} keys %keys) {
    my $contextIsSingleRange = ($keys{$k} !~ /\s+/);
    if ($keys{$k} ne $currentContext) {
      print DWORDS $divEnd;
      $divEnd = '';
      $esp = '';
      if ($contextIsSingleRange && $keys{$k}) {
        print DWORDS "
  <div context=\"".$keys{$k}."\">";
       $divEnd = "  </div>\n";
       $esp = '  ';
      }
    }
    $currentContext = $keys{$k};
    print DWORDS "
".$esp."  <entry osisRef=\"".&entry2osisRef($MOD, $k)."\">
".$esp."    <name>".$k."</name>
".$esp."    <match".(!$contextIsSingleRange && $keys{$k} ? ' context="'.$keys{$k}.'"':'').">/\\b(\\Q".$k."\\E)\\b/i</match>
".$esp."  </entry>\n";
  }
  print DWORDS $divEnd."
</div>
</dictionaryWords>";
  close(DWORDS);
  
  &checkEntryNames(\@keywords);
}

sub sortDictKeys($$) {
  my $a = shift;
  my $b = shift;
  my $kP = shift;
  
  # sort first by context, with multi-context always after single-context, then sort by length
  if ($kP->{$a} eq $kP->{$b}) {return length($b) <=> length($a);}
  
  if ($kP->{$a} =~ /\s+/ && $kP->{$b} !~ /\s+/) {return 1;}
  if ($kP->{$a} !~ /\s+/ && $kP->{$b} =~ /\s+/) {return -1;}
  if ($kP->{$a} =~ /\s+/) {return length($b) <=> length($a);}
  
  my $bookOrderP;
  &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
  $a = $kP->{$a}; $a =~ s/^([^\.\-]+).*?$/$1/;
  $b = $kP->{$b}; $b =~ s/^([^\.\-]+).*?$/$1/;
  $a = ($a && defined($bookOrderP->{$a}) ? $bookOrderP->{$a}:0);
  $b = ($b && defined($bookOrderP->{$b}) ? $bookOrderP->{$b}:0);
  return $a <=> $b;
}

# check that the entries in an imp or osis dictionary source file are included in 
# the global dictionaryWords file. If the difference is only in capitalization,
# which occurs when converting from DictionaryWords.txt to DictionaryWords.xml,
# then fix these, and update the dictionaryWords file.
sub compareToDictionaryWordsXML($) {
  my $imp_or_osis = shift;
  
  my $dw_file = "$INPD/$DICTIONARY_WORDS";
  &Log("\n--- CHECKING ENTRIES IN: $imp_or_osis FOR INCLUSION IN: $DICTIONARY_WORDS\n", 1);
  
  my $update = 0;
  
  my @sourceEntries = &getDictKeys($imp_or_osis);
  
  my @dwfEntries = $XPC->findnodes('//entry[@osisRef]/@osisRef', $DWF);
  
  my $allmatch = 1; my $mod;
  foreach my $es (@sourceEntries) {
    my $match = 0;
    foreach my  $edr (@dwfEntries) {
      my $ed = &osisRef2Entry($edr->value, \$mod);
      if ($es eq $ed) {$match = 1; last;}
      elsif (&uc2($es) eq &uc2($ed)) {
        $match = 1;
        $update++;
        $edr->setValue(entry2osisRef($mod, $es));
        my $name = @{$XPC->findnodes('../child::name[1]/text()', $edr)}[0];
        if (&uc2($name) ne &uc2($es)) {&Log("ERROR: \"$name\" does not corresponding to \"$es\" in osisRef \"$edr\" of $DICTIONARY_WORDS\n");}
        else {$name->setData($es);}
        last;
      }
    }
    if (!$match) {&Log("ERROR: Missing entry \"$es\" in $DICTIONARY_WORDS\n"); $allmatch = 0;}
  }
  
  if ($update) {
    if (!open(OUTF, ">$dw_file.tmp")) {&Log("ERROR: Could not open $DICTIONARY_WORDS.tmp\n"); die;}
    print OUTF $DWF->toString();
    close(OUTF);
    unlink($dw_file); rename("$dw_file.tmp", $dw_file);
    &Log("NOTE: Updated $update entries in $dw_file\n");
    
    $DWF = $XML_PARSER->parse_file($dw_file);
  }
  
  if ($allmatch) {&Log("All entries are included.\n");}
  
}

sub getDictKeys($$) {
  my $in_file = shift;
  my $skip = shift;
  
  my @keywords;
  if ($in_file =~ /\.(xml|osis)$/i) {
    my $xml = $XML_PARSER->parse_file($in_file);
    my @keys = $XPC->findnodes('//osis:seg[@type="keyword"]', $xml);
    foreach my $kw (@keys) {
      if ($skip && $XPC->findnodes($skip, $kw)) {next;}
      push(@keywords, $kw->textContent());
    }
  }
  else {
    open(IMPIN, "<:encoding(UTF-8)", $in_file) or die "Could not open IMP $in_file";
    while (<IMPIN>) {
      if ($_ =~ /^\$\$\$\s*(.*?)\s*$/) {push(@keywords, $1);}
    }
    close(IMPIN);
  }
  
  return @keywords;
}


# report various info about the entries in a dictionary
sub checkEntryNames(\@) {
  my $entriesP = shift;
  
  my %entries;
  foreach my $name (@$entriesP) {$entries{$name}++;}
  
  foreach my $e (keys %entries) {
    if ($entries{$e} > 1) {
      &Log("ERROR: Entry \"$e\" appears more than once. These must be merged.\n"); 
    }
  }

  my $total = 0;
  my %instances;
  foreach my $e1 (keys %entries) {
    foreach my $e2 (keys %entries) {
      if ($e1 eq $e2) {next;}
      my $euc1 = &uc2($e1);
      my $euc2 = &uc2($e2); 
      if ($euc1 =~ /\Q$euc2\E/) {
        $total++;
        $instances{"\"$e1\" contains \"$e2\"\n"}++;
      }
    }
  }
  &Log("\nREPORT: Glossary entry names which are repeated in other entry names: ($total instances)\n");
  if ($total) {
    &Log("NOTE: Usually these are intentional, but rarely may indicate some problem.\n");
    foreach my $i (sort keys %instances) {&Log($i);}
  }

  my $p = ''; my $total = 0;
  undef(%instances); my %instances;
  foreach my $e (keys %entries) {
    if ($e =~ /(-|,|;|\[|\()/) {$instances{$e}++;}
  }
  foreach my $i (sort keys %instances) {
    my $skip = 0;
    if ($DWF) {
      my @elems = $XPC->findnodes('//entry[child::name[text()="' . $i . '"]]', $DWF);
      foreach my $elem (@elems) {
        if (@{$elem->findnodes('./match')} > 1) {$skip = 1;}
      }
    }
    if (!$skip) {$p .= $i."\n"; $total += $instances{$i};}
  }
  &Log("\nREPORT: Compound glossary entry names with a single match element: ($total instances)\n");
  if ($total) {
    &Log("NOTE: Multiple <match> elements should probably be added to $DICTIONARY_WORDS\nto match each part of the compound glossary entry.\n$p");
  }
  
}

sub createDiv($) {
  my $xml = shift;
  my $div = @{$XPC->findnodes('//osis:div[@type="glossary"]', $xml)}[0]->cloneNode(0);
  $div->removeAttribute('subType');
  $div->removeAttribute('osisRef');
  return $div
}

1;
