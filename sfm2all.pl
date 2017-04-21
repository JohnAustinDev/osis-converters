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

$INPD = shift; $LOGFILE = shift;

# check for BOM in SFM and clear it if it's there, also normalize line endings to Unix
if (-e "$INPD/sfm") {
  `find "$INPD/sfm" -type f -exec sed '1s/^\xEF\xBB\xBF//' -i.bak {} \\; -exec rm {}.bak \\;`;
  `find "$INPD/sfm" -type f -exec dos2unix {} \\;`;
}

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

# collect all modules to run
my %modules;
$modules{$INPD} = $ConfEntryP->{'ModDrv'};

foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
  if (!-e "$INPD/$companion/config.conf") {
    &Log("ERROR: config.conf of companion project \"$companion\" of \"$MOD\" could not be located for conversion.\n"); 
    next;
  }
  $modules{"$INPD/$companion"} = &readConf("$INPD/$companion/config.conf")->{'ModDrv'};
}

# create each OSIS file and SWORD module, dictionaries last so footnote osisIDs are known during dictionary processing
foreach my $dir (sort {($modules{$a} =~ /LD/ ? 1:0) <=> ($modules{$b} =~ /LD/ ? 1:0)} keys %modules) {
  if (-e "$dir/CF_osis2osis.txt") {&osis_converters("$SCRD/osis2osis.pl", $dir, $LOGFILE);}
  else {&osis_converters("$SCRD/sfm2osis.pl", $dir, $LOGFILE);}
  &osis_converters("$SCRD/osis2sword.pl", $dir, $LOGFILE);
}

# create any GoBibles and eBooks
foreach my $dir (keys %modules) {
  if ($modules{$dir} !~ /Text/) {next;}
  &osis_converters("$SCRD/osis2GoBible.pl", $dir, $LOGFILE);
  &osis_converters("$SCRD/osis2ebooks.pl", $dir, $LOGFILE);
}

# run any specified projects
my $CFfile = (-e "$INPD/CF_usfm2osis.txt" ? "$INPD/CF_usfm2osis.txt":(-e "$INPD/CF_osis2osis.txt" ? "$INPD/CF_osis2osis.txt":''));
my $sfm2all_RUN;
if (open(CF, "<encoding(UTF-8)", $CFfile)) {
  while(<CF>) {if ($_ =~ /^SET_sfm2all_RUN:\s*(.*?)\s*$/) {$sfm2all_RUN = $1; last;}}
  close(CF);
}
if ($sfm2all_RUN) {
  my @runProjects = split(/\s*,\s*/, $sfm2all_RUN);
  foreach my $cp (@runProjects) {
    if ($cp =~ /^\./) {$cp = File::Spec->rel2abs($cp, $INPD);}
    else {$cp = "$INPD/../$cp"}
    if (-e $cp) {`"$SCRD/sfm2all.pl" "$cp"`;} # Run as a separate process with its own separate logfile
  }
}

&Log("\nend time: ".localtime()."\n");

1;
