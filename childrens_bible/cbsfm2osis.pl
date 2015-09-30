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

# usage: cbsfm2osis.pl [Project_Directory]

$DEBUG = 0;

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

# Get SFM files
$List = "-l";
$INPF = "$INPD/SFM_Files.txt";
if (! -e $INPF) {
  &Log("ERROR: Must list sfm files in \"$INPF\", one file per line, in proper sequence.\n");
  exit;
}

# Get any prefix to be added to additional language specific picture file names
$PREFIX = '';
if (-e "$INPD/Image_Prefix.txt") {
  open(INF, "<$INPD/Image_Prefix.txt"); 
  $PREFIX = <INF>; 
  close(INF);
}

$CBD = "$SCRD/childrens_bible";

# run preprocessor
&Log("\n--- PREPROCESSING USFM\n-----------------------------------------------------\n\n", 1);
$AddFileOpt = (-e "$INPD/SFM_Add.txt" ? "-a \"$INPD/SFM_Add.txt\"":'');
$cmd = "$CBD/scripts/preproc.py $AddFileOpt $List $INPF \"$TMPDIR/".$MOD."_1.sfm\" jpg $PREFIX";
&Log($cmd);
`$cmd`;

# run main conversion script
&Log("\n--- CONVERTING PARATEXT TO OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$CBD/scripts/usfm2osis.py $MOD -o \"$TMPDIR/".$MOD."_1.xml\" -r -g -x \"$TMPDIR/".$MOD."_1.sfm\"";
&Log($cmd);
`$cmd`;

# run postprocessor
&Log("\n--- POSTPROCESSING OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$CBD/scripts/postproc.py \"$TMPDIR/".$MOD."_1.xml\" \"$TMPDIR/".$MOD."_2.xml\"";
&Log($cmd);
`$cmd`;

# run addScripRefLinks.pl
if (-e "$INPD/CF_addScripRefLinks.txt") {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_2.xml", $OUTOSIS);
}
else {
  &Log("Skipping Scripture reference parsing.\n");
  rename("$TMPDIR/".$MOD."_2.xml", $OUTOSIS);
}

1;
