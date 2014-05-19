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

use File::Find; 

&Log("\n-----------------------------------------------------\nSTARTING makeCompressedMod.pl\n\n");

# prepare module directories and remove old module bits if any
if (!-e "$SWDD/mods.d") {make_path("$SWDD/mods.d");}

$RMOD = $MOD."r";
$RMODLC = $MODLC."r";
if (-e "$SWDD/modules/texts/rawtext/$RMODLC") {remove_tree("$SWDD/modules/texts/rawtext/$RMODLC");}
make_path("$SWDD/modules/texts/rawtext/$RMODLC");
if (-e "$SWDD/mods.d/$RMODLC.conf") {unlink("$SWDD/mods.d/$RMODLC.conf");}

if (-e "$SWDD/modules/texts/ztext/$MODLC") {remove_tree("$SWDD/modules/texts/ztext/$MODLC");}
make_path("$SWDD/modules/texts/ztext/$MODLC");
if (-e "$SWDD/mods.d/$MODLC.conf") {unlink("$SWDD/mods.d/$MODLC.conf");}

# determine the minimum sword version needed to render modules created by this osis2mod
$msv = "1.6.1";
if ($VERSESYS && $VERSESYS ne "KJV") {
  system(&escfile($SWORD_BIN."osis2mod")." 2> ".&escfile("$TMPDIR/osis2mod_vers.txt"));
  open(OUTF, "<:encoding(UTF-8)", "$TMPDIR/osis2mod_vers.txt") || die "Could not open $TMPDIR/osis2mod_vers.txt\n";
  while(<OUTF>) {
    if ($_ =~ (/\$REV:\s*(\d+)\s*\$/i) && $1 > 2478) {
      $msv = "1.6.2"; last;
    }
  }
  close(OUTF);
  unlink("$TMPDIR/osis2mod_vers.txt");
  if ($VERSESYS eq "SynodalProt") {$msv = "1.7.0";}
}

# due to SWORD bug: http://www.crosswire.org/bugs/browse/API-121
# a raw module is created, then it's converted to a zip mod.
# create config for zipped module
copy($CONFFILE, "$SWDD/mods.d/$MODLC.conf") || die "Could not copy zip conf $CONFFILE\n";
if ($ConfEntry{"DataPath"} && $ConfEntry{"DataPath"}  ne "./modules/texts/ztext/$MODLC/") {
  &Log("ERROR: DataPath is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"ModDrv"} && $ConfEntry{"ModDrv"}  ne "zText") {
  &Log("ERROR: ModDrv is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"CompressType"} && $ConfEntry{"CompressType"}  ne "ZIP") {
  &Log("ERROR: CompressType is set in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"BlockType"} && $ConfEntry{"BlockType"}  ne "BOOK") {
  &Log("ERROR: BlockType is set in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"MinimumVersion"} && $ConfEntry{"MinimumVersion"}  ne $msv) {
  &Log("ERROR: MinimumVersion is set in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"Category"} && $ConfEntry{"Category"} ne "Biblical Texts") {
  &Log("ERROR: Category is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"SwordVersionDate"}) {
  &Log("WARN: SwordVersionDate is set in $CONFFILE. Remove this entry to have it update automatically\n");
}
open(CONF, ">>:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not open zip conf $SWDD/mods.d/$MODLC.conf\n";
$ret = "\n";
if ($ConfEntry{"DataPath"}  ne "./modules/texts/ztext/$MODLC/") {
  print CONF $ret."DataPath=./modules/texts/ztext/$MODLC/\n"; $ret="";
}
print CONF $ret."CompressType=ZIP\nBlockType=BOOK\n"; $ret="";
if ($VERSESYS && $VERSESYS ne "KJV" && $ConfEntry{"MinimumVersion"} ne $msv) {
  print CONF $ret."MinimumVersion=$msv\n"; $ret="";
}
if (!$ConfEntry{"SwordVersionDate"}) {
  @tm = localtime(time);
  print CONF $ret."SwordVersionDate=".sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3])."\n"; $ret="";
}
if ($ConfEntry{"Category"} ne $Category) {
  print CONF $ret."Category=Biblical Texts\n"; $ret="";
}
close(CONF);

# modify config for raw module
open(CONF, "<:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not open zip conf \"$SWDD/mods.d/$MODLC.conf\"\n";
open(CONF2, ">:encoding(UTF-8)", "$SWDD/mods.d/$RMODLC.conf") || die "Could not open raw conf \"$SWDD/mods.d/$RMODLC.conf\"\n";
while(<CONF>) {
  # change modname
  $_ =~ s/^\[\Q$MOD\E\]/\[$RMOD\]/;
  
  #change datapath
  if ($_ =~ /^DataPath\s*=/) {
    $_ =~ s/ztext/rawtext/;
    $_ =~ s/(\Q$MODLC\E)/$RMODLC/;
  }
  
  # remove zip entries
  if ($_ =~ /^(ModDrv|CompressType|BlockType)/) {next;}
  
  print CONF2 $_;
}
print CONF2 "ModDrv=RawText\n";
close(CONF);
close(CONF2);

# create the raw module
&Log("\n--- CREATING $MOD RAW SWORD MODULE (".$VERSESYS.")\n");
chdir("$SWDD");
if ($VERSESYS) {$vsys = "-v $VERSESYS ";}
$cmd = &escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWDD/modules/texts/rawtext/$RMODLC")." ".&escfile($OSISFILE)." -N $vsys>> ".&escfile($LOGFILE);
&Log("$cmd\n", -1);
system($cmd);
$installSize = 0; 
# NOTE: this installSize should not include the index.             
find(sub { $installSize += -s if -f $_ }, "$SWDD/modules/texts/rawtext/$RMODLC");
open(CONF, ">>:encoding(UTF-8)", "$SWDD/mods.d/$RMODLC.conf") || die "Could not append to raw conf $SWDD/mods.d/$RMODLC.conf\n";
print CONF "\nInstallSize=$installSize\n";
close(CONF);

# create the zip module
&Log("\n--- CREATING $MOD ZIPPED SWORD MODULE (".$VERSESYS.")\n");
$cmd = &escfile($SWORD_BIN."mod2zmod")." $RMOD ".&escfile("$SWDD/modules/texts/ztext/$MODLC")." 4 2 >> ".&escfile($LOGFILE);
&Log("$cmd\n", -1);
system($cmd);
$installSize = 0;        
# NOTE: this installSize should not include the index.     
find(sub { $installSize += -s if -f $_ }, "$SWDD/modules/texts/ztext/$MODLC");
open(CONF, ">>:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not append to zip conf $SWDD/mods.d/$MODLC.conf\n";
print CONF "\nInstallSize=$installSize\n";
close(CONF);

&Log("\n--- TESTING FOR EMPTY VERSES\n");
$cmd = &escfile($SWORD_BIN."emptyvss")." 2>&1";
$cmd = `$cmd`;
if ($cmd =~ /usage/i) {
  &Log("BEGIN EMPTYVSS OUTPUT\n", -1);
  $cmd = &escfile($SWORD_BIN."emptyvss")." $MOD >> ".&escfile($LOGFILE);
  system($cmd);
  &Log("END EMPTYVSS OUTPUT\n", -1);
}
else {&Log("ERROR: Could not check for empty verses. Sword tool \"emptyvss\" could not be found. It may need to be compiled locally.");}
chdir($INPD);

&Log("\n--- RUNNING OSIS2MOD LINK MESSAGE POST PROCESSOR\n");
require("$SCRD/scripts/postProLog.pl");

