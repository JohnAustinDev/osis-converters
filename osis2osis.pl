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

# usage: osis2osis.pl [Bible_Directory]

# Run this script to create an OSIS file from a source OSIS file. 
# There are three possible steps in the process:
# 1) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 2) parse and add dictionary links to words 
# which are described in a separate dictionary module. 3) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_osis2osis.txt command 
# file located in the Bible_Directory (see those files for more info). 
# Then check the log file: Bible_Directory/OUT_osis2osis.txt.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common.pl"; &init(__FILE__);

&Log("osis-converters rev: $GITHEAD\n\n");
&Log("\n-----------------------------------------------------\nSTARTING osis2osis.pl\n\n");

$COMMANDFILE = "$INPD/CF_osis2osis.txt";
if (-e $COMMANDFILE) {
  &Log("\n--- READING COMMAND FILE\n");
  &removeRevisionFromCF($COMMANDFILE);
  open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open osis2osis command file $COMMANDFILE\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    # VARIOUS SETTINGS...
    elsif ($_ =~ /^SET_(addScripRefLinks|addDictLinks|addCrossRefs):(\s*(\S+)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
        &Log("INFO: Setting $par to $val\n");
      }
    }
  }
  close(COMF);
  $NOCONSOLELOG = 0;
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

copy($OSISFILE, "$TMPDIR/".$MOD."_1.xml");

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

1;
