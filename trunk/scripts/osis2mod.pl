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

require "$SCRD/utils/common.pl";

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {die "ERROR: Missing conf file: $CONFFILE\n";}
&getInfoFromConf($CONFFILE);
if (!$MODPATH) {$MODPATH = "./modules/texts/ztext/$MODLC/";}

$OSISFILE = "$INPD/".$MOD.".xml";
if (!-e $OSISFILE) {die "ERROR: Missing osis file: $OSISFILE\n";}
$LOGFILE = "$INPD/OUT_osis2sword.txt";

my $delete;
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if (-e "$INPD/sword") {$delete .= "$INPD/sword\n";}
if (-e "$INPD/$MOD.zip") {$delete .= "$INPD/$MOD.zip\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {die;}
}
if (-e $LOGFILE) {unlink($LOGFILE);}
if (-e "$INPD/sword") {remove_tree("$INPD/sword");}
if (-e "$INPD/$MOD.zip") {unlink("$INPD/$MOD.zip");}

$TMPDIR = "$INPD/tmp/osis2mod";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("\n-----------------------------------------------------\nSTARTING osis2mod.pl\n\n");
if (!-e "$INPD/sword") {make_path("$INPD/sword");}

# create raw and zipped modules from OSIS
$SWDD = "$INPD/sword";
require("$SCRD/utils/makeCompressedMod.pl");

# make a zipped copy of the entire zipped module
&Log("\n--- COMPRESSING ZTEXT MODULE TO A ZIP FILE.\n");
$tmp = "$TMPDIR/sword";
make_path("$tmp/mods.d");
copy("$SWDD/mods.d/$MODLC.conf", "$tmp/mods.d/$MODLC.conf");
&copy_dir("$SWDD/$MODPATH", "$tmp/$MODPATH");
if ("$^O" =~ /MSWin32/i) {
  `7za a -tzip \"$INPD\\$MOD.zip\" -r \"$tmp\\*\"`;
}
else {
  chdir($tmp);
  `zip -r \"$INPD/$MOD.zip\" ./*`;
  chdir($INPD);
}

# copy the module to SWORD_PATH for easy testing
if ($SWORD_PATH) {
  &Log("\n--- ADDING COPY OF MODULE TO SWORD_PATH:\n (SWORD_PATH=$SWORD_PATH)\n");
  if (-e "$SWORD_PATH/$MODPATH") {remove_tree("$SWORD_PATH/$MODPATH");}
  if (!-e "$SWORD_PATH/mods.d") {make_path("$SWORD_PATH/mods.d");}
  if (-e "$SWORD_PATH/mods.d/$MODLC.conf") {unlink("$SWORD_PATH/mods.d/$MODLC.conf");}

  copy("$SWDD/mods.d/$MODLC.conf", "$SWORD_PATH/mods.d/$MODLC.conf");
  &copy_dir("$SWDD/$MODPATH", "$SWORD_PATH/$MODPATH");
}
1;
