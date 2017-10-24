sub aggregateRepeatedEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  foreach my $report (@{$XPC->findnodes('//osis:div[@type and not(ancestor-or-self::osis:div[@type="glossary"])]', $xml)}) {
    &Log("\nWARNING: The div with type=\"".$report->getAttribute('type')."\" will NOT appear in the SWORD glossary module, because only \"\\id GLO\" type USFM files will appear in the SWORD glossary module.\n");
  }
  
  &Log("\n\nDetecting and applying glossary scopes to OSIS file \"$osis\".\n");
  my @gdivs = $XPC->findnodes('//osis:div[@type="glossary"]', $xml);
  foreach my $gdiv (@gdivs) {
    # look for special comment indicating the glossary osisRef
    my @comment = $XPC->findnodes('./descendant::comment()[1]', $gdiv);
    if (@comment && !$gdiv->getAttribute('osisRef')) {
      my $scope = @comment[0]->textContent();
      # only a single scope can be set in glossaries
      my $c = () = $scope =~ /==/g;
      if ($scope =~ s/^.*?\bscope\s*==\s*(.*?)\s*$/$1/) {
        $gdiv->setAttribute('osisRef', $scope);
        $c--;
      }
      if ($c) {&Log("ERROR: Only a single \"scope == <value>\" can be specified for an OSIS glossary div!\n");}
    }
  }
  
  &Log("\nAggregating duplicate keywords in OSIS file \"$osis\".\n\n");
  
  # Find any duplicate entries (case insensitive)
  my @keys = $XPC->findnodes('//osis:div[@type="glossary"]//osis:seg[@type="keyword"]', $xml);
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
      
      # show glossary titles only if all glossaries have titles to show. Title is first <title type="main">
      my %glossaryTitles;
      my $titles = 1;
      my $n = 1;
      foreach my $dk (sort sortSubEntriesByScope @{$duplicates{$uck}}) {
        my @titleElem = $XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]/descendant::osis:title[@type="main"][1]', $dk);
        my $title = (@titleElem && @titleElem[0] ? "<title level=\"2\">$n) " . @titleElem[0]->textContent . "</title>":'');
        if ($title) {$glossaryTitles{$dk->unique_key} = $title;}
        else {
          $titles = 0;
          break;
        }
        $n++;
      }
      
      # cycle through each duplicate keyword element
      my $haveKey = 0;
      my $n = 1;
      my @prevGlos;
      foreach my $dk (sort sortSubEntriesByScope @{$duplicates{$uck}}) {
        # create new x-duplicate div to mark this duplicate entry
        my $xDupDiv = &createDiv($xml);
        $xDupDiv->setAttribute('type', 'x-duplicate-keyword'); # holds entries whose keyword is not unique
        my $glossScope = &getGlossaryScope($dk); # save this before dk might be cloned/edited
        
        # get glossary
        my $myGlossary = @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"]', $dk)}[0];
        if (@prevGlos) {foreach my $pg (@prevGlos) {if ($pg->isEqual($myGlossary)) {&Log("WARNING: duplicate keywords within same glossary div: ".$dk->textContent()."\n");}}}
        push (@prevGlos, $myGlossary);
        
        # Next, move the entry into the x-duplicate div. IMPORTANT: This method assumes this 
        # keyword's "top" element and the following keyword's "top" element ("top" being 
        # the highest ancestor containing no other keywords, or else self) are siblings 
        # of each another. If this is not true (due to inconsistent keyword hierarchy) an ERROR
        # is generated because it's possible some text between keywrods could be lost.
        
        # topfirst and toplast elements may need replication if their content is split between two keywords
        my $topFirst = $dk; # topFirst element is the highest ancestor which contains no other keywords, or else self if there isn't such an ancestor 
        while (@{$XPC->findnodes('./descendant::osis:seg[@type="keyword"]', $topFirst->parentNode())} == 1) {$topFirst = $topFirst->parentNode();}
        $topFirst = &replicateIfMultiContent($topFirst, 1);
        my @newSiblings;
        push(@newSiblings, $topFirst);
        my @topSiblings = $XPC->findnodes('./following-sibling::node()', $topFirst);
        foreach my $sibling (@topSiblings) {
          # stop on first sibling that is, or contains, the next keyword
          my @kwchild = $XPC->findnodes('./descendant-or-self::osis:seg[@type="keyword"]', $sibling);
          if (@kwchild > 1) {
            &Log("ERROR aggregateRepeatedEntries: Inconsistent keyword hierarchy between \"$topFirst\" and \"$sibling\" some text between them may have been LOST!\n");
          }
          if (@kwchild && !@kwchild[0]->isEqual($dk)) {
            my $topLast = &replicateIfMultiContent($sibling, 0);
            if ($topLast) {push(@newSiblings, $topLast);}
            last;
          }
          push(@newSiblings, $sibling);
        }
        $topFirst->parentNode()->insertBefore($xDupDiv, $topFirst);
        foreach my $sibling (@newSiblings) {$xDupDiv->appendChild($sibling);}
        
        # copy xDupDiv content plus title (and minus the initial keyword element, instead prepending it once) to the subType='x-aggregate' glossary
        my $xAggDiv = $xDupDiv->cloneNode(1);
        $xAggDiv->setAttribute('type', 'x-aggregate-subentry'); # holds individual entries within an aggregate entry
        if ($glossScope) {$xAggDiv->setAttribute('osisRef', $glossScope);}
        if ($titles) {$xAggDiv->insertBefore($XML_PARSER->parse_balanced_chunk($glossaryTitles{$dk->unique_key}), $xAggDiv->firstChild);}
        my @kw = $XPC->findnodes('./descendant::osis:seg[@type="keyword"]', $xAggDiv);
        if (@kw && @kw[0] && @kw == 1) {
          # remove keyword and any resultant empty ancestors
          my $p = @kw[0]; do {my $nx = $p->parentNode; $p->unbindNode(); $p = $nx;} while ($p && $p->textContent =~ /^[\s\n]*$/);
          if (!$haveKey) {
            $haveKey = 1;
            $glossDiv->appendChild(@kw[0]);
          }
        }
        else {
          &Log("ERROR aggregateRepeatedEntries: keyword aggregation failed.\n");
        }
        if (!$titles) {
          my @par = $XPC->findnodes('*[1]', $xAggDiv);
          if (@par && @par[0]) {
            @par[0]->insertBefore($XML_PARSER->parse_balanced_chunk('<hi type="super"><hi type="bold">'.$n.') </hi></hi>'), @par[0]->firstChild);
          }
        }
        $glossDiv->appendChild($xAggDiv);
        
        $n++;
      }
    }
    
    &Log("$MOD REPORT: $count instance(s) of duplicate keywords were found and aggregated:\n");
    foreach my $uck (keys %duplicates) {&Log("$uck\n");}
  }
  else {&Log("$MOD REPORT: 0 instance(s) of duplicate keywords. Entry aggregation isn't needed (according to case insensitive keyword comparison).\n");}

  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

# If element is an element which contains text belonging to two 
# keywords, then clone a previous-sibling element and remove from each  
# sibling any text not associated with that particular sibling's 
# relavent keyword. If isFirst is true, then return the (possibly 
# modified) element, otherwise return the clone, which will be empty if 
# no cloning was necessary.
sub replicateIfMultiContent($$) {
  my $element = shift;
  my $isFirst = shift;
  
  my $clone = $element->cloneNode(1);
  if (&keywordAncestorStrip($clone, 0)) {
    &keywordAncestorStrip($element, 1);
    $element->parentNode()->insertBefore($clone, $element);
  }
  else {$clone = '';}
  
  return ($isFirst ? $element:$clone);
}

# Strips text and resulting empty elements either before or after (and also 
# including) keyword. Returns number of modifications made.
sub keywordAncestorStrip($$) {
  my $keywordAncestor = shift;
  my $stripBefore = shift;
  
  my $modsMade = 0;
  
  my $isBefore = 1;
  my @textNodes = $XPC->findnodes('./descendant::text()', $keywordAncestor);
  foreach my $textNode (@textNodes) {
    my @kw = $XPC->findnodes('./ancestor::osis:seg[@type="keyword"]', $textNode);
    if ($isBefore && $stripBefore || !$isBefore && !$stripBefore || $isBefore && @kw && @kw[0]) {
      $textNode->unbindNode(); $modsMade++;
    }
    if (@kw && @kw[0]) {$isBefore = 0;}
  }
  
  $isBefore = 1;
  my @elements = $XPC->findnodes('./descendant::*', $keywordAncestor);
  foreach my $element (@elements) {
    my @kw = $XPC->findnodes('self::osis:seg[@type="keyword"]', $element);
    if ($isBefore && $stripBefore || !$isBefore && !$stripBefore || $isBefore && @kw && @kw[0]) {
      if ($element->textContent =~ /^[\s\n]*$/) {
        $element->unbindNode(); $modsMade++;
      }
    }
    if (@kw && @kw[0]) {$isBefore = 0;}
  }
  
  return $modsNade;
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

# Returns names of filtered divs, or else '-1' if all were filtered or '0' if none were filtered
sub filterGlossaryToScope($$) {
  my $osis = shift;
  my $scope = shift;
  
  my @removed;
  my @kept;
  
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

  if (@removed == @glossDivs) {return '-1';}
  
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &removeAggregateEntries($osis);
  
  return (@removed ? join(',', @removed):'0');
}

sub removeDuplicateEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @dels = $XPC->findnodes('//osis:div[@type="x-duplicate-keyword"]', $xml);
  foreach my $del (@dels) {$del->unbindNode();}
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &Log("$MOD REPORT: ".@dels." instance(s) of x-duplicate-keyword div removal.\n");
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
  
  USE THE FOLLOWING BOOLEAN & NON-BOOLEAN ATTRIBUTES TO CONTROL LINK PLACEMENT:
  
  Boolean:
  IMPORTANT: default is false for boolean attributes
  onlyNewTestament=\"true|false\"
  onlyOldTestament=\"true|false\"
  dontLink=\"true|false\" to specify matched text should NOT get linked to the entry
  multiple=\"true|false\" to allow more than one identical link per entry or chapter
  notExplicit=\"true|false\" selects if match(es) should NOT be applied to explicitly marked glossary entries in the text
  onlyExplicit=\"true|false\" selects if match(es) should only be applied to explicitly marked glossary entries in the text
  
  Non-Boolean:
  IMPORTANT: non-boolean attribute values are CUMULATIVE, so if the same 
  attribute appears in multiple ancestors, each ancestor value is 
  accumalated. Also, 'context' and 'XPATH' attributes CANCEL the effect   
  of ancestor 'notContext' and 'notXPATH' attributes respectively.
  
  context=\"space separated list of osisRefs or comma separated list of Paratext refs\" in which to create links
  notContext=\"space separated list of osisRefs or comma separated list of Paratext refs\" in which not to create links
  XPATH=\"xpath expression\" to be applied on each text node to keep text nodes that return non-null
  notXPATH=\"xpath expression\" to be applied on each text node to skip text nodes that return non-null

  ENTRY ELEMENTS MAY CONTAIN THE FOLLOWING ATTRIBUTES:
  <entry osisRef=\"osisRef location(s) of this entry's source target(s)\"
         noOutboundLinks=\"true|false: set true if entry should not contain any see-also links\">

  Match patterns can be any perl match regex. The last matching 
  parenthetical group, or else a group named 'link' with (?'link'...), 
  will become the link's inner text.

-->\n";
}

sub writeDefaultDictionaryWordsXML($) {
  my $in_file = shift; # could be osis or imp
  
  my $osis = ($in_file =~ /\.(xml|osis)$/i ? $XML_PARSER->parse_file($in_file):'');
  my @osisKW = ($osis ? $XPC->findnodes('//osis:seg[@type="keyword"][ancestor::osis:div[@type="glossary"]][not(ancestor::osis:div[@subType="x-aggregate"])]', $osis):'');
  
  # read keywords. For OSIS files, ignore those marked x-duplicate-keyword (but keep aggregate keywords)
  my @keywords = &getDictKeys($in_file, './ancestor::osis:div[@type="x-duplicate-keyword"]');
  my %keys;
  foreach my $k (@keywords) {
    if ($osis) {
      # get a list of this keyword's context values (this keyword may appear multiple times with different context each time)
      my @c;
      foreach my $kw (@osisKW) {
        if (uc($kw->textContent()) ne uc($k)) {next;}
        my $gScope = &getGlossaryScope($kw);
        if (!$gScope) {@c = (); last;} # if any keyword has no context, consider this keyword global
        push(@c, $gScope);
      }
      $keys{$k} = join(' ', @c);
    }
    else {$keys{$k} = '';}
  }
  
  if (!open(DWORDS, ">:encoding(UTF-8)", $DEFAULT_DICTIONARY_WORDS)) {&Log("ERROR: Could not open $DEFAULT_DICTIONARY_WORDS"); die;}
  print DWORDS &dictWordsHeader();
  print DWORDS "
<dictionaryWords version=\"1.0\" xmlns=\"$DICTIONARY_WORDS_NAMESPACE\">
<div multiple=\"false\" notXPATH=\"$DICTIONARY_NotXPATH_Default\">\n";
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
# and all the OSIS file's keywords are unique according to a case-sensitive comparison,
# (which occurs when converting from DictionaryWords.txt to DictionaryWords.xml)
# then fix these, and update the dictionaryWords file.
sub compareToDictionaryWordsXML($) {
  my $imp_or_osis = shift;
  
  my $dw_file = "$INPD/$DICTIONARY_WORDS";
  &Log("\n--- CHECKING ENTRIES IN: $imp_or_osis FOR INCLUSION IN: $DICTIONARY_WORDS\n", 1);
  
  my $update = 0;
  
  my @sourceEntries = &getDictKeys($imp_or_osis);
  
  my $allowUpdate = 1; my %noCaseKeys;
  foreach my $es (@sourceEntries) {
    if ($noCaseKeys{lc($es)}) {
      &Log("NOTE: Will not update case-only discrepancies in $DICTIONARY_WORDS.\n");
      $allowUpdate = 0;
      last;
    }
    $noCaseKeys{lc($es)}++;
  }
  
  my @dwfEntries = $XPC->findnodes('//dw:entry[@osisRef]/@osisRef', $DWF);
  
  my $allmatch = 1; my $mod;
  foreach my $es (@sourceEntries) {
    my $match = 0;
    foreach my  $edr (@dwfEntries) {
      my $ed = &osisRef2Entry($edr->value, \$mod);
      if ($es eq $ed) {$match = 1; last;}
      elsif ($allowUpdate && &uc2($es) eq &uc2($ed)) {
        $match = 1;
        $update++;
        $edr->setValue(entry2osisRef($mod, $es));
        my $name = @{$XPC->findnodes('../child::dw:name[1]/text()', $edr)}[0];
        if (&uc2($name) ne &uc2($es)) {&Log("ERROR: \"$name\" does not correspond to \"$es\" in osisRef \"$edr\" of $DICTIONARY_WORDS\n");}
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
    
    &loadDictionaryWordsXML();
  }
  
  if ($allmatch) {&Log("All entries are included.\n");}
  
}

sub getDictKeys($$) {
  my $in_file = shift;
  my $skip = shift;
  
  my @keywords;
  if ($in_file =~ /\.(xml|osis)$/i) {
    my $xml = $XML_PARSER->parse_file($in_file);
    my @keys = $XPC->findnodes('//osis:seg[@type="keyword"][ancestor::osis:div[@type="glossary"]]', $xml);
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
  &Log("\n$MOD REPORT: Glossary entry names which are repeated in other entry names: ($total instances)\n");
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
      my @elems = $XPC->findnodes('//dw:entry[child::dw:name[text()="' . $i . '"]]', $DWF);
      foreach my $elem (@elems) {
        if (@{$XPC->findnodes('./dw:match', $elem)} != 1) {$skip = 1;}
      }
    }
    if (!$skip) {$p .= $i."\n"; $total += $instances{$i};}
  }
  &Log("\n$MOD REPORT: Compound glossary entry names with a single match element: ($total instances)\n");
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

sub writeEntryOsisIDs($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  &Log("\n\nWriting glossary osisID's to OSIS file \"$osis\".\n");
  
  my %osisIDS;
  my @kws = $XPC->findnodes('//osis:seg[@type="keyword"]', $xml);
  foreach $kw (@kws) {
    my $suf = '';
    if (@{$XPC->findnodes('ancestor::osis:div[@type="x-duplicate-keyword"]', $kw)}) {
      $suf = ".part1";
    }
    my $osisID = &encodeOsisRef($kw->textContent) . $suf;
    if ($osisIDS{$osisID}) {
      if ($osisID =~ /^(.*?\.part)(\d+)$/) {
        my $id = $1; my $n = $2;
        do {$n++} while ($osisIDS{$id.$n});
        $osisID = $id.$n;
      }
      else {&log("ERROR writeEntryOsisIDs: Duplicate osisID \"$osisID\"!\n");}
    }
    $kw->setAttribute("osisID", $osisID);
    $osisIDS{$osisID}++;
  }

  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

1;
