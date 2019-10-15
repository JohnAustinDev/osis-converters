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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();
require "$SCRD/scripts/dict/processGlossary.pl";

&runAnyUserScriptsAt("sword/preprocess", \$INOSIS);

$Sconf = &getSwordConfFromOSIS($INOSIS);
$SModDrv = $Sconf->{'ModDrv'};
$SModPath = &dataPath2RealPath($Sconf->{'DataPath'});
if (! -e "$SWOUT/$SModPath") {make_path("$SWOUT/$SModPath");}

&links2sword(\$INOSIS);

if ($SModDrv =~ /LD/) {&removeDuplicateEntries(\$INOSIS);}
elsif ($SModDrv =~ /Text/) {
  &runScript("$SCRD/scripts/bible/swordText.xsl", \$INOSIS);
  &runScript("$SCRD/scripts/bible/osis2fittedVerseSystem.xsl", \$INOSIS);
}
if ($SModDrv =~ /GenBook/) {
  &checkChildrensBibleStructure($INOSIS);
  &runScript("$SCRD/scripts/genbook/childrens_bible/genbook2sword.xsl", \$INOSIS);
}

my $typePreProcess = ($SModDrv =~ /Text/ ? 'osis2sword.xsl':($SModDrv =~ /LD/ ? 'osis2tei.xsl':''));
if ($typePreProcess) {&runScript($MODULETOOLS_BIN.$typePreProcess, \$INOSIS);}

if ($UPPERCASE_DICTIONARY_KEYS) {&upperCaseKeys(\$INOSIS);}

# Copy images and set Feature conf entry
if (&copyReferencedImages($INOSIS, $INPD, "$SWOUT/$SModPath")) {
  $Sconf->{'Feature'} = ($Sconf->{'Feature'} ? $Sconf->{'Feature'}."<nx/>":"")."Images";
}

# Set MinimumVersion conf entry
$msv = "1.6.1";
if ($Sconf->{'Versification'} ne "KJV") {
  my $vers = &shell(&escfile($SWORD_BIN."osis2mod"), 3);
  if ($vers =~ (/\$rev:\s*(\d+)\s*\$/i) && $1 > 2478) {$msv = "1.6.2";}
  if ($Sconf->{'Versification'} eq "SynodalProt") {$msv = "1.7.0";}
  $Sconf->{'MinimumVersion'} = $msv;
}

# Write the SWORD module
if ($SModDrv =~ /Text/) {
  &Log("\n--- CREATING $MOD SWORD MODULE (".$Sconf->{'Versification'}.")\n");
  &shell(&escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$SModPath")." ".&escfile($INOSIS)." ".($SModDrv =~ /zText/ ? ' -z z':'')." -v ".$Sconf->{'Versification'}.($SModDrv =~ /Text4/ ? ' -s 4':''), -1);
}
elsif ($SModDrv =~ /^RawGenBook$/) {
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE (".$Sconf->{'Versification'}.")\n");
	chdir("$SWOUT/$SModPath");
  &shell(&escfile($SWORD_BIN."xml2gbs")." $INOSIS ".lc($MOD), -1);
	chdir($SCRD);
}
elsif ($SModDrv =~ /LD/) {
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE (".$Sconf->{'Versification'}.")\n");
  &shell(&escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWOUT/$SModPath")." ".&escfile($INOSIS)." -s ".($SModDrv eq "RawLD" ? "2":"4"), -1);
  # tei2mod creates module files called "dict" which are non-standard, so fix
  opendir(MODF, "$SWOUT/$SModPath");
  my @mf = readdir(MODF);
  closedir(MODF);
  foreach my $m (@mf) {
  if ($m !~ /^dict\.(.*?)$/) {next;}
    rename("$SWOUT/$SModPath/$m", "$SWOUT/$SModPath/".lc($MOD).".$1");
  }
}
else {
	&ErrorBug("Unhandled module type \"$SModDrv\".", 'Only the following are supported: Bible, Dictionary or General-Book', 1);
}

# Copy PreferredCSSXHTML css and set PreferredCSSXHTML conf entry
if ($Sconf->{'PreferredCSSXHTML'}) {
  my $cssfile = &getDefaultFile(($SModDrv =~ /LD/ ? 'dict':'bible')."/sword/css/".$Sconf->{'PreferredCSSXHTML'});
  copy($cssfile, "$SWOUT/$SModPath");
  &Log("\n--- COPYING PreferredCSSXHTML \"$cssfile\"\n");
}

# Set InstallSize conf entry
{
  my $installSize = 0;             
  find(sub { $installSize += -s if -f $_ }, "$SWOUT/$SModPath");
  $Sconf->{'InstallSize'} = $installSize;
}

# Write the SWORD config.conf file
$SwordConfFile = "$SWOUT/mods.d/".lc($MOD).".conf";
if (! -e "$SWOUT/mods.d") {mkdir "$SWOUT/mods.d";}
&writeConf($SwordConfFile, $Sconf);
&zipModule($OUTZIP, $SWOUT);

&Log("\n\nFINAL CONF FILE CONTENTS:\n", 1);
open(XCONF, "<:encoding(UTF-8)", $SwordConfFile) || die "Could not open $SwordConfFile\n";
while(<XCONF>) {&Log("$_", 1);}
close(XCONF);

&timer('stop');

########################################################################
########################################################################

# Forwards glossary links targetting a member of an aggregated entry to 
# the aggregated entry because SWORD uses the aggregated entries. 
# Removes some duplicate and chapter nevmenus, which aren't wanted 
# for SWORD. If a jpg image is also available in png, switch it to png.
# Also removes subType="x-external" attributes from references, and
# composite cover images.
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

  my $bibleIntroLinks = &conf("ARG_BibleIntroLinks"); $bibleIntroLinks = ($bibleIntroLinks eq 'true' ? 1:0);
  foreach my $d ($XPC->findnodes('//osis:'.($bibleIntroLinks ? 'div':'item').'[@resp="duplicate"]', $xml)) {
    my $beg = substr($d->textContent, 0, 128); $beg =~ s/[\s\n]+/ /g;
    &Note("Removed duplicate ".($bibleIntroLinks ? 'div':'item')." beginning with: $beg");
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
  
  # Remove composite cover images from SWORD modules (because SWORD intro types are combined by some programs like xulsword)
  my @comps = $XPC->findnodes('//osis:figure[@subType="x-comp-publication"]', $xml);
  foreach my $comp (@comps) {$comp->unbindNode();}

  my $output = $$osisP; $output =~ s/$MOD\.xml$/links2sword.xml/;
  &writeXMLFile($xml, $output, $osisP);
}

sub dataPath2RealPath($) {
  my $datapath = shift;
  $datapath =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $datapath =~ s/[\\\/]\s*$//; # remove ending slash
  $datapath =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
  return $datapath;
}


1;
