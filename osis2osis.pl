#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
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

# usage: osis2osis.pl [Bible_Directory]

# Run this script to create an OSIS file from a source OSIS file. 
# There are three possible steps in the process:
# 1) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 2) parse and add dictionary links to words 
# which are described in a separate dictionary module. 3) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_osis2osis.txt command 
# file located in the Bible_Directory (see those files for more info). 
# Then check the log file: Bible_Directory/OUT_osis2osis.txt.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$DEBUG = 0;

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

require("$SCRD/scripts/simplecc.pl");

my $osis_in = "";

$COMMANDFILE = "$INPD/CF_osis2osis.txt";
if (! -e $COMMANDFILE) {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open osis2osis command file $COMMANDFILE\n";
while (<COMF>) {
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^SET_(addScripRefLinks|addDictLinks|addCrossRefs|CCTable|companionProject|CONFIG_\w+|CONVERT_\w+):(\s*(.*?)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
      &Log("INFO: Setting $par to $val\n");
    }
  }
  elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
    my $CCIN="../$companionProject/$1"; my $CCOUT="./$1";
    &Log("\nINFO: Processing CC $CCIN\n");
    if ($CCIN =~ /^\./) {$CCIN = File::Spec->rel2abs($CCIN, $INPD);}
    if (! -e $CCIN) {&Log("ERROR Could not find \"$CCIN\" with \"$_\"\n"); next;}
    if (!$CCTable) {&Log("ERROR: Cannot do CC command:\n".$_."You must first specify SET_CCTable:<file-path>\n\n"); next;}
    if ($CCTable =~ /^\./) {$CCTable = File::Spec->rel2abs($CCTable, $INPD);}
    if (! -e $CCTable) {&Log("ERROR Could not find \"$CCTable\" with:\n$_\n"); next;}
    if ($CCOUT =~ /^\./) {$CCOUT = File::Spec->rel2abs($CCOUT, $INPD);}
    
    my $fname = $CCIN; $fname =~ s/^.*\///;
    
    if ($fname eq "config.conf") {
      my $confP = &readConf($CCIN);
      my @convertThese = ('Abbreviation', 'Description', 'About');
      foreach my $e (@convertThese) {$confP->{$e} = &simplecc_convert($confP->{$e}, $CCTable);}
      $confP->{'ModuleName'} = $MOD;
      foreach my $ent (keys %{$confP}) {if (${"CONFIG_$ent"}) {$confP->{$ent} = ${"CONFIG_$ent"};}}
      &writeConf($CCOUT, $confP);
    }
    elsif ($fname eq "collections.txt") {
      if (!$companionProject) {&Log("ERROR: Unable to update collections.txt! To remedy this, specify SET_companionProject in $COMMANDFILE\n"); next;}
      my $newMod = lc($MOD);
      if (!open(CI, "<encoding(UTF-8)", $CCIN)) {&Log("ERROR: Could not open collections.txt input \"$CCIN\"\n"); next;}
      if (!open(CO, ">encoding(UTF-8)", $CCOUT)) {&Log("ERROR: Coult not open collections.txt output \"$CCOUT\"\n"); next;}
      my %col;
      while(<CI>) {
        if ($_ =~ s/^(Collection\:\s*)(\Q$companionProject\E)(.*)$/$1$newMod$3/i) {$col{"$2$3"} = "$newMod$3";}
        else {$_ = &simplecc_convert($_, $CCTable);}
        print CO $_;
      }
      close(CO);
      close(CI);
      if (!%col) {&Log("ERROR: Did not update Collection names in collections.txt\n");}
      else {foreach my $c (sort keys %col) {&Log("Updated Collection \"$c\" to \"".$col{$c}."\"\n");}}
    }
    elsif ($fname eq "convert.txt") {
      if (!open(CI, "<encoding(UTF-8)", $CCIN)) {&Log("ERROR: Could not open convert.txt input \"$CCIN\"\n"); next;}
      if (!open(CO, ">encoding(UTF-8)", $CCOUT)) {&Log("ERROR: Coult not open convert.txt output \"$CCOUT\"\n"); next;}
      while(<CI>) {
        if ($_ =~ /^([\w\d]+)\s*=\s*(.*?)\s*$/) {
          my $e=$1; my $v=$2;
          if ($e !~ /^(Language|Publisher|BookTitlesInOSIS|Epub3|TestamentGroups)$/) {
            $_ = "$e=".&simplecc_convert($v, $CCTable)."\n";
          }
          if (${"CONVERT_$e"}) {$_ = "$e=".${"CONVERT_$e"}."\n";}
        }
        print CO $_;
      }
      close(CO);
      close(CI);
    }
    else {&simplecc($CCIN, $CCTable, $CCOUT);}
  }
  elsif ($_ =~ /^CCOSIS:\s*(.*?)\s*$/) {
    my $osis = $1;
    if (!$companionProject) {&Log("ERROR: Unable to run CCOSIS! To remedy this, specify SET_companionProject in $COMMANDFILE\n"); next;}
    if ($osis =~ /\.xml$/i) {
      if ($osis =~ /^\./) {$osis = File::Spec->rel2abs($osis, $INPD);}
    }
    else {
      if ($OUTDIR eq "$INPD/output") {$osis = "$INPD/../$osis/output/$osis.xml";}
      else {$osis = "$OUTDIR/../$osis/$osis.xml";}
    }
    if (! -e $osis) {&Log("ERROR Could not find \"$osis\" with:\n".$_."You may need to specify OUTDIR in paths.pl.\n"); next;}
    if (!$CCTable) {&Log("ERROR: Cannot do CCOSIS command:\n".$_."You must first specify SET_CCTable:<file-path>\n\n"); next;}
    if ($CCTable =~ /^\./) {$CCTable = File::Spec->rel2abs($CCTable, $INPD);}
    if (! -e $CCTable) {&Log("ERROR Could not find \"$CCTable\" with:\n$_\n"); next;}
    $osis_in = "$TMPDIR/".$MOD."_1.xml";
    &Log("\nINFO: Processing CCOSIS $osis\n");
    &simplecc($osis, $CCTable, $osis_in);
  }
  elsif ($_ =~ /^OSIS_IN:\s*(.*?)\s*$/) {
    $osis_in = $1;
    &Log("\nINFO: Processing OSIS_IN $CCIN\n");
    if ($osis_in =~ /^\./) {$osis_in = File::Spec->rel2abs($osis_in, $INPD);}
    if (! -e $osis_in) {die "ERROR: Specified OSIS file $_ not found. Exiting...\n";}
    copy($osis_in, "$TMPDIR/".$MOD."_1.xml");
  }
  else {&Log("ERROR: Unhandled command:\n".$_."in $COMMANDFILE\n\n");}
}
close(COMF);

if ($osis_in) {require("$SCRD/scripts/processOSIS.pl");}

1;
