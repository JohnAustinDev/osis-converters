# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

our ($TMPDIR, $XML_PARSER, $XPC, %DOCUMENT_CACHE);

# Duplicate an OSIS file as a series of files: one file having all 
# $xpath elements' children removed, and then one for each $xpath 
# element, which has all the other $xpath elements' children removed. 
# This method provides a massive speedup compared to searching or 
# modifying one huge nodeset. It is intended for use with joinOSIS 
# which will reassemble these OSIS files back into one document, after 
# they are searched and/or processed. 
# IMPORTANT: external processing should ONLY modify the one specific 
# element associated with each particular OSIS file, otherwise changes 
# will be lost upon reassembly. This is what splitOSIS_element() is 
# used for, since it returns this modifiable element of a file.
# NOTE: properly handling an element sometimes requires that it be 
# located within its document context, thus cloning is required.
sub splitOSIS {
  my $in_osis = shift;
  my $xpath = shift; 
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]'); # split these out
  
  &Log("\nsplitOSIS: ".&encodePrintPaths($in_osis).":\n", 2);
  
  # splitOSIS uses the same file paths over again and DOCUMENT_CACHE 
  # is keyed on file path!
  undef(%DOCUMENT_CACHE);
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (-e $tmp) {remove_tree("$tmp");}
  make_path("$tmp");
  
  my $xml = $XML_PARSER->parse_file($in_osis);
  
  my @xmls;
  push(@xmls, { 'xml' => $xml, 'file' => &encfile("$tmp/other.osis") });
  
  # First, completely prune other.osis (before any cloning)
  my (%checkID, $x);
  foreach my $e ($XPC->findnodes("//${xpath}[\@osisID]", $xml)) {
    my $osisID = $e->getAttribute('osisID');
    if ($checkID{$osisID}) {&ErrorBug("osisID is not unique: $osisID", 1);}
    $checkID{$osisID}++;
    my $file = sprintf("%s/%03i_%s.osis", $tmp, ++$x, $osisID);
    my $marker = $e->cloneNode();
    $e->replaceNode($marker);
    push(@xmls, { 'element' => $e, 'osisID' => $osisID, 'file' => &encfile($file) });
  }
  
  # Then write OSIS files
  my @files;
  foreach my $xmlP (@xmls) {
    if (!defined($xmlP->{'xml'})) {
      $xmlP->{'xml'} = $xml->cloneNode(1);
      my $marker = @{$XPC->findnodes(
        "//${xpath}[\@osisID='$xmlP->{'osisID'}']", $xmlP->{'xml'})}[0];
      if (!$marker) {&ErrorBug("No marker: $xmlP->{'osisID'}", 1);}
      $marker->replaceNode($xmlP->{'element'});
    }
    &writeXMLFile($xmlP->{'xml'}, $xmlP->{'file'});
    push(@files, $xmlP->{'file'});
  }
  
  return @files;
}

# Take a file created by splitOSIS and return the element which it
# pertains to. This function is used because within the file, only this 
# element may be modified. If an xml pointer is passed, it will point to  
# the file's parsed document node. If $filterP pointer is passed, it
# be written with an xpath filter to be applied to node searches within
# the element (useful when the exact number of changes made is required
# for instance). If $xpath was used when splitOSIS was called, the same 
# value must be passed here.
sub splitOSIS_element {
  my $file = shift;
  my $xml_or_xmlP = shift;
  my $filterP = shift;
  my $xpath = shift;
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]');
  if (ref($filterP)) {$$filterP = '';}
  
  my $xml;
  if (!defined($xml_or_xmlP)) {
    $xml = $XML_PARSER->parse_file($file);
  }
  elsif (ref($xml_or_xmlP)) {
    $xml = $XML_PARSER->parse_file($file);
    $$xml_or_xmlP = $xml;
  }
  
  if ($file =~ /\bother\.osis$/) {
    if (ref($filterP)) {$$filterP = "[not($xpath)]";}
    return $xml->firstChild;
  }
  elsif ($file !~ /\b\d\d\d_([^\.]+)\.osis$/) {
    &Warn("splitOSIS_element is being called on an unsplit OSIS file.");
    return $xml->firstChild;
  }
  my $osisID = $1;
  
  my @e = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $xml)}[0];
  if (!@e[0] || @e > 1) {&ErrorBug("Problem with $osisID in $file", 1);}
  
  return @e[0];
}

# Rejoin the OSIS files previously cloned by splitOSIS(osis, $xpath) and 
# write it to $path_or_pointer using writeXMLFile();
sub joinOSIS {
  my $path_or_pointer = shift;
  my $xpath = shift;
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]');
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (!-e $tmp) {&ErrorBug("No: $tmp", 1);}
  
  if (!opendir(JOSIS, $tmp)) {&ErrorBug("Can't open: $tmp", 1);}
  my @files = readdir(JOSIS); closedir(JOSIS);
  foreach (@files) {$_ = decode('utf8', $_);}
  
  if (!-e "$tmp/other.osis") {&ErrorBug("No: $tmp/other.osis", 1);}
  my $xml = $XML_PARSER->parse_file("$tmp/other.osis");
  
  # Replace each marker with the correct element file's element
  foreach my $f (@files) {
    my $fdec = &decfile($f);
    if ($fdec !~ /\b\d\d\d_([^\.]+)\.osis$/) {next;}
    my $osisID = $1;
    my $exml = $XML_PARSER->parse_file("$tmp/$f");
    my @e = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $exml)};
    if (!@e[0] || @e > 1) {&ErrorBug("Bad element file: $f", 1);}
    @e[0]->unbindNode();
    my @marker = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $xml)};
    if (!@marker[0]) {
      &ErrorBug('No marker: '.$osisID." in $f", 1);
    }
    @marker[0]->replaceNode(@e[0]);
  }
  
  # Save the reassembled document
  &writeXMLFile($xml, $path_or_pointer, undef, 2);
}

1;
