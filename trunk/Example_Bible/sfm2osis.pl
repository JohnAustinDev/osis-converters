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

# Run this script to create an OSIS file from source (U)SFM files. 
# There are four distinct parts of the process: 1) convert the SFM to 
# OSIS. 2) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 3) parse and add dictionary links to words 
# which are described in a separate dictionary module. 4) insert cross 
# reference links into the OSIS file.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
#  -The CF_paratext2osis.txt command file is executed from top to
#   bottom. All settings remain in effect until/unless changed (so
#   settings may be set more than once). All SFM files are processed 
#   and added to the OSIS file in the order in which they appear in 
#   the command file. Books are processed using all settings 
#   previously set in the command file. The special terms "OT" and 
#   "NT" should appear before the first Old-Testament and first 
#   New-Testament books.
#
#  -It might be helpful on the first run of a new SFM project to use 
#   "FIND_ALL_TAGS:true". This will log all tags found in the project
#   after "Following is the list of unhandled tags which were 
#   skipped:" The listed tags can be added to the command file and 
#   handled as desired.

# set to 1 any features which are to be added.
# controls for these features are in 
# corresponding CF_<script>.txt files
$addscrip = 0;    # addScriptRefLinks.pl
$adddicts = 0;    # addDictLinks.pl
$addcross = 0;    # addCrossRefs.pl

# set to full or relative path of the script directory
$SCRD = "../scripts";

########################################################################
########################################################################

use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
require("$SCRD/src2osis.pl");
#print "Press ENTER to close..."; $a = <>;
