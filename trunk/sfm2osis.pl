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

# usage: sfm2osis.pl [Bible_Directory]

# Run this script to create an OSIS file from source (U)SFM files. 
# There are four possible steps in the process: 1) convert the SFM to 
# OSIS. 2) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 3) parse and add dictionary links to words 
# which are described in a separate dictionary module. 4) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_paratext2osis.txt command 
# file located in the Bible_Directory (see those files for more info). 
# Then check the log file: Bible_Directory/OUT_sfm2osis.txt.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use File::Spec;
$INPD = shift;
if ($INPD) {
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  my $dproj = "./Example_Bible";
  print "usage: sfm2osis.pl [Bible_Directory]\n";
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
$SCRD =~ s/\/[^\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$COMMANDFILE = "$INPD/CF_paratext2osis.txt";
if (open(COMF, "<:encoding(UTF-8)", $COMMANDFILE)) {
  while(<COMF>) {
    if ($_ =~ /^RUN_addScripRefLinks:\s*(.*?)\s*$/) {
      $addscrip = $1;
      if ($addscrip && $addscrip =~ /(1|true)/i) {$addscrip = 1;}
      else {$addscrip = 0;}
    }
    if ($_ =~ /^RUN_addDictLinks:\s*(.*?)\s*$/) {
      $adddicts = $1;
      if ($adddicts && $adddicts =~ /(1|true)/i) {$adddicts = 1;}
      else {$adddicts = 0;}
    }
    if ($_ =~ /^RUN_addCrossRefs:\s*(.*?)\s*$/) {
      $addcross = $1;
      if ($addcross && $addcross =~ /(1|true)/i) {$addcross = 1;}
      else {$addcross = 0;}
    }
  }
  close(COMF);
}
else {
  print "Command File \"$COMMANDFILE\" not found. Exiting.\n";
  exit;
}

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);
if (!$MODPATH) {$MODPATH = "./modules/texts/ztext/$MODLC/";}

$OSISFILE = "$INPD/".$MOD.".xml";
$LOGFILE = "$INPD/OUT_sfm2osis.txt";

my $delete;
if (-e $OSISFILE) {$delete .= "$OSISFILE\n";}
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {die;}
}
if (-e $OSISFILE) {unlink($OSISFILE);}
if (-e $LOGFILE) {unlink($LOGFILE);}

$TMPDIR = "$INPD/tmp/src2osis";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

if ($SWORDBIN && $SWORDBIN !~ /\/\*$/) {$SWORDBIN .= "/";}

&Log("\n-----------------------------------------------------\nSTARTING src2osis.pl\n\n");

# insure the following conf settings are in the conf file
$OSISVersion = $OSISSCHEMA;
$OSISVersion =~ s/(\s*osisCore\.|\.xsd\s*)//ig;
open(CONF, ">>:encoding(UTF-8)", "$CONFFILE") || die "Could not open $CONFFILE\n";
$ret = "\n";
if ($ConfEntry{"GlobalOptionFilter"} !~ /OSISFootnotes/) {print CONF $ret."GlobalOptionFilter=OSISFootnotes\n"; $ret="";}
if ($ConfEntry{"GlobalOptionFilter"} !~ /OSISHeadings/)  {print CONF $ret."GlobalOptionFilter=OSISHeadings\n"; $ret="";}
if ($ConfEntry{"GlobalOptionFilter"} !~ /OSISScripref/)  {print CONF $ret."GlobalOptionFilter=OSISScripref\n"; $ret="";}
if ($ConfEntry{"Encoding"} && $ConfEntry{"Encoding"}  ne "UTF-8") {
  &Log("ERROR: Encoding is set incorrectly in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"SourceType"} && $ConfEntry{"SourceType"}  ne "OSIS") {
  &Log("ERROR: SourceType is set in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"OSISVersion"} && $ConfEntry{"OSISVersion"}  ne $OSISVersion) {
  &Log("ERROR: OSISVersion is set in $CONFFILE. Remove this entry.\n");
}
if ($ConfEntry{"Encoding"}  ne "UTF-8") {
  print CONF $ret."Encoding=UTF-8\n"; $ret="";
}
if ($ConfEntry{"SourceType"}  ne "OSIS") {
  print CONF $ret."SourceType=OSIS\n"; $ret="";
}
if ($ConfEntry{"OSISVersion"}  ne $OSISVersion) {
  print CONF $ret."OSISVersion=$OSISVersion\n"; $ret="";
}
close(CONF);

# run paratext2osis.pl
$COMMANDFILE = "$INPD/CF_paratext2osis.txt";
if (-e $COMMANDFILE) {
  &Log("\n--- CONVERTING PARATEXT TO OSIS\n");
  $OUTPUTFILE = "$TMPDIR/".$MOD."_1.xml";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/paratext2osis.pl");
  $NOCONSOLELOG = 0;
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

# run addScripRefLinks.pl
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if ($addscrip && !-e $COMMANDFILE) {&Log("ERROR: Skipping Scripture reference parsing. Missing command file: $COMMANDFILE.\n");}
if ($addscrip && -e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  $INPUTFILE = "$TMPDIR/".$MOD."_1.xml";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_2.xml";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");}

# run addDictLinks.pl
$COMMANDFILE = "$INPD/CF_addDictLinks.txt";
if ($adddicts && !-e $COMMANDFILE) {&Log("ERROR: Skipping dictionary link parsing/checking. Missing command file: $COMMANDFILE.\n");}
if ($adddicts && -e $COMMANDFILE) {
  &Log("\n--- ADDING/CHECKING DICTIONARY LINKS\n");
  $COMMANDFILE = "$INPD/CF_addDictLinks.txt";
  $INPUTFILE = "$TMPDIR/".$MOD."_2.xml";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_3.xml";
  if ($ConfEntry{"GlobalOptionFilter"} !~ /OSISDictionary/) {
    open(CONF, ">>:encoding(UTF-8)", "$CONFFILE") || die "Could not open $CONFFILE\n";
    print CONF "GlobalOptionFilter=OSISDictionary\n";
    close(CONF);
  }
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addDictLinks.pl");
  $NOCONSOLELOG = 0;
  foreach my $dn (values %DictNames) {$allDictNames{$dn}++;}
  foreach my $dn (keys %allDictNames) {
    if ($ConfEntry{"DictionaryModule"} !~ /\Q$dn\E/ ) {
      open(CONF, ">>:encoding(UTF-8)", "$CONFFILE") || die "Could not open $CONFFILE\n";
      print CONF "DictionaryModule=$dn\n";
      close(CONF);
    }
  }
}
else {rename("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");}
close(CONF);

# run addCrossRefs.pl
$COMMANDFILE = "$INPD/CF_addCrossRefs.txt";
if ($addcross && !-e $COMMANDFILE) {&Log("ERROR: Skipping cross-reference insertion. Missing command file: $COMMANDFILE.\n");}
if ($addcross && -e $COMMANDFILE) {
  &Log("\n--- ADDING CROSS REFERENCES\n");
  $COMMANDFILE = "$INPD/CF_addCrossRefs.txt";
  $INPUTFILE = "$TMPDIR/".$MOD."_3.xml";
  $OUTPUTFILE = $OSISFILE;
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addCrossRefs.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_3.xml", $OSISFILE);}


# add any non-canonical and empty verses to the osis file
require("$SCRD/scripts/fillEmptyVerses.pl");
&fillEmptyVerses($VERSESYS, $OSISFILE, $TMPDIR);

# validate new OSIS file against schema
&Log("\n--- VALIDATING OSIS SCHEMA\n");
&Log("BEGIN OSIS SCHEMA VALIDATION\n");
$cmd = $XMLLINT."xmllint --noout --schema \"http://www.bibletechnologies.net/$OSISSCHEMA\" ".&escfile($OSISFILE)." 2>> ".&escfile($LOGFILE);
&Log("$cmd\n");
system($cmd);
&Log("END OSIS SCHEMA VALIDATION\n");

1;
