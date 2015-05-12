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
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  print "\nusage: sfm2imp.pl [Glossary_Directory]\n";
  print "\n";
  exit;
}
if (!-e $INPD) {
  print "Glossary_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);

$IMPFILE = "$OUTDIR/".$MOD.".imp";
$LOGFILE = "$OUTDIR/OUT_sfm2imp.txt";

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

$TMPDIR = "$OUTDIR/tmp/sfm2imp";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

if ($SWORDBIN && $SWORDBIN !~ /[\\\/]$/) {$SWORDBIN .= "/";}

&Log("osis-converters rev: $GITHEAD\n\n");
&Log("\n-----------------------------------------------------\nSTARTING sfm2imp.pl\n\n");

# insure the following conf settings are in the conf file
$OSISVersion = $OSISSCHEMA;
$OSISVersion =~ s/(\s*osisCore\.|\.xsd\s*)//ig;
$IS_usfm2osis = 0;

# run paratext2imp.pl
$COMMANDFILE = "$INPD/CF_paratext2imp.txt";
if (-e $COMMANDFILE) {
  &Log("\n--- CONVERTING PARATEXT TO IMP\n");
  $OUTPUTFILE = "$TMPDIR/".$MOD."_1.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/paratext2imp.pl");
  $NOCONSOLELOG = 0;
}
else {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

# run addScripRefLinks.pl
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if ($addScripRefLinks && !-e $COMMANDFILE) {&Log("ERROR: Skipping Scripture reference parsing. Missing command file: $COMMANDFILE.\n");}
if ($addScripRefLinks && -e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  $INPUTFILE = "$TMPDIR/".$MOD."_1.imp";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_2.imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_1.imp", "$TMPDIR/".$MOD."_2.imp");}

# run addSeeAlsoLinks.pl
$COMMANDFILE = "$INPD/CF_addSeeAlsoLinks.txt";
if ($addSeeAlsoLinks && !-e $COMMANDFILE) {&Log("ERROR: Skipping dictionary link parsing/checking. Missing command file: $COMMANDFILE.\n");}
if ($addSeeAlsoLinks && -e $COMMANDFILE) {
  &Log("\n--- ADDING DICTIONARY LINKS\n");
  $INPUTFILE = "$TMPDIR/".$MOD."_2.imp";
  $OUTPUTFILE = "$OUTDIR/".$MOD.".imp";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addSeeAlsoLinks.pl");
  $NOCONSOLELOG = 0;
}
else {rename("$TMPDIR/".$MOD."_2.imp", "$OUTDIR/".$MOD.".imp");}
close(CONF);

1;
