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

# Run this script to convert an SFM glossary file into an IMP file
# There are three distinct parts of the process: 1) convert the SFM to 
# OSIS. 2) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 3) parse and add dictionary links to words 
# which are described in a separate dictionary module.

#  IMP wiki: http://www.crosswire.org/wiki/File_Formats#IMP
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
#  -The CF_paratext2imp.txt command file is executed from top to
#   bottom. All settings remain in effect until/unless changed (so
#   settings may be set more than once). All SFM files are processed 
#   and added to the IMP file in the order in which they appear in 
#   the command file. Books are processed using all settings 
#   previously set in the command file.

# set to 1 any features which are to be added.
# controls for these features are in 
# corresponding CF_<script>.txt files
$addscrip = 0;    # addScriptRefLinks.pl
$addseeal = 0;    # addSeeAlsoLinks.pl

# set to full or relative path of the script directory
$SCRD = "../scripts";

# set to full path of SWORD module directory where you would like a
# copy to be made, as a convenience to help speed up development.
# if not set, the module will not be copied.
$SWORD_PATH = "";

# set to full path of the SWORD bin directory 
# or leave empty if it's in PATH.
$SWORD_BIN = "";

########################################################################
########################################################################

use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
require("$SCRD/src2imp.pl");
#print "Press ENTER to close..."; $a = <>;
