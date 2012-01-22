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

# Run this script to create a dictionary SWORD module from an IMP 
# file and a config.conf file located in this directory.

#  IMP wiki: http://www.crosswire.org/wiki/File_Formats#IMP
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

# set to full or relative path of the script directory
$SCRD = "../scripts";

# set to full path of SWORD module directory where you would like a
# copy to be made, as a convenience to help speed up development.
# if not set, the module will not be copied.
$SWORD_PATH = "";

# set to full path of the SWORD bin directory 
# or leave empty if it's in PATH.
$SWORD_BIN = "";

# set to full or relative path of image directory 
# or leave empty if there are no images i the module.
$IMAGEDIR = ""; 

########################################################################
########################################################################

if ($SWORD_BIN && $SWORD_BIN !~ /\/$/) {$SWORD_BIN .= "/";}
use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
require("$SCRD/dict2mod.pl");
#print "Press ENTER to close..."; $a = <>;
