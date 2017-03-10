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
  
  if ($addDictLinks =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    copy($in_file, $out_file);
    return;
  }
  
  my @files = &splitOSIS($in_file);
  foreach my $file (@files) {&processFile($file);}
  &joinOSIS($out_file);

  &logDictLinks();
}

sub processFile($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);

  # bible intro
  my $bibleintro = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  &processContainer($bibleintro);
  
  # testament intros
  my @tstintro = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
  foreach my $tst (@tstintro) {&processContainer($tst);}
  
  # books and book intros
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $book (@books) {&processContainer($book);}
  
  open(OUTF, ">$osis") or die "addDictLinks processFile could not open $osis.\n";
  print OUTF $xml->toString();
  close(OUTF);
}

sub processContainer($) {
  my $con = shift;
  
  my $name = ($con->nodeName() eq 'osisText' ? 'Bible introduction':($con->getAttribute('type') eq 'bookGroup' ? 'Testament introduction':$con->getAttribute('osisID')));
  
  my $filter = '';
  if ($name eq 'Bible introduction') {$filter = '[not(ancestor-or-self::osis:div[@type=\'bookGroup\']) and not(ancestor-or-self::osis:header)]';}
  elsif ($name eq 'Testament introduction') {$filter = '[not(ancestor-or-self::osis:div[@type=\'book\'])]';}

  # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
  my @glossary = $XPC->findnodes(".//osis:index[\@index='Glossary'][\@level1]$filter", $con);
  &convertExplicitGlossaryElements(\@glossary);

  my @elems = $XPC->findnodes(".//*[local-name() != 'reference']$filter", $con);
  &addDictionaryLinks(\@elems, 0);
}

1;
