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

$INPD = shift;
use File::Spec;
$SCRD = File::Spec->rel2abs(__FILE__);
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl"; 
&init(__FILE__);

$OSISFILE = "$OUTDIR/$MOD.xml";


$IS_usfm2osis = &is_usfm2osis($OSISFILE);
if ($IS_usfm2osis) {
  # uppercase dictionary keys were necessary to avoid requiring ICU.
  # XSLT cannot be used to do this because a custom uc2() Perl function is needed.
  if ($UPPERCASE_DICTIONARY_KEYS) {
    my $xml = $XML_PARSER->parse_file($OSISFILE);
    if ($MODDRV =~ /LD/) {
      my @keywords = $XPC->findnodes('//'.$KEYWORD.'/text()', $xml);
      foreach my $keyword (@keywords) {$keyword->setData(uc2($keyword->data));}
    }
    my @dictrefs = $XPC->findnodes('//osis:reference[type=\'x-glossary\' or type=\'x-glosslink\']/@osisRef', $xml);
    foreach my $dictref (@dictrefs) {
      $ref = $dictref->value;
      if ($ref !~ /^(\w+):(.*)$/) {&Log("ERROR: bad osisRef \"$ref\"\n");}
      $dictref->setValue($1.":".uc2($2));
    }
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

$msv = "1.6.1";
if ($VERSESYS && $VERSESYS ne "KJV") {
  system(&escfile($SWORD_BIN."osis2mod")." 2> ".&escfile("$TMPDIR/osis2mod_vers.txt"));
  open(OUTF, "<:encoding(UTF-8)", "$TMPDIR/osis2mod_vers.txt") || die "Could not open $TMPDIR/osis2mod_vers.txt\n";
  while(<OUTF>) {
    if ($_ =~ (/\$rev:\s*(\d+)\s*\$/i) && $1 > 2478) {
      $msv = "1.6.2"; last;
    }
  }
  close(OUTF);
  unlink("$TMPDIR/osis2mod_vers.txt");
  if ($VERSESYS eq "SynodalProt") {$msv = "1.7.0";}
  $ConfEntryP->{'MinimumVersion'} = $msv;
}

$defdir = cwd();
if ($MODDRV =~ /Text$/) {
	$ConfEntryP->{'Category'} = 'Biblical Texts';
  
  if ($MODDRV eq 'zText') {
    $ConfEntryP->{'CompressType'} = 'ZIP';
    $ConfEntryP->{'BlockType'} = 'BOOK';
  }

  &writeConf($CONFFILE, $ConfEntryP, $OSISFILE, "$SWOUT/mods.d/$MODLC.conf");
  &Log("\n--- CREATING $MOD SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($OSISFILE)." ".($MODDRV eq 'zText' ? ' -z z':'').($VERSESYS ? " -v $VERSESYS":'')." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  
  &Log("\n--- TESTING FOR EMPTY VERSES\n");
  $cmd = &escfile($SWORD_BIN."emptyvss")." 2>&1";
  $cmd = `$cmd`;
  if ($cmd =~ /usage/i) {
    &Log("BEGIN EMPTYVSS OUTPUT\n", -1);
    chdir($SWOUT);
    $cmd = &escfile($SWORD_BIN."emptyvss")." $MOD >> ".&escfile($LOGFILE);
    system($cmd);
    &Log("END EMPTYVSS OUTPUT\n", -1);
  }
  else {&Log("ERROR: Could not check for empty verses. Sword tool \"emptyvss\" could not be found. It may need to be compiled locally.");}
  chdir($INPD);
}
elsif ($MODDRV =~ /^RawGenBook$/) {
  &writeConf($CONFFILE, $ConfEntryP, $OSISFILE, "$SWOUT/mods.d/$MODLC.conf");
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".$VERSESYS.")\n");
	$cmd = &escfile($SWORD_BIN."xml2gbs")." $OSISFILE $MODLC >> ".&escfile($LOGFILE);
	&Log("$cmd\n", -1);
	chdir("$SWOUT/$MODPATH");
	system($cmd);
	chdir("$defdir")
}
elsif ($MODDRV =~ /LD/) {
  &writeConf($CONFFILE, $ConfEntryP, $OSISFILE, "$SWOUT/mods.d/$MODLC.conf");
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($OSISFILE)." -s ".($MODDRV eq "RawLD" ? "2":"4")." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  # tei2mod creates module files called "dict" which are non-standard, so fix
  opendir(MODF, "$SWOUT/$MODPATH");
  my @mf = readdir(MODF);
  closedir(MODF);
  foreach my $m (@mf) {
  if ($m !~ /^dict\.(.*?)$/) {next;}
    rename("$SWOUT/$MODPATH/$m", "$SWOUT/$MODPATH/$MODLC.$1");
  }
}
else {
	&Log("ERROR: Unhandled module type \"$MODDRV\".\n");
	die;
}
$CONFFILE = "$SWOUT/mods.d/$MODLC.conf";

if (-e "$INPD/images") {&copy_images_to_module("$INPD/images", "$SWOUT/$MODPATH");}

&writeInstallSizeToConf("$SWOUT/$MODPATH", $CONFFILE);

&zipModule($SWOUT, $OUTZIP);

&Log("\n\n");
open(CONF, "<:encoding(UTF-8)", $CONFFILE) || die "Could not open $CONFFILE\n";
while(<CONF>) {&Log("$_", 1);}
close(CONF);
