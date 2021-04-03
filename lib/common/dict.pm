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

use strict;

# Parse the module's CF_addDictLinks.xml to DWF. Check for outdated 
# DictionaryWords markup and update it. Validate CF_addDictLinks.xml 
# entries against a dictionary OSIS file's keywords. Validate 
# CF_addDictLinks.xml. Return DWF on successful parsing and 
# checking without error, '' otherwise. 

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($DEBUG, $XPC, $XML_PARSER, $OSISBOOKSRE, $ADDDICTLINKS_NAMESPACE, $ONS);
    
our (%LINK_OSISREF, @EXPLICIT_GLOSSARY);

our $DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb]";

my %DWF_CACHE;
sub getDWF {
  my $which = shift; # 'main', 'dict' or $MOD is default
  my $returnFile = shift;
  
  $which = ($which eq 'main' ? $MAININPD : ($which eq 'dict' ? $DICTINPD : $INPD));

  my $dwfFile = "$which/CF_addDictLinks.xml";
  if (!-e $dwfFile) {return '';}
  elsif ($returnFile) {return $dwfFile;}
  
  if (!exists($DWF_CACHE{$dwfFile})) {
    $DWF_CACHE{$dwfFile} = $XML_PARSER->parse_file($dwfFile);
  }
  
  return $DWF_CACHE{$dwfFile};
}

sub checkDWF {
  my $dictosis = shift;
  my $dwffile = shift;
  my $noupdateMarkup = shift;
  my $noupdateEntries = shift;
  
  my $dwf = $XML_PARSER->parse_file($dwffile);
  
  # Check for old DictionaryWords markup and update or report
  my $errors = 0;
  my $update = 0;
  my $tst = @{$XPC->findnodes('//dw:div', $dwf)}[0];
  if (!$tst) {
    &Error("Missing namespace declaration in: \"$dwffile\", continuing with default.", "Add 'xmlns=\"$ADDDICTLINKS_NAMESPACE\"' to the root element.");
    $errors++;
    my @ns = $XPC->findnodes('//*', $dwf);
    foreach my $n (@ns) {$n->setNamespace($ADDDICTLINKS_NAMESPACE, 'dw', 1); $update++;}
  }
  my $tst = @{$XPC->findnodes('//*[@highlight]', $dwf)}[0];
  if ($tst) {
    &Warn("Ignoring outdated attribute: \"highlight\" found in: \"$dwffile\"", "Remove the \"highlight\" attribute and use the more powerful notXPATH attribute instead.");
    $errors++;
  }
  my $tst = @{$XPC->findnodes('//*[@withString]', $dwf)}[0];
  if ($tst) {
    $errors++;
    &Warn("\"withString\" attribute is no longer supported.", "Remove withString attributes from $dwffile and replace it with XPATH=<xpath-expression> instead.");
  }
  
  # Compare dictosis to CF_addDictLinks.xml
  if (&compareDictOsis2DWF($dictosis, $dwffile)) {
    if (!$noupdateEntries) {
      # If updates were made, reload DWF etc.
      $noupdateEntries++;
      return &checkDWF($dictosis, $dwffile, $noupdateMarkup, $noupdateEntries);
    }
    else {
      $errors++;
      &ErrorBug("compareDictOsis2DWF failed to update entry osisRef capitalization on first pass");
    }
  }
  
  # Warn if some entries should have multiple match elements
  my @r = $XPC->findnodes('//dw:entry/dw:name[translate(text(), "_,;[(", "_____") != text()][count(following-sibling::dw:match) = 1]', $dwf);
  if (!@r[0]) {@r = ();}
  &Report("Compound glossary entry names with a single match element: (".scalar(@r)." instances)");
  if (@r) {
    &Note("Multiple <match> elements should probably be added to $dwffile\nto match each part of the compound glossary entry.");
    foreach my $r (@r) {&Log($r->textContent."\n");}
  }
  
  my $valid = 0;
  if ($errors == 0) {$valid = &validateAddDictLinksXML($dwf);}
  if ($valid) {&Note("$dwffile has no unrecognized elements or attributes.\n");}
  
  return ($valid && $errors == 0 ? $dwf:'');
}


# Check that all keywords in dictosis, except those in the NAVMENU, are 
# included as entries in the addDictLinks file and all entries 
# in addDictLinks have keywords in dictosis. If the difference 
# is only in capitalization, and all the OSIS file's keywords are unique 
# according to a case-sensitive comparison, (which occurs when 
# converting from DictionaryWords.txt to CF_addDictLinks.xml) then fix 
# them, update CF_addDictLinks.xml, and return 1. Otherwise return 0.
sub compareDictOsis2DWF {
  my $dictosis = shift; # dictionary osis file to validate entries against
  my $addDictLinks = shift; # CF_addDictLinks.xml file to validate
  
  &Log("\n--- CHECKING ENTRIES IN: $dictosis FOR INCLUSION IN: $addDictLinks\n", 1);
  
  my $osis = $XML_PARSER->parse_file($dictosis);
  my $dwf  = $XML_PARSER->parse_file($addDictLinks);
  
  my $osismod = &getOsisRefWork($osis);
  
  # Decide if keyword any capitalization update is possible or not
  my $allowUpdate = 1; my %noCaseKeys;
  foreach my $es ($XPC->findnodes('//osis:seg[@type="keyword"]/text()', $osis)) {
    if ($noCaseKeys{lc($es)}) {
      &Note("Will not update case-only discrepancies in $addDictLinks.");
      $allowUpdate = 0;
      last;
    }
    $noCaseKeys{lc($es)}++;
  }

  my $update = 0;
  my $allmatch = 1;
  my @dwfOsisRefs = $XPC->findnodes('//dw:entry/@osisRef', $dwf);
  my @dictOsisIDs = $XPC->findnodes('//osis:seg[@type="keyword"][not(ancestor::osis:div[@subType="x-aggregate"])]/@osisID', $osis);
  
  # Check that all DICTMOD keywords (except NAVEMNU keywords) are included as entries in addDictLinks
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
        &Warn("DICT mod keyword and CF_addDictLinks.xml entry name are identical, but osisID != osisRef. UPDATING CF_addDictLinks.xml osisRef from $origOsisRef to $osisID", "<>This happens when an old version of CF_addDictLinks.xml is being upgraded. Otherwise, there could be bug or some problem with this osisRef.");
        last;
      }
    }
    if (!$match) {&Warn("Missing entry \"$osisID\" in $addDictLinks", "That you don't want any links to this entry."); $allmatch = 0;}
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
          &Warn("Extra entry with osisRef=\"$osisRef\" in $addDictLinks", 
          "Remove references to $osisRef from $addDictLinks if target does not appear in $DICTMOD.");
        }
        $reported{$osisRef}++;
        $allmatch = 0;
      }
    }
  }
  
  # Check that aggregated entries are not targeted by CF_addDictLinks.xml
  foreach my $e ($XPC->findnodes('//@osisID
      [ancestor::osis:div[@type="glossary"][@subType="x-aggregate"]]', $osis)) {
    my $osisRef = $DICTMOD.':'.$e->value;
    my $entry = @{$XPC->findnodes("//dw:entry[\@osisRef='$osisRef']", $dwf)}[0];
    if ($entry) {
      &Error(
"Cannot reference aggregated glossary entry in $addDictLinks:\n<entry osisRef=\"".$entry->getAttribute('osisRef')."\">",
"Append .dupN to the osisRef, where N is the specific number of a duplicate to be referenced.");
    }
  }
  
  # Save any updates back to source addDictLinks
  if ($update) {
    &writeXMLFile($dwf, "$addDictLinks.tmp");
    unlink($addDictLinks); rename("$addDictLinks.tmp", $addDictLinks);
    &Note("Updated $update entries in $addDictLinks");
  }
  elsif ($allmatch) {&Log("All entries are included.\n");}
  
  return ($update ? 1:0);
}


# Brute force validation of dwf returns 1 on successful validation, 0 otherwise
sub validateAddDictLinksXML {
  my $dwf = shift;
  
  my @entries = $XPC->findnodes('//dw:entry[@osisRef]', $dwf);
  foreach my $entry (@entries) {
    my @dicts = split(/\s+/, $entry->getAttribute('osisRef'));
    foreach my $dict (@dicts) {
      if ($dict !~ s/^(\w+):.*$/$1/) {&Error("osisRef \"$dict\" has no target module", "Add the dictionary module name followed by ':' to the osisRef value.");}
    }
  }
  
  my $success = 1;
  my $x = "//*";
  my @allowed = ('addDictLinks', 'div', 'entry', 'name', 'match');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badElem = $XPC->findnodes($x, $dwf);
  if (@badElem) {
    foreach my $ba (@badElem) {
      &Error("Bad CF_addDictLinks.xml element: \"".$ba->localname()."\"", "Only the following elements are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//*[local-name()!='addDictLinks'][local-name()!='entry']/@*";
  @allowed = ('onlyNewTestament', 'onlyOldTestament', 'context', 'notContext', 'multiple', 'osisRef', 'XPATH', 'notXPATH', 'version', 'dontLink', 'notExplicit', 'onlyExplicit');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("\nBad CF_addDictLinks.xml attribute: \"".$ba->localname()."\"", "Only the following attributes are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//dw:entry/@*";
  push(@allowed, ('osisRef', 'noOutboundLinks'));
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("Bad CF_addDictLinks.xml entry attribute: \"".$ba->localname()."\"", "The entry element may contain these attributes: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  return $success;
}


# Takes an <index index="Glossary"/> element and converts it
# into a glossary reference, recording the results.
sub explicitGlossaryIndexes {
  my $indexElement = shift;
  
  my @result;
  if (&usfm3GetAttribute($indexElement->getAttribute('level1'), 'lemma', 'lemma')) {
    push(@result, &glossaryLink($indexElement));
  }
  else {
    push(@result, @{&searchForGlossaryLinks($indexElement)});
  }
  
  # Now record the results for later reporting
  foreach my $r (@result) {
    if ($r->nodeName eq 'reference') {
      my %data = (
        'success' => 1, 
        'linktext' => $r->textContent, 
        'osisRef' => $r->getAttribute('osisRef')
      );
      push(@EXPLICIT_GLOSSARY, \%data);
    }
    else {
      # Report either level1 if it was specified, or else context
      my $report = $r->getAttribute('level1');
      
      if (!$report) {
        my $infoP = &getIndexInfo($r, 1);
        if ($infoP) {
          $report = $infoP->{'previousNode'}->data;
          $report =~ s/^.*?(.{32})$/>$1/s;
          $report .= "[*]";
          if ($infoP->{'followingNode'}) {
            my $cr = $infoP->{'followingNode'}->data;
            $cr =~ s/^(.{32}).*?$/$1</;
            $report .= $cr;
          }
        }
        $report =~ s/[\s\n]+/ /g;
      }
      
      my %data = ('success' => 0, 'linktext' => $report);
      push(@EXPLICIT_GLOSSARY, \%data);
      
      &Error(@{&atomizeContext(&getNodeContext($r))}[0]." Failed to link explicit glossary reference: $report", 
"<>Add the proper entry to CF_addDictLinks.xml to match this text 
and create a hyperlink to the correct glossary entry. If desired you can 
use the attribute 'onlyExplicit' to match this term only where it is 
explicitly marked in the text as a glossary index, and nowhere else. 
Without the onlyExplicit attribute, you are able to hyperlink the term 
everywhere it appears in the text.");
  
      # Leave the unhandled index element as it was since it was in the source
      #$r->unbindNode();
    }
  }
}


# Convert <index index="Glossary" level="link text|lemma='keyword'"/>.
# Returns the new reference element if successful or the unchanged
# index element otherwise.
sub glossaryLink {
  my $i = shift;
  
  my $infoP = &getIndexInfo($i);
  if (!defined($infoP)) {return $i;}
  
  my $linktext = $infoP->{'linktext'};

  if (!$linktext) {
    &Error("Could not determine link text for index ".$i->toString());
    return $i;
  }
  
  # Create the reference
  my $beforeText = $i->parentNode->textContent;
  my $t_new = $infoP->{'previousNode'}->data; 
  $t_new =~ s/^(.*)\Q$linktext\E$/$1/;
  my $osisRef = $DICTMOD.':'.&encodeOsisRef($infoP->{'lemma'});
  
  # Handle any USFM attributes effecting the target
  if (defined($infoP->{'dup'})) {$osisRef .= '.dup'.$infoP->{'dup'};}
  elsif (defined($infoP->{'context'})) {
    # Look at the specified context in CF_addDictLinks.xml for the lemma
    my $r = @{$XPC->findnodes("//dw:entry
      [ancestor-or-self::*[\@context][1][\@context='$infoP->{'context'}']]
      /\@osisRef[starts-with(., '$osisRef.dup') or . = '$osisRef']", &getDWF())}[0];
    if ($r) {$osisRef = $r->value;}
    else {&Error(
"An entry '$osisRef' having context '$infoP->{'context'}' could not be found in CF_addDictLinks.xml.",
"CF_addDictLinks.xml does not contain an entry for lemma '$infoP->{'lemma'}' which has context '$infoP->{'context'}' as specified by the \\w ...\\w* tag.");
    }
  }
  
  my $newRefElement = $XML_PARSER->parse_balanced_chunk(
    "<reference $ONS osisRef='$osisRef' type='".($MOD eq $MAINMOD ? 'x-glossary':'x-glosslink')."'>$linktext</reference>"
  );
  $i->parentNode->insertBefore($newRefElement, $i);
  my $ref = $i->previousSibling;
  $infoP->{'previousNode'}->setData($t_new);
  $i->parentNode->removeChild($i);
  
  if ($beforeText ne $ref->parentNode->textContent) {
    &ErrorBug("Explicit glossary linking changed the source text: ".$infoP->{'linktext'}."\nBEFORE: $beforeText\nAFTER : ".$ref->parentNode->textContent);
  }
  
  if ($infoP->{'x-subType'}) {
    $ref->setAttribute('subType', $infoP->{'x-subType'});
  }
  
  $LINK_OSISREF{$osisRef}{'context'}{@{&atomizeContext(&getNodeContext($ref))}[0]}++;
  $LINK_OSISREF{$osisRef}{'matched'}{$linktext}++;
  $LINK_OSISREF{$osisRef}{'total'}++;

  return $ref;
}


# Search a node for glossary links according to CF_addDictLinks.xml. The 
# only handled node types are element, text, or <index index="Glossary"/>. 
# An array is returned containing a list of the new reference elements 
# that were added.
my %NoOutboundLinks;
sub searchForGlossaryLinks {
  my $node = shift; # non text-node child elements will not be modified

  if ($node->nodeType != XML::LibXML::XML_TEXT_NODE &&
      $node->nodeType != XML::LibXML::XML_ELEMENT_NODE) {
    &ErrorBug("Node is not a text or element node.", 1);
  }

  my $isIndex = ($node->nodeName eq 'index' && $node->getAttribute('index') eq 'Glossary');
  
  # If this node is in a glossary, get the glossary info
  my $glossary;
  if (&isDict($node)) {
    
    $glossary->{'node_context'} = @{&atomizeContext(&getNodeContext($node))}[0];
    if (!$glossary->{'node_context'}) {next;}
    
    my @gs; foreach my $gsp ( split(/\s+/, &getGlossaryScopeAttribute($node)) ) {
      push(@gs, ($gsp =~ /\-/ ? @{&scopeToBooks($gsp, &getOsisVersification($node))}:$gsp));
    }
    $glossary->{'scopes_context'} = join('+', @gs);
    
    if (!$NoOutboundLinks{'haveBeenRead'}) {
      foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', &getDWF())) {
        foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
      }
      $NoOutboundLinks{'haveBeenRead'}++;
    }
    if ($NoOutboundLinks{&entry2osisRef($MOD, $glossary->{'node_context'})}) {next;}
  }

  my $container = ($isIndex || $node->nodeType == XML::LibXML::XML_TEXT_NODE ? $node->parentNode:$node);
  
  # Never put links in a keyword element
  if ($glossary && $XPC->findnodes("self::osis:seg[\@type='keyword']", $container)) {next;}
  
  my @refs;
  if ($isIndex) {
    push(@refs, &searchGlossaryLinkAtIndex($node, $glossary));
  }
  else {
    # Get all text nodes to which to add glossary links
    my @textNodes;
    if ($node->nodeType == XML::LibXML::XML_TEXT_NODE) {push(@textNodes, $node);}
    else {@textNodes = $XPC->findnodes('child::text()', $container);}
    foreach my $textnode (@textNodes) {
      push(@refs, @{&searchGlossaryLinksInTextNode($textnode, $glossary)});
    }
  }
  
  return \@refs;
}


# Take an index element and search for a glossary link to replace it 
# with. Text node siblings of the index element are shortened as needed
# to account for the new glossary link's child text. Either the new
# reference element is returned on success or the indexElement on
# failure.
sub searchGlossaryLinkAtIndex {
  my $indexElement = shift;
  my $glossaryHP = shift;
  my $bidir = shift; # search before and after the index for a match

  my $original = $indexElement->parentNode->textContent;
  
  my $infoP = &getIndexInfo($indexElement);
  if (!defined($infoP)) {
    return $indexElement;
  }
  
  my @unbindOnSuccess;
  my $removeOnSuccess;
  
  my $match;
  my $context;
  my $expcon = &conf('ARG_explicitContext'); # left, right or both
  if (!$expcon && $infoP->{'linktext'}) {
    $context = $infoP->{'linktext'};
    # If we have linktext then only the linktext is searched, and the
    # preceding text node must end with the link text.
    $removeOnSuccess = $context;
    $match = &searchText(\$context, $indexElement, $glossaryHP, length($context));
  }
  else {
    if (!$expcon || $expcon =~ /^(left|both)$/) {
      $context = $infoP->{'previousNode'}->data;
      push(@unbindOnSuccess, $infoP->{'previousNode'});
    }
    my $index = length($context);
    if ($infoP->{'followingNode'} && (
        (!$expcon && $bidir) || 
        $expcon =~ /^(right|both)$/)) {
      $context .= $infoP->{'followingNode'}->data;
      push(@unbindOnSuccess, $infoP->{'followingNode'});
    }
    $match = &searchText(\$context, $indexElement, $glossaryHP, $index);
  }
  
  if (!$match) {
    # If unidirectional search failed, try bi-directional
    if (!$infoP->{'linktext'} && !$bidir) {
      return searchGlossaryLinkAtIndex($indexElement, $glossaryHP, 1);
    }
    
    return $indexElement;
  }
  
  # Now update the tree with the new reference
  my $r = @{&applyReferenceTags($context, $indexElement)}[0];
  
  # Fix up the text nodes surrounding the new reference
  foreach my $n (@unbindOnSuccess) {$n->unbindNode();}
  if ($removeOnSuccess) {
    my $t = $infoP->{'previousNode'}->data;
    $t =~ s/\Q$removeOnSuccess\E$//;
    $infoP->{'previousNode'}->setData($t);
  }
  
  if ($infoP->{'x-subType'}) {
    $r->setAttribute('subType', $infoP->{'x-subType'});
  }
  
  # Finally, sanity check that our textContent is unchanged
  if ($r->parentNode->textContent ne $original) {
    &ErrorBug("Text was changed while replacing index with glossary link:
WAS: $original
IS : ".$r->parentNode->textContent, 1);
  }
  
  return $r;
}


# Take a text node, and search for reference links in it. In the 
# process, the text node may be split into multiple text nodes, with 
# reference tags in appropriate places. Returns a list containing
# either the new reference elements on success or the original text node
# on failure.
sub searchGlossaryLinksInTextNode {
  my $textnode = shift;
  my $glossaryHP = shift;
  
  my $original = $textnode->parentNode->toString();

  my $text = $textnode->data();
  if ($text =~ /^\s*$/) {next;}
  my $done;
  do {
    $done = 1;
    my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
    foreach my $part (@parts) {
      if ($part =~ /<reference.*?<\/reference[^>]*>/ || $part =~ /^[\s\n]*$/) {next;}
      if (my $matchedPattern = &searchText(\$part, $textnode, $glossaryHP)) {
        $done = 0;
      }
    }
    $text = join('', @parts);
  } while(!$done);
  $text =~ s/<reference [^>]*osisRef="REMOVE_LATER"[^>]*>(.*?)<\/reference>/$1/sg;
  
  # Sanity check that the only modification was the addition of <reference> tags
  my $check = $text;
  $check =~ s/<\/?reference[^>]*>//g;
  if ($check ne $textnode->data()) {
    &ErrorBug("Bible text changed during glossary linking!\nBEFORE=".$textnode->data()."\nAFTER =$check", 1);
  }
  
  return &applyReferenceTags($text, $textnode); 
}

# Replace any $node in the document tree with new nodes that are created
# by rendering the $referenceMarkup string. This string can only contain
# text and <reference> tags. An array is returned containing the new 
# reference elements.
sub applyReferenceTags {
  my $referenceMarkup = shift;
  my $node = shift;
  
  # apply new reference tags back to DOM
  my @refs;
  foreach my $childnode (split(/(<reference[^>]*>.*?<\/reference[^>]*>)/s, $referenceMarkup)) {
    my $newRefElement = '';
    my $t = $childnode; 
    if ($t =~ s/(<reference[^>]*>)(.*?)(<\/reference[^>]*>)/$2/s) {
      my $refelem = "$1 $3";
      $newRefElement = $XML_PARSER->parse_balanced_chunk($refelem);
    }
    my $newTextNode = XML::LibXML::Text->new($t);
    if ($newRefElement) {
      $newRefElement->firstChild->insertBefore($newTextNode, undef);
      $newRefElement->firstChild->removeChild($newRefElement->firstChild->firstChild); # remove the originally necessary ' ' in $refelem 
    }
    
    my $newChildNode = ($newRefElement ? $newRefElement:$newTextNode);
    $node->parentNode->insertBefore($newChildNode, $node);
    if ($newRefElement) {push(@refs, $node->previousSibling);}
  }
  $node->unbindNode();
  
  return \@refs;
}

# Searches $$textP and adds a single reference glossary link according 
# to the context of $node (and $glossaryHP) and the CF_addDictLinks.xml 
# file. If a match to a glossary keyword is not found, the empty string 
# is returned and $$textP is left unmodified. If a match is found, the 
# matching pattern is returned, and a <reference> and </reference> tag
# will be inserted into $$textP at the appropriate places. The $index
# argument must be defined for explicit glossary link searches. When 
# $index is defined, any match will be further restricted so that the 
# linktext must include the index position (which may be 0).
our (@MATCHES, $OT_CONTEXTSP, $NT_CONTEXTSP, $LAST_CONTEXT, %MULTIPLES, 
    %MATCHES_USED, %EntryHits, @DICT_DEBUG_THIS, @DICT_DEBUG);
sub searchText {
  my $textP = shift; # the string to search
  my $node = shift;  # only used to get context information
  my $glossaryHP = shift;
  my $index = shift; # MUST be defined for ALL explicit index searches

  my $matchedPattern = '';
  
  # Cache match related info
  if (!@MATCHES) {
    my $debug;
    $OT_CONTEXTSP =  &getContextAttributeHash('OT');
    $NT_CONTEXTSP =  &getContextAttributeHash('NT');
    foreach my $m ($XPC->findnodes('//dw:match', &getDWF())) {
      my %minfo;
      if (!&matchRegex($m, \%minfo)) {next;}
      $minfo{'node'} = $m;
      $minfo{'notExplicit'} = &attributeContextValue('notExplicit', $m);
      $minfo{'onlyExplicit'} = &attributeContextValue('onlyExplicit', $m);
      $minfo{'onlyOldTestament'} = &attributeIsSet('onlyOldTestament', $m);
      $minfo{'onlyNewTestament'} = &attributeIsSet('onlyNewTestament', $m);
      $minfo{'dontLink'} = &attributeIsSet('dontLink', $m);
      $minfo{'context'} = &getScopedAttribute('context', $m);
      $minfo{'contexts'} = &getContextAttributeHash($minfo{'context'}, \$debug);
      $minfo{'notContext'} = &getScopedAttribute('notContext', $m);
      $minfo{'notContexts'} = &getContextAttributeHash($minfo{'notContext'}, \$debug);
      $minfo{'notXPATH'} = &getScopedAttribute('notXPATH', $m);
      $minfo{'XPATH'} = &getScopedAttribute('XPATH', $m);
      $minfo{'osisRef'} = @{$XPC->findnodes('ancestor::dw:entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
      $minfo{'name'} = @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent;
      $minfo{'multiple'} = @{$XPC->findnodes("ancestor-or-self::*[\@multiple][1]/\@multiple", $m)}[0]; 
      if (!$minfo{'multiple'}) {
        $minfo{'multiple'} = 'entry-name';
      }
      else {
        my $v = $minfo{'multiple'}->value;
        $minfo{'multiple'} = ($v eq 'false' ? 'entry-name':$v);
      }
      $minfo{'key'} = ($minfo{'multiple'} eq 'match' ? $minfo{'node'}->unique_key:$minfo{'name'});
      # A <match> element should never be applied to any textnode inside 
      # the glossary entry (or entries) which the match pertains to or 
      # any duplicate entries thereof. This is necessary to insure an 
      # entry will never contain links to itself or to a duplicate.
      foreach my $r (split(/\s+/, @{$XPC->findnodes('ancestor::dw:entry[1]', $m)}[0]->getAttribute('osisRef'))) {
        $minfo{'skipRootID'}{&getRootID($r)}++;
      }
      
      push(@MATCHES, \%minfo);
    }
    #if ($debug) {&Log("\n".('-' x 80)."\n".('-' x 80)."\n\n$notes\n");}
    #&Log(Dumper(\@MATCHES)."\n");
  }
  
  my $context;
  my $multiples_context;
  # After every context change, %MULTIPLES is cleared. Options for the
  # multiple attribute value are:
  #  'false' - Allow an entry name to link once per context.
  #  'match' - Allow a match element to be used once per context.
  #  'true'  - No limitation on number of links.
  # The $contextNoteKey var allows a link within a note, even if it was
  # already linked in the given context.
  if ($glossaryHP->{'node_context'}) {
    $context = $glossaryHP->{'node_context'}; 
    $multiples_context = $glossaryHP->{'node_context'};
  }
  else {
    $context = &bibleContext($node);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {
    undef %MULTIPLES; 
    &Log("--> $multiples_context\n", 2);
  }
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &inContext($context, $OT_CONTEXTSP);
  my $contextIsNT = &inContext($context, $NT_CONTEXTSP);
  my $contextNoteKey = @{$XPC->findnodes("ancestor::osis:note", $node)}[0];
  $contextNoteKey = ($contextNoteKey ? $contextNoteKey->unique_key:'');
  
#@DICT_DEBUG = ($$textP); @DICT_DEBUG_THIS = (decode("utf8", "Такаббурлик ва мағрурлик ҳақида"));
  &dbg("DEBUGGING searchText() is on...\n");
  
  my $a;
  foreach my $m (@MATCHES) {
    my $removeLater = $m->{'dontLink'};
    my $key = $m->{'key'}.$contextNoteKey;
#@DICT_DEBUG = ($context, @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m->{'node'})}[0]->textContent()); @DICT_DEBUG_THIS = ("Gen.49.10.10", decode("utf8", "АҲД САНДИҒИ"));
    if (defined($index) && $m->{'notExplicit'} && ($m->{'notExplicit'} == 1 || &inContext($context, $m->{'notExplicit'}))) {
      &dbg("filtered at 00\n\n"); next;
    }
    elsif (!defined($index) && $m->{'onlyExplicit'} && ($m->{'onlyExplicit'} == 1 || &inContext($context, $m->{'onlyExplicit'}))) {
      &dbg("filtered at 01\n\n"); next;
    }
    else {
      if ($glossaryHP->{'node_context'} && $m->{'skipRootID'}{&getRootID($glossaryHP->{'node_context'})}) {
        &dbg("05\n\n"); next; # never add glossary links to self
      }
      if (!$contextIsOT && $m->{'onlyOldTestament'}) {&dbg("filtered at 10\n\n"); next;}
      if (!$contextIsNT && $m->{'onlyNewTestament'}) {&dbg("filtered at 20\n\n"); next;}
      if (!defined($index) && $m->{'multiple'} ne 'true' && $MULTIPLES{$key}) {
        # $removeLater disallows links within any phrase that was previously skipped as a multiple.
        # This helps prevent matched, but unlinked, phrases inadvertantly being torn into smaller, likely irrelavent, entry links.
        &dbg("filtered at 40\n\n"); $removeLater = 1;
      }
      if ($m->{'context'}) {
        my $gs  = ($glossaryHP->{'scopes_context'} ? 1:0);
        my $ic  = &inContext($context, $m->{'contexts'});
        my $igc = ($gs ? &inContext($glossaryHP->{'scopes_context'}, $m->{'contexts'}):0);
        if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {
          &dbg("filtered at 50 (gs=$gs, ic=$ic, igc=$igc)\n\n");
          next;
        }
      }
      if ($m->{'notContext'}) {
        if (&inContext($context, $m->{'notContexts'})) {&dbg("filtered at 60\n\n"); next;}
      }
      if ($m->{'XPATH'}) {
        my $tst = @{$XPC->findnodes($m->{'XPATH'}, $node)}[0];
        if (!$tst) {&dbg("filtered at 70\n\n"); next;}
      }
      if ($m->{'notXPATH'}) {
        my $tst = @{$XPC->findnodes($m->{'notXPATH'}, $node)}[0];
        if ($tst) {&dbg("filtered at 80\n\n"); next;}
      }
    }
    
    my $is; my $ie;
    if (!&searchMatch($m, $textP, \$is, \$ie, $index)) {
      next;
    }
    if ($is == $ie) {
      &ErrorBug("Match result was zero width!: \"".$m->{'node'}->textContent."\"");
      next;
    }
    
    $MATCHES_USED{$m->{'node'}->toString()}++;
    $matchedPattern = $m->{'node'}->textContent;
    my $osisRef = ($removeLater ? 'REMOVE_LATER':$m->{'osisRef'});
    my $attribs = "osisRef=\"$osisRef\" type=\"".($MOD eq $MAINMOD ? 'x-glossary':'x-glosslink')."\"";
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

      if ($m->{'multiple'} ne 'true') {$MULTIPLES{$key}++;}
    }
    
    last;
  }
  
  &dbg("LEAVING searchText(): matchedPattern=$matchedPattern\n");
  return $matchedPattern;
}


# Look for a single match $m in $$textP and set start/end positions
# in $$textP if match is found. Returns 1 if a match was found or 
# else 0 if no match was found, or undefined on error. If optional 
# $index is passed, it will be used for matching, to restrict the 
# search to include that particular index (and $itext is only used
# by this function to iteratively perform the $index search).
sub searchMatch {
  my $m = shift;        # the match element to search with
  my $textP = shift;     # pointer to text in which to search
  my $isP = shift;       # will hold index of match start in text
  my $ieP = shift;       # will hold index of match end in text
  my $index = shift;     # index to include if link is explicitly marked
  my $itext = shift;     # only used for recursive index searching
  
  # When the match must include an index point, some setup is required
  # before each new match. The textP is copied, and may be recursively
  # shortened.
  if (defined($index) && !defined($itext)) {
    $itext = $$textP;
  }
  
  # Handle case sensitivity using custom case function
  my $t = (defined($index) ? $itext : $$textP);
  if (exists($m->{'flags'}{'i'})) {$t = &uc2($t);}
  
  # finally do the actual MATCHING...
  my $pm = $m->{'regex'};
  &dbg("pattern match ".($t !~ /$pm/ ? "failed!":"success!").": \"$t\" =~ /$pm/\n"); 
  if ($t !~ /$pm/) {return 0;}

  $$isP = $-[$#+];
  $$ieP = $+[$#+];
  
  # if a (?'link'...) named group 'link' exists, use it instead
  if (defined($+{'link'})) {
    my $i;
    no strict "refs";
    for ($i=0; $i <= $#+; $i++) {
      if ($$i eq $+{'link'}) {last;}
    }
    $$isP = $-[$i];
    $$ieP = $+[$i];
  }
  
  if (defined($index)) {
    # translate isP and ieP from the index text back to textP
    my $clip = length($$textP) - length($itext);
    $$isP += $clip;
    $$ieP += $clip;
     
    # Order must be: isP, index, ieP with isP=index and ieP=index 
    # inclusive. Sometimes punctuation or space appears between the 
    # glossary term and the index element, so allow these chars 
    # between ieP and our index.
    my $ieAdj = $$ieP; while (substr($$textP, $ieAdj, 1) =~ /[\s\P{L}]/) {$ieAdj++;}
    if ( !( ($index - $$isP) >= 0 && ($ieAdj - $index) >= 0 ) ) {
      &dbg("but the match '".substr($$textP, $$isP, ($$ieP-$$isP))."' did not include the index $index\n");
      
      # This match did not include the index, but this match may still 
      # be the correct one, if it happens to match again later in the 
      # string. The only way to know this for certain is to keep short-
      # ening the text and trying again with this same match, until 
      # there is nothing left before the index to test.
      if ($itext !~ s/^\s*\S+//) {return 0;}
      
      if (length($itext) < (length($$textP) - $index)) {
        # This match failed to include the index, even with the 
        # recursive checking.
        return 0;
      }
      
      return &searchMatch($m, $textP, $isP, $ieP, $index, $itext);
    }
  }
  
  &dbg("LINKED: $pm\n$t\n$$isP, $$ieP, '".substr($$textP, $$isP, ($$ieP-$$isP))."'\n");
  
  return 1;
}

sub matchRegex {
  my $matchElem = shift;
  my $infoP = shift;
  
  my $p = $matchElem->textContent;
  if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {
    &ErrorBug("Bad match regex: $p !~ /^\s*\/(.*)\/(\w*)\s*\$/");
    &dbg("80\n");
    return;
  }
  my $pm = $1; my $pf = $2;
  
  # handle PUNC_AS_LETTER word boundary matching issue
  our $PUNC_AS_LETTER;
  if ($PUNC_AS_LETTER) {
    $pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;
  }
  
  # handle xml decodes
  $pm = decode_entities($pm);
  
  # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
  my $pf2 = $pf;
  my $i = ($pf2 =~ s/i//);
  $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;

  # test match a pattern, so any errors with it will be found right away
  if ($pm !~ /(?<!\\)\(.*(?<!\\)\)/) {
    &Error("Skipping match \"$pm\" becauase it is missing capture parentheses", 
    "Add parenthesis around the match text which should be linked.");
    return;
  }
  my $test = "testme";
  if (!defined(eval("\$test =~ /$pm/"))) {
    &Error("Skipping bad match \"$pm\" ($@)");
    return;
  }
  
  # save the regex for later use
  foreach my $f (split(//, $pf)) {
    if ($f eq 'i') { 
      $infoP->{'flags'}{$f}++;
    }
    else {
      &Error("Only the 'i' flag is currently supported: ".$matchElem->textContent."\n");
    }
  }
  $infoP->{'regex'} = $pm;
}

# Print log info for all glossary link searches
sub logDictLinks {

  my $dwf = &getDWF();
  
  &Log("\n");
  
  my %explicits = ('total' => 0, 'total_links' => 0, 'total_fails' => 0, 'maxl' => 0);
  foreach my $h (@EXPLICIT_GLOSSARY) {
    $explicits{'total'}++;
    if ($h->{'success'}) {
      $explicits{'total_links'}++;
      $explicits{'linktext'}{$h->{'linktext'}}{$h->{'osisRef'}}++;
      if ($explicits{'maxl'} < length($h->{'linktext'})) {
        $explicits{'maxl'} = length($h->{'linktext'});
      }
    }
    else {
      $explicits{'total_fails'}++;
      $explicits{'fails'}{$h->{'linktext'}}++;
    }
  }
      
  &Report("Explicitly marked words or phrases that were linked to glossary entries: (". (scalar keys %{$explicits{'linktext'}}) . " variations)");
  foreach my $linktext (sort keys %{$explicits{'linktext'}}) {
    foreach my $osisRef (sort keys %{$explicits{'linktext'}{$linktext}}) {
      &Log(sprintf("%-".$explicits{'maxl'}."s --> %s (%i)\n", 
              $linktext, 
              &osisRef2Entry($osisRef), 
              $explicits{'linktext'}{$linktext}{$osisRef}
          ));
    }
  }
  
  &Report("There were ".(scalar keys %{$explicits{'fails'}})." unique failed explicit entry contexts:");
  foreach my $context (sort { length($b) <=> length($a) } keys %{$explicits{'fails'}}) {
    &Log("$context\n");
  }
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//dw:entry/dw:name/text()', $dwf);
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
  
  &Report("Glossary entries from CF_addDictLinks.xml which have no links in the text: ($numnolink instances)");
  if ($nolink) {
    &Note("You may want to link to these entries using a different word or phrase. To do this, edit the");
    &Log("CF_addDictLinks.xml file.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  
  my @matches = $XPC->findnodes('//dw:match', $dwf);
  my %unused;
  my $total = 0;
  my $mlen = 0;
  foreach my $m (@matches) {
    if ($MATCHES_USED{$m->toString()}) {next;}
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
    else {&Error("No <entry> containing $m in CF_addDictLinks.xml", "Match elements may only appear inside entry elements.");}
  }
  &Report("Unused match elements in CF_addDictLinks.xml: ($total instances)");
  if ($total > 50) {
    &Warn("Large numbers of unused match elements can slow down the parser.", 
"When you are sure they are not needed, and parsing is slow, then you  
can remove unused match elements from CF_addDictLinks.xml by running:
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
text using the match elements found in the CF_addDictLinks.xml file.\n");
  &Report("<-Explicit indexes succesfully converted into glossary links: ".$explicits{'total_links'});
  &Report("<-Removed explicit indexes due to glossary match failure: ".$explicits{'total_fails'});
  &Report("<-Links created: ($grandTotal instances)\n* is textual difference other than capitalization\n$p");
}


# This returns the context surrounding an index milestone, which may 
# be necessary to determine the intended index target. The following 
# situation happens: "This is some Bible text concerning the Ark of 
# the Covenant<index type="Glossary"/>". Looking up the preceding 
# word results in the wrong match: 'Covenant', but using context 
# gives the correct match: 'Ark of the Covenant'. 
sub getIndexInfo {
  my $i = shift; # an index milestone element
  my $quiet = shift;
  
  # Index markers must have a text node as their previous sibling.
  my $prevtext = @{$XPC->findnodes('preceding-sibling::node()[1][self::text()]', $i)}[0];
  if (!$prevtext) {
    if (!$quiet) {
      &Error(@{&atomizeContext(getNodeContext($i))}[0]." Index marker ".$i->toString()." has no preceding text node in:".$i->parentNode->toString);
    }
    return;
  }
  
  my $attribsHP = &usfm3GetAttributes($i->getAttribute('level1'), 'lemma');
  my $lemma = $attribsHP->{'lemma'};
  
  # If linktext is empty, it may be determined later.
  my $linktext = ($i->hasAttribute('level1') ? $i->getAttribute('level1'):'');
  $linktext =~ s/^([^\|]*)\|.*$/$1/; # may have USFM3 attributes that need to be removed
  if (!$linktext || $linktext =~ /^\s*$/) {
    $linktext = $lemma;
  }
  if (!$linktext || $linktext =~ /^\s*$/) {
    $linktext = '';
  }
  
  if ($linktext && $prevtext->data !~ /\Q$linktext\E$/) {
    if (!$quiet) {
      &Error("Index marker preceding text node does not end with the link-text (".$prevtext->data." !~ /\Q$linktext\E\$/).");
    }
    return;
  }
    
  my %info = (
    'linktext' => $linktext,
    'previousNode' => $prevtext,
    'followingNode' => @{$XPC->findnodes('following-sibling::node()[1][self::text()]', $i)}[0]
  );
  
  foreach my $k (sort keys %{$attribsHP}) {
    $info{$k} = $attribsHP->{$k};
  }
  
  #&Log($i->toString()."\n".Dumper(\%info)."\n", 1);
  return \%info;
}


sub getRootID {
  my $osisID = shift;
  
  $osisID =~ s/(^[^\:]+\:|[\.\!]dup\d+$)//g;
  return lc(&decodeOsisRef($osisID));
}


# Converts a comma separated list of Paratext references (which are 
# supported by context and notContext attributes of DWF) and converts
# them into an osisRef. If $paratextRefList is not a valid Paratext 
# reference list, then $paratextRefList is returned unchaged.
my %CONVERTED_P2O;
sub paratextRefList2osisRef {
  my $paratextRefList = shift;
  
  if ($CONVERTED_P2O{$paratextRefList}) {return $CONVERTED_P2O{$paratextRefList};}
  
  my @parts;
  @parts = split(/\s*,\s*/, $paratextRefList);
  my $reportParatextWarnings = (($paratextRefList =~ /^([\d\w]\w\w)\b/ && &bookOsisAbbr($1) ? 1:0) || (scalar(@parts) > 3));
  foreach my $part (@parts) {
    if ($part =~ /^([\d\w]\w\w)\b/ && &bookOsisAbbr($1)) {next;}
    if ($reportParatextWarnings) {
      &Warn("Attribute part \"$part\" might be a failed Paratext reference in \"$paratextRefList\".");
    }
    $CONVERTED_P2O{$paratextRefList} = $paratextRefList;
    return $paratextRefList;
  }
  
  my $p1; my $p2;
  my @osisRefs = ();
  foreach my $part (@parts) {
    my @pOsisRefs = ();
    
    # book-book (assumes Paratext and OSIS verse system's book orders are the same)
    if ($part =~ /^([\d\w]\w\w)\s*\-\s*([\d\w]\w\w)$/) {
      my $bk1 = $1; my $bk2 = $2;
      $bk1 = &bookOsisAbbr($bk1);
      $bk2 = &bookOsisAbbr($bk2);
      if (!$bk1 || !$bk2) {
        $CONVERTED_P2O{$paratextRefList} = $paratextRefList;
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
      # book, book ch, book ch[:.]vs, book ch[:.]vs-lch[:.]lvs, book ch[:.]vs-lvs
      elsif ($part !~ /^([\d\w]\w\w)(\s+(\d+)([\:\.](\d+)(\s*\-\s*(\d+)([\:\.](\d+))?)?)?)?$/) {
        $CONVERTED_P2O{$paratextRefList} = $paratextRefList;
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
      
      my $bk = &bookOsisAbbr($bk);
      if (!$bk) {
        $CONVERTED_P2O{$paratextRefList} = $paratextRefList;
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
        # Warning - this assumes &conf('Versification') is verse system of osisRef  
        &swordVsys(&conf('Versification'), \$canonP, undef, undef, undef);
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
  
  $CONVERTED_P2O{$paratextRefList} = $ret;
  return $ret;
}

sub attributeIsSet {
  my $a = shift;
  my $m = shift;
  
  return scalar(@{$XPC->findnodes("ancestor-or-self::*[\@$a][1][\@$a='true']", $m)});
}

# Reads the given attribute as it applies to node, and returns:
# 0 if 'false' or unset (means no context)
# 1 if 'true' (means any context)
# \% if anything else (means the specified context)
sub attributeContextValue {
  my $a = shift;
  my $node = shift;
  
  my $elem = @{$XPC->findnodes("ancestor-or-self::*[\@$a][1]", $node)}[0];
  
  if (!$elem || $elem->getAttribute($a) eq 'false') {return 0;}
  elsif ($elem->getAttribute($a) eq 'true') {return 1;}
  
  return &getContextAttributeHash($elem->getAttribute($a));
}

sub dbg {
  my $p = shift;

  if (!$DEBUG) {return 0;}
  
  if (!@DICT_DEBUG_THIS) {return 0;}
  for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {
    if (@DICT_DEBUG_THIS[$i] ne @DICT_DEBUG[$i]) {return 0;}
  }
  
  &Debug($p);
  return 1;
}

sub usfm3GetAttributes {
  my $value = shift;
  my $defaultAttribute = shift;
  
  my %attribs;
  if (!$value) {return \%attribs;}
  if ($value !~ /(?<!\\)\|(.*)$/) {return \%attribs;}
  my $as = $1;
  
  my $re = '(\S+)\s*=\s*([\'"])(.*?)(?!<\\\\)\2';
  if ($as =~ /$re/) {
    while ($as =~ s/$re//) {
      $attribs{$1} = &valueClean($3);
    }
    if ($as !~ /^\s*$/) {
      &Error("Parsing USFM3 attributes: $value.",
"Acceptable attributes must have one of these forms:
\\w some-text|attrib1='value' attrib2='value'\\w*
\\w some-text|value\\w* (only for default attribute)");
    }
  }
  else {$attribs{$defaultAttribute} = &valueClean($as);}

  return \%attribs;
}

sub usfm3GetAttribute {
  my $value = shift;
  my $attribute = shift;
  my $defaultAttribute = shift;
  
  return &usfm3GetAttributes($value, $defaultAttribute)->{$attribute};
}

sub valueClean {
  my $value = shift;
  
  $value =~ s/(^\s*|\s*$)//g;
  $value =~ s/[\s\n]+/ /g;
  return $value;
}

sub numAlphaSort {
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
