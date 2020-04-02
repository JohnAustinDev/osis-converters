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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();
require("$SCRD/utils/simplecc.pl");
require("$SCRD/scripts/processOSIS.pl");
require("$SCRD/scripts/osis2osis.pl");

# NOTE: CF_osis2osis.txt may contain instructions for both MAINMOD and 
# DICTMOD, but an osis file will only be generated for the MOD on which 
# this script is called.
my $commandFile = "$MAININPD/CF_osis2osis.txt";
if (! -e $commandFile) {&Error("Cannot run osis2osis.pl without a CF_osis2osis.txt command file located at: $MAININPD.", '', 1);}

my $outmod = &runCF_osis2osis('postinit', $MAININPD);
if ($outmod) {&ErrorBug("runCF_osis2osis failed to write OSIS file.", 1);}

$MOD = $outmod;
$INPD = ($outmod =~ /DICT$/ ? $DICTINPD:$MAININPD);
$OSIS = "$TMPDIR/$outmod/$outmod.xml"; # written by runCF_osis2osis() above
if (! -e &getModuleOutputDir($outmod)) {&make_path(&getModuleOutputDir($outmod));}
$OUTOSIS = &getModuleOsisFile($outmod, 'quiet');
&reprocessOSIS($outmod);

if ($NO_OUTPUT_DELETE) {
 # When NO_OUTPUT_DELETE = true, then the following debug code will be run on tmp files previously created by processOSIS.pl
 # YOUR DEBUG CODE GOES HERE 
}

&timer('stop');

;1

