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

# Initialized in /scripts/usfm2osis.pl
our $addDictLinks;

our ($XPC, $XML_PARSER);
our ($SCRD, $INPD, $LOGFILE, $TMPDIR, $SCRIPT_NAME, $NO_FORKS, $DEBUG);

my $REF_SEG_CACHE;

require("$SCRD/scripts/forks/fork_funcs.pl");

sub runAddDictLinks {
  my $osisP = shift;
  
  &Log("\n--- ADDING DICTIONARY LINKS\n-----------------------------------------------------\n", 1);
  &Log("READING OSIS FILE: \"$$osisP\".\n");
  
  if ($addDictLinks =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    return;
  }
  
  undef($REF_SEG_CACHE);
  
  my @files = &splitOSIS($$osisP);
  
  if ($NO_FORKS =~ /\b(1|true|addDictLinks)\b/) {
    &Warn("Running addDictLinks without forks.pl", 
    "Un-set NO_FORKS in the config.conf [system] section to enable parallel processing for improved speed.", 1);
    foreach my $osis (@files) {&adlProcessFile($osis);}
  }
  else {
    # Run adlProcessFile in parallel on each book
    my $ramkb = 440544; # Approx. KB RAM usage per fork
    system(&escfile("$SCRD/scripts/forks/forks.pl") . " " .
      &escfile($INPD) . ' ' .
      &escfile($LOGFILE) . ' ' .
      "\"$DEBUG\"" . ' ' .
      $SCRIPT_NAME . ' ' .
      __FILE__ . ' ' .
      "adlProcessFile" . ' ' .
      "ramkb:$ramkb" . ' ' .
      join(' ', map(&escarg("arg1:$_"), @files))
    );
    &reassembleForkData(__FILE__);
  }

  &joinOSIS($osisP);
  
  &logDictLinks();
}

# This function may be run in its own thread.
sub adlProcessFile {
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
  &writeXMLFile($xml, $osis);
  
  &saveForkData(__FILE__);
}

sub processContainer {
  my $con = shift;
  
  my $name = ($con->nodeName() eq 'osisText' ? 'Bible introduction':($con->getAttribute('type') eq 'bookGroup' ? 'Testament introduction':$con->getAttribute('osisID')));
  
  my $filter = '';
  if ($name eq 'Bible introduction') {$filter = '[not(ancestor-or-self::osis:div[@type=\'bookGroup\']) and not(ancestor-or-self::osis:header)]';}
  elsif ($name eq 'Testament introduction') {$filter = '[not(ancestor-or-self::osis:div[@type=\'book\'])]';}

  # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
  my @glossary = $XPC->findnodes("./descendant::osis:index[\@index='Glossary']$filter", $con);
  &explicitGlossaryIndexes(\@glossary);

  foreach my $e (@{$XPC->findnodes("./descendant::*[local-name() != 'reference']$filter", $con)}) {
    my $refAP = &searchForGlossaryLinks($e);
  }
}

1;
