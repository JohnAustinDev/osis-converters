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
  
  return (@removed ? join(',', @removed):'0');
}

sub removeDuplicateEntries($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @dels = $XPC->findnodes('//osis:div[contains(@type, "duplicate")]', $xml);
  foreach my $del (@dels) {$del->unbindNode();}
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  &Log("$MOD REPORT: ".@dels." instance(s) of x-keyword-duplicate div removal.\n");
}

# Returns scopes of filtered entries, or else '-1' if all were filtered or '0' if none were filtered
sub filterAggregateEntries($$) {
  my $osis = shift;
  my $scope = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @check = $XPC->findnodes('//osis:div[@type="glossary"][@subType="x-aggregate"]//osis:div[@type="x-aggregate-subentry"]', $xml);
  my $bookOrderP; &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
  
  my @removed; my $removeCount = 0;
  foreach my $subentry (@check) {
    my $osisRef = $subentry->getAttribute('osisRef');
    if ($osisRef && !&myGlossaryContext($scope, &scopeToBooks($osisRef, $bookOrderP))) {
      $subentry->unbindNode();
      my %scopes = map {$_ => 1} @removed;
      if (!$scopes{$osisRef}) {push(@removed, $osisRef);}
      $removeCount++;
    }
  }
    
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
  
  if ($removeCount == scalar(@check)) {&removeAggregateEntries($osis);}
  
  return ($removeCount == scalar(@check) ? '-1':(@removed ? join(',', @removed):'0'));
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

# check that the entries in an osis dictionary source file are included in 
# the global dictionaryWords file. If the difference is only in capitalization,
# and all the OSIS file's keywords are unique according to a case-sensitive comparison,
# (which occurs when converting from DictionaryWords.txt to DictionaryWords.xml)
# then fix these, and update the dictionaryWords file.
sub compareToDictionaryWordsXML($) {
  my $in_osis = shift;
  
  my $dw_file = "$INPD/$DICTIONARY_WORDS";
  &Log("\n--- CHECKING ENTRIES IN: $in_osis FOR INCLUSION IN: $DICTIONARY_WORDS\n", 1);
  
  my $update = 0;
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  my $osismod = &getOsisRefWork($osis);
  
  my $allowUpdate = 1; my %noCaseKeys;
  foreach my $es ($XPC->findnodes('//osis:seg[@type="keyword"]/text()', $osis)) {
    if ($noCaseKeys{lc($es)}) {
      &Log("NOTE: Will not update case-only discrepancies in $DICTIONARY_WORDS.\n");
      $allowUpdate = 0;
      last;
    }
    $noCaseKeys{lc($es)}++;
  }

  my $allmatch = 1;
  foreach my $osisIDa ($XPC->findnodes('//osis:seg[@type="keyword"][not(ancestor::osis:div[@subType="x-aggregate"])]/@osisID', $osis)) {
    if (!$osisIDa) {next;}
    my $osisID = $osisIDa->value;
    my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
    
    my $match = 0;
    foreach my $osisRefa ($XPC->findnodes('//dw:entry/@osisRef', $DWF)) {
      if (!$osisRefa) {next;}
      my $osisRef = $osisRefa->value;
      my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
    
      if ($osisID_mod ne $osisRef_mod) {next;}
      
      my $name = @{$XPC->findnodes('parent::dw:entry/dw:name[1]', $osisRefa)}[0];
      if ($osisID eq $osisRef) {$match = 1; last;}
      elsif ($allowUpdate && &uc2($osisIDa->parentNode->textContent) eq &uc2($name->textContent)) {
        $match = 1;
        $update++;
        $osisRefa->setValue(entry2osisRef($osisID_mod, $osisID));
        foreach my $c ($name->childNodes()) {$c->unbindNode();}
        $name->appendText($osisIDa->parentNode->textContent);
        last;
      }
    }
    if (!$match) {&Log("ERROR: Missing entry \"$osisID\" in $DICTIONARY_WORDS\n"); $allmatch = 0;}
  }
  
  if ($update) {
    if (!open(OUTF, ">$dw_file.tmp")) {&Log("ERROR: Could not open $DICTIONARY_WORDS.tmp\n"); die;}
    print OUTF $DWF->toString();
    close(OUTF);
    unlink($dw_file); rename("$dw_file.tmp", $dw_file);
    &Log("NOTE: Updated $update entries in $dw_file\n");
    
    &loadDictionaryWordsXML();
  }
  
  my @r = $XPC->findnodes('//dw:entry/dw:name[translate(text(), "_,;[(", "_____") != text()][count(following-sibling::dw:match) = 1]', $DWF);
  if (!@r[0]) {@r = ();}
  &Log("\n$MOD REPORT: Compound glossary entry names with a single match element: (".scalar(@r)." instances)\n");
  if (@r) {
    &Log("NOTE: Multiple <match> elements should probably be added to $DICTIONARY_WORDS\nto match each part of the compound glossary entry.\n");
    foreach my $r (@r) {&Log($r->textContent."\n");}
  }
  
  if ($allmatch) {&Log("All entries are included.\n");}
}

1;
