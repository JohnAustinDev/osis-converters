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

# usage: sfm2imp.pl [Glossary_Directory] 

# Run this script to convert an SFM glossary file into an IMP file
# There are three possible parts of the process: 1) convert the SFM to 
# IMP. 2) parse and add Scripture reference links to glossary entries. 
# 3) parse and add "see-also" links to other entries in the glossary.
#
# Begin by updating the config.conf and CF_paratext2imp.txt command 
# file located in the Glossary_Directory (see those files for more 
# info). Then check the log file: Glossary_Directory/OUT_sfm2imp.txt.

#  IMP wiki: http://www.crosswire.org/wiki/File_Formats#IMP
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use File::Spec;
$INPD = shift;
if ($INPD) {$INPD = File::Spec->rel2abs($INPD);}
else {
  my $dproj = "./Example_Glossary";
  print "usage: sfm2imp.pl [Glossary_Directory]\n";
  print "\n";
  print "run default project $dproj? (Y/N):";
  my $in = <>;
  if ($in !~ /^\s*y\s*$/i) {exit;}
  $INPD = File::Spec->rel2abs($dproj);
}
if (!-e $INPD) {
  print "Glossary_Directory does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
require "$SCRD/scripts/common.pl";
&initPaths();

$COMMANDFILE = "$INPD/CF_paratext2imp.txt";
if (open(COMF, "<:encoding(UTF-8)", $COMMANDFILE)) {
  while(<COMF>) {
    if ($_ =~ /^RUN_addScripRefLinks:\s*(.*?)\s*$/) {
      $addscrip = $1;
      if ($addscrip && $addscrip =~ /(1|true)/i) {$addscrip = 1;}
      else {$addscrip = 0;}
    }
    if ($_ =~ /^RUN_addSeeAlsotLinks:\s*(.*?)\s*$/) {
      $addseeal = $1;
      if ($addseeal && $addseeal =~ /(1|true)/i) {$addseeal = 1;}
      else {$addseeal = 0;}
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
if (!$MODPATH) {$MODPATH = "./modules/lexdict/rawld/$MODLC/";}

$IMPFILE = "$INPD/".$MOD.".imp";
$LOGFILE = "$INPD/OUT_sfm2imp.txt";

my $delete;
if (-e $IMPFILE) {$delete .= "$IMPFILE\n";}
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $IMPFILE) {unlink($IMPFILE);}
if (-e $LOGFILE) {unlink($LOGFILE);}

$TMPDIR = "$INPD/tmp/src2imp";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

if ($SWORDBIN && $SWORDBIN !~ /\/\*$/) {$SWORDBIN .= "/";}

&Log("\n-----------------------------------------------------\nSTARTING src2imp.pl\n\n");

# insure the following conf settings are in the conf file
$OSISVersion = $OSISSCHEMA;
$OSISVersion =~ s/(\s*osisCore\.|\.xsd\s*)//ig;
open(CONF, ">>:encoding(UTF-8)", "$CONFFILE") || die "Could not open $CONFFILE\n";
$ret = "\n";
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

# run paratext2imp.pl
$COMMANDFILE = "$INPD/CF_paratext2imp.txt";
if (-e $COMMANDFILE) {
  &Log("\n--- CONVERTING PARATEXT TO IMP\n");
  $DICTWORDS = "$INPD/DictionaryWords.txt";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_1.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/paratext2imp.pl");
  $NOCONSOLELOG = 0;
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

# run addScripRefLinks.pl
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if ($addscrip && !-e $COMMANDFILE) {&Log("ERROR: Skipping Scripture reference parsing. Missing command file: $COMMANDFILE.\n");}
if ($addscrip && -e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  if (!$ConfEntry{"ReferenceBible"}) {
    &Log("WARNING: ReferenceBible is not specified in $CONFFILE.\n");
    &Log("Any companion Bible should be listed in $CONFFILE: ReferenceBible=<BibleModName>\n");
  }
  $INPUTFILE = "$TMPDIR/".$MOD."_1.imp";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_2.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_1.imp", "$TMPDIR/".$MOD."_2.imp");}

# run addSeeAlsoLinks.pl
$COMMANDFILE = "$INPD/CF_addSeeAlsoLinks.txt";
if ($addseeal && !-e $DICTWORDS) {&Log("\nERROR: Skipping see-also link parsing/checking. Missing dictionary listing: $DICTWORDS.\n");}
if ($addseeal && !-e $COMMANDFILE) {&Log("ERROR: Skipping dictionary link parsing/checking. Missing command file: $COMMANDFILE.\n");}
if ($addseeal && -e $COMMANDFILE && -e $DICTWORDS) {
  &Log("\n--- ADDING/CHECKING DICTIONARY LINKS\n");
  $INPUTFILE = "$TMPDIR/".$MOD."_2.imp";
  $OUTPUTFILE = "$INPD/".$MOD.".imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addSeeAlsoLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_2.imp", "$INPD/".$MOD.".imp");}
close(CONF);

1;
