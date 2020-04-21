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

# This script might be loaded on any operating system.

# This script uses 2 passed parameters (the 2nd is optional): $INPD, $LOGFILE

# This is the starting point for osis-converter scripts. The opsys is checked,
# Global variables are initialized or cleaned up, and common.pl is loaded.

# This script must be called with the following line, having X replaced 
# by the calling script's proper sub-directory depth (and don't bother
# trying to shorten anything since 'require' only handles absolute 
# paths, and File::Spec->rel2abs(__FILE__) is the only way to get the 
# script's absolute path, and it must work on both host opsys and 
# Vagrant and the osis-converters installation directory name is 
# unknown):
# use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){X}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();

use File::Spec;
require "$SCRD/scripts/common_opsys.pl";

$WRITELAYER = ">:encoding(UTF-8)";
$APPENDLAYER = ">>:encoding(UTF-8)";
$READLAYER = "<:encoding(UTF-8)".(runningInVagrant() ? ":crlf":''); # crlf read should work with both Windows and Linux, but only use it with Vagrant anyway

$INPD = shift;

# If $LOGFILE is not passed then a new clean one will be started, named $SCRIPT_NAME, during init_linux_script().
# If $LOGFILE is passed, that one will be appended to, or, if the passed value is 'none', there will be no log file.
$LOGFILE = shift; # the special value of 'none' will print to the console with no log file created

$INPD = File::Spec->rel2abs($INPD);
$INPD =~ s/\\/\//g;
$INPD =~ s/\/(sfm|GoBible|eBook|html|sword|images|output)(\/.*?$|$)//; # allow using a subdir as project dir
if (!-e $INPD) {die "Error: Project directory \"$INPD\" does not exist. Check your command line.\n";}
  
if ($LOGFILE && $LOGFILE ne 'none') {
  $LOGFILE = File::Spec->rel2abs($LOGFILE);
  $LOGFILE =~ s/\\/\//g;
}

$SCRIPT = File::Spec->rel2abs($SCRIPT);
$SCRIPT =~ s/\\/\//g;

$SCRD = File::Spec->rel2abs($SCRD);
$SCRD =~ s/\\/\//g;

$SCRIPT_NAME = $SCRIPT; $SCRIPT_NAME =~ s/^.*\/([^\/]+)\.[^\/\.]+$/$1/;

# Set MOD, MAININPD, MAINMOD, DICTINPD and DICTMOD (DICTMOD is updated after 
# checkAndWriteDefaults() in case a new dictionary is discovered in the 
# USFM).
$MOD = $INPD; $MOD =~ s/^.*\///;
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

$CONFFILE = "$MAININPD/config.conf";
&readSetCONF();
# $DICTMOD will be empty if there is no dictionary module for the project, but $DICTINPD always has a value
my $cn = "${MAINMOD}DICT"; $DICTMOD = ($INPD eq $DICTINPD || $CONF->{'Companion'} =~ /\b$cn\b/ ? $cn:'');

# Allow running MAININPD-only scripts from a DICT sub-project
if ($INPD eq $DICTINPD && $SCRIPT =~ /\/(sfm2all|update|osis2ebooks|osis2html|osis2GoBible)\.pl$/) {
  $INPD = $MAININPD;
  $MOD = $MAINMOD;
}

@SUB_PUBLICATIONS = &getSubPublications("$MAININPD/sfm");

if ($INPD eq $DICTINPD && -e "$INPD/CF_osis2osis.txt") {
  &Error("CF_osis2osis.txt in DICT sub-modules are not processed.", 
"To run osis2osis on a DICT sub-module, the CF_osis2osis.txt file 
should still be placed in the main module directory. If you want to run 
sfm2osis.pl on the main module, then ALSO include a CF_usfm2osis.txt 
file in the main module directory.", 1);
}

if (!&init_opsys()) {exit;} # init_opsys also sets Perl global vars with config.conf [system] section entries

require "$SCRD/scripts/functions/common.pl";

1;
