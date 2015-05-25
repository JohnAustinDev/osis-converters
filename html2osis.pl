#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
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

# usage: html2osis.pl [Project_Directory]

# Run this script to create an OSIS file from source HTML files. 
# There are four possible steps in the process: 1) convert the HTML to 
# OSIS. 2) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 3) parse and add dictionary links to words 
# which are described in a separate dictionary module. 4) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_html2osis.txt command 
# file located in the Project_Directory (see those files for more info). 
# Then check the log file: Project_Directory/OUT_html2osis.txt.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$INPD = shift;
use File::Spec;
$SCRD = File::Spec->rel2abs(__FILE__);
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl"; 
&init(__FILE__);

# run web2osis.pl
$COMMANDFILE = "$INPD/CF_html2osis.txt";
if (-e $COMMANDFILE) {
  require("$SCRD/scripts/web2osis.pl");
  &web2osis($COMMANDFILE, "$TMPDIR/".$MOD."_1.xml");
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

# run addScripRefLinks.pl
if ($addScripRefLinks) {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");
}
else {rename("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");}

# run addDictLinks.pl
if ($addDictLinks) {
  require("$SCRD/scripts/addDictLinks.pl");
  &addDictLinks("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");
  foreach my $dn (values %DictNames) {$allDictNames{$dn}++;}
  foreach my $dn (keys %allDictNames) {
    if ($ConfEntryP->{"DictionaryModule"} !~ /\Q$dn\E/ ) {
      open(CONF, ">>:encoding(UTF-8)", "$CONFFILE") || die "Could not open $CONFFILE\n";
      print CONF "DictionaryModule=$dn\n";
      close(CONF);
    }
  }
}
else {rename("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");}

# run addCrossRefs.pl
if ($addCrossRefs) {
  require("$SCRD/scripts/addCrossRefs.pl");
  &addCrossRefs("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);
}
else {rename("$TMPDIR/".$MOD."_3.xml", $OUTOSIS);}

&validateOSIS($OUTOSIS);
