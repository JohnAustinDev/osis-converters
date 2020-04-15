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

&runAnyUserScriptsAt("sword/preprocess", \$INOSIS);

$Sconf = &getSwordConfFromOSIS($INOSIS);
$SModDrv = $Sconf->{'ModDrv'};
$SModPath = &dataPath2RealPath($Sconf->{'DataPath'});
if (! -e "$SWOUT/$SModPath") {make_path("$SWOUT/$SModPath");}

# Prepare osis-converters OSIS for SWORD import
my %params = (
  'conversion' => 'sword', 
  'MAINMOD_URI' => &getModuleOsisFile($MAINMOD), 
  'DICTMOD_URI' => ($DICTMOD ? &getModuleOsisFile($DICTMOD):'')
);
&runScript("$SCRD/scripts/osis2sword.xsl", \$INOSIS, \%params);

&usePngIfAvailable(\$INOSIS);

if ($SModDrv =~ /GenBook/) {
  &checkChildrensBibleStructure($INOSIS);
  &runScript("$SCRD/scripts/genbook/childrens_bible/genbook2sword.xsl", \$INOSIS);
}

# Apply CrossWire ModuleTools osis2sword.xsl
my $typePreProcess = ($SModDrv =~ /Text/ ? 'osis2sword.xsl':($SModDrv =~ /LD/ ? 'osis2tei.xsl':''));
if ($typePreProcess) {&runScript($MODULETOOLS_BIN.$typePreProcess, \$INOSIS);}

# Uppercasing must be done by Perl to use uc2()
if ($UPPERCASE_DICTIONARY_KEYS) {&upperCaseKeys(\$INOSIS);}

# Copy images and set Feature conf entry
if (&copyReferencedImages(\$INOSIS, $INPD, "$SWOUT/$SModPath")) {
  $Sconf->{'Feature'} = ($Sconf->{'Feature'} ? $Sconf->{'Feature'}."<nx/>":"")."Images";
}

# If this is a DICT module, validate all glossary references in both the
# MAIN and the DICT SWORD source files.
if ($SModDrv =~ /LD/) {
  # find the final MAIN source OSIS file used for its SWORD module
  my $mainmod = &getModuleOsisFile($MAINMOD);
  $mainmod =~ s/\/[^\/]+$//;
  $mainmod .= '/tmp/osis2sword';
  if (opendir(TF, $mainmod)) {
    my @fs = readdir(TF);
    closedir(TF);
    my $n = 0; my $name;
    foreach my $f (@fs) {
      if ($f =~ /^(\d+)/ && int($1) > $n) {
        $n = int($1); $name = $f;
      }
    }
    $mainmod = "$mainmod/$name";
    if (-e $mainmod) {
      # pass MAIN and DICT to checkLinks.xsl script and report results
      my %params = ('mainmodURI' => $mainmod, 'mainmod' => $MAINMOD);
      my $msg = &runScript("$SCRD/scripts/dict/sword/checkLinks.xsl", \$INOSIS, \%params, 0, 1);
      my $err = () = $msg =~ /ERROR/g;
      &Report("Found $err problem(s) with links in $MAINMOD and $DICTMOD.\n");
    }
    else {
      &Error("Could not locate SWORD main module.", 
      "The main SWORD module must be created before the dict SWORD module.");
    }
  }
  else {
    &ErrorBug("Could not open dir $mainmod.");
  }
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
	&ErrorBug("Unhandled module type \"$SModDrv\"; only the following are supported: Bible, Dictionary or General-Book", 1);
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
open(XCONF, $READLAYER, $SwordConfFile) || die "Could not open $SwordConfFile\n";
while(<XCONF>) {&Log("$_", 1);}
close(XCONF);

&timer('stop');

########################################################################
########################################################################

sub usePngIfAvailable($) {
  my $osisP = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  # use png images if available
  my @jpgs = $XPC->findnodes('//osis:figure[contains(@src, ".jpg") or contains(@src, ".JPG")]', $xml);
  foreach my $jpg (@jpgs) {
    my $src = $jpg->getAttribute('src');
    $src =~ /^(.*)(\.jpg)$/i; my $pnm = $1; my $ext = $2;
    if (-e "$INPD/$pnm.png") {
      $jpg->setAttribute('src', "$pnm.png");
      &Note("Changing jpg image to png: ".$jpg->getAttribute('src'));
    }
  }
  
  &writeXMLFile($xml, $osisP);
}

# uppercase dictionary keys were necessary to avoid requiring ICU in SWORD.
# XSLT was not used to do this because a custom uc2() Perl function is needed.
sub upperCaseKeys($) {
  my $osis_or_teiP = shift;
  
  my $xml = $XML_PARSER->parse_file($$osis_or_teiP);
  if (&conf('ModDrv') =~ /LD/) {
    foreach my $keyword ($XPC->findnodes('//*[local-name()="entryFree"]/@n', $xml)) {
      $keyword->setValue(&uc2($keyword->getValue()));
    }
    # These DICT note osisRefs are unnecessary so remove rather than change them
    foreach my $osisRef ($XPC->findnodes('//*[local-name()="note"]/@osisRef', $xml)) {
      $osisRef->unbindNode();
    }
  }
  my @dictrefs = $XPC->findnodes('//*[local-name()="reference"][starts-with(@type, "x-gloss")]/@osisRef', $xml);
  foreach my $dr (@dictrefs) {
    my @new;
    foreach my $dictref (split(/\s+/, $dr->getValue())) {
      my $mod; my $e = &osisRef2Entry($dictref, \$mod);
      push(@new, &entry2osisRef($mod, &uc2($e)));
    }
    $dr->setValue(join(' ', @new));
  }

  &writeXMLFile($xml, $osis_or_teiP);
}

sub dataPath2RealPath($) {
  my $datapath = shift;
  $datapath =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $datapath =~ s/[\\\/]\s*$//; # remove ending slash
  $datapath =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
  return $datapath;
}


1;
