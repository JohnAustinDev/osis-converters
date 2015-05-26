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

# usage: sfm2imp.pl [Glossary_Directory] 

# Run this script to convert an SFM glossary file into an IMP file
# There are three possible parts of the process: 1) convert the SFM to 
# IMP. 2) parse and add Scripture reference links to glossary entries. 
# 3) parse and add "see-also" links to other entries in the glossary.
#
# Begin by updating the config.conf and CF_paratext2imp.txt command 
# file located in the Glossary_Directory (see those files for more 
# info). Then check the log file: Glossary_Directory/OUT_sfm2imp.txt.

#  IMP wiki: http://www.crosswire.org/wiki/File_Formats#IMP
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$DEBUG = 0;

$INPD = shift;
use File::Spec;
$SCRD = File::Spec->rel2abs(__FILE__);
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl"; 
&init(__FILE__);

&Log("NOTE: sfm2imp.pl (IMP output) is DEPRECATED in preference to sfm2osis.pl (TEI output).\n");

$IS_usfm2osis = 0;

require("$SCRD/scripts/paratext2imp.pl");
&paratext2imp('CF_paratext2imp.txt', "$TMPDIR/".$MOD."_1.imp");

open(AFILE, ">>:encoding(UTF-8)", "$TMPDIR/".$MOD."_1.imp") || die;

&writeDictionaryWordsXML("$TMPDIR/".$MOD."_1.imp", "$OUTDIR/DictionaryWords_autogen.xml");
&compareToDictWordsFile("$TMPDIR/".$MOD."_1.imp");

if ($addScripRefLinks) {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_1.imp", "$TMPDIR/".$MOD."_2.imp");
}
else {rename("$TMPDIR/".$MOD."_1.imp", "$TMPDIR/".$MOD."_2.imp");}

if ($addSeeAlsoLinks) {
  require("$SCRD/scripts/addSeeAlsoLinks.pl");
  &addSeeAlsoLinks("$TMPDIR/".$MOD."_2.imp", $OUTIMP);
}
else {rename("$TMPDIR/".$MOD."_2.imp", $OUTIMP);}

&checkDictReferences($OUTIMP);


