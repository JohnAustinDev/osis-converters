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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/](osis\-converters|vagrant))[\\\/].*?$/$1/; require "$SCRD/scripts/bootstrap.pl";

# if this is a childrens_bible, run the separate cb script
if ($MODDRV =~ /RawGenBook/ && $MOD =~ /CB$/i) {
  &osis_converters("$SCRD/scripts/genbook/childrens_bible/cbsfm2osis.pl", $INPD, $LOGFILE);
  exit;
}

my $CF_usfm2osis = &getDefaultFile(($MODDRV =~ /LD/ ? 'dict':'bible').'/CF_usfm2osis.txt');
if ($CF_usfm2osis) {
  require("$SCRD/scripts/usfm2osis.pl");
  &usfm2osis($CF_usfm2osis, "$TMPDIR/".$MOD."_0.xml");
}
else {&Error("Cannot proceed without a command file: CF_usfm2osis.txt.", "This file is generated automatically in new project directories which are empty except for the 'sfm' directory.", 1);}

if (!$NO_OUTPUT_DELETE) {require("$SCRD/scripts/processOSIS.pl");}
else {
  # debug code to run on previously created output tmp files can be run here when NO_OUTPUT_DELETE = true
}

1;
