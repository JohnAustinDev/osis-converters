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

our ($XPC, $XML_PARSER);
our ($SCRD, $INPD, $LOGFILE, $TMPDIR, $SCRIPT_NAME, $NO_FORKS, $DEBUG);

my $REF_SEG_CACHE;

require("$SCRD/lib/forks/fork_funcs.pm");

sub addDictLinks {
  my $osisP = shift;
  
  &Log("\n--- ADDING DICTIONARY LINKS TO BIBLE MODULE\n-----------------------------------------------------\n", 1);
  &Log("READING OSIS FILE: \"$$osisP\".\n");
  
  if (&conf('AddDictLinks') =~ /^check$/i) {
    &Log("Skipping link parser. Checking existing links only.\n");
    &Log("\n");
    return;
  }
  
  undef($REF_SEG_CACHE);
  
  my @files = &splitOSIS($$osisP);
  
  if ($NO_FORKS =~ /\b(1|true|AddDictLinks)\b/) {
    &Warn("Running addDictLinks without forks.pm", 
    "Un-set NO_FORKS in the config.conf [system] section to enable parallel processing for improved speed.", 1);
    foreach my $osis (@files) {&adlProcessFile($osis);}
  }
  else {
    # Run adlProcessFile in parallel on each book
    my $ramkb = 440544; # Approx. KB RAM usage per fork
    system(
      &escfile("$SCRD/lib/forks/forks.pm") . ' ' .
      &escfile($INPD) . ' ' .
      &escfile($LOGFILE) . ' ' .
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
  
  my $xml;
  my $e = &splitOSIS_element($osis, \$xml);

  # convert any explicit Glossary entries: <index index="Glossary" level1="..."/>
  foreach (@{$XPC->findnodes('descendant::osis:index[@index="Glossary"]
      [not(ancestor::osis:header)]', $e)}) {
    &explicitGlossaryIndexes($_);
  }

  foreach (@{$XPC->findnodes('descendant::*[local-name() != "reference"]
      [not(ancestor-or-self::osis:header)]', $e)}) {
    &searchForGlossaryLinks($_);
  }
  
  &writeXMLFile($xml, $osis);
  
  &saveForkData(__FILE__);
}

1;
