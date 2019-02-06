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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";
require("$SCRD/utils/simplecc.pl");

$OSIS = "$TMPDIR/osis2osis.xml";
if (&runOsis2osis('postinit', $INPD, $OSIS) eq $OSIS) {
  require("$SCRD/scripts/processOSIS.pl");
  if ($NO_OUTPUT_DELETE) {
   # When NO_OUTPUT_DELETE = true, then the following debug code will be run on tmp files previously created by processOSIS.pl
   # YOUR DEBUG CODE GOES HERE 
  }
}
else {&ErrorBug("runOsis2osis failed to write OSIS file.");}

;1

