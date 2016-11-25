# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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

sub addSeeAlsoLinks($$) {
  my $in_file = shift;
  my $out_file = shift;
  
  &Log("\n--- ADDING DICTIONARY SEE-ALSO LINKS\n-----------------------------------------------------\n\n", 1);
  &Log("READING INPUT FILE: \"$in_file\".\n");
  &Log("WRITING OUTPUT FILE: \"$out_file\".\n");
  
  my @entries = $XPC->findnodes('//entry[@osisRef]', $DWF);
  
  if ($addDictLinks =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    copy($in_file, $out_file);
  }
  else {
    &Log("PARSING ".@entries." ENTRIES...\n");
    
    # Process OSIS dictionary input file (from usfm2osis.py)
    if ($IS_usfm2osis) {
      my $xml = $XML_PARSER->parse_file($in_file);
      
      # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
      my @glossary = $XPC->findnodes(".//osis:index[\@index='Glossary'][\@level1]", $xml);
      &convertExplicitGlossaryElements(\@glossary);
      
      my @entryStarts = $XPC->findnodes("//$KEYWORD", $xml);
      my $bookOrderP; &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
      for (my $i=0; $i<@entryStarts; $i++) {
        &processEntry(@entryStarts[$i]->textContent(), \$i, \@entryStarts, &scopeToBooks(&getGlossaryScope(@entryStarts[$i]), $bookOrderP));
      }
      open(OUTF, ">$out_file") or die "Could not open $out_file.\n";
      print OUTF $xml->toString();
      close(OUTF);
    }
    
    # Or process IMP dictionary input file
    else {
      my $entryName, %entryText, @entryOrder;
      open(INF, "<:encoding(UTF-8)", $in_file) or die "Could not open $in_file.\n";
      while(<INF>) {
        if ($_ =~ /^\s*$/) {next;}
        elsif ($_ =~ /^\$\$\$\s*(.*)\s*$/) {$entryName = $1; push(@entryOrder, $entryName);}
        else {$entryText{$entryName} .= $_;}
      }
      close(INF);
      
      open(OUTF, ">$out_file") or die "Could not open $out_file.\n";
      foreach my $entryName (@entryOrder) {
        my $entryElem = $XML_PARSER->parse_balanced_chunk("<entry>$entryText{$entryName}</entry>");
        &processEntry($entryName, \$entryElem);
        print OUTF encode("utf8", "\$\$\$$entryName\n");
        print OUTF &fragmentToString($entryElem, '<entry>'); 
      }
      close(OUTF);
    }
    
    &checkCircularEntries($out_file);
    &logDictLinks();
  }

  &Log("FINISHED\n\n");
}

# $i_or_elem is either an index into a $startsArrayP of entry start tags (as  
# with OSIS files), or else a document fragment containing an entry (as with IMP).
# Either way, this function processes the passed entry.
sub processEntry($$$\@) {
  my $entryName = shift;
  my $i_or_elemP = shift;
  my $startsArrayP = shift;
  my $glossaryScopeP = shift;
  
  my $entryTextNodesP = &getEntryTextNodes($i_or_elemP, $startsArrayP);
  
  # remove text nodes that are within reference elements
  for (my $x=0; $x < @{$entryTextNodesP}; $x++) {
    if (@{$entryTextNodesP}[$x]->parentNode->nodeName() ne 'reference') {next;}
    splice(@{$entryTextNodesP}, $x, 1);
    $x--;
  }
  
  my @parseTextNodes;
  foreach my $e (@$entryTextNodesP) {
    if ($e->parentNode()->localname =~ /^($DICTLINK_SKIPNAMES)$/) {next;}
    push(@parseTextNodes, $e);
  }

  &addDictionaryLinks(\@parseTextNodes, $entryName, $glossaryScopeP);
  
  &checkCircularEntryCandidate($entryName, &getEntryTextNodes($i_or_elemP, $startsArrayP));
}

sub getEntryTextNodes($$) {
  my $i_or_elemP = shift;
  my $startsArrayP = shift;
  
  my @entryTextNodes;
  if (ref($$i_or_elemP) eq "XML::LibXML::DocumentFragment") {
    my $elemP = $$i_or_elemP;
    @entryTextNodes = $XPC->findnodes('descendant-or-self::text()', $elemP);
  }
  else {
    my $i = $$i_or_elemP;
    my @text = $XPC->findnodes('descendant-or-self::text()|following::text()', $startsArrayP->[$i]);
    for (my $j=0; $j<@text && ($i==@$startsArrayP-1 || !@text[$j]->parentNode()->isSameNode($startsArrayP->[$i+1])); $j++) {
      push(@entryTextNodes, @text[$j]);
    }
  }
  
  if ($DEBUG) {foreach my $e (@entryTextNodes) {&Log("getEntryTextNodes = $e\n");}}
  return \@entryTextNodes;
}

# If an entry is short and contains only one link, record it because 
# it may read simply: "see other entry" and in this case, the other entry  
# should not link back to this dummy entry. Later on, we can report if 
# the other entry contains such a useless link back to this one.
sub checkCircularEntryCandidate($\@) {
  my $entryName = shift;
  my $allTextNodesP = shift;

  my $text; 
  my $single_osisRef = 0;
  foreach my $t (@$allTextNodesP) {
    my $e = $t->parentNode();
    if ($IS_usfm2osis && $XPC->findnodes("self::$KEYWORD", $e)) {next;}
    $text .= $t->data;
    if ($e->localName eq 'reference' && $e->getAttribute('type') eq 'x-glosslink') {
      my $osisRef = $e->getAttribute('osisRef');
      $single_osisRef = ($single_osisRef == 0 ? $osisRef:NULL);
      $EntryLinkList{$entryName} .= $osisRef." ";
    }
  }

  $text =~ s/\s//sg;
  if (length($text) < 80 && $single_osisRef) {
    &Log("NOTE: circular reference candidate link to \"".&osisRef2Entry($single_osisRef)."\" from short entry \"$entryName\"\n");
    $CheckCircular{$entryName} = $single_osisRef;
  }

}

sub checkCircularEntries($) {
  my $out_file = shift;
  
  &Log("\nCHECKING FOR CIRCULAR ENTRIES...\n");
  
  my %circulars;
  foreach my $shortEntryName (sort keys %CheckCircular) {
    my $osisRefShort = &entry2osisRef($MOD, $shortEntryName);
    my $osisRefLong = $CheckCircular{$shortEntryName};
    my $longLinks = $EntryLinkList{&osisRef2Entry($osisRefLong)};
    if (!$longLinks || $longLinks !~ /(^|\s)\Q$osisRefShort\E(\s|$)/) {
      my @a; foreach my $or (split(/\s/, $longLinks)) {if ($or) {push(@a, &osisRef2Entry($or));}}
      &Log("NOTE: short entry was not circular: ".&osisRef2Entry($osisRefShort)." (target only contains links to: ".(@a ? join(", ", @a):'nothing').").\n"); 
      next;
    }
    $circulars{$osisRefShort} = $osisRefLong;
  }
  
  my $n = 0; foreach my $k (sort keys %circulars) {$n++;}
  
  &Log("\nREPORT: Found $n circular cross references in \"$out_file\".\n");
  if ($addDictLinks !~ /^check$/i && $n > 0) {
    &Log("NOTE: Some short entries only say: \"See long entry\". In such cases it is\n");
    &Log("often nice if the long entry does not link to the short \"dummy\" entry.\n");
    &Log("These circular references can be eliminated with 'notContext' attributes in $DICTIONARY_WORDS, like this:\n");
    foreach my $osisRefShort (sort keys %circulars) {
      my $osisRefLong = $circulars{$osisRefShort};
      &Log("<entry osisRef=\"$osisRefShort\" notContext=\"".$osisRefLong."\">\n");
    }
  }
}

1;

