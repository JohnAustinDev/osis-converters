# This file is part of "osis-converters".
# 
# Copyright 2020 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

# Parse the module's DICTIONARY_WORDS to DWF. Check for outdated 
# DICTIONARY_WORDS markup and update it. Validate DICTIONARY_WORDS 
# entries against a dictionary OSIS file's keywords. Validate 
# DICTIONARY_WORDS xml markup. Return DWF on successful parsing and 
# checking without error, '' otherwise. 
sub loadDictionaryWordsXML($$$) {
  my $dictosis = shift;
  my $noupdateMarkup = shift;
  my $noupdateEntries = shift;
  
  if (! -e "$INPD/$DICTIONARY_WORDS") {return '';}
  my $dwf = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # Check for old DICTIONARY_WORDS markup and update or report
  my $errors = 0;
  my $update = 0;
  my $tst = @{$XPC->findnodes('//dw:div', $dwf)}[0];
  if (!$tst) {
    &Error("Missing namespace declaration in: \"$INPD/$DICTIONARY_WORDS\", continuing with default.", "Add 'xmlns=\"$DICTIONARY_WORDS_NAMESPACE\"' to root element of \"$INPD/$DICTIONARY_WORDS\".");
    $errors++;
    my @ns = $XPC->findnodes('//*', $dwf);
    foreach my $n (@ns) {$n->setNamespace($DICTIONARY_WORDS_NAMESPACE, 'dw', 1); $update++;}
  }
  my $tst = @{$XPC->findnodes('//*[@highlight]', $dwf)}[0];
  if ($tst) {
    &Warn("Ignoring outdated attribute: \"highlight\" found in: \"$INPD/$DICTIONARY_WORDS\"", "Remove the \"highlight\" attribute and use the more powerful notXPATH attribute instead.");
    $errors++;
  }
  my $tst = @{$XPC->findnodes('//*[@withString]', $dwf)}[0];
  if ($tst) {
    $errors++;
    &Warn("\"withString\" attribute is no longer supported.", "Remove withString attributes from $DICTIONARY_WORDS and replace it with XPATH=<xpath-expression> instead.");
  }
  
  # Save any updates back to source dictionary_words_xml and reload
  if ($update) {
    &writeXMLFile($dwf, "$dictionary_words_xml.tmp");
    unlink($dictionary_words_xml); rename("$dictionary_words_xml.tmp", $dictionary_words_xml);
    &Note("Updated $update instance of non-conforming markup in $dictionary_words_xml");
    if (!$noupdateMarkup) {
      $noupdateMarkup++;
      return &loadDictionaryWordsXML($dictosis, $noupdateMarkup, $noupdateEntries);
    }
    else {
      $errors++;
      &Error("loadDictionaryWordsXML failed to update markup. Update $DICTIONARY_WORDS manually.", "Sometimes the $DICTIONARY_WORDS can only be updated manually.");
    }
  }
  
  # Compare dictosis to DICTIONARY_WORDS
  if ($dictosis && &compareDictOsis2DWF($dictosis, "$INPD/$DICTIONARY_WORDS")) {
    if (!$noupdateEntries) {
      # If updates were made, reload DWF etc.
      $noupdateEntries++;
      return &loadDictionaryWordsXML($dictosis, $noupdateMarkup, $noupdateEntries);
    }
    else {
      $errors++;
      &ErrorBug("compareDictOsis2DWF failed to update entry osisRef capitalization on first pass");
    }
  }
  
  # Warn if some entries should have multiple match elements
  my @r = $XPC->findnodes('//dw:entry/dw:name[translate(text(), "_,;[(", "_____") != text()][count(following-sibling::dw:match) = 1]', $dwf);
  if (!@r[0]) {@r = ();}
  &Log("\n");
  &Report("Compound glossary entry names with a single match element: (".scalar(@r)." instances)");
  if (@r) {
    &Note("Multiple <match> elements should probably be added to $DICTIONARY_WORDS\nto match each part of the compound glossary entry.");
    foreach my $r (@r) {&Log($r->textContent."\n");}
  }
  
  my $valid = 0;
  if ($errors == 0) {$valid = &validateDictionaryWordsXML($dwf);}
  if ($valid) {&Note("$INPD/$DICTIONARY_WORDS has no unrecognized elements or attributes.\n");}
  
  return ($valid && $errors == 0 ? $dwf:'');
}


# Check that all keywords in dictosis, except those in the NAVMENU, are 
# included as entries in the dictionary_words_xml file and all entries 
# in dictionary_words_xml have keywords in dictosis. If the difference 
# is only in capitalization, and all the OSIS file's keywords are unique 
# according to a case-sensitive comparison, (which occurs when 
# converting from DictionaryWords.txt to DictionaryWords.xml) then fix 
# them, update dictionary_words_xml, and return 1. Otherwise return 0.
sub compareDictOsis2DWF($$) {
  my $dictosis = shift; # dictionary osis file to validate entries against
  my $dictionary_words_xml = shift; # DICTIONARY_WORDS xml file to validate
  
  &Log("\n--- CHECKING ENTRIES IN: $dictosis FOR INCLUSION IN: $dictionary_words_xml\n", 1);
  
  my $osis = $XML_PARSER->parse_file($dictosis);
  my $osismod = &getOsisRefWork($osis);
  my $dwf = $XML_PARSER->parse_file($dictionary_words_xml);
  
  # Decide if keyword any capitalization update is possible or not
  my $allowUpdate = 1; my %noCaseKeys;
  foreach my $es ($XPC->findnodes('//osis:seg[@type="keyword"]/text()', $osis)) {
    if ($noCaseKeys{lc($es)}) {
      &Note("Will not update case-only discrepancies in $dictionary_words_xml.");
      $allowUpdate = 0;
      last;
    }
    $noCaseKeys{lc($es)}++;
  }

  my $update = 0;
  my $allmatch = 1;
  my @dwfOsisRefs = $XPC->findnodes('//dw:entry/@osisRef', $dwf);
  my @dictOsisIDs = $XPC->findnodes('//osis:seg[@type="keyword"][not(ancestor::osis:div[@subType="x-aggregate"])]/@osisID', $osis);
  
  # Check that all DICTMOD keywords (except NAVEMNU keywords) are included as entries in dictionary_words_xml
  foreach my $osisIDa (@dictOsisIDs) {
    if (!$osisIDa || @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"][@scope="NAVMENU"][1]', $osisIDa)}[0]) {next;}
    my $osisID = $osisIDa->value;
    my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
    
    my $match = 0;
DWF_OSISREF:
    foreach my $dwfOsisRef (@dwfOsisRefs) {
      if (!$dwfOsisRef) {next;}
      foreach my $osisRef (split(/\s+/, $dwfOsisRef->value)) {
        my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
        if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last DWF_OSISREF;}
      }
        
      # Update entry osisRefs that need to be, and can be, updated
      my $name = @{$XPC->findnodes('parent::dw:entry/dw:name[1]', $dwfOsisRef)}[0];
      if ($allowUpdate && &uc2($osisIDa->parentNode->textContent) eq &uc2($name->textContent)) {
        $match = 1;
        $update++;
        my $origOsisRef = $dwfOsisRef->value;
        $dwfOsisRef->setValue(entry2osisRef($osisID_mod, $osisID));
        foreach my $c ($name->childNodes()) {$c->unbindNode();}
        $name->appendText($osisIDa->parentNode->textContent);
        &Warn("DICT mod keyword and DictionaryWords entry name are identical, but osisID != osisRef. UPDATING DictionaryWords osisRef from $origOsisRef to $osisID", "<>This happens when an old version of DictionaryWords.xml is being upgraded. Otherwise, there could be bug or some problem with this osisRef.");
        last;
      }
    }
    if (!$match) {&Warn("Missing entry \"$osisID\" in $dictionary_words_xml", "That you don't want any links to this entry."); $allmatch = 0;}
  }
  
  # Check that all DWF osisRefs are included as keywords in dictosis
  my %reported;
  foreach my $dwfOsisRef (@dwfOsisRefs) {
    if (!$dwfOsisRef) {next;}
    foreach my $osisRef (split(/\s+/, $dwfOsisRef->value)) {
      my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
      
      my $match = 0;
      foreach my $osisIDa (@dictOsisIDs) {
        if (!$osisIDa) {next;}
        my $osisID = $osisIDa->value;
        my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
        if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last;}
      }
      if (!$match && $osisRef !~ /\!toc$/) {
        if (!$reported{$osisRef}) {
          &Warn("Extra entry \"$osisRef\" in $dictionary_words_xml", "Remove this entry from $dictionary_words_xml because does not appear in $DICTMOD.");
        }
        $reported{$osisRef}++;
        $allmatch = 0;
      }
    }
  }
  
  # Save any updates back to source dictionary_words_xml
  if ($update) {
    &writeXMLFile($dwf, "$dictionary_words_xml.tmp");
    unlink($dictionary_words_xml); rename("$dictionary_words_xml.tmp", $dictionary_words_xml);
    &Note("Updated $update entries in $dictionary_words_xml");
  }
  elsif ($allmatch) {&Log("All entries are included.\n");}
  
  return ($update ? 1:0);
}


# Brute force validation of dwf returns 1 on successful validation, 0 otherwise
sub validateDictionaryWordsXML($) {
  my $dwf = shift;
  
  my @entries = $XPC->findnodes('//dw:entry[@osisRef]', $dwf);
  foreach my $entry (@entries) {
    my @dicts = split(/\s+/, $entry->getAttribute('osisRef'));
    foreach my $dict (@dicts) {
      if ($dict !~ s/^(\w+):.*$/$1/) {&Error("osisRef \"$dict\" in \"$INPD/$DefaultDictWordFile\" has no target module", "Add the dictionary module name followed by ':' to the osisRef value.");}
    }
  }
  
  my $success = 1;
  my $x = "//*";
  my @allowed = ('dictionaryWords', 'div', 'entry', 'name', 'match');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badElem = $XPC->findnodes($x, $dwf);
  if (@badElem) {
    foreach my $ba (@badElem) {
      &Error("Bad DictionaryWords.xml element: \"".$ba->localname()."\"", "Only the following elements are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//*[local-name()!='dictionaryWords'][local-name()!='entry']/@*";
  @allowed = ('onlyNewTestament', 'onlyOldTestament', 'context', 'notContext', 'multiple', 'osisRef', 'XPATH', 'notXPATH', 'version', 'dontLink', 'notExplicit', 'onlyExplicit');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("\nBad DictionaryWords.xml attribute: \"".$ba->localname()."\"", "Only the following attributes are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//dw:entry/@*";
  push(@allowed, ('osisRef', 'noOutboundLinks'));
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("Bad DictionaryWords.xml entry attribute: \"".$ba->localname()."\"", "The entry element may contain these attributes: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  return $success;
}

# Add dictionary links as described in $DWF to the nodes pointed to 
# by $eP array pointer. Expected node types are element or text.
sub addDictionaryLinks(\@$$) {
  my $eP = shift; # array of text-nodes or text-node parent elements from a document (Note: node element child elements are not touched)
  my $ifExplicit = shift; # text context if the node was marked in the text as a glossary link
  my $isGlossary = shift; # true if the nodes are in a glossary (See-Also linking)
  
  my $bookOrderP;
  foreach my $node (@$eP) {
    my $glossaryNodeContext;
    my $glossaryScopeContext;
    
    if ($isGlossary) {
      if (!$bookOrderP) {&getCanon(&getVerseSystemOSIS($node), NULL, \$bookOrderP, NULL)}
      $glossaryNodeContext = &getNodeContext($node);
      if (!$glossaryNodeContext) {next;}
      my @gs; foreach my $gsp ( split(/\s+/, &getGlossaryScopeAttribute($node)) ) {
        push(@gs, ($gsp =~ /\-/ ? @{&scopeToBooks($gsp, $bookOrderP)}:$gsp));
      }
      $glossaryScopeContext = join('+', @gs);
      if (!$NoOutboundLinks{'haveBeenRead'}) {
        foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', $DWF)) {
          foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
        }
        $NoOutboundLinks{'haveBeenRead'}++;
      }
      if ($NoOutboundLinks{&entry2osisRef($MOD, $glossaryNodeContext)}) {return;}
    }
  
    my @textchildren;
    my $container = ($node->nodeType == XML::LibXML::XML_TEXT_NODE ? $node->parentNode:$node);
    if ($node->nodeType == XML::LibXML::XML_TEXT_NODE) {push(@textchildren, $node);}
    else {@textchildren = $XPC->findnodes('child::text()', $container);}
    if (&conf('ModDrv') =~ /LD/ && $XPC->findnodes("self::$KEYWORD", $container)) {next;}
    my $text, $matchedPattern;
    foreach my $textchild (@textchildren) {
      $text = $textchild->data();
      if ($text =~ /^\s*$/) {next;}
      my $done;
      do {
        $done = 1;
        my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
        foreach my $part (@parts) {
          if ($part =~ /<reference.*?<\/reference[^>]*>/ || $part =~ /^[\s\n]*$/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $textchild, $ifExplicit, $glossaryNodeContext, $glossaryScopeContext)) {
            if (!$ifExplicit) {$done = 0;}
          }
        }
        $text = join('', @parts);
      } while(!$done);
      $text =~ s/<reference [^>]*osisRef="REMOVE_LATER"[^>]*>(.*?)<\/reference>/$1/sg;
      
#&Debug("BEFORE=".$textchild->data()."\nAFTER =".$text."\n\n");
      
      # sanity check
      my $check = $text;
      $check =~ s/<\/?reference[^>]*>//g;
      if ($check ne $textchild->data()) {
        &ErrorBug("Bible text changed during glossary linking!\nBEFORE=".$textchild->data()."\nAFTER =$check", 1);
      }
      
      # apply new reference tags back to DOM
      foreach my $childnode (split(/(<reference[^>]*>.*?<\/reference[^>]*>)/s, $text)) {
        my $newRefElement = '';
        my $t = $childnode; 
        if ($t =~ s/(<reference[^>]*>)(.*?)(<\/reference[^>]*>)/$2/s) {
          my $refelem = "$1 $3";
          $newRefElement = $XML_PARSER->parse_balanced_chunk($refelem);
        }
        my $newTextNode = XML::LibXML::Text->new($t);
        if ($newRefElement) {
          $newRefElement->firstChild->insertBefore($newTextNode, NULL);
          $newRefElement->firstChild->removeChild($newRefElement->firstChild->firstChild); # remove the originally necessary ' ' in $refelem 
        }
        my $newChildNode = ($newRefElement ? $newRefElement:$newTextNode);
        $textchild->parentNode->insertBefore($newChildNode, $textchild);
      }
      $textchild->unbindNode(); 
    }
  }
}

# Searches and replaces $$tP text for a single dictionary link, according 
# to the $DWF file, and logs any result. If a match is found, the proper 
# reference tags are inserted, and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$$\@) {
  my $textP = shift;
  my $textNode = shift;
  my $explicitContext = shift; # context string if the node was marked in the text as a glossary link
  my $glossaryNodeContext = shift; # for SeeAlso links only
  my $glossaryScopeContext = shift; # for SeeAlso links only

  my $matchedPattern = '';
  
  # Cache match related info
  if (!@MATCHES) {
    my $notes;
    $OT_CONTEXTSP =  &getContextAttributeHash('OT');
    $NT_CONTEXTSP =  &getContextAttributeHash('NT');
    my @ms = $XPC->findnodes('//dw:match', $DWF);
    foreach my $m (@ms) {
      my %minfo;
      $minfo{'node'} = $m;
      $minfo{'notExplicit'} = &attributeIsSet('notExplicit', $m);
      $minfo{'onlyExplicit'} = &attributeIsSet('onlyExplicit', $m);
      $minfo{'onlyOldTestament'} = &attributeIsSet('onlyOldTestament', $m);
      $minfo{'onlyNewTestament'} = &attributeIsSet('onlyNewTestament', $m);
      $minfo{'multiple'} = @{$XPC->findnodes("ancestor-or-self::*[\@multiple][1]/\@multiple", $m)}[0]; if ($minfo{'multiple'}) {$minfo{'multiple'} = $minfo{'multiple'}->value;}
      $minfo{'dontLink'} = &attributeIsSet('dontLink', $m);
      $minfo{'context'} = &getScopedAttribute('context', $m);
      $minfo{'contexts'} = &getContextAttributeHash($minfo{'context'}, \$notes);
      $minfo{'notContext'} = &getScopedAttribute('notContext', $m);
      $minfo{'notContexts'} = &getContextAttributeHash($minfo{'notContext'}, \$notes);
      $minfo{'notXPATH'} = &getScopedAttribute('notXPATH', $m);
      $minfo{'XPATH'} = &getScopedAttribute('XPATH', $m);
      $minfo{'osisRef'} = @{$XPC->findnodes('ancestor::dw:entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
      $minfo{'name'} = @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent;
      # A <match> element should never be applied to any textnode inside the glossary entry (or entries) which the match pertains to or any duplicate entries thereof.
      # This is necessary to insure an entry will never contain links to itself or to a duplicate.
      my @osisRef = split(/\s+/, @{$XPC->findnodes('ancestor::dw:entry[1]', $m)}[0]->getAttribute('osisRef'));
      foreach my $ref (@osisRef) {$minfo{'skipRootID'}{&getRootID($ref)}++;}
      
      # test match pattern, so any errors with it can be found right away
      if ($m->textContent !~ /(?<!\\)\(.*(?<!\\)\)/) {
        &Error("Skipping match \"$m\" becauase it is missing capture parentheses", "Add parenthesis around the match text which should be linked.");
        next;
      }
      my $test = "testme"; my $is; my $ie;
      if (&glossaryMatch(\$test, $m, \$is, \$ie) == 2) {next;}
      
      push(@MATCHES, \%minfo);
      
      my @wds = split(/\s+/, $minfo{'name'});
      if (@wds > $MAX_MATCH_WORDS) {$MAX_MATCH_WORDS = @wds; &Note("Setting MAX_MATCH_WORDS to $MAX_MATCH_WORDS");}
    }
    #if ($notes) {&Log("\n".('-' x 80)."\n".('-' x 80)."\n\n$notes\n");}
  }
  
  my $context;
  my $multiples_context;
  if ($glossaryNodeContext) {$context = $glossaryNodeContext; $multiples_context = $glossaryNodeContext;}
  else {
    $context = &bibleContext($textNode);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &inContext($context, $OT_CONTEXTSP);
  my $contextIsNT = &inContext($context, $NT_CONTEXTSP);
  my @contextNote = $XPC->findnodes("ancestor::osis:note", $textNode);
  
  my $a;
  foreach my $m (@MATCHES) {
    my $removeLater = $m->{'dontLink'};
#@DICT_DEBUG = ($context, @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m->{'node'})}[0]->textContent()); @DICT_DEBUG_THIS = ("Gen.49.10.10", decode("utf8", "АҲД САНДИҒИ"));
#@DICT_DEBUG = ($textNode->data); @DICT_DEBUG_THIS = (decode("utf8", "Хөрмәтле укучылар, < Борынгы Шерык > сезнең игътибарга Изге Язманың хәзерге татар телендә беренче тапкыр нәшер ителгән тулы җыентыгын тәкъдим итәбез."));
#my $nodedata; foreach my $k (sort keys %{$m}) {if ($k !~ /^(node|contexts|notContexts|skipRootID)$/) {$nodedata .= "$k: ".$m->{$k}."\n";}}  use Data::Dumper; $nodedata .= "contexts: ".Dumper(\%{$m->{'contexts'}}); $nodedata .= "notContexts: ".Dumper(\%{$m->{'notContexts'}});
#&dbg(sprintf("\nNode(type %s, %s):\nText: %s\nMatch: %s\n%s", $textNode->parentNode->nodeType, $context, $$textP, $m->{'node'}, $nodedata));
    
    my $filterMultiples = (!$explicitContext && $m->{'multiple'} !~ /^true$/i);
    my $key = ($filterMultiples ? &getMultiplesKey($m, $m->{'multiple'}, \@contextNote):'');
    
    if ($explicitContext && $m->{'notExplicit'}) {&dbg("filtered at 00\n\n"); next;}
    elsif (!$explicitContext && $m->{'onlyExplicit'}) {&dbg("filtered at 01\n\n"); next;}
    else {
      if ($glossaryNodeContext && $m->{'skipRootID'}{&getRootID($glossaryNodeContext)}) {&dbg("05\n\n"); next;} # never add glossary links to self
      if (!$contextIsOT && $m->{'onlyOldTestament'}) {&dbg("filtered at 10\n\n"); next;}
      if (!$contextIsNT && $m->{'onlyNewTestament'}) {&dbg("filtered at 20\n\n"); next;}
      if ($filterMultiples) {
        if (@contextNote > 0) {if ($MULTIPLES{$key}) {&dbg("filtered at 35\n\n"); next;}}
        # $removeLater disallows links within any phrase that was previously skipped as a multiple.
        # This helps prevent matched, but unlinked, phrases inadvertantly being torn into smaller, likely irrelavent, entry links.
        elsif ($MULTIPLES{$key}) {&dbg("filtered at 40\n\n"); $removeLater = 1;}
      }
      if ($m->{'context'}) {
        my $gs  = ($glossaryScopeContext ? 1:0);
        my $ic  = &inContext($context, $m->{'contexts'});
        my $igc = ($gs ? &inContext($glossaryScopeContext, $m->{'contexts'}):0);
        if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {&dbg("filtered at 50 (gs=$gs, ic=$ic, igc=$igc)\n\n"); next;}
      }
      if ($m->{'notContext'}) {
        if (&inContext($context, $m->{'notContexts'})) {&dbg("filtered at 60\n\n"); next;}
      }
      if ($m->{'XPATH'}) {
        my $tst = @{$XPC->findnodes($m->{'XPATH'}, $textNode)}[0];
        if (!$tst) {&dbg("filtered at 70\n\n"); next;}
      }
      if ($m->{'notXPATH'}) {
        $tst = @{$XPC->findnodes($m->{'notXPATH'}, $textNode)}[0];
        if ($tst) {&dbg("filtered at 80\n\n"); next;}
      }
    }
    
    my $is; my $ie;
    if (&glossaryMatch($textP, $m->{'node'}, \$is, \$ie, $explicitContext)) {next;}
    if ($is == $ie) {
      &ErrorBug("Match result was zero width!: \"".$m->{'node'}->textContent."\"");
      next;
    }
    
    $MATCHES_USED{$m->{'node'}->unique_key}++;
    $matchedPattern = $m->{'node'}->textContent;
    my $osisRef = ($removeLater ? 'REMOVE_LATER':$m->{'osisRef'});
    my $attribs = "osisRef=\"$osisRef\" type=\"".(&conf('ModDrv') =~ /LD/ ? 'x-glosslink':'x-glossary')."\"";
    my $match = substr($$textP, $is, ($ie-$is));
    
    substr($$textP, $ie, 0, "</reference>");
    substr($$textP, $is, 0, "<reference $attribs>");
    
    if (!$removeLater) {
      # record hit...
      $EntryHits{$m->{'name'}}++;
      
      my $logContext = $context;
      $logContext =~ s/\..*$//; # keep book/entry only
      $LINK_OSISREF{$m->{'osisRef'}}{'context'}{$logContext}++;
      $LINK_OSISREF{$m->{'osisRef'}}{'matched'}{$match}++;
      $LINK_OSISREF{$m->{'osisRef'}}{'total'}++;

      if ($filterMultiples) {$MULTIPLES{$key}++;}
    }
    
    last;
  }
 
  return $matchedPattern;
}

# Print log info for a word file
sub logDictLinks() {
  &Log("\n\n");
  &Report("Explicitly marked words or phrases that were linked to glossary entries: (". (scalar keys %EXPLICIT_GLOSSARY) . " variations)");
  my $mxl = 0; foreach my $eg (sort keys %EXPLICIT_GLOSSARY) {if (length($eg) > $mxl) {$mxl = length($eg);}}
  my %cons;
  foreach my $eg (sort keys %EXPLICIT_GLOSSARY) {
    my @txt;
    foreach my $tg (sort keys %{$EXPLICIT_GLOSSARY{$eg}}) {
      if ($tg eq 'Failed') {
        my @contexts = sort keys %{$EXPLICIT_GLOSSARY{$eg}{$tg}{'context'}};
        my $mlen = 0;
        foreach my $c (@contexts) {
          if (length($c) > $mlen) {$mlen = length($c);}
          my $ctx = $c; $ctx =~ s/^\s+//; $ctx =~ s/\s+$//; $ctx =~ s/<index\/>.*$//;
          $cons{lc($ctx)}++;
        }
        foreach my $c (@contexts) {$c = sprintf("%".($mlen+5)."s", $c);}
        push(@txt, $tg." (".$EXPLICIT_GLOSSARY{$eg}{$tg}{'count'}.")\n".join("\n", @contexts)."\n");
      }
      else {
        push(@txt, $tg." (".$EXPLICIT_GLOSSARY{$eg}{$tg}.")");
      }
    }
    my $msg = join(", ", sort { ($a =~ /failed/i ? 0:1) <=> ($b =~ /failed/i ? 0:1) } @txt);
    &Log(sprintf("%-".$mxl."s ".($msg !~ /failed/i ? "was linked to ":'')."%s", $eg, $msg) . "\n");
  }
  # Report each unique context ending for failures, since these may represent entries that are missing from the glossary
  my %uniqueConEnd;
  foreach my $c (sort keys %cons) {
    my $toLastWord;
    for (my $i=2; $i<=length($c) && $c !~ /^\s*$/; $i++) {
      my $end = substr($c, -$i, $i);
      my $keep = 1;
      if (substr($end,0,1) =~ /\s/) {$toLastWord = substr($end, 1, length($end)-1);}
      foreach my $c2 (sort keys %cons) {
        if ($c2 eq $c) {next;}
        if ($c2 =~ /\Q$end\E$/i) {$keep = 0; last;}
      }
      if ($keep) {
        my $uce = $c;
        if ($toLastWord) {$uce = $toLastWord;}
        else {$uce =~ s/^.*\s//};
        $uniqueConEnd{$uce}++; $i=length($c);
      }
    }
  }
  &Log("\n");
  &Report("There were ".%uniqueConEnd." unique failed explicit entry contexts".(%uniqueConEnd ? ':':'.'));
  foreach my $uce (sort { length($b) <=> length($a) } keys %uniqueConEnd) {&Log("$uce\n");}
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//dw:entry/dw:name/text()', $DWF);
  my %entriesH; foreach my $e (@entries) {
    my @ms = $XPC->findnodes('./ancestor::dw:entry[1]//dw:match', $e);
    $entriesH{(!@ms || !@ms[0] ? '(no match rules) ':'').$e}++;
  }
  foreach my $e (sort keys %entriesH) {
    my $match = 0;
    foreach my $dh (sort keys %EntryHits) {
      my $xe = $e; $xe =~ s/^No <match> element(s)\://g;
      if ($xe eq $dh) {$match = 1;}
    }
    if (!$match) {$nolink .= $e."\n"; $numnolink++;}
  }
  
  &Log("\n\n");
  &Report("Glossary entries from $DICTIONARY_WORDS which have no links in the text: ($numnolink instances)");
  if ($nolink) {
    &Note("You may want to link to these entries using a different word or phrase. To do this, edit the");
    &Log("$DICTIONARY_WORDS file.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  &Log("\n");
  
  my @matches = $XPC->findnodes('//dw:match', $DWF);
  my %unused;
  my $total = 0;
  my $mlen = 0;
  foreach my $m (@matches) {
    if ($MATCHES_USED{$m->unique_key}) {next;}
    my $entry = @{$XPC->findnodes('./ancestor::dw:entry[1]', $m)}[0];
    if ($entry) {
      my $osisRef = $entry->getAttribute('osisRef');
      if (!$unused{$osisRef}) {
        $unused{$osisRef} = ();
      }
      push(@{$unused{$osisRef}}, $m->toString());
      if (length($osisRef) > $mlen) {$mlen = length($osisRef);}
      $total++;
    }
    else {&Error("No <entry> containing $m in $DICTIONARY_WORDS", "Match elements may only appear inside entry elements.");}
  }
  &Report("Unused match elements in $DICTIONARY_WORDS: ($total instances)");
  if ($total > 50) {
    &Warn("Large numbers of unused match elements can slow down the parser.", 
"When you are sure they are not needed, and parsing is slow, then you  
can remove unused match elements from DictionaryWords.xml by running:
osis-converters/utils/removeUnusedMatchElements.pl $INPD");
  }
  foreach my $osisRef (sort keys %unused) {
    foreach my $m (@{$unused{$osisRef}}) {
      &Log(sprintf("%-".$mlen."s %s\n", $osisRef, $m));
    }
  }
  &Log("\n");

  # REPORT: N links to DICTMOD:<decoded_entry_osisRef> as <match1>(N) <match2>(N*)... in <context1>(N) <context2>(N)...
  # get fields and their lengths
  my $grandTotal = 0;
  my %toString; my $maxLenToString = 0;
  my %asString; my $maxLenAsString = 0;
  foreach my $refs (keys %LINK_OSISREF) {
    $grandTotal += $LINK_OSISREF{$refs}{'total'};
    $toString{$refs} = &decodeOsisRef($refs);
    if (!$maxLenToString || $maxLenToString < length($toString{$refs})) {$maxLenToString = length($toString{$refs});}
    foreach my $as (sort {&numAlphaSort($LINK_OSISREF{$refs}{'matched'}, $a, $b, '', 0);} keys %{$LINK_OSISREF{$refs}{'matched'}}) {
      my $tp = '*'; foreach my $ref (split(/\s+/, $refs)) {if (lc($as) eq lc(&osisRef2Entry($ref))) {$tp = '';}}
      $asString{$refs} .= $as."(".$LINK_OSISREF{$refs}{'matched'}{$as}."$tp) ";
    }
    if (!$maxLenAsString || $maxLenAsString < length($asString{$refs})) {$maxLenAsString = length($asString{$refs});}
  }
  
  my %inString;
  foreach my $refs (keys %LINK_OSISREF) {
    foreach my $in (sort {&numAlphaSort($LINK_OSISREF{$refs}{'context'}, $a, $b, '', 1);} keys %{$LINK_OSISREF{$refs}{'context'}}) {
      $inString{$refs} .= &decodeOsisRef($in)."(".$LINK_OSISREF{$refs}{'context'}{$in}.") ";
    }
  }
  
  my $p;
  foreach my $refs (sort {&numAlphaSort(\%LINK_OSISREF, $a, $b, 'total', 1);} keys %LINK_OSISREF) {
    $p .= sprintf("%4i links to %-".$maxLenToString."s as %-".$maxLenAsString."s in %s\n", 
            $LINK_OSISREF{$refs}{'total'}, 
            $toString{$refs}, 
            $asString{$refs},
            $inString{$refs}
          );
  }
  &Note("
The following listing should be looked over to be sure text is
correctly linked to the glossary. Glossary entries are matched in the
text using the match elements found in the $DICTIONARY_WORDS file.\n");
  &Report("Links created: ($grandTotal instances)\n* is textual difference other than capitalization\n$p");
}


# This returns the context surrounding an index milestone, which is 
# often necessary to determine the intended index target. Since this 
# error is commonly seen for example when level1 should be "Ark of the 
# Covenant": 
# "This is some Bible text concerning the Ark of the Covenant<index level1="Covenant"/>"
# The index alone does not result in the intended match, but using
# context gives us an excellent chance of correcting this common mistake. 
# The risk of unintentionally making a 'too-specific' match may exist, 
# but this is unlikely and would probably not be incorrect anyway.
sub getIndexContextString($) {
  my $i = shift;
  
  my $cbefore = '';
  my $tn = $i;
  do {
    $tn = @{$XPC->findnodes("(preceding-sibling::text()[1] | preceding-sibling::*[1][not(self::osis:title) and not(self::osis:p) and not(self::osis:div)]//text()[last()])[last()]", $tn)}[0];
    if ($tn) {$cbefore = $tn->data.$cbefore;}
    $cbefore =~ s/\s+/ /gs;
    my $n =()= $cbefore =~ /\S+/g;
  } while ($tn && $n < $MAX_MATCH_WORDS);
  
  my $m = ($MAX_MATCH_WORDS-1);
  $cbefore =~ s/^.*?(\S+(\s+\S+){1,$m})$/$1/;
  
  if (!$cbefore || $cbefore =~ /^\s*$/) {&Error("Could not determine context before $i");}
  
  my $cafter = '';
  my $tn = $i;
  do {
    $tn = @{$XPC->findnodes("(following-sibling::text()[1] | following-sibling::*[1][not(self::osis:title) and not(self::osis:p) and not(self::osis:div)]//text()[1])[1]", $tn)}[0];
    if ($tn) {$cafter .= $tn->data;}
    $cafter =~ s/\s+/ /gs;
    my $n =()= $cafter =~ /\S+/g;
  } while ($tn && $n < $MAX_MATCH_WORDS);
  
  my $m = ($MAX_MATCH_WORDS-1);
  $cafter =~ s/^(\s*\S+(\s+\S+){1,$m}).*?$/$1/;
  
  return ":CXBEFORE:$cbefore:CXAFTER:$cafter";
}

sub getMultiplesKey($$\@) {
  my $m = shift;
  my $multiple = shift;
  my $contextNoteP = shift;
  
  my $base = ($multiple eq 'match-per-chapter' ? $m->{'node'}->unique_key:$m->{'osisRef'});
  if (@{$contextNoteP} > 0) {return $base . ',' .@{$contextNoteP}[$#$contextNoteP]->unique_key;}
  else {return $base;}
}


sub getRootID($) {
  my $osisID = shift;
  
  $osisID =~ s/(^[^\:]+\:|\.dup\d+$)//g;
  return lc(&decodeOsisRef($osisID));
}

# Look for a single match $m in $$textP and set its start/end positions
# if one is found. Returns 0 if a match was found; or else 1 if no 
#  match was found, or 2 on error.
sub glossaryMatch(\$$\$\$$) {
  my $textP = shift;
  my $m = shift;
  my $isP = shift;
  my $ieP = shift;
  my $explicitContext = shift;
  
  my $index; my $cxbefore; my $cxafter;
  if ($explicitContext =~ /^(.*?)\:CXBEFORE\:(.*?)\:CXAFTER\:(.*)$/) {$index = $1; $cxbefore = $2; $cxafter = $3;}
  
  my $p = $m->textContent;
  if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {
    &ErrorBug("Bad match regex: $p !~ /^\s*\/(.*)\/(\w*)\s*\$/");
    &dbg("80\n");
    return 2;
  }
  my $pm = $1; my $pf = $2;
  
  # handle PUNC_AS_LETTER word boundary matching issue
  if ($PUNC_AS_LETTER) {
    $pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;
  }
  
  # handle xml decodes
  $pm = decode_entities($pm);
  
  # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
  my $t = ($explicitContext ? "$cxbefore$cxafter":$$textP);
  my $i = $pf =~ s/i//;
  $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;
  if ($i) {
    $t = &uc2($t);
  }
  if ($pf =~ /(\w+)/) {
    &Error("Regex flag \"$1\" not supported in \"".$m->textContent."\"", "Only Perl regex flags are supported.");
  }
 
  # finally do the actual MATCHING...
  &dbg("pattern matching ".($t !~ /$pm/ ? "failed!":"success!").": \"$t\" =~ /$pm/\n"); 
  if ($t !~ /$pm/) {return 1;}

  $$isP = $-[$#+];
  $$ieP = $+[$#+];
  
  # if a (?'link'...) named group 'link' exists, use it instead
  if (defined($+{'link'})) {
    my $i;
    for ($i=0; $i <= $#+; $i++) {
      if ($$i eq $+{'link'}) {last;}
    }
    $$isP = $-[$i];
    $$ieP = $+[$i];
  }
  
  if ($explicitContext && ($$isP > (length($cxbefore)-1) || (length($cxbefore)-1) > $$ieP)) {
    &dbg("but match '".substr("$cxbefore$cxafter", $$isP, ($$ieP-$$isP))."' did not include the index '$index'\n");
    if ($cxbefore !~ s/^\s*\S+//) {return 1;}
    return &glossaryMatch($textP, $m, $isP, $ieP, "$index:CXBEFORE:$cxbefore:CXAFTER:$cxafter");
  }
  
  if ($explicitContext) {
    $$isP = length($$textP) - length($index);
    $$ieP = length($$textP);
  }
  
  &dbg("LINKED: $pm\n$t\n$$isP, $$ieP, '".substr($$textP, $$isP, ($$ieP-$$isP))."'\n");
  
  return 0;
}

# Converts a comma separated list of Paratext references (which are 
# supported by context and notContext attributes of DWF) and converts
# them into an osisRef. If $paratextRefList is not a valid Paratext 
# reference list, then $paratextRefList is returned unchaged. If there 
# are any errors, $paratextRefList is returned unchanged.
sub paratextRefList2osisRef($) {
  my $paratextRefList = shift;
  
  if ($CONVERTED_P2O{$paratextRefList}) {return $CONVERTED_P2O{$paratextRefList};}
  
  my @parts;
  @parts = split(/\s*,\s*/, $paratextRefList);
  my $reportParatextWarnings = (($paratextRefList =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1) ? 1:0) || (scalar(@parts) > 3));
  foreach my $part (@parts) {
    if ($part =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1)) {next;}
    if ($reportParatextWarnings) {
      &Warn("Attribute part \"$part\" might be a failed Paratext reference in \"$paratextRefList\".");
    }
    return $paratextRefList;
  }
  
  my $p1; my $p2;
  my @osisRefs = ();
  foreach my $part (@parts) {
    my @pOsisRefs = ();
    
    # book-book (assumes Paratext and OSIS verse system's book orders are the same)
    if ($part =~ /^([\d\w]\w\w)\s*\-\s*([\d\w]\w\w)$/) {
      my $bk1 = $1; my $bk2 = $2;
      $bk1 = &getOsisName($bk1, 1);
      $bk2 = &getOsisName($bk2, 1);
      if (!$bk1 || !$bk2) {
        &Error("contextAttribute2osisRefAttribute: Bad Paratext book name(s) \"$part\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      push(@pOsisRefs, "$bk1-$bk2");
    }
    else {
      my $bk;
      my $bkP;
      my $ch;
      my $chP;
      my $vs;
      my $vsP;
      my $lch;
      my $lchP;
      my $lvs;
      # book ch-ch
      if ($part =~ /^([\d\w]\w\w)\s+(\d+)\s*\-\s*(\d+)$/) {
        $bk = $1;
        $ch = $2;
        $lch = $3;
        $bkP = 1;
      }
      # book, book ch, book ch:vs, book ch:vs-lch-lvs, book ch:vs-lvs
      elsif ($part !~ /^([\d\w]\w\w)(\s+(\d+)(\:(\d+)(\s*\-\s*(\d+)(\:(\d+))?)?)?)?$/) {
        &Error("contextAttribute2osisRefAttribute: Bad Paratext reference \"$part\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      $bk = $1;
      $bkP = $2;
      $ch = $3;
      $chP = $4;
      $vs = $5;
      $vsP = $6;
      $lch = $7;
      $lchP = $8;
      $lvs = $9;
      
      if ($vsP && !$lchP) {$lvs = $lch; $lch = '';}
      
      my $bk = &getOsisName($bk, 1);
      if (!$bk) {
        &Error("contextAttribute2osisRefAttribute: Unrecognized Paratext book \"$bk\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      
      if (!$bkP) {
        push(@pOsisRefs, $bk);
      }
      elsif (!$chP) {
        if ($lch) {
          for (my $i=$ch; $i<=$lch; $i++) {
            push(@pOsisRefs, "$bk.$i");
          }
        }
        push(@pOsisRefs, "$bk.$ch");
      }
      elsif (!$vsP) {
        push(@pOsisRefs, "$bk.$ch.$vs");
      }
      elsif (!$lchP) {
        push(@pOsisRefs, "$bk.$ch.$vs".($lvs != $vs ? "-$bk.$ch.$lvs":''));
      }
      else {
        my $canonP;
        # Bug warning - this assumes &conf('Versification') is verse system of osisRef  
        &getCanon(&conf('Versification'), \$canonP, NULL, NULL, NULL);
        my $ch1lv = ($lch == $ch ? $lvs:@{$canonP->{$bk}}[($ch-1)]);
        push(@pOsisRefs, "$bk.$ch.$vs".($ch1lv != $vs ? "-$bk.$ch.$ch1lv":''));
        if ($lch != $ch) {
          if (($lch-$ch) >= 2) {
            push(@pOsisRefs, "$bk.".($ch+1).(($lch-1) != ($ch+1) ? "-$bk.".($lch-1):''));
          }
          push(@pOsisRefs, "$bk.$lch.1".($lvs != 1 ? "-$bk.$lch.$lvs":''));
        }
      }
    }
    
    push(@osisRefs, @pOsisRefs);
    my $new = join(' ', @pOsisRefs);
    my $len = length($part);
    if ($len < length($new)) {$len = length($new);}
    $p1 .= sprintf("%-".$len."s ", $part);
    $p2 .= sprintf("%-".$len."s ", $new);
  }
  
  my $ret = join(' ', @osisRefs);
  if ($ret ne $paratextRefList) {
    $CONVERTED_P2O{$paratextRefList} = $ret;
    &Note("Converted Paratext context attribute to OSIS:\n\tParatext: $p1\n\tOSIS:     $p2\n");
  }
  
  return $ret;
}

# Returns the OSIS book name from a Paratext or OSIS bookname. Or  
# returns nothing if argument is neither.
sub getOsisName($$) {
  my $bnm = shift;
  my $quiet = shift;
  
  # If it's already an OSIS book name, just return it
  if (!$AllBooksRE) {$AllBooksRE = join('|', @OT_BOOKS, @NT_BOOKS);}
  if ($bnm =~ /^($AllBooksRE)$/) {return $bnm;}
  
  my $bookName = "";
     if ($bnm eq "1CH") {$bookName="1Chr";}
  elsif ($bnm eq "1CO") {$bookName="1Cor";}
  elsif ($bnm eq "1JN") {$bookName="1John";}
  elsif ($bnm eq "1KI") {$bookName="1Kgs";}
  elsif ($bnm eq "1PE") {$bookName="1Pet";}
  elsif ($bnm eq "1SA") {$bookName="1Sam";}
  elsif ($bnm eq "1TH") {$bookName="1Thess";}
  elsif ($bnm eq "1TI") {$bookName="1Tim";}
  elsif ($bnm eq "2CH") {$bookName="2Chr";}
  elsif ($bnm eq "2COR"){$bookName="2Cor";}
  elsif ($bnm eq "2CO") {$bookName="2Cor";}
  elsif ($bnm eq "2JN") {$bookName="2John";}
  elsif ($bnm eq "2KI") {$bookName="2Kgs";}
  elsif ($bnm eq "2PE") {$bookName="2Pet";}
  elsif ($bnm eq "2SA") {$bookName="2Sam";}
  elsif ($bnm eq "2TH") {$bookName="2Thess";}
  elsif ($bnm eq "2TI") {$bookName="2Tim";}
  elsif ($bnm eq "3JN") {$bookName="3John";}
  elsif ($bnm eq "ACT") {$bookName="Acts";}
  elsif ($bnm eq "AMO") {$bookName="Amos";}
  elsif ($bnm eq "COL") {$bookName="Col";}
  elsif ($bnm eq "DAN") {$bookName="Dan";}
  elsif ($bnm eq "DEU") {$bookName="Deut";}
  elsif ($bnm eq "ECC") {$bookName="Eccl";}
  elsif ($bnm eq "EPH") {$bookName="Eph";}
  elsif ($bnm eq "EST") {$bookName="Esth";}
  elsif ($bnm eq "EXO") {$bookName="Exod";}
  elsif ($bnm eq "EZK") {$bookName="Ezek";}
  elsif ($bnm eq "EZR") {$bookName="Ezra";}
  elsif ($bnm eq "GAL") {$bookName="Gal";}
  elsif ($bnm eq "GEN") {$bookName="Gen";}
  elsif ($bnm eq "HAB") {$bookName="Hab";}
  elsif ($bnm eq "HAG") {$bookName="Hag";}
  elsif ($bnm eq "HEB") {$bookName="Heb";}
  elsif ($bnm eq "HOS") {$bookName="Hos";}
  elsif ($bnm eq "ISA") {$bookName="Isa";}
  elsif ($bnm eq "JAS") {$bookName="Jas";}
  elsif ($bnm eq "JDG") {$bookName="Judg";}
  elsif ($bnm eq "JER") {$bookName="Jer";}
  elsif ($bnm eq "JHN") {$bookName="John";}
  elsif ($bnm eq "JOB") {$bookName="Job";}
  elsif ($bnm eq "JOL") {$bookName="Joel";}
  elsif ($bnm eq "JON") {$bookName="Jonah";}
  elsif ($bnm eq "JOS") {$bookName="Josh";}
  elsif ($bnm eq "JUD") {$bookName="Jude";}
  elsif ($bnm eq "LAM") {$bookName="Lam";}
  elsif ($bnm eq "LEV") {$bookName="Lev";}
  elsif ($bnm eq "LUK") {$bookName="Luke";}
  elsif ($bnm eq "MAL") {$bookName="Mal";}
  elsif ($bnm eq "MAT") {$bookName="Matt";}
  elsif ($bnm eq "MIC") {$bookName="Mic";}
  elsif ($bnm eq "MRK") {$bookName="Mark";}
  elsif ($bnm eq "NAM") {$bookName="Nah";}
  elsif ($bnm eq "NEH") {$bookName="Neh";}
  elsif ($bnm eq "NUM") {$bookName="Num";}
  elsif ($bnm eq "OBA") {$bookName="Obad";}
  elsif ($bnm eq "PHM") {$bookName="Phlm";}
  elsif ($bnm eq "PHP") {$bookName="Phil";}
  elsif ($bnm eq "PROV") {$bookName="Prov";}
  elsif ($bnm eq "PRO") {$bookName="Prov";}
  elsif ($bnm eq "PSA") {$bookName="Ps";}
  elsif ($bnm eq "REV") {$bookName="Rev";}
  elsif ($bnm eq "ROM") {$bookName="Rom";}
  elsif ($bnm eq "RUT") {$bookName="Ruth";}
  elsif ($bnm eq "SNG") {$bookName="Song";}
  elsif ($bnm eq "TIT") {$bookName="Titus";}
  elsif ($bnm eq "ZEC") {$bookName="Zech";}
  elsif ($bnm eq "ZEP") {$bookName="Zeph";}
  elsif (!$quiet) {&Error("Unrecognized Bookname:\"$bnm\"", "Only Paratext and OSIS Bible book abbreviations are recognized.");}

  return $bookName;
}

sub attributeIsSet($$) {
  my $a = shift;
  my $m = shift;
  
  return scalar(@{$XPC->findnodes("ancestor-or-self::*[\@$a][1][\@$a='true']", $m)});
}

sub dbg($) {
  my $p = shift;
  if (!$DEBUG) {return 0;}
  
  if (!@DICT_DEBUG_THIS) {return 0;}
  for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {
    if (@DICT_DEBUG_THIS[$i] ne @DICT_DEBUG[$i]) {return 0;}
  }
  
  &Debug($p);
  return 1;
}

sub numAlphaSort(\%$$$) {
  my $hashP = shift;
  my $a = shift;
  my $b = shift;
  my $key = shift;
  my $doDecode = shift;
  
  my $m1 = ($key ? ($hashP->{$b}{$key} <=> $hashP->{$a}{$key}):($hashP->{$b} <=> $hashP->{$a}));
  if ($m1) {
    return $m1;
  }
  
  if ($doDecode) {
    return (&decodeOsisRef($a) cmp &decodeOsisRef($b));
  }
  
  return $a cmp $b;
}

1;
