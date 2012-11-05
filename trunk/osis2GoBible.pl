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

# usage: osis2GoBible.pl [Bible_Directory]

# Run this script to create GoBible mobile phone Bibles from an osis 
# file. The following input files need to be in a 
# "Bible_Directory/GoBible" sub-directory:
#    collections.txt            - build-control file
#    ui.properties              - user interface translation
#    icon.png                   - icon for the application
#    normalChars.txt (optional) - character replacement file
#    simpleChars.txt (optional) - simplified character replacement file

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# GoBible wiki: http://www.crosswire.org/wiki/Projects:Go_Bible

use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  my $dproj = "./Example_GoBible";
  print "\nusage: osis2GoBible.pl [Bible_Directory]\n";
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
if (!$GOCREATOR || !-e $GOCREATOR) {
  print "Please specify the path to Go Bible Creator in \"$PATHFILE\". Exiting.\n";
  exit;
}

require("$SCRD/scripts/goBibleConvChars.pl");

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);

$GOBIBLE = "$INPD/GoBible";
if (!-e $GOBIBLE) {print "ERROR: Missing GoBible directory: $GOBIBLE. Exiting.\n"; exit;}

$GBOUT = "$OUTDIR/GoBible/$MOD$REV";

$LOGFILE = "$OUTDIR/OUT_osis2GoBible.txt";
my $delete;
if (-e $GBOUT) {$delete .= "$GBOUT\n";}
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $GBOUT) {remove_tree($GBOUT);}
if (-e $LOGFILE) {unlink($LOGFILE);}

make_path($GBOUT);

$TMPDIR = "$OUTDIR/tmp/osis2GoBible";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("\n-----------------------------------------------------\nSTARTING osis2GoBible.pl\n\n");


&Log("\n--- Creating Go Bible osis.xml file...\n");
$INPUTFILE = "$OUTDIR/$MOD.xml";
$OUTPUTFILE = "$TMPDIR/osis.xml";
require("$SCRD/scripts/goBibleFromOsis.pl");

@FILES = ("$GOBIBLE/ui.properties", "$GOBIBLE/collections.txt", "$TMPDIR/osis.xml");
foreach my $f (@FILES) {
  if (!-e $f) {&Log("ERROR: Missing required file: $f\n");}
}
if (!-e "$GOBIBLE/icon.png") {&Log("ERROR: Missing icon file: $GOBIBLE/icon.png");}

&Log("\n--- Converting characters (normal)\n");
&goBibleConvChars("normal", \@FILES);
copy("$GOBIBLE/icon.png", "$TMPDIR/normal/icon.png");
&makeGoBible("normal");

if (-e "$GOBIBLE/simpleChars.txt") {
  &Log("\n--- Converting characters (simple)\n");
  &goBibleConvChars("simple", \@FILES);
  copy("$GOBIBLE/icon.png", "$TMPDIR/simple/icon.png");
  &makeGoBible("simple");
}
else {&Log("WARN: Skipping simplified character apps; missing $GOBIBLE/simpleChars.txt\n");}

sub makeGoBible($) {
  my $type = shift;
  &Log("\n--- Running Go Bible Creator with collections.txt\n");
  copy("$TMPDIR/$type/ui.properties", "$GOCREATOR/GoBibleCore/ui.properties");
  chdir($GOCREATOR);
  system("java -jar GoBibleCreator.jar ".&escfile("$TMPDIR/$type/collections.txt")." >> ".&escfile($LOGFILE));
  chdir($INPD);

  &Log("\n--- Copying module to MKS directory $MOD$REV\n");
  chdir("$TMPDIR/$type");
  opendir(DIR, "./");
  my @f = readdir(DIR);
  closedir(DIR);
  for (my $i=0; $i < @f; $i++) {
    if ($f[$i] !~ /\.(jar|jad)$/i) {next;}
    copy("$TMPDIR/$type/$f[$i]", "$GBOUT/$f[$i]");
  }
}
;1
