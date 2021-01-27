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

# All code here is expected to be run on a Linux Ubuntu 14 to 18 or 
# compatible operating system having all osis-converters dependencies 
# already installed.

use strict;
use Encode;
use File::Spec;
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Find;
use Cwd;
use DateTime;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

# Initialized in entry script
our ($SCRIPT, $SCRD);

# Initialized in /scripts/bootstrap.pl 
our (@SUB_PUBLICATIONS, $LOGFILE, $SCRIPT_NAME, $CONFFILE, $CONF, $MOD, 
    $INPD, $MAINMOD, $DICTMOD, $MAININPD, $DICTINPD, $READLAYER, 
    $WRITELAYER, $APPENDLAYER);
     
# Initialized in /scripts/common_opsys.pl
our ($CONF, $OSISBOOKSRE, %OSIS_ABBR, %OSIS_GROUP, @OSIS_GROUPS, @SWORD_OC_CONFIGS,
    %CONFIG_DEFAULTS, @MULTIVALUE_CONFIGS, @CONTINUABLE_CONFIGS, 
    @OC_LOCALIZABLE_CONFIGS, @SWORD_LOCALIZABLE_CONFIGS, @OC_SYSTEM_CONFIGS, 
    @OC_CONFIGS, @SWORD_AUTOGEN_CONFIGS, @SWORD_CONFIGS, $TEI_NAMESPACE, 
    $OSIS_NAMESPACE, @CONFIG_SECTIONS, $SWORD_VERSE_SYSTEMS);
    
# Config.conf [system] globals initialized in set_system_globals 
# (see @OC_SYSTEM_CONFIGS in common_opsys.pl).
our ($REPOSITORY, $MODULETOOLS_BIN, $GO_BIBLE_CREATOR, $SWORD_BIN, 
    $OUTDIR, $FONTS, $COVERS, $EBOOKS, $DEBUG, $NO_OUTPUT_DELETE, 
    $VAGRANT);
    
# Initialized within common.pl functions
our (%BOOKNAMES, $DEFAULT_DICTIONARY_WORDS, $INOSIS, $OUTOSIS, $OUTZIP, 
    $SWOUT, $GBOUT, $EBOUT, $HTMLOUT, $MOD_OUTDIR, $TMPDIR, $XML_PARSER,
    $XPC, %DOCUMENT_CACHE);

our $KEYWORD = "osis:seg[\@type='keyword']"; # XPath expression matching dictionary entries in OSIS source
our $OSISSCHEMA = "http://localhost/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd"; # Original is at www.crosswire.org, but it's copied locally for speedup/networkless functionality
our $INDENT = "<milestone type=\"x-p-indent\" />";
our $LB = "<lb />";
our $FNREFSTART = "<reference type=\"x-note\" osisRef=\"TARGET\">";
our $FNREFEND = "</reference>";
our $FNREFEXT = "note.n";
our $MAX_UNICODE = 1103; # Default value: highest Russian Cyrillic Uncode code point
our @Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
our @USFM2OSIS_PY_SPECIAL_BOOKS = ('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other');
our $DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb]";
our $DICTIONARY_WORDS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
our $UPPERCASE_DICTIONARY_KEYS = 1;
our $SFM2ALL_SEPARATE_LOGS = 1;

# The attribute types and values below are hardwired into the xsl files
# to allow them to be more portable. But in Perl, these variables are used.
our %RESP;
$RESP{'oc'} = 'x-oc';     # @resp='x-oc' means osis-converters is responsible for adding the element
$RESP{'vsys'} = 'x-vsys'; # means fitToVerseSystem is responsible for adding this element
$RESP{'copy'} = 'x-copy'; # means this element is a copy of another element

our $ROC = $RESP{'oc'}; # a convenience variable name

# Verse System related attribute types
our %VSYS;
$VSYS{'prefix_vs'}     = 'x-vsys';
$VSYS{'missing_vs'}    = $VSYS{'prefix_vs'}.'-missing';
$VSYS{'movedto_vs'}    = $VSYS{'prefix_vs'}.'-movedto';
$VSYS{'extra_vs'}      = $VSYS{'prefix_vs'}.'-extra';
$VSYS{'fitted_vs'}     = $VSYS{'prefix_vs'}.'-fitted';
$VSYS{'start_vs'}      = '-start';
$VSYS{'end_vs'}        = '-end';
$VSYS{'fixed_altvs'}   = 'x-alternate-'.&conf('Versification');
$VSYS{'moved_type'}    = $VSYS{'prefix_vs'}.'-moved';

# annotateType attribute values
our %ANNOTATE_TYPE;
$ANNOTATE_TYPE{'Source'} = $VSYS{'prefix_vs'}.'-source'; # annotateRef is osisRef to source (custom) verse system
$ANNOTATE_TYPE{'Universal'} = $VSYS{'prefix_vs'}.'-universal'; # annotateRef is osisRef to an external (fixed) verse system
$ANNOTATE_TYPE{'conversion'} = 'x-conversion'; # annotateRef listing conversions where an element should be output
$ANNOTATE_TYPE{'not_conversion'} = 'x-notConversion'; # annotateRef listing conversions where an element should not be output
$ANNOTATE_TYPE{'cover'} = 'x-coverInsertion'; # annotateRef gives cover insertion info
$ANNOTATE_TYPE{'Feature'} = 'x-feature'; # annotateRef listing special features to which an element applies

require("$SCRD/scripts/bible/getScope.pl");
require("$SCRD/scripts/bible/fitToVerseSystem.pl");
our (%ID_TYPE_MAP, %ID_TYPE_MAP_R, %PERIPH_TYPE_MAP, %PERIPH_TYPE_MAP_R, 
     %PERIPH_SUBTYPE_MAP, %PERIPH_SUBTYPE_MAP_R, 
     %USFM_DEFAULT_PERIPH_TARGET);
require("$SCRD/scripts/functions/childrensBible.pl");
require("$SCRD/scripts/functions/context.pl");
require("$SCRD/scripts/functions/image.pl");
require("$SCRD/scripts/functions/osisID.pl");
require("$SCRD/scripts/functions/dictionaryWords.pl");
require("$SCRD/scripts/blockFile.pl");

sub init_linux_script {
  # Global $forkScriptName will only be set when running from fork.pl, in  
  # which case SCRIPT_NAME is inherited for &conf() values to be correct.
  if (our $forkScriptName) {$SCRIPT_NAME = $forkScriptName;}
  
  &Log("\n-----------------------------------------------------\nSTARTING \$SCRIPT_NAME=$SCRIPT_NAME\n\n");
  
  # osis2ebook is usually called multiple times by osis2ebooks so don't repeat these
  if ($SCRIPT_NAME !~ /^osis2ebook$/) {
    &logGitRevs();
    &timer('start');
  }
  
  &initLibXML();
  
  %BOOKNAMES; &readBookNamesXML(\%BOOKNAMES);
  
  # If appropriate, do either runCF_osis2osis(preinit) OR 
  # checkAndWriteDefaults(), but never both, since osis2osis also 
  # creates input control files.
  if (-e "$INPD/CF_osis2osis.txt" && $SCRIPT =~ /(?<!osis2osis)\/(osis2osis|sfm2all)\.pl$/) {
    require("$SCRD/scripts/osis2osis/functions.pl");
    &runCF_osis2osis('preinit');
    our $MOD_OUTDIR = &getModuleOutputDir();
    if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
    
    $TMPDIR = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";

    $LOGFILE = &initLogFile($LOGFILE, "$MOD_OUTDIR/OUT_".$SCRIPT_NAME."_$MOD.txt");
    return 1;
  }
  elsif ($SCRIPT_NAME =~ /update/) {
    &checkAndWriteDefaults(\%BOOKNAMES); # do this after readBookNamesXML() so %BOOKNAMES is set
    
    # update old convert.txt configuration
    if ($INPD eq $MAININPD && (-e "$INPD/eBook/convert.txt" || -e "$INPD/html/convert.txt")) {
      &update_removeConvertTXT($CONFFILE);
    }

    # update old /DICT/config.conf configuration
    if ($DICTMOD && -e "$DICTINPD/config.conf") {
      &update_removeDictConfig("$DICTINPD/config.conf", $CONFFILE);
    }
    
    &readSetCONF();
    # $DICTMOD will be empty if there is no dictionary module for the project, but $DICTINPD always has a value
    {
     my $cn = "${MAINMOD}DICT"; $DICTMOD = ($INPD eq $DICTINPD || &conf('Companion', $MAINMOD) =~ /\b$cn\b/ ? $cn:'');
    }
  }
  
  if (!-e $CONFFILE) {
    &Error("There is no config.conf file: \"$CONFFILE\".", 
    "\"$INPD\" may not be an osis-converters project directory. If it is, then run update.pl to create a config.conf file.\n", 1);
  }
  
  $MOD_OUTDIR = &getModuleOutputDir();
  if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
  
  $TMPDIR = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";
  if (our $forkScriptName) { # will be set when called by forks.pl
    if (!defined($LOGFILE)) {&ErrorBug("Fork log file must be specified, and numbered.", 1);}
    $TMPDIR = $LOGFILE; $TMPDIR =~ s/\/[^\/]+$//;
  }
  if (!$NO_OUTPUT_DELETE) {
    if (-e $TMPDIR) {remove_tree($TMPDIR);}
    make_path($TMPDIR);
  }
  
  &initInputOutputFiles($SCRIPT_NAME, $INPD, $MOD_OUTDIR, $TMPDIR);
  
  $LOGFILE = &initLogFile($LOGFILE, "$MOD_OUTDIR/OUT_".$SCRIPT_NAME."_$MOD.txt");
  
  $DEFAULT_DICTIONARY_WORDS = "$MOD_OUTDIR/DictionaryWords_autogen.xml";
  
  if ($SCRIPT_NAME =~ /^update$/) {return;}
  
  &checkConfGlobals();
    
  &checkProjectConfiguration();
    
  &checkRequiredConfEntries();
  
  if (&conf('Font')) {&checkFont(&conf('Font'));}
  
  if (-e "$INPD/images") {&checkImageFileNames("$INPD/images");}
  
  if ($DEBUG) {
    &Error("DEBUG is set in config.conf.", 
"For publication of output files, DEBUG needs to be commented out or 
set to 0 in config.conf. DEBUG may only be specified during development
and debugging.");
  }
}

sub logGitRevs {

  chdir($MAININPD);
  my $inpdGit = &shell("git rev-parse HEAD 2>/dev/null", 3, 1); chomp($inpdGit);
  my $inpdOriginGit = ($inpdGit ? &shell("git config --get remote.origin.url", 3, 1):''); chomp($inpdOriginGit);
  
  chdir($SCRD);
  my $scrdGit = &shell("git rev-parse HEAD 2>/dev/null", 3, 1); chomp($scrdGit);
  
  my $modtoolsGit = &shell("cd \"$MODULETOOLS_BIN\" && git rev-parse HEAD 2>/dev/null", 3, 1); chomp($modtoolsGit);
  
  &Log("osis-converters git rev: $scrdGit\n");
  &Log("Module-tools git rev: $modtoolsGit at $MODULETOOLS_BIN\n");
  if ($inpdGit) {
    &Log("$inpdOriginGit rev: $inpdGit\n");
  }
}

# This is only needed to update old osis-converters projects
sub update_removeConvertTXT {
  my $confFile = shift;
  
  &Warn("UPDATE: Found outdated convert.txt. Updating $confFile...");
  my $confP = &readConfFile($confFile);
  if (!$confP) {
    &Error("Could not read config.conf file: $confFile");
    return;
  }
  
  &updateConvertTXT("$MAININPD/eBook/convert.txt", $confP, 'osis2ebooks');
  &updateConvertTXT("$MAININPD/html/convert.txt", $confP, 'osis2html');
  return &writeConf($confFile, $confP);
}

# This is only needed to update old osis-converters projects
sub updateConvertTXT {
  my $convtxt = shift;
  my $confP = shift;
  my $section = shift;
  
  if (! -e $convtxt) {return '';}
  
  my %pubScopeTitle;
  if (open(CONV, $READLAYER, $convtxt)) {
    while(<CONV>) {
      my $s = $section;
      if ($_ =~ /^#/) {next;}
      elsif ($_ =~ /^([^=]+?)\s*=\s*(.*?)\s*$/) {
        my $e = $1; my $v = $2;
        my $warn;
        if ($e eq 'MultipleGlossaries') {
          $warn = "Changing $e=$v to";
          $s = '';
          $e = 'CombineGlossaries';
          $v = ($v && $v !~ /^(false|0)$/i ? 'false':'true');
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^CreateFullPublication(\d+)/) {
          my $n = $1;
          my $sp = $v; $sp =~ s/\s/_/g;
          $pubScopeTitle{$n}{'sp'} = $sp;
          $e = '';
        }
        elsif ($e =~ /^TitleFullPublication(\d+)/) {
          my $n = $1;
          $pubScopeTitle{$n}{'title'} = $v;
          $e = '';
        }
        elsif ($e =~ /^Group1\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $s = '';
          $e = 'BookGroupTitleOT';
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Group2\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $s = '';
          $e = 'BookGroupTitleNT';
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Title\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $s = '';
          $e = 'TranslationTitle';
          &Warn("<-$warn $e=$v");
        }
        if ($e) {
          $confP->{($s ? "$s+":'').$e} = $v;
        }
      }
    }
    close(CONV);
    foreach my $n (sort keys %pubScopeTitle) {
      my $e = ($section ? "$section+":'').'TitleSubPublication['.$pubScopeTitle{$n}{'sp'}.']';
      my $v = $pubScopeTitle{$n}{'title'};
      $confP->{$e} = $v;
      &Warn("<-Changing CreateFullPublication and TitleFullPublication to $e=$v");
    }
  }
  else {&Warn("Did not find \"$convtxt\"");}
  
  &Warn("<-UPDATE: Removing outdated convert.txt: $convtxt");
  &Note("The file: $convtxt which was used for 
various settings has now been replaced by a section in the config.conf 
file. The convert.txt file will be deleted. Your config.conf will have 
a new section with that information.");
  unlink($convtxt);
}

# This is only needed to update old osis-converters projects
sub update_removeDictConfig {
  my $dconf = shift;
  my $confFile = shift;

  &Warn("UPDATE: Found outdated DICT config.conf. Updating...");
  my $mainConfP = &readConfFile($confFile);
  my $dictConfP = &readConfFile($dconf);
  &Warn("<-UPDATE: Removing outdated DICT config.conf: $dconf");
  unlink($dconf);
  &Note("The file: $dconf which was used for 
DICT settings has now been replaced by a section in the config.conf 
file. The DICT config.conf file will be deleted. Your config.conf will 
have new section with that information.");
  foreach my $de (sort keys %{$dictConfP}) {
    if ($de =~ /(^MainmodName|DictmodName)$/) {next;}
    my $de2 = $de; $de2 =~ s/^$MAINMOD\+//;
    if ($mainConfP->{$de} eq $dictConfP->{$de} || $mainConfP->{"$MAINMOD+$de2"} eq $dictConfP->{$de}) {next;}
    $mainConfP->{$de} = $dictConfP->{$de};
  }

  return &writeConf($confFile, $mainConfP);
}

# If $logfileIn is not specified then start a new one at $logfileDef.
# If $logfileIn is specified then append to $logfileIn.
sub initLogFile {
  my $logfileIn = shift;
  my $logfileDef = shift;
  
  my $logfile = ($logfileIn ? $logfileIn:$logfileDef);
  
  # delete old log if $logfileIn was not specified
  if (!$logfileIn && -e $logfile) {unlink($logfile);}
  
  # create parent directory if it doesn't exist yet
  my $logfileParent = $logfile; $logfileParent =~ s/\/[^\/]+\/?$//;
  if (!-e $logfileParent) {&make_path($logfileParent);}
  
  return $logfile;
}

# Enforce the only supported module configuration and naming convention
sub checkProjectConfiguration {

  if (uc($MAINMOD) ne $MAINMOD) {
    print 
  "ERROR: Module name $MAINMOD should be all capitals. Change the 
  directory name to ".uc($MAINMOD)."  and change the name in config.conf 
  (if config.conf exists). Then try again.
  Exiting...";
    exit;
  }
  if (&conf('ModDrv') =~ /LD/) {
    my $main = $INPD;
    if ($main !~ s/^.*?\/([^\/]+)\/$MOD$/$1/) {
      &Error("Unsupported project configuration.", "The top project directory must be a Bible project.", 1);
    }
    if ($MOD ne $main.'DICT') {
      &Error("The name for this project's sub-directory $INPD must be '$main"."DICT'.", 
"Change the name of this sub-directory and edit config.conf to change  
the module name between [] at the top, as well as the Companion entry.", 1);
    }
  }
  elsif (&conf('ModDrv') =~ /GenBook/) {
    if ($MOD !~ /CB$/) {
      &Error("The only GenBook type modules currently supported are
Children's Bibles, and their module names should be uppercase language
code followed by 'CB'.", 1);
    }
  }
  elsif (&conf('Companion') && &conf('Companion') ne $MOD.'DICT') {
    &Error("There can only be one companion module, and it must be named '".$MOD."DICT.", 
"All reference materials for this project will be written to a single 
OSIS file and SWORD module. This OSIS/SWORD file may contain multiple 
glossaries, dictionaries, maps, tables, etc. etc.. But its name must be 
'$MOD"."DICT'.", 1);
  }
}

sub readBookNamesXML {
  my $booknamesHP = shift;
  
  my $main = $INPD; if ($main =~ /DICT$/) {$main .= "/..";}
  # Read BookNames.xml, if found, which can be used for localizing Bible book names
  foreach my $bknxml (split(/\n+/, &shell("find '$main/sfm' -name 'BookNames.xml' -print", 3))) {
    if (! -e "$bknxml") {next;}
    my $bknames = $XML_PARSER->parse_file("$bknxml");
    my @bkelems = $XPC->findnodes('//book[@code]', $bknames);
    if (@bkelems[0]) {
      &Note("Reading localized book names from \"$bknxml\"");
    }
    foreach my $bkelem (@bkelems) {
      my $bk = &bookOsisAbbr($bkelem->getAttribute('code'));
      if (!$bk) {next;}
      my @ts = ('abbr', 'short', 'long');
      foreach my $t (@ts) {
        if (!$bkelem->hasAttribute($t) || $bkelem->getAttribute($t) =~ /^\s*$/) {next;}
        if ($booknamesHP->{$bk}{$t} && $booknamesHP->{$bk}{$t} ne $bkelem->getAttribute($t)) {
          my $new = $bkelem->getAttribute($t);
          if (
            ($t eq 'short' && length($new) > length($booknamesHP->{$bk}{$t})) || 
            ($t eq 'long' && length($new) < length($booknamesHP->{$bk}{$t}))
          ) {
            $new = $booknamesHP->{$bk}{$t};
            &Warn("Multiple $t definitions for $bk. Keeping '$new' rather than '".$bkelem->getAttribute($t)."'.", "That the resulting value is correct, and possibly fix the incorrect one.");
          }
          else {
            &Warn("Multiple $t definitions for $bk. Using '$new' rather than '".$booknamesHP->{$bk}{$t}."'.", "That the resulting value is correct, and possibly fix the incorrect one.");
          }
        }
        $booknamesHP->{$bk}{$t} = $bkelem->getAttribute($t);
      }
    }
  }
}

my $STARTTIME;
sub timer {
  my $do = shift;
 
  if ($do =~ /start/i) {
    &Log("start time: ".localtime()."\n");
    $STARTTIME = DateTime->now();
  }
  elsif ($do =~ /stop/i) {
    &Log("\nend time: ".localtime()."\n");
    if ($STARTTIME) {
      my $now = DateTime->now();
      my $e = $now->subtract_datetime($STARTTIME);
      &Log("elapsed time: ".
        ($e->hours ? $e->hours." hours ":'').
        ($e->minutes ? $e->minutes." minutes ":'').
        $e->seconds." seconds\n", 1);
    }
    $STARTTIME = '';
  }
  else {&Log("\ncurrent time: ".localtime()."\n");}
}

our %FONT_FILES;
sub checkFont {
  my $font = shift;
  
  # After this routine is run, font features can use "if ($FONT)" to check
  # font support and then use $FONTS/$FONT_FILES if font files are needed.
  
  # FONTS can be a URL in which case update the local font cache
  if ($FONTS =~ /^https?\:/) {$FONTS = &getURLCache('fonts', $FONTS, 1, 12);}

  if ($FONTS && ! -e $FONTS) {
    &Error("config.conf specifies FONTS as \"$FONTS\" but this path does ".
    "not exist. FONTS will be unset.", 
    "Change the value of FONTS in the [system] section of config.conf to ".
    "point to an existing path or URL.");
    $FONTS = '';
  }

  if ($FONTS) {
    # The Font value is a font internal name, which may have multiple font 
    # files associated with it. Font files should be named according to 
    # the excpectations below.
    opendir(DIR, $FONTS);
    my @fonts = readdir(DIR);
    closedir(DIR);
    my %styles = (
      'R'  => 'regular', 
      'B'  => 'bold', 
      'I'  => 'italic', 
      'BI' => 'bold italic', 
      'IB' => 'bold italic'
    );
    foreach my $s (sort keys %styles) {
      if ($font =~ /\-$s$/i) {
        &Error("The Font config.conf entry should not specify the font style.", 
        "Remove '-$s' from FONT=$font in config.conf");
      }
    }
    foreach my $f (@fonts) {
      if ($f =~ /^\./) {next;}
      if ($f =~ /^(.*?)(\-([ribRIB]{1,2}))?\.([^\.]+)$/) {
        my $n = $1; my $t = ($2 ? $3:'R'); my $ext = $4;
        if ($2 && uc($3) eq 'R') {
          &Error("Regular font $f should not have the $2 extension.", 
          "Change the name of the font file from $f to $n.$ext");
        }
        if ($n eq $font) {
          $FONT_FILES{$font}{$f}{'style'} = $styles{uc($t)};
          $FONT_FILES{$font}{$f}{'ext'} = $ext;
          $FONT_FILES{$font}{$f}{'fullname'} = &shell('fc-scan --format "%{fullname}" "'."$FONTS/$f".'"', 3);
        }
      }
      else {&Warn("\nFont \"$f\" file name could not be parsed. Ignoring...\n");}
    }
    if (scalar(%FONT_FILES)) {
      foreach my $f (sort keys(%{$FONT_FILES{$font}})) {
        &Note("Using font file \"$f\" as ".$FONT_FILES{$font}{$f}{'style'}." font for \"$font\".");
      }
    }
    else {
      &Error("No font file(s) for \"$font\" were found at \"$FONTS\"", 
      "Add the required font to this directory, or change FONTS in the ".
      "[system] section of config.conf to the correct path or URL.");
    }
  }
  else {
    &Warn("\nThe config.conf specifies font \"$font\", but no FONTS directory ".
    "has been specified in the [system] section of config.conf. Therefore, ".
    "this setting will be ignored!\n");
  }
  
  &Debug("\n\$FONTS=$FONTS\n\%FONT_FILES=".Dumper(\%FONT_FILES)."\n");
}

# Return 1 if there is an Internet connection or 0 of there is not. This
# test may take time, so cache the result for the remainder of the script.
our $HAVEINTERNET;
sub haveInternet {

  if (!defined($HAVEINTERNET)) {
    my $r = &shell('bash -c "echo -n > /dev/tcp/8.8.8.8/53"', 3, 1);
    $HAVEINTERNET = ($r =~ /no route to host/i ? 0:1);
  }
  
  return $HAVEINTERNET;
}

# Caches files from a URL, or if the $listingAP array pointer is 
# provided, a listing of files at the URL (without actually downloading 
# the files). The path to the local cache is returned. If $listingAP 
# pointer is provided, it will be set to the array of file paths. The 
# $depth value is the directory recursion level. If the cache was last 
# updated more than $updatePeriod hours ago, the cache will first be 
# updated. Directories in the $listingAP listing end with '/'. For 
# $listingAP to work, the URL must target an Apache server directory 
# where html listing is enabled.
sub getURLCache {
  my $name = shift;  # local .osis-converters subdirectory to update
  my $url = shift;   # URL to read from
  my $depth = shift; # max subdirectory depth of URL cache
  my $updatePeriod = shift; # hours between updates (0 updates always)
  my $listingAP = shift; # Do not download any files, just write a file listing here.
  
  if (!$name) {&ErrorBug("Subdir cannot be empty.", 1);}
  
  my $pp = "~/.osis-converters/URLCache/$name";
  my $p = &expandLinuxPath($pp);
  if (! -e $p) {make_path($p);}
  my $pdir = $url; $pdir =~ s/^.*?([^\/]+)\/?$/$1/; # URL directory name
  
  # This function may take significant time to complete, and other  
  # threads may try to access the cache before it is ready. So BlockFile  
  # is used to limit the cache to one thread at a time.
  my $blockFile = BlockFile->new("$p/../$name-blocked.txt");

  # Check last time this subdirectory was updated
  if ($updatePeriod && -e "$p/../$name-updated.txt") {
    my $lastTime;
    if (open(TXT, $READLAYER, "$p/../$name-updated.txt")) {
      while(<TXT>) {if ($_ =~ /^epoch=(.*?)$/) {$lastTime = $1;}}
      close(TXT);
    }
    if ($lastTime) {
      my $now = DateTime->now()->epoch();
      my $delta = sprintf("%.2f", ($now-$lastTime)/3600);
      if ($delta < $updatePeriod) {
        if ($listingAP) {&wgetReadFilePaths($p, $listingAP, $p);}
        &Note("Using local cache directory $pp");
        return $p;
      }
    }
  }
  
  if (!&haveInternet()) {
    if ($listingAP) {&wgetReadFilePaths($p, $listingAP, $p);}
    &Note("Using local cache directory $pp");
    &Error(
"No Internet connection, and cached files are invalid.", 
"Connected to the Internet and then rerun the conversion.");
    return $p;
  }
  
  # Refresh the subdirectory contents from the URL.
  &Log("\n\nPlease wait while I update $pp...\n", 2);
  my $success = 0;
  if ($p && $url) {
    if (!-e $p) {mkdir($p);}
    use Net::Ping;
    my $net = Net::Ping->new;
    my $d = $url; $d =~ s/^https?\:\/\/([^\/]+).*?$/$1/;
    my $r; use Try::Tiny; try {$r = $net->ping($d, 5);} catch {$r = 0;};
    if ($r) {
      # Download files
      if (!$listingAP) {
        $url =~ s/\/$//; # downloads should never end with /
        shell("cd '$p' && wget -r --level=$depth -np -nd --quiet -erobots=off -N -A '*.*' -R '*.html*' '$url'", 3);
        $success = &wgetSyncDel($p);
      }
      # Otherwise return a listing
      else {
        $url =~ s/(?<!\/)$/\//; # listing URLs should always end in /
        my $cdir = $url; $cdir =~ s/^https?\:\/\/[^\/]+\/(.*?)\/$/$1/; my @cd = split(/\//, $cdir); $cdir = @cd-1; # url path depth
        if ($p !~ /\/\.osis-converters\//) {die;} remove_tree($p); make_path($p);
        &shell("cd '$p' && wget -r --level=$depth -np -nH --quiet -erobots=off --restrict-file-names=nocontrol --cut-dirs=$cdir --accept index.html -X $pdir $url", 3);
        $success = &wgetReadFilePaths($p, $listingAP, $p);
      }
    }
  }
  
  if ($success) {
    &Note("Updated local cache directory $pp from URL $url");
    
    # Save time of this update
    if (open(TXT, $WRITELAYER, "$p/../$name-updated.txt")) {
      print TXT "localtime()=".localtime()."\n";
      print TXT "epoch=".DateTime->now()->epoch()."\n";
      close(TXT);
    }
  }
  else {
    &Error("Failed to update $pp from $url.", "That there is an Internet connection and that $url is a valid URL.");
  }
  
  return $p;
}

# Delete any local files that were not just downloaded by wget
sub wgetSyncDel {
  my $p = shift;
  
  my $success = 0;
  $p =~ s/\/\s*$//;
  if ($p !~ /\/\Q.osis-converters\E\//) {return 0;} # careful with deletes
  my $dname = $p; $dname =~ s/^.*\///;
  my $html = $XML_PARSER->load_html(location  => "$p/$dname.tmp", recover => 1);
  if ($html) {
    $success++;
    my @files = $html->findnodes('//tr//a');
    my @files = map($_->textContent() , @files);
    opendir(PD, $p) or &ErrorBug("Could not open dir $p", 1);
    my @locfiles = readdir(PD); closedir(PD);
    foreach my $lf (@locfiles) {
      if (-d "$p/$lf") {next;}
      my $del = 1; foreach my $f (@files) {if ($f eq $lf) {$del = 0;}}
      if ($del) {unlink("$p/$lf");}
    }
  }
  else {&ErrorBug("The $dname.tmp HTML was undreadable: $p/$dname.tmp");}
  shell("cd '$p' && rm -f *.tmp", 3);
  
  return $success;
}

# Recursively read $wgetdir directory that contains the wget result 
# of reading an apache server directory, and add paths of listed files 
# and directories to the $filesAP array pointer. All directories will
# end with a '/'.
sub wgetReadFilePaths {
  my $wgetdir = shift; # directory containing the wget result of reading an apache server directory
  my $filesAP = shift; # the listing of subdirectories on the server
  my $root = shift; # root of recursive search
  
  if (!opendir(DIR, $wgetdir)) {
    &ErrorBug("Could not open $wgetdir");
    return 0;
  }
  
  my $success = 1;
  my @subs = readdir(DIR);
  closedir(DIR);
  
  foreach my $sub (@subs) {
    $sub = decode_utf8($sub);
    if ($sub =~ /^\./ || $sub =~ /(robots\.txt\.tmp)/) {next;}
    elsif (-d "$wgetdir/$sub") {
      my $save = "$wgetdir/$sub/"; $save =~ s/^\Q$root\E\/[^\/]+/./;
      push(@{$filesAP}, $save);
      #&Debug("Found folder: $save\n", 1);
      $success &= &wgetReadFilePaths("$wgetdir/$sub", $filesAP, $root);
      next;
    }
    elsif ($sub ne 'index.html') {
      &ErrorBug("Encountered unexpected file $sub in $wgetdir.");
      $success = 0;
      next;
    }
    my $html = $XML_PARSER->load_html(location  => "$wgetdir/$sub", recover => 1);
    if (!$html) {&ErrorBug("Could not parse $wgetdir/$sub"); $success = 0; next;}
    foreach my $a ($html->findnodes('//tr/td/a')) {
      my $icon = @{$a->findnodes('preceding::img[1]/@src')}[0];
      if ($icon->value =~ /\/(folder|back)\.gif$/) {next;}
      my $save = "$wgetdir/".decode_utf8($a->textContent()); $save =~ s/^\Q$root\E\/[^\/]+/./;
      if ($save ne ".") {
        push(@{$filesAP}, $save);
        #&Debug("Found file: $save\n", 1);
      }
    }
  }
  
  return $success;
}

sub initInputOutputFiles {
  my $script_name = shift;
  my $inpd = shift;
  my $modOutdir = shift;
  my $tmpdir = shift;
  
  my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
  
  my @outs;
  if ($script_name =~ /^(osis2osis.*|sfm2osis)$/) {
    $OUTOSIS = "$modOutdir/$sub.xml"; push(@outs, $OUTOSIS);
  }
  if ($script_name =~ /^(osis2sword)$/) {
    $OUTZIP = "$modOutdir/$sub.zip"; push(@outs, $OUTZIP);
    $SWOUT = "$modOutdir/sword"; push(@outs, $SWOUT);
  }
  if ($script_name =~ /^osis2GoBible$/) {
    $GBOUT = "$modOutdir/GoBible/$sub"; push(@outs, $GBOUT);
  }
  if ($script_name =~ /^osis2ebooks$/) {
    $EBOUT = "$modOutdir/eBook"; push(@outs, $EBOUT);
  }
  if ($script_name =~ /^osis2html$/) {
    $HTMLOUT = "$modOutdir/html"; push(@outs, $HTMLOUT);
  }

  if ($script_name =~ /^(osis2sword|osis2GoBible|osis2ebooks|osis2html)$/) {
    if (-e "$modOutdir/$sub.xml") {
      &copy("$modOutdir/$sub.xml", "$tmpdir/$sub.xml");
      $INOSIS = "$tmpdir/$sub.xml";
    }
    else {
      &ErrorBug("$script_name.pl cannot find an input OSIS file at \"$modOutdir/$sub.xml\".", 1);
    }
  }

  our $forkScriptName; # fork results should not be deleted
  if (!$NO_OUTPUT_DELETE && !$forkScriptName) {
    foreach my $outfile (@outs) {
      my $isDir = ($outfile =~ /\.[^\\\/\.]+$/ ? 0:1);
      if (-e $outfile) {
        if (!$isDir) {unlink($outfile);}
        else {remove_tree($outfile);}
      }
      if ($isDir) {make_path($outfile);}
    }
  }
  
  # init SFM files if needed
  if ($script_name =~ /^update$/ && -e "$inpd/sfm") {
    # check for BOM in SFM and clear it if it's there, also normalize line endings to Unix
    &shell("find \"$inpd/sfm\" -type f -exec sed '1s/^\xEF\xBB\xBF//' -i.bak {} \\; -exec rm {}.bak \\;", 3);
    &shell("find \"$inpd/sfm\" -type f -exec dos2unix {} \\;", 3);
  }
}


sub initLibXML {

  use Sword;
  use HTML::Entities;
  use XML::LibXML;
  $XPC = XML::LibXML::XPathContext->new;
  $XPC->registerNs('osis', $OSIS_NAMESPACE);
  $XPC->registerNs('tei', $TEI_NAMESPACE);
  $XPC->registerNs('dw', $DICTIONARY_WORDS_NAMESPACE);
  $XML_PARSER = XML::LibXML->new();
}


# If any 'projectDefaults' files are missing from the entire project 
# (including the DICT sub-project if there is one), those default files 
# will be copied to the proper directory using getDefaultFile(). If a 
# copied file is a 'customDefaults' file, then it will also be 
# customized for the project. Note that not all control files are 
# included in the 'projectDefaults' list, such as those which rarely 
# change from project to project. This is because all default files are 
# read at runtime by getDefaultFile(). So these may be copied and 
# customized as needed, manually by the user.
my %USFM;
sub checkAndWriteDefaults {
  my $booknamesHP = shift;
  
  # Project default control files
  my @projectDefaults = (
    'template.conf', 
    'childrens_bible/config.conf',
    'bible/CF_usfm2osis.txt', 
    'bible/CF_addScripRefLinks.txt',
    'dict/CF_usfm2osis.txt', 
    'dict/CF_addScripRefLinks.txt',
    'childrens_bible/CF_usfm2osis.txt', 
    'childrens_bible/CF_addScripRefLinks.txt'
  );
  
  # These are default control files which are automatically customized 
  # to save the user's time and energy. These files are processed in 
  # order, and config.conf files must come first because the 
  # customization of the others depends on config.conf contents.
  my @customDefaults = (
    'config.conf', 
    'CF_usfm2osis.txt', 
    'CF_addScripRefLinks.txt',
  );
  
  # Always process the main project, regardless of which module we started with
  # Determine if there is any sub-project dictionary (the fastest way possible)
  my $haveDICT = ($MAININPD ne $INPD ? 1:0);
  if (!$haveDICT) {
    if ($CONFFILE && -e $CONFFILE) {
      if (my $comps = &conf('Companion', $MAINMOD)) {
        foreach my $c (split(/\s*,\s*/, $comps)) {
          if ($c =~ /DICT$/) {$haveDICT = 1;}
        }
      }
    }
    else {
      if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
      if (exists($USFM{'dictionary'})) {$haveDICT = 1;}
    }
  }
  
  # Copy projectDefaults files that are missing
  my $projName = $MAININPD; $projName =~ s/^.*\/([^\/]+)\/?$/$1/;
  my $projType = ($projName =~ /\w{3,}CB$/ ? 'childrens_bible':'bible');
  my @newDefaultFiles;
  foreach my $df (@projectDefaults) {
    my $df_isDirectory = ($df =~ s/\/\*$// ? 1:0); 
    my $dest = $df;
    $dest =~ s/template\.conf$/config.conf/;
    my $dftype = ($dest =~ s/^(bible|dict|childrens_bible)\/// ? $1:$projType);
    $dest = "$MAININPD/".($dftype eq 'dict' ? $projName.'DICT/':'').$dest;
    if ($dftype eq 'dict') {
      if (!$haveDICT) {next;}
    }
    elsif ($dftype ne $projType) {next;}
    
    my $dparent = $dest; $dparent =~ s/[^\/]+$//;
    if (!-e $dparent) {make_path($dparent);}
    
    if ($df_isDirectory && (! -e $dest || ! &shell("ls -A '$dest'", 3))) {
      &Note("Copying missing default directory $df to $dest.");
      &copy_dir_with_defaults($df, $dest);
      push(@newDefaultFiles, split(/\n+/, &shell("find '$dest' -type f -print", 3)));
    }
    # If the user has added CF_osis2osis.txt then never add a default CF_usfm2osis.txt file
    elsif ($df =~ /CF_usfm2osis\.txt$/ && -e ($dftype eq 'dict' ? $DICTINPD:$MAININPD)."/CF_osis2osis.txt") {
      next;
    }
    elsif (! -e $dest) {
      &Note("Copying missing default file $df to $dest.");
      my $src = &getDefaultFile($df, -1);
      if (-e $src) {copy($src, $dest);}
      push(@newDefaultFiles, $dest);
    }
  }
  
  # Customize any new default files which need it (in order)
  foreach my $dc (@customDefaults) {
    foreach my $file (@newDefaultFiles) {
      if ($file =~ /\/\Q$dc\E$/) {
        my $modName = ($file =~ /\/$projName\/($projName)DICT\// ? $projName.'DICT':$projName);
        my $modType = ($modName eq $projName ? $projType:'dictionary');
        
        &Note("Customizing $file...");
        if    ($file =~ /config\.conf$/)             {&customize_conf($modName, $modType, $haveDICT);}
        elsif ($file =~ /CF_usfm2osis\.txt$/)        {&customize_usfm2osis($file, $modType);}
        elsif ($file =~ /CF_addScripRefLinks\.txt$/) {&customize_addScripRefLinks($file, $booknamesHP);}
        else {&ErrorBug("Unknown customization type $dc for $file; write a customization function for this type of file.", 1);}
      }
    }
  }
}

sub customize_conf {
  my $modName = shift;
  my $modType = shift;
  my $haveDICT = shift;

  if ($modType eq 'dictionary') {
    &ErrorBug("The 'dictionary' modType does not have its own config.conf file, but customize_conf was called with modType='dictionary'.", 1);
  }
 
  # Save any comments at the end of the default config.conf so they can 
  # be added back after writing the new conf file.
  my $comments = '';
  if (open(MCF, $READLAYER, $CONFFILE)) {
    while(<MCF>) {
      if ($comments) {$comments .= $_;}
      elsif ($_ =~ /^\Q#COMMENTS-ONLY-MUST-FOLLOW-NEXT-LINE/) {$comments = "\n";}
    }
    close(MCF);
  }
  $comments =~ s/^#(\[\w+\])/$1/mg;
 
  # If there is any existing $modName conf that is located in a repository 
  # then replace our default config.conf with a stripped-down version of 
  # the repo version and its dict.
  my $defConfP = &readConf();
  
  my $haveRepoConf;
  if ($defConfP->{'system+REPOSITORY'} && $defConfP->{'system+REPOSITORY'} =~ /^http/) {
    my $swautogen = &configRE(@SWORD_AUTOGEN_CONFIGS);
    $swautogen =~ s/\$$//;
    
    my $mfile = $defConfP->{'system+REPOSITORY'}.'/'.lc($modName).".conf";
    my $dfile = $defConfP->{'system+REPOSITORY'}.'/'.lc($modName)."dict.conf";
    
    my $mtext = &shell("wget \"$mfile\" -q -O -", 3);
    my $dtext = &shell("wget \"$dfile\" -q -O -");
    
    # strip @SWORD_AUTOGEN_CONFIGS entries
    $mtext =~ s/$swautogen\s*=[^\n]*\n//mg; 
    $dtext =~ s/$swautogen\s*=[^\n]*\n//mg;
    if ($mtext) {
      &Note("Default conf was located in REPOSITORY: $mfile", 1);
      &Log("$mtext\n\n");
      &Log("$dtext\n\n");
      if (open(CNF, $WRITELAYER, $CONFFILE)) {
        $haveRepoConf++;
        print CNF $mtext;
        close(CNF);
        my $confP = &readConfFile($CONFFILE);
        foreach my $k (keys %{$confP}) {
          $defConfP->{$k} = $confP->{$k};
        }
      }
      else {&ErrorBug("Could not open conf $CONFFILE");}
    }
    
    if ($dtext) {
      if (open(CNF, $WRITELAYER, "$CONFFILE.dict")) {
        print CNF $dtext;
        close(CNF);
        my $confP = &readConfFile("$CONFFILE.dict");
        foreach my $k (keys %{$confP}) {
          my $e = $k; $e =~ s/^[^\+]+\+//;
          # Don't keep these dict entries since MAIN/DICT are now always the same
          if ($e =~ /^(Version|History_.*)$/) {next;}
          if ($defConfP->{"$modName+$e"} eq $confP->{$k}) {next;}
          $defConfP->{$k} = $confP->{$k};
        }
        $defConfP->{'MainmodName'} = $modName;
        $defConfP->{'DictmodName'} = $modName.'DICT';
        unlink("$CONFFILE.dict");
      }
      else {&ErrorBug("Could not open conf $CONFFILE.dict");}
    }
  }
  
  if (!$haveRepoConf) {
    # Abbreviation
    &setConfValue($defConfP, "$modName+Abbreviation", $modName, 1);
    
    # ModDrv
    if ($modType eq 'childrens_bible') {&setConfValue($defConfP, "$modName+ModDrv", 'RawGenBook', 1);}
    if ($modType eq 'bible') {&setConfValue($defConfP, "$modName+ModDrv", 'zText', 1);}
    if ($modType eq 'other') {&setConfValue($defConfP, "$modName+ModDrv", 'RawGenBook', 1);}
  }

  # TitleSubPublication[scope]
  foreach my $scope (@SUB_PUBLICATIONS) {
    my $sp = $scope; $sp =~ s/\s/_/g;
    &setConfValue($defConfP, "$modName+TitleSubPublication[$sp]", "Title of Sub-Publication $sp DEF", 1);
  }
  
  # FullResourceURL
  my $v = $defConfP->{"$modName+FullResourceURL"};
  $v =~ s/\bNAME\b/$modName/g;
  if ($v) {&setConfValue($defConfP, "$modName+FullResourceURL", $v, 1);}
  
  # Companion + [DICTMOD] section
  if ($haveDICT) {
    my $companion = $modName.'DICT';
    &setConfValue($defConfP, "$modName+Companion", $companion, 1);
    &setConfValue($defConfP, "$companion+Companion", $modName, 1);
    &setConfValue($defConfP, "$companion+ModDrv", 'RawLD4', 1);
  }
  else {&setConfValue($defConfP, "$modName+Companion", '', 1);}
  
  &writeConf($CONFFILE, $defConfP);
  
  # Now append the following to the new config.conf:
  # - documentation comments
  # - comments from original config.conf
  my $defs = "# DEFAULT OSIS-CONVERTER CONFIG SETTINGS\n[$modName]\n";
  foreach my $c (@OC_CONFIGS) {
    if (!($CONFIG_DEFAULTS{"doc:$c"})) {next;}
    $defs .= "# $c ".$CONFIG_DEFAULTS{"doc:$c"}."\n#".$c.'='.$CONFIG_DEFAULTS{$c}."\n\n";
  }
  my $section;
  foreach my $k (sort keys %CONFIG_DEFAULTS) {
    if ($k !~ /^([^\+]+)\+(.*)$/) {next;}
    my $s = $1; my $e = $2;
    if ($s ne $section) {$defs .= "[$s]\n"; $section = $s;}
    $defs .= "$e=".$CONFIG_DEFAULTS{$k}."\n";
  }
  my $newconf = '';
  if (open(MCF, $READLAYER, $CONFFILE)) {
    while(<MCF>) {
      if ($defs && $. != 1 && $_ =~ /^\[/) {$newconf .= "$defs\n"; $defs = '';}
      $newconf .= $_;
    }
    $newconf .= $comments;
    close(MCF);
  }
  else {&ErrorBug("customize_conf could not open config file $CONFFILE");}
  if ($newconf) {
    if (open(MCF, $WRITELAYER, $CONFFILE)) {
      print MCF $newconf;
      close(MCF);
    }
    else {&ErrorBug("customize_conf could not open config file $CONFFILE");}
  }
}

sub customize_addScripRefLinks {
  my $cf = shift;
  my $booknamesHP = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  # Collect all available Bible book abbreviations
  my %abbrevs;
  # $booknamesHP is from BookNames.xml
  foreach my $bk (sort keys %{$booknamesHP}) {
    foreach my $type (sort keys %{$booknamesHP->{$bk}}) {
      # 'long' names aren't normally used for Scripture references but
      # they don't slow down the parser very much at all, and are 
      # sometimes useful so keep them.
      #if ($type eq 'long') {next;}
      $abbrevs{$booknamesHP->{$bk}{$type}} = $bk;
    }
  }
  # from SFM files (%USFM)
  foreach my $f (sort keys %{$USFM{'bible'}}) {
    foreach my $t (sort keys %{$USFM{'bible'}{$f}}) {
      if ($t !~ /^toc\d$/) {next;}
      $abbrevs{$USFM{'bible'}{$f}{$t}} = $USFM{'bible'}{$f}{'osisBook'};
    }
  }
  
  # Collect Scripture reference markup settings
  my %cfSettings = (
    '00 CURRENT_BOOK_TERMS' => [],
    '01 CURRENT_CHAPTER_TERMS' => [],
    '02 CHAPTER_TERMS' => [],
    '03 VERSE_TERMS' => [],
    '04 SEPARATOR_TERMS' => [',', ';'],
    '06 REF_END_TERMS' => ['\.', '\s', '\)', '<', '$'],
    '07 CHAPTER_TO_VERSE_TERMS' => ['\:'],
    '08 CONTINUATION_TERMS' => ['\-'],
    '09 PREFIXES' => [],
    '10 SUFFIXES' => ['\.']
  );
  my $paratextSettingsP = &readParatextReferenceSettings();
  foreach my $k (sort keys %{$paratextSettingsP}) {$paratextSettingsP->{$k} = quotemeta($paratextSettingsP->{$k});}
  my %cf2paratext = ( # mapping from osis-converters CF_addScripRefLinks.txt settings to Paratext settings
    '04 SEPARATOR_TERMS' => ['SequenceIndicator', 'ChapterNumberSeparator'],
    '06 REF_END_TERMS' => ['ReferenceFinalPunctuation'],
    '07 CHAPTER_TO_VERSE_TERMS' => ['ChapterVerseSeparator'],
    '08 CONTINUATION_TERMS' => ['RangeIndicator', 'ChapterRangeSeparator']
  );
  foreach my $cfs (sort keys %cfSettings) {
    if (!exists($cf2paratext{$cfs})) {next;}
    my @val;
    foreach my $ps (@{$cf2paratext{$cfs}}) {
      if (!$paratextSettingsP->{$ps}) {next;}
      push(@val, $paratextSettingsP->{$ps});
    }
    if (@val) {
      if ($cfs eq '06 REF_END_TERMS') {push(@val, @{$cfSettings{$cfs}});}
      my %seen; my @uniq = grep !$seen{$_}++, @val;
      &Note("Setting default CF_addScripRefLinks.txt $cfs from '".&toCFRegex($cfSettings{$cfs})."' to '".&toCFRegex(\@uniq)."'");
      $cfSettings{$cfs} = \@uniq;
    }
  }
  my @comRefTerms;
  $cfSettings{'05 COMMON_REF_TERMS'} = \@comRefTerms;
  
  # Write to CF_addScripRefLinks.txt in the most user friendly way possible
  if (!open(CFT, $WRITELAYER, "$cf.tmp")) {&ErrorBug("Could not open \"$cf.tmp\"", 1);}
  foreach my $cfs (sort keys %cfSettings) {
    my $pcfs = $cfs; $pcfs =~ s/^\d\d //;
    print CFT "$pcfs:".( @{$cfSettings{$cfs}} ? &toCFRegex($cfSettings{$cfs}):'')."\n";
  }
  print CFT "\n";
  foreach my $group (@OSIS_GROUPS) {
    foreach my $osis (@{$OSIS_GROUP{$group}}) {
      print CFT &getAllAbbrevsString($osis, \%abbrevs);
    }
  }
  
  close(CFT);
  unlink($cf);
  move("$cf.tmp", $cf);
}
sub toCFRegex {
  my $aP = shift;
  
  my @sorted = sort { length $a <=> length $b } @{$aP};
  # remove training spaces from segments
  foreach my $s (@sorted) {if ($s =~ s/(\S)\\?\s+$/$1/) {&Note("Removed trailing space from $s");}}
  return '('.join('|', @sorted).')';
}
sub readParatextReferenceSettings {

  my @files = split(/\n/, &shell("find \"$MAININPD/sfm\" -type f -exec grep -q \"<RangeIndicator>\" {} \\; -print", 3, 1));
  my $settingsFilePATH;
  my $settingsFileXML;
  foreach my $file (@files) {
    if ($file && -e $file && -r $file) {
      &Note("Reading Settings.xml file: $file", 1);
      $settingsFilePATH = $file;
      last;
    }
  }
  if ($settingsFilePATH) {$settingsFileXML = $XML_PARSER->parse_file($settingsFilePATH);}

  # First set the defaults
  my %settings = (
    'RangeIndicator' => '-', 
    'SequenceIndicator' => ',', 
    'ReferenceFinalPunctuation' => '.', 
    'ChapterNumberSeparator' => '; ', 
    'ChapterRangeSeparator' => decode('utf8', '—'), 
    'ChapterVerseSeparator' => ':',
    'BookSequenceSeparator' => '; '
  );
  
  # Now overwrite defaults with anything in settingsFileXML
  foreach my $k (sort keys %settings) {
    my $default = $settings{$k};
    if ($settingsFileXML) {
      my $kv = @{$XPC->findnodes("$k", $settingsFileXML)}[0];
      if ($kv && $kv->textContent) {
        my $v = $kv->textContent;
        &Note("<>Found localized Scripture reference settings in $settingsFilePATH");
        if ($v ne $default) {
          &Note("Setting Paratext $k from '".$settings{$k}."' to '$v' according to $settingsFilePATH");
          $settings{$k} = $v;
        }
      }
    }
  }
  
  #use Data::Dumper; &Debug("Paratext settings = ".Dumper(\%settings)."\n", 1); 
  
  return \%settings;
}
sub getAllAbbrevsString {
  my $osisBook = shift;
  my $nameBookP = shift;
  
  my $p = '';
  foreach my $name (sort { length($b) <=> length($a) } keys %{$nameBookP}) {
    if (!$nameBookP->{$name} || $nameBookP->{$name} ne $osisBook || $name =~ /^\s*$/) {next;}
    $p .= sprintf("%-6s = %s\n", $osisBook, $name);
    $nameBookP->{$name} = ''; # only print each abbrev once
  }
  
  return $p;
}

# Sort USFM files by scope, type, book, then filename
sub usfmFileSort {
  my $fa = shift;
  my $fb = shift;
  my $infoP = shift;
  
  my $scopea = $infoP->{$fa}{'scope'};
  my $scopeb = $infoP->{$fb}{'scope'};
  
  # sort by scope exists or not
  my $r = ($scopea ? 1:0) <=> ($scopeb ? 1:0);
  if ($r) {return $r;}
  
  # sort by first book of scope
  $scopea =~ s/^([^\s\-]+).*?$/$1/;
  $scopeb =~ s/^([^\s\-]+).*?$/$1/;
  $r = &defaultOsisIndex($scopea) <=> &defaultOsisIndex($scopeb);
  if ($r) {return $r;}
  
  # sort by type, bible books last
  my $typea = ($infoP->{$fa}{'osisBook'} ? 'book':'other');
  my $typeb = ($infoP->{$fb}{'osisBook'} ? 'book':'other');
  if ($typea ne $typeb) {return ($typea eq 'book' ? 1:-1);}
  
  # if we have bible books, sort by default order
  if ($typea eq 'bible') {
    $r = &defaultOsisIndex($infoP->{$fa}{'osisBook'}) <=> 
         &defaultOsisIndex($infoP->{$fb}{'osisBook'});
    if ($r) {return $r;}
  }

  # finally sort by file name
  return $fa cmp $fb;
}

sub customize_usfm2osis {
  my $cf = shift;
  my $modType = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  if (!open (CFF, $APPENDLAYER, "$cf")) {&ErrorBug("Could not open \"$cf\"", 1);}
  print CFF "\n# NOTE: The order of books in the final OSIS file will be verse system order, regardless of the order they are run in this control file.\n";
  my $lastScope;
  foreach my $f (sort { usfmFileSort($a, $b, $USFM{$modType}) } keys %{$USFM{$modType}}) {
    my $scope = $USFM{$modType}{$f}{'scope'};
    if ($scope ne $lastScope) {
      print CFF "\n";
      if ($scope) {print CFF "# $scope\n";}
    }
    $lastScope = $scope;
    
    my $r = File::Spec->abs2rel($f, $MAININPD);
    $r = ($modType eq 'dictionary' ? '.':'').($r !~ /^\./ ? './':'').$r;
    
    # peripherals need a target location in the OSIS file listed after their ID
    if ($USFM{$modType}{$f}{'peripheralID'}) {
      #print CFF "\n# Use location == <xpath> to place this peripheral in the proper location in the OSIS file\n";
      if (defined($ID_TYPE_MAP{$USFM{$modType}{$f}{'peripheralID'}})) {
        print CFF "EVAL_REGEX($r):s/^(\\\\id ".quotemeta($USFM{$modType}{$f}{'peripheralID'}).".*)\$/\$1";
      }
      else {
        print CFF "EVAL_REGEX($r):s/^(\\\\id )".quotemeta($USFM{$modType}{$f}{'peripheralID'})."(.*)\$/\$1FRT\$2";
      }
      
      my @instructions;
      if ($scope) {push(@instructions, "scope == $scope");} # scope is first instruction because it only effects following instructions
      if ($modType eq 'bible') {
        push(@instructions, &getOsisMap('sfmfile', $scope));
        if (defined($USFM{$modType}{$f}{'periphType'}) && @{$USFM{$modType}{$f}{'periphType'}}) {
          foreach my $periphType (@{$USFM{$modType}{$f}{'periphType'}}) {
            my $osisMap = &getOsisMap($periphType, $scope);
            if (!defined($osisMap)) {
              &Error("Unrecognized peripheral name \"$periphType\" in $f.", "Change it to one of the following: " . join(', ', sort keys %PERIPH_TYPE_MAP));
              next;
            }
            push(@instructions, $osisMap);
          }
        }
      }
      if (@instructions) {
        splice(@instructions, 0, 0, ''); # to add leading separator with join
        my $line = join(", ", @instructions);
        $line =~ s/([\@\$\/])/\\$1/g; # escape these so Perl won't interperet them as special chars on the replacement side s//X/
        print CFF "$line";
      }
      print CFF "/m\n";
    }

    print CFF "RUN:$r\n";
  }
  close(CFF);
}

# Given an official peripheral-type and scope, return the
# CF_usfm2osis.txt code for default placement of that peripheral within 
# the OSIS file. When $periphType is 'sfmfile' (meaning an entire sfm 
# file) it is placed in the proper bookGroup, or at the beginning of the
# first book of $scope, or else after the osis:header.
sub getOsisMap {
  my $periphType = shift; # a key to %USFM_DEFAULT_PERIPH_TARGET defined in fitToVerseSystem.pl
  my $scope = shift;
  
  # default sfmfile placement is after osis header
  my $defPath = 'osis:header/following-sibling::node()[1]';
  
  my $scopePath = $defPath;
  if ($scope) {
    if ($scope eq 'Matt-Rev') {$scopePath = $USFM_DEFAULT_PERIPH_TARGET{'New Testament Introduction'};}
    elsif ($scope eq 'Gen-Mal') {$scopePath = $USFM_DEFAULT_PERIPH_TARGET{'Old Testament Introduction'};}
    else {
      $scopePath = ($scope =~ /^([^\s\-]+)/ ? $1:''); # try to get first book of scope
      if ($scopePath && defined($OSIS_ABBR{$scopePath})) {
        # place at the beginning of the first book of scope
        $scopePath = 'osis:div[@type="book"][@osisID="'.$scopePath.'"]/node()[1]';
      }
      else {
        &Error("USFM file's scope \"$scope\" is not recognized.", 
"Make sure the sfm sub-directory is named using a proper OSIS 
book scope, such as: 'Ruth_Esth_Jonah' or 'Matt-Rev'");
        $scopePath = $defPath;
      }
    }
  }
  if ($periphType eq 'sfmfile') {return "location == $scopePath";}

  my $periphTypeDescriptor = $PERIPH_TYPE_MAP{$periphType};
  if (!$periphTypeDescriptor) {return;}
  if ($periphTypeDescriptor eq 'introduction') {$periphTypeDescriptor = $PERIPH_SUBTYPE_MAP{$periphType};}

  # default periph placement is introduction to first book
  my $xpath = 'osis:div[@type="book"]/node()[1]';
  foreach my $t (sort keys %USFM_DEFAULT_PERIPH_TARGET) {
    if ($periphType !~ /^($t)$/i) {next;}
    $xpath = $USFM_DEFAULT_PERIPH_TARGET{$t};
    if ($xpath eq 'place-according-to-scope') {$xpath = $scopePath;}
    last;
  }
  
  return "\"$periphType\" == $xpath";
}

# Copy fontname (which is part of a filename which may correspond to multiple
# font files) to fontdir 
sub copyFont {
  my $fontname = shift;
  my $fontdir = shift;
  my $fontP = shift;
  my $outdir = shift;
  my $dontRenameRegularFile = shift;
  
  &Log("\n--- COPYING font \"$fontname\"\n");
  
  $outdir =~ s/\/\s*$//;
  `mkdir -p "$outdir"`;
  
  my $copied = 0;
  foreach my $f (sort keys %{$fontP->{$fontname}}) {
    my $fdest = $f;
    if (!$dontRenameRegularFile && $fontP->{$fontname}{$f}{'style'} eq 'regular') {
      $fdest =~ s/^.*\.([^\.]+)$/$fontname.$1/;
    }
    &copy("$fontdir/$f", "$outdir/$fdest");
    $copied++;
    &Note("Copied font file $f to \"$outdir/$fdest\"");
  }
}

my $SCAN_USFM_SKIPPED;
sub scanUSFM {
  my $sfm_dir = shift;
  my $sfmP = shift;
  
  $SCAN_USFM_SKIPPED = '';
  
  if (!opendir(SFMS, $sfm_dir)) {
    &Error("Unable to read default sfm directory: \"$sfm_dir\"", '', 1);
  }
  
  my @sfms = readdir(SFMS); closedir(SFMS);
  
  foreach my $sfm (@sfms) {
    if ($sfm =~ /^\./) {next;}
    my $f = "$sfm_dir/$sfm";
    if (-d $f) {&scanUSFM($f, $sfmP); next;}
    my $sfmInfoP = &scanUSFM_file($f);
    if (!$sfmInfoP->{'doConvert'}) {next;}
    $sfmP->{$sfmInfoP->{'type'}}{$f} = $sfmInfoP;
  }
  
  if ($SCAN_USFM_SKIPPED) {&Log("$SCAN_USFM_SKIPPED\n");}
}

sub scanUSFM_file {
  my $f = shift;
  
  my %info;
  
  &Log("Scanning SFM file: \"$f\"\n");
  
  if (!open(SFM, $READLAYER, $f)) {&ErrorBug("scanUSFM_file could not read \"$f\"", 1);}
  
  $info{'scope'} = ($f =~ /\/sfm\/([^\/]+)\/[^\/]+$/ ? $1:'');
  if ($info{'scope'}) {$info{'scope'} =~ s/_/ /g;}
  
  my $id;
  # Only the first of each of the following tag roots (by root meaning 
  # the tag followed by any digit) within an SFM file, will be 
  # recorded.
  my @tags = ('h', 'imt', 'is', 'mt', 'toc1', 'toc2', 'toc3');
  while(<SFM>) {
    if ($_ =~ /^\W*?\\id \s*(\S+)/) {
      my $i = $1; 
      if ($id) {
        if (substr($id, 0, 3) ne substr($i, 0, 3)) {&Warn("ambiguous id tags: \"$id\", \"$i\"");}
        next;
      }
      $id = $i;
      &Note("id is $id");
    }
    foreach my $t (@tags) {
      if ($_ =~ /^\\($t\d*) \s*(.*?)\s*$/) {
        my $ts = $1; my $tv = $2;
        $tv =~ s/\/\// /g; $tv =~ s/ +/ /g; # Remove forced line breaks and extra spaces from titles/names/etc.
        if ($info{$t}) {&Note("ignoring SFM $ts tag which is \"".$tv."\""); next;}
        $info{$t} = $tv;
      }
    }
    if ($_ =~ /^\\periph\s+(.*?)\s*$/) {
      my $pt = $1;
      push(@{$info{'periphType'}}, $pt);
    }
    if ($_ =~ /^\\(c|ie)/) {last;}
  }
  close(SFM);
  
  if ($id =~ /^\s*(\w{2,3}).*$/) {
    my $shortid = $1;
    $info{'doConvert'} = 1;
    my $osisBook = &bookOsisAbbr($shortid);
    if ($osisBook) {
      $info{'osisBook'} = $osisBook;
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /^(FRT|INT|TOC|OTH|AVT|PRE|TTL)/i) { # AVT, PRE, and TTL are from old back-converted osis-converters projects
      $info{'type'} = 'bible';
      $info{'peripheralID'} = $id;
    }
    elsif ($id =~ /(GLO|DIC|BAK|FIN|CNC|TDX|NDX)/i) {
      $info{'type'} = 'dictionary';
      $info{'peripheralID'} = $1;
    }
    elsif ($id =~ /^(PREPAT|SHM[NO]T|CB|NT|OT|FOTO)/i) { # Strange IDs associated with Children's Bibles
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /^\s*(\w{3})\b/) {
      $info{'peripheralID'} = $1;
      $info{'type'} = 'dictionary'; # This has some kind of SFM-like id, so just treat it like a dictionary peripheral
    }
    # others are currently unhandled by osis-converters
    else {
      $info{'type'} = 'other';
      $info{'doConvert'} = 0;
      $SCAN_USFM_SKIPPED .= "ERROR: SFM file \"$f\" has an unrecognized ID \"$id\" and is being SKIPPED!\n";
    }
    &Note(" ");
    foreach my $k (sort keys %info) {&Log(" $k=[".$info{$k}."]");}
    &Log("\n");
  }
  
  &Log("\n");
  
  return \%info;
}

# Sets a config.conf entry to a particular value (when $flag = 1) or  
# adds another entry having the value if there isn't already one ($flag 
# = 2) or just checks that an entry is present with the value (!$flag). 
# Returns 1 if the config contains the value upon function exit, or 0 if 
# it does not.
sub setConfValue {
  my $confP = shift;
  my $fullEntry = shift;
  my $value = shift;
  my $flag = shift;
  
  my $multRE = &configRE(@MULTIVALUE_CONFIGS);
  
  my $e = $fullEntry;
  my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
  if (!$s) {
    &ErrorBug("setConfValue requires a qualified config entry name.", 1);
  }
 
  my $sep = ($e =~ /$multRE/ ? '<nx/>':'');
  
  if ($value eq $confP->{$fullEntry}) {return 1;}
  if ($flag != 1 && $sep && 
      $confP->{$fullEntry} =~ /(^|\s*\Q$sep\E\s*)\Q$value\E(\s*\Q$sep\E\s*|$)/) {
    return 1;
  }
  if ($flag == 2 && !$sep) {
    &ErrorBug("Config entry '$e' cannot have multiple values, but setConfValue flag='$flag'", 1);
  }
  
  if (!$flag) {return 0;}
  elsif ($flag == 1) {
    $confP->{$fullEntry} = $value;
  }
  elsif ($flag == 2) {
    if ($confP->{$fullEntry}) {$confP->{$fullEntry} .= $sep.$value;}
    else {$confP->{$fullEntry} = $value;}
  }
  else {&ErrorBug("Unexpected setConfValue flag='$flag'", 1);}
  return 1;
}

# Sets a config entry for a CrossWire SWORD module. If the entry is not
# a valid SWORD config entry, an error is thrown.
sub setSwordConfValue {
  my $confP = shift;
  my $entry = shift;
  my $value = shift;
  
  if ($entry =~ /\+/) {
    &ErrorBug("setSwordConfValue requires an unqualified config entry name.");
  }
  
  my $swordAutoRE = &configRE(@SWORD_CONFIGS, @SWORD_OC_CONFIGS);
  if ($entry !~ /$swordAutoRE/) {
    &ErrorBug("'$entry' is not a valid SWORD entry.", 1);
  }
  
  my $multRE = &configRE(@MULTIVALUE_CONFIGS);
  if ($entry =~ /$multRE/) {
    &setConfValue($confP, "$MOD+$entry", $value, 2);
  }
  else {
    &setConfValue($confP, "$MOD+$entry", $value, 1);
  }
}

# If $path_or_pointer is a path, $xml is written to it. If it is a 
# pointer, then temporaryFile(pointed-to) will be written, and the 
# pointer will be updated to that new path. If $outname or $levelup is
# provided, they will be passed to temporaryFile().
sub writeXMLFile {
  my $xml = shift;
  my $path_or_pointer = shift;
  my $outname = shift;
  my $levelup = shift;
  
  if (!$levelup) {$levelup = 1;}
  
  my $output;
  if (!ref($path_or_pointer)) {
    $output = $path_or_pointer;
  }
  else {
    $output = &temporaryFile($$path_or_pointer, $outname, (1+$levelup));
    $$path_or_pointer = $output;
  }
  
  if (open(XML, ">$output")) {
    $DOCUMENT_CACHE{$output} = '';
    print XML $xml->toString();
    close(XML);
  }
  else {&ErrorBug("Could not open XML file for writing: '$output'", 1);}
}

sub osis_converters {
  my $script = shift;
  my $project_dir = shift; # THIS MUST BE AN ABSOLUTE PATH!
  my $logfile = shift;
  
  my $cmd = &escfile($script)." ".&escfile($project_dir).($logfile ? " ".&escfile($logfile):'');
  &Log("\n\n\nRUNNING OSIS_CONVERTERS:\n$cmd\n", 1);
  &Log("########################################################################\n", 1);
  &Log("########################################################################\n", 1);
  system($cmd.($logfile ? " 2>> ".&escfile($logfile):''));
}

# Write config file $conf to contain entries in $entryValueP. Config 
# entries of defaults/defaults.conf will NOT be included in the 
# resulting config file unless $writeDefaults is set.
sub writeConf {
  my $conf = shift;
  my $entryValueP = shift;
  my $writeDefaults = shift;
  
  my %defaults;
  my $oc = &getDefaultFile('defaults.conf', -1);
  if (-e $oc) {
    &readConfFile($oc, \%defaults, undef, 1);
  }
  
  my $confdir = $conf; $confdir =~ s/([\\\/][^\\\/]+){1}$//;
  if (!-e $confdir) {make_path($confdir);}
  
  if (open(XCONF, $WRITELAYER, $conf)) {
    my $section = '';
    foreach my $fullName (sort { &confEntrySort($a, $b, $entryValueP); } keys %{$entryValueP} ) {
      if ($fullName =~ /^(MainmodName|DictmodName)$/) {next;}
      elsif (!$writeDefaults && defined($defaults{$fullName})) {next;}
      else {
        my $e = $fullName; 
        my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
        if (!$s) {
          &ErrorBug("Config entry has no section: $fullName", 1);
        }
        if ($s ne $section) {
          print XCONF ($section ? "\n":'')."[$s]\n";
          $section = $s;
        }
        
        foreach my $val (split(/<nx\/>/, $entryValueP->{$fullName})) {
          print XCONF $e."=".$val."\n";
        }
      }
    }
    close(XCONF);
  }
  else {
    &Error("Could not open config.conf file: $conf.");
    return;
  }

  #use Data::Dumper; &Log(Dumper($entryValueP)."\n", 1);

  $entryValueP = &readConfFile($conf);
  return $entryValueP;
}
sub confEntrySort {
  my $a = shift;
  my $b = shift;
  my $confP = shift;
  
  my $ae = $a; my $be = $b;
  my $as = ($ae =~ s/([^\+]+)\+// ? $1:'');
  my $bs = ($be =~ s/([^\+]+)\+// ? $1:'');
  if    ($as eq $confP->{'MainmodName'}) {$as = 'MAINMOD';}
  elsif ($as eq $confP->{'DictmodName'}) {$as = 'DICTMOD';}
  if    ($bs eq $confP->{'MainmodName'}) {$bs = 'MAINMOD';}
  elsif ($bs eq $confP->{'DictmodName'}) {$bs = 'DICTMOD';}
    
  # First by section
  my $ax = @CONFIG_SECTIONS,
  my $bx = @CONFIG_SECTIONS;
  for (my $i=0; $i < @CONFIG_SECTIONS; $i++) {
    if ($as eq @CONFIG_SECTIONS[$i]) {$ax = $i;}
    if ($bs eq @CONFIG_SECTIONS[$i]) {$bx = $i;}
  }
  my $res = ($ax <=> $bx);
  if ($res) {return $res;}
  
  # Then by entry
  return $ae cmp $be;
}

# Return a list of all config entries which have values in the current 
# context.
sub contextConfigEntries {
  
  my @entries;
  foreach my $fe (keys %{$CONF}) {
    if ($fe =~ /^(MainmodName|DictmodName)$/) {next;}
    my $e = $fe;
    my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
    if ($s eq 'system') {next;}
    if (!defined(&conf($e, undef, undef, undef, 1))) {next;}
    push(@entries, $e);
  }
  
  return @entries;
}

# Fill a config conf data pointer with SWORD entries taken from:
# 1) Project config.conf
# 2) Current OSIS source file
# 3) auto-generated 
sub getSwordConf {
  my $moduleSource = shift;
  
  my %swordConf = ( 'MainmodName' => $MOD );
  
  # Copy appropriate values from project config.conf
  my $swordConfigRE = &configRE(@SWORD_CONFIGS, @SWORD_OC_CONFIGS);
  foreach my $e (&contextConfigEntries()) {
    if ($e !~ /$swordConfigRE/) {next;}
    &setSwordConfValue(\%swordConf, $e, &conf($e));
  }
  
  my $moddrv = $swordConf{"$MOD+ModDrv"};
  if (!$moddrv) {
		&Error("No ModDrv specified in $moduleSource.", 
    "Update the OSIS file by re-running sfm2osis.pl.", '', 1);
	}
  
	my $dp;
  my $mod = $swordConf{"MainmodName"};
	if    ($moddrv eq "RawText")    {$dp = "./modules/texts/rawtext/".lc($mod)."/";}
  elsif ($moddrv eq "RawText4")   {$dp = "./modules/texts/rawtext4/".lc($mod)."/";}
	elsif ($moddrv eq "zText")      {$dp = "./modules/texts/ztext/".lc($mod)."/";}
	elsif ($moddrv eq "zText4")     {$dp = "./modules/texts/ztext4/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom")     {$dp = "./modules/comments/rawcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom4")    {$dp = "./modules/comments/rawcom4/".lc($mod)."/";}
	elsif ($moddrv eq "zCom")       {$dp = "./modules/comments/zcom/".lc($mod)."/";}
	elsif ($moddrv eq "HREFCom")    {$dp = "./modules/comments/hrefcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawFiles")   {$dp = "./modules/comments/rawfiles/".lc($mod)."/";}
	elsif ($moddrv eq "RawLD")      {$dp = "./modules/lexdict/rawld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawLD4")     {$dp = "./modules/lexdict/rawld4/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "zLD")        {$dp = "./modules/lexdict/zld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawGenBook") {$dp = "./modules/genbook/rawgenbook/".lc($mod)."/".lc($mod);}
	else {
		&Error("ModDrv \"$moddrv\" is unrecognized.", "Change it to a recognized SWORD module type.");
	}
  # At this time (Jan 2017) JSword does not yet support zText4
  if ($moddrv =~ /^(raw)(text|com)$/i || $moddrv =~ /^rawld$/i) {
    &Error("ModDrv \"".$moddrv."\" should be changed to \"".$moddrv."4\" in config.conf.");
  }
  &setSwordConfValue(\%swordConf, 'DataPath', $dp);

  my $type = 'genbook';
  if ($moddrv =~ /LD/) {$type = 'dictionary';}
  elsif ($moddrv =~ /Text/) {$type = 'bible';}
  elsif ($moddrv =~ /Com/) {$type = 'commentary';}
  
  &setSwordConfValue(\%swordConf, 'Encoding', 'UTF-8');

  if ($moddrv =~ /Text/) {
    &setSwordConfValue(\%swordConf, 'Category', 'Biblical Texts');
    if ($moddrv =~ /zText/) {
      &setSwordConfValue(\%swordConf, 'CompressType', 'ZIP');
      &setSwordConfValue(\%swordConf, 'BlockType', 'BOOK');
    }
  }
  
  my $moduleSourceXML = $XML_PARSER->parse_file($moduleSource);
  my $sourceType = 'OSIS'; # NOTE: osis2tei.xsl still produces a TEI file having OSIS markup!
  
  if (($type eq 'bible' || $type eq 'commentary')) {
    &setSwordConfValue(\%swordConf, 'Scope', &getScope($moduleSourceXML));
  }
  
  if ($moddrv =~ /LD/ && !$swordConf{"$MOD+KeySort"}) {
    &setSwordConfValue(\%swordConf, 'KeySort', &getApproximateLangSortOrder($moduleSourceXML));
  }
  if ($moddrv =~ /LD/ && !$swordConf{"$MOD+LangSortOrder"}) {
    &setSwordConfValue(\%swordConf, 'LangSortOrder', &getApproximateLangSortOrder($moduleSourceXML));
  }
  
  &setSwordConfValue(\%swordConf, 'SourceType', $sourceType);
  if ($swordConf{"$MOD+SourceType"} !~ /^(OSIS|TEI)$/) {
    &Error("Unsupported SourceType: ".$swordConf{"$MOD+SourceType"}, 
    "Only OSIS and TEI are supported by osis-converters", 1);
  }
  if ($swordConf{"$MOD+SourceType"} eq 'TEI') {
    &Warn("Some front-ends may not fully support TEI yet");
  }
  
  if ($swordConf{"$MOD+SourceType"} eq 'OSIS') {
    my $vers = @{$XPC->findnodes('//osis:osis/@xsi:schemaLocation', $moduleSourceXML)}[0];
    if ($vers) {
      $vers = $vers->value; $vers =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
      &setSwordConfValue(\%swordConf, 'OSISVersion', $vers);
    }
    if ($XPC->findnodes("//osis:reference[\@type='x-glossary']", $moduleSourceXML)) {
      &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 
      'OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On');
    }

    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISFootnotes');
    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISHeadings');
    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISScripref');
  }
  
  if ($moddrv =~ /LD/) {
    &setSwordConfValue(\%swordConf, 'SearchOption', 'IncludeKeyInSearch');
    # The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
    if ($UPPERCASE_DICTIONARY_KEYS) {
      &setSwordConfValue(\%swordConf, 'CaseSensitiveKeys', 'true');
    }
  }

  my @tm = localtime(time);
  &setSwordConfValue(\%swordConf, 'SwordVersionDate', sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]));
  
  return \%swordConf;
}


sub checkConfGlobals {

  if ($MAINMOD =~ /^...CB$/ && &conf('FullResourceURL')) {
    &Error("For Children's Bibles, FullResourceURL must be removed from config.conf or set to false.", "Children's Bibles do not currently support this feature so it must be turned off.");
  }
  foreach my $entry (sort keys %{$CONF}) {
    my $isConf = &isValidConfig($entry);
    if (!$isConf) {
      &Error("Unrecognized config entry: $entry", "Either this entry is not needed, or else it is named incorrectly.");
    }
    elsif ($isConf eq 'sword-autogen') {
      &Error("Config request '$entry' is valid but it should not be set in config.conf because it is auto-generated by osis-converters.", "Remove this entry from the config.conf file.");
    }
  }
  
  # Check companion value(s)
  if ($DICTMOD && &conf('Companion', $MAINMOD) ne &conf('Companion', $DICTMOD).'DICT') {
    &Error("config.conf companion entries are inconsistent: ".&conf('Companion', $MAINMOD).", ".&conf('Companion', $DICTMOD), 
    "Correct values should be:\n[$MOD]\nCompanion=$DICTMOD\n[$DICTMOD]\nCompanion=$MOD\n");
  }

  if ($INPD ne $DICTINPD) {
    # Check for UI that needs localization
    foreach my $s (@SUB_PUBLICATIONS) {
      my $sp = $s; $sp =~ s/\s/_/g;
      if (&conf("TitleSubPublication[$sp]") && &conf("TitleSubPublication[$sp]") !~ / DEF$/) {next;}
      &Warn("Sub publication title config entry 'TitleSubPublication[$sp]' is not localized: ".&conf("TitleSubPublication[$sp]"), 
      "You should localize the title in config.conf with: TitleSubPublication[$sp]=Localized Title");
    }
  }
  
  if ($DICTMOD && !&conf('KeySort', $DICTMOD)) {
    &Error("KeySort is missing from config.conf", '
This required config entry facilitates correct sorting of glossary 
keys. EXAMPLE:
KeySort = AaBbDdEeFfGgHhIijKkLlMmNnOoPpQqRrSsTtUuVvXxYyZz[G`][g`][Sh][sh][Ch][ch][ng]`{\\[\\\\[\\\\]\\\\{\\\\}\\(\\)\\]}
This entry allows sorting in any desired order by character collation. 
Square brackets are used to separate any arbitrary JDK 1.4 case  
sensitive regular expressions which are to be treated as single 
characters during the sort comparison. Also, a single set of curly 
brackets can be used around a regular expression which matches all 
characters/patterns to be ignored during the sort comparison. IMPORTANT: 
EVERY square or curly bracket within any regular expression must have an 
ADDITIONAL \ added before it. This is required so the KeySort value can 
be parsed correctly. This means the string to ignore all brackets and 
parenthesis would be: {\\[\\\\[\\\\]\\\\{\\\\}\\(\\)\\]}');
  }
  if ($DICTMOD && !&conf('LangSortOrder', $DICTMOD)) {
    &Error("LangSortOrder is missing from config.conf", "
Although this config entry has been replaced by KeySort and is 
deprecated and no longer used by osis-converters, for now it is still 
required to prevent the breaking of older programs. Its value is just 
that of KeySort, but bracketed groups of regular expressions are not 
allowed and must be removed.");
  }
  
}


sub checkRequiredConfEntries {

  if (&conf('Abbreviation') eq $MOD) {
    &Warn("Currently the config.conf 'Abbreviation' setting is '$MOD'.",
"This is a short user-readable name for the module.");
  }
  
  if (&conf('About') eq 'ABOUT') {
    &Error("You must provide the config.conf 'About' setting with information about module $MOD.",
"This can be a lengthier description and may include copyright, 
source, etc. information, possibly duplicating information in other 
elements.");
  }
  
  if (&conf('Description') eq 'DESCRIPTION') {
    &Error("You must provide the config.conf 'Description' setting with a short description about module $MOD.",
"This is a short (1 line) title for the module.");
  }
  
  if (&conf('Lang') eq 'LANG') {
    &Error("You must provide the config.conf 'Lang' setting as the ISO-639 code for this language.",
"Use the shortest available ISO-639 code. If there may be multiple 
scripts then follow the languge code with '-' and an ISO-15924 4 letter 
script code, such as: 'Cyrl', 'Latn' or 'Arab'.");
  }
}


sub getApproximateLangSortOrder {
  my $tei = shift;
  
  my $res = '';
  my @entries = $XPC->findnodes('//tei:entryFree/@n', $tei);
  my $last = '';
  foreach my $e (@entries) {
    my $l = substr($e->value, 0, 1);
    if (&uc2($l) eq $last) {next;}
    $res .= &uc2($l).&lc2($l);
    $last = &uc2($l);
  }

  return $res;
}

# Convert entire OSIS file to Normalization Form C (formed by canonical 
# decomposition followed by canonical composition) or another form.
sub normalizeUnicode {
  my $osisP = shift;
  my $normalizationType = shift;
  
  if ($normalizationType =~ /true/i) {$normalizationType = 'NFC';}
  
  no strict 'refs';
  if (!defined(&$normalizationType)) {
    &Error("Unknown Unicode normalization type: $normalizationType", 
"Change NormalizeUnicode in config.conf to true, false, NFD, 
NFC, NFKD, NFKC or FCD. See https://perldoc.perl.org/Unicode/Normalize.html 
for an explanation of the differences.");
    return;
  }
  
  use Unicode::Normalize;
  
  my $output = &temporaryFile($$osisP, '', 1);
  
  open(ISF, $READLAYER, $$osisP);
  open(OSF, $WRITELAYER, $output);
  while (<ISF>) {print OSF &$normalizationType($_);}
  close(OSF);
  close(ISF);
  
  $$osisP = $output;
}


# Converts cases using special translations
sub lc2 {return &uc2(shift, 1);}
sub uc2 {
  my $t = shift;
  my $tolower = shift;
  
  # Form for $i: a->A b->B c->C ...
  our $SPECIAL_CAPITALS;
  if ($SPECIAL_CAPITALS) {
    my $r = $SPECIAL_CAPITALS;
    $r =~ s/(^\s*|\s*$)//g;
    my @trs = split(/\s+/, $r);
    for (my $i=0; $i < @trs; $i++) {
      my @tr = split(/->/, $trs[$i]);
      if ($tolower) {
        $t =~ s/$tr[1]/$tr[0]/g;
      }
      else {
        $t =~ s/$tr[0]/$tr[1]/g;
      }
    }
  }

  $t = ($tolower ? lc($t):uc($t));

  return $t;
}

my %CANON_CACHE;
sub getCanon {
  my $vsys = shift;
  my $canonPP = shift;     # hash pointer: OSIS-book-name => Array (base 0!!) containing each chapter's max-verse number
  my $bookOrderPP = shift; # hash pointer: OSIS-book-name => position (Gen = 1, Rev = 66)
  my $testamentPP = shift; # hash pointer: OSIS-nook-name => 'OT' or 'NT'
  my $bookArrayPP = shift; # array pointer: OSIS-book-names in verse system order starting with index 1!!
  
  if (!$CANON_CACHE{$vsys}) {
    if (!&isValidVersification($vsys)) {
      &Error("Not a valid versification system: $vsys".
"Must be one of: ($SWORD_VERSE_SYSTEMS)");
      return;
    }
    
    my $vk = new Sword::VerseKey();
    $vk->setVersificationSystem($vsys);
    
    for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
      my ($t, $bkt);
      if ($bk < $vk->bookCount(1)) {$t = 1; $bkt = ($bk+1);}
      else {$t = 2; $bkt = (($bk+1) - $vk->bookCount(1));}
      $CANON_CACHE{$vsys}{'bookOrder'}{$bkname} = ($bk+1);
      $CANON_CACHE{$vsys}{'testament'}{$bkname} = ($t == 1 ? "OT":"NT");
      my $chaps = [];
      for (my $ch = 1; $ch <= $vk->chapterCount($t, $bkt); $ch++) {
        # Note: CHAPTER 1 IN ARRAY IS INDEX 0!!!
        push(@{$chaps}, $vk->verseCount($t, $bkt, $ch));
      }
      $CANON_CACHE{$vsys}{'canon'}{$bkname} = $chaps;
    }
    @{$CANON_CACHE{$vsys}{'bookArray'}} = ();
    foreach my $bk (sort keys %{$CANON_CACHE{$vsys}{'bookOrder'}}) {
      @{$CANON_CACHE{$vsys}{'bookArray'}}[$CANON_CACHE{$vsys}{'bookOrder'}{$bk}] = $bk;
    }
  }
  
  if ($canonPP)     {$$canonPP     = \%{$CANON_CACHE{$vsys}{'canon'}};}
  if ($bookOrderPP) {$$bookOrderPP = \%{$CANON_CACHE{$vsys}{'bookOrder'}};}
  if ($testamentPP) {$$testamentPP = \%{$CANON_CACHE{$vsys}{'testament'}};}
  if ($bookArrayPP) {$$bookArrayPP = \@{$CANON_CACHE{$vsys}{'bookArray'}};}

  return $vsys;
}


sub isValidVersification {
  my $vsys = shift;
  
  my $vsmgr = Sword::VersificationMgr::getSystemVersificationMgr();
  my $vsyss = $vsmgr->getVersificationSystems();
  foreach my $vsys (@$vsyss) {if ($vsys->c_str() eq $vsys) {return 1;}}
  
  return 0;
}


sub changeNodeText {
  my $node = shift;
  my $new = shift;

  foreach my $r ($node->childNodes()) {$r->unbindNode();}
  if ($new) {$node->appendText($new)};
}

# Some of the following routines take either nodes or module names as inputs.
# Note: Whereas //osis:osisText[1] is TRULY, UNBELIEVABLY SLOW, /osis:osis/osis:osisText[1] is fast
sub getOsisModName {
  my $node = shift; # might already be string mod name- in that case just return it

  if (!ref($node)) {
    my $modname = $node; # node is not a ref() so it's a modname
    if (!$DOCUMENT_CACHE{$modname}) {
      our $OSIS;
      my $osis = ($SCRIPT_NAME =~ /^(osis2sword|osis2GoBible|osis2ebooks|osis2html)$/ ? $INOSIS:$OSIS);
      if (! -e $osis) {&ErrorBug("getOsisModName: No current osis file to read for $modname.", 1);}
      &initDocumentCache($XML_PARSER->parse_file($osis));
      if (!$DOCUMENT_CACHE{$modname}) {&ErrorBug("getOsisModName: header of osis $osis does not include modname $modname.", 1);}
    }
    return $modname;
  }
  
  # Generate doc data if the root document has not been seen before
  my $headerDoc = $node->ownerDocument->URI;

  if (!$DOCUMENT_CACHE{$headerDoc}) {
    # When splitOSIS() is used, the document containing the header may be different than the current node's document.
    my $splitOSISdoc = $headerDoc;
    if ($splitOSISdoc =~ s/[^\/]+$/other.osis/ && -e $splitOSISdoc) {
      if (!$DOCUMENT_CACHE{$splitOSISdoc}) {&initDocumentCache($XML_PARSER->parse_file($splitOSISdoc));}
      $DOCUMENT_CACHE{$headerDoc} = $DOCUMENT_CACHE{$splitOSISdoc};
    }
    else {&initDocumentCache($node->ownerDocument);}
  }
  
  if (!$DOCUMENT_CACHE{$headerDoc}) {
    &ErrorBug("initDocumentCache failed to init \"$headerDoc\"!", 1);
    return '';
  }
  
  return $DOCUMENT_CACHE{$headerDoc}{'getOsisModName'};
}
# Associated functions use this cached header data for a big speedup. 
# The cache is cleared and reloaded the first time a node is referenced 
# from an OSIS file URI.
sub initDocumentCache {
  my $xml = shift; # must be a document node
  
  my $dbg = "initDocumentCache: ";
  
  my $headerDoc = $xml->URI;
  undef($DOCUMENT_CACHE{$headerDoc});
  $DOCUMENT_CACHE{$headerDoc}{'xml'} = $xml;
  my $shd = $headerDoc; $shd =~ s/^.*\///; $dbg .= "document=$shd ";
  my $osisIDWork = @{$XPC->findnodes('/osis:osis/osis:osisText[1]', $xml)}[0];
  if (!$osisIDWork) {
    &ErrorBug("Document is not an osis document:".$headerDoc, 1);
  }
  $osisIDWork = $osisIDWork->getAttribute('osisIDWork');
  $DOCUMENT_CACHE{$headerDoc}{'getOsisModName'} = $osisIDWork;
  
  # Save data by MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  undef($DOCUMENT_CACHE{$osisIDWork});
  $DOCUMENT_CACHE{$osisIDWork}{'xml'}                = $xml;
  $dbg .= "selfmod=$osisIDWork ";
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisModName'}     = $osisIDWork;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisRefSystem'}   = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[@osisWork="'.$osisIDWork.'"]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'} = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type!="x-glossary"]]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'} =~ s/^Bible.//i;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisBibleModName'}    = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type!="x-glossary"]]', $xml)}[0]->getAttribute('osisWork');
  my $dict = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-glossary"]]', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisDictModName'}     = ($dict ? $dict->getAttribute('osisWork'):'');
  my %books; foreach my $bk (map($_->getAttribute('osisID'), $XPC->findnodes('//osis:div[@type="book"]', $xml))) {$books{$bk}++;}
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisBooks'} = \%books;
  my $scope = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[1]/osis:scope', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisScope'} = ($scope ? $scope->textContent():'');
  
  # Save companion data by its MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  my @works = $XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work', $xml);
  foreach my $work (@works) {
    my $w = $work->getAttribute('osisWork');
    if ($w eq $osisIDWork) {next;}
    undef($DOCUMENT_CACHE{$w});
    $DOCUMENT_CACHE{$w}{'getOsisRefSystem'} = @{$XPC->findnodes('./osis:refSystem', $work)}[0]->textContent;
    $dbg .= "compmod=$w ";
    $DOCUMENT_CACHE{$w}{'getOsisVersification'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'};
    $DOCUMENT_CACHE{$w}{'getOsisBibleModName'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisBibleModName'};
    $DOCUMENT_CACHE{$w}{'getOsisDictModName'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisDictModName'};
    $DOCUMENT_CACHE{$w}{'xml'} = ''; # force a re-read when again needed (by existsElementID)
  }
  &Debug("$dbg\n");
  
  return $DOCUMENT_CACHE{$osisIDWork}{'getOsisModName'};
}
# IMPORTANT: the osisCache lookup can ONLY be called on $modname after 
# a call to getOsisModName($modname), since getOsisModName($modname) 
# is where the cache is written.
sub osisCache {
  my $func = shift;
  my $modname = shift;

  if (exists($DOCUMENT_CACHE{$modname}{$func})) {return $DOCUMENT_CACHE{$modname}{$func};}
  &Error("DOCUMENT_CACHE failure: $modname $func\n");
  return '';
}
sub getOsisXML {
  my $mod = shift;

  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    undef($DOCUMENT_CACHE{$mod});
    &getOsisModName($mod);
    $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  }
  return $xml;
}
sub getOsisRefSystem {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisRefSystem', $mod);
  if (!$return) {
    &ErrorBug("getOsisRefSystem: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisVersification {
  my $mod = &getOsisModName(shift);

  if ($mod eq 'KJV') {return 'KJV';}
  if ($mod eq $MOD) {return &conf('Versification');}
  my $return = &osisCache('getOsisVersification', $mod);
  if (!$return) {
    &ErrorBug("getOsisVersification: No document node for \"$mod\"!");
    return &conf('Versification');
  }
  return $return;
}
sub getOsisBibleModName {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisBibleModName', $mod);
  if (!$return) {
    &ErrorBug("getOsisBibleModName: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisDictModName {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisDictModName', $mod);
  if (!$return) {
    &ErrorBug("getOsisDictModName: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisRefWork {return &getOsisModName(shift);}
sub getOsisIDWork {return &getOsisModName(shift);}
sub getOsisBooks {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisBooks', $mod);
  if (!$return) {
    &ErrorBug("getOsisBooks: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisScope {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisScope', $mod);
  if (!$return) {
    &ErrorBug("getOsisScope: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub isChildrensBible {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Book\.\w+CB$/ ? 1:0);
}
sub isBible {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Bible/ ? 1:0);
}
sub isDict {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Dict/ ? 1:0);
}

sub getModuleOutputDir {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  
  if ($OUTDIR && ! -d $OUTDIR) {
    $OUTDIR = undef;
    &Error("OUTDIR is not an existing directory.", 
"OUTDIR has been set to a non-existent directory in:\n" . &findConf('OUTDIR') . "\n" .
"Change it to the path of a directory where output files can be written.");
  }
  
  my $moddir;
  if ($OUTDIR) {$moddir = "$OUTDIR/$mod";}
  else {
    my $parentDir = "$MAININPD/..";
    if ($mod =~ /^(.*?)DICT$/) {$moddir = "$parentDir/$1/$mod/output";}
    else {$moddir = "$parentDir/$mod/output";}
  }

  return $moddir;
}

# Returns the path to mod's OSIS file if it exists, or, when reportFunc 
# is 'quiet' (whether the OSIS file exists or not). Otherwise returns ''.
sub getModuleOsisFile {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  my $reportFunc = shift;
  
  my $mof = &getModuleOutputDir($mod)."/$mod.xml";
  if ($reportFunc eq 'quiet' || -e $mof) {return $mof;}
  
  if ($reportFunc) {
    no strict "refs";
    &$reportFunc("$mod OSIS file does not exist: $mof");
  }
  return '';
}

# Sometimes source texts use reference type="annotateRef" to reference
# verses which were not included in the source text. When an annotateRef
# target does not exist, the reference tags are replaced by a span.
sub adjustAnnotateRefs {
  my $osisP = shift;

  &Log("\nChecking annotateRef targets in \"$$osisP\".\n");
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my $osisIDsP = &getVerseOsisIDs($xml);
  
  my $update;
  foreach my $reference (@{$XPC->findnodes('//osis:reference[@type="annotateRef"][@osisRef]', $xml)}) {
    my $remove;
    foreach my $r (split(/\s+/, &osisRef2osisID($reference->getAttribute('osisRef')))) {
      if (!$osisIDsP->{$r}) {$remove++; $update++; last;}
    }
    if ($remove) {
      my $new = $XML_PARSER->parse_balanced_chunk('<hi type="bold">'.$reference->textContent.'</hi>');
      $reference->parentNode->insertAfter($new, $reference);
      $reference->unbindNode();
      &Warn("Removing annotateRef hyperlink to missing verse(s): '".$reference->getAttribute('osisRef')."'",
      "This can happen when the source text has annotateRef references 
targeting purposefully missing verses for instance. In such cases it is
correct to convert these to textual rather than hyperlink references.");
    }
  }

  if ($update) {
    &writeXMLFile($xml, $osisP);
  }
}

sub checkRefs {
  my $osis = shift;
  my $isDict = shift;
  my $prep_xslt = shift;
  
  my $t = ($prep_xslt =~ /fitted/i ? ' FITTED':($prep_xslt =~ /source/i ? ' SOURCE':' '));
  &Log("CHECKING$t OSISREF/OSISIDS IN OSIS: $osis\n");
  
  my $main = ($isDict ? &getModuleOsisFile($MAINMOD):$osis);
  my $dict = ($isDict ? $osis:'');
  
  if ($prep_xslt) {
    &runScript("$SCRD/scripts/$prep_xslt", \$main, '', 3);
    if ($dict) {
      &runScript("$SCRD/scripts/$prep_xslt", \$dict, '', 3);
    }
  }
  
  my %params = ( 
    'MAINMOD_URI' => $main, 
    'DICTMOD_URI' => $dict, 
    'versification' => ($prep_xslt !~ /source/i ? &conf('Versification'):'')
  );
  my $result = &runXSLT("$SCRD/scripts/checkrefs.xsl", ($isDict ? $dict:$main), '', \%params, 3);
  
  &Log($result."\n");
}

# Check all Scripture reference links in the source text. This does not
# look for or check any externally supplied cross-references. This check
# is run before fitToVerseSystem(), so it is checking that the source
# text's references are consistent with itself. Any broken links found
# here are either mis-parsed, or are errors in the source text.
sub checkMarkSourceScripRefLinks {
  my $in_osis = shift;
  
  if (&conf("ARG_SkipSourceRefCheck") =~/^true$/i) {
    &Note("Source references will not be checked because ARG_SkipSourceRefCheck=true");
    return
  }
  
  &Log("\nCHECKING SOURCE SCRIPTURE REFERENCE OSISREF TARGETS IN $in_osis...\n");
  
  my $changes = 0; my $problems = 0; my $checked = 0;
  
  my $in_bible = ($INPD eq $MAININPD ? $in_osis:'');
  if (!$in_bible) {
    # The Bible OSIS needs to be put into the source verse system for this check
    $in_bible = "$TMPDIR/$MAINMOD.xml";
    &copy(&getModuleOsisFile($MAINMOD, 'Error'), $in_bible);
    &runScript("$SCRD/scripts/osis2sourceVerseSystem.xsl", \$in_bible);
  }
  
  my $osis;
  if (-e $in_bible) {
    my $bible = $XML_PARSER->parse_file($in_bible);
    # Get all books found in the Bible
    my %bks;
    foreach my $bk ($XPC->findnodes('//osis:div[@type="book"]', $bible)) {
      $bks{$bk->getAttribute('osisID')}++;
    }
    # Get all chapter and verse osisIDs
    my %ids;
    foreach my $v ($XPC->findnodes('//osis:verse[@osisID] | //osis:chapter[@osisID]', $bible)) {
      foreach my $id (split(/\s+/, $v->getAttribute('osisID'))) {$ids{"$MAINMOD:$id"}++;}
    }
    
    # Check Scripture references in the original text (not those added by addCrossRefs)
    $osis = $XML_PARSER->parse_file($in_osis);
    foreach my $sref ($XPC->findnodes('//osis:reference[not(starts-with(@type, "x-gloss"))][not(ancestor::osis:note[@resp])][@osisRef]', $osis)) {
      $checked++;
      # check beginning and end of range, but not each verse of range (since verses within the range may be purposefully missing)
      my $oref = $sref->getAttribute('osisRef');
      foreach my $id (split(/\-/, $oref)) {
        $id = ($id =~ /\:/ ? $id:"$MAINMOD:$id");
        my $bk = ($id =~ /\:([^\.]+)/ ? $1:'');
        if (!$bk) {
          &ErrorBug("Failed to parse reference from book: $id !~ /\:([^\.]+)/ in $sref.");
        }
        elsif (!$bks{$bk}) {
          &Warn("<>Marking hyperlinks to missing book: $bk", 
"<>Apparently not all 66 Bible books have been included in this 
project, but there are references in the source text to these missing 
books. So these hyperlinks will be marked as x-external until the 
other books are added to the translation.");
          if ($sref->getAttribute('subType') && $sref->getAttribute('subType') ne 'x-external') {
            &ErrorBug("Overwriting subType ".$sref->getAttribute('subType')." with x-external in $sref");
          }
          $sref->setAttribute('subType', 'x-external');
          $changes++;
        }
        elsif (!$ids{$id}) {
          $problems++;
          &Error(
"Scripture reference in source text targets a nonexistant verse: \"$id\"", 
"Maybe this should not have been parsed as a Scripture 
reference, or maybe it was mis-parsed by CF_addScripRefLinks.txt? Or 
else this is a problem with the source text: 
".$sref);
        }
      }
    }
  }
  else {
    $problems++;
    &Error("Cannot check Scripture reference targets because unable to locate $MAINMOD.xml.", "Run sfm2osis.pl on $MAINMOD to generate an OSIS file.");
  }
  
  if ($osis && $changes) {&writeXMLFile($osis, $in_osis);}
  
  &Report("$checked Scripture references checked. ($problems problems)\n");
}

sub removeMissingOsisRefs {
  my $osisP = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @badrefs = $XPC->findnodes('//osis:reference[not(@osisRef)]', $xml);
  if (!@badrefs[0]) {return;}
  
  &Error("There are ".@badrefs." reference element(s) without osisRef attributes. These reference tags will be removed!", 
"Make sure SET_addScripRefLinks is set to 'true' in CF_usfm2osis.txt, so that reference osisRefs will be parsed.");
  
  foreach my $r (@badrefs) {
    my @children = $r->childNodes();
    foreach my $child (@children) {$r->parentNode->insertBefore($child, $r);}
    $r->unbindNode();
  }
  
  &writeXMLFile($xml, $osisP);
}

sub reportReferences {
  my $refcntP = shift;
  my $errorsP = shift;
  
  my $total = 0; my $errtot = 0;
  foreach my $type (sort keys (%{$refcntP})) {
    &Report("<-\"".$refcntP->{$type}."\" ${type}s checked. (".($errorsP->{$type} ? $errorsP->{$type}:0)." problems)");
    $total += $refcntP->{$type}; $errtot += $errorsP->{$type};
  }
  &Report("<-\"$total\" Grand total osisRefs checked. (".($errtot ? $errtot:0)." problems)");
}

sub checkIntroductionTags {
  my $inosis = shift;

  my $parser = XML::LibXML->new('line_numbers' => 1);
  my $xml = $parser->parse_file($inosis);
  my @warnTags = $XPC->findnodes('//osis:div[@type="majorSection"][not(ancestor::osis:div[@type="book"])]', $xml);
  #my @warnTags = $XPC->findnodes('//osis:title[not(ancestor-or-self::*[@subType="x-introduction"])][not(parent::osis:div[contains(@type, "ection")])]', $xml);
  foreach my $t (@warnTags) {
    my $tag = $t;
    $tag =~ s/^[^<]*?(<[^>]*?>).*$/$1/s;
    &Error("The non-introduction tag on line: ".$t->line_number().", \"$tag\" was used in an introduction. This could trigger a bug in osis2mod.cpp, dropping introduction text.", 'Replace this tag with the proper \imt introduction title tag.');
  }
}

sub checkCharacters {
  my $osis = shift;
  
  open(OSIS, $READLAYER, $osis) || die;
  my %characters;
  while(<OSIS>) {
    foreach my $c (split(/(\X)/, $_)) {if ($c =~ /^[\n ]$/) {next;} $characters{$c}++;}
  }
  close(OSIS);
  
  my $numchars = keys %characters; my $chars = ''; my %composed;
  foreach my $c (sort { ord($a) <=> ord($b) } keys %characters) {
    my $n=0; foreach my $chr (split(//, $c)) {$n++;}
    if ($n > 1) {$composed{$c} = $characters{$c};}
    $chars .= $c;
  }
  &Report("Characters used in OSIS file:\n$chars($numchars chars)");
  
  # Report composed characters
  my @comp; foreach my $c (sort { 
      ($composed{$b} <=> $composed{$a} ? $composed{$b} <=> $composed{$a} : $a cmp $b)
    } keys %composed) {
    push(@comp, "$c(".$composed{$c}.')');
  }
  &Report("<-Extended grapheme clusters used in OSIS file: ".(@comp ? join(' ', @comp):'none'));
  
  # Report rarely used characters
  my $rc = 20;
  my @rare; foreach my $c (
    sort { ( !($characters{$a} <=> $characters{$b}) ? 
             ord($a) <=> ord($b) :
             $characters{$a} <=> $characters{$b} ) 
         } keys %characters) {
    if ($characters{$c} >= $rc) {next;}
    push(@rare, $c);
  }
  &Report("<-Characters occuring fewer than $rc times in OSIS file (least first): ".(@rare ? join(' ', @rare):'none'));
  
  # Check for high order Unicode character replacements needed for GoBible/simpleChars.txt
  my %allChars; for my $c (split(//, $chars)) {$allChars{$c}++;}
  my @from; my @to; &readReplacementChars(&getDefaultFile("bible/GoBible/simpleChars.txt"), \@from, \@to);
  foreach my $chr (sort { ord($a) <=> ord($b) } keys %allChars) {
    if (ord($chr) <= $MAX_UNICODE) {next;}
    my $x; for ($x=0; $x<@from; $x++) {
      if (@from[$x] eq $chr) {&Note("High Unicode character found ( > $MAX_UNICODE): ".ord($chr)." '$chr' <> '".@to[$x]."'"); last;}
    }
    if (@from[$x] ne $chr) {
      &Note("High Unicode character found ( > $MAX_UNICODE): ".ord($chr)." '$chr' <> no-replacement");
      &Warn("<-There is no simpleChars.txt replacement for the high Unicode character: '$chr'", 
      "This character, and its low order replacement, may be added to: $SCRIPT/defaults/bible/GoBible/simpleChars.txt to remove this warning.");
    }
  }
}

sub readReplacementChars {
  my $replacementsFile = shift;
  my $fromAP = shift;
  my $toAP = shift;

  if (open(INF, $READLAYER, $replacementsFile)) {
    while(<INF>) {
      if ($fromAP && $_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$fromAP}, substr($chars, $i, 1));
        }
      }
      if ($toAP && $_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$toAP}, substr($chars, $i, 1));
        }
      }
      if ($fromAP && $_ =~ /Replace-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$fromAP}, $chars);
      }
      if ($toAP && $_ =~ /With-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$toAP}, $chars);
      }
    }
    close(INF);
  }
}

# copies a directoryʻs contents to a possibly non existing destination directory
sub copy_dir {
  my $id = shift;
  my $od = shift;
  my $overwrite = shift; # merge with existing directories and overwrite existing files
  my $noRecurse = shift; # don't recurse into subdirs
  my $keep = shift; # a regular expression matching files to be copied (null means copy all)
  my $skip = shift; # a regular expression matching files to be skipped (null means skip none). $skip overrules $keep

  if (!-e $id || !-d $id) {
    &Error("copy_dir: Source does not exist or is not a direcory: $id");
    return 0;
  }
  if (!$overwrite && -e $od) {
    &Error("copy_dir: Destination already exists: $od");
    return 0;
  }
 
  opendir(DIR, $id) || die "Could not open dir $id\n";
  my @fs = readdir(DIR);
  closedir(DIR);
  make_path($od);

  for(my $i=0; $i < @fs; $i++) {
    if ($fs[$i] =~ /^\.+$/) {next;}
    my $if = "$id/".$fs[$i];
    my $of = "$od/".$fs[$i];
    if (!$noRecurse && -d $if) {&copy_dir($if, $of, $overwrite, $noRecurse, $keep, $skip);}
    elsif ($skip && $if =~ /$skip/) {next;}
    elsif (!$keep || $if =~ /$keep/) {
			if ($overwrite && -e $of) {unlink($of);}
			copy($if, $of);
		}
  }
  return 1;
}


# Copies files from each default directory, starting with lowest to 
# highest priority, and merging files each time.
sub copy_dir_with_defaults {
  my $dir = shift;
  my $dest = shift;
  my $keep = shift;
  my $skip = shift;
  
  my $isDefaultDest; # not sure what this is - 'use strict' caught it
  
  for (my $x=3; $x>=($isDefaultDest ? 2:1); $x--) {
    my $defDir = &getDefaultFile($dir, $x);
    if (!$defDir) {next;}
    # Never copy a directory over itself
    my ($dev1, $ino1) = stat $defDir;
    my ($dev2, $ino2) = stat $dest;
    if ($dev1 eq $dev2 && $ino1 eq $ino2) {next;}
    &copy_dir($defDir, $dest, 1, 0, $keep, $skip);
  }
}


# deletes files recursively without touching dirs
sub delete_files {
  my $dir = shift;

  my $success = 0;
  if (!opendir(CHDIR, $dir)) {return 0;}
  my @listing = readdir(CHDIR);
  closedir(CHDIR);
  foreach my $entry (@listing) {
    if ($entry =~ /^\.+$/) {next;}
    if (-d "$dir/$entry") {$success &= delete_files("$dir/$entry");}
    unlink("$dir/$entry");
  }
  
  return $success;
}


sub fromUTF8 {
  my $c = shift;

  $c = decode("utf8", $c);
  utf8::upgrade($c);
  return $c;
}


sub is_usfm2osis {
  my $osis = shift;

  my $usfm2osis = 0;
  if (!open(TEST, $READLAYER, "$osis")) {&Error("is_usfm2osis could not open $osis", '', 1);}
  while(<TEST>) {if ($_ =~ /<!--[^!]*\busfm2osis.py\b/) {$usfm2osis = 1; last;}}
  close(TEST);
  if ($usfm2osis) {&Log("\n--- OSIS file was created by usfm2osis.py.\n");}
  return $usfm2osis;
}

# Runs an XSLT and/or a Perl script if they have been placed at the
# appropriate input project path by the user. This allows a project to 
# apply custom scripts if needed.
sub runAnyUserScriptsAt {
  my $pathNoExt = "$INPD/".shift; # path to script, but without extension
  my $sourceP = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  if (-e "$pathNoExt.xsl") {
    &Note("Running user XSLT: $pathNoExt.xsl");
    &runScript("$pathNoExt.xsl", $sourceP, $paramsP, $logFlag);
  }
  else {&Note("No user XSLT to run at $pathNoExt.xsl");}
  
  if (-e "$pathNoExt.pl") {
    &Note("Running user Perl script: $pathNoExt.pl");
    &runScript("$pathNoExt.pl", $sourceP, $paramsP, $logFlag);
  }
  else {&Note("No user Perl script to run at $pathNoExt.pl");}
}

# Runs a script according to its type (its extension). The inputP points
# to the input file. If overwrite is set, the input file is overwritten,
# otherwise the output file has the name of the script which created it.
# Upon sucessfull completion, inputP will be updated to point to the 
# newly created output file.
sub runScript {
  my $script = shift;
  my $inputP = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  my $overwrite = shift;
  
  my $name = $script; 
  my $ext;
  if ($name =~ s/^.*?\/([^\/]+)\.([^\.\/]+)$/$1/) {$ext = $2;}
  else {
    &ErrorBug("runScript: Bad script name \"$script\"!");
    return 0;
  }
  
  if (! -e $script) {
    &ErrorBug("runScript: Script not found \"$script\"!");
  }
  
  my $output = &temporaryFile($$inputP, $name);

  my $result;
  if ($ext eq 'xsl')   {$result = &runXSLT($script, $$inputP, $output, $paramsP, $logFlag);}
  elsif ($ext eq 'pl') {$result = &runPerl($script, $$inputP, $output, $paramsP, $logFlag);}
  else {
    &ErrorBug("runScript: Unsupported script extension \"$script\".\n$result", 1);
    return 0;
  }
  
  if (-z $output) {
    &ErrorBug("runScript: Output file $output has 0 size.\n$result", 1);
    return 0;
  }
  elsif ($overwrite) {&copy($output, $$inputP);}
  else {$$inputP = $output;} # change inputP to pass output file name back
  
  return ($result ? $result:1);
}

sub runPerl {
  my $script = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  # Perl scripts need to have the following arguments
  # script-name input-file output-file [key1=value1] [key2=value2]...
  my @args = (&escfile($script), &escfile($source), &escfile($output));
  map(push(@args, &escfile("$_=".$paramsP->{$_})), sort keys %{$paramsP});
  
  return &shell(join(' ', @args), $logFlag);
}

sub runXSLT {
  my $xsl = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  my $cmd = "saxonb-xslt -l -ext:on";
  $cmd .= " -xsl:" . &escfile($xsl) ;
  $cmd .= " -s:" . &escfile($source);
  if ($output) {
    $cmd .= " -o:" . &escfile($output);
  }
  if ($paramsP) {
    foreach my $p (sort keys %{$paramsP}) {
      my $v = $paramsP->{$p};
      $v =~ s/(["\\])/\\$1/g; # escape quote since below passes with quote
      $cmd .= " $p=\"$v\"";
    }
  }
  $cmd .= " DEBUG=\"$DEBUG\" DICTMOD=\"$DICTMOD\" SCRIPT_NAME=\"$SCRIPT_NAME\" TMPDIR=\"$MOD_OUTDIR/tmp\"";
  
  return &shell($cmd, $logFlag);
}


my $ProgressTotal = 0;
my $ProgressTime = 0;
sub logProgress {
  my $msg = shift;
  my $ln = shift;
  
  my $t = time;
  my $tleft = 0;
  if ($ln == -1) {
      $ProgressTime = time;
      $ProgressTotal = 0;
      copy($msg, "$msg.progress.tmp");
      if (open(PRGF, $READLAYER, "$msg.progress.tmp")) {
        while(<PRGF>) {$ProgressTotal++;}
        close(PRGF);
      }
      unlink("$msg.progress.tmp");
      return;
  }
  elsif ($ln) {$tleft = ((($t-$ProgressTime)/$ln)*($ProgressTotal-$ln));}

  &Log("-> $msg", 2);
  if ($tleft) {&Log(sprintf(" (eta: %dmin %dsec)\n", ($tleft/60), ($tleft%60)), 2);}
  else {&Log("\n", 2);}
}


# make a zipped copy of a module
sub zipModule {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  chdir($moddir);
  my $result = &shell($cmd, 3); # capture result so that output lines can be sorted before logging
  chdir($SCRD);
  &Log("$cmd\n", 1); my @lines = split("\n", $result); $result = join("\n", sort @lines); &Log($result, 1);
}


# I could not find a way to get XML::LibXML::DocumentFragment->toString()
# to STOP converting high-order unicode characters to entities when 
# serializing attributes. But regular documents, with proper declarations, 
# don't have this problem. So here is a solution.
sub fragmentToString {
  my $doc_frag = shift;
  my $rootTag = shift;
  
  my $rootTagName = $rootTag;
  if ($rootTagName !~ s/^\s*<(\w+).*$/$1/) {&ErrorBug("fragmentToString bad rootTagName: $rootTagName !~ s/^\s*<(\w+).*\$/\$1/");}
  
  my $dom = XML::LibXML::Document->new("1.0", "UTF-8");
  $dom->insertBefore($doc_frag, undef);
  my $doc = $dom->toString();
  
  # remove xml declaration
  if ($doc !~ s/^\s*<\?xml[^>]*\?>[\s\n]*//) {&ErrorBug("fragmentToString problem removing xml declaration: $doc !~ s/^\s*<\?xml[^>]*\?>[\s\n]*//");}
  
  # remove root tags
  if ($doc !~ s/(^$rootTag|<\/$rootTagName>[\s\n]*$)//g) {&ErrorBug("fragmentToString problem removing root tags: $doc !~ s/(^$rootTag|<\/$rootTagName>[\s\n]*\$)//g");} 
  
  return $doc;
}


# Deletes existing header work elements, and writes new ones which
# include, as meta-data, all settings from config.conf. The osis file is 
# overwritten if $osis_or_osisP is not a reference, otherwise a new 
# output file is written and the reference is updated to point to it.
sub writeOsisHeader {
  my $osis_or_osisP = shift;
  
  my $osis = (ref($osis_or_osisP) ? $$osis_or_osisP:$osis_or_osisP); 
  
  &Log("\nWriting work and companion work elements in OSIS header:\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # Both osisIDWork and osisRefWork defaults are set to the current work.
  my @uds = ('osisRefWork', 'osisIDWork');
  foreach my $ud (@uds) {
    my @orw = $XPC->findnodes('/osis:osis/osis:osisText[@'.$ud.']', $xml);
    if (!@orw || @orw > 1) {&ErrorBug("The osisText element's $ud is not being updated to \"$MOD\"");}
    else {
      &Log("Updated $ud=\"$MOD\"\n");
      @orw[0]->setAttribute($ud, $MOD);
    }
  }
  
  # Remove any work elements
  foreach my $we (@{$XPC->findnodes('//*[local-name()="work"]', $xml)}) {
    $we->unbindNode();
  }
  
  my $header;
    
  # Add work element for MAINMOD
  my %workElements;
  &getOSIS_Work($MAINMOD, \%workElements, &searchForISBN($MAINMOD, ($MOD eq $MAINMOD ? $xml:'')));
  # CAUTION: The workElements indexes must correlate to their assignment in getOSIS_Work()
  if ($workElements{'100000:type'}{'textContent'} eq 'Bible') {
    $workElements{'190000:scope'}{'textContent'} = &getScope($osis, &conf('Versification'));
  }
  for (my $x=0; $x<@SUB_PUBLICATIONS; $x++) {
    my $n = 59000;
    $workElements{sprintf("%06i:%s", ($n+$x), 'description')}{'textContent'} = @SUB_PUBLICATIONS[$x];
    $workElements{sprintf("%06i:%s", ($n+$x), 'description')}{'type'} = "x-array-$x-SubPublication";
  }
  my %workAttributes = ('osisWork' => $MAINMOD);
  $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  
  # Add work element for DICTMOD
  if ($DICTMOD) {
    my %workElements;
    &getOSIS_Work($DICTMOD, \%workElements, &searchForISBN($DICTMOD, ($MOD eq $DICTMOD ? $xml:'')));
    my %workAttributes = ('osisWork' => $DICTMOD);
    $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  }
  
  &writeXMLFile($xml, $osis_or_osisP);
  
  return $header;
}

# Search for any ISBN number(s) in the osis file or config.conf.
sub searchForISBN {
  my $mod = shift;
  my $xml = shift;
  
  my %isbns; my $isbn;
  my @checktxt = ($xml ? $XPC->findnodes('//text()', $xml):());
  my @checkconfs = ('About', 'Description', 'ShortPromo', 'TextSource', 'LCSH');
  foreach my $cc (@checkconfs) {push(@checktxt, &conf($cc, $mod));}
  foreach my $tn (@checktxt) {
    if ($tn =~ /\bisbn (number|\#|no\.?)?([\d\-]+)/i) {
      $isbn = $2;
      $isbns{$isbn}++;
    }
  }
  return join(', ', sort keys %isbns);
}

# Write all work children elements for modname to osisWorkP. The modname 
# must be either the value of $MAINMOD or $DICTMOD. In addition to
# writing the standard OSIS work elements, most of the config.conf is 
# also written as description elements, and these config.conf entries
# are written as follows:
# - Config entries which are particular to DICT are written to the 
#   DICT work element. All others are written to the MAIN work element. 
# - Description type attributes contain the section+entry EXCEPT when
#   section is DICT or MAIN (since this is defined by the word element). 
# IMPORTANT: Retreiving the usual context specific config.conf value from 
# header data requires searching both MAIN and DICT work elements. 
sub getOSIS_Work {
  my $modname = shift; 
  my $osisWorkP = shift;
  my $isbn = shift;
 
  my @tm = localtime(time);
  my %type;
  if    (&conf('ModDrv', $modname) =~ /LD/)   {$type{'type'} = 'x-glossary'; $type{'textContent'} = 'Glossary';}
  elsif (&conf('ModDrv', $modname) =~ /Text/) {$type{'type'} = 'x-bible'; $type{'textContent'} = 'Bible';}
  elsif (&conf('ModDrv', $modname) =~ /GenBook/ && $MOD =~ /CB$/i) {$type{'type'} = 'x-childrens-bible'; $type{'textContent'} = 'Children\'s Bible';}
  elsif (&conf('ModDrv', $modname) =~ /Com/) {$type{'type'} = 'x-commentary'; $type{'textContent'} = 'Commentary';}
  my $idf = ($type{'type'} eq 'x-glossary' ? 'Dict':($type{'type'} eq 'x-childrens-bible' ? 'GenBook':($type{'type'} eq 'x-commentary' ? 'Comm':'Bible')));
  my $refSystem = "Bible.".&conf('Versification');
  if ($type{'type'} eq 'x-glossary') {$refSystem = "Dict.$DICTMOD";}
  if ($type{'type'} eq 'x-childrens-bible') {$refSystem = "Book.$modname";}
  my $isbnID = $isbn;
  $isbnID =~ s/[\- ]//g;
  foreach my $n (split(/,/, $isbnID)) {if ($n && length($n) != 13 && length($n) != 10) {
    &Error("ISBN number \"$n\" is not 10 or 13 digits", "Check that the ISBN number is correct.");
  }}
  
  # write OSIS Work elements:
  # element order seems to be important for passing OSIS schema validation for some reason (hence the ordinal prefix)
  $osisWorkP->{'000000:title'}{'textContent'} = ($modname eq $DICTMOD ? &conf('CombinedGlossaryTitle'):&conf('TranslationTitle'));
  &mapLocalizedElem(30000, 'subject', 'Description', $osisWorkP, $modname, 1);
  $osisWorkP->{'040000:date'}{'textContent'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  $osisWorkP->{'040000:date'}{'event'} = 'eversion';
  &mapLocalizedElem(50000, 'description', 'About', $osisWorkP, $modname, 1);
  &mapConfig(50008, 58999, 'description', 'x-config', $osisWorkP, $modname);
  &mapLocalizedElem(60000, 'publisher', 'CopyrightHolder', $osisWorkP, $modname);
  &mapLocalizedElem(70000, 'publisher', 'CopyrightContactAddress', $osisWorkP, $modname);
  &mapLocalizedElem(80000, 'publisher', 'CopyrightContactEmail', $osisWorkP, $modname);
  &mapLocalizedElem(90000, 'publisher', 'ShortPromo', $osisWorkP, $modname);
  $osisWorkP->{'100000:type'} = \%type;
  $osisWorkP->{'110000:format'}{'textContent'} = 'text/xml';
  $osisWorkP->{'110000:format'}{'type'} = 'x-MIME';
  $osisWorkP->{'120000:identifier'}{'textContent'} = $isbnID;
  $osisWorkP->{'120000:identifier'}{'type'} = 'ISBN';
  $osisWorkP->{'121000:identifier'}{'textContent'} = "$idf.$modname";
  $osisWorkP->{'121000:identifier'}{'type'} = 'OSIS';
  if ($isbn) {$osisWorkP->{'130000:source'}{'textContent'} = "ISBN: $isbn";}
  $osisWorkP->{'140000:language'}{'textContent'} = (&conf('Lang') =~ /^([A-Za-z]+)/ ? $1:&conf('Lang'));
  &mapLocalizedElem(170000, 'rights', 'Copyright', $osisWorkP, $modname);
  &mapLocalizedElem(180000, 'rights', 'DistributionNotes', $osisWorkP, $modname);
  $osisWorkP->{'220000:refSystem'}{'textContent'} = $refSystem;

# From OSIS spec, valid work elements are:
#    '000000:title' => '',
#    '010000:contributor' => '',
#    '020000:creator' => '',
#    '030000+:subject' => '',
#    '040000:date' => '',
#    '050000+:description' => '',
#    '060000-090000+:publisher' => '',
#    '100000:type' => '',
#    '110000:format' => '',
#    '120000-121000:identifier' => '',
#    '130000:source' => '',
#    '140000:language' => '',
#    '150000:relation' => '',
#    '160000:coverage' => '',
#    '170000-180000+:rights' => '',
#    '190000:scope' => '',
#    '200000:castList' => '',
#    '210000:teiHeader' => '',
#    '220000:refSystem' => ''
  
  return;
}

sub mapLocalizedElem {
  my $index = shift;
  my $workElement = shift;
  my $entry = shift;
  my $osisWorkP = shift;
  my $mod = shift;
  my $skipTypeAttribute = shift;
  
  foreach my $k (sort {$a cmp $b} keys %{$CONF}) {
    if ($k !~ /^([^\+]+)\+$entry(_([\w\-]+))?$/) {next;}
    my $s = $1;
    my $lang = ($2 ? $3:'');
    if ($mod eq $MAINMOD && $s eq $DICTMOD) {next;}
    elsif ($mod eq $DICTMOD && $s eq $MAINMOD && $CONF->{"$DICTMOD+$entry"}) {next;}
    $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'textContent'} = $CONF->{$k};
    if (!$skipTypeAttribute) {$osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'type'} = "x-$entry";}
    if ($lang) {
      $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'xml:lang'} = $lang;
    }
    $index++;
    if (($index % 10) == 6) {&ErrorBug("mapLocalizedConf: Too many \"$workElement\" language variants.");}
  }
}

sub mapConfig {
  my $index = shift;
  my $maxindex = shift;
  my $elementName = shift;
  my $prefix = shift;
  my $osisWorkP = shift;
  my $modname = shift;
  
  foreach my $fullEntry (sort keys %{$CONF}) {
    if ($index > $maxindex) {&ErrorBug("mapConfig: Too many \"$elementName\" $prefix entries.");}
    elsif ($modname && $fullEntry =~ /DICT\+/ && $modname ne $DICTMOD) {next;}
    elsif ($modname && $fullEntry !~ /DICT\+/ && $modname eq $DICTMOD) {next;}
    elsif ($fullEntry =~ /Title$/ && $CONF->{$fullEntry} =~ / DEF$/) {next;}
    elsif ($fullEntry eq 'system+OUTDIR') {next;}
    else {
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'textContent'} = $CONF->{$fullEntry};
      $fullEntry =~ s/[^\-]+DICT\+//;
      my $xmlEntry = $fullEntry; $xmlEntry =~ s/^$MAINMOD\+//;
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'type'} = "$prefix-$xmlEntry";
      $index++;
    }
  }
}

sub writeWorkElement {
  my $attributesP = shift;
  my $elementsP = shift;
  my $xml = shift;
  
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  $header->appendTextNode("\n");
  my $work = $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work></work>"), undef);
  
  # If an element would have no textContent, the element is not written
  foreach my $a (sort keys %{$attributesP}) {$work->setAttribute($a, $attributesP->{$a});}
  foreach my $e (sort keys %{$elementsP}) {
    if (!exists($elementsP->{$e}{'textContent'})) {next;}
    $work->appendTextNode("\n  ");
    my $er = $e;
    $er =~ s/^\d+\://;
    my $elem = $work->insertAfter($XML_PARSER->parse_balanced_chunk("<$er></$er>"), undef);
    foreach my $a (sort keys %{$elementsP->{$e}}) {
      if ($a eq 'textContent') {$elem->appendTextNode($elementsP->{$e}{$a});}
      else {$elem->setAttribute($a, $elementsP->{$e}{$a});}
    }
  }
  $work->appendTextNode("\n");
  $header->appendTextNode("\n");
  
  my $w = $work->toString(); 
  $w =~ s/\n+/\n/g;
  return $w;
}

sub getDivTitle {
  my $glossdiv = shift;
  
  my $telem = @{$XPC->findnodes('(descendant::osis:title[@type="main"][1] | descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n)[1]', $glossdiv)}[0];
  if (!$telem) {return '';}
  
  my $title = $telem->textContent();
  $title =~ s/^(\[[^\]]*\])+//g;
  return $title;
}

sub oc_stringHash {
  my $s = shift;

  use Digest::MD5 qw(md5 md5_hex md5_base64);
  return substr(md5_hex(encode('utf8', $s)), 0, 4);
}


# Check for TOC entries, and write as much TOC information as possible
my $WRITETOC_MSG;
sub writeTOC {
  my $osisP = shift;
  my $modType = shift;

  &Log("\nChecking Table Of Content tags (these tags dictate the TOC of eBooks)...\n");
  
  my $toc = &conf('TOC');
  &Note("Using \"\\toc$toc\" USFM tags to determine eBook TOC.");
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @tocTags = $XPC->findnodes('//osis:milestone[@n][starts-with(@type, "x-usfm-toc")]', $xml);
  
  if (@tocTags) {
    &Note("Found ".scalar(@tocTags)." table of content milestone tags:");
    foreach my $t (@tocTags) {
      &Log($t->toString()."\n");
    }
  }
  
  if ($modType eq 'bible') {
    # Insure there are as many possible x-usfm-tocN entries for each book,
    # and add book introduction TOC entries where needed.
    my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
    foreach my $bk (@bks) {
      my $osisID = $bk->getAttribute('osisID');
      for (my $t=1; $t<=3; $t++) {
        # Is there a TOC entry if this type? If not, add one if we know what it should be
        my @e = $XPC->findnodes('./osis:milestone[@n][@type="x-usfm-toc'.$t.'"] | ./*[1][self::osis:div]/osis:milestone[@n][@type="x-usfm-toc'.$t.'"]', $bk);
        if (@e && @e[0]) {next;}
        
        if ($t eq $toc && !$WRITETOC_MSG) {
          &Warn("At least one book ($osisID) is missing a \\toc$toc SFM tag. 
These \\toc tags are used to generate the eBook table of contents. When 
possible, such tags will be automatically inserted.",
"That your eBook TOCs render with proper book names and/or 
hierarchy. If not then you can add \\toc$toc tags to the SFM using 
EVAL_REGEX. Or, if you wish to use a different \\toc tag, you must add 
a TOC=N config setting to: $MOD/config.conf (where N is the \\toc 
tag number you wish to use.)\n");
          $WRITETOC_MSG++;
        }
        
        my $name;
        my $type;
        
        # Try and get the book name from BookNames.xml
        if (%BOOKNAMES) {
          my @attrib = ('', 'long', 'short', 'abbr');
          $name = $BOOKNAMES{$osisID}{@attrib[$t]};
          if ($name) {$type = @attrib[$t];}
        }
        
        # Otherwise try and get the default TOC from the first applicable title
        if (!$name && $t eq $toc) {
          my @title = $XPC->findnodes('./osis:title[@type="runningHead"]', $bk);
          if (!@title || !@title[0]) {
            @title = $XPC->findnodes('./osis:title[@type="main"]', $bk);
          }
          if (!@title || !@title[0]) {
            $name = $osisID;
            $type = "osisID";
            &Error("writeTOC: Could not locate book name for \"$name\" in OSIS file.");
          }
          else {$name = @title[0]->textContent; $type = 'title';}
        }
        
        if ($name) {
          my $tag = "<milestone type=\"x-usfm-toc$t\" n=\"$name\" resp=\"$ROC\"/>";
          &Note("Inserting $osisID book $type TOC entry as: $name");
          $bk->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $bk->firstChild);
        }
      }
      
      # Add book introduction TOC if needed
      my $bookIntroTOC = @{$XPC->findnodes(
        'descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][2]
        [following::osis:chapter[@osisID="'.$osisID.'.1"]]', $bk)}[0];
      if (!$bookIntroTOC) {
        my $firstIntroTitle = @{$XPC->findnodes(
          'descendant::osis:title[@type="main"][@subType="x-introduction"][1]', $bk)}[0];
        if ($firstIntroTitle) {
          my $title = &conf('IntroductionTitle', undef, undef, undef, 1);
          if ($title =~ /DEF$/) {$title = $firstIntroTitle->textContent;}
          &Note("Inserting $osisID book introduction TOC entry as: $title");
          # Add a special osisID since these book intros may all share the same title
          my $toc = $XML_PARSER->parse_balanced_chunk("
<milestone type='x-usfm-toc".&conf('TOC')."' n='[not_parent]$title' osisID='introduction_$osisID!toc' resp='$ROC'/>");
          $firstIntroTitle->parentNode->insertBefore($toc, $firstIntroTitle);
        }
      }
    }
    
    # Add translation main TOC entry if not there already
    my $mainTOC = @{$XPC->findnodes('//osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]
      [not(ancestor::osis:div[starts-with(@type, "book")])]
      [not(preceding::osis:div[starts-with(@type, "book")])][1]', $xml)}[0];
    if (!$mainTOC) {
      my $translationTitle = &conf('TranslationTitle');
      my $toc = $XML_PARSER->parse_balanced_chunk('
<div type="introduction" resp="'.$ROC.'">
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1][not_parent]'.$translationTitle.'"/>
</div>');
      my $insertBefore = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[not(self::osis:div[@type="x-cover"])][1]', $xml)}[0];
      if ($insertBefore) {
        $insertBefore->parentNode->insertBefore($toc, $insertBefore);
        &Note("Inserting top TOC entry and title within new introduction div as: $translationTitle");
      }
      else {&Error("No elements follow header");}
    }
    
    # Check if there is a whole book introduction without a TOC entry
    my $wholeBookIntro = @{$XPC->findnodes('//osis:div[@type="introduction" or @type="front"]
        [not(ancestor::osis:div[starts-with(@type,"book")])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml)}[0];
    if ($wholeBookIntro) {
      my $confentry = 'ARG_'.$wholeBookIntro->getAttribute('osisID'); $confentry =~ s/\!.*$//;
      my $confTitle = ($wholeBookIntro->getAttribute('osisID') ? &conf($confentry):'');
      my $intrTitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $wholeBookIntro)}[0];
      my $title = ($confTitle ? $confTitle:($intrTitle ? $intrTitle->textContent():''));
      if ($title) {
        my $toc = $XML_PARSER->parse_balanced_chunk('
<milestone resp="'.$ROC.'" type="x-usfm-toc'.&conf('TOC').'" n="[level1][not_parent]'.$title.'"/>');
        $wholeBookIntro->insertBefore($toc, $wholeBookIntro->firstChild);
        &Note("Inserting introduction TOC entry as: $title");
      }
      else {
        &Warn("There is a whole-book introduction which is not included in the TOC.",
        "If you want to include it, add to config.conf the entry: $confentry=<title>");
      }
    }
        
    # Check each bookGroup's bookGroup introduction and bookSubGroup introduction 
    # divs (if any), and add TOC entries and/or [not_parent] markers as appropriate. 
    # NOTE: Each bookGroup may have one or both of these: bookGroup introduction
    # and/or bookSubGroup introduction(s) (see below how these are distinguished).
    my @bookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
    foreach my $bookGroup (@bookGroups) {
      # The bookGroup introduction is defined as first child div of the bookGroup when it 
      # is either the only non-book TOC div or else is immediately followed by another non-book
      # TOC div.

      # Is there already a bookGroup introduction TOC (in other words not autogenerated)?
      my $singleNonBookChild = (@{$XPC->findnodes('child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")]', $bookGroup)} == 1 ? 'true()':'false()');
      my $bookGroupIntroTOCM = @{$XPC->findnodes('child::*[1][self::osis:div[not(@type="book")]][not(@resp="'.$ROC.'")]
      [boolean(following-sibling::*[1][self::osis:div[not(@type="book")][not(@resp="'.$ROC.'")]]) or '.$singleNonBookChild.']
      /child::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $bookGroup)}[0];
      
      # bookGroup child TOC entries will be made [not_parent] IF there already 
      # exists a bookGroup introduction TOC entry (otherwise chapters would end 
      # up as useless level4 which do not appear in eBook readers).
      if ($bookGroupIntroTOCM) {
        foreach my $m ($XPC->findnodes('child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")][count(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]) = 1]/
            osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $bookGroup)) {
          if ($m->getAttribute('n') !~ /\Q[not_parent]\E/ && $m->parentNode->unique_key ne $bookGroupIntroTOCM->parentNode->unique_key) {
            $m->setAttribute('n', '[not_parent]'.$m->getAttribute('n'));
            &Note("Modifying sub-section TOC to: '".$m->getAttribute('n')."' because a Testament introduction TOC already exists: '".$bookGroupIntroTOCM->getAttribute('n')."'.");
          }
        }
      }
        
      # bookSubGroupAuto TOCs are are defined as non-book bookGroup child divs 
      # having a scope, which are either preceded by a book or are the 1st 
      # or 2nd children of their bookGroup, excluding any bookGroup introduction. 
      # Each bookSubGroupAuto will appear in the TOC.
      my @bookSubGroupAuto = $XPC->findnodes(
          'child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")][@scope][preceding-sibling::*[not(@resp="'.$ROC.'")][1][self::osis:div[@type="book"]]] |
           child::*[not(@resp="'.$ROC.'")][position()=1 or position()=2][self::osis:div[not(@type="book")][@scope]]'
      , $bookGroup);
      for (my $x=0; $x<@bookSubGroupAuto; $x++) {
        if (@bookSubGroupAuto[$x] && $bookGroupIntroTOCM && @bookSubGroupAuto[$x]->unique_key eq $bookGroupIntroTOCM->parentNode->unique_key) {
          splice(@bookSubGroupAuto, $x--, 1);
        }
      }
     
      foreach my $div (@bookSubGroupAuto) {
        # Add bookSubGroup TOC milestones when there isn't one yet
        if (@{$XPC->findnodes('child::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $div)}[0]) {next;}
        my $tocentry = ($div->hasAttribute('scope') ? &getScopeTitle($div->getAttribute('scope')):'');
        if (!$tocentry) {
          my $nexttitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $div)}[0];
          if ($nexttitle) {$tocentry = $nexttitle->textContent();}
        }
        if (!$tocentry) {
          my $nextbkn = @{$XPC->findnodes('following::osis:div[@type="book"][1]/descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n', $div)}[0];
          if ($nextbkn) {$tocentry = $nextbkn->value(); $tocentry =~ s/^\[[^\]]*\]//;}
        }
        if ($tocentry) {
          # New bookSubGroup TOCs will be [not_parent] if there is already a bookGroup introduction
          my $notParent = ($bookGroupIntroTOCM ? '[not_parent]':'');
          my $tag = "<milestone type=\"x-usfm-toc".&conf('TOC')."\" n=\"$notParent$tocentry\" resp=\"$ROC\"/>";
          &Note("Inserting Testament sub-section TOC entry into \"".$div->getAttribute('type')."\" div as $tocentry");
          $div->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $div->firstChild);
        }
        else {&Note("Could not insert Testament sub-section TOC entry into \"".$div->getAttribute('type')."\" div because a title could not be determined.");}
      }

      # Add bookGroup introduction TOC entries using BookGroupTitles, if:
      # + there is more than one bookGroup
      # + the bookGroup has more than one book
      # + there are no bookSubGroups in the bookGroup
      # + there is no bookGroup introduction already
      # + the BookGroupTitle is not 'no'
      if (@bookGroups > 1 && 
            @{$XPC->findnodes('child::osis:div[@type="book"]', $bookGroup)} > 1 && 
            !@bookSubGroupAuto && !$bookGroupIntroTOCM) {
        my $firstBook = @{$XPC->findnodes(
            'descendant::osis:div[@type="book"][1]/@osisID', $bookGroup)}[0]->value;
        my $whichBookGroup = &defaultOsisIndex($firstBook, 3);
        my $bookGroupTitle = &conf("BookGroupTitle$whichBookGroup");
        if ($bookGroupTitle eq 'no') {next;}
        my $toc = $XML_PARSER->parse_balanced_chunk('
<div type="introduction" resp="'.$ROC.'">
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1]'.$bookGroupTitle.'"/>
</div>');
        $bookGroup->insertBefore($toc, $bookGroup->firstChild);
        &Note("Inserting $whichBookGroup bookGroup TOC entry within new introduction div as: $bookGroupTitle");
      }
    }
  }
  elsif ($modType eq 'dict') {
    my $maxkw = &conf("ARG_AutoMaxTOC1"); $maxkw = ($maxkw ne '' ? $maxkw:7);
    # Any Paratext div which does not have a TOC entry already and does 
    # not have sub-entries that are specified as level1-TOC, should get 
    # a level1-TOC entry, so that its main contents will be available 
    # there. Such a TOC entry is not added, however, if the div is a 
    # glossary (that is, a div containing keywords) that has less than 
    # ARG_AutoMaxTOC1 keywords, in which case the sub-entries themselves 
    # may be left without a preceding level1-TOC entry so that they will 
    # appear as level1-TOC themselves.
    my $typeRE = '^('.join('|', sort keys(%PERIPH_TYPE_MAP_R), sort keys(%ID_TYPE_MAP_R)).')$';
    $typeRE =~ s/\-/\\-/g;
  
    my @needTOC = $XPC->findnodes('//osis:div[not(@subType = "x-aggregate")]
        [not(@resp="x-oc")]
        [not(descendant::*[contains(@n, "[level1]")])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml);
        
    my %n;
    foreach my $div (@needTOC) {
      if (!$div->hasAttribute('type') || $div->getAttribute('type') !~ /$typeRE/) {next;}
      my $type = $div->getAttribute('type');
      if ($maxkw && @{$XPC->findnodes('descendant::osis:seg[@type="keyword"]', $div)} <= $maxkw) {next;}
      if ($div->getAttribute('scope')) {
        if (!@{&scopeToBooks($div->getAttribute('scope'), &conf('Versification'))}) {next;} # If scope is not an OSIS scope, then skip it
      }
      
      my $tocTitle;
      my $confentry = 'ARG_'.$div->getAttribute('osisID'); $confentry =~ s/\!.*$//;
      my $confTitle = &conf($confentry);
      my $combinedGlossaryTitle = &conf('CombinedGlossaryTitle');
      my $titleSubPublication = ( $div->getAttribute('scope') ? 
        &conf("TitleSubPublication[".$div->getAttribute('scope')."]") : '' );
      # Look in OSIS file for a title element
      $tocTitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $div)}[0];
      if ($tocTitle) {
        $tocTitle = $tocTitle->textContent;
      }
      # Or look in config.conf for explicit toc entry
      if (!$tocTitle && $confTitle) {
        if ($confTitle eq 'SKIP') {next;}
        $tocTitle = $confTitle;
      }
      # Or create a toc entry (without title) from SUB_PUBLICATIONS & CombinedGlossaryTitle 
      if (!$tocTitle && $combinedGlossaryTitle && $titleSubPublication) {
        $tocTitle = "$combinedGlossaryTitle ($titleSubPublication)";
      }
      if (!$tocTitle) {
        $tocTitle = $div->getAttribute('osisID');
        &Error("The Paratext div with title '$tocTitle' needs a localized title.",
"A level1 TOC entry for this div has been automatically created, but it 
needs a title. You must provide the localized title for this TOC entry 
by adding the following to config.conf: 
$confentry=The Localized Title. 
If you really do not want this glossary to appear in the TOC, then set
the localized title to 'SKIP'.");
      }
      
      my $toc = $XML_PARSER->parse_balanced_chunk(
        '<milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1]'.$tocTitle.'" resp="'.$ROC.'"/>'
      );
      $div->insertBefore($toc, $div->firstChild);
      &Note("Inserting glossary TOC entry within introduction div as: $tocTitle");
    }
    
    # If a glossary with a TOC entry has only one keyword, don't let that
    # single keyword become a secondary TOC entry.
    foreach my $gloss ($XPC->findnodes('//osis:div[@type="glossary"]
        [descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]]
        [count(descendant::osis:seg[@type="keyword"]) = 1]', $xml)) {
      my $ms = @{$XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $gloss)}[0];
      if ($ms->getAttribute('n') =~ /^(\[[^\]]*\])*\[no_toc\]/) {next;}
      my $kw = @{$XPC->findnodes('descendant::osis:seg[@type="keyword"][1]', $gloss)}[0];
      if ($kw->getAttribute('n') =~ /^(\[[^\]]*\])*\[no_toc\]/) {next;}
      $kw->setAttribute('n', '[no_toc]');
    }
    
  }
  elsif ($modType eq 'childrens_bible') {return;}
  
  
  &writeXMLFile($xml, $osisP);
}

sub getScopeTitle {
  my $scope = shift;
  
  $scope =~ s/\s/_/g;
  return &conf("TitleSubPublication[$scope]");
}

# Duplicate an OSIS file as a series of files: one file having all 
# $xpath elements' children removed, and then one for each $xpath 
# element, which has all the other $xpath elements' children removed. 
# This method provides a massive speedup compared to searching or 
# modifying one huge nodeset. It is intended for use with joinOSIS 
# which will reassemble these OSIS files back into one document, after 
# they are searched and/or processed. 
# IMPORTANT: external processing should ONLY modify the one specific 
# element associated with each particular OSIS file, otherwise changes 
# will be lost upon reassembly. This is what splitOSIS_element() is 
# used for, since it returns this modifiable element of a file.
# NOTE: properly handling an element sometimes requires that it be 
# located within its document context, thus cloning is required.
sub splitOSIS {
  my $in_osis = shift;
  my $xpath = shift; 
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]'); # split these out
  
  &Log("\nsplitOSIS: ".&encodePrintPaths($in_osis).":\n", 2);
  
  # splitOSIS uses the same file paths over again and DOCUMENT_CACHE 
  # is keyed on file path!
  undef(%DOCUMENT_CACHE);
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (-e $tmp) {remove_tree($tmp);}
  make_path($tmp);
  
  my $xml = $XML_PARSER->parse_file($in_osis);
  
  my @xmls;
  push(@xmls, { 'xml' => $xml, 'file' => &encfile("$tmp/other.osis") });
  
  # First, completely prune other.osis (before any cloning)
  my (%checkID, $x);
  foreach my $e ($XPC->findnodes("//${xpath}[\@osisID]", $xml)) {
    my $osisID = $e->getAttribute('osisID');
    if ($checkID{$osisID}) {&ErrorBug("osisID is not unique: $osisID", 1);}
    $checkID{$osisID}++;
    my $file = sprintf("%s/%03i_%s.osis", $tmp, ++$x, $osisID);
    my $marker = $e->cloneNode();
    $e->replaceNode($marker);
    push(@xmls, { 'element' => $e, 'osisID' => $osisID, 'file' => &encfile($file) });
  }
  
  # Then write OSIS files
  my @files;
  foreach my $xmlP (@xmls) {
    if (!defined($xmlP->{'xml'})) {
      $xmlP->{'xml'} = $xml->cloneNode(1);
      my $marker = @{$XPC->findnodes(
        "//${xpath}[\@osisID='$xmlP->{'osisID'}']", $xmlP->{'xml'})}[0];
      if (!$marker) {&ErrorBug("No marker: $xmlP->{'osisID'}", 1);}
      $marker->replaceNode($xmlP->{'element'});
    }
    &writeXMLFile($xmlP->{'xml'}, $xmlP->{'file'});
    push(@files, $xmlP->{'file'});
  }
  
  return @files;
}

# Take a file created by splitOSIS and return the element which it
# pertains to. This function is used because within the file, only this 
# element may be modified. If an xml pointer is passed, it will point to  
# the file's parsed document node. If $filterP pointer is passed, it
# be written with an xpath filter to be applied to node searches within
# the element (useful when the exact number of changes made is required
# for instance). If $xpath was used when splitOSIS was called, the same 
# value must be passed here.
sub splitOSIS_element {
  my $file = shift;
  my $xml_or_xmlP = shift;
  my $filterP = shift;
  my $xpath = shift;
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]');
  if (ref($filterP)) {$$filterP = '';}
  
  my $xml;
  if (!defined($xml_or_xmlP)) {
    $xml = $XML_PARSER->parse_file($file);
  }
  elsif (ref($xml_or_xmlP)) {
    $xml = $XML_PARSER->parse_file($file);
    $$xml_or_xmlP = $xml;
  }
  
  if ($file =~ /\bother\.osis$/) {
    if (ref($filterP)) {$$filterP = "[not($xpath)]";}
    return $xml->firstChild;
  }
  elsif ($file !~ /\b\d\d\d_([^\.]+)\.osis$/) {
    &Warn("splitOSIS_element is being called on an unsplit OSIS file.");
    return $xml->firstChild;
  }
  my $osisID = $1;
  
  my @e = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $xml)}[0];
  if (!@e[0] || @e > 1) {&ErrorBug("Problem with $osisID in $file", 1);}
  
  return @e[0];
}

# Rejoin the OSIS files previously cloned by splitOSIS(osis, $xpath) and 
# write it to $path_or_pointer using writeXMLFile();
sub joinOSIS {
  my $path_or_pointer = shift;
  my $xpath = shift;
  
  $xpath = ($xpath ? $xpath:'osis:div[@type="book"]');
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (!-e $tmp) {&ErrorBug("No: $tmp", 1);}
  
  if (!opendir(JOSIS, $tmp)) {&ErrorBug("Can't open: $tmp", 1);}
  my @files = readdir(JOSIS); closedir(JOSIS);
  foreach (@files) {$_ = decode('utf8', $_);}
  
  if (!-e "$tmp/other.osis") {&ErrorBug("No: $tmp/other.osis", 1);}
  my $xml = $XML_PARSER->parse_file("$tmp/other.osis");
  
  # Replace each marker with the correct element file's element
  foreach my $f (@files) {
    my $fdec = &decfile($f);
    if ($fdec !~ /\b\d\d\d_([^\.]+)\.osis$/) {next;}
    my $osisID = $1;
    my $exml = $XML_PARSER->parse_file("$tmp/$f");
    my @e = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $exml)};
    if (!@e[0] || @e > 1) {&ErrorBug("Bad element file: $f", 1);}
    @e[0]->unbindNode();
    my @marker = @{$XPC->findnodes("//${xpath}[\@osisID='$osisID']", $xml)};
    if (!@marker[0]) {
      &ErrorBug('No marker: '.$osisID." in $f", 1);
    }
    @marker[0]->replaceNode(@e[0]);
  }
  
  # Save the reassembled document
  &writeXMLFile($xml, $path_or_pointer, undef, 2);
}

sub writeMissingNoteOsisRefsFAST {
  my $osisP = shift;
  
  &Log("\nWriting missing note osisRefs in OSIS file \"$$osisP\".\n", 1);
  
  my @files = &splitOSIS($$osisP);
  
  my $count = 0;
  foreach my $file (@files) {
    my $xml;
    my $element = &splitOSIS_element($file, \$xml);
    if ($element->hasAttribute('osisID')) {
      &Log($element->getAttribute('osisID')."\n", 2);
    }
    $count += &writeMissingNoteOsisRefs($element);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($osisP);
  
  &Report("Wrote \"$count\" note osisRefs.");
}

# A note's osisRef points to the passage to which a note applies. For 
# glossaries this is the note's context keyword. For Bibles this is also 
# the note's context, unless the note contains a reference of type 
# annotateRef, in which case the note applies to the annotateRef passage.
sub writeMissingNoteOsisRefs {
  my $xml = shift;
  
  my @notes = $XPC->findnodes('descendant::osis:note[not(@osisRef)]', $xml);
  my $refSystem = &getOsisRefSystem($xml);
  
  my $count = 0;
  foreach my $note (@notes) {
    my $osisRef;
    if (&isBible($xml)) {
      # need an actual osisID, so bibleContext output needs fixup
      $osisRef = @{&atomizeContext(&bibleContext($note))}[0];
      if ($osisRef =~ /(BIBLE_INTRO|TESTAMENT_INTRO)/) {
        $osisRef = '';
      }
      $osisRef =~ s/(\.0)+$//;
    }
    if (!$osisRef) {
      $osisRef = @{&atomizeContext(&otherModContext($note))}[0];
    }
    
    # Check if Bible annotateRef should override verse context
    my $con_bc; my $con_vf; my $con_vl;
    if (&isBible($xml) && $osisRef =~ /^($OSISBOOKSRE)\.\d+\.\d+$/) {
      # get notes's context
      $con_bc = &bibleContext($note);
      if ($con_bc !~ /^(($OSISBOOKSRE)\.\d+)(\.(\d+)(\.(\d+))?)?$/) {$con_bc = '';}
      else {
        $con_bc = $1;
        $con_vf = $4;
        $con_vl = $6;
        if ($con_vf == 0 || $con_vl == 0) {$con_bc = '';}
      }
    }
    if ($con_bc) {
      # let annotateRef override context if it makes sense
      my $aror;
      my $rs = @{$XPC->findnodes('descendant::osis:reference[1][@type="annotateRef" and @osisRef]', $note)}[0];
      if ($rs) {
        $aror = $rs->getAttribute('osisRef');
        $aror =~ s/^[\w\d]+\://;
        if ($aror =~ /^([^\.]+\.\d+)(\.(\d+)(-\1\.(\d+))?)?$/) {
          my $ref_bc = $1; my $ref_vf = $3; my $ref_vl = $5;
          if (!$ref_vf) {$ref_vf = 0;}
          if (!$ref_vl) {$ref_vl = $ref_vf;}
          if ($rs->getAttribute('annotateType') ne $ANNOTATE_TYPE{'Source'} && ($con_bc ne $ref_bc || $ref_vl < $con_vf || $ref_vf > $con_vl)) {
            &Warn("writeMissingNoteOsisRefs: Note's annotateRef \"".$rs."\" is outside note's context \"$con_bc.$con_vf.$con_vl\"");
            $aror = '';
          }
        }
        else {
          &Warn("writeMissingNoteOsisRefs: Unexpected annotateRef osisRef found \"".$rs."\"");
          $aror = '';
        }
      }
      
      $osisRef = ($aror ? $aror:"$con_bc.$con_vf".($con_vl != $con_vf ? "-$con_bc.$con_vl":''));
    }

    $note->setAttribute('osisRef', $osisRef);
    $count++;
  }
  
  return $count;
}

sub removeDefaultWorkPrefixesFAST {
  my $osisP = shift;
  
  &Log("\nRemoving default work prefixes in OSIS file \"$$osisP\".\n", 1);
  
  my @files = &splitOSIS($$osisP);
  
  my %stats = ('osisRef'=>0, 'osisID'=>0);
  
  foreach my $file (@files) {
    my $xml; my $filter;
    my $element = &splitOSIS_element($file, \$xml, \$filter);
    if ($element->hasAttribute('osisID')) {
      &Log($element->getAttribute('osisID')."\n", 2);
    }
    &removeDefaultWorkPrefixes($element, \%stats, $filter);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($osisP);
  
  &Report("Removed \"".$stats{'osisRef'}."\" redundant Work prefixes from osisRef attributes.");
  &Report("<-Removed \"".$stats{'osisID'}."\" redundant Work prefixes from osisID attributes.");
}

# Removes work prefixes of all osisIDs and osisRefs which match their
# respective osisText osisIDWork or osisRefWork attribute value (in 
# other words removes work prefixes which are unnecessary).
sub removeDefaultWorkPrefixes {
  my $xml = shift;
  my $statsP = shift;
  my $filter = shift;
  
  # normalize osisRefs
  my @osisRefs = $XPC->findnodes("descendant-or-self::*${filter}/\@osisRef", $xml);
  my $osisRefWork = &getOsisRefWork($xml);
  my $normedOR = 0;
  foreach my $osisRef (@osisRefs) {
    if ($osisRef->getValue() !~ /^$osisRefWork\:/) {next;}
    my $new = $osisRef->getValue();
    $new =~ s/^$osisRefWork\://;
    $osisRef->setValue($new);
    $statsP->{'osisRef'}++;
  }
  
  # normalize osisIDs
  my @osisIDs = $XPC->findnodes("descendant-or-self::*${filter}/\@osisID", $xml);
  my $osisIDWork = &getOsisIDWork($xml);
  my $normedID = 0;
  foreach my $osisID (@osisIDs) {
    if ($osisID->getValue() !~ /^$osisIDWork\:/) {next;}
    my $new = $osisID->getValue();
    $new =~ s/^$osisIDWork\://;
    $osisID->setValue($new);
    $statsP->{'osisID'}++;
  }
}

# Take an input file path and return the path of a new temporary file, 
# which is sequentially numbered and does not already exist. If $outname
# is provided, that name will be used for the tmp file, or, if $levelup
# is provided, then the caller $levelup levels up will be used (default
# is one level up).
sub temporaryFile {
  my $path = shift;
  my $outname = shift;
  my $levelup = shift;
  
  if (!$outname) {
    $levelup = ($levelup ? $levelup:1);
    $outname = (caller($levelup))[3]; 
    $outname =~ s/^.*\:{2}//;
  }
  
  my $dir = $path;
  my $file = ($dir =~ s/^(.*?)\/([^\/]+)$/$1/ ? $2:'');
  if (!$file) {&ErrorBug("Could not parse temporaryFile file $path", 1);}
  my $ext = ($file =~ s/^(.*?)\.([^\.]+)$/$1/ ? $2:'');
  if (!$ext) {&ErrorBug("Could not parse temporaryFile ext $path", 1);}
  
  opendir(TDIR, $TMPDIR) || &ErrorBug("Could not open temporaryFile dir $TMPDIR", 1);
  my @files = readdir(TDIR);
  closedir(TDIR);
  
  my $n = 0;
  foreach my $f (@files) {
    if (-d "$TMPDIR/$f") {next;}
    if ($f =~ /^(\d+)_/) {
      my $nf = $1; $nf =~ s/^0+//; $nf = (1*$nf);
      if ($nf > $n) {$n = $nf;}
    }
  }
  $n++;
  
  my $p = sprintf("%s/%02i_%s.%s", $TMPDIR, $n, $outname, $ext);
  
  if (-e $p) {
    &ErrorBug("Temporary file exists: $p", 1);
  }

  return $p;
}

# XSLT has an uncontrollable habit of creating huge numbers of WARNINGS, 
# so only print the first of each.
sub LogXSLT {
  my $log = shift;
  
  my (%seen, $last);
  foreach my $l (split(/^/, $log)) {
    if ($l =~ /^WARNING:/) {
      if (exists($seen{$l})) {next;}
      $seen{$l}++;
    }
    
    if ($l eq $last) {next;}
    
    &Log($l);
    $last = $l;
  }
}

1;
