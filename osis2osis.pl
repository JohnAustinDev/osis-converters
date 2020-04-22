#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
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

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();

our ($INPD, $LOGFILE);

# Two scripts are run in succession to convert OSIS files from one proj-
# ect into those of another. The osis2osis.pl script runs the CF_osis-
# 2osis.txt file and applies the CC instructions, which may also create
# a project config.conf where there was none before. Therefore, the
# osis2osis_2.pl script starts over, using the new config.conf, and then
# applies the CCOSIS instructions to complete the conversion.

&osis_converters("$SCRD/scripts/osis2osis/osis2osis_2.pl", $INPD, $LOGFILE);

&timer('stop');

1;
