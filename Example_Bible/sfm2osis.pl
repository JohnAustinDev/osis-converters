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
# There are four possible steps in the process: 1) convert the SFM to 
# OSIS. 2) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 3) parse and add dictionary links to words 
# which are described in a separate dictionary module. 4) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_paratext2osis.txt command 
# file for the project (see those files for more info). Then set the 
# $SCRD path below, and run this script. Check the OUT_sfm2osis.txt 
# log file. Once there are no errors, enable another feature below if 
# desired, update its command file, and run this script again. Once 
# all desired features are enabled, there are no errors, and the 
# information reported in OUT_sfm2osis.txt looks correct, then the 
# OSIS file is done.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

# set to 1 any features which are to be added.
# controls for these features are in 
# corresponding CF_<script>.txt files
$addscrip = 0;    # addScriptRefLinks.pl
$adddicts = 0;    # addDictLinks.pl
$addcross = 0;    # addCrossRefs.pl

# set to full or relative path of the script directory
$SCRD = "../scripts";

# set to full path of the directory containing the xmllint executable 
# or null if it's in PATH. xmllint is a program used to validate the 
# resulting OSIS file.
$XMLLINT = "";

########################################################################
########################################################################

if ($XMLLINT && $XMLLINT !~ /\/$/) {$XMLLINT .= "/";}
use File::Spec;
use Cwd; $INPD = getcwd;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}
if (!-e $SCRD) {die "ERROR: Bad path to script directory.\n";}
require("$SCRD/src2osis.pl");
#print "Press ENTER to close..."; $a = <>;
