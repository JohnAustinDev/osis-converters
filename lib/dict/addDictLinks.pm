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

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, 
    $TMPDIR, $XML_PARSER, $XPC, $MOD_OUTDIR);

my ($REF_SEG_CACHE, %CheckCircular, %ELINKLIST);

sub addDictLinks2Dict {
  my $osisP = shift;
  
  &Log("\n--- ADDING DICTIONARY LINKS TO DICTIONARY MODULE\n-----------------------------------------------------\n\n", 1);
  &Log("READING INPUT FILE: \"$$osisP\".\n");
  
  my @entries = $XPC->findnodes('//dw:entry[@osisRef]', &getDWF());
  
  if (&conf('AddDictLinks') =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
  }
  else {
    &Log("PARSING ".@entries." ENTRIES...\n");
    
    undef($REF_SEG_CACHE);
    
    # Process OSIS dictionary input file (from usfm2osis.py)
    my $xml = $XML_PARSER->parse_file($$osisP);
    
    # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
    foreach (@{$XPC->findnodes('descendant::osis:index[@index="Glossary"]
        [not(ancestor::osis:header)]', $xml)}) {
      &explicitGlossaryIndexes($_);
    }
    
    # must use local-name() = 'reference' here, because added references have no namespace
    foreach my $textNode (@{$XPC->findnodes("//text()[normalize-space()]
      [not(ancestor::*[local-name() = 'reference'])][not(ancestor::osis:header)]", $xml)}) {
      my $resAP = &searchForGlossaryLinks($textNode);
    }
    
    my @keywords = $XPC->findnodes("//osis:seg[\@type='keyword']", $xml);
    &checkCircularEntryCandidates(\@keywords);
   
    &writeXMLFile($xml, $osisP);
    
    if (my $resHP = &checkCircularEntries($$osisP)) {
      my $dwfIsDefault = &isDictDWFDefault(); # check before changing
      my $dxml = $XML_PARSER->parse_file("$MOD_OUTDIR/CF_addDictLinks.dict.xml");
      foreach my $osisRef (sort keys %{$resHP}) {
        my $entry = @{$XPC->findnodes("//dw:entry[\@osisRef='$osisRef']", $dxml)}[0];
        $entry->setAttribute('notContext', ($entry->hasAttribute('notContext') ? $entry->getAttribute('notContext').' ':'').$resHP->{$osisRef});
        &Note("Setting entry $osisRef notContext=\"".$entry->getAttribute('notContext')."\" in $MOD_OUTDIR/CF_addDictLinks.dict.xml");
      }
      &writeXMLFile($dxml, "$MOD_OUTDIR/CF_addDictLinks.dict.xml");
      if ($dwfIsDefault) {&copy("$MOD_OUTDIR/CF_addDictLinks.dict.xml", "$DICTINPD/CF_addDictLinks.xml");}
      &Error("Circular entry links were found.", 
($dwfIsDefault ? 
"Run sfm2osis again and these should disappear because the 
circular entries have now been addressed in your ":
"Apply the notContext attributes listed above 
to ") . "CF_addDictLinks.xml file."
      );
    }
    
    &logDictLinks($$osisP);
  }

  &Log("FINISHED\n\n");
}

# If an entry is short and contains only one link, record it because 
# it may read simply: "see other entry" and in this case, the other entry  
# should not link back to this dummy entry. Later on, we can report if 
# the other entry contains such a useless link back to this one.
sub checkCircularEntryCandidates {
  my $keywordsP = shift;
  
  foreach my $kw (@{$keywordsP}) {
    my $entryName = $kw->textContent;
    my $glossaryElement = @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"][1]', $kw)}[0];
    my @allTextNodes = $XPC->findnodes("following::text()", $kw);
    my $i;
    for ($i=0; $i<@allTextNodes; $i++) {
      if ($XPC->findnodes("./parent::osis:seg[\@type='keyword']", @allTextNodes[$i])) {last;}
      my @tge = $XPC->findnodes('./ancestor::osis:div[@type="glossary"][1]', @allTextNodes[$i]);
      if (!@tge || !@tge[0] || !@tge[0]->isSameNode($glossaryElement)) {last;}
    }
    splice(@allTextNodes, $i);
  
    my $text; 
    my $single_osisRef = 0;
    foreach my $t (@allTextNodes) {
      my $e = $t->parentNode();
      if ($XPC->findnodes("self::osis:seg[\@type='keyword']", $e)) {next;}
      $text .= $t->data;
      if ($e->localName eq 'reference' && $e->getAttribute('type') eq 'x-glosslink') {
        my $osisRef = $e->getAttribute('osisRef');
        $single_osisRef = ($single_osisRef == 0 ? $osisRef:undef);
        $ELINKLIST{$entryName} .= $osisRef." ";
      }
    }

    $text =~ s/\s//sg;
    if (length($text) < 80 && $single_osisRef) {
      &Note("circular reference candidate link to \"".&osisRef2Entry($single_osisRef)."\" from short entry \"$entryName\"");
      $CheckCircular{$entryName} = $single_osisRef;
    }
  }
}

sub checkCircularEntries {
  my $out_file = shift;
  
  &Log("\nCHECKING FOR CIRCULAR ENTRIES...\n");
  
  my %circulars;
  foreach my $shortEntryName (sort keys %CheckCircular) {
    my $osisRefShort = &entry2osisRef($MOD, $shortEntryName);
    my $osisRefLong = $CheckCircular{$shortEntryName};
    my $longLinks = $ELINKLIST{&osisRef2Entry($osisRefLong)};
    if (!$longLinks || $longLinks !~ /(^|\s)\Q$osisRefShort\E(\s|$)/) {
      my @a; foreach my $or (split(/\s/, $longLinks)) {if ($or) {push(@a, &osisRef2Entry($or));}}
      &Note("short entry was not circular: ".&osisRef2Entry($osisRefShort)." (target only contains links to: ".(@a ? join(", ", @a):'nothing').")."); 
      next;
    }
    $circulars{$osisRefShort} = $osisRefLong;
  }
  
  my $n = 0; foreach my $k (sort keys %circulars) {$n++;}
  
  &Report("Found $n circular cross references in \"$out_file\".");
  if (!&isDictDWFDefault() && &conf('AddDictLinks') !~ /^check$/i && $n > 0) {
    &Warn(
"The above $n short entries only say: \"See longer entry\".", 
"In most such cases the long entry should not link back to the short 
entry. These circular references can be eliminated with the following
'notContext' attributes added to CF_addDictLinks.xml, like this:");
    foreach my $osisRefShort (sort keys %circulars) {
      my $osisRefLong = $circulars{$osisRefShort};
      &Log("<entry osisRef=\"$osisRefShort\" notContext=\"".$osisRefLong."\">\n");
    }
    &Log("\n");
  }
  
  return (%circulars ? \%circulars:'');
}

# Return true if the current DICT DWF file is same as the current default DICT DWF file
sub isDictDWFDefault {

  return (&shell("diff \"$DICTINPD/CF_addDictLinks.xml\" \"$MOD_OUTDIR/CF_addDictLinks.dict.xml\"", 3, 1) ? 0:1);
}

1;

