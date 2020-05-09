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

# usage: osis2osis_2.pl [Bible_Directory]

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();

our ($MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our $NO_OUTPUT_DELETE;

# Two scripts are run in succession to convert OSIS files from one proj-
# ect into those of another. The osis2osis.pl script runs the CF_osis-
# 2osis.txt file and applies the CC instructions, which may also create
# a project config.conf where there was none before. Therefore, the
# osis2osis_2.pl script starts over, using the new config.conf, and then
# applies the CCOSIS instructions to complete the conversion.

require("$SCRD/utils/simplecc.pl");
require("$SCRD/scripts/processOSIS.pl");
require("$SCRD/scripts/osis2osis/functions.pl");

# Initialized in runCF_osis2osis.pl
our $sourceProject;

# NOTE: CF_osis2osis.txt may contain instructions for both MAINMOD and 
# DICTMOD, but an osis file will only be generated for the MOD on which 
# this script is called.
my $commandFile = "$MAININPD/CF_osis2osis.txt";
if (! -e $commandFile) {&Error("Cannot run osis2osis.pl without a CF_osis2osis.txt command file located at: $MAININPD.", '', 1);}

if (&runCF_osis2osis('postinit')) {
  &reprocessOSIS($MOD, $sourceProject);

  if ($NO_OUTPUT_DELETE) {
   # When NO_OUTPUT_DELETE = true, then the following debug code will be run on tmp files previously created by processOSIS.pl
   # YOUR DEBUG CODE GOES HERE 
  }
}
else {
  &Warn("The osis2osis.pl script did not produce $MOD.", 
  "If $MOD has a CF_usfm2osis.txt file, then sfm2osis.pl should be used instead of osis2osis.pl.");
}

;1

