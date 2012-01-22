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
# There are three possible parts of the process: 1) convert the SFM to 
# IMP. 2) parse and add Scripture reference links to glossary entries. 
# 3) parse and add "see-also" links to other entries in the glossary.
#
# Begin by updating the config.conf and CF_paratext2imp.txt command 
# file for the project (see those files for more info). Then set the 
# path variables below and run this script. Check the OUT_sfm2imp.txt 
# log file. Once there are no errors, enable another feature below, 
# update its command file, and run this script again. Once all 
# desired features are enabled, there are no errors, and the 
# information reported in OUT_sfm2imp.txt looks correct, then the 
# IMP file is done.

#  IMP wiki: http://www.crosswire.org/wiki/File_Formats#IMP
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

# set to 1 any features which are to be added.
# controls for these features are in 
# corresponding CF_<script>.txt files
$addscrip = 0;    # addScriptRefLinks.pl
$addseeal = 0;    # addSeeAlsoLinks.pl

# set to full or relative path of the script directory
$SCRD = "../scripts";

########################################################################
########################################################################

use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
require("$SCRD/src2imp.pl");
#print "Press ENTER to close..."; $a = <>;
