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

# usage: osis2sword.pl [Bible_Directory]

# Run this script to create raw and zipped SWORD modules from an 
# osis.xml file and a config.conf file located in the Bible_Directory.

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  my $dproj = "./Example_Bible";
  print "\nusage: osis2sword.pl [Bible_Directory]\n";
  print "\n";
  print "run default project $dproj? (Y/N):";
  my $in = <>;
  if ($in !~ /^\s*y\s*$/i) {exit;}
  $INPD = File::Spec->rel2abs($dproj);
}
if (!-e $INPD) {
  print "Bible_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);
if (!$MODPATH) {$MODPATH = "./modules/texts/ztext/$MODLC/";}

$OSISFILE = "$INPD/".$MOD.".xml";
if (!-e $OSISFILE) {print "ERROR: Missing osis file: $OSISFILE. Exiting.\n"; exit;}
$LOGFILE = "$INPD/OUT_osis2sword.txt";

my $delete;
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if (-e "$INPD/sword") {$delete .= "$INPD/sword\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $LOGFILE) {unlink($LOGFILE);}
if (-e "$INPD/sword") {remove_tree("$INPD/sword");}

$TMPDIR = "$INPD/tmp/osis2mod";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("\n-----------------------------------------------------\nSTARTING osis2sword.pl\n\n");
if (!-e "$INPD/sword") {make_path("$INPD/sword");}

# create raw and zipped modules from OSIS
$SWDD = "$INPD/sword";
require("$SCRD/scripts/makeCompressedMod.pl");

# make a zipped copy of the entire zipped module
&Log("\n--- COMPRESSING ZTEXT MODULE TO A ZIP FILE.\n");
$tmp = "$TMPDIR/sword";
make_path("$tmp/mods.d");
copy("$SWDD/mods.d/$MODLC.conf", "$tmp/mods.d/$MODLC.conf");
&copy_dir("$SWDD/$MODPATH", "$tmp/$MODPATH");
if ("$^O" =~ /MSWin32/i) {
  `7za a -tzip \"$SWDD\\$MOD.zip\" -r \"$tmp\\*\"`;
}
else {
  chdir($tmp);
  `zip -r \"$SWDD/$MOD.zip\" ./*`;
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
