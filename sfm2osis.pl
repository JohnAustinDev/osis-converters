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

$DEBUG_SKIP_CONVERSION = 0;

use File::Copy;
use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  print "\nusage: sfm2osis.pl [Project_Directory]\n";
  print "\n";
  exit;
}
if (!-e $INPD) {
  print "Project_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf starter file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);

$OSISFILE = "$OUTDIR/".$MOD.".xml";
$LOGFILE = "$OUTDIR/OUT_sfm2osis.txt";

my $delete;
if (-e $OSISFILE) {$delete .= "$OSISFILE\n";}
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $OSISFILE) {unlink($OSISFILE);}
if (-e $LOGFILE) {unlink($LOGFILE);}

$TMPDIR = "$OUTDIR/tmp/sfm2osis";
if (!$DEBUG_SKIP_CONVERSION) {
  if (-e $TMPDIR) {remove_tree($TMPDIR);}
  make_path($TMPDIR);
}

if ($SWORDBIN && $SWORDBIN !~ /[\\\/]$/) {$SWORDBIN .= "/";}

&Log("osis-converters rev: $GITHEAD\n\n");
&Log("\n-----------------------------------------------------\nSTARTING sfm2osis.pl\n\n");

# insure the following conf settings are in the conf file
$OSISVersion = $OSISSCHEMA;
$OSISVersion =~ s/(\s*osisCore\.|\.xsd\s*)//ig;

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

# create DictionaryWords.txt if needed
if ($MODDRV =~ /LD/) {
  use XML::LibXML;
  my $xpc = XML::LibXML::XPathContext->new;
  $xpc->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
  my $parser = XML::LibXML->new();
  my $xml = $parser->parse_file($OUTPUTFILE);
  my @keywords = $xpc->findnodes('//osis:seg[@type="keyword"]', $xml);
  open(DWORDS, ">:encoding(UTF-8)", "$OUTDIR/DictionaryWords_autogen.txt") or die "Could not open $OUTDIR/DictionaryWords_autogen.txt";
  for (my $i=0; $i<@keywords; $i++) {print DWORDS "DE$i:".uc(@keywords[$i]->textContent())."\n";}
  print DWORDS "\n########################################################################\n\n";
  for (my $i=0; $i<@keywords; $i++) {print DWORDS "DL$i:".@keywords[$i]->textContent()."\n";}
  close(DWORDS);
}

# run addScripRefLinks.pl
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if ($addScripRefLinks && !-e $COMMANDFILE) {&Log("ERROR: Skipping Scripture reference parsing. Missing command file: $COMMANDFILE.\n");}
if ($addScripRefLinks && -e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  $INPUTFILE = "$TMPDIR/".$MOD."_1.xml";
  $OUTPUTFILE = "$TMPDIR/".$MOD."_2.xml";
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {copy("$TMPDIR/".$MOD."_1.xml", "$TMPDIR/".$MOD."_2.xml");}

# run addDictLinks.pl or addSeeAlsoLinks.pl
if ($MODDRV =~ /Text/) {
  $COMMANDFILE = "$INPD/CF_addDictLinks.txt";
  if ($addDictLinks && !-e $COMMANDFILE) {&Log("ERROR: Skipping dictionary link parsing/checking. Missing command file: $COMMANDFILE.\n");}
  if ($addDictLinks && -e $COMMANDFILE) {
    &Log("\n--- ADDING DICTIONARY LINKS\n");
    $INPUTFILE = "$TMPDIR/".$MOD."_2.xml";
    $OUTPUTFILE = "$TMPDIR/".$MOD."_3.xml";
    $NOCONSOLELOG = 1;
    require("$SCRD/scripts/addDictLinks.pl");
    $NOCONSOLELOG = 0;
  }
}
elsif ($MODDRV =~ /LD/) {
  $COMMANDFILE = "$INPD/CF_addSeeAlsoLinks.txt";
  if ($addSeeAlsoLinks && !-e "$INPD/$DICTWORDS") {&Log("\nERROR: Skipping see-also link parsing/checking. Missing dictionary listing: $INPD/$DICTWORDS.\n");}
  if ($addSeeAlsoLinks && !-e $COMMANDFILE) {&Log("ERROR: Skipping dictionary link parsing/checking. Missing command file: $COMMANDFILE.\n");}
  if ($addSeeAlsoLinks && -e $COMMANDFILE && -e "$INPD/$DICTWORDS") {
    &Log("\n--- ADDING DICTIONARY LINKS\n");
    $INPUTFILE = "$TMPDIR/".$MOD."_2.xml";
    $OUTPUTFILE = "$OUTDIR/".$MOD."_3.xml";
    $NOCONSOLELOG = 1;
    require("$SCRD/scripts/addSeeAlsoLinks.pl");
    $NOCONSOLELOG = 0;
  }
}
if (!-e "$TMPDIR/".$MOD."_3.xml") {copy("$TMPDIR/".$MOD."_2.xml", "$TMPDIR/".$MOD."_3.xml");}

# run addCrossRefs.pl
if ($addCrossRefs && ($MODDRV =~ /Text/ || $MODDRV =~ /Com/)) {
  &Log("\n--- ADDING CROSS REFERENCES\n");
  $COMMANDFILE = "$INPD/CF_addCrossRefs.txt";
  $INPUTFILE = "$TMPDIR/".$MOD."_3.xml";
  $OUTPUTFILE = $OSISFILE;
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addCrossRefs.pl");
  $NOCONSOLELOG = 0;
}
else {copy("$TMPDIR/".$MOD."_3.xml", $OSISFILE);}

if ($MODDRV =~ /Text/ || $MODDRV =~ /Com/) {
  # order books in OSIS file according to chosen vlln
  require("$SCRD/scripts/toVersificationBookOrder.pl");
  &toVersificationBookOrder($VERSESYS, $OSISFILE);
}

# validate new OSIS file against schema
&Log("\n--- VALIDATING OSIS SCHEMA\n");
&Log("BEGIN OSIS SCHEMA VALIDATION\n");
$cmd = ("$^O" =~ /linux/i ? "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ":'');
$cmd .= $XMLLINT."xmllint --noout --schema \"http://www.bibletechnologies.net/$OSISSCHEMA\" ".&escfile($OSISFILE)." 2>> ".&escfile($LOGFILE);
&Log("$cmd\n");
system($cmd);
&Log("END OSIS SCHEMA VALIDATION\n");

1;
