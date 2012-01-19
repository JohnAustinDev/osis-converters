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
#
########################################################################

# Run this script to create GoBible mobile phone Bibles from an osis file.
# The following input files need to be in a "GoBible" sub-directory:
#    collections.txt            - build-control file
#    ui.properties              - user interface translation
#    icon.png                   - icon for the application
#    normalChars.txt (optional) - character replacement file
#    simpleChars.txt (optional) - simplified character replacement file

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# GoBible wiki: http://www.crosswire.org/wiki/Projects:Go_Bible

# set to full or relative path of the script directory
$SCRD = "../scripts";

# set this to the full or relative path of the GoBible creator directory
$GOCREATOR = "../scripts/utils/GoBibleCreator_Version_2.4.3";

########################################################################
########################################################################

use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
if ($GOCREATOR =~ /^\./) {$GOCREATOR = File::Spec->rel2abs($GOCREATOR);}
if (!-e $GOCREATOR) {die "ERROR: Bad path to GoBible Creator directory.\n";}
require("$SCRD/osis2GoBible.pl");
#print "Press ENTER to close..."; $a = <>;
