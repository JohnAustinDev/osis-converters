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

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

$OSISFILE = "$OUTDIR/$MOD.xml";

$IS_usfm2osis = &is_usfm2osis($OSISFILE);
if ($IS_usfm2osis) {
  my $outtype = 'osis';
  
  # Forward glossary links targetting a member of an aggregated entry to the aggregated entry
  my $processing = "$TMPDIR/1_osis.xml";
  my $xml = $XML_PARSER->parse_file($OSISFILE);
  my @gks = $XPC->findnodes('//osis:reference[starts-with(@type, "x-gloss")][contains(@osisRef, ".dup")]/@osisRef', $xml);
  foreach my $gk (@gks) {
    my $osisID = $gk->value;
    $osisID =~ s/\.dup\d+$//;
    $gk->setValue($osisID);
  }
  &Log("$MOD REPORT: Forwarded ".scalar(@gks)." link(s) to their aggregated entries.\n");
  
  # Remove x-glossary-duplicate
  foreach my $d ($XPC->findnodes('//osis:div[@type="introduction" and @subType="x-glossary-duplicate"]', $xml)) {
    my $beg = substr($d->textContent, 0, 128); $beg =~ s/[\s\n]+/ /g;
    &Log("NOTE: Removed x-glossary-duplicate div beginning with: $beg\n");
    $d->unbindNode();
  }
  
  open(OSIS2, ">$processing");
  print OSIS2 $xml->toString();
  close(OSIS2);
  
  # run xslt if OSIS came from usfm2osis.py
  my $xsl = '';
  if ($MODDRV =~ /Text/) {
    $xsl = 'osis2sword.xsl';
  }
  elsif ($MODDRV =~ /LD/) {
    $xsl = 'osis2tei.xsl';
    $outtype = "tei";
    require "$SCRD/scripts/processGlossary.pl";
    &removeDuplicateEntries($processing);
  }
  my $output = "$TMPDIR/2_".$outtype.".preprocessed.xml";
  &userXSLT("$INPD/sword/preprocess.xsl", $processing, $output);
  $processing = $output;
  if ($xsl) {
    $output = "$TMPDIR/3_".$outtype."_xslts.xml";
    &runXSLT($MODULETOOLS_BIN.$xsl, $processing, $output);
    $processing = $output;
  }
  
  # uppercase dictionary keys were necessary to avoid requiring ICU.
  # XSLT was not used to do this because a custom uc2() Perl function is needed.
  if ($UPPERCASE_DICTIONARY_KEYS) {
    my $xml = $XML_PARSER->parse_file($processing);
    if ($MODDRV =~ /LD/) {
      my @keywords = $XPC->findnodes('//*[local-name()="entryFree"]/@n', $xml);
      foreach my $keyword (@keywords) {$keyword->setValue(&uc2($keyword->getValue()));}
    }
    my @dictrefs = $XPC->findnodes('//*[local-name()="reference"][starts-with(@type, "x-gloss")]/@osisRef', $xml);
    foreach my $dictref (@dictrefs) {
      my $mod; my $e = &osisRef2Entry($dictref->getValue(), \$mod);
      $dictref->setValue(&entry2osisRef($mod, &uc2($e)));
    }
    my $p = "$TMPDIR/3_".$outtype."_ucdict.xml";
    open(OSIS2, ">$p");
    print OSIS2 $xml->toString();
    close(OSIS2);
    $processing = $p;
  }
  
  $OSISFILE = $processing;
}

if (&copyReferencedImages($OSISFILE, $INPD, "$SWOUT/$MODPATH")) {
  $ConfEntryP->{'Feature'} = ($ConfEntryP->{'Feature'} ? $ConfEntryP->{'Feature'}."<nx/>":"")."Images";
}

if ($ConfEntryP->{"Font"} && $FONTS) {
  &copyFont($ConfEntryP->{"Font"}, $FONTS, \%FONT_FILES, "$SWOUT/fonts", 0);
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

if ($MODDRV =~ /Text/) {
	$ConfEntryP->{'Category'} = 'Biblical Texts';
  
  if ($MODDRV =~ /zText/) {
    $ConfEntryP->{'CompressType'} = 'ZIP';
    $ConfEntryP->{'BlockType'} = 'BOOK';
  }

  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $OSISFILE);
  &Log("\n--- CREATING $MOD SWORD MODULE (".$VERSESYS.")\n");
  $cmd = &escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($OSISFILE)." ".($MODDRV =~ /zText/ ? ' -z z':'').($VERSESYS ? " -v $VERSESYS":'').($MODDRV =~ /Text4/ ? ' -s 4':'')." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
  
  &emptyvss($SWOUT);
}
elsif ($MODDRV =~ /^RawGenBook$/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $OSISFILE);
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".$VERSESYS.")\n");
	$cmd = &escfile($SWORD_BIN."xml2gbs")." $OSISFILE $MODLC >> ".&escfile($LOGFILE);
	&Log("$cmd\n", -1);
	chdir("$SWOUT/$MODPATH");
	system($cmd);
	chdir($SCRD);
}
elsif ($MODDRV =~ /LD/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $OSISFILE);
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
if ($ConfEntryP->{"PreferredCSSXHTML"} && ! -e "$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}) {
  &Log("ERROR: The conf file specifies PreferredCSSXHTML but it was not found at \"$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}."\".\n");
}
elsif (-e "$INPD/sword/css") {
  if ($ConfEntryP->{"PreferredCSSXHTML"}) {
    copy("$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}, "$SWOUT/$MODPATH");
    &Log("\n--- COPYING PreferredCSSXHTML \"$INPD/sword/css/".$ConfEntryP->{"PreferredCSSXHTML"}."\"\n");
  }
  else {&Log("ERROR: \"$INPD/sword/css\" directory exists, but conf file lacks a PreferredCSSXHTML entry.\n");}
}

&writeInstallSizeToConf($CONFFILE, "$SWOUT/$MODPATH");

&zipModule($OUTZIP, $SWOUT);

&Log("\n\nFINAL CONF FILE CONTENTS:\n", 1);
open(CONF, "<:encoding(UTF-8)", $CONFFILE) || die "Could not open $CONFFILE\n";
while(<CONF>) {&Log("$_", 1);}
close(CONF);

&Log("\nend time: ".localtime()."\n");

1;
