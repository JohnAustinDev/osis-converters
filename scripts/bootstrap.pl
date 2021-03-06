#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2018 John Austin (gpl.programs.info@gmail.com)
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

# This script might be run on Linux, MS-Windows, or MacOS operating systems.

# This is the starting point for all osis-converter scripts. Global 
# variables are initialized, the operating system is checked and a Linux 
# VM is utilized with Vagrant if necessary, and finally init_linux_script() 
# is run to initialize the osis-converters script.

# Scripts are usually called the following way, having N replaced 
# by the calling script's proper sub-directory depth (and don't bother
# trying to shorten anything since 'require' only handles absolute 
# paths, and File::Spec->rel2abs(__FILE__) is the only way to get the 
# script's absolute path, and it must work on both host opsys and 
# Vagrant and the osis-converters installation directory name is 
# unknown):
# use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){N}$//; require "$SCRD/scripts/bootstrap.pl"; &init(shift, shift);

use strict;
use File::Spec;

# Initialized in entry script
our ($SCRIPT, $SCRD);

require "$SCRD/scripts/common_opsys.pl";

sub init() {
  my $inpd = shift; # project directory
  my $logf = shift; # log file (undef=default-log|<path>=append-to-log|'none'=no-log)
  
  # Set Perl globals associated with the project configuration
  &set_configuration_globals($inpd, $logf);

  # Set Perl global variables defined in the [system] section of config.conf.
  &set_system_globals();
  &DebugListVars('SCRD', 'SCRIPT', 'LOGFILE', 'SCRIPT_NAME', 'MOD', 
      'INPD', 'MAINMOD', 'MAININPD', 'DICTMOD', 'DICTINPD',
      our @OC_SYSTEM_PATH_CONFIGS, 'VAGRANT', 'NO_OUTPUT_DELETE');

  # Check that this is a provisioned Linux system (otherwise restart in 
  # Vagrant if possible, and then exit when Vagrant is finished).
  if (!&init_opsys()) {exit;}
  
  # From here on out we're always running on a provisioned Linux system
  # (either natively or as a VM).
  require "$SCRD/scripts/functions/common.pl";
  
  &init_linux_script();
  &DebugListVars('OUTDIR', 'MOD_OUTDIR', 'TMPDIR', 'LOGFILE', 'SCRIPT_NAME');
}

sub set_configuration_globals {
  our $INPD = shift;

  # If $LOGFILE is undef then a new log file named $SCRIPT_NAME will be 
  # started by init_linux_script().
  # If $LOGFILE is 'none' then no log file will be created but log info 
  # will be printed to the console.
  # If $LOGFILE is a file path then that file will be appended to.
  our $LOGFILE = shift;

  $SCRIPT =~ s/\\/\//g;
  $SCRD   =~ s/\\/\//g;

  $INPD = File::Spec->rel2abs($INPD);
  $INPD =~ s/\\/\//g;
  # Allow using a project subdirectory as $INPD argument
  $INPD =~ s/\/(sfm|GoBible|eBook|html|sword|images|output)(\/.*?$|$)//;
  # This works even for MS-Windows because of '\' replacement done above
  $INPD = &shortLinuxPath($INPD);
  if (!-e $INPD) {die 
"Error: Project directory \"$INPD\" does not exist. Check your command line.\n";
  }
    
  if ($LOGFILE && $LOGFILE ne 'none') {
    $LOGFILE = File::Spec->rel2abs($LOGFILE);
    $LOGFILE =~ s/\\/\//g;
  }

  our $SCRIPT_NAME = $SCRIPT; $SCRIPT_NAME =~ s/^.*\/([^\/]+)\.[^\/\.]+$/$1/;
  # Global $forkScriptName will only be set when running in fork.pl, in  
  # which case SCRIPT_NAME is inherited for &conf() values to be correct.
  if (our $forkScriptName) {$SCRIPT_NAME = $forkScriptName;}

  # Set MOD, MAININPD, MAINMOD, DICTINPD and DICTMOD (DICTMOD is updated  
  # after checkAndWriteDefaults() in case a new dictionary is discovered 
  # in the USFM).
  our $MOD = $INPD; $MOD =~ s/^.*\///;
  our ($MAINMOD, $DICTMOD, $MAININPD, $DICTINPD); 
  if ($INPD =~ /^(.*)\/[^\/]+DICT$/) {
    $MAININPD = $1; 
    $DICTINPD = $INPD;
    $MAINMOD = $MAININPD; $MAINMOD =~ s/^.*\///;
  }
  else {
    $MAININPD = $INPD;
    $MAINMOD = $MAININPD; $MAINMOD =~ s/^.*\///;
    $DICTINPD = "$MAININPD/${MAINMOD}DICT";
  }

  # Before testing the project configuration, run bootstrap.pl if it 
  # exists in the project, to prepare any control files that need it.
  if ($MOD eq $MAINMOD && -e "$MAININPD/bootstrap.pl" && 
      $SCRIPT_NAME =~ /^(sfm2all|osis2osis|sfm2osis)$/) {
    &shell("$MAININPD/bootstrap.pl");
  }

  our $CONF;
  our $CONFFILE = "$MAININPD/config.conf";
  if (-e $CONFFILE) {&readSetCONF();}
  # $DICTMOD will be empty if there is no dictionary module for the 
  # project, but $DICTINPD always has a value
  {
   my $cn = "${MAINMOD}DICT"; 
   $DICTMOD = (
      $INPD eq $DICTINPD || $CONF->{"$MAINMOD+Companion"} =~ /\b$cn\b/ 
      ? $cn : '' );
  }

  # Allow running MAININPD-only scripts from a DICT sub-project
  if ($INPD eq $DICTINPD && 
    $SCRIPT =~ /\/(sfm2all|update|osis2ebooks|osis2html|osis2GoBible)\.pl$/) {
    $INPD = $MAININPD;
    $MOD = $MAINMOD;
  }

  our @SUB_PUBLICATIONS = &getSubPublications("$MAININPD/sfm");

  if (@SUB_PUBLICATIONS == 1) {
    &Error("There is only one sub-publication directory: ".@SUB_PUBLICATIONS[0], 
  "When there is a single publication, all source USFM files should be
  located directly under the sfm directory, without any sub-publication 
  directories.", 1);
  }

  if ($INPD eq $DICTINPD && -e "$INPD/CF_osis2osis.txt") {
    &Error("CF_osis2osis.txt in DICT sub-modules are not processed.", 
  "To run osis2osis on a DICT sub-module, the CF_osis2osis.txt file 
  should still be placed in the main module directory. If you want to run 
  sfm2osis.pl on the main module, then ALSO include a CF_usfm2osis.txt 
  file in the main module directory.", 1);
  }
  
  if (our $NO_OUTPUT_DELETE) {our $DEBUG = 1;}
}

1;
