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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";
require "$SCRD/scripts/dict/processGlossary.pl";

$STARTOSIS = $INOSIS;
&runAnyUserScriptsAt("sword/preprocess", \$INOSIS);

&links2sword(\$INOSIS);

if (&conf('ModDrv') =~ /LD/) {&removeDuplicateEntries(\$INOSIS);}
elsif (&conf('ModDrv') =~ /Text/) {
  &runScript("$SCRD/scripts/bible/osis2fittedVerseSystem.xsl", \$INOSIS);
  &runScript("$SCRD/scripts/bible/removeLinklessCrossRefs.xsl", \$INOSIS);
}
if (&conf('ModDrv') =~ /GenBook/) {
  &checkChildrensBibleStructure($INOSIS);
  &runScript("$SCRD/scripts/genbook/childrens_bible/genbook2sword.xsl", \$INOSIS);
}

my $typePreProcess = (&conf('ModDrv') =~ /Text/ ? 'osis2sword.xsl':(&conf('ModDrv') =~ /LD/ ? 'osis2tei.xsl':''));
if ($typePreProcess) {&runScript($MODULETOOLS_BIN.$typePreProcess, \$INOSIS);}

if ($UPPERCASE_DICTIONARY_KEYS) {&upperCaseKeys(\$INOSIS);}

if (&copyReferencedImages($INOSIS, $INPD, "$SWOUT/$MODPATH")) {
  $CONF->{'Feature'} = (&conf('Feature') ? &conf('Feature')."<nx/>":"")."Images";
}

# The fonts folder is not a standard SWORD feature
#if (&conf("Font") && $FONTS) {
#  &copyFont(&conf("Font"), $FONTS, \%FONT_FILES, "$SWOUT/fonts", 0);
#}

$msv = "1.6.1";
if (&conf('Versification') ne "KJV") {
  system(&escfile($SWORD_BIN."osis2mod")." 2> ".&escfile("$TMPDIR/osis2mod_vers.txt"));
  open(OUTF, "<:encoding(UTF-8)", "$TMPDIR/osis2mod_vers.txt") || die "Could not open $TMPDIR/osis2mod_vers.txt\n";
  while(<OUTF>) {
    if ($_ =~ (/\$rev:\s*(\d+)\s*\$/i) && $1 > 2478) {
      $msv = "1.6.2"; last;
    }
  }
  close(OUTF);
  unlink("$TMPDIR/osis2mod_vers.txt");
  if (&conf('Versification') eq "SynodalProt") {$msv = "1.7.0";}
  $CONF->{'MinimumVersion'} = $msv;
}

if (&conf('ModDrv') =~ /Text/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $CONF, $CONFFILE, $INOSIS, 1);
  &Log("\n--- CREATING $MOD SWORD MODULE (".&conf('Versification').")\n");
  $cmd = &escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($INOSIS)." ".(&conf('ModDrv') =~ /zText/ ? ' -z z':'')." -v ".&conf('Versification').(&conf('ModDrv') =~ /Text4/ ? ' -s 4':'')." >> ".&escfile($LOGFILE);
  &Log("$cmd\n", -1);
  system($cmd);
}
elsif (&conf('ModDrv') =~ /^RawGenBook$/) {
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $CONF, $CONFFILE, $INOSIS, 1);
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".&conf('Versification').")\n");
	$cmd = &escfile($SWORD_BIN."xml2gbs")." $INOSIS $MODLC >> ".&escfile($LOGFILE);
	&Log("$cmd\n", -1);
	chdir("$SWOUT/$MODPATH");
	system($cmd);
	chdir($SCRD);
}
elsif (&conf('ModDrv') =~ /LD/) {
  # Input file is now TEI with OSIS markup. So get the OSISVersion from the original OSIS file.
  my $sxml = $XML_PARSER->parse_file($STARTOSIS);
  my $vers = @{$XPC->findnodes('//osis:osis/@xsi:schemaLocation', $sxml)}[0];
  if ($vers) {
    $vers = $vers->value; $vers =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
    $CONF->{'OSISVersion'} = $vers;
  }
  
  &writeConf("$SWOUT/mods.d/$MODLC.conf", $CONF, $CONFFILE, $INOSIS, 1);
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE (".&conf('Versification').")\n");
  $cmd = &escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWOUT/$MODPATH")." ".&escfile($INOSIS)." -s ".(&conf('ModDrv') eq "RawLD" ? "2":"4")." >> ".&escfile($LOGFILE);
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
	&ErrorBug("Unhandled module type \"".&conf('ModDrv')."\".", 'Only the following are supported: Bible, Dictionary or General-Book', 1);
}

if (&conf("PreferredCSSXHTML")) {
  my $cssfile = &getDefaultFile((&conf('ModDrv') =~ /LD/ ? 'dict':'bible')."/sword/css/".&conf("PreferredCSSXHTML"));
  copy($cssfile, "$SWOUT/$MODPATH");
  &Log("\n--- COPYING PreferredCSSXHTML \"$cssfile\"\n");
}

$CONFFILE = "$SWOUT/mods.d/$MODLC.conf";
&writeInstallSizeToConf($CONFFILE, "$SWOUT/$MODPATH");

&zipModule($OUTZIP, $SWOUT);

&Log("\n\nFINAL CONF FILE CONTENTS:\n", 1);
open(CONF, "<:encoding(UTF-8)", $CONFFILE) || die "Could not open $CONFFILE\n";
while(<CONF>) {&Log("$_", 1);}
close(CONF);

&timer('stop');

# Forwards glossary links targetting a member of an aggregated entry to 
# the aggregated entry because SWORD uses the aggregated entries. 
# Removes x-glossary-duplicate and chapter nevmenus, which aren't wanted 
# for SWORD. If a jpg image is also available in png, switch it to png.
# Also removes subType="x-external" attributes from references.
sub links2sword($) {
  my $osisP = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my @gks = $XPC->findnodes('//osis:reference[starts-with(@type, "x-gloss")][contains(@osisRef, ".dup")]/@osisRef', $xml);
  foreach my $gk (@gks) {
    my $osisID = $gk->value;
    $osisID =~ s/\.dup\d+$//;
    $gk->setValue($osisID);
  }
  &Report("Forwarded ".scalar(@gks)." link(s) to their aggregated entries.");

  
  foreach my $d ($XPC->findnodes('//osis:div[@type="introduction" and @subType="x-glossary-duplicate"]', $xml)) {
    my $beg = substr($d->textContent, 0, 128); $beg =~ s/[\s\n]+/ /g;
    &Note("Removed x-glossary-duplicate div beginning with: $beg");
    $d->unbindNode();
  }
  
  my $c = 0;
  foreach my $d ($XPC->findnodes('//osis:list[@subType="x-navmenu"][following-sibling::*[1][self::osis:chapter[@eID]]]', $xml)) {
    $d->unbindNode(); $c++;
  }
  &Note("Removed '$c' x-navmenu elements from Bible chapters");
  
  my @jpgs = $XPC->findnodes('//osis:figure[contains(@src, ".jpg") or contains(@src, ".JPG")]', $xml);
  foreach my $jpg (@jpgs) {
    my $src = $jpg->getAttribute('src');
    $src =~ /^(.*)(\.jpg)$/i; my $pnm = $1; my $ext = $2;
    if (-e "$INPD/$pnm.png") {
      $jpg->setAttribute('src', "$pnm.png");
      &Note("Changing jpg image to png: ".$jpg->getAttribute('src'));
    }
  }
  
  my @exts = $XPC->findnodes('//osis:reference[@subType="x-external"]/@subType', $xml);
  foreach my $ext (@exts) {$ext->unbindNode();}

  my $output = $$osisP; $output =~ s/$MOD\.xml$/links2sword.xml/;
  &writeXMLFile($xml, $output, $osisP);
}

1;
