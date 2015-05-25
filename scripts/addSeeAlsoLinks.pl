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
  
  my $dwf = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  my @entries = $XPC->findnodes('//entry[@osisRef]', $dwf);
  
  if ($addDictLinks =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    copy($in_file, $out_file);
  }
  else {
    &Log("PARSING LINKS...\n");
    
    # Process OSIS dictionary input file (from usfm2osis.py)
    if ($IS_usfm2osis) {
      my $xml = $XML_PARSER->parse_file($in_file);
      my $entryStartsP = getOSISEntryStarts($xml);
      for (my $i=0; $i<@$entryStartsP; $i++) {
        &processEntry(getOSISEntryName($entryStartsP->[$i]), $dwf, \$i, $entryStartsP);
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
        &processEntry($entryName, $dwf, \$entryElem);
        print OUTF encode("utf8", "\$\$\$$entryName\n");
        print OUTF &fragmentToString($entryElem, '<entry>'); 
      }
      close(OUTF);
    }
    
    &checkCircularEntries($out_file);
    &logDictLinks($dwf);
  }

  &checkDictOsisRefs($out_file, $dwf);

  &Log("FINISHED\n\n");
}

sub getOSISEntryStarts($) {
  my $xml = shift;
  return $XPC->findnodes("//*[count(descendant::".$KEYWORD.")=1]|".$KEYWORD."[count(../child::".$KEYWORD.")>1]", $xml);
}

sub getOSISEntryName($) {
  my $elem = shift;
  return @{$XPC->findnodes("descendant-or-self::".$KEYWORD, $elem)}[0]->textContent();
}

# $i_or_elem is either an index into a $startsArrayP of entry start tags (as  
# with OSIS files), or else a document fragment containing an entry (as with IMP).
# Either way, this function processes the passed entry.
sub processEntry($$$$) {
  my $entryName = shift;
  my $dwf = shift;
  my $i_or_elemP = shift;
  my $startsArrayP = shift;
  
  my $entryElementsP = &getEntryElements($i_or_elemP, $startsArrayP);
  
  my @parseElems;
  foreach my $e (@$entryElementsP) {
    if ($e->localname =~ /^($DICTLINK_SKIPNAMES)$/) {next;}
    push(@parseElems, $e);
  }

  &addDictionaryLinks(\@parseElems, $dwf, $entryName);
  
  $entryElementsP = &getEntryElements($i_or_elemP, $startsArrayP);
  &checkCircularEntryCandidate($entryName, $entryElementsP);
}

sub getEntryElements($$) {
  my $i_or_elemP = shift;
  my $startsArrayP = shift;
  
  my @entryElements;
  if (ref($$i_or_elemP) eq "XML::LibXML::DocumentFragment") {
    @entryElements = $XPC->findnodes('*', $$i_or_elemP);
  }
  else {
    my $i = $$i_or_elemP;
    my @all = $XPC->findnodes('self::*|following::*', $startsArrayP->[$i]);
    for (my $j=0; $j<@all && ($i==@$startsArrayP-1 || !@all[$j]->isSameNode($startsArrayP->[$i+1])); $j++) {
      push(@entryElements, @all[$j]);
    }
  }
  
  return \@entryElements;
}

# If this entry is short and contains only one link, record it because 
# it may read simply: "see other entry" and in this case, the other entry  
# should not link back to this dummy entry. Later on, we can report if 
# the other entry contains such a useless link back to this one.
sub checkCircularEntryCandidate($\@) {
  my $entryName = shift;
  my $allElemsP = shift;

  my $tlen = 0; 
  my $single_osisRef = 0;
  foreach my $e (@$allElemsP) {
    $tlen += length($e->textContent);
    if ($e->localName eq 'reference' && $e->getAttribute('type') eq 'x-glosslink') {
      my $osisRef = $e->getAttribute('osisRef');
      $single_osisRef = ($single_osisRef == 0 ? $osisRef:NULL);
      $OsisRefLinks{&entry2osisRef($MOD, $entryName)} .= "$osisRef ";
    }
  }

  if ($tlen < 80 && $single_osisRef) {
    &Log("NOTE: circular reference candidate: from \"".&osisRef2Entry($single_osisRef)."\" to \"$entryName\"\n");
    $CheckCircular{$entryName} = $single_osisRef;
  }
}

# Some entries only say: "see blah". In such cases, blah should not 
# link back to the short entry. So report these instances.
sub checkCircularEntries($) {
  my $out_file = shift;
  
  &Log("\nCHECKING FOR CIRCULAR ENTRIES...\n");
  
  my %circulars;
  foreach my $shortEntryName (sort keys %CheckCircular) {
    my $shortEntryOsisRef = &entry2osisRef($MOD, $shortEntryName);
    my $shortEntrySingleLinkOsisRef = $CheckCircular{$shortEntryName};
    my $longLinks = $OsisRefLinks{$shortEntrySingleLinkOsisRef};
    if (!$longLinks || $longLinks !~ /\b\Q$shortEntryOsisRef\E\b/) {&Log("NOT CIRC:$longLinks,$shortEntryOsisRef.\n", 1); next;}
    $circulars{$shortEntrySingleLinkOsisRef} = $shortEntryOsisRef;
  }
  
  my $n = 0; foreach my $k (keys %circulars) {$n++;}
  
  &Log("\nREPORT: Found $n circular cross references in \"$out_file\".\n");
  if ($addDictLinks !~ /^check$/i && $n > 0) {
    &Log("These circular references can be eliminated with 'notContext' attributes in $DICTIONARY_WORDS, like this:\n");
    foreach my $shortEntrySingleLinkOsisRef (sort keys %circulars) {
      my $shortEntryOsisRef = $circulars{$shortEntrySingleLinkOsisRef};
      &Log("<entry osisRef=\"$shortEntryOsisRef\" notContext=\"".$shortEntrySingleLinkOsisRef."\">\n");
    }
  }
}

1;

