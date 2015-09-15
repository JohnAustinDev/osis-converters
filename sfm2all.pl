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

$DEBUG = 0;

$INPD = shift; $LOGFILE = shift;
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

# create each OSIS file and SWORD module, dictionaries first
foreach my $dir (sort {($modules{$b} =~ /LD/ ? 1:0) <=> ($modules{$a} =~ /LD/ ? 1:0)} keys %modules) {
  &osis_converters("$SCRD/sfm2osis.pl", $dir, $LOGFILE);
  &osis_converters("$SCRD/osis2sword.pl", $dir, $LOGFILE);
}

# create any GoBibles and eBooks
foreach my $dir (keys %modules) {
  if ($modules{$dir} !~ /Text/) {next;}
  &osis_converters("$SCRD/osis2GoBible.pl", $dir, $LOGFILE);
  &osis_converters("$SCRD/osis2ebooks.pl", $dir, $LOGFILE);
}

1;
