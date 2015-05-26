#!/usr/bin/perl
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

# usage: sfm2osis.pl [Project_Directory]
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$DEBUG_SKIP_CONVERSION = 0;
$DEBUG = 0;

$INPD = shift;
use File::Spec;
$SCRD = File::Spec->rel2abs(__FILE__);
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl"; 
&init(__FILE__);

if (-e "$INPD/CF_usfm2osis.txt") {
  $IS_usfm2osis = 1;
  require("$SCRD/scripts/usfm2osis.pl");
  &usfm2osis("$INPD/CF_usfm2osis.txt", "$TMPDIR/".$MOD."_1.xml");
}
elsif(-e "$INPD/CF_paratext2osis.txt") {
  $IS_usfm2osis = 0;
  require("$SCRD/scripts/paratext2osis.pl");
  &paratext2osis("$INPD/CF_paratext2osis.txt", "$TMPDIR/".$MOD."_1.xml");
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

# create DictionaryWords_autogen.xml if needed
if ($MODDRV =~ /LD/) {
  &writeDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml", "$OUTDIR/DictionaryWords_autogen.xml");
  &checkDictionaryWordsXML("$TMPDIR/".$MOD."_1.xml");
}

if ($addScripRefLinks) {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");
}
else {copy("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");}

if ($MODDRV =~ /Text/ && $addDictLinks) {
  if (!$DWF) {&Log("ERROR: $DICTIONARY_WORDS is required to run addDictLinks.pl. Copy it from companion dictionary project.\n"); die;}
  else {
    require("$SCRD/scripts/addDictLinks.pl");
    &addDictLinks("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");
  }
}
elsif ($MODDRV =~ /LD/ && $addSeeAlsoLinks) {
  require("$SCRD/scripts/addSeeAlsoLinks.pl");
  &addSeeAlsoLinks("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");
  &checkDictReferences("$TMPDIR/".$MOD."_3.xml");
}
else {copy("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");}

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  if ($addCrossRefs) {
    require("$SCRD/scripts/addCrossRefs.pl");
    &addCrossRefs("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);
  }
  else {copy("$TMPDIR/".$MOD."_3.xml", $OUTOSIS); }

  require("$SCRD/scripts/toVersificationBookOrder.pl");
  &toVersificationBookOrder($VERSESYS, $OUTOSIS);
}
else {copy("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);}

&validateOSIS($OUTOSIS);

