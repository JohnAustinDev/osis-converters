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

# usage: osis2sword.pl [Project_Directory]

# Run this script to create raw and zipped SWORD modules from an 
# osis.xml file and a config.conf file located in the Project_Directory.

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$UPPERCASE_DICTIONARY_KEYS = 1;

use File::Spec;
use Cwd;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  print "\nusage: osis2sword.pl [Project_Directory]\n";
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
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);

$OSISFILE = "$OUTDIR/$MOD.xml";
if (!-e $OSISFILE) {print "ERROR: Missing osis file: $OSISFILE. Exiting.\n"; exit;}
$LOGFILE = "$OUTDIR/OUT_osis2sword.txt";

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

$TMPDIR = "$OUTDIR/tmp/osis2sword";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("osis-converters rev: $GITHEAD\n\n");
&Log("\n-----------------------------------------------------\nSTARTING osis2sword.pl\n\n");
if (!-e "$OUTDIR/sword") {make_path("$OUTDIR/sword");}

$IS_usfm2osis = &is_usfm2osis($OSISFILE);
if ($IS_usfm2osis) {
  # uppercase dictionary keys used to be needed to avoid requiring ICU.
  # XSLT cannot be used to do this because a custom uc2() Perl function is needed.
  if ($UPPERCASE_DICTIONARY_KEYS) {
    my $xml = $XML_PARSER->parse_file($OSISFILE);
    my $dict;
    if ($MODDRV =~ /LD/) {
      $dict = $MOD;
      my @keywords = $XPC->findnodes('//'.$KEYWORD.'/text()', $xml);
      foreach my $keyword (@keywords) {$keyword->setData(uc2($keyword->data));}
    }
    else {$dict = $ConfEntry{"Companion"}; $dict =~ s/,.*$//;}
    my @dictrefs = $XPC->findnodes('//osis:reference[contains(@osisRef, "'.$dict.':")]/@osisRef', $xml);
    foreach my $dictref (@dictrefs) {$dictref->setValue(uc2($dictref->value));}
    open(OSIS2, ">$TMPDIR/osis_ucdict.xml");
    print OSIS2 $xml->toString();
    close(OSIS2);
    $OSISFILE = "$TMPDIR/osis_ucdict.xml";
  }
  
  # run xslt if OSIS came from usfm2osis.py
  my $xsl = ''; my $out = '';
  if ($MODDRV =~ /Text/) {$xsl = 'osis2sword.xsl'; $out = "osis";}
  elsif ($MODDRV =~ /LD/) {$xsl = 'osis2tei.xsl'; $out = "tei";}
  if ($xsl) {
    &usfm2osisXSLT($OSISFILE, "$USFM2OSIS/$xsl", "$TMPDIR/$out.xml");
    $OSISFILE = "$TMPDIR/$out.xml";
  }
}

# create and check module's conf file
&updatedSwordConf("$TMPDIR/config.conf");
$CONFFILE = "$TMPDIR/config.conf";

# create raw and zipped modules from OSIS
$SWDD = "$OUTDIR/sword";
remove_tree("$SWDD");
make_path("$SWDD/mods.d");
$defdir = cwd();
if ($MODDRV =~ /Text$/ || $MODDRV =~ /Com\d*$/) {
	require("$SCRD/scripts/makeCompressedMod.pl");
}
elsif ($MODDRV =~ /^RawGenBook$/) {
	copy($CONFFILE, "$SWDD/mods.d/$MODLC.conf");
	make_path("$SWDD/$MODPATH");
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".$VERSESYS.")\n");
	$cmd = &escfile($SWORD_BIN."xml2gbs")." $OSISFILE $MODLC >> ".&escfile($LOGFILE);
	&Log("$cmd\n", -1);
	chdir("$SWDD/$MODPATH");
	system($cmd);
	chdir("$defdir")
}
elsif ($MODDRV =~ /LD/) {
  copy($CONFFILE, "$SWDD/mods.d/$MODLC.conf");
  make_path("$SWDD/$MODPATH");
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWDD/$MODPATH")." ".&escfile($OSISFILE)." -s ".($MODDRV eq "RawLD" ? "2":"4")." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  opendir(MODF, "$SWDD/$MODPATH");
  my @mf = readdir(MODF);
  closedir(MODF);
  foreach my $m (@mf) {
  if ($m !~ /^dict\.(.*?)$/) {next;}
    rename("$SWDD/$MODPATH/$m", "$SWDD/$MODPATH/$MODLC.$1");
  }
}
else {
	&Log("ERROR: Unhandled module type \"$MODDRV\".\n");
	die;
}

$IMAGEDIR = "$INPD/images";
if (-e $IMAGEDIR) {&copy_images_to_module($IMAGEDIR);}

sub copy_images_to_module($) {
	my $imgFile = shift;
	&Log("\n--- COPYING $MOD image(s) \"$imgFile\"\n");
	if (-d $imgFile) {
		my $imagePaths = "INCLUDE IMAGE PATHS.txt";
		&copy_dir($imgFile, "$SWDD/$MODPATH/images", 1, 0, 0, quotemeta($imagePaths));
		if (-e "$imgFile/$imagePaths") { # then copy any additional images located in $imagePaths file
			open(IIF, "<$imgFile/$imagePaths") || die "Could not open \"$imgFile/$imagePaths\"\n";
			while (<IIF>) {
				if ($_ =~ /^\s*#/) {next;}
				chomp;
				if ($_ =~ /^\./) {$_ = "$imgFile/$_";}
				if (-e $_) {&copy_images_to_module($_);}
				else {&Log("ERROR: Image directory listed in \"$imgFile/$imagePaths\" was not found: \"$_\"\n");}
			}
			close(IIF);
		}
	}
	else {
		if (-e "$SWDD/$MODPATH/images/$imgFile") {unlink("$SWDD/$MODPATH/images/$imgFile");} 
		copy($imgFile, "$SWDD/$MODPATH/images");
	}
}

# make a zipped copy of the entire zipped module
&Log("\n--- COMPRESSING ZTEXT MODULE TO A ZIP FILE.\n");
$tmp = "$TMPDIR/sword";
make_path("$tmp/mods.d");
copy("$SWDD/mods.d/$MODLC.conf", "$tmp/mods.d/$MODLC.conf");
&copy_dir("$SWDD/$MODPATH", "$tmp/$MODPATH");
if ("$^O" =~ /MSWin32/i) {
  `7za a -tzip \"$OUTDIR\\$MOD.zip\" -r \"$tmp\\*\"`;
}
else { 
  chdir($tmp);
  `zip -r \"$OUTDIR/$MOD.zip\" ./*`;
  chdir($INPD);
}

&Log("\n");
open(CONF, "<:encoding(UTF-8)", "$SWDD/mods.d/$MODLC.conf") || die "Could not open $SWDD/mods.d/$MODLC.conf\n";
while(<CONF>) {&Log($_);}
close(CONF);

1;
