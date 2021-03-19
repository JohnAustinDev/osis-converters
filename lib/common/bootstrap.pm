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

# These are set in config.conf by set_system_globals()
#our $DEBUG = 1;
#our $VAGRANT = 1;

use strict;
use Carp qw(longmess);
use Encode;
use File::Copy;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Spec;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

our $OC_VERSION = "1.9";

# These two globals must be initialized in the entry script:
our ($SCRIPT, $SCRD, $SCRIPT_NAME);

# Conversion to OSIS executables
our @CONV_OSIS = ('sfm2osis', 'osis2osis');

# Conversion from OSIS to publication executables
our @CONV_PUBS = ('osis2ebooks', 'osis2html', 'osis2sword', 'osis2gobible');
sub CONV_PUBS {
  my @p; foreach (@CONV_PUBS) {if (/^osis2(.*)$/) {push(@p, $_);}}
  return @p;
}

# Other osis-converters executables
our @CONV_OTHER = ('convert', 'defaults');

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

# Conversion output subdirectories (MOD will be replaced with $MOD)
our %CONV_OUTPUT_SUBDIR = (
  'osis2ebooks'  => 'eBook',
  'osis2html'    => 'html',
  'osis2gobible' => 'GoBible/MOD',
);

# Ouput files generated by each conversion (MOD will be replaced with $MOD)
our %CONV_OUTPUT_FILES = (
  'sfm2osis'     => [ 'MOD.xml' ],
  'osis2osis'    => [ 'MOD.xml' ],
  'osis2sword'   => [ 'MOD.zip',
                      'config.conf' ],
  'osis2ebooks'  => [ '*.epub', 
                      '*.azw3',
                      '*/*.epub', 
                      '*/*.azw3' ],
  'osis2html'    => [ '*/index.xhtml',
                      '*/*' ],
  'osis2gobible' => [ '*.jar', 
                      '*.jad' ],
);
sub CONV_OUTPUT_FILES {
  my $conversion = shift;
  
  my %u;
  foreach (@{$CONV_OUTPUT_FILES{$conversion}}) {
    if (/\.([^\.]+)$/) {$u{$1}++;}
  }
  return sort keys %u;
}

# Publication sets output by each conversion: 'tran' is the entire
# Bible translation, 'subpub' is one of any SUB_PUBLICATIONS, 'tbook' is 
# a single Bible-book publication which is part of the 'tran' 
# publication and 'book' is a single Bible-book publication taken as a 
# part of the 'subpub'.
our %CONV_PUB_SETS = (
  'sword'   => [ 'tran' ],
  'gobible' => [ 'tran' ], #  'SimpleChar', 'SizeLimited'
  'ebooks'  => [ 'tran', 'subpub', 'tbook', 'book' ],
  'html'    => [ 'tran', 'subpub', 'tbook', 'book' ],
);

{
my %h; 
foreach my $c (keys %CONV_PUB_SETS) {map($h{$_}++, @{$CONV_PUB_SETS{$c}});}
our @CONV_PUB_SETS = (sort { length($b) <=> length($a) } keys %h);
}

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

$SCRIPT =~ s/\\/\//g;
$SCRD   =~ s/\\/\//g;

# Don't reset, in case a fork already set SCRIPT_NAME
if (! $SCRIPT_NAME) {
  $SCRIPT_NAME = &scriptName();
}

print "Running $SCRIPT_NAME version $OC_VERSION\n";
require "$SCRD/lib/common/common_opsys.pm";
require "$SCRD/lib/common/help.pm";

# This init will exit with 1 on error, or 0 on help or Vagrant-restart.
# Otherwise it returns after initializing the Perl globals expected by 
# the calling script.
sub init() {
  our %ARGS = &arguments(@_);
  
  our ($MAINMOD, $INPD, $LOGFILE, $SCRIPT_NAME, $HELP, $OSIS2OSIS_PASS);
  
  if ($ARGS{'abort'}) {
    print &usage();
    exit 1;
  }
  elsif (exists($ARGS{'h'}) && !$HELP) {
    print &usage() . "\n";
    print &help("$SCRIPT_NAME;Synopsis");
    exit 0;
  }
  elsif (exists($ARGS{'h'}) && $HELP) {
    print &usage() . "\n";
    print &help($HELP);
    exit 0;
  }
  
  # 'convert' doesn't need  a particular $INPD directory or config
  # and does its own Vagrant checking and .vm.conf initialization.
  if ($SCRIPT_NAME eq 'convert') {return;}
  
  my $error = &checkModuleDir($INPD);
  if ($error) {print $error . &usage(); exit 1};
  
  # Set Perl globals associated with the project configuration
  &set_project_globals();
  
  # Set Perl global variables defined in the [system] section of config.conf.
  &set_system_globals();
  &set_system_default_paths();
  
  &DebugListVars("BEFORE &init_opsys() WHERE\n$SCRIPT_NAME globals", 'SCRD', 
    'SCRIPT', 'SCRIPT_NAME', 'MOD', 'MAINMOD', 'MAININPD', 'DICTMOD', 
    'DICTINPD', our @OC_SYSTEM_PATH_CONFIGS, 'VAGRANT', 
    'NO_OUTPUT_DELETE');

  # Check that this is a provisioned Linux system (otherwise restart in 
  # Vagrant if possible, and exit when Vagrant is finished).
  &init_opsys();
  
  # From here on out we're always running on a provisioned Linux system
  # (either natively or on a VM).
  require "$SCRD/lib/common/common.pm";
  
  if ($OSIS2OSIS_PASS eq 'preinit') {return;}
  
  &init_linux_script();
  
  &DebugListVars("AFTER &init_linux_script() WHERE\n$SCRIPT_NAME globals", 
    'OUTDIR', 'MOD_OUTDIR', 'TMPDIR', 'LOGFILE');
}

# Check that $dir is an osis-converters module directory, returning an 
# error message if there is a problem, undef otherwise.
sub checkModuleDir {
  my $inpd = shift;
  
  if (!-d $inpd) {
    return "\nABORT: Not a directory: '$inpd'\n";
  }
  elsif (!-d "$inpd/sfm" && !-d "$inpd/../sfm" && 
         !-e "$inpd/CF_osis2osis.txt" && !-e "$inpd/../CF_osis2osis.txt") {
    return "\nABORT: Not an osis-converters project: '$inpd'\n";
  }
}

sub scriptName {
  
  my $n = $0;
  $n =~ s/^\.+//;
  $n =~ s/^.*[\/\\]([^\/\\]+)$/$1/;
  $n =~ s/(\.[^\/\.]+)$//;
  
  return $n;
}

1;
