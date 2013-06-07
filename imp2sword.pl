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

# usage: imp2sword.pl [Glossary_Directory]

# Run this script to create a dictionary SWORD module from an IMP 
# file and a config.conf file located in the Glossary_Directory.

use File::Find; 
use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  my $dproj = "./Example_Glossary";
  print "\nusage: imp2sword.pl [Glossary_Directory]\n";
  print "\n";
  print "run default project $dproj? (Y/N):";
  my $in = <>;
  if ($in !~ /^\s*y\s*$/i) {exit;}
  $INPD = File::Spec->rel2abs($dproj);
}
if (!-e $INPD) {
  print "Glossary_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$COMMANDFILE = "$INPD/CF_paratext2imp.txt";
&normalizeNewLines($COMMANDFILE);
if (open(COMF, "<:encoding(UTF-8)", $COMMANDFILE)) {
  while(<COMF>) {
    if ($_ =~ /^SET_imageDir:\s*(.*?)\s*$/) {if ($1) {$imageDir = $1;}}
  }
  close(COMF);
}
else {
  print "Command File \"$COMMANDFILE\" not found. Exiting.\n";
  exit;
}
if ($imageDir && $imageDir =~ /^\./) {
  chdir($INPD);
  $imageDir = File::Spec->rel2abs($imageDir);
  chdir($SCRD);
}

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);
if (!$MODPATH) {$MODPATH = "./modules/lexdict/rawld/$MODLC/";}

$IMPFILE = "$OUTDIR/$MOD.imp";
if (!-e $IMPFILE) {print "ERROR: Missing imp file: $IMPFILE. Exiting.\n"; exit;}

$LOGFILE = "$OUTDIR/OUT_imp2sword.txt";

my $delete;
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if (-e "$OUTDIR/$MOD.zip") {$delete .= "$OUTDIR/$MOD.zip\n";}
if (-e "$OUTDIR/sword") {$delete .= "$OUTDIR/sword\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $LOGFILE) {unlink($LOGFILE);}
if (-e "$OUTDIR/$MOD.zip") {unlink("$OUTDIR/$MOD.zip");}
if (-e "$OUTDIR/sword") {remove_tree("$OUTDIR/sword");}

&Log("osis-converters rev: $SVNREV\n\n");
&Log("\n-----------------------------------------------------\nSTARTING imp2sword.pl\n\n");

$TMPDIR = "$OUTDIR/tmp/dict2mod";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("\n--- CREATING NEW $MOD MODULE\n");
$SWDD = "$OUTDIR/sword";

# create new conf
if (!-e "$SWDD/mods.d") {make_path("$SWDD/mods.d");}
copy($CONFFILE, "$SWDD/mods.d/$MODLC.conf") || die "Could not copy dict conf $CONFFILE\n";
if ($ConfEntry{"ModDrv"} && $ConfEntry{"ModDrv"} ne "RawLD4") {
  &Log("ERROR: ModDrv is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"Category"} && $ConfEntry{"Category"} ne "Lexicons / Dictionaries") {
  &Log("ERROR: Category is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"DataPath"} && $ConfEntry{"DataPath"} ne "./modules/lexdict/rawld/$MODLC/$MODLC") {
  &Log("ERROR: DataPath is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"Encoding"} && $ConfEntry{"Encoding"} ne "UTF-8") {
  &Log("ERROR: Encoding is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"MinimumVersion"} && $ConfEntry{"MinimumVersion"} ne "1.5.11") {
  &Log("ERROR: MinimumVersion is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"SourceType"} && $ConfEntry{"SourceType"} ne "OSIS") {
  &Log("ERROR: SourceType is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"SwordVersionDate"}) {
  &Log("WARN: SwordVersionDate is set in $CONFFILE. Remove this entry to have it update automatically\n");
}

open(CONF, ">>:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not open \"$SWDD/mods.d/$MODLC.conf\"\n";
$ret = "\n";
if ($ConfEntry{"ModDrv"} ne "RawLD4") {
  print CONF $ret."ModDrv=RawLD4\n"; $ret="";
}
if ($ConfEntry{"Category"} ne "Lexicons / Dictionaries") {
  print CONF $ret."Category=Lexicons / Dictionaries\n"; $ret="";
}
if ($ConfEntry{"DataPath"} ne "./modules/lexdict/rawld/$MODLC/$MODLC") {
  print CONF $ret."DataPath=./modules/lexdict/rawld/$MODLC/$MODLC\n"; $ret="";
}
if ($ConfEntry{"Encoding"} ne "UTF-8") {
  print CONF $ret."Encoding=UTF-8\n"; $ret="";
}
if ($ConfEntry{"MinimumVersion"} ne "1.5.11") {
  print CONF $ret."MinimumVersion=1.5.11\n"; $ret="";
}
if ($ConfEntry{"SourceType"} ne "OSIS") {
  print CONF $ret."SourceType=OSIS\n"; $ret="";
}
if (!$ConfEntry{"SearchOption"}) {
  print CONF $ret."SearchOption=IncludeKeyInSearch\n"; $ret="";
}
if (!$ConfEntry{"SwordVersionDate"}) {
  my @tm = localtime(time);
  print CONF $ret."SwordVersionDate=".sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3])."\n"; $ret="";
}
# The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
if (!$ConfEntry{"CaseSensitiveKeys"}) {
  print CONF $ret."CaseSensitiveKeys=true\n"; $ret="";
}
close(CONF);

# create new module files
make_path("$SWDD/$MODPATH");
chdir("$SWDD/$MODPATH") || die "Could not cd into \"$SWDD/$MODPATH\"\n";
$cmd = &escfile($SWORD_BIN."imp2ld")." ".&escfile($IMPFILE)." -o ./$MODLC -4 >> ".&escfile($LOGFILE);
#$cmd = &escfile($SWORD_BIN."imp2ld")." ".&escfile($IMPFILE)." $MODLC >> ".&escfile($LOGFILE);
&Log("$cmd\n", 1);
system($cmd);
chdir($INPD);

if ($imageDir) {
  &Log("\n--- COPYING IMAGES TO MODULE\n");
  if (-e "$SWDD/$MODPATH/images") {remove_tree("$SWDD/$MODPATH/images");}
  &copy_dir($imageDir, "$SWDD/$MODPATH/images");
}

$installSize = 0;        
# NOTE: this installSize should not include the index.     
find(sub { $installSize += -s if -f $_ }, "$SWDD/$MODPATH");
open(CONF, ">>:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not append to conf $SWDD/mods.d/$MODLC.conf\n";
print CONF "\nInstallSize=$installSize\n";
close(CONF);

# make a zipped copy of the module
&Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
if ("$^O" =~ /MSWin32/i) {
  `7za a -tzip \"$OUTDIR\\$MOD.zip\" -r \"$SWDD\\*\"`;
}
else {
  chdir($SWDD);
  `zip -r \"$OUTDIR/$MOD.zip\" ./*`;
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
