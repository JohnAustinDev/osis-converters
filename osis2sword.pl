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

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init(shift, shift);

our ($WRITELAYER, $APPENDLAYER, $READLAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($INOSIS, $SWOUT, $OUTZIP, $MOD_OUTDIR, $SWORD_BIN, $MODULETOOLS_BIN, $XPC, 
    $XML_PARSER, $UPPERCASE_DICTIONARY_KEYS);

&runAnyUserScriptsAt("sword/preprocess", \$INOSIS);

my $Sconf = &getSwordConf($INOSIS);
my $SModDrv = $Sconf->{"$MOD+ModDrv"};
my $SModPath = &dataPath2RealPath($Sconf->{"$MOD+DataPath"});
my $SModVsys = $Sconf->{"$MOD+Versification"};
if (! -e "$SWOUT/$SModPath") {make_path("$SWOUT/$SModPath");}

# Prepare osis-converters OSIS for SWORD import
my %params = (
  'conversion' => 'sword', 
  'MAINMOD_URI' => &getModuleOsisFile($MAINMOD), 
  'DICTMOD_URI' => ($DICTMOD ? &getModuleOsisFile($DICTMOD):'')
);
&LogXSLT(&runScript("$SCRD/scripts/osis2sword.xsl", \$INOSIS, \%params, 3));

&usePngIfAvailable(\$INOSIS);

if ($SModDrv =~ /GenBook/) {
  &checkChildrensBibleStructure($INOSIS);
  &runScript("$SCRD/scripts/genbook/childrens_bible/genbook2sword.xsl", \$INOSIS);
}

# Apply CrossWire ModuleTools osis2sword.xsl
my $OSIS_OR_TEI = $INOSIS; # could be OSIS or TEI after the next step
my $typePreProcess = ($SModDrv =~ /Text/ ? 'osis2sword.xsl':($SModDrv =~ /LD/ ? 'osis2tei.xsl':''));
if ($typePreProcess) {&runScript($MODULETOOLS_BIN.$typePreProcess, \$OSIS_OR_TEI);}

# Uppercasing must be done by Perl to use uc2()
if ($UPPERCASE_DICTIONARY_KEYS) {&upperCaseKeys(\$OSIS_OR_TEI);}

# Copy images and set Feature conf entry
my $imgsAP = &copyReferencedImages(\$OSIS_OR_TEI, $INPD, "$SWOUT/$SModPath");
if (@{$imgsAP}) {
  &setSwordConfValue($Sconf, 'Feature', ($Sconf->{"$MOD+Feature"} ? $Sconf->{"$MOD+Feature"}."<nx/>":"")."Images");
}

# Validate osisRef and src attribtues
my %params;
if ($SModDrv =~ /LD/) {
  # find the final OSIS file that was used to build the MAIN SWORD module
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
      %params = (
        'MAINMOD' => $MAINMOD, 
        'MAINMOD_URI' => $mainmod, 
        'DICTMOD_URI' => $OSIS_OR_TEI
      );
    }
    else {
      &Error("Could not locate SWORD main module.", 
      "The main SWORD module must be created before the dict SWORD module.");
    }
  }
  else {
    &Error("Main module not found, unable to run checkLinks.xsl");
  }
}
else {
  %params = (
    'MAINMOD' => $MAINMOD, 
    'MAINMOD_URI' => $OSIS_OR_TEI,
    'DICTMOD_URI' => ''
  );
}
if (%params) {
  $params{'moduleFiles'} = join('|', @{$imgsAP});
  my $msg = &runXSLT("$SCRD/scripts/dict/sword/checkLinks.xsl", $OSIS_OR_TEI, undef, \%params);
  my $err = () = $msg =~ /ERROR/g;
  &Report("Found $err problem(s) with links of $MAINMOD and $DICTMOD.\n");
}

# Set MinimumVersion conf entry
my $msv = "1.6.1";
if ($SModVsys ne "KJV") {
  my $vers = &shell(&escfile($SWORD_BIN."osis2mod"), 3, 1);
  if ($vers =~ (/\$rev:\s*(\d+)\s*\$/i) && $1 > 2478) {$msv = "1.6.2";}
  if ($SModVsys eq "SynodalProt") {$msv = "1.7.0";}
  &setSwordConfValue($Sconf, 'MinimumVersion', $msv);
}

# Write the SWORD module
if ($SModDrv =~ /Text/) {
  &Log("\n--- CREATING $MOD SWORD MODULE ($SModVsys)\n");
  &shell(&escfile($SWORD_BIN."osis2mod")." ".&escfile("$SWOUT/$SModPath")." ".&escfile($OSIS_OR_TEI)." ".($SModDrv =~ /zText/ ? ' -z z':'')." -v ".$SModVsys.($SModDrv =~ /Text4/ ? ' -s 4':''), -1);
}
elsif ($SModDrv =~ /^RawGenBook$/) {
	&Log("\n--- CREATING $MOD RawGenBook SWORD MODULE ($SModVsys)\n");
	chdir("$SWOUT/$SModPath");
  &shell(&escfile($SWORD_BIN."xml2gbs")." $OSIS_OR_TEI ".lc($MOD), -1);
	chdir($SCRD);
}
elsif ($SModDrv =~ /LD/) {
  &Log("\n--- CREATING $MOD Dictionary TEI SWORD MODULE ($SModVsys)\n");
  &shell(&escfile($SWORD_BIN."tei2mod")." ".&escfile("$SWOUT/$SModPath")." ".&escfile($OSIS_OR_TEI)." -s ".($SModDrv eq "RawLD" ? "2":"4"), -1);
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
if ($Sconf->{"$MOD+PreferredCSSXHTML"}) {
  my $cssfile = &getDefaultFile(($SModDrv =~ /LD/ ? 'dict':'bible')."/sword/css/".$Sconf->{"$MOD+PreferredCSSXHTML"});
  copy($cssfile, "$SWOUT/$SModPath");
  &Log("\n--- COPYING PreferredCSSXHTML \"$cssfile\"\n");
}

# Set InstallSize conf entry
{
  my $installSize = 0;             
  find(sub { $installSize += -s if -f $_ }, "$SWOUT/$SModPath");
  &setSwordConfValue($Sconf, 'InstallSize', $installSize);
}

# Write the SWORD config.conf file
my $SwordConfFile = "$SWOUT/mods.d/".lc($MOD).".conf";
if (! -e "$SWOUT/mods.d") {mkdir "$SWOUT/mods.d";}
&writeConf($SwordConfFile, $Sconf);
&zipModule($OUTZIP, $SWOUT);

# Copy config.conf for CVS
&copy(&escfile($SwordConfFile), "$MOD_OUTDIR/config.conf");

&timer('stop');

########################################################################
########################################################################

sub usePngIfAvailable {
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
sub upperCaseKeys {
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

sub dataPath2RealPath {
  my $datapath = shift;

  $datapath =~ s/([\/\\][^\/\\]+)\s*$//; # remove any file name at end
  $datapath =~ s/[\\\/]\s*$//; # remove ending slash
  $datapath =~ s/^[\s\.]*[\\\/]//; # normalize beginning of path
  return $datapath;
}


1;
