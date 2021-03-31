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

our ($CONF, $DICTMOD, $MAININPD, $MAINMOD, $MOD, $ONS, $XML_PARSER,
    $XPC, @SUB_PUBLICATIONS);

# Deletes existing header work elements, and writes new ones which
# include, as meta-data, all settings from config.conf. The osis file is 
# overwritten if $osis_or_osisP is not a reference, otherwise a new 
# output file is written and the reference is updated to point to it.
sub writeOsisHeader {
  my $osis_or_osisP = shift;
  
  my $osis = (ref($osis_or_osisP) ? $$osis_or_osisP:$osis_or_osisP); 
  
  &Log("\nWriting work and companion work elements in OSIS header:\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # Both osisIDWork and osisRefWork defaults are set to the current work.
  my @uds = ('osisRefWork', 'osisIDWork');
  foreach my $ud (@uds) {
    my @orw = $XPC->findnodes('/osis:osis/osis:osisText[@'.$ud.']', $xml);
    if (!@orw || @orw > 1) {&ErrorBug("The osisText element's $ud is not being updated to \"$MOD\"");}
    else {
      &Log("Updated $ud=\"$MOD\"\n");
      @orw[0]->setAttribute($ud, $MOD);
    }
  }
  
  # Remove any work elements
  foreach my $we (@{$XPC->findnodes('//*[local-name()="work"]', $xml)}) {
    $we->unbindNode();
  }
  
  my $header;
    
  # Add work element for MAINMOD
  my %workElements;
  &getOSIS_Work($MAINMOD, \%workElements, &searchForISBN($MAINMOD, ($MOD eq $MAINMOD ? $xml:'')));
  # CAUTION: The workElements indexes must correlate to their assignment in getOSIS_Work()
  if ($workElements{'100000:type'}{'textContent'} eq 'Bible') {
    my $v = &conf('Versification');
    $workElements{'190000:scope'}{'textContent'} = 
      &getScopeXML($osis, undef, \$v);
  }
  for (my $x=0; $x<@SUB_PUBLICATIONS; $x++) {
    my $n = 59000;
    $workElements{sprintf("%06i:%s", ($n+$x), 'description')}{'textContent'} = @SUB_PUBLICATIONS[$x];
    $workElements{sprintf("%06i:%s", ($n+$x), 'description')}{'type'} = "x-array-$x-SubPublication";
  }
  my %workAttributes = ('osisWork' => $MAINMOD);
  $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  
  # Add work element for DICTMOD
  if ($DICTMOD) {
    my %workElements;
    &getOSIS_Work($DICTMOD, \%workElements, &searchForISBN($DICTMOD, ($MOD eq $DICTMOD ? $xml:'')));
    my %workAttributes = ('osisWork' => $DICTMOD);
    $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  }
  
  &writeXMLFile($xml, $osis_or_osisP);
  
  return $header;
}

# Search for any ISBN number(s) in the osis file or config.conf.
sub searchForISBN {
  my $mod = shift;
  my $xml = shift;
  
  my %isbns; my $isbn;
  my @checktxt = ($xml ? $XPC->findnodes('//text()', $xml):());
  my @checkconfs = ('About', 'Description', 'ShortPromo', 'TextSource', 'LCSH');
  foreach my $cc (@checkconfs) {push(@checktxt, &conf($cc, $mod));}
  foreach my $tn (@checktxt) {
    if ($tn =~ /\bisbn (number|\#|no\.?)?([\d\-]+)/i) {
      $isbn = $2;
      $isbns{$isbn}++;
    }
  }
  return join(', ', sort keys %isbns);
}

# Write all work children elements for modname to osisWorkP. The modname 
# must be either the value of $MAINMOD or $DICTMOD. In addition to
# writing the standard OSIS work elements, most of the config.conf is 
# also written as description elements, and these config.conf entries
# are written as follows:
# - Config entries which are particular to DICT are written to the 
#   DICT work element. All others are written to the MAIN work element. 
# - Description type attributes contain the section+entry EXCEPT when
#   section is DICT or MAIN (since this is defined by the word element). 
# IMPORTANT: Retreiving the usual context specific config.conf value from 
# header data requires searching both MAIN and DICT work elements. 
sub getOSIS_Work {
  my $modname = shift; 
  my $osisWorkP = shift;
  my $isbn = shift;
 
  my @tm = localtime(time);
  my %type;
  if ($DICTMOD && $modname eq $DICTMOD) {
    $type{'type'} = 'x-glossary'; $type{'textContent'} = 'Glossary';
  }
  elsif (&conf('ProjectType', $modname) eq 'bible') {
    $type{'type'} = 'x-bible'; $type{'textContent'} = 'Bible';
  }
  elsif (&conf('ProjectType', $modname) eq 'childrens_bible') {
    $type{'type'} = 'x-childrens-bible'; $type{'textContent'} = 'Children\'s Bible';
  }
  elsif (&conf('ProjectType', $modname) eq 'commentary') {
    $type{'type'} = 'x-commentary'; $type{'textContent'} = 'Commentary';
  
  }
  my $idf = ($type{'type'} eq 'x-glossary' ? 'Dict':($type{'type'} eq 'x-childrens-bible' ? 'GenBook':($type{'type'} eq 'x-commentary' ? 'Comm':'Bible')));
  my $refSystem = "Bible.".&conf('Versification');
  if ($type{'type'} eq 'x-glossary') {$refSystem = "Dict.$DICTMOD";}
  if ($type{'type'} eq 'x-childrens-bible') {$refSystem = "Book.$modname";}
  my $isbnID = $isbn;
  $isbnID =~ s/[\- ]//g;
  foreach my $n (split(/,/, $isbnID)) {if ($n && length($n) != 13 && length($n) != 10) {
    &Error("ISBN number \"$n\" is not 10 or 13 digits", "Check that the ISBN number is correct.");
  }}
  
  # write OSIS Work elements:
  # element order seems to be important for passing OSIS schema validation for some reason (hence the ordinal prefix)
  $osisWorkP->{'000000:title'}{'textContent'} = ($modname eq $DICTMOD ? &conf('CombinedGlossaryTitle'):&conf('TranslationTitle'));
  &mapLocalizedElem(30000, 'subject', 'Description', $osisWorkP, $modname, 1);
  $osisWorkP->{'040000:date'}{'textContent'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  $osisWorkP->{'040000:date'}{'event'} = 'eversion';
  &mapLocalizedElem(50000, 'description', 'About', $osisWorkP, $modname, 1);
  &mapConfig(50008, 58999, 'description', 'x-config', $osisWorkP, $modname);
  &mapLocalizedElem(60000, 'publisher', 'CopyrightHolder', $osisWorkP, $modname);
  &mapLocalizedElem(70000, 'publisher', 'CopyrightContactAddress', $osisWorkP, $modname);
  &mapLocalizedElem(80000, 'publisher', 'CopyrightContactEmail', $osisWorkP, $modname);
  &mapLocalizedElem(90000, 'publisher', 'ShortPromo', $osisWorkP, $modname);
  $osisWorkP->{'100000:type'} = \%type;
  $osisWorkP->{'110000:format'}{'textContent'} = 'text/xml';
  $osisWorkP->{'110000:format'}{'type'} = 'x-MIME';
  $osisWorkP->{'120000:identifier'}{'textContent'} = $isbnID;
  $osisWorkP->{'120000:identifier'}{'type'} = 'ISBN';
  $osisWorkP->{'121000:identifier'}{'textContent'} = "$idf.$modname";
  $osisWorkP->{'121000:identifier'}{'type'} = 'OSIS';
  if ($isbn) {$osisWorkP->{'130000:source'}{'textContent'} = "ISBN: $isbn";}
  $osisWorkP->{'140000:language'}{'textContent'} = (&conf('Lang') =~ /^([A-Za-z]+)/ ? $1:&conf('Lang'));
  &mapLocalizedElem(170000, 'rights', 'Copyright', $osisWorkP, $modname);
  &mapLocalizedElem(180000, 'rights', 'DistributionNotes', $osisWorkP, $modname);
  $osisWorkP->{'220000:refSystem'}{'textContent'} = $refSystem;

# From OSIS spec, valid work elements are:
#    '000000:title' => '',
#    '010000:contributor' => '',
#    '020000:creator' => '',
#    '030000+:subject' => '',
#    '040000:date' => '',
#    '050000+:description' => '',
#    '060000-090000+:publisher' => '',
#    '100000:type' => '',
#    '110000:format' => '',
#    '120000-121000:identifier' => '',
#    '130000:source' => '',
#    '140000:language' => '',
#    '150000:relation' => '',
#    '160000:coverage' => '',
#    '170000-180000+:rights' => '',
#    '190000:scope' => '',
#    '200000:castList' => '',
#    '210000:teiHeader' => '',
#    '220000:refSystem' => ''
  
  return;
}

sub mapLocalizedElem {
  my $index = shift;
  my $workElement = shift;
  my $entry = shift;
  my $osisWorkP = shift;
  my $mod = shift;
  my $skipTypeAttribute = shift;
  
  foreach my $k (sort {$a cmp $b} keys %{$CONF}) {
    if ($k !~ /^([^\+]+)\+$entry(_([\w\-]+))?$/) {next;}
    my $s = $1;
    my $lang = ($2 ? $3:'');
    if ($mod eq $MAINMOD && $s eq $DICTMOD) {next;}
    elsif ($mod eq $DICTMOD && $s eq $MAINMOD && $CONF->{"$DICTMOD+$entry"}) {next;}
    $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'textContent'} = $CONF->{$k};
    if (!$skipTypeAttribute) {$osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'type'} = "x-$entry";}
    if ($lang) {
      $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'xml:lang'} = $lang;
    }
    $index++;
    if (($index % 10) == 6) {&ErrorBug("mapLocalizedConf: Too many \"$workElement\" language variants.");}
  }
}

sub mapConfig {
  my $index = shift;
  my $maxindex = shift;
  my $elementName = shift;
  my $prefix = shift;
  my $osisWorkP = shift;
  my $modname = shift;
  
  foreach my $fullEntry (sort keys %{$CONF}) {
    if ($index > $maxindex) {&ErrorBug("mapConfig: Too many \"$elementName\" $prefix entries.");}
    elsif ($modname && $fullEntry =~ /DICT\+/ && $modname ne $DICTMOD) {next;}
    elsif ($modname && $fullEntry !~ /DICT\+/ && $modname eq $DICTMOD) {next;}
    elsif ($fullEntry =~ /Title$/ && $CONF->{$fullEntry} =~ / DEF$/) {next;}
    elsif ($fullEntry eq 'system+OUTDIR') {next;}
    else {
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'textContent'} = $CONF->{$fullEntry};
      $fullEntry =~ s/[^\-]+DICT\+//;
      my $xmlEntry = $fullEntry; $xmlEntry =~ s/^$MAINMOD\+//;
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'type'} = "$prefix-$xmlEntry";
      $index++;
    }
  }
}

sub writeWorkElement {
  my $attributesP = shift;
  my $elementsP = shift;
  my $xml = shift;
  
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  $header->appendTextNode("\n");
  my $work = $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work $ONS></work>"), undef);
  
  # If an element would have no textContent, the element is not written
  foreach my $a (sort keys %{$attributesP}) {$work->setAttribute($a, $attributesP->{$a});}
  foreach my $e (sort keys %{$elementsP}) {
    if (!exists($elementsP->{$e}{'textContent'})) {next;}
    $work->appendTextNode("\n  ");
    my $er = $e;
    $er =~ s/^\d+\://;
    my $elem = $work->insertAfter($XML_PARSER->parse_balanced_chunk("<$er $ONS></$er>"), undef);
    foreach my $a (sort keys %{$elementsP->{$e}}) {
      if ($a eq 'textContent') {$elem->appendTextNode($elementsP->{$e}{$a});}
      else {$elem->setAttribute($a, $elementsP->{$e}{$a});}
    }
  }
  $work->appendTextNode("\n");
  $header->appendTextNode("\n");
  
  my $w = $work->toString(); 
  $w =~ s/\n+/\n/g;
  return $w;
}

sub addWorkElements {
  my $osisP = shift;
  my $worksP = shift; # hash pointer whose keys are work IDs for adding
  
  my $xml = $XML_PARSER->parse_file($$osisP);

  foreach (sort keys %{$worksP}) {
    if (@{$XPC->findnodes("//osis:work[\@osisWork='$_']", $xml)}[0]) {next;}
    &addExternalWorkToHeader($_, $xml);
  }
  
  if (keys %{$worksP}) {&writeXMLFile($xml, $osisP);}
}

sub addExternalWorkToHeader {
  my $work = shift;
  my $xml = shift;
  
  my %workAttributes = ('osisWork' => $work);
  my %workElements;
  $workElements{'110000:format'}{'textContent'} = 'text/xml';
  $workElements{'110000:format'}{'type'} = 'x-MIME';
  
  # Look for external work's config.conf
  my $wmain = $work; $wmain =~ s/DICT$//;
  my $extWorkDir = "$MAININPD/../$wmain";
  if (-e "$extWorkDir/config.conf") {
    my $cP = &readProjectConf("$extWorkDir/config.conf");
    my $ptype = $cP->{"$work+ProjectType"};
    my %type;
    if ($work ne $wmain) {
      $type{'type'}        = 'x-glossary'; 
      $type{'textContent'} = 'Glossary';
    }
    elsif ($ptype eq 'bible') {
      $type{'type'}        = 'x-bible';
      $type{'textContent'} = 'Bible';
    }
    elsif ($ptype eq 'childrens_bible') {
      $type{'moddrv'}        = 'x-childrens-bible';
      $type{'textContent'} = 'Children\'s Bible';
    }
    elsif ($ptype eq 'commentary') {
      $type{'type'}        = 'x-commentary';
      $type{'textContent'} = 'Commentary';
    }

    my $refSystem = "Bible.".$cP->{"$wmain+Versification"};
    if ($type{'type'} eq 'x-glossary') {$refSystem = "Dict.$work";}
    if ($type{'type'} eq 'x-childrens-bible') {$refSystem = "Book.$work";}
    
    $workElements{'100000:type'} = \%type;
    $workElements{'140000:language'}{'textContent'} = $cP->{"$wmain+Lang"};
    $workElements{'220000:refSystem'}{'textContent'} = $refSystem;
  }
  else {
    &Error("Referenced external work $work could not be located.");
  }
  
  my $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  &Note("Added work element to header:\n$header");
}

1;
