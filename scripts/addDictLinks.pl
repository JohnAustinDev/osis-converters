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
  
  my $xml = $XML_PARSER->parse_file($in_file);

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
      
      # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
      my @glossary = $XPC->findnodes(".//osis:index[\@index='Glossary'][\@level1]", $book);
      &convertExplicitGlossaryElements(\@glossary);
      
      my @skips = split(/\|/, $DICTLINK_SKIPNAMES);
      push(@skips, "reference");
      foreach my $skip (@skips) {$skip = "local-name() != '$skip'";}
      my $xpath = ".//*[". join(" and ", @skips) . "]";    
      my @elems = $XPC->findnodes($xpath, $book);
      &addDictionaryLinks(\@elems);
    }
    
    open(OUTF, ">$out_file") or die "Could not open $out_file.\n";
    print OUTF $xml->toString();
    close(OUTF);

    &logDictLinks();
  }

}

1;
