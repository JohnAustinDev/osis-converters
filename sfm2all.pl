#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
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

# usage: sfm2all.pl [Project_Directory]
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";

# collect all modules to run
my %modules;
$modules{$INPD} = &conf('ModDrv');

if (&conf('Companion')) {
  foreach $companion (split(/\s*,\s*/, &conf('Companion'))) {
    if ($companion !~ /DICT$/) {next;}
    if (!-e "$INPD/$companion") {
      &Error("Companion project \"$companion\" of \"$MOD\" could not be located for conversion.", 
"There should be a $companion subdirectory of $MOD which 
contains command files and resources for the DICT module."); 
    }
    if (!&conf("$companion+ModDrv")) {
      &Error("ModDrv of companion project \"$companion\" is not specified in $CONFFILE.", 
"Specify the ModDrv entry in the [$companion] section of $CONFFILE.");
    }
    else {$modules{"$INPD/$companion"} = &conf("$companion+ModDrv");}
  }
}

# create each OSIS file and SWORD module.
# NOTE: any dictionary module must be last so footnote osisIDs may be  
# known during dictionary processing, even though this means the default 
# run of the project can never perform addDictLinks (and who cares, 
# since it wouldn't be useful anwyway).
foreach my $dir (sort {($modules{$a} =~ /LD/ ? 1:0) <=> ($modules{$b} =~ /LD/ ? 1:0)} keys %modules) {
  if (-e "$dir/CF_usfm2osis.txt") {&osis_converters("$SCRD/sfm2osis.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));}
  else {&osis_converters("$SCRD/osis2osis.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));}
  &osis_converters("$SCRD/osis2sword.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));
}

# create any GoBibles and eBooks
foreach my $dir (keys %modules) {
  if ($modules{$dir} =~ /LD/) {next;}
  if ($modules{$dir} =~ /Text/) {
    &osis_converters("$SCRD/osis2GoBible.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));
  }
  &osis_converters("$SCRD/osis2html.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));
  &osis_converters("$SCRD/osis2ebooks.pl", $dir, (!$SFM2ALL_SEPARATE_LOGS ? $LOGFILE:''));
}

# run any other projects specified by SET_sfm2all_RUN
my $defDir = ($INPD =~ /DICT\/?\s*$/ ? 'dict':'bible');
my $CFfile = &getDefaultFile("$defDir/CF_usfm2osis.txt", 1);
if (!$CFfile) {$CFfile = &getDefaultFile("$defDir/CF_osis2osis.txt", 1);}
if (!$CFfile) {&Error("The project must have either CF_usfm2osis.txt or CF_osis2osis.txt to run sfm2all.pl", '', 1);}
my $sfm2all_RUN;
if (open(CF, "<:encoding(UTF-8)", $CFfile)) {
  while(<CF>) {if ($_ =~ /^SET_sfm2all_RUN:\s*(.*?)\s*$/) {$sfm2all_RUN = $1; last;}}
  close(CF);
}
if ($sfm2all_RUN) {
  my @runProjects = split(/\s*,\s*/, $sfm2all_RUN);
  foreach my $cp (@runProjects) {
    if ($cp =~ /^\./) {$cp = File::Spec->rel2abs($cp, $INPD);}
    else {$cp = "$INPD/../$cp"}
    if (-e $cp) {
      my $cmd = "\"$SCRD/sfm2all.pl\" \"$cp\"";
      &Log("\n-----------------------------------------------------\nRUNNING $cmd\n\n");
      open(SFM2ALL, "$cmd |");
      while(<SFM2ALL>) {print $_;}
      close(SFM2ALL);
    }
  }
}

&timer('stop');

1;
