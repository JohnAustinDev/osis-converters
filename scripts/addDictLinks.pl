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

sub addDictLinks($$) {
  my $in_file = shift;
  my $out_file = shift;
  
  &Log("\n--- ADDING DICTIONARY LINKS\n-----------------------------------------------------\n", 1);
  &Log("READING OSIS FILE: \"$in_file\".\n");
  &Log("WRITING OSIS FILE: \"$out_file\".\n");
  
  my @entries = $XPC->findnodes('//entry[@osisRef]', $DWF);
  
  my $xml = $XML_PARSER->parse_file($in_file);
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  
  # add all dict modules to in_file's osis work header
  my %didDict;
  foreach my $entry (@entries) {
    my @dicts = split(/\s+/, $entry->getAttribute('osisRef'));
    foreach my $dict (@dicts) {
      if ($dict !~ s/^(\w+):.*$/$1/) {&Log("ERROR: osisRef \"$dict\" in \"$INPD/$DefaultDictWordFile\" has no target module\n"); die;}
      if (!$didDict{$dict}) {
        $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work osisWork=\"$dict\"><type type=\"x-glossary\">Glossary</type></work>"), NULL);
      }
      $didDict{$dict}++;
    }
  }
  
  if ($addDictLinks =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    copy($in_file, $out_file);
  }
  else {
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
    foreach my $book (@books) {
      my $bk = $book->getAttribute('osisID');
      
      &Log("Processing $bk\n", 1);
      
      my $skip = $DICTLINK_SKIPNAMES;
      $skip =~ s/([^\|]+(\||$))/self::osis:$1/g;
      
      my @elems = $XPC->findnodes(".//*[not($skip)]", $book);
      &addDictionaryLinks(\@elems);
    }
    
    open(OUTF, ">$out_file") or die "Could not open $out_file.\n";
    print OUTF $xml->toString();
    close(OUTF);

    &logDictLinks();
  }

}

1;
