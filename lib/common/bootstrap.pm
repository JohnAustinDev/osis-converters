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
# variables are initialized, the operating system is checked (and a Linux 
# VM is utilized with Vagrant if necessary) and finally init_linux_script() 
# is run to initialize the osis-converters script.

# Scripts are usually called the following way, having N replaced 
# by the calling script's proper sub-directory depth (and don't bother
# trying to shorten anything since 'require' only handles absolute 
# paths, and File::Spec->rel2abs(__FILE__) is the only way to get the 
# script's absolute path, and it must work on both host opsys and 
# Vagrant and the osis-converters installation directory name is 
# unknown):
# use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){N}$//; require "$SCRD/lib/common/bootstrap.pm"; &init(shift, shift);

use strict;
use Carp qw(longmess);
use Encode;
use File::Copy;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Spec;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

# Must be initialized in entry script:
our ($SCRIPT, $SCRD);

# Conversions to OSIS
# NOTE: 'osis' means sfm2osis unless the project has a source project, 
# in which case it means osis2osis.
our @CONV_OSIS = ('sfm2osis', 'osis2osis', 'osis');

# Conversions from OSIS to others
our @CONV_PUBS = ('sword', 'ebooks', 'gobible', 'html');

# Unsupported conversions of each module type
our %CONV_NOCANDO = (
  'bible'          => undef, 
  'childrensBible' => [ 'gobible' ],
  'dict'           => [ 'ebooks', 'gobible', 'html' ],
  'commentary'     => [ 'ebooks', 'gobible', 'html' ],
);

# Conversion dependencies
our %CONV_DEPENDENCIES = (
  # DICT are converted after MAIN, enabling DICT references to be checked
  'osis DICT'                     => [ 'osis MAIN' ],
  'osis MAIN(with-sourceProject)' => [ 'osis MAIN(sourceProject)', 
                                       'osis DICT(sourceProject)?' ],
  # don't need osis DICT(with-sourceProject) because of osis DICT => osis MAIN
  'sword MAIN'                    => [ 'osis MAIN' ],
  # sword DICT are converted after sword MAIN, enabling SWORD DICT references to be checked
  'sword DICT'                    => [ 'osis DICT', 
                                       'sword MAIN' ],
  'ebooks MAIN'                   => [ 'osis MAIN', 
                                       'osis DICT?' ],
  'html MAIN'                     => [ 'osis MAIN', 
                                       'osis DICT?' ],
  'gobible MAIN'                  => [ 'osis MAIN' ],
);

# Conversion executable dependencies
our %CONV_BIN_DEPENDENCIES = (
  'all'          => [ 'SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2', 'JAVA' ],
  'sfm2osis'     => [ 'XMLLINT' ],
  'osis2osis'    => [ 'XMLLINT' ],
  'osis2sword'   => [ 'SWORD_BIN' ],
  'osis2ebooks'  => [ 'CALIBRE' ],
  'osis2gobible' => [ 'GO_BIBLE_CREATOR' ],
);

#  Host default paths to locally installed osis-converters executables
our %SYSTEM_DEFAULT_PATHS = (
  'MODULETOOLS_BIN'  => "~/.osis-converters/src/Module-tools/bin", 
  'GO_BIBLE_CREATOR' => "~/.osis-converters/GoBibleCreator.245", 
  'SWORD_BIN'        => "~/.osis-converters/src/sword/build/utilities",
);

# Compatibility tests for executable dependencies
our %CONV_BIN_TEST = (
  'SWORD_PERL'       => [ "perl -le 'use Sword; print \$Sword::SWORD_VERSION_STR'", 
                          "1.8.900" ], 
  'MODULETOOLS_BIN'  => [ "'MODULETOOLS_BIN/usfm2osis.py'",
                          "Revision: 491" ], 
  'XMLLINT'          => [ "xmllint --version",
                          "xmllint: using libxml" ],
  'SWORD_BIN'        => [ "'SWORD_BIN/osis2mod'",
                          "You are running osis2mod: \$Rev: 3431 \$" ],
  'CALIBRE'          => [ "ebook-convert --version",
                          "calibre 5" ],
  'GO_BIBLE_CREATOR' => [ "java -jar 'GO_BIBLE_CREATOR/GoBibleCreator.jar'", 
                          "Usage" ],
  # XSLT2 also requires that openjdk 10.0.1 is NOT being used 
  # because its Unicode character classes fail with saxonb-xslt.
  'XSLT2'            => [ 'saxonb-xslt',
                          "Saxon 9" ],
  'JAVA'             => [ 'java -version', 
                          "openjdk version \"10.", 1 ], # NOT openjdk 10.
);

# Ouput files for each conversion type (MOD will be replaced with $MOD)
our %CONV_OUTPUT_TEST = (
  'sfm2osis'     => [ 'MOD.xml' ],
  'osis2osis'    => [ 'MOD.xml' ],
  'osis2sword'   => [ 'MOD.zip' ],
  'osis2ebooks'  => [ 'eBook/*.epub', 
                      'eBook/*.azw3',
                      'eBook/*/*.epub', 
                      'eBook/*/*.azw3' ],
  'osis2html'    => [ 'html/*/index.xhtml' ],
  'osis2gobible' => [ 'GoBible/MOD/*.jar' ],
);

require "$SCRD/lib/common/common_opsys.pm";

sub init() {
  my $inpd = shift; # project directory
  my $logf = shift; # log file (undef=default-log|<path>=append-to-log|'none'=no-log)
  
  # Set Perl globals associated with the project configuration
  &set_configuration_globals($inpd, $logf);
  
  &checkInputs();

  # Set Perl global variables defined in the [system] section of config.conf.
  &set_system_globals(our $MAINMOD);
  &set_system_default_paths();
  &DebugListVars('SCRD', 'SCRIPT', 'LOGFILE', 'SCRIPT_NAME', 'MOD', 
      'INPD', 'MAINMOD', 'MAININPD', 'DICTMOD', 'DICTINPD',
      our @OC_SYSTEM_PATH_CONFIGS, 'VAGRANT', 'NO_OUTPUT_DELETE');

  # Check that this is a provisioned Linux system (otherwise restart in 
  # Vagrant if possible, and then exit when Vagrant is finished).
  if (!&init_opsys()) {exit;}
  
  # From here on out we're always running on a provisioned Linux system
  # (either natively or as a VM).
  require "$SCRD/lib/common/common.pm";
  
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
  $INPD = &shortPath($INPD);
  if (!-e $INPD) {die 
"Error: Project directory \"$INPD\" does not exist. Check your command line.\n";
  }
    
  if ($LOGFILE && $LOGFILE ne 'none') {
    $LOGFILE = File::Spec->rel2abs($LOGFILE);
    $LOGFILE =~ s/\\/\//g;
  }
  
  our $SCRIPT_NAME = $SCRIPT; $SCRIPT_NAME =~ s/^.*\/([^\/]+)(\.[^\/\.]+)?$/$1/;
  # Global $forkScriptName will only be set when running in fork.pm, in  
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
      $SCRIPT_NAME =~ /^(osis2osis|sfm2osis)$/) {
    &shell("$MAININPD/bootstrap.pl");
  }

  our $CONF;
  our $CONFFILE = "$MAININPD/config.conf";
  if (-e $CONFFILE) {&readSetCONF(1);}
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
    $SCRIPT =~ /\/(defaults|osis2ebooks|osis2html|osis2gobible)$/) {
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
  should still be placed in the main module directory. If you want to  
  run sfm2osis on the main module, then ALSO include a CF_usfm2osis.txt 
  file in the main module directory.", 1);
  }
  
  if (our $NO_OUTPUT_DELETE) {our $DEBUG = 1;}
}

sub checkInputs {

  our ($SCRIPT_NAME, $INPD);
  my $usage = "
USAGE: $SCRIPT_NAME [directory] [log-file]

directory : Path to an osis-converters project directory having an 'sfm'
            subdirectory containing USFM files. Default is the working 
            directory.
log-file  : Path/filename for the log file. Default is OUT_${SCRIPT_NAME}_MOD.txt 
            in the OUTDIR directory determined by config.conf.
";
  if (!-d $INPD) {
print "ABORT: Not a directory: '$INPD'\n";
    print $usage;
    exit 1;
  }
  elsif (!-d "$INPD/sfm" && !-d "$INPD/../sfm" && 
         !-e "$INPD/CF_osis2osis.txt" && !-e "$INPD/../CF_osis2osis.txt") {
print "ABORT: Not an osis-converters project: '$INPD'\n";
    print $usage;
    exit 1;
  }
}

1;
