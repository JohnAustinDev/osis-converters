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

$IMPFILE = "$INPD/dict.imp";
if (!-e $IMPFILE) {die "ERROR: Missing imp file: $IMPFILE\n";}

$LOGFILE = "$INPD/OUT_dict2mod.txt";

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

&Log("\n-----------------------------------------------------\nSTARTING dict2mod.pl\n\n");

$TMPDIR = "$INPD/tmp/dict2mod";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

# add Scripture reference links to imp file
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if (!-e $COMMANDFILE) {&Log("ERROR: Skipping Scripture reference parsing. Missing command file: $COMMANDFILE.\n");}
if ($addscrip && -e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  $INPUTFILE = "$INPD/dict.imp";
  $OUTPUTFILE = "$TMPDIR/dict_1.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {copy("$INPD/dict.imp", "$TMPDIR/dict_1.imp");}

# add see-also links to imp file
$COMMANDFILE = "$INPD/CF_addSeeAlsoLinks.txt";
$DICTWORDS = "$INPD/DictionaryWords.txt";
if (!-e $COMMANDFILE) {&Log("\nERROR: Skipping see-also link parsing/checking. Missing command file: $COMMANDFILE.\n");}
if (!-e $DICTWORDS) {&Log("\nERROR: Skipping see-also link parsing/checking. Missing dictionary listing: $DICTWORDS.\n");}
if ($addseeal && -e $COMMANDFILE && -e $DICTWORDS) {
  &Log("\n--- ADDING/CHECKING SEE-ALSO LINKS\n");
  $INPUTFILE = "$TMPDIR/dict_1.imp";
  $OUTPUTFILE = "$TMPDIR/dict_2.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/addSeeAlsoLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/dict_1.imp", "$TMPDIR/dict_2.imp");}

&Log("\n--- CREATING NEW $MOD MODULE\n");
$SWDD = "$INPD/sword";

# create new conf
if (!-e "$SWDD/mods.d") {make_path("$SWDD/mods.d");}
copy($CONFFILE, "$SWDD/mods.d/$MODLC.conf") || die "Could not copy dict conf $CONFFILE\n";
if ($ConfEntry{"ModDrv"} && $ConfEntry{"ModDrv"} ne "RawLD") {
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
if ($ConfEntry{"ModDrv"} ne "RawLD") {
  print CONF $ret."ModDrv=RawLD\n"; $ret="";
}
if ($ConfEntry{"Category"} ne "Lexicons / Dictionaries") {
  print CONF $ret."Category=Lexicons / Dictionaries\n"; $ret="";
}
if ($ConfEntry{"DataPath"} ne "./modules/lexdict/rawld/$MODLC/$MODLC") {
  print CONF $ret."Category=./modules/lexdict/rawld/$MODLC/$MODLC\n"; $ret="";
}
if ($ConfEntry{"Encoding"} ne "UTF-8") {
  print CONF $ret."Category=UTF-8\n"; $ret="";
}
if ($ConfEntry{"MinimumVersion"} ne "1.5.11") {
  print CONF $ret."Category=1.5.11\n"; $ret="";
}
if ($ConfEntry{"SourceType"} ne "OSIS") {
  print CONF $ret."Category=OSIS\n"; $ret="";
}
if (!$ConfEntry{"SwordVersionDate"}) {
  my @tm = localtime(time);
  print CONF $ret."SwordVersionDate=".sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3])."\n"; $ret="";
}
close(CONF);

# create new module files
make_path("$SWDD/$MODPATH");
chdir("$SWDD/$MODPATH") || die "Could not cd into \"$SWDD/$MODPATH\"\n";
$cmd = &escfile($SWORD_BIN."imp2ld")." ".&escfile("$TMPDIR/dict_2.imp")." $MODLC 2 >> ".&escfile($LOGFILE);
&Log("$cmd\n", 1);
`$cmd`;
chdir($INPD);

if ($IMAGEDIR) {
  &Log("\n--- COPYING IMAGES TO MODULE\n");
  if (-e "$SWDD/$MODPATH/images") {remove_tree("$SWDD/$MODPATH/images");}
  &copy_dir($IMAGEDIR, "$SWDD/$MODPATH/images");
}

# make a zipped copy of the module
&Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
if ("$^0" =~ /MSWin32/i) {
  `7za a -tzip \"$INPD\\$MOD.zip\" -r \"$SWDD\\*\"`;
}
else {
  chdir($SWDD);
  my $tSWDD = quotemeta($SWDD);
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
