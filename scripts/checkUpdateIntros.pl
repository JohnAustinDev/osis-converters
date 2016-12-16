# This file is part of "osis-converters".
# 
# Copyright 2016 John Austin (gpl.programs.info@gmail.com)
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

sub checkUpdateIntros($) {
  my $osis = shift;
  
  my %report;
  my $total=0;

  &Log("\n\nChecking introductory material in \"$osis\".\n");

  my $xml = $XML_PARSER->parse_file($osis);
  my @elems = $XPC->findnodes('//*', $xml);
 
  # Report relevant intro elements which are not subType="x-introduction" and make them such.
  # Also add canonical=false as needed.
  my $inIntro = 1;
  for (my $x=0; $x<@elems; $x++) {
    my $elem = @elems[$x];
    if    ($elem->nodeName() eq 'div' && $elem->getAttribute('type') eq 'bookGroup') {$inIntro = 1; next;}
    elsif ($elem->nodeName() eq 'div' && $elem->getAttribute('type') eq 'book') {$inIntro = 1; next;}
    elsif ($elem->nodeName() eq 'chapter' && $elem->getAttribute('osisID') =~ /^[^\.]+\.1\s*$/) {$inIntro = 0; next;}
    elsif (!$inIntro) {next;}
    elsif ($elem->nodeName() !~ /^(title|item|p|l|q)$/) {next;} # these are the introduction elements output by usfm2osis.py:

    if ($XPC->findnodes('ancestor::osis:div[@type="book"][@canonical="true"]', $elem) && !$elem->hasAttribute('canonical')) {
      $elem->setAttribute('canonical', 'false');
    }
    
    # if there are section titles just before chapter 1, these are NOT x-introduction
    if ($elem->nodeName() eq 'title' && &isSectionTitle($elem)) {
      my $n = $x;
      while ((@elems[$n+1]->nodeName() eq 'title' && &isSectionTitle(@elems[$n+1])) ||
          (@elems[$n+1]->nodeName() eq 'div' && @elems[$n+1]->getAttribute('type') =~ /section/i) ||
          @elems[$n+1]->nodeType == XML::LibXML::XML_TEXT_NODE && @elems[$n+1]->data =~ /^[\s\n]*$/) {
        $n++;
      }
      if (@elems[$n+1]->nodeName() eq 'chapter') {
        &Log("NOTE: Section title(s) at end of introduction were left without subType=\"x-introduction\".\n");
        $x = $n;
        next;
      }
    }
    
    if (!$elem->hasAttribute('subType')) {
      $elem->setAttribute('subType', 'x-introduction');
      $report{$elem->nodeName()}++;
      $total++;
    }
    
  }
  
  # titles should be canonical=false unless already explicitly set
  my @tts = $XPC->findnodes('//osis:title[not(@canonical)]', $xml);
  foreach my $tt (@tts) {$tt->setAttribute('canonical', 'false');}
  
  my $t = $xml->toString();
  
  open(OUTF, ">$osis");
  print OUTF $t;
  close(OUTF);
  
  &Log("\nREPORT: $total instance(s) of non-introduction USFM tags used in introductions".($total ? ':':'.')."\n");
  if ($total) {
    &Log("NOTE: Some USFM tags used for introductory material were not proper introduction\n");
    &Log("tags. But these have been handled by adding subType=\"x-introduction\" to resulting\n");
    &Log("OSIS elements, so changes to USFM source are not required.\n");
    foreach my $k (sort keys %report) {
      &Log(sprintf("WARNING: Added subType=\"x-introduction\" to %5i %4s elements.\n", $report{$k}, $k));
    }
  }
}

sub isSectionTitle($) {
  my $t = shift;
  my @p = $XPC->findnodes('parent::osis:div', $t);
  if (!@p) {return 0;}
  if (@p[0]->getAttribute('type') !~ /section/i) {return 0;}
  return @p[0]->firstChild()->isEqual($t);
}

1;
