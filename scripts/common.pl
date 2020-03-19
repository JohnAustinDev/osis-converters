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

use Encode;
use File::Spec;
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Find;
use Cwd;
use DateTime;

select STDERR; $| = 1;  # make unbuffered
select STDOUT; $| = 1;  # make unbuffered

$KEYWORD = "osis:seg[\@type='keyword']"; # XPath expression matching dictionary entries in OSIS source
$OSISSCHEMA = "http://localhost/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd"; # Original is at www.crosswire.org, but it's copied locally for speedup/networkless functionality
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
$FNREFSTART = "<reference type=\"x-note\" osisRef=\"TARGET\">";
$FNREFEND = "</reference>";
$FNREFEXT = "!note.n";
$MAX_MATCH_WORDS = 3;
$MAX_UNICODE = 1103; # Default value: highest Russian Cyrillic Uncode code point
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
$OT_BOOKS = "Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr Ezra Neh Esth Job Ps Prov Eccl Song Isa Jer Lam Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech Mal";
$NT_BOOKS = "Matt Mark Luke John Acts Rom 1Cor 2Cor Gal Eph Phil Col 1Thess 2Thess 1Tim 2Tim Titus Phlm Heb Jas 1Pet 2Pet 1John 2John 3John Jude Rev";
{ my $bn = 1;
  foreach my $bk (split(/\s+/, "$OT_BOOKS $NT_BOOKS")) {
    $OSISBOOKS{$bk} = $bn; $bn++;
  }
}
$OSISBOOKSRE = "$OT_BOOKS $NT_BOOKS"; $OSISBOOKSRE =~ s/\s+/|/g;
$SWORD_VERSE_SYSTEMS = "KJV|German|KJVA|Synodal|Leningrad|NRSVA|Luther|Vulg|SynodalProt|Orthodox|LXX|NRSV|MT|Catholic|Catholic2";
$VSYS_INSTR_RE  = "($OSISBOOKSRE)\\.(\\d+)(\\.(\\d+)(\\.(\\d+))?)?";
$VSYS_PINSTR_RE = "($OSISBOOKSRE)\\.(\\d+)(\\.(\\d+)(\\.(\\d+|PART))?)?";
$VSYS_UNIVERSE_RE = "($SWORD_VERSE_SYSTEMS)\:$VSYS_PINSTR_RE";
@USFM2OSIS_PY_SPECIAL_BOOKS = ('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other');
$DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb]";
$DICTIONARY_WORDS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
$DICTIONARY_WORDS = "DictionaryWords.xml";
$UPPERCASE_DICTIONARY_KEYS = 1;
$NOCONSOLELOG = 1;
$SFM2ALL_SEPARATE_LOGS = 1;

# The attribute types and values below are hardwired into the xsl files
# to allow them to be more portable. But in Perl, these variables are used.

$ROC = 'x-oc'; # @resp='x-oc' means osis-converters is responsible for adding the element

# Verse System related attribute types
$VSYS{'prefix_vs'}  = 'x-vsys';
$VSYS{'resp_vs'}    = $VSYS{'prefix_vs'};
$VSYS{'missing_vs'} = $VSYS{'prefix_vs'}.'-missing';
$VSYS{'movedto_vs'} = $VSYS{'prefix_vs'}.'-movedto';
$VSYS{'extra_vs'}   = $VSYS{'prefix_vs'}.'-extra';
$VSYS{'fitted_vs'}  = $VSYS{'prefix_vs'}.'-fitted';
$VSYS{'start_vs'}   = '-start';
$VSYS{'end_vs'}     = '-end';

# annotateType attribute values
$ANNOTATE_TYPE{'Source'} = $VSYS{'prefix_vs'}.'-source'; # annotateRef is osisRef to source (custom) verse system
$ANNOTATE_TYPE{'Universal'} = $VSYS{'prefix_vs'}.'-universal'; # annotateRef is osisRef to an external (fixed) verse system
$ANNOTATE_TYPE{'Conversion'} = 'x-conversion'; # annotateRef listing conversions where an element should be output
$ANNOTATE_TYPE{'Feature'} = 'x-feature'; # annotateRef listing special features to which an element applies

require("$SCRD/scripts/bible/getScope.pl");
require("$SCRD/scripts/bible/fitToVerseSystem.pl"); # This defines some globals
require("$SCRD/scripts/functions_childrensBible.pl");
require("$SCRD/scripts/functions_context.pl");
require("$SCRD/scripts/functions_image.pl");

sub init_linux_script() {
  chdir($MAININPD);
  my $inpdGit = &shell("git rev-parse HEAD 2>/dev/null", 3); chomp($inpdGit);
  my $inpdOriginGit = ($inpdGit ? &shell("git config --get remote.origin.url", 3):''); chomp($inpdOriginGit);
  
  chdir($SCRD);
  my $scrdGit = &shell("git rev-parse HEAD 2>/dev/null", 3); chomp($scrdGit);
  
  my $modtoolsGit = &shell("cd \"$MODULETOOLS_BIN\" && git rev-parse HEAD 2>/dev/null", 3); chomp($modtoolsGit);
  
  &Log("\nUsing ".`calibre --version`);
  &Log("osis-converters git rev: $scrdGit\n");
  &Log("Module-tools git rev: $modtoolsGit at $MODULETOOLS_BIN\n");
  if ($inpdGit) {
    &Log("$inpdOriginGit rev: $inpdGit\n");
  }
  &Log("\n-----------------------------------------------------\nSTARTING $SCRIPT_NAME.pl\n\n");
  
  if ($SCRIPT_NAME !~ /^osis2ebook$/) {&timer('start');} # osis2ebook is usually called multiple times by osis2ebooks.pl so don't restart timer
  
  &initLibXML();
  
  %BOOKNAMES; &readBookNamesXML(\%BOOKNAMES);
  
  # If appropriate, do either runOsis2osis(preinit) OR checkAndWriteDefaults() (but never both, since osis2osis also creates input control files)
  if (-e "$INPD/CF_osis2osis.txt" && $SCRIPT_NAME =~ /(osis2osis|sfm2all)/) {
    require("$SCRD/scripts/osis2osis.pl");
    &runOsis2osis('preinit', $INPD);
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
    my $cn = "${MAINMOD}DICT"; $DICTMOD = ($INPD eq $DICTINPD || $CONF->{'Companion'} =~ /\b$cn\b/ ? $cn:'');
  }
  
  if (!-e $CONFFILE) {
    &Error("There is no config.conf file: \"$CONFFILE\".", "\"$INPD\" may not be an osis-converters project directory. If it is, then run update.pl to create a config.conf file.\n", 1);
  }
  
  $MOD_OUTDIR = &getModuleOutputDir();
  if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
  
  $TMPDIR = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";
  if (!$NO_OUTPUT_DELETE) {
    if (-e $TMPDIR) {remove_tree($TMPDIR);}
    make_path($TMPDIR);
  }
  
  &initInputOutputFiles($SCRIPT_NAME, $INPD, $MOD_OUTDIR, $TMPDIR);
  
  $LOGFILE = &initLogFile($LOGFILE, "$MOD_OUTDIR/OUT_".$SCRIPT_NAME."_$MOD.txt");
  
  # Set default to 'on' for the following OSIS processing steps
  my @CF_files = ('addScripRefLinks', 'addFootnoteLinks');
  foreach my $s (@CF_files) {if (-e "$INPD/CF_$s.txt") {$$s = 'on_by_default';}}
  if ($SCRIPT_NAME !~ /osis2osis/) {
    $addCrossRefs = "on_by_default";
    if ($INPD eq $DICTINPD) {$addSeeAlsoLinks = 'on_by_default';}
    elsif (-e "$INPD/$DICTIONARY_WORDS") {$addDictLinks = 'on_by_default';}
  }
  
  $DEFAULT_DICTIONARY_WORDS = "$MOD_OUTDIR/DictionaryWords_autogen.xml";
  
  &Debug("Linux script ".(&runningInVagrant() ? "on virtual machine":"on host").":\n\tOUTDIR=$OUTDIR\n\tMOD_OUTDIR=$MOD_OUTDIR\n\tTMPDIR=$TMPDIR\n\tLOGFILE=$LOGFILE\n\tMAININPD=$MAININPD\n\tMAINMOD=$MAINMOD\n\tDICTINPD=$DICTINPD\n\tDICTMOD=$DICTMOD\n\tMOD=$MOD\n\tREADLAYER=$READLAYER\n");
  
  if ($SCRIPT_NAME =~ /^update$/) {return;}
  
  &checkConfGlobals();
    
  &checkProjectConfiguration();
    
  &checkRequiredConfEntries();
  
  if (&conf('Font')) {&checkFont(&conf('Font'));}
  
  if (-e "$INPD/images") {&checkImageFileNames("$INPD/images");}
}
# This is only needed to update old osis-converters projects
sub update_removeConvertTXT($) {
  my $confFile = shift;
  
  &Warn("UPDATE: Found outdated convert.txt. Updating $confFile...");
  my %confP; if (!&readConfFile($confFile, \%confP)) {
    &Error("Could not read config.conf file: $confFile");
    return;
  }
  
  &updateConvertTXT("$MAININPD/eBook/convert.txt", \%confP, 'osis2ebooks');
  &updateConvertTXT("$MAININPD/html/convert.txt", \%confP, 'osis2html');
  return &writeConf($confFile, \%confP);
}
# This is only needed to update old osis-converters projects
sub updateConvertTXT($$$) {
  my $convtxt = shift;
  my $confP = shift;
  my $section = shift;
  
  if (! -e $convtxt) {return '';}
  
  my %pubScopeTitle;
  if (open(CONV, "<$READLAYER", $convtxt)) {
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
          $e = 'OldTestamentTitle';
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Group2\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $s = '';
          $e = 'NewTestamentTitle';
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
sub update_removeDictConfig($$) {
  my $dconf = shift;
  my $confFile = shift;

  &Warn("UPDATE: Found outdated DICT config.conf. Updating...");
  my %mainConf; &readConfFile($confFile, \%mainConf);
  my %dictConf; &readConfFile($dconf, \%dictConf);
  &Warn("<-UPDATE: Removing outdated DICT config.conf: $dconf");
  unlink($dconf);
  &Note("The file: $dconf which was used for 
DICT settings has now been replaced by a section in the config.conf 
file. The DICT config.conf file will be deleted. Your config.conf will 
have new section with that information.");
  foreach my $de (sort keys %dictConf) {
    if ($de =~ /(^|\+)(ModuleName)$/) {next;}
    my $de2 = $de; $de2 =~ s/^$MAINMOD\+//;
    if ($mainConf{$de2} eq $dictConf{$de} || $mainConf{"$MAINMOD+$de2"} eq $dictConf{$de}) {next;}
    $mainConf{"$DICTMOD+$de"} = $dictConf{$de};
  }

  return &writeConf($confFile, \%mainConf);
}

# If $logfileIn is not specified then start a new one at $logfileDef.
# If $logfileIn is specified then append to $logfileIn.
sub initLogFile($$) {
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
sub checkProjectConfiguration() {
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

sub readBookNamesXML($) {
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
      my $bk = getOsisName($bkelem->getAttribute('code'), 1);
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

sub timer($) {
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
      &Log("elapsed time: ".($e->hours ? $e->hours." hours ":'').($e->minutes ? $e->minutes." minutes ":'').$e->seconds." seconds\n", 1);
    }
    $STARTTIME = '';
  }
  else {&Log("\ncurrent time: ".localtime()."\n");}
}

sub checkFont($) {
  my $font = shift;
  
  # After this routine is run, font features can use "if ($FONT)" to check 
  # font support, and can use FONT_FILES whenever fonts files are needed.
  
  %FONT_FILES;
  
  # FONTS can be a URL in which case update the local font cache
  if ($FONTS =~ /^https?\:/) {$FONTS = &updateURLCache('fonts', $FONTS, 12);}

  if ($FONTS && ! -e $FONTS) {
    &Error("config.conf specifies FONTS as \"$FONTS\" but this path does not exist. FONTS will be unset.", "Change the value of FONTS in the [system] section of config.conf to point to an existing path or URL.");
    $FONTS = '';
  }

  if ($FONTS) {
    # The Font value is a font internal name, which may have multiple font files associated with it.
    # Font files should be named according to the excpectations below.
    opendir(DIR, $FONTS);
    my @fonts = readdir(DIR);
    closedir(DIR);
    my %styles = ('R' => 'regular', 'B' => 'bold', 'I' => 'italic', 'BI' => 'bold italic', 'IB' => 'bold italic');
    foreach my $s (sort keys %styles) {if ($font =~ /\-$s$/i) {&Error("The Font config.conf entry should not specify the font style.", "Remove '-$s' from FONT=$font in config.conf");}}
    foreach my $f (@fonts) {
      if ($f =~ /^\./) {next;}
      if ($f =~ /^(.*?)(\-([ribRIB]{1,2}))?\.([^\.]+)$/) {
        my $n = $1; my $t = ($2 ? $3:'R'); my $ext = $4;
        if ($2 && uc($3) eq 'R') {
          &Error("Regular font $f should not have the $2 extension.", "Change the name of the font file from $f to $n.$ext");
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
      &Error("No font file(s) for \"$font\" were found in \"$FONTS\"", "Add the required font to this directory, or change FONTS in the [system] section of config.conf to the correct path or URL.");
    }
  }
  else {
    &Warn("\nThe config.conf specifies font \"$font\", but no FONTS directory has been specified in the [system] section of config.conf. Therefore, this setting will be ignored!\n");
  }
}

# Cache files from a URL to an .osis-converters subdirectory. The cache 
# will NOT be updated if it was already updated less than $updatePeriod 
# hours ago. If an array pointer $listingAP is provided, then files will 
# NOT be downloaded, rather, the directory listing will be written to 
# $listingAP. Directories in the listing end with '/'. For $listingAP
# to work, the URL must target an Apache server directory where html 
# listing is enabled. The path to the URLCache subdirectory is returned.
sub updateURLCache($$$$) {
  my $subdir = shift; # local .osis-converters subdirectory to update
  my $url = shift; # URL to read from
  my $updatePeriod = shift; # hours between updates (0 updates always)
  my $listingAP = shift; # Do not download files, just write a file listing here.
  
  if (!$subdir) {&ErrorBug("Subdir cannot be empty.", 1);}
  
  my $pp = "~/.osis-converters/URLCache/$subdir";
  my $p = &expandLinuxPath($pp);
  if (! -e $p) {make_path($p);}
  
  # Check last time this subdirectory was updated
  if ($updatePeriod && -e "$p/../$subdir-updated.txt") {
    my $last;
    if (open(TXT, "<$READLAYER", "$p/../$subdir-updated.txt")) {
      while(<TXT>) {if ($_ =~ /^epoch=(.*?)$/) {$last = $1;}}
      close(TXT);
    }
    if ($last) {
      my $now = DateTime->now()->epoch();
      my $delta = sprintf("%.2f", ($now-$last)/3600);
      if ($delta < $updatePeriod) {
        if ($listingAP) {&readWgetFilePaths($p, $listingAP, $p);}
        &Note("Checked local cache directory $pp (last updated $delta hours ago)");
        return $p;
      }
    }
  }
  
  # Refresh the subdirectory contents from the URL
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
        shell("cd '$p' && wget -r --quiet --level=1 -erobots=off -nd -np -N -A '*.*' -R '*.html*' '$url'", 3);
        $success = &wgetSyncDel($p);
      }
      # Otherwise return a listing
      else {
        my $pdir = $url; $pdir =~ s/^.*?([^\/]+)\/?$/$1/; # directory name
        my $cdir = $url; $cdir =~ s/^https?\:\/\/[^\/]+\/(.*?)\/?$/$1/; @cd = split(/\//, $cdir); $cdir = @cd-1; # url path depth
        if ($p !~ /\/\.osis-converters\//) {die;} remove_tree($p); make_path($p);
        &shell("cd '$p' && wget -r -np -nH --restrict-file-names=nocontrol --cut-dirs=$cdir --accept index.html -X $pdir $url", 3);
        $success = &readWgetFilePaths($p, $listingAP, $p);
      }
    }
  }
  
  if ($success) {
    &Note("Updated local cache directory $pp from URL $url");
    
    # Save time of this update
    if (open(TXT, ">$WRITELAYER", "$p/../$subdir-updated.txt")) {
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
sub wgetSyncDel($) {
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
  shell("cd '$p' && rm *.tmp", 3);
  
  return $success;
}

# Recursively read $wgetdir directory that contains the wget result 
# of reading an apache server directory, and add paths of listed files 
# and directories to the $filesAP array pointer. All directories will
# end with a '/'.
sub readWgetFilePaths($\@$) {
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
      &Debug("Found folder: $save\n", 1);
      $success &= &readWgetFilePaths("$wgetdir/$sub", $filesAP, $root);
      next;
    }
    elsif ($sub ne 'index.html') {
      &ErrorBug("Encounteed unexpected file $sub in $wgetdir.");
      $success = 0;
      next;
    }
    my $html = $XML_PARSER->load_html(location  => "$wgetdir/$sub", recover => 1);
    if (!$html) {&ErrorBug("Could not parse $wgetdir/$sub"); $success = 0; next;}
    foreach my $a ($html->findnodes('//tr/td/a')) {
      my $icon = @{$a->findnodes('preceding::img[1]/@src')}[0];
      if ($icon->value =~ /\/(folder|back)\.gif$/) {next;}
      my $save = "$wgetdir/".decode_utf8($a->textContent()); $save =~ s/^\Q$root\E\/[^\/]+/./;
      push(@{$filesAP}, $save);
      &Debug("Found file: $save\n", 1);
    }
  }
  
  return $success;
}


# Parse the module's DICTIONARY_WORDS to DWF. Check for outdated 
# DICTIONARY_WORDS markup and update it. Validate DICTIONARY_WORDS 
# entries against a dictionary OSIS file's keywords. Validate 
# DICTIONARY_WORDS xml markup. Return DWF on successful parsing and 
# checking without error, '' otherwise. 
sub loadDictionaryWordsXML($$$) {
  my $dictosis = shift;
  my $noupdateMarkup = shift;
  my $noupdateEntries = shift;
  
  if (! -e "$INPD/$DICTIONARY_WORDS") {return '';}
  my $dwf = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # Check for old DICTIONARY_WORDS markup and update or report
  my $errors = 0;
  my $update = 0;
  my $tst = @{$XPC->findnodes('//dw:div', $dwf)}[0];
  if (!$tst) {
    &Error("Missing namespace declaration in: \"$INPD/$DICTIONARY_WORDS\", continuing with default.", "Add 'xmlns=\"$DICTIONARY_WORDS_NAMESPACE\"' to root element of \"$INPD/$DICTIONARY_WORDS\".");
    $errors++;
    my @ns = $XPC->findnodes('//*', $dwf);
    foreach my $n (@ns) {$n->setNamespace($DICTIONARY_WORDS_NAMESPACE, 'dw', 1); $update++;}
  }
  my $tst = @{$XPC->findnodes('//*[@highlight]', $dwf)}[0];
  if ($tst) {
    &Warn("Ignoring outdated attribute: \"highlight\" found in: \"$INPD/$DICTIONARY_WORDS\"", "Remove the \"highlight\" attribute and use the more powerful notXPATH attribute instead.");
    $errors++;
  }
  my $tst = @{$XPC->findnodes('//*[@withString]', $dwf)}[0];
  if ($tst) {
    $errors++;
    &Warn("\"withString\" attribute is no longer supported.", "Remove withString attributes from $DICTIONARY_WORDS and replace it with XPATH=<xpath-expression> instead.");
  }
  
  # Save any updates back to source dictionary_words_xml and reload
  if ($update) {
    &writeXMLFile($dwf, "$dictionary_words_xml.tmp");
    unlink($dictionary_words_xml); rename("$dictionary_words_xml.tmp", $dictionary_words_xml);
    &Note("Updated $update instance of non-conforming markup in $dictionary_words_xml");
    if (!$noupdateMarkup) {
      $noupdateMarkup++;
      return &loadDictionaryWordsXML($dictosis, $noupdateMarkup, $noupdateEntries);
    }
    else {
      $errors++;
      &Error("loadDictionaryWordsXML failed to update markup. Update $DICTIONARY_WORDS manually.", "Sometimes the $DICTIONARY_WORDS can only be updated manually.");
    }
  }
  
  # Compare dictosis to DICTIONARY_WORDS
  if ($dictosis && &compareDictOsis2DWF($dictosis, "$INPD/$DICTIONARY_WORDS")) {
    if (!$noupdateEntries) {
      # If updates were made, reload DWF etc.
      $noupdateEntries++;
      return &loadDictionaryWordsXML($dictosis, $noupdateMarkup, $noupdateEntries);
    }
    else {
      $errors++;
      &ErrorBug("compareDictOsis2DWF failed to update entry osisRef capitalization on first pass");
    }
  }
  
  # Warn if some entries should have multiple match elements
  my @r = $XPC->findnodes('//dw:entry/dw:name[translate(text(), "_,;[(", "_____") != text()][count(following-sibling::dw:match) = 1]', $dwf);
  if (!@r[0]) {@r = ();}
  &Log("\n");
  &Report("Compound glossary entry names with a single match element: (".scalar(@r)." instances)");
  if (@r) {
    &Note("Multiple <match> elements should probably be added to $DICTIONARY_WORDS\nto match each part of the compound glossary entry.");
    foreach my $r (@r) {&Log($r->textContent."\n");}
  }
  
  my $valid = 0;
  if ($errors == 0) {$valid = &validateDictionaryWordsXML($dwf);}
  if ($valid) {&Note("$INPD/$DICTIONARY_WORDS has no unrecognized elements or attributes.\n");}
  
  return ($valid && $errors == 0 ? $dwf:'');
}


# Check that all keywords in dictosis, except those in the NAVMENU, are 
# included as entries in the dictionary_words_xml file and all entries 
# in dictionary_words_xml have keywords in dictosis. If the difference 
# is only in capitalization, and all the OSIS file's keywords are unique 
# according to a case-sensitive comparison, (which occurs when 
# converting from DictionaryWords.txt to DictionaryWords.xml) then fix 
# them, update dictionary_words_xml, and return 1. Otherwise return 0.
sub compareDictOsis2DWF($$) {
  my $dictosis = shift; # dictionary osis file to validate entries against
  my $dictionary_words_xml = shift; # DICTIONARY_WORDS xml file to validate
  
  &Log("\n--- CHECKING ENTRIES IN: $dictosis FOR INCLUSION IN: $dictionary_words_xml\n", 1);
  
  my $osis = $XML_PARSER->parse_file($dictosis);
  my $osismod = &getOsisRefWork($osis);
  my $dwf = $XML_PARSER->parse_file($dictionary_words_xml);
  
  # Decide if keyword any capitalization update is possible or not
  my $allowUpdate = 1; my %noCaseKeys;
  foreach my $es ($XPC->findnodes('//osis:seg[@type="keyword"]/text()', $osis)) {
    if ($noCaseKeys{lc($es)}) {
      &Note("Will not update case-only discrepancies in $dictionary_words_xml.");
      $allowUpdate = 0;
      last;
    }
    $noCaseKeys{lc($es)}++;
  }

  my $update = 0;
  my $allmatch = 1;
  my @dwfOsisRefs = $XPC->findnodes('//dw:entry/@osisRef', $dwf);
  my @dictOsisIDs = $XPC->findnodes('//osis:seg[@type="keyword"][not(ancestor::osis:div[@subType="x-aggregate"])]/@osisID', $osis);
  
  # Check that all DICTMOD keywords (except NAVEMNU keywords) are included as entries in dictionary_words_xml
  foreach my $osisIDa (@dictOsisIDs) {
    if (!$osisIDa || @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"][@scope="NAVMENU"][1]', $osisIDa)}[0]) {next;}
    my $osisID = $osisIDa->value;
    my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
    
    my $match = 0;
DWF_OSISREF:
    foreach my $dwfOsisRef (@dwfOsisRefs) {
      if (!$dwfOsisRef) {next;}
      foreach my $osisRef (split(/\s+/, $dwfOsisRef->value)) {
        my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
        if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last DWF_OSISREF;}
      }
        
      # Update entry osisRefs that need to be, and can be, updated
      my $name = @{$XPC->findnodes('parent::dw:entry/dw:name[1]', $dwfOsisRef)}[0];
      if ($allowUpdate && &uc2($osisIDa->parentNode->textContent) eq &uc2($name->textContent)) {
        $match = 1;
        $update++;
        my $origOsisRef = $dwfOsisRef->value;
        $dwfOsisRef->setValue(entry2osisRef($osisID_mod, $osisID));
        foreach my $c ($name->childNodes()) {$c->unbindNode();}
        $name->appendText($osisIDa->parentNode->textContent);
        &Warn("DICT mod keyword and DictionaryWords entry name are identical, but osisID != osisRef. UPDATING DictionaryWords osisRef from $origOsisRef to $osisID", "<>This happens when an old version of DictionaryWords.xml is being upgraded. Otherwise, there could be bug or some problem with this osisRef.");
        last;
      }
    }
    if (!$match) {&Warn("Missing entry \"$osisID\" in $dictionary_words_xml", "That you don't want any links to this entry."); $allmatch = 0;}
  }
  
  # Check that all DWF osisRefs are included as keywords in dictosis
  my %reported;
  foreach my $dwfOsisRef (@dwfOsisRefs) {
    if (!$dwfOsisRef) {next;}
    foreach my $osisRef (split(/\s+/, $dwfOsisRef->value)) {
      my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
      
      my $match = 0;
      foreach my $osisIDa (@dictOsisIDs) {
        if (!$osisIDa) {next;}
        my $osisID = $osisIDa->value;
        my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
        if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last;}
      }
      if (!$match && $osisRef !~ /\!toc$/) {
        if (!$reported{$osisRef}) {
          &Warn("Extra entry \"$osisRef\" in $dictionary_words_xml", "Remove this entry from $dictionary_words_xml because does not appear in $DICTMOD.");
        }
        $reported{$osisRef}++;
        $allmatch = 0;
      }
    }
  }
  
  # Save any updates back to source dictionary_words_xml
  if ($update) {
    &writeXMLFile($dwf, "$dictionary_words_xml.tmp");
    unlink($dictionary_words_xml); rename("$dictionary_words_xml.tmp", $dictionary_words_xml);
    &Note("Updated $update entries in $dictionary_words_xml");
  }
  elsif ($allmatch) {&Log("All entries are included.\n");}
  
  return ($update ? 1:0);
}


# Brute force validation of dwf returns 1 on successful validation, 0 otherwise
sub validateDictionaryWordsXML($) {
  my $dwf = shift;
  
  my @entries = $XPC->findnodes('//dw:entry[@osisRef]', $dwf);
  foreach my $entry (@entries) {
    my @dicts = split(/\s+/, $entry->getAttribute('osisRef'));
    foreach my $dict (@dicts) {
      if ($dict !~ s/^(\w+):.*$/$1/) {&Error("osisRef \"$dict\" in \"$INPD/$DefaultDictWordFile\" has no target module", "Add the dictionary module name followed by ':' to the osisRef value.");}
    }
  }
  
  my $success = 1;
  my $x = "//*";
  my @allowed = ('dictionaryWords', 'div', 'entry', 'name', 'match');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badElem = $XPC->findnodes($x, $dwf);
  if (@badElem) {
    foreach my $ba (@badElem) {
      &Error("Bad DictionaryWords.xml element: \"".$ba->localname()."\"", "Only the following elements are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//*[local-name()!='dictionaryWords'][local-name()!='entry']/@*";
  @allowed = ('onlyNewTestament', 'onlyOldTestament', 'context', 'notContext', 'multiple', 'osisRef', 'XPATH', 'notXPATH', 'version', 'dontLink', 'notExplicit', 'onlyExplicit');
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("\nBad DictionaryWords.xml attribute: \"".$ba->localname()."\"", "Only the following attributes are allowed: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  $x = "//dw:entry/@*";
  push(@allowed, ('osisRef', 'noOutboundLinks'));
  foreach my $a (@allowed) {$x .= "[local-name()!='$a']";}
  my @badAttribs = $XPC->findnodes($x, $dwf);
  if (@badAttribs) {
    foreach my $ba (@badAttribs) {
      &Error("Bad DictionaryWords.xml entry attribute: \"".$ba->localname()."\"", "The entry element may contain these attributes: ".join(' ', @allowed));
      $success = 0;
    }
  }
  
  return $success;
}


sub initInputOutputFiles($$$$) {
  my $script_name = shift;
  my $inpd = shift;
  my $modOutdir = shift;
  my $tmpdir = shift;
  
  my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
  
  my @outs;
  if ($script_name =~ /^(osis2osis|sfm2osis)$/) {
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

  if (!$NO_OUTPUT_DELETE) {
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


sub initLibXML() {
  use Sword;
  use HTML::Entities;
  use XML::LibXML;
  $XPC = XML::LibXML::XPathContext->new;
  $XPC->registerNs('osis', 'http://www.bibletechnologies.net/2003/OSIS/namespace');
  $XPC->registerNs('tei', 'http://www.crosswire.org/2013/TEIOSIS/namespace');
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
sub checkAndWriteDefaults($) {
  my $booknamesHP = shift;
  
  # Project default control files
  my @projectDefaults = (
    'bible/config.conf', 
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
      if (my $comps = $CONF->{'Companion'}) {
        foreach my $c (split(/\s*,\s*/, $comps)) {if ($c =~ /DICT$/) {$haveDICT = 1;}}
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
    my $dftype = ($dest =~ s/^(bible|dict|childrens_bible)\/// ? $1:'');
    $dest = "$MAININPD/".($dftype eq 'dict' ? $projName.'DICT/':'')."$dest";
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
        if    ($file =~ /config\.conf$/)             {&customize_conf($file, $modName, $modType, $haveDICT);}
        elsif ($file =~ /CF_usfm2osis\.txt$/)        {&customize_usfm2osis($file, $modType);}
        elsif ($file =~ /CF_addScripRefLinks\.txt$/) {&customize_addScripRefLinks($file, $booknamesHP);}
        else {&ErrorBug("Unknown customization type $dc for $file; write a customization function for this type of file.", 1);}
      }
    }
  }
}

sub customize_conf($$$$) {
  my $conf = shift;
  my $modName = shift;
  my $modType = shift;
  my $haveDICT = shift;

  if ($modType eq 'dictionary') {
    &ErrorBug("The 'dictionary' modType does not have its own config.conf file, but customize_conf was called with modType='dictionary'.", 1);
  }
 
  # Save any comments at the end of the default config.conf so they can 
  # be added back after writing the new conf file.
  my $comments = '';
  if (open(MCF, "<$READLAYER", $conf)) {
    while(<MCF>) {
      if ($comments) {$comments .= $_;}
      elsif ($_ =~ /^\Q#COMMENTS-ONLY-MUST-FOLLOW-NEXT-LINE/) {$comments = "\n";}
    }
    close(MCF);
  }
 
  # If there is any existing $modName conf that is located in a repository 
  # then start with that instead. This SWORD conf will only have one 
  # section, and any entries in the repo conf that were added by osis-
  # converters will be dropped.
  my %tmpConf; &readConfFile($conf, \%tmpConf); 
  if ($tmpConf{'system+REPOSITORY'} && $tmpConf{'system+REPOSITORY'} =~ /^http/) {
    my $swautogen = join('|', @SWORD_AUTOGEN);
    my $cfile = $tmpConf{'system+REPOSITORY'}.'/'.lc($modName).".conf";
    my $ctext = &shell("wget \"$cfile\" -q -O -", 3);
    $ctext =~ s/^(.+?)\n\[[^\]]+\].*$/$1/s;    # strip all after next section
    $ctext =~ s/^($swautogen)\s*=[^\n]*\n//mg; # strip @SWORD_AUTOGEN entries
    if ($ctext) {
      &Note("Default conf was located in REPOSITORY: $cfile", 1); &Log("$ctext\n\n");
      if (open(CNF, ">$WRITELAYER", $conf)) {
        print CNF $ctext;
        close(CNF);
      }
      else {&ErrorBug("Could not open conf $conf");}
    }
  }
  # The current $conf file is now either a copy from the SWORD 
  # REPOSITORY (minus the oc-added stuff) or the default config.conf
  
  my %newConf; &readConfFile($conf, \%newConf); 

  # Abbreviation
  &setConfValue(\%newConf, 'Abbreviation', $modName, 1);
  
  # ModuleName
  &setConfValue(\%newConf, 'ModuleName', $modName, 1);
  
  # ModDrv
  if ($modType eq 'childrens_bible') {&setConfValue(\%newConf, 'ModDrv', 'RawGenBook', 1);}
  if ($modType eq 'bible') {&setConfValue(\%newConf, 'ModDrv', 'zText', 1);}
  if ($modType eq 'other') {&setConfValue(\%newConf, 'ModDrv', 'RawGenBook', 1);}
  
  # TitleSubPublication[scope]
  foreach my $scope (@SUB_PUBLICATIONS) {
    my $sp = $scope; $sp =~ s/\s/_/g;
    &setConfValue(\%newConf, "TitleSubPublication[$sp]", "Title of Sub-Publication $sp DEF", 1);
  }
  
  # FullResourceURL
  my %c; &readConfFile($conf, \%c);
  if ($c{"system+EBOOKS"}) {
    if ($c{"system+EBOOKS"} =~ /^https?\:/) {
      my $ebdir = $c{"system+EBOOKS"}."/$modName/$modName";
      my $r = &shell("wget \"$ebdir\" -q -O -", 3);
      if ($r) {&setConfValue(\%newConf, 'FullResourceURL', $ebdir, 1);}
    }
    else {&Warn("The [system] config.conf entry should be a URL: EBOOKS=".$c{"system+EBOOKS"}, "It should be the URL where ebooks will be uploaded to. Or else it should be empty.");}
  }
  
  # Companion + [DICTMOD] section
  if ($haveDICT) {
    my $companion = $modName.'DICT';
    &setConfValue(\%newConf, 'Companion', $companion, 1);
    &setConfValue(\%newConf, "$companion+Companion", $modName, 1);
    &setConfValue(\%newConf, "$companion+ModDrv", 'RawLD4', 1);
  }
  else {&setConfValue(\%newConf, 'Companion', '', 1);}
  
  &writeConf($conf, \%newConf);
  
  # Now append the following to the new config.conf:
  # - documentation comments
  # - any [<section>] settings from the default config.conf
  # - comments from default config.conf
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
  if (open(MCF, "<$READLAYER", $conf)) {
    while(<MCF>) {
      if ($defs && $. != 1 && $_ =~ /^\[/) {$newconf .= "$defs\n"; $defs = '';}
      $newconf .= $_;
    }
    $newconf .= $comments;
    close(MCF);
  }
  else {&ErrorBug("customize_conf could not open config file $conf");}
  if ($newconf) {
    if (open(MCF, ">$WRITELAYER", $conf)) {
      print MCF $newconf;
      close(MCF);
    }
    else {&ErrorBug("customize_conf could not open config file $conf");}
  }
}

sub customize_addScripRefLinks($$) {
  my $cf = shift;
  my $booknamesHP = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  # Collect all available Bible book abbreviations
  my %abbrevs;
  # $booknamesHP is from BookNames.xml
  foreach my $bk (sort keys %{$booknamesHP}) {
    foreach my $type (sort keys %{$booknamesHP->{$bk}}) {
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
  if (!open(CFT, ">$WRITELAYER", "$cf.tmp")) {&ErrorBug("Could not open \"$cf.tmp\"", 1);}
  foreach my $cfs (sort keys %cfSettings) {
    my $pcfs = $cfs; $pcfs =~ s/^\d\d //;
    print CFT "$pcfs:".( @{$cfSettings{$cfs}} ? &toCFRegex($cfSettings{$cfs}):'')."\n";
  }
  print CFT "\n";
  foreach my $osis ( split(/\s+/, $OT_BOOKS), split(/\s+/, $NT_BOOKS) ) {
    print CFT &getAllAbbrevsString($osis, \%abbrevs);
  }
  close(CFT);
  unlink($cf);
  move("$cf.tmp", $cf);
}
sub toCFRegex($) {
  my $aP = shift;
  
  my @sorted = sort { length $a <=> length $b } @{$aP};
  # remove training spaces from segments
  foreach my $s (@sorted) {if ($s =~ s/(\S)\\?\s+$/$1/) {&Note("Removed trailing space from $s");}}
  return '('.join('|', @sorted).')';
}
sub readParatextReferenceSettings() {
  my @files = split(/\n/, &shell("find \"$MAININPD/sfm\" -type f -exec grep -q \"<RangeIndicator>\" {} \\; -print", 3));
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
sub getAllAbbrevsString($\%) {
  my $osis = shift;
  my $abbrP = shift;
  
  my $p = '';
  foreach my $abbr (sort { length($b) <=> length($a) } keys %{$abbrP}) {
    if ($abbrP->{$abbr} ne $osis || $abbr =~ /^\s*$/) {next;}
    my $a = $abbr;
    $p .= sprintf("%-6s = %s\n", $osis, $a);
    $abbrP->{$abbr} = ''; # only print each abbrev once
  }
  
  return $p;
}

# Sort USFM files by scope, type (and if type is book, then book order 
# in KJV), then filename
sub usfmFileSort($$$) {
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
  $r = $OSISBOOKS{$scopea} <=> $OSISBOOKS{$scopeb};
  if ($r) {return $r;}
  
  # sort by type, bible books last
  my $typea = $infoP->{$fa}{'type'};
  my $typeb = $infoP->{$fb}{'type'};
  $r = ($typea eq 'bible' ? 0:1) <=> ($typeb eq 'bible' ? 0:1);
  if ($r) {return $r;}
  
  # if we have bible books, sort by order in KJV
  if ($typea eq 'bible') {
    $r = $OSISBOOKS{$infoP->{$fa}{'osisBook'}} <=> $OSISBOOKS{$infoP->{$fb}{'osisBook'}};
    if ($r) {return $r;}
  }

  # finally sort by file name
  return $fa cmp $fb;
}

sub customize_usfm2osis($$) {
  my $cf = shift;
  my $modType = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  if (!open (CFF, ">>$WRITELAYER", "$cf")) {&ErrorBug("Could not open \"$cf\"", 1);}
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
        if (@{$USFM{$modType}{$f}{'periphType'}}) {
          foreach my $periphType (@{$USFM{$modType}{$f}{'periphType'}}) {
            my $osisMap = &getOsisMap($periphType, $scope);
            if (!$osisMap) {next;}
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
sub getOsisMap($) {
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
      if ($scopePath && $OSISBOOKS{$scopePath}) {
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
  if (!$periphTypeDescriptor) {
    &Error("Unrecognized peripheral name \"$periphType\"", "Change it to one of the following: " . join(', ', sort keys %PERIPH_TYPE_MAP));
    return '';
  }
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
sub copyFont($$$$$) {
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

sub scanUSFM($\%) {
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

sub scanUSFM_file($) {
  my $f = shift;
  
  my %info;
  
  &Log("Scanning SFM file: \"$f\"\n");
  
  if (!open(SFM, "<$READLAYER", $f)) {&ErrorBug("scanUSFM_file could not read \"$f\"", 1);}
  
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
      if (!@{$info{'periphType'}}) {$info{'periphType'} = [];}
      push(@{$info{'periphType'}}, $pt);
    }
    if ($_ =~ /^\\(c|ie)/) {last;}
  }
  close(SFM);
  
  if ($id =~ /^\s*(\w{2,3}).*$/) {
    my $shortid = $1;
    $info{'doConvert'} = 1;
    my $osisBook = &getOsisName($shortid, 1);
    if ($osisBook) {
      $info{'osisBook'} = $osisBook;
      $info{'type'} = 'bible';
    }
    elsif ($id =~ /^(FRT|INT|OTH|AVT|PRE|TTL)/i) { # AVT, PRE, and TTL are from old back-converted osis-converters projects
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

# Checks, and optionally updates, a param in confEntriesP.
# Returns 1 if the value is there, otherwise 0.
# Flag values are:
# 0 or empty = check only
# 1 = overwrite existing
# 2 = add to existing value (either another entry with the same name or separated by a separator)
sub setConfValue($$$$) {
  my $confEntriesP = shift;
  my $param = shift;
  my $value = shift;
  my $flag = shift;
  
  my $p = $param; my $s = ($p =~ s/^([^\+]*)\+// ? $1:'');
 
  my $sep = '';
  foreach my $ec (sort keys %MULTIVALUE_CONFIGS) {if ($p eq $ec) {$sep = $MULTIVALUE_CONFIGS{$ec};}}
  
  if ($value eq $confEntriesP->{$param}) {return 1;}
  if ($flag != 1 && $sep && $confEntriesP->{$param} =~ /(^|\s*\Q$sep\E\s*)\Q$value\E(\s*\Q$sep\E\s*|$)/) {return 1;}
  if ($flag == 2 && !$sep) {&ErrorBug("Param '$param' cannot have multiple values, yet setConfValue flag=$flag", 1);}
  
  if (!$flag) {return 0;}
  elsif ($flag == 1) {
    $confEntriesP->{$param} = $value;
  }
  elsif ($flag == 2) {
    if ($confEntriesP->{$param}) {$confEntriesP->{$param} .= $sep.$value;}
    else {$confEntriesP->{$param} = $value;}
  }
  else {&ErrorBug("Unexpected setConfValue flag='$flag'", 1);}
  return 1;
}

sub writeXMLFile($$$$) {
  my $xml = shift;
  my $file = shift;
  my $fileP = shift;
  my $clean = shift;
  
  if (open(XML, ">$file")) {
    $DOCUMENT_CACHE{$file} = '';
    my $t = $xml->toString();
    if ($clean) {$t =~ s/\n+/\n/g;}
    print XML $t;
    close(XML);
    if ($fileP) {
      if (ref($fileP)) {$$fileP = $file;}
      else {&ErrorBug("File pointer is required, not a file: $fileP");}
    }
  }
  else {&ErrorBug("Could not open XML file for writing: $file");}
}

sub osis_converters($$$) {
  my $script = shift;
  my $project_dir = shift; # THIS MUST BE AN ABSOLUTE PATH!
  my $logfile = shift;
  
  my $cmd = &escfile($script)." ".&escfile($project_dir).($logfile ? " ".&escfile($logfile):'');
  &Log("\n\n\nRUNNING OSIS_CONVERTERS:\n$cmd\n", 1);
  &Log("########################################################################\n", 1);
  &Log("########################################################################\n", 1);
  system($cmd.($logfile ? " 2>> ".&escfile($logfile):''));
}


sub readConfFromOSIS($) {
  my $osis = shift;
  
  my %entryValue;
  my $xml = $XML_PARSER->parse_file($osis);
  $entryValue{'ModuleName'} = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[1]', $xml)}[0]->getAttribute('osisWork');
  my $dict = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[2]', $xml)}[0];
  if ($dict) {$entryValue{$dict->getAttribute('osisWork').'+ModuleName'} = $dict->getAttribute('osisWork');}
  foreach my $de ($XPC->findnodes('/osis:osis[1]/osis:osisText[1]/osis:header[1]/osis:work/osis:description[starts-with(@type, "x-config")]', $xml)) {
    my $e = $de->getAttribute('type'); $e =~ s/^x\-config\-//;
    my $elit = (@{$XPC->findnodes('parent::osis:work', $de)}[0]->getAttribute('osisWork') eq $DICTMOD ? "$DICTMOD+$e":$e);
    $entryValue{$elit} = $de->textContent(); 
  }
    
  return \%entryValue;
}

sub writeConf($$) {
  my $conf = shift;
  my $entryValueP = shift;
  
  my $confdir = $conf; $confdir =~ s/([\\\/][^\\\/]+){1}$//;
  if (!-e $confdir) {make_path($confdir);}
  
  my $modname = $entryValueP->{'ModuleName'};
  
  open(XCONF, ">$WRITELAYER", $conf) || die "Could not open conf $conf\n";
  print XCONF "[$modname]\n";
  my $section = ''; my %used;
  foreach my $elit (sort { &confEntrySort($a, $b); } keys %{$entryValueP} ) {
    my $e = $elit; my $s = ($e =~ s/^(.*?)\+// ? $1:'');
    if ($s eq $modname) {$s = '';}
    if ($s && $s ne $section) {
      print XCONF "\n[$s]\n";
      $section = $s;
    }
    if ($elit =~ /(^|\+)ModuleName$/) {next;}
    foreach my $val (split(/<nx\/>/, $entryValueP->{$elit})) {
      if ($used{$elit.$val}) {next;}
      print XCONF $e."=".$val."\n";
      $used{$elit.$val}++;
    }
  }
  close(XCONF);

  return &readConfFile($conf, $entryValueP);
}
sub confEntrySort($$) {
  my $a = shift;
  my $b = shift;
    
  # Module name first
  if ($a eq 'ModuleName') {return -1;}
  if ($b eq 'ModuleName') {return 1;}
  
  # Then by section
  my $a2 = $a; my $b2 = $b;
  my $as = ($a2 =~ s/(.*?)\+// ? $1:'');
  my $bs = ($b2 =~ s/(.*?)\+// ? $1:'');
  if ($as eq $MAINMOD) {$as = '';}
  if ($bs eq $MAINMOD) {$bs = '';}
  my $r = $as cmp $bs;
  if ($r) {return $r;}
  
  # Then by entry
  return $a2 cmp $b2;
}

# Read CrossWire SWORD $conf file from swordSource. Only SWORD config 
# entries will be retained and only the initial [MODNAME] section is 
# retained. All values are according to current script/mod-type context. 
sub getSwordConfFromOSIS($) {
  my $moduleSource = shift;
  
  # Filter and contextualize OSIS config to SWORD
  my $entryValueP = &readConfFromOSIS($moduleSource);
  my %swordConf;
  foreach my $elit (sort { &confEntrySort($a, $b); } keys %{$entryValueP} ) {
    my $e = $elit; my $s = ($e =~ s/^(.*?)\+// ? $1:'');
    # skip sections other than SCRIPT_NAME and possibly DICT (if context is DICT then don't skip it) and also skip non-sword entries
    if (($s && $s ne $SCRIPT_NAME && $s ne $MOD) || &isValidConfig($elit) ne 'sword') {
      &Note("Config entry $elit will not be written to SWORD conf.");
      next;
    }
    $swordConf{$e} = &conf($elit, '', '', $entryValueP);
  }
  
  my $moddrv = $swordConf{"ModDrv"};
  if (!$moddrv) {
		&Error("No ModDrv specified in $moduleSource.", "Update the OSIS file by re-running sfm2osis.pl.", '', 1);
	}
  
	my $dp;
  my $mod = $swordConf{"ModuleName"};
	if    ($moddrv eq "RawText") {$dp = "./modules/texts/rawtext/".lc($mod)."/";}
  elsif ($moddrv eq "RawText4") {$dp = "./modules/texts/rawtext4/".lc($mod)."/";}
	elsif ($moddrv eq "zText") {$dp = "./modules/texts/ztext/".lc($mod)."/";}
	elsif ($moddrv eq "zText4") {$dp = "./modules/texts/ztext4/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom") {$dp = "./modules/comments/rawcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom4") {$dp = "./modules/comments/rawcom4/".lc($mod)."/";}
	elsif ($moddrv eq "zCom") {$dp = "./modules/comments/zcom/".lc($mod)."/";}
	elsif ($moddrv eq "HREFCom") {$dp = "./modules/comments/hrefcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawFiles") {$dp = "./modules/comments/rawfiles/".lc($mod)."/";}
	elsif ($moddrv eq "RawLD") {$dp = "./modules/lexdict/rawld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawLD4") {$dp = "./modules/lexdict/rawld4/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "zLD") {$dp = "./modules/lexdict/zld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawGenBook") {$dp = "./modules/genbook/rawgenbook/".lc($mod)."/".lc($mod);}
	else {
		&Error("ModDrv \"$moddrv\" is unrecognized.", "Change it to a recognized SWORD module type.");
	}
  # At this time (Jan 2017) JSword does not yet support zText4
  if ($moddrv =~ /^(raw)(text|com)$/i || $moddrv =~ /^rawld$/i) {
    &Error("ModDrv \"".$moddrv."\" should be changed to \"".$moddrv."4\" in config.conf.");
  }
  $swordConf{'DataPath'} = $dp;

  my $type = 'genbook';
  if ($moddrv =~ /LD/) {$type = 'dictionary';}
  elsif ($moddrv =~ /Text/) {$type = 'bible';}
  elsif ($moddrv =~ /Com/) {$type = 'commentary';}
  
  $swordConf{'Encoding'} = 'UTF-8';
  
  if ($moddrv =~ /Text/) {
    $swordConf{'Category'} = 'Biblical Texts';
    if ($moddrv =~ /zText/) {
      $swordConf{'CompressType'} = 'ZIP';
      $swordConf{'BlockType'} = 'BOOK';
    }
  }
  
  my $moduleSourceXML = $XML_PARSER->parse_file($moduleSource);
  my $sourceType = 'OSIS'; # NOTE: osis2tei.xsl still produces a TEI file having OSIS markup!
  
  if (($type eq 'bible' || $type eq 'commentary')) {$swordConf{'Scope'} = &getScope($moduleSource);}
  
  if ($moddrv =~ /LD/ && !$swordConf{"KeySort"}) {
    $swordConf{'KeySort'} = &getApproximateLangSortOrder($moduleSourceXML);
  }
  if ($moddrv =~ /LD/ && !$swordConf{"LangSortOrder"}) {
    $swordConf{'LangSortOrder'} = &getApproximateLangSortOrder($moduleSourceXML);
  }
  
  $swordConf{'SourceType'} = $sourceType;
  if ($swordConf{"SourceType"} !~ /^(OSIS|TEI)$/) {&Error("Unsupported SourceType: ".$swordConf{"SourceType"}, "Only OSIS and TEI are supported by osis-converters", 1);}
  if ($swordConf{"SourceType"} eq 'TEI') {&Warn("Some front-ends may not fully support TEI yet");}
  
  if ($swordConf{"SourceType"} eq 'OSIS') {
    my $vers = @{$XPC->findnodes('//osis:osis/@xsi:schemaLocation', $moduleSourceXML)}[0];
    if ($vers) {
      $vers = $vers->value; $vers =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
      $swordConf{'OSISVersion'} = $vers;
    }
    if ($XPC->findnodes("//osis:reference[\@type='x-glossary']", $moduleSourceXML)) {
      &setConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On', 2);
    }
  }

  if ($swordConf{"SourceType"} eq "OSIS") {
    &setConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISFootnotes', 2);
    &setConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISHeadings', 2);
    &setConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISScripref', 2);
  }
  else {
    delete($swordConf{'OSISVersion'});
    $swordConf{'GlobalOptionFilter'} =~ s/(<nx\/>)?OSIS[^<]*(?=(<|$))//g;
  }
  
  if ($moddrv =~ /LD/) {
    $swordConf{'SearchOption'} = 'IncludeKeyInSearch';
    # The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
    if ($UPPERCASE_DICTIONARY_KEYS) {$swordConf{'CaseSensitiveKeys'} = 'true';}
  }

  my @tm = localtime(time);
  $swordConf{'SwordVersionDate'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  
  return \%swordConf;
}


sub checkConfGlobals() {
  if ($MAINMOD =~ /^...CB$/ && &conf('FullResourceURL') ne 'false') {
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
  if ($DICTMOD && ($CONF->{'Companion'} || $CONF->{$DICTMOD.'+Companion'})) {
    if ($CONF->{'Companion'} ne $CONF->{$DICTMOD.'+Companion'}.'DICT') {
      &Error("config.conf companion entries are inconsistent: ".$CONF->{'Companion'}.", ".$CONF->{$DICTMOD.'+Companion'}, "Correct values should be:\n[$MOD]\nCompanion=$DICTMOD\n[$DICTMOD]\nCompanion=$MOD\n");
    }
  }
  
  if ($INPD ne $DICTINPD) {
    # Check for UI that needs localization
    foreach my $s (@SUB_PUBLICATIONS) {
      my $sp = $s; $sp =~ s/\s/_/g;
      if ($CONF->{"TitleSubPublication[$sp]"} && $CONF->{"TitleSubPublication[$sp]"} !~ / DEF$/) {next;}
      &Warn("Sub publication title config entry 'TitleSubPublication[$sp]' is not localized: ".$CONF->{"TitleSubPublication[$sp]"}, 
      "You should localize the title in config.conf with: TitleSubPublication[$sp]=Localized Title");
    }
  }
}


sub checkRequiredConfEntries($) {
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


sub getApproximateLangSortOrder($) {
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


# Formerly there was an addRevisionToCF function which wrote the SVN rev
# into the CF_ files. But this caused these input files to be rev-ed even
# when there were no changes to the file settings. This was really a
# bother. So, the rev is now written to the LOG file, and the 
# function below is used to remove the old SVN rev from the CF_ files
# if it's there. 
sub removeRevisionFromCF($) {
  my $f = shift;
  
  my $changed = 0;
  my $msg = "# osis-converters rev-";
  if (open(RCMF, "<$READLAYER", $f)) {
    if (!open(OCMF, ">$WRITELAYER", "$f.tmp")) {&ErrorBug("Could not open \"$f.tmp\".", 1);}
    my $l = 0;
    while(<RCMF>) {
      $l++;
      if ($l == 1 && $_ =~ /\Q$msg\E(\d+)/) {
        $changed = 1;
        next;
      }
      print OCMF $_;
    }
    close(RCMF);
    close(OCMF);
    
    if ($changed) {
      unlink($f);
      move("$f.tmp", $f);
    }
    else {unlink("$f.tmp");}
  }
  else {&ErrorBug("removeRevisionFromCF could not add revision to command file.");}
}


sub encodeOsisRef($) {
  my $r = shift;

  # Apparently \p{gc=L} and \p{gc=N} work different in different regex implementations.
  # So some schema checkers don't validate high order Unicode letters.
  $r =~ s/(.)/my $x = (ord($1) > 1103 ? "_".ord($1)."_":$1)/eg;
  
  $r =~ s/([^\p{gc=L}\p{gc=N}_])/my $x="_".ord($1)."_"/eg;
  $r =~ s/;/ /g;
  return $r;
}


sub decodeOsisRef($) {
  my $r = shift;
  while ($r =~ /(_(\d+)_)/) {
    my $rp = quotemeta($1);
    my $n = $2;
    $r =~ s/$rp/my $ret = chr($n);/e;
  }
  return $r;
}


# Converts cases using special translations
sub lc2($) {return &uc2(shift, 1);}
sub uc2($$) {
  my $t = shift;
  my $tolower = shift;
  
  # Form for $i: a->A b->B c->C ...
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

# Returns the OSIS book name from a Paratext or OSIS bookname. Or  
# returns nothing if argument is neither.
sub getOsisName($$) {
  my $bnm = shift;
  my $quiet = shift;
  
  # If it's already an OSIS book name, just return it
  if (!$AllBooksRE) {$AllBooksRE = join('|', @OT_BOOKS, @NT_BOOKS);}
  if ($bnm =~ /^($AllBooksRE)$/) {return $bnm;}
  
  my $bookName = "";
     if ($bnm eq "1CH") {$bookName="1Chr";}
  elsif ($bnm eq "1CO") {$bookName="1Cor";}
  elsif ($bnm eq "1JN") {$bookName="1John";}
  elsif ($bnm eq "1KI") {$bookName="1Kgs";}
  elsif ($bnm eq "1PE") {$bookName="1Pet";}
  elsif ($bnm eq "1SA") {$bookName="1Sam";}
  elsif ($bnm eq "1TH") {$bookName="1Thess";}
  elsif ($bnm eq "1TI") {$bookName="1Tim";}
  elsif ($bnm eq "2CH") {$bookName="2Chr";}
  elsif ($bnm eq "2COR"){$bookName="2Cor";}
  elsif ($bnm eq "2CO") {$bookName="2Cor";}
  elsif ($bnm eq "2JN") {$bookName="2John";}
  elsif ($bnm eq "2KI") {$bookName="2Kgs";}
  elsif ($bnm eq "2PE") {$bookName="2Pet";}
  elsif ($bnm eq "2SA") {$bookName="2Sam";}
  elsif ($bnm eq "2TH") {$bookName="2Thess";}
  elsif ($bnm eq "2TI") {$bookName="2Tim";}
  elsif ($bnm eq "3JN") {$bookName="3John";}
  elsif ($bnm eq "ACT") {$bookName="Acts";}
  elsif ($bnm eq "AMO") {$bookName="Amos";}
  elsif ($bnm eq "COL") {$bookName="Col";}
  elsif ($bnm eq "DAN") {$bookName="Dan";}
  elsif ($bnm eq "DEU") {$bookName="Deut";}
  elsif ($bnm eq "ECC") {$bookName="Eccl";}
  elsif ($bnm eq "EPH") {$bookName="Eph";}
  elsif ($bnm eq "EST") {$bookName="Esth";}
  elsif ($bnm eq "EXO") {$bookName="Exod";}
  elsif ($bnm eq "EZK") {$bookName="Ezek";}
  elsif ($bnm eq "EZR") {$bookName="Ezra";}
  elsif ($bnm eq "GAL") {$bookName="Gal";}
  elsif ($bnm eq "GEN") {$bookName="Gen";}
  elsif ($bnm eq "HAB") {$bookName="Hab";}
  elsif ($bnm eq "HAG") {$bookName="Hag";}
  elsif ($bnm eq "HEB") {$bookName="Heb";}
  elsif ($bnm eq "HOS") {$bookName="Hos";}
  elsif ($bnm eq "ISA") {$bookName="Isa";}
  elsif ($bnm eq "JAS") {$bookName="Jas";}
  elsif ($bnm eq "JDG") {$bookName="Judg";}
  elsif ($bnm eq "JER") {$bookName="Jer";}
  elsif ($bnm eq "JHN") {$bookName="John";}
  elsif ($bnm eq "JOB") {$bookName="Job";}
  elsif ($bnm eq "JOL") {$bookName="Joel";}
  elsif ($bnm eq "JON") {$bookName="Jonah";}
  elsif ($bnm eq "JOS") {$bookName="Josh";}
  elsif ($bnm eq "JUD") {$bookName="Jude";}
  elsif ($bnm eq "LAM") {$bookName="Lam";}
  elsif ($bnm eq "LEV") {$bookName="Lev";}
  elsif ($bnm eq "LUK") {$bookName="Luke";}
  elsif ($bnm eq "MAL") {$bookName="Mal";}
  elsif ($bnm eq "MAT") {$bookName="Matt";}
  elsif ($bnm eq "MIC") {$bookName="Mic";}
  elsif ($bnm eq "MRK") {$bookName="Mark";}
  elsif ($bnm eq "NAM") {$bookName="Nah";}
  elsif ($bnm eq "NEH") {$bookName="Neh";}
  elsif ($bnm eq "NUM") {$bookName="Num";}
  elsif ($bnm eq "OBA") {$bookName="Obad";}
  elsif ($bnm eq "PHM") {$bookName="Phlm";}
  elsif ($bnm eq "PHP") {$bookName="Phil";}
  elsif ($bnm eq "PROV") {$bookName="Prov";}
  elsif ($bnm eq "PRO") {$bookName="Prov";}
  elsif ($bnm eq "PSA") {$bookName="Ps";}
  elsif ($bnm eq "REV") {$bookName="Rev";}
  elsif ($bnm eq "ROM") {$bookName="Rom";}
  elsif ($bnm eq "RUT") {$bookName="Ruth";}
  elsif ($bnm eq "SNG") {$bookName="Song";}
  elsif ($bnm eq "TIT") {$bookName="Titus";}
  elsif ($bnm eq "ZEC") {$bookName="Zech";}
  elsif ($bnm eq "ZEP") {$bookName="Zeph";}
  elsif (!$quiet) {&Error("Unrecognized Bookname:\"$bnm\"", "Only Paratext and OSIS Bible book abbreviations are recognized.");}

  return $bookName;
}

sub getCanon($\%\%\%\@) {
  my $vsys = shift;
  my $canonPP = shift;     # hash pointer: OSIS-book-name => Array (base 0!!) containing each chapter's max-verse number
  my $bookOrderPP = shift; # hash pointer: OSIS-book-name => position (Gen = 1, Rev = 66)
  my $testamentPP = shift; # hash pointer: OSIS-nook-name => 'OT' or 'NT'
  my $bookArrayPP = shift; # array pointer: OSIS-book-names in verse system order starting with index 1!!
  
  if (! %{$CANON_CACHE{$vsys}}) {
    if (!&isValidVersification($vsys)) {return 0;}
    
    my $vk = new Sword::VerseKey();
    $vk->setVersificationSystem($vsys);
    
    for (my $bk = 0; my $bkname = $vk->getOSISBookName($bk); $bk++) {
      my $t, $bkt;
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

  return 1;
}


sub isValidVersification($) {
  my $vsys = shift;
  
  my $vsmgr = Sword::VersificationMgr::getSystemVersificationMgr();
  my $vsyss = $vsmgr->getVersificationSystems();
  foreach my $vsys (@$vsyss) {if ($vsys->c_str() eq $vsys) {return 1;}}
  
  return 0;
}


sub sortSearchTermKeys($$) {
  my $aa = shift;
  my $bb = shift;
  
  while ($aa =~ /["\s]+(<[^>]*>\s*)+$/) {$aa =~ s/["\s]+(<[^>]*>\s*)+$//;}
  while ($bb =~ /["\s]+(<[^>]*>\s*)+$/) {$bb =~ s/["\s]+(<[^>]*>\s*)+$//;}
  
  length($bb) <=> length($aa)
}


sub changeNodeText($$) {
  my $node = shift;
  my $new = shift;
  foreach my $r ($node->childNodes()) {$r->unbindNode();}
  if ($new) {$node->appendText($new)};
}


sub usfm3GetAttribute($$$) {
  my $value = shift;
  my $attribute = shift;
  my $default = shift;
  
  if (!$attribute) {$attribute = $default;}
  
  my $atl = $value;
  if ($atl =~ s/^.*?\|//) {
    my $aname = $default;
    while ($atl =~ s/\s*([^\s="]+)\s*=\s*"([^"]*)"//) {
      $aname = $1;
      $aval = $2;
      if ($aname eq $attribute) {return $aval;}
    }
    return ($aname eq $attribute ? $atl:'');
  }
  
  return '';
}


sub convertExplicitGlossaryElements(\@) {
  my $indexElementsP = shift;
  
  foreach my $index (@{$indexElementsP}) {
    my $linktext = $index->getAttribute("level1");
    my $entryname = ($linktext =~ s/\|.*$// ? &usfm3GetAttribute($index->getAttribute("level1"), 'lemma', 'lemma'):'');
    my $cxstring = &getIndexContextString($index);
    my $original = $index->parentNode->toString();
    
    my $result;
    my @pt = $XPC->findnodes("preceding::text()[1]", $index);
    if (@pt != 1 || @pt[0]->data !~ /\Q$linktext\E$/) {
      &ErrorBug("Could not locate preceding text node for explicit glossary entry \"$index\" ($linktext !~ ".@pt[0]->data);
      &recordExplicitGlossFail($index, $linktext, $cxstring);
      next;
    }
    my $tn = @pt[0];
    
    # Check preceding text node
    my $t = $tn->data;
    if ($t !~ s/\Q$linktext\E$//) {
      &ErrorBug("Index tag $index in ".$index->parentNode->toString()." is not preceded by '$linktext'.");
      &recordExplicitGlossFail($index, $linktext, $cxstring);
      next;
    }
    
    if ($entryname) {
      # Write reference
      my $newRefElement = $XML_PARSER->parse_balanced_chunk(
        '<reference osisRef="'.$DICTMOD.':'.&encodeOsisRef($entryname).'" type="x-gloss'.($MOD eq $DICTMOD ? 'link':'ary').'">'.$linktext.'</reference>'
      );
      $index->parentNode->insertBefore($newRefElement, $index);
      $tn->setData($t);
    }
    else {
      # Find and write the matching reference
      my @tns; push(@tns, $tn);
      &addDictionaryLinks(\@tns, "$linktext$cxstring", (@{$XPC->findnodes('ancestor::osis:div[@type="glossary"]', $tn)}[0] ? 1:0));
    }
    
    # Check and record the reference
    if ($original eq $index->parentNode->toString()) {
      &recordExplicitGlossFail($index, $linktext, $cxstring);
      next;
    }
    my $osisRef = @{$XPC->findnodes("preceding::reference[1]", $index)}[0]->getAttribute("osisRef");
    $EXPLICIT_GLOSSARY{$linktext}{&decodeOsisRef($osisRef)}++;
    
    # Remove index element if successful
    $index->parentNode->removeChild($index);
  }
}

sub recordExplicitGlossFail($$$) {
  my $index = shift;
  my $level = shift;
  my $cxstring = shift;
  
  my $str = $cxstring; $str =~ s/^(.*?)\:CXBEFORE\:(.*?)\:CXAFTER\:(.*)$/$2<index\/>$3/;

  $EXPLICIT_GLOSSARY{$level}{"Failed"}{'count'}++;
  $EXPLICIT_GLOSSARY{$level}{"Failed"}{'context'}{$str}++;
  
  &Error("Failed to convert explicit glossary index: $index", 
"<>Add the proper entry to DictionaryWords.xml to match this text 
and create a hyperlink to the correct glossary entry. If desired you can 
use the attribute 'onlyExplicit' to match this term only where it is 
explicitly marked in the text as a glossary index, and nowhere else. 
Without the onlyExplicit attribute, you are able to hyperlink the term 
everywhere it appears in the text.");
}

# This returns the context surrounding an index milestone, which is 
# often necessary to determine the intended index target. Since this 
# error is commonly seen for example when level1 should be "Ark of the 
# Covenant": 
# "This is some Bible text concerning the Ark of the Covenant<index level1="Covenant"/>"
# The index alone does not result in the intended match, but using
# context gives us an excellent chance of correcting this common mistake. 
# The risk of unintentionally making a 'too-specific' match may exist, 
# but this is unlikely and would probably not be incorrect anyway.
sub getIndexContextString($) {
  my $i = shift;
  
  my $cbefore = '';
  my $tn = $i;
  do {
    $tn = @{$XPC->findnodes("(preceding-sibling::text()[1] | preceding-sibling::*[1][not(self::osis:title) and not(self::osis:p) and not(self::osis:div)]//text()[last()])[last()]", $tn)}[0];
    if ($tn) {$cbefore = $tn->data.$cbefore;}
    $cbefore =~ s/\s+/ /gs;
    my $n =()= $cbefore =~ /\S+/g;
  } while ($tn && $n < $MAX_MATCH_WORDS);
  
  my $m = ($MAX_MATCH_WORDS-1);
  $cbefore =~ s/^.*?(\S+(\s+\S+){1,$m})$/$1/;
  
  if (!$cbefore || $cbefore =~ /^\s*$/) {&Error("Could not determine context before $i");}
  
  my $cafter = '';
  my $tn = $i;
  do {
    $tn = @{$XPC->findnodes("(following-sibling::text()[1] | following-sibling::*[1][not(self::osis:title) and not(self::osis:p) and not(self::osis:div)]//text()[1])[1]", $tn)}[0];
    if ($tn) {$cafter .= $tn->data;}
    $cafter =~ s/\s+/ /gs;
    my $n =()= $cafter =~ /\S+/g;
  } while ($tn && $n < $MAX_MATCH_WORDS);
  
  my $m = ($MAX_MATCH_WORDS-1);
  $cafter =~ s/^(\s*\S+(\s+\S+){1,$m}).*?$/$1/;
  
  return ":CXBEFORE:$cbefore:CXAFTER:$cafter";
}

# Add dictionary links as described in $DWF to the nodes pointed to 
# by $eP array pointer. Expected node types are element or text.
sub addDictionaryLinks(\@$$) {
  my $eP = shift; # array of text-nodes or text-node parent elements from a document (Note: node element child elements are not touched)
  my $ifExplicit = shift; # text context if the node was marked in the text as a glossary link
  my $isGlossary = shift; # true if the nodes are in a glossary (See-Also linking)
  
  my $bookOrderP;
  foreach my $node (@$eP) {
    my $glossaryNodeContext;
    my $glossaryScopeContext;
    
    if ($isGlossary) {
      if (!$bookOrderP) {&getCanon(&getVerseSystemOSIS($node), NULL, \$bookOrderP, NULL)}
      $glossaryNodeContext = &getNodeContext($node);
      if (!$glossaryNodeContext) {next;}
      my @gs; foreach my $gsp ( split(/\s+/, &getGlossaryScopeAttribute($node)) ) {
        push(@gs, ($gsp =~ /\-/ ? @{&scopeToBooks($gsp, $bookOrderP)}:$gsp));
      }
      $glossaryScopeContext = join('+', @gs);
      if (!$NoOutboundLinks{'haveBeenRead'}) {
        foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', $DWF)) {
          foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
        }
        $NoOutboundLinks{'haveBeenRead'}++;
      }
      if ($NoOutboundLinks{&entry2osisRef($MOD, $glossaryNodeContext)}) {return;}
    }
  
    my @textchildren;
    my $container = ($node->nodeType == XML::LibXML::XML_TEXT_NODE ? $node->parentNode:$node);
    if ($node->nodeType == XML::LibXML::XML_TEXT_NODE) {push(@textchildren, $node);}
    else {@textchildren = $XPC->findnodes('child::text()', $container);}
    if (&conf('ModDrv') =~ /LD/ && $XPC->findnodes("self::$KEYWORD", $container)) {next;}
    my $text, $matchedPattern;
    foreach my $textchild (@textchildren) {
      $text = $textchild->data();
      if ($text =~ /^\s*$/) {next;}
      my $done;
      do {
        $done = 1;
        my @parts = split(/(<reference.*?<\/reference[^>]*>)/, $text);
        foreach my $part (@parts) {
          if ($part =~ /<reference.*?<\/reference[^>]*>/ || $part =~ /^[\s\n]*$/) {next;}
          if ($matchedPattern = &addDictionaryLink(\$part, $textchild, $ifExplicit, $glossaryNodeContext, $glossaryScopeContext)) {
            if (!$ifExplicit) {$done = 0;}
          }
        }
        $text = join('', @parts);
      } while(!$done);
      $text =~ s/<reference [^>]*osisRef="REMOVE_LATER"[^>]*>(.*?)<\/reference>/$1/sg;
      
#&Debug("BEFORE=".$textchild->data()."\nAFTER =".$text."\n\n");
      
      # sanity check
      my $check = $text;
      $check =~ s/<\/?reference[^>]*>//g;
      if ($check ne $textchild->data()) {
        &ErrorBug("Bible text changed during glossary linking!\nBEFORE=".$textchild->data()."\nAFTER =$check", 1);
      }
      
      # apply new reference tags back to DOM
      foreach my $childnode (split(/(<reference[^>]*>.*?<\/reference[^>]*>)/s, $text)) {
        my $newRefElement = '';
        my $t = $childnode; 
        if ($t =~ s/(<reference[^>]*>)(.*?)(<\/reference[^>]*>)/$2/s) {
          my $refelem = "$1 $3";
          $newRefElement = $XML_PARSER->parse_balanced_chunk($refelem);
        }
        my $newTextNode = XML::LibXML::Text->new($t);
        if ($newRefElement) {
          $newRefElement->firstChild->insertBefore($newTextNode, NULL);
          $newRefElement->firstChild->removeChild($newRefElement->firstChild->firstChild); # remove the originally necessary ' ' in $refelem 
        }
        my $newChildNode = ($newRefElement ? $newRefElement:$newTextNode);
        $textchild->parentNode->insertBefore($newChildNode, $textchild);
      }
      $textchild->unbindNode(); 
    }
  }
}


# Some of the following routines take either nodes or module names as inputs.
# Note: Whereas //osis:osisText[1] is TRULY, UNBELIEVABLY SLOW, /osis:osis/osis:osisText[1] is fast
sub getModNameOSIS($) {
  my $node = shift; # might already be string mod name- in that case just return it
  if (!ref($node)) {
    my $modname = $node; # node is not a ref() so it's a modname
    if (!$DOCUMENT_CACHE{$modname}) {
      my $osis = ($SCRIPT_NAME =~ /^(osis2sword|osis2GoBible|osis2ebooks|osis2html)$/ ? $INOSIS:$OSIS);
      if (! -e $osis) {&ErrorBug("getModNameOSIS: No current osis file to read for $modname.", 1);}
      &initDocumentCache($XML_PARSER->parse_file($osis));
      if (!$DOCUMENT_CACHE{$modname}) {&ErrorBug("getModNameOSIS: header of osis $osis does not include modname $modname.", 1);}
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
  
  return $DOCUMENT_CACHE{$headerDoc}{'getModNameOSIS'};
}
# Associated functions use this cached header data for a big speedup. 
# The cache is cleared and reloaded the first time a node is referenced 
# from an OSIS file URI.
sub initDocumentCache($) {
  my $xml = shift; # must be a document node
  
  my $dbg = "initDocumentCache: ";
  
  my $headerDoc = $xml->URI;
  undef($DOCUMENT_CACHE{$headerDoc});
  $DOCUMENT_CACHE{$headerDoc}{'xml'} = $xml;
  my $shd = $headerDoc; $shd =~ s/^.*\///; $dbg .= "document=$shd ";
  my $osisIDWork = @{$XPC->findnodes('/osis:osis/osis:osisText[1]', $xml)}[0]->getAttribute('osisIDWork');
  $DOCUMENT_CACHE{$headerDoc}{'getModNameOSIS'} = $osisIDWork;
  
  # Save data by MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  undef($DOCUMENT_CACHE{$osisIDWork});
  $DOCUMENT_CACHE{$osisIDWork}{'xml'}                = $xml;
  $dbg .= "selfmod=$osisIDWork ";
  $DOCUMENT_CACHE{$osisIDWork}{'getModNameOSIS'}     = $osisIDWork;
  $DOCUMENT_CACHE{$osisIDWork}{'getRefSystemOSIS'}   = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[@osisWork="'.$osisIDWork.'"]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getVerseSystemOSIS'} = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type!="x-glossary"]]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getVerseSystemOSIS'} =~ s/^Bible.//i;
  $DOCUMENT_CACHE{$osisIDWork}{'getBibleModOSIS'}    = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type!="x-glossary"]]', $xml)}[0]->getAttribute('osisWork');
  my $dict = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-glossary"]]', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getDictModOSIS'}     = ($dict ? $dict->getAttribute('osisWork'):'');
  my %books; foreach my $bk (map($_->getAttribute('osisID'), $XPC->findnodes('//osis:div[@type="book"]', $xml))) {$books{$bk}++;}
  $DOCUMENT_CACHE{$osisIDWork}{'getBooksOSIS'} = \%books;
  my $scope = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[1]/osis:scope', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getScopeOSIS'} = ($scope ? $scope->textContent():'');
  
  # Save companion data by its MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  my @works = $XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work', $xml);
  foreach my $work (@works) {
    my $w = $work->getAttribute('osisWork');
    if ($w eq $osisIDWork) {next;}
    undef($DOCUMENT_CACHE{$w});
    $DOCUMENT_CACHE{$w}{'getRefSystemOSIS'} = @{$XPC->findnodes('./osis:refSystem', $work)}[0]->textContent;
    $dbg .= "compmod=$w ";
    $DOCUMENT_CACHE{$w}{'getVerseSystemOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getVerseSystemOSIS'};
    $DOCUMENT_CACHE{$w}{'getBibleModOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getBibleModOSIS'};
    $DOCUMENT_CACHE{$w}{'getDictModOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getDictModOSIS'};
    $DOCUMENT_CACHE{$w}{'xml'} = ''; # force a re-read when again needed (by existsElementID)
  }
  &Debug("$dbg\n");
  
  return $DOCUMENT_CACHE{$osisIDWork}{'getModNameOSIS'};
}
# IMPORTANT: the osisCache lookup can ONLY be called on $modname after 
# a call to getModNameOSIS($modname), since getModNameOSIS($modname) 
# is where the cache is written.
sub osisCache($$) {
  my $func = shift;
  my $modname = shift;

  if (exists($DOCUMENT_CACHE{$modname}{$func})) {return $DOCUMENT_CACHE{$modname}{$func};}
  &Error("DOCUMENT_CACHE failure: $modname $func\n");
  return '';
}
sub getModXmlOSIS($) {
  my $mod = shift;
  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    undef($DOCUMENT_CACHE{$mod});
    &getModNameOSIS($mod);
    $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  }
  return $xml;
}
sub getRefSystemOSIS($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('getRefSystemOSIS', $mod);
  if (!$return) {
    &ErrorBug("getRefSystemOSIS: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getVerseSystemOSIS($) {
  my $mod = &getModNameOSIS(shift);
  if ($mod eq 'KJV') {return 'KJV';}
  if ($mod eq $MOD) {return &conf('Versification');}
  my $return = &osisCache('getVerseSystemOSIS', $mod);
  if (!$return) {
    &ErrorBug("getVerseSystemOSIS: No document node for \"$mod\"!");
    return &conf('Versification');
  }
  return $return;
}
sub getBibleModOSIS($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('getBibleModOSIS', $mod);
  if (!$return) {
    &ErrorBug("getBibleModOSIS: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getDictModOSIS($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('getDictModOSIS', $mod);
  if (!$return) {
    &ErrorBug("getDictModOSIS: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisRefWork($) {return &getModNameOSIS(shift);}
sub getOsisIDWork($)  {return &getModNameOSIS(shift);}
sub getBooksOSIS($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('getBooksOSIS', $mod);
  if (!$return) {
    &ErrorBug("getBooksOSIS: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getScopeOSIS($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('getScopeOSIS', $mod);
  if (!$return) {
    &ErrorBug("getScopeOSIS: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getAltVersesOSIS($) {
  my $mod = &getModNameOSIS(shift);
  
  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    &ErrorBug("getAltVersesOSIS: No xml document node!");
    return '';
  }
  
  if (!$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}) {
    $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'exists'}++;
    &Debug("Cache failed for getAltVersesOSIS: $mod\n");
    
    # VSYS changes are recorded in the OSIS file with milestone elements written by applyVsysFromTo()
    my @maps = (
      ['fixed2Source',  'movedto_vs', 'osisRef',     'annotateRef'],
      ['fixedMissing',  'missing_vs', 'osisRef',     ''],
      ['source2Fitted', 'fitted_vs',  'annotateRef', 'osisRef'],
    );
    foreach my $map (@maps) {
      my %hash;
      foreach my $e ($XPC->findnodes('//osis:milestone[@type="'.$VSYS{@$map[1]}.'"]', $xml)) {
        $hash{$e->getAttribute(@$map[2])} = $e->getAttribute(@$map[3]);
      }
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{@$map[0]} = \%hash;
    }
    
    # fixed2Fitted is a convenience map since it is the same as source2Fitted{fixed2Source{verse}}
    foreach my $fixed (sort keys (%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}})) {
      my $source = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}{$fixed};
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Fitted'}{$fixed} = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'source2Fitted'}{$source};
    }
    
    use Data::Dumper; &Debug("getAltVersesOSIS = ".Dumper(\%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}})."\n", 1);
  }
  
  return \%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}};
}
sub isChildrensBible($) {
  my $mod = &getModNameOSIS(shift);
  return (&osisCache('getRefSystemOSIS', $mod) =~ /^Book\w+CB$/ ? 1:0);
}
sub isBible($) {
  my $mod = &getModNameOSIS(shift);
  return (&osisCache('getRefSystemOSIS', $mod) =~ /^Bible/ ? 1:0);
}
sub isDict($) {
  my $mod = &getModNameOSIS(shift);
  return (&osisCache('getRefSystemOSIS', $mod) =~ /^Dict/ ? 1:0);
}

# Take in osisRef and map the whole thing. Mapping gaps are healed and
# PART verses are always treated as whole verses.
sub mapOsisRef($$$) {
  my $mapP = shift;
  my $map = shift;
  my $osisRef = shift;
  
  my @mappedOsisRefs;
  foreach my $ref (split(/\s+/, $osisRef)) {
    my @mappedOsisIDs;
    foreach my $osisID (split(/\s+/, &osisRef2osisID($ref))) {
      my $idin = $osisID;
      $idin =~ s/!PART$//;
      my $id = $idin;
      if    ($mapP->{$map}{$idin})        {$id = $mapP->{$map}{$idin};}
      elsif ($mapP->{$map}{"$idin!PART"}) {$id = $mapP->{$map}{"$idin!PART"}; push(@mappedOsisIDs, $idin);}
      $id =~ s/!PART$//; # if part is included, include the whole thing
      push(@mappedOsisIDs, $id);
    }
    push(@mappedOsisRefs, &fillGapsInOsisRef(&osisID2osisRef(join(' ', &normalizeOsisID(\@mappedOsisIDs)))));
  }

  return join(' ', @mappedOsisRefs);
}

# Take an osisRef's starting and ending point, and return an osisRef 
# that covers the entire range between them. This can be used to 'heal' 
# missing verses in mapped ranges.
sub fillGapsInOsisRef() {
  my $osisRef = shift;
  
  my @id = split(/\s+/, &osisRef2osisID($osisRef));
  if ($#id == 0) {return $osisRef;}
  return @id[0].'-'.@id[$#id];
}

sub getModuleOutputDir($) {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  
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
sub getModuleOsisFile($$) {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  my $reportFunc = shift;
  
  my $mof = &getModuleOutputDir($mod)."/$mod.xml";
  if ($reportFunc eq 'quiet' || -e $mof) {return $mof;}
  
  if ($reportFunc) {&$reportFunc("Module OSIS file does not exist: $mof");}
  return '';
}


# Searches and replaces $$tP text for a single dictionary link, according 
# to the $DWF file, and logs any result. If a match is found, the proper 
# reference tags are inserted, and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$$\@) {
  my $textP = shift;
  my $textNode = shift;
  my $explicitContext = shift; # context string if the node was marked in the text as a glossary link
  my $glossaryNodeContext = shift; # for SeeAlso links only
  my $glossaryScopeContext = shift; # for SeeAlso links only

  my $matchedPattern = '';
  
  # Cache match related info
  if (!@MATCHES) {
    my $notes;
    $OT_CONTEXTSP =  &getContextAttributeHash('OT');
    $NT_CONTEXTSP =  &getContextAttributeHash('NT');
    my @ms = $XPC->findnodes('//dw:match', $DWF);
    foreach my $m (@ms) {
      my %minfo;
      $minfo{'node'} = $m;
      $minfo{'notExplicit'} = &attributeIsSet('notExplicit', $m);
      $minfo{'onlyExplicit'} = &attributeIsSet('onlyExplicit', $m);
      $minfo{'onlyOldTestament'} = &attributeIsSet('onlyOldTestament', $m);
      $minfo{'onlyNewTestament'} = &attributeIsSet('onlyNewTestament', $m);
      $minfo{'multiple'} = @{$XPC->findnodes("ancestor-or-self::*[\@multiple][1]/\@multiple", $m)}[0]; if ($minfo{'multiple'}) {$minfo{'multiple'} = $minfo{'multiple'}->value;}
      $minfo{'dontLink'} = &attributeIsSet('dontLink', $m);
      $minfo{'context'} = &getScopedAttribute('context', $m);
      $minfo{'contexts'} = &getContextAttributeHash($minfo{'context'}, \$notes);
      $minfo{'notContext'} = &getScopedAttribute('notContext', $m);
      $minfo{'notContexts'} = &getContextAttributeHash($minfo{'notContext'}, \$notes);
      $minfo{'notXPATH'} = &getScopedAttribute('notXPATH', $m);
      $minfo{'XPATH'} = &getScopedAttribute('XPATH', $m);
      $minfo{'osisRef'} = @{$XPC->findnodes('ancestor::dw:entry[@osisRef][1]', $m)}[0]->getAttribute('osisRef');
      $minfo{'name'} = @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m)}[0]->textContent;
      # A <match> element should never be applied to any textnode inside the glossary entry (or entries) which the match pertains to or any duplicate entries thereof.
      # This is necessary to insure an entry will never contain links to itself or to a duplicate.
      my @osisRef = split(/\s+/, @{$XPC->findnodes('ancestor::dw:entry[1]', $m)}[0]->getAttribute('osisRef'));
      foreach my $ref (@osisRef) {$minfo{'skipRootID'}{&getRootID($ref)}++;}
      
      # test match pattern, so any errors with it can be found right away
      if ($m->textContent !~ /(?<!\\)\(.*(?<!\\)\)/) {
        &Error("Skipping match \"$m\" becauase it is missing capture parentheses", "Add parenthesis around the match text which should be linked.");
        next;
      }
      my $test = "testme"; my $is; my $ie;
      if (&glossaryMatch(\$test, $m, \$is, \$ie) == 2) {next;}
      
      push(@MATCHES, \%minfo);
      
      my @wds = split(/\s+/, $minfo{'name'});
      if (@wds > $MAX_MATCH_WORDS) {$MAX_MATCH_WORDS = @wds; &Note("Setting MAX_MATCH_WORDS to $MAX_MATCH_WORDS");}
    }
    #if ($notes) {&Log("\n".('-' x 80)."\n".('-' x 80)."\n\n$notes\n");}
  }
  
  my $context;
  my $multiples_context;
  if ($glossaryNodeContext) {$context = $glossaryNodeContext; $multiples_context = $glossaryNodeContext;}
  else {
    $context = &bibleContext($textNode);
    $multiples_context = $context;
    $multiples_context =~ s/^(\w+\.\d+).*$/$1/; # reset multiples each chapter
  }
  if ($multiples_context ne $LAST_CONTEXT) {undef %MULTIPLES; &Log("--> $multiples_context\n", 2);}
  $LAST_CONTEXT = $multiples_context;
  
  my $contextIsOT = &inContext($context, $OT_CONTEXTSP);
  my $contextIsNT = &inContext($context, $NT_CONTEXTSP);
  my @contextNote = $XPC->findnodes("ancestor::osis:note", $textNode);
  
  my $a;
  foreach my $m (@MATCHES) {
    my $removeLater = $m->{'dontLink'};
#@DICT_DEBUG = ($context, @{$XPC->findnodes('preceding-sibling::dw:name[1]', $m->{'node'})}[0]->textContent()); @DICT_DEBUG_THIS = ("Gen.49.10.10", decode("utf8", "АҲД САНДИҒИ"));
#@DICT_DEBUG = ($textNode->data); @DICT_DEBUG_THIS = (decode("utf8", "Хөрмәтле укучылар, < Борынгы Шерык > сезнең игътибарга Изге Язманың хәзерге татар телендә беренче тапкыр нәшер ителгән тулы җыентыгын тәкъдим итәбез."));
#my $nodedata; foreach my $k (sort keys %{$m}) {if ($k !~ /^(node|contexts|notContexts|skipRootID)$/) {$nodedata .= "$k: ".$m->{$k}."\n";}}  use Data::Dumper; $nodedata .= "contexts: ".Dumper(\%{$m->{'contexts'}}); $nodedata .= "notContexts: ".Dumper(\%{$m->{'notContexts'}});
#&dbg(sprintf("\nNode(type %s, %s):\nText: %s\nMatch: %s\n%s", $textNode->parentNode->nodeType, $context, $$textP, $m->{'node'}, $nodedata));
    
    my $filterMultiples = (!$explicitContext && $m->{'multiple'} !~ /^true$/i);
    my $key = ($filterMultiples ? &getMultiplesKey($m, $m->{'multiple'}, \@contextNote):'');
    
    if ($explicitContext && $m->{'notExplicit'}) {&dbg("filtered at 00\n\n"); next;}
    elsif (!$explicitContext && $m->{'onlyExplicit'}) {&dbg("filtered at 01\n\n"); next;}
    else {
      if ($glossaryNodeContext && $m->{'skipRootID'}{&getRootID($glossaryNodeContext)}) {&dbg("05\n\n"); next;} # never add glossary links to self
      if (!$contextIsOT && $m->{'onlyOldTestament'}) {&dbg("filtered at 10\n\n"); next;}
      if (!$contextIsNT && $m->{'onlyNewTestament'}) {&dbg("filtered at 20\n\n"); next;}
      if ($filterMultiples) {
        if (@contextNote > 0) {if ($MULTIPLES{$key}) {&dbg("filtered at 35\n\n"); next;}}
        # $removeLater disallows links within any phrase that was previously skipped as a multiple.
        # This helps prevent matched, but unlinked, phrases inadvertantly being torn into smaller, likely irrelavent, entry links.
        elsif ($MULTIPLES{$key}) {&dbg("filtered at 40\n\n"); $removeLater = 1;}
      }
      if ($m->{'context'}) {
        my $gs  = ($glossaryScopeContext ? 1:0);
        my $ic  = &inContext($context, $m->{'contexts'});
        my $igc = ($gs ? &inContext($glossaryScopeContext, $m->{'contexts'}):0);
        if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {&dbg("filtered at 50 (gs=$gs, ic=$ic, igc=$igc)\n\n"); next;}
      }
      if ($m->{'notContext'}) {
        if (&inContext($context, $m->{'notContexts'})) {&dbg("filtered at 60\n\n"); next;}
      }
      if ($m->{'XPATH'}) {
        my $tst = @{$XPC->findnodes($m->{'XPATH'}, $textNode)}[0];
        if (!$tst) {&dbg("filtered at 70\n\n"); next;}
      }
      if ($m->{'notXPATH'}) {
        $tst = @{$XPC->findnodes($m->{'notXPATH'}, $textNode)}[0];
        if ($tst) {&dbg("filtered at 80\n\n"); next;}
      }
    }
    
    my $is; my $ie;
    if (&glossaryMatch($textP, $m->{'node'}, \$is, \$ie, $explicitContext)) {next;}
    if ($is == $ie) {
      &ErrorBug("Match result was zero width!: \"".$m->{'node'}->textContent."\"");
      next;
    }
    
    $MATCHES_USED{$m->{'node'}->unique_key}++;
    $matchedPattern = $m->{'node'}->textContent;
    my $osisRef = ($removeLater ? 'REMOVE_LATER':$m->{'osisRef'});
    my $attribs = "osisRef=\"$osisRef\" type=\"".(&conf('ModDrv') =~ /LD/ ? 'x-glosslink':'x-glossary')."\"";
    my $match = substr($$textP, $is, ($ie-$is));
    
    substr($$textP, $ie, 0, "</reference>");
    substr($$textP, $is, 0, "<reference $attribs>");
    
    if (!$removeLater) {
      # record hit...
      $EntryHits{$m->{'name'}}++;
      
      my $logContext = $context;
      $logContext =~ s/\..*$//; # keep book/entry only
      $LINK_OSISREF{$m->{'osisRef'}}{'context'}{$logContext}++;
      $LINK_OSISREF{$m->{'osisRef'}}{'matched'}{$match}++;
      $LINK_OSISREF{$m->{'osisRef'}}{'total'}++;

      if ($filterMultiples) {$MULTIPLES{$key}++;}
    }
    
    last;
  }
 
  return $matchedPattern;
}

sub getMultiplesKey($$\@) {
  my $m = shift;
  my $multiple = shift;
  my $contextNoteP = shift;
  
  my $base = ($multiple eq 'match-per-chapter' ? $m->{'node'}->unique_key:$m->{'osisRef'});
  if (@{$contextNoteP} > 0) {return $base . ',' .@{$contextNoteP}[$#$contextNoteP]->unique_key;}
  else {return $base;}
}

sub getRootID($) {
  my $osisID = shift;
  
  $osisID =~ s/(^[^\:]+\:|\.dup\d+$)//g;
  return lc(&decodeOsisRef($osisID));
}

# Look for a single match $m in $$textP and set its start/end positions
# if one is found. Returns 0 if a match was found; or else 1 if no 
#  match was found, or 2 on error.
sub glossaryMatch(\$$\$\$$) {
  my $textP = shift;
  my $m = shift;
  my $isP = shift;
  my $ieP = shift;
  my $explicitContext = shift;
  
  my $index; my $cxbefore; my $cxafter;
  if ($explicitContext =~ /^(.*?)\:CXBEFORE\:(.*?)\:CXAFTER\:(.*)$/) {$index = $1; $cxbefore = $2; $cxafter = $3;}
  
  my $p = $m->textContent;
  if ($p !~ /^\s*\/(.*)\/(\w*)\s*$/) {
    &ErrorBug("Bad match regex: $p !~ /^\s*\/(.*)\/(\w*)\s*\$/");
    &dbg("80\n");
    return 2;
  }
  my $pm = $1; my $pf = $2;
  
  # handle PUNC_AS_LETTER word boundary matching issue
  if ($PUNC_AS_LETTER) {
    $pm =~ s/\\b/(?:^|[^\\w$PUNC_AS_LETTER]|\$)/g;
  }
  
  # handle xml decodes
  $pm = decode_entities($pm);
  
  # handle case insensitive with the special uc2() since Perl can't handle Turkish-like locales
  my $t = ($explicitContext ? "$cxbefore$cxafter":$$textP);
  my $i = $pf =~ s/i//;
  $pm =~ s/(\\Q)(.*?)(\\E)/my $r = quotemeta($i ? &uc2($2):$2);/ge;
  if ($i) {
    $t = &uc2($t);
  }
  if ($pf =~ /(\w+)/) {
    &Error("Regex flag \"$1\" not supported in \"".$m->textContent."\"", "Only Perl regex flags are supported.");
  }
 
  # finally do the actual MATCHING...
  &dbg("pattern matching ".($t !~ /$pm/ ? "failed!":"success!").": \"$t\" =~ /$pm/\n"); 
  if ($t !~ /$pm/) {return 1;}

  $$isP = $-[$#+];
  $$ieP = $+[$#+];
  
  # if a (?'link'...) named group 'link' exists, use it instead
  if (defined($+{'link'})) {
    my $i;
    for ($i=0; $i <= $#+; $i++) {
      if ($$i eq $+{'link'}) {last;}
    }
    $$isP = $-[$i];
    $$ieP = $+[$i];
  }
  
  if ($explicitContext && ($$isP > (length($cxbefore)-1) || (length($cxbefore)-1) > $$ieP)) {
    &dbg("but match '".substr("$cxbefore$cxafter", $$isP, ($$ieP-$$isP))."' did not include the index '$index'\n");
    if ($cxbefore !~ s/^\s*\S+//) {return 1;}
    return &glossaryMatch($textP, $m, $isP, $ieP, "$index:CXBEFORE:$cxbefore:CXAFTER:$cxafter");
  }
  
  if ($explicitContext) {
    $$isP = length($$textP) - length($index);
    $$ieP = length($$textP);
  }
  
  &dbg("LINKED: $pm\n$t\n$$isP, $$ieP, '".substr($$textP, $$isP, ($$ieP-$$isP))."'\n");
  
  return 0;
}

# Converts a comma separated list of Paratext references (which are 
# supported by context and notContext attributes of DWF) and converts
# them into an osisRef. If $paratextRefList is not a valid Paratext 
# reference list, then $paratextRefList is returned unchaged. If there 
# are any errors, $paratextRefList is returned unchanged.
sub paratextRefList2osisRef($) {
  my $paratextRefList = shift;
  
  if ($CONVERTED_P2O{$paratextRefList}) {return $CONVERTED_P2O{$paratextRefList};}
  
  my @parts;
  @parts = split(/\s*,\s*/, $paratextRefList);
  my $reportParatextWarnings = (($paratextRefList =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1) ? 1:0) || (scalar(@parts) > 3));
  foreach my $part (@parts) {
    if ($part =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1)) {next;}
    if ($reportParatextWarnings) {
      &Warn("Attribute part \"$part\" might be a failed Paratext reference in \"$paratextRefList\".");
    }
    return $paratextRefList;
  }
  
  my $p1; my $p2;
  my @osisRefs = ();
  foreach my $part (@parts) {
    my @pOsisRefs = ();
    
    # book-book (assumes Paratext and OSIS verse system's book orders are the same)
    if ($part =~ /^([\d\w]\w\w)\s*\-\s*([\d\w]\w\w)$/) {
      my $bk1 = $1; my $bk2 = $2;
      $bk1 = &getOsisName($bk1, 1);
      $bk2 = &getOsisName($bk2, 1);
      if (!$bk1 || !$bk2) {
        &Error("contextAttribute2osisRefAttribute: Bad Paratext book name(s) \"$part\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      push(@pOsisRefs, "$bk1-$bk2");
    }
    else {
      my $bk;
      my $bkP;
      my $ch;
      my $chP;
      my $vs;
      my $vsP;
      my $lch;
      my $lchP;
      my $lvs;
      # book ch-ch
      if ($part =~ /^([\d\w]\w\w)\s+(\d+)\s*\-\s*(\d+)$/) {
        $bk = $1;
        $ch = $2;
        $lch = $3;
        $bkP = 1;
      }
      # book, book ch, book ch:vs, book ch:vs-lch-lvs, book ch:vs-lvs
      elsif ($part !~ /^([\d\w]\w\w)(\s+(\d+)(\:(\d+)(\s*\-\s*(\d+)(\:(\d+))?)?)?)?$/) {
        &Error("contextAttribute2osisRefAttribute: Bad Paratext reference \"$part\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      $bk = $1;
      $bkP = $2;
      $ch = $3;
      $chP = $4;
      $vs = $5;
      $vsP = $6;
      $lch = $7;
      $lchP = $8;
      $lvs = $9;
      
      if ($vsP && !$lchP) {$lvs = $lch; $lch = '';}
      
      my $bk = &getOsisName($bk, 1);
      if (!$bk) {
        &Error("contextAttribute2osisRefAttribute: Unrecognized Paratext book \"$bk\" of \"$paratextRefList\".");
        return $paratextRefList;
      }
      
      if (!$bkP) {
        push(@pOsisRefs, $bk);
      }
      elsif (!$chP) {
        if ($lch) {
          for (my $i=$ch; $i<=$lch; $i++) {
            push(@pOsisRefs, "$bk.$i");
          }
        }
        push(@pOsisRefs, "$bk.$ch");
      }
      elsif (!$vsP) {
        push(@pOsisRefs, "$bk.$ch.$vs");
      }
      elsif (!$lchP) {
        push(@pOsisRefs, "$bk.$ch.$vs".($lvs != $vs ? "-$bk.$ch.$lvs":''));
      }
      else {
        my $canonP;
        # Bug warning - this assumes &conf('Versification') is verse system of osisRef  
        &getCanon(&conf('Versification'), \$canonP, NULL, NULL, NULL);
        my $ch1lv = ($lch == $ch ? $lvs:@{$canonP->{$bk}}[($ch-1)]);
        push(@pOsisRefs, "$bk.$ch.$vs".($ch1lv != $vs ? "-$bk.$ch.$ch1lv":''));
        if ($lch != $ch) {
          if (($lch-$ch) >= 2) {
            push(@pOsisRefs, "$bk.".($ch+1).(($lch-1) != ($ch+1) ? "-$bk.".($lch-1):''));
          }
          push(@pOsisRefs, "$bk.$lch.1".($lvs != 1 ? "-$bk.$lch.$lvs":''));
        }
      }
    }
    
    push(@osisRefs, @pOsisRefs);
    my $new = join(' ', @pOsisRefs);
    my $len = length($part);
    if ($len < length($new)) {$len = length($new);}
    $p1 .= sprintf("%-".$len."s ", $part);
    $p2 .= sprintf("%-".$len."s ", $new);
  }
  
  my $ret = join(' ', @osisRefs);
  if ($ret ne $paratextRefList) {
    $CONVERTED_P2O{$paratextRefList} = $ret;
    &Note("Converted Paratext context attribute to OSIS:\n\tParatext: $p1\n\tOSIS:     $p2\n");
  }
  
  return $ret;
}


sub osisRef2Entry($\$$) {
  my $osisRef = shift;
  my $modP = shift;
  my $loose = shift;
  
  if ($osisRef !~ /^(\w+):(.*)$/) {
    if ($loose) {return &decodeOsisRef($osisRef);}
    &Error("osisRef2Entry loose=0, problem with osisRef: $osisRef !~ /^(\w+):(.*)\$/");
  }
  if ($modP) {$$modP = $1;}
  return &decodeOsisRef($2);
}


sub entry2osisRef($$) {
  my $mod = shift;
  my $ref = shift;
  return $mod.":".encodeOsisRef($ref);
}


sub attributeIsSet($$) {
  my $a = shift;
  my $m = shift;
  
  return scalar(@{$XPC->findnodes("ancestor-or-self::*[\@$a][1][\@$a='true']", $m)});
}


sub dbg($) {
  my $p = shift;
  if (!$DEBUG) {return 0;}
  
  if (!@DICT_DEBUG_THIS) {return 0;}
  for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {
    if (@DICT_DEBUG_THIS[$i] ne @DICT_DEBUG[$i]) {return 0;}
  }
  
  &Debug($p);
  return 1;
}


# Returns an atomized equivalent osisID from an osisRef. By atomized 
# meaning each segment of the result is an introduction context, verse ID 
# or keyword ID. The osisRef may contain one or more hyphenated continuation 
# segments whereas osisIDs cannot contain continuations. If expandIntros is 
# set, then expanded osisRefs will also include introductions. Note: it is 
# always assumed that osisRefWork = osisIDWork.
sub osisRef2osisID($$$$) {
  my $osisRefLong = shift;
  my $osisRefWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisRefWorkDefault
  my $expandIntros = shift;
  
  my @osisIDs;
  
  my $logTheResult;
  foreach my $osisRef (split(/\s+/, $osisRefLong)) {
    my $work = ($osisRefWorkDefault ? $osisRefWorkDefault:'');
    my $pwork = ($workPrefixFlag =~ /always/i ? "$osisRefWorkDefault:":'');
    if ($osisRef =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
    if (!$work && $workPrefixFlag =~ /always/i) {
      &Error("osisRef2osisID: workPrefixFlag is set to 'always' but osisRefWorkDefault is null for \"$osisRef\" in \"$osisRefLong\"!");
    }
    if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisRefWorkDefault:") {$pwork = '';}
    my $bible = $work; $bible =~ s/DICT$//;
    my $vsys = ($work ? &getVerseSystemOSIS($bible):&conf('Versification'));
  
    if ($osisRef eq 'OT') {
      $osisRef = "Gen-Mal"; 
      if ($expandIntros) {push(@osisIDs, $pwork."TESTAMENT_INTRO.0");}
    }
    elsif ($osisRef eq 'NT') {
      $osisRef = "Matt-Rev"; 
      if ($expandIntros) {push(@osisIDs, $pwork."TESTAMENT_INTRO.1");}
    }

    if ($osisRef !~ /^(.*?)\-(.*)$/) {push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($osisRef, $vsys, $expandIntros)))); next;}
    my $r1 = $1; my $r2 = $2;
    
    if ($r1 !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?/) {push(@osisIDs, "$pwork$osisRef"); next;}
    my $b1 = $1; my $c1 = ($2 ? $3:''); my $v1 = ($4 ? $5:'');
    if ($r2 !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?/) {push(@osisIDs, "$pwork$osisRef"); next;}
    my $b2 = $1; my $c2 = ($2 ? $3:''); my $v2 = ($4 ? $5:'');
    
    # The task is to output every verse in the range, not to limit or test the input
    # with respect to the verse system. But outputing ranges greater than a chapter 
    # requires knowledge of the verse system, so SWORD is used for this.
    push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($r1, $vsys, $expandIntros))));
    if ($r1 ne $r2) {
      push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($r2, $vsys, $expandIntros))));
      # if r1 is verse 0, it has already been pushed to osisIDs above 
      # but it cannot be incremented as VerseKey since it's not a valid 
      # verse. So take care of that situation on the next line.
      if ($r1 =~ s/^([^\.]+\.\d+)\.0$/$1.1/) {push(@osisIDs, "$r1");}
      # The end points are now recorded, but all verses in between must be pushed to osisIDs
      # (duplicates are ok). If b and c are the same in $r1 and $r2 then this is easy:
      if ($b1 eq $b2 && $c2 && $c1 == $c2) {
        for (my $v=$v1; $v<=$v2; $v++) {push(@osisIDs, "$pwork$b2.$c2.$v");}
        next;
      }
      # Otherwise verse key increment must be used until we reach the same book and chapter
      # as $r2, then simple verse incrementing can be used.
      my $ir1 = &idInVerseSystem($r1, $vsys);
      if (!$ir1) {
        &Warn("osisRef2osisID: Start verse \"$r1\" is not in \"$vsys\" so the following range may be incorrect: ");
        $logTheResult++;
        next;
      }
      my $ir2 = &idInVerseSystem($b2.($c2 ? ".$c2.1":''), $vsys);
      if (!$ir2) {
        &Error("osisRef2osisID: End point \"".$b2.($c2 ? ".$c2.1":'')."\" was not found in \"$vsys\" so the following range is likely incorrect: ");
        $logTheResult++;
        next;
      }
      if ($ir2 < $ir1) {
        &Error("osisRef2osisID: Range end is before start: \"$osisRef\". Changing to \"$r1\"");
        next;
      }
      my $vk = new Sword::VerseKey();
      $vk->setVersificationSystem($vsys); 
      $vk->setText($b2.($c2 ? ".$c2.1":''));
      if (!$c2) {$vk->setChapter($vk->getChapterMax()); $c2 = $vk->getChapter();}
      if (!$v2) {$vk->setVerse($vk->getVerseMax()); $v2 = $vk->getVerse();}
      $ir2 = $vk->getIndex();
      $vk->setText($r1);
      $ir1 = $vk->getIndex();
      while ($ir1 != $ir2) {
        if ($expandIntros && $vk->getChapter() == 1 && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".0");}
        if ($expandIntros && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".".$vk->getChapter().".0");}
        push(@osisIDs, $pwork.$vk->getOSISRef());
        $vk->increment();
        $ir1 = $vk->getIndex();
      }
      if ($expandIntros && $vk->getChapter() == 1 && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".0");}
      if ($expandIntros && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".".$vk->getChapter().".0");}
      for (my $v=$vk->getVerse(); $v<=$v2; $v++) {push(@osisIDs, "$pwork$b2.$c2.$v");}
    }
  }

  my $r = join(' ', &normalizeOsisID(\@osisIDs, $osisRefWorkDefault, $workPrefixFlag));
  if ($logTheResult) {&Log(" '$osisRefLong' = '$r' ?\n");}
  return $r;
}

# Return index if osisID is in verse-system vsys, or 0 otherwise
sub idInVerseSystem($$) {
  my $osisID = shift; if (ref($osisID)) {$osisID = $osisID->getOSISRef();}
  my $vsys = shift;
 
  if ($osisID !~ /^([^\.]+)(\.\d+(\.\d+)?)?$/) {return 0;}
  my $bk = $1;
  my $reb = join('|', @bks, split(/\s+/, $OT_BOOKS), split(/\s+/, $NT_BOOKS));
  if ($bk !~ /\b($reb)\b/) {return 0;}

  my $vk = new Sword::VerseKey();
  $vk->setAutoNormalize(0); # The default VerseKey will NOT allow a verse that doesn't exist in the verse system
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setText($osisID);
  my $before = $vk->getOSISRef();
  $vk->normalize();
  my $after = $vk->getOSISRef();

  return ($before eq $after ? $vk->getIndex():0);
}

# Take an osisID of the form DIVID, BOOK or BOOK.CH (or BOOK.CH.VS but 
# this only returns itself) and expand it to a list of individual verses 
# of the form BOOK.CH.VS, according to the verse system vsys. Book
# introductions, which have the form BOOK.0, are returned unchanged.
# When osisID is a DIVID it returns itself and all ancestor DIVIDs. All 
# expanded osisIDs also include book and chapter introductions if 
# expandIntros is set.
sub expandOsisID($$$) {
  my $osisID = shift;
  my $vsys = shift;
  my $expandIntros = shift;
  
  if ($osisID =~ /\!/) {return $osisID;}
  elsif ($osisID =~ /^[^\.]+\.\d+\.\d+$/ || $osisID =~ /^[^\.]+\.0$/) {
    return $osisID;
  }
  elsif (!&idInVerseSystem($osisID, $vsys)) {
    return join(' ', &osisID2Contexts($osisID, $expandIntros));
  }
  elsif ($osisID !~ /^([^\.]+)(\.(\d+))?$/) {
    return $osisID;
  }
  my $bk = $1; my $ch = ($2 ? $3:'');
  
  my @verses;
  if ($expandIntros && $ch eq '') {push(@verses, "$bk.0");}
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setText($osisID);
  $vk->normalize();
  
  if ($expandIntros && $vk->getVerse() == 1) {push(@verses, "$bk.".$vk->getChapter().".0");}
  push(@verses, $vk->getOSISRef());
  my $lastIndex = $vk->getIndex();
  $vk->increment();
  while ($lastIndex ne $vk->getIndex && 
         $vk->getOSISBookName() eq $bk && 
         (!$ch || $vk->getChapter() == $ch)) {
    if ($expandIntros && $vk->getVerse() == 1) {push(@verses, "$bk.".$vk->getChapter().".0");}
    push(@verses, $vk->getOSISRef());
    $lastIndex = $vk->getIndex();
    $vk->increment();
  }
  
  return join(' ', @verses);
}

# Return a SWORD verse key with the osisID. If the osisID does not exist
# in the verse system, then 0 is returned, unless dontCheck is set, in
# which case the key is returned anyway (however bugs or errors will 
# appear if such a key is later incremented, so use dontCheck with caution).
sub getVerseKey($$$) {
  my $osisID = shift;
  my $osisIDWorkDefault = shift;
  my $dontCheck = shift;
  
  my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
  if ($osisID =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1;}
  my $vsys = $work ? &getVerseSystemOSIS($work):&conf('Versification');
  
  if (!$dontCheck && !&idInVerseSystem($osisID, $vsys)) {return 0;}
  
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys);
  $vk->setAutoNormalize(0);
  $vk->setText($osisID);

  return $vk;
}

# Returns an equivalent osisRef from an osisID. The osisRef will contain 
# one or more hyphenated continuation segments if sequential osisID 
# verses are present (osisIDs cannot contain continuations). If 
# onlySpanVerses is set, then hyphenated segments returned may cover at 
# most one chapter (and in this case, the verse system is irrelevant). 
# Note: it is always assumed that osisRefWork = osisIDWork
sub osisID2osisRef($$$$) {
  my $osisID = shift;
  my $osisIDWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisIDWorkDefault
  my $onlySpanVerses = shift; # if true, ranges will only span verses (not chapters or books)
  
  my $osisRef = '';
  
  my @segs = &normalizeOsisID([ split(/\s+/, $osisID) ], $osisIDWorkDefault, $workPrefixFlag);
  my $inrange = 0;
  my $lastwk = '';
  my $lastbk = '';
  my $lastch = '';
  my $lastvs = '';
  my $vk;
  foreach my $seg (@segs) {
    my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
    my $pwork = ($workPrefixFlag =~ /always/i ? "$osisIDWorkDefault:":'');
    if ($seg =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
    if (!$work && $workPrefixFlag =~ /always/i) {
      &ErrorBug("osisID2osisRef: workPrefixFlag is set to 'always' but osisIDWorkDefault is null for \"$seg\"!");
    }
    if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisIDWorkDefault:") {$pwork = '';}
    
    if ($vk) {$vk->increment();}
    
    if ($vk && $lastwk eq $work && $vk->getOSISRef() eq $seg) {
      $inrange = 1;
      $lastbk = $vk->getOSISBookName();
      $lastch = $vk->getChapter();
      $lastvs = $vk->getVerse();
      next;
    }
    elsif ($seg =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      my $bk = $1; my $ch = $2; my $vs = $3;
      if ($lastwk eq $work && $lastbk eq $bk && $lastch && $lastch eq $ch && $vs == ($lastvs+1)) {
        $inrange = 1;
      }
      else {
        if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs"; $inrange = 0;}
        $osisRef .= " $pwork$seg";
      }
      $lastwk = $work;
      $lastbk = $bk;
      $lastch = $ch;
      $lastvs = $vs;
    }
    else {
      if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs"; $inrange = 0;}
      $osisRef .= " $pwork$seg";
      $lastbk = '';
      $lastch = '';
      $lastvs = '';
    }
    $vk = ($onlySpanVerses ? '':&getVerseKey($seg, $work));
  }
  if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs";}
  $osisRef =~ s/^\s*//;
  
  return $osisRef;
}


# Takes an array of osisIDs, splits each into segments, removes duplicates 
# and empty values, normalizes work prefixes if desired, and sorts each
# resulting segment in verse system order.
sub normalizeOsisID(\@$$$) {
  my $aP = shift;
  my $osisIDWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisIDWorkDefault
  my $vsys = shift;
  
  my @avs;
  foreach my $osisID (@{$aP}) {
    foreach my $seg (split(/\s+/, $osisID)) {
      my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
      my $pwork = ($workPrefixFlag =~ /always/i ? "$osisIDWorkDefault:":'');
      if ($seg =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
      if (!$work && $workPrefixFlag =~ /always/i) {
        &ErrorBug("normalizeOsisID: workPrefixFlag is set to 'always' but osisIDWorkDefault is null for \"$seg\" in \"$osisID\"!");
      }
      if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisIDWorkDefault:") {$pwork = '';}
      push(@avs, "$pwork$seg");
    }
  }
  
  my %seen;
  return sort { osisIDSort($a, $b, $osisIDWorkDefault, $vsys) } grep(($_ && !$seen{$_}++), @avs);
}


# Sort osisID segments (ie. Rom.14.23) in verse system order
sub osisIDSort($$$$) {
  my $a = shift;
  my $b = shift;
  my $osisIDWorkDefault = shift;
  my $vsys = shift; if (!$vsys) {$vsys = &conf('Versification');}
  
  my $awp = ($a =~ s/^([^\:]*\:)(.*)$/$2/ ? $1:($osisIDWorkDefault ? "$osisIDWorkDefault:":''));
  my $bwp = ($b =~ s/^([^\:]*\:)(.*)$/$2/ ? $1:($osisIDWorkDefault ? "$osisIDWorkDefault:":''));
  my $r = $awp cmp $bwp;
  if ($r) {return $r;}

  my $aNormal = 1; my $bNormal = 1;
  if ($a !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?(\!.*)?$/) {$aNormal = 0;}
  my $abk = $1; my $ach = (1*$3); my $avs = (1*$5);
  if ($b !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?(\!.*)?$/) {$bNormal = 0;}
  my $bbk = $1; my $bch = (1*$3); my $bvs = (1*$5);
  if    ( $aNormal && !$bNormal) {return 1;}
  elsif (!$aNormal &&  $bNormal) {return -1;}
  elsif (!$aNormal && !$bNormal) {return $a cmp $b;}
  
  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  &getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP);
  my $abi = (defined($bookOrderP->{$abk}) ? $bookOrderP->{$abk}:-1);
  my $bbi = (defined($bookOrderP->{$bbk}) ? $bookOrderP->{$bbk}:-1);
  if    ($abi != -1 && $bbi == -1) {return 1;}
  elsif ($abi == -1 && $bbi != -1) {return -1;}
  elsif ($abi == -1 && $bbi == -1) {return $abk cmp $bbk;}
  $r = $bookOrderP->{$abk} <=> $bookOrderP->{$bbk};
  if ($r) {return $r;}
  
  $r = $ach <=> $bch;
  if ($r) {return $r;}
  
  return $avs <=> $bvs;
}

# Check all Scripture reference links in the source text. This does not
# look for or check any externally supplied cross-references. This check
# is run before fitToVerseSystem(), so it is checking that the source
# text's references are consistent with itself. Any broken links found
# here are either mis-parsed, or are errors in the source text.
sub checkSourceScripRefLinks($) {
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

# Check that the targets of all references in a project Bible and Dict 
# (if present) OSIS file exist. This includes both the fixed and the 
# source verse system references. It is assumed that the Bible OSIS file 
# is created before the Dict OSIS file. Therefore, references in a Bible 
# which target the Dict are not checked until the Dict is created, when 
# they will be checked along with the Dict's references.
sub checkReferenceLinks($) {
  my $osis = shift;
  
  my %osisID; my %refcount; my %errors;
  
  &Log("\nCHECKING OSISREF TARGETS IN $osis...\n");
  my $inXML = $XML_PARSER->parse_file($osis);
  my $inIsBible = (&getRefSystemOSIS($inXML) !~ /^Dict\./ ? 1:0);
  &readOsisIDs(\%osisID, $inXML);
  my $bibleOSIS;
  my $bibleXML;
  if ($inIsBible) {
    $bibleOSIS = $osis;
    $bibleXML = $inXML;
  }
  else {
    $bibleOSIS = "$TMPDIR/chrl_$MAINMOD.xml";
    &copy(&getModuleOsisFile($MAINMOD, 'Error'), $bibleOSIS);
    $bibleXML = $XML_PARSER->parse_file($bibleOSIS);
    &readOsisIDs(\%osisID, $bibleXML);
  }
  # Check reference links in OSIS file (fixed vsys) NOT including glossary links if OSIS is a Bible
  &checkReferenceLinks2($inXML, \%refcount, \%errors, \%osisID, 1, ($inIsBible ? -1:0));
  &reportReferences(\%refcount, \%errors); undef(%refcount); undef(%errors);
  
  # If OSIS is NOT a Bible, now check glossary reference links in the Bible OSIS
  if (!$inIsBible) {
    &Log("\nCHECKING GLOSSARY OSISREF TARGETS IN BIBLE OSIS $bibleOSIS...\n");
    &checkReferenceLinks2($bibleXML, \%refcount, \%errors, \%osisID, 1, 1);
    &reportReferences(\%refcount, \%errors); undef(%refcount); undef(%errors);
  }

  undef(%osisID); # re-read source vsys OSIS files
  &runScript("$SCRD/scripts/osis2sourceVerseSystem.xsl", \$osis);
  &Log("\nCHECKING SOURCE VSYS NON-GLOSSARY OSISREF TARGETS IN $osis");
  $inXML = $XML_PARSER->parse_file($osis);
  &readOsisIDs(\%osisID, $inXML);
  if ($inIsBible) {$bibleOSIS = $osis; $bibleXML = $inXML;}
  else {
    &runScript("$SCRD/scripts/osis2sourceVerseSystem.xsl", \$bibleOSIS);
    &Log(" AGAINST $bibleOSIS\n");
    $bibleXML = $XML_PARSER->parse_file($bibleOSIS);
    &readOsisIDs(\%osisID, $bibleXML);
  }
  &Log("...\n");
  # Check reference links in OSIS (source vsys) NOT including glossary links which are unchanged between fixed/source
  &checkReferenceLinks2($inXML, \%refcount, \%errors, \%osisID, 1, -1);
  &reportReferences(\%refcount, \%errors);
}

sub removeMissingOsisRefs($) {
  my $osisP = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1removeMissingOsisRefs$3/;
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
  
  &writeXMLFile($xml, $output, $osisP);
}

sub readOsisIDs(\%$) {
  my $osisIDP = shift;
  my $xml = shift;
  
  my $mod = &getOsisIDWork($xml);
  foreach my $elem ($XPC->findnodes('//*[@osisID]', $xml)) {
    my $id = $elem->getAttribute('osisID');
    foreach my $i (split(/\s+/, $id)) {$osisIDP->{$mod}{$i}++;}
  }
}

sub reportReferences(\%\%) {
  my $refcntP = shift;
  my $errorsP = shift;
  
  my $total = 0; my $errtot = 0;
  foreach my $type (sort keys (%{$refcntP})) {
    &Report("\"".$refcntP->{$type}."\" ${type}s checked. (".($errorsP->{$type} ? $errorsP->{$type}:0)." problems)");
    $total += $refcntP->{$type}; $errtot += $errorsP->{$type};
  }
  &Report("\"$total\" Grand total osisRefs checked. (".($errtot ? $errtot:0)." problems)");
}

sub checkReferenceLinks2($$\%\%\%$) {
  my $inxml = shift;
  my $refcountP = shift;
  my $errorsP = shift;
  my $osisIDP = shift;
  my $throwError = shift;
  my $glossaryFlag = shift; # < 0 means check all refs except glossary refs
                            # = 0 means check all refs
                            # > 0 means check only glossary refs
  my $osisRefWork = &getOsisRefWork($inxml);
  
  my @references = $XPC->findnodes('//osis:reference', $inxml);
  my @osisRefs = $XPC->findnodes('//*[@osisRef][not(self::osis:reference)]', $inxml);
  push(@osisRefs, @references);
  
  my $glosstype = 'glossary osisRef';
  foreach my $r (@osisRefs) {
    my $rtag = $r->toString(); $rtag =~ s/^(<[^>]*>).*?$/$1/;
    
    my $type;
    if ($r->getAttribute('type') =~ /^(\Qx-glossary\E|\Qx-glosslink\E)$/) {$type = $glosstype;}
    elsif ($r->getAttribute('type') eq 'x-note') {$type = 'osisRefs to note';}
    else {$type = $r->nodeName.' osisRef';}
    
    if    ($type eq $glosstype && $glossaryFlag < 0) {next;}
    elsif ($type ne $glosstype && $glossaryFlag > 0) {next;}
    
    my $osisRefAttrib = $r->getAttribute('osisRef');
    if (!$osisRefAttrib) {
    &Error("Reference link is missing an osisRef attribute: \"$r\"", 
"Maybe this should not be marked as a reference? Reference tags in OSIS 
require a valid target. When there isn't a valid target, then a 
different USFM tag should be used instead.");
      $errors{$type}++;
      next;
    }
    
    $refcountP->{$type}++;
    
    if ($osisRefAttrib =~ /\s+/ && $type eq 'reference osisRef') {
      &Error("A Scripture osisRef cannot have multiple targets: $osisRefAttrib", "Use multiple reference elements instead.");
    }
    
    # The osisRef attributes of x-glosslink and x-glossary references may 
    # contain spaces for multiple targets (but other osisRefs may not).
    foreach my $osisRef (split(/\s+/, $osisRefAttrib)) {
      my $rwork = ($osisRef =~ s/^(\w+):// ? $1:$osisRefWork);
      
      # If this is a reference to a verse, check that it follows some rules:
      # 1) warn if a range exceeds the chapter since xulsword and other programs don't support these
      if ($osisRef =~ /(^|\s+)\w+\.\d+(\.\d+)?(\s+|$)/) {
        if ($osisRef =~ /^(\w+\.\d+).*?\-(\w+\.\d+).*?$/ && $1 ne $2) {
          &Warn("An osisRef to a range of Scripture should not exceed a chapter: $osisRef", "Some software, like xulsword, does not support ranges that exceed a chapter.");
        }
      }
      
      my $failed = '';
      foreach my $orp (split(/[\s\-]+/, $osisRef)) {
        my $ext = ($orp =~ s/(![^!]*)$// ? $1:'');
        if ($r->getAttribute('subType') eq 'x-external') {
          if (!&inVersesystem($orp, $rwork)) {$failed .= "$rwork:$orp$ext ";}
        }
        else {
          if (!$osisIDP->{$rwork}{"$orp$ext"}) {
            if (!$osisIDP->{$rwork}{$orp}) {
              $failed .= "$rwork:$orp$ext ";
            }
            else {
              &Warn("$type $rwork:$orp$ext extension not found.", 
  "<>Although the root osisID exists in the OSIS file, the extension 
  id does not. This is allowed if the specific location which the 
  extension references exists but is unknown, such as !PART.");
            }
          }
        }
      }
      
      if ($failed) {
        $errorsP->{$type}++;
        if (!$throwError) {&Warn("$type $failed not found: ".$r->toString());}
        else {&Error("$type $failed not found: ".$r->toString());}
      }
    }
  }
}

sub inVersesystem($$) {
  my $osisID = shift;
  my $workid = shift;
  
  foreach my $id (split(/\s+/, $osisID)) {
    my $ext = ($id =~ s/(\!.*)$// ? $1:'');
    my $osisIDWork = $workid;
    my $wktype = 'Bible';
    my $wkvsys = &conf('Versification');
    if ($id =~ s/^([\w\d]+)\://) {$osisIDWork = $1;}
    if (!&isChildrensBible($MOD) && $osisIDWork && $osisIDWork !~ /^bible$/i) {
      &getRefSystemOSIS($osisIDWork) =~ /^([^\.]+)\.(.*)$/;
      $wktype = $1; $wkvsys = $2;
    }
    
    if ($id !~ /^([\w\d]+)(\.(\d+)(\.(\d+))?)?$/) {
      &Error("Could not parse osisID $id.");
      return 0;
    }
    my $b = $1; my $c = ($2 ? $3:''); my $v = ($4 ? $5:'');
    if ($OT_BOOKS !~ /\b$b\b/ && $NT_BOOKS !~ /\b$b\b/)  {
      &Error("Unrecognized OSIS book abbreviation $b in osisID $id.");
      return 0;
    }
    my ($canonP, $bookOrderP, $bookArrayP);
    &getCanon($wkvsys, \$canonP, \$bookOrderP, NULL, \$bookArrayP);
    if ($c && ($c < 0 || $c > @{$canonP->{$b}})) {
      &Error("Chapter $c of osisID $id is outside of verse system $wkvsys.");
      return 0;
    }
    if ($v && ($v < 0 || $v > @{$canonP->{$b}}[$c-1])) {
      &Error("Verse $v of osisID $id is outside of verse system $wkvsys.");
      return 0;
    }
  }
  
  return 1;
}

sub checkUniqueOsisIDs($) {
  my $in_osis = shift;
  
  &Log("\nCHECKING OSISIDS ARE UNIQUE IN $in_osis...\n");
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  my @osisIDs = $XPC->findnodes('//@osisID', $osis);
  my %ids;
  foreach my $id (@osisIDs) {$ids{$id->value}++;}
  foreach my $k (sort keys %ids) {
    if ($ids{$k} > 1) {
      &Error("osisID attribute value is not unique: $k (".$ids{$k}.")", "There are multiple elements with the same osisID, which is not allowed.");
    }
  }
  
  &Report("Found ".@osisIDs." unique osisIDs");
}

sub checkIntroductionTags($) {
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

sub checkCharacters($) {
  my $osis = shift;
  
  # Get all characters used anywhere in the OSIS file
  my $chars = &shell("cat '$osis' | sed 's/./&\\n/g' | LC_COLLATE=C sort -u | tr -d '\\n'", 3);
  &Log("\n"); &Report("Characters used in OSIS file: $chars (".length($chars)." chars)");
  
  # Check for high Unicode character replacements needed for GoBible/simpleChars.txt
  my %allChars; for my $c (split(//, $chars)) {$allChars{$c}++;}
  my @from; my @to; &readReplacementChars(&getDefaultFile("bible/GoBible/simpleChars.txt"), \@from, \@to);
  foreach my $chr (sort { ord($a) <=> ord($b) } keys %allChars) {
    if (ord($chr) <= $MAX_UNICODE) {next;}
    my $x; for ($x=0; $x<@from; $x++) {
      if (@from[$x] eq $chr) {&Note("High Unicode character found ( > $MAX_UNICODE): ".ord($chr)." '$chr' <> '".@to[$x]."'"); last;}
    }
    if (@from[$x] ne $chr) {
      &Warn("There is no simpleChars.txt replacement for the high Unicode character: '$chr'", "This character, and its low order replacement, may be added to: $SCRIPT/defaults/bible/GoBible/simpleChars.txt to remove this warning.");
    }
  }
}

sub readReplacementChars($\@\@) {
  my $replacementsFile = shift;
  my $fromAP = shift;
  my $toAP = shift;

  if (open(INF, "<$READLAYER", $replacementsFile)) {
    while(<INF>) {
      if ($fromAP && $_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for ($i=0; substr($chars, $i, 1); $i++) {
          push(@{$fromAP}, substr($chars, $i, 1));
        }
      }
      if ($toAP && $_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for ($i=0; substr($chars, $i, 1); $i++) {
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

# Print log info for a word file
sub logDictLinks() {
  &Log("\n\n");
  &Report("Explicitly marked words or phrases that were linked to glossary entries: (". (scalar keys %EXPLICIT_GLOSSARY) . " variations)");
  my $mxl = 0; foreach my $eg (sort keys %EXPLICIT_GLOSSARY) {if (length($eg) > $mxl) {$mxl = length($eg);}}
  my %cons;
  foreach my $eg (sort keys %EXPLICIT_GLOSSARY) {
    my @txt;
    foreach my $tg (sort keys %{$EXPLICIT_GLOSSARY{$eg}}) {
      if ($tg eq 'Failed') {
        my @contexts = sort keys %{$EXPLICIT_GLOSSARY{$eg}{$tg}{'context'}};
        my $mlen = 0;
        foreach my $c (@contexts) {
          if (length($c) > $mlen) {$mlen = length($c);}
          my $ctx = $c; $ctx =~ s/^\s+//; $ctx =~ s/\s+$//; $ctx =~ s/<index\/>.*$//;
          $cons{lc($ctx)}++;
        }
        foreach my $c (@contexts) {$c = sprintf("%".($mlen+5)."s", $c);}
        push(@txt, $tg." (".$EXPLICIT_GLOSSARY{$eg}{$tg}{'count'}.")\n".join("\n", @contexts)."\n");
      }
      else {
        push(@txt, $tg." (".$EXPLICIT_GLOSSARY{$eg}{$tg}.")");
      }
    }
    my $msg = join(", ", sort { ($a =~ /failed/i ? 0:1) <=> ($b =~ /failed/i ? 0:1) } @txt);
    &Log(sprintf("%-".$mxl."s ".($msg !~ /failed/i ? "was linked to ":'')."%s", $eg, $msg) . "\n");
  }
  # Report each unique context ending for failures, since these may represent entries that are missing from the glossary
  my %uniqueConEnd;
  foreach my $c (sort keys %cons) {
    my $toLastWord;
    for (my $i=2; $i<=length($c) && $c !~ /^\s*$/; $i++) {
      my $end = substr($c, -$i, $i);
      my $keep = 1;
      if (substr($end,0,1) =~ /\s/) {$toLastWord = substr($end, 1, length($end)-1);}
      foreach my $c2 (sort keys %cons) {
        if ($c2 eq $c) {next;}
        if ($c2 =~ /\Q$end\E$/i) {$keep = 0; last;}
      }
      if ($keep) {
        my $uce = $c;
        if ($toLastWord) {$uce = $toLastWord;}
        else {$uce =~ s/^.*\s//};
        $uniqueConEnd{$uce}++; $i=length($c);
      }
    }
  }
  &Log("\n");
  &Report("There were ".%uniqueConEnd." unique failed explicit entry contexts".(%uniqueConEnd ? ':':'.'));
  foreach my $uce (sort { length($b) <=> length($a) } keys %uniqueConEnd) {&Log("$uce\n");}
  
  my $nolink = "";
  my $numnolink = 0;
  my @entries = $XPC->findnodes('//dw:entry/dw:name/text()', $DWF);
  my %entriesH; foreach my $e (@entries) {
    my @ms = $XPC->findnodes('./ancestor::dw:entry[1]//dw:match', $e);
    $entriesH{(!@ms || !@ms[0] ? '(no match rules) ':'').$e}++;
  }
  foreach my $e (sort keys %entriesH) {
    my $match = 0;
    foreach my $dh (sort keys %EntryHits) {
      my $xe = $e; $xe =~ s/^No <match> element(s)\://g;
      if ($xe eq $dh) {$match = 1;}
    }
    if (!$match) {$nolink .= $e."\n"; $numnolink++;}
  }
  
  &Log("\n\n");
  &Report("Glossary entries from $DICTIONARY_WORDS which have no links in the text: ($numnolink instances)");
  if ($nolink) {
    &Note("You may want to link to these entries using a different word or phrase. To do this, edit the");
    &Log("$DICTIONARY_WORDS file.\n");
    &Log($nolink);
  }
  else {&Log("(all glossary entries have at least one link in the text)\n");}
  &Log("\n");
  
  my @matches = $XPC->findnodes('//dw:match', $DWF);
  my %unused;
  my $total = 0;
  my $mlen = 0;
  foreach my $m (@matches) {
    if ($MATCHES_USED{$m->unique_key}) {next;}
    my $entry = @{$XPC->findnodes('./ancestor::dw:entry[1]', $m)}[0];
    if ($entry) {
      my $osisRef = $entry->getAttribute('osisRef');
      if (!$unused{$osisRef}) {
        $unused{$osisRef} = ();
      }
      push(@{$unused{$osisRef}}, $m->toString());
      if (length($osisRef) > $mlen) {$mlen = length($osisRef);}
      $total++;
    }
    else {&Error("No <entry> containing $m in $DICTIONARY_WORDS", "Match elements may only appear inside entry elements.");}
  }
  &Report("Unused match elements in $DICTIONARY_WORDS: ($total instances)");
  if ($total > 50) {
    &Warn("Large numbers of unused match elements can slow down the parser.", 
"When you are sure they are not needed, and parsing is slow, then you  
can remove unused match elements from DictionaryWords.xml by running:
osis-converters/utils/removeUnusedMatchElements.pl $INPD");
  }
  foreach my $osisRef (sort keys %unused) {
    foreach my $m (@{$unused{$osisRef}}) {
      &Log(sprintf("%-".$mlen."s %s\n", $osisRef, $m));
    }
  }
  &Log("\n");

  # REPORT: N links to DICTMOD:<decoded_entry_osisRef> as <match1>(N) <match2>(N*)... in <context1>(N) <context2>(N)...
  # get fields and their lengths
  my $grandTotal = 0;
  my %toString; my $maxLenToString = 0;
  my %asString; my $maxLenAsString = 0;
  foreach my $refs (keys %LINK_OSISREF) {
    $grandTotal += $LINK_OSISREF{$refs}{'total'};
    $toString{$refs} = &decodeOsisRef($refs);
    if (!$maxLenToString || $maxLenToString < length($toString{$refs})) {$maxLenToString = length($toString{$refs});}
    foreach my $as (sort {&numAlphaSort($LINK_OSISREF{$refs}{'matched'}, $a, $b, '', 0);} keys %{$LINK_OSISREF{$refs}{'matched'}}) {
      my $tp = '*'; foreach my $ref (split(/\s+/, $refs)) {if (lc($as) eq lc(&osisRef2Entry($ref))) {$tp = '';}}
      $asString{$refs} .= $as."(".$LINK_OSISREF{$refs}{'matched'}{$as}."$tp) ";
    }
    if (!$maxLenAsString || $maxLenAsString < length($asString{$refs})) {$maxLenAsString = length($asString{$refs});}
  }
  
  my %inString;
  foreach my $refs (keys %LINK_OSISREF) {
    foreach my $in (sort {&numAlphaSort($LINK_OSISREF{$refs}{'context'}, $a, $b, '', 1);} keys %{$LINK_OSISREF{$refs}{'context'}}) {
      $inString{$refs} .= &decodeOsisRef($in)."(".$LINK_OSISREF{$refs}{'context'}{$in}.") ";
    }
  }
  
  my $p;
  foreach my $refs (sort {&numAlphaSort(\%LINK_OSISREF, $a, $b, 'total', 1);} keys %LINK_OSISREF) {
    $p .= sprintf("%4i links to %-".$maxLenToString."s as %-".$maxLenAsString."s in %s\n", 
            $LINK_OSISREF{$refs}{'total'}, 
            $toString{$refs}, 
            $asString{$refs},
            $inString{$refs}
          );
  }
  &Note("
The following listing should be looked over to be sure text is
correctly linked to the glossary. Glossary entries are matched in the
text using the match elements found in the $DICTIONARY_WORDS file.\n");
  &Report("Links created: ($grandTotal instances)\n* is textual difference other than capitalization\n$p");
}

sub numAlphaSort(\%$$$) {
  my $hashP = shift;
  my $a = shift;
  my $b = shift;
  my $key = shift;
  my $doDecode = shift;
  
  my $m1 = ($key ? ($hashP->{$b}{$key} <=> $hashP->{$a}{$key}):($hashP->{$b} <=> $hashP->{$a}));
  if ($m1) {
    return $m1;
  }
  
  if ($doDecode) {
    return (&decodeOsisRef($a) cmp &decodeOsisRef($b));
  }
  
  return $a cmp $b;
}

# copies a directoryʻs contents to a possibly non existing destination directory
sub copy_dir($$$$) {
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
sub copy_dir_with_defaults($$$$) {
  my $dir = shift;
  my $dest = shift;
  my $keep = shift;
  my $skip = shift;
  
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
sub delete_files($) {
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


sub fromUTF8($) {
  my $c = shift;
  $c = decode("utf8", $c);
  utf8::upgrade($c);
  return $c;
}


sub is_usfm2osis($) {
  my $osis = shift;
  my $usfm2osis = 0;
  if (!open(TEST, "<$READLAYER", "$osis")) {&Error("is_usfm2osis could not open $osis", '', 1);}
  while(<TEST>) {if ($_ =~ /<!--[^!]*\busfm2osis.py\b/) {$usfm2osis = 1; last;}}
  close(TEST);
  if ($usfm2osis) {&Log("\n--- OSIS file was created by usfm2osis.py.\n");}
  return $usfm2osis;
}

# Runs an XSLT and/or a Perl script if they have been placed at the
# appropriate input project path by the user. This allows a project to 
# apply custom scripts if needed.
sub runAnyUserScriptsAt($$\%$) {
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

# Runs a script according to its type (its extension). The sourceP points
# to the input file. If overwrite is set, the input file is overwritten,
# otherwise the output file has the name of the script which created it
# unless a file with that name already exists, at which time _n is 
# appended to have a unique name. Upon sucessfull completion, inputP 
# will be updated to point to the newly created output file.
sub runScript($$\%$) {
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
  
  my $output = $$inputP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1$name$3/;
  my $fp = "$1$name"; my $fe = $3; my $n = 0;
  while (-e $output) {$n++; $output = $fp.'_'.$n.$fe;}
  if ($ext eq 'xsl')   {&runXSLT($script, $$inputP, $output, $paramsP, $logFlag);}
  elsif ($ext eq 'pl') {&runPerl($script, $$inputP, $output, $paramsP, $logFlag);}
  else {
    &ErrorBug("runScript: Unsupported script extension \"$script\"!");
    return 0;
  }
  
  if (-z $output) {
    &Error("runScript: Output file $output has 0 size.");
    return 0;
  }
  elsif ($overwrite) {&copy($output, $$inputP);}
  else {$$inputP = $output;} # change inputP to pass output file name back
  
  return 1;
}

sub runPerl($$$\%$) {
  my $script = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  # Perl scripts need to have the following arguments
  # script-name input-file output-file [key1=value1] [key2=value2]...
  my @args = (&escfile($script), &escfile($source), &escfile($output));
  map(push(@args, &escfile("$_=".$paramsP->{$_})), sort keys %{$paramsP});
  &shell(join(' ', @args), $logFlag);
}

sub runXSLT($$$\%$) {
  my $xsl = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  my $cmd = "saxonb-xslt -ext:on";
  $cmd .= " -xsl:" . &escfile($xsl) ;
  $cmd .= " -s:" . &escfile($source);
  $cmd .= " -o:" . &escfile($output);
  foreach my $p (sort keys %{$paramsP}) {
    my $v = $paramsP->{$p};
    $v =~ s/(["\\])/\\$1/g; # escape quote since below passes with quote
    $cmd .= " $p=\"$v\"";
  }
  $cmd .= " DEBUG=\"$DEBUG\" DICTMOD=\"$DICTMOD\" SCRIPT_NAME=\"$SCRIPT_NAME\" OUTPUT_FILE=\"$output\"";
  &shell($cmd, $logFlag);
}


$ProgressTotal = 0;
$ProgressTime = 0;
sub logProgress($$) {
  my $msg = shift;
  my $ln = shift;
  
  my $t = time;
  my $tleft = 0;
  if ($ln == -1) {
      $ProgressTime = time;
      $ProgressTotal = 0;
      copy($msg, "$msg.progress.tmp");
      if (open(PRGF, "<$READLAYER", "$msg.progress.tmp")) {
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
sub zipModule($$) {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  chdir($moddir);
  my $result = &shell($cmd, 3); # capture result so that output lines can be sorted before logging
  chdir($SCRD);
  &Log("$cmd\n", 1); @lines = split("\n", $result); $result = join("\n", sort @lines); &Log($result, 1);
}


# I could not find a way to get XML::LibXML::DocumentFragment->toString()
# to STOP converting high-order unicode characters to entities when 
# serializing attributes. But regular documents, with proper declarations, 
# don't have this problem. So here is a solution.
sub fragmentToString($$) {
  my $doc_frag = shift;
  my $rootTag = shift;
  
  my $rootTagName = $rootTag;
  if ($rootTagName !~ s/^\s*<(\w+).*$/$1/) {&ErrorBug("fragmentToString bad rootTagName: $rootTagName !~ s/^\s*<(\w+).*\$/\$1/");}
  
  my $dom = XML::LibXML::Document->new("1.0", "UTF-8");
  $dom->insertBefore($doc_frag, NULL);
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
sub writeOsisHeader($) {
  my $osis_or_osisP = shift;
  
  my $osis = (ref($osis_or_osisP) ? $$osis_or_osisP:$osis_or_osisP); 
  my $osisP =(ref($osis_or_osisP) ? $osis_or_osisP:\$osis);
  
  my $output;
  if (ref($osis_or_osisP)) {$output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1writeOsisHeader$3/;}
  else {$output = $osis;}
  
  &Log("\nWriting work and companion work elements in OSIS header:\n");
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
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
    $workElements{'190000:scope'}{'textContent'} = &getScope($$osisP, &conf('Versification'));
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
  
  &writeXMLFile($xml, $output, (ref($osis_or_osisP) ? $osis_or_osisP:''));
  
  return $header;
}

# Search for any ISBN number(s) in the osis file or config.conf.
sub searchForISBN($$) {
  my $mod = shift;
  my $xml = shift;
  
  my %isbns; my $isbn;
  my @checktxt = ($xml ? $XPC->findnodes('//text()', $xml):());
  my @checkconfs = ('About', 'Description', 'ShortPromo', 'TextSource', 'LCSH');
  foreach my $cc (@checkconfs) {push(@checktxt, &conf($cc, $mod, '', '', 1));}
  foreach my $tn (@checktxt) {
    if ($tn =~ /\bisbn (number|\#|no\.?)?([\d\-]+)/i) {
      $isbn = $2;
      $isbns{$isbn}++;
    }
  }
  return join(', ', sort keys %isbns);
}

# Write all work children elements for modname to osisWorkP. The modname 
# must be either the value of $MAINMOD or $DICTMOD. Note that each raw 
# conf value is written to the work element matching its section (context 
# specific values from &conf are not written). This means that retreiving 
# the usual context specific value from the header data requires 
# searching both MAIN and DICT work elements. 
sub getOSIS_Work($$$) {
  my $modname = shift; 
  my $osisWorkP = shift;
  my $isbn = shift;
  
  my $section = ($modname eq $DICTMOD ? "$DICTMOD+":'');
 
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
  
  # map conf info to OSIS Work elements:
  # element order seems to be important for passing OSIS schema validation for some reason (hence the ordinal prefix)
  $osisWorkP->{'000000:title'}{'textContent'} = ($modname eq $DICTMOD ? &conf('CombinedGlossaryTitle'):&conf('TranslationTitle'));
  &mapLocalizedElem(30000, 'subject', $section.'Description', $osisWorkP, 1);
  $osisWorkP->{'040000:date'}{'textContent'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  $osisWorkP->{'040000:date'}{'event'} = 'eversion';
  &mapLocalizedElem(50000, 'description', $section.'About', $osisWorkP, 1);
  &mapConfig(50008, 58999, 'description', 'x-config', $osisWorkP, $modname);
  &mapLocalizedElem(60000, 'publisher', $section.'CopyrightHolder', $osisWorkP);
  &mapLocalizedElem(70000, 'publisher', $section.'CopyrightContactAddress', $osisWorkP);
  &mapLocalizedElem(80000, 'publisher', $section.'CopyrightContactEmail', $osisWorkP);
  &mapLocalizedElem(90000, 'publisher', $section.'ShortPromo', $osisWorkP);
  $osisWorkP->{'100000:type'} = \%type;
  $osisWorkP->{'110000:format'}{'textContent'} = 'text/xml';
  $osisWorkP->{'110000:format'}{'type'} = 'x-MIME';
  $osisWorkP->{'120000:identifier'}{'textContent'} = $isbnID;
  $osisWorkP->{'120000:identifier'}{'type'} = 'ISBN';
  $osisWorkP->{'121000:identifier'}{'textContent'} = "$idf.$modname";
  $osisWorkP->{'121000:identifier'}{'type'} = 'OSIS';
  if ($isbn) {$osisWorkP->{'130000:source'}{'textContent'} = "ISBN: $isbn";}
  $osisWorkP->{'140000:language'}{'textContent'} = &conf('Lang');
  &mapLocalizedElem(170000, 'rights', $section.'Copyright', $osisWorkP);
  &mapLocalizedElem(180000, 'rights', $section.'DistributionNotes', $osisWorkP);
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

sub mapLocalizedElem($$$$$) {
  my $index = shift;
  my $workElement = shift;
  my $confEntry = shift;
  my $osisWorkP = shift;
  my $skipTypeAttribute = shift;
  
  foreach my $k (sort {$a cmp $b} keys %{$CONF}) {
    if ($k !~ /^$confEntry(_([\w\-]+))?$/) {next;}
    my $lang = ($1 ? $2:'');
    $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'textContent'} = $CONF->{$k};
    if (!$skipTypeAttribute) {$osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'type'} = "x-$k";}
    if ($lang) {
      $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'xml:lang'} = $lang;
    }
    $index++;
    if (($index % 10) == 6) {&ErrorBug("mapLocalizedConf: Too many \"$workElement\" language variants.");}
  }
}

sub mapConfig($$$$$$) {
  my $index = shift;
  my $maxindex = shift;
  my $elementName = shift;
  my $prefix = shift;
  my $osisWorkP = shift;
  my $modname = shift;
  
  foreach my $confEntry (sort keys %{$CONF}) {
    if ($index > $maxindex) {&ErrorBug("mapConfig: Too many \"$elementName\" $prefix entries.");}
    elsif ($modname && $confEntry =~ /DICT\+/ && $modname ne $DICTMOD) {next;}
    elsif ($modname && $confEntry !~ /DICT\+/ && $modname eq $DICTMOD) {next;}
    else {
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'textContent'} = $CONF->{$confEntry};
      $confEntry =~ s/[^\-]+DICT\+//;
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'type'} = "$prefix-$confEntry";
      $index++;
    }
  }
}

sub writeWorkElement($$$) {
  my $attributesP = shift;
  my $elementsP = shift;
  my $xml = shift;
  
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  $header->appendTextNode("\n");
  my $work = $header->insertAfter($XML_PARSER->parse_balanced_chunk("<work></work>"), NULL);
  
  # If an element would have no textContent, the element is not written
  foreach my $a (sort keys %{$attributesP}) {$work->setAttribute($a, $attributesP->{$a});}
  foreach my $e (sort keys %{$elementsP}) {
    if (!exists($elementsP->{$e}{'textContent'})) {next;}
    $work->appendTextNode("\n  ");
    my $er = $e;
    $er =~ s/^\d+\://;
    my $elem = $work->insertAfter($XML_PARSER->parse_balanced_chunk("<$er></$er>"), NULL);
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

sub getGlossaryTitle($) {
  my $glossdiv = shift;
  
  my $telem = @{$XPC->findnodes('(descendant::osis:title[@type="main"][1] | descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n)[1]', $glossdiv)}[0];
  if (!$telem) {return '';}
  
  my $title = $telem->textContent();
  $title =~ s/^(\[[^\]]*\])+//g;
  return $title;
}

# Write unique osisIDs to any elements that still need them
sub writeOsisIDs($) {
  my $osisP = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1writeOsisIDs$3/;
  
  my $type;
  if    (&conf('ModDrv') =~ /LD/)   {$type = 'x-glossary';}
  elsif (&conf('ModDrv') =~ /Text/) {$type = 'x-bible';}
  elsif (&conf('ModDrv') =~ /GenBook/) {$type = 'x-childrens-bible';}
  else {return;}
  
  &Log("\nWriting osisIDs:\n", 1);
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @existing = $XPC->findnodes('//osis:note[not(@resp)][@osisID]', $xml);
  if (@existing) {
    &Warn(@existing." notes already have osisIDs assigned, so this step will be skipped and no new note osisIDs will be written!");
    return;
  }
  
  my $myMod = &getOsisRefWork($xml);
  
  # Add osisID to DICT container divs
  my %ids;
  foreach my $div (
    @{$XPC->findnodes('//osis:div[@type][not(@osisID)]
      [not(@resp="x-oc")]
      [not(starts-with(@type, "book"))]
      [not(starts-with(@type, "x-keyword"))]
      [not(starts-with(@type, "x-aggregate"))]
      [not(contains(@type, "ection"))]', $xml)}
    ) {
    my $n=1;
    my $id;
    my $title = &encodeOsisRef(&getGlossaryTitle($div));
    do {
      my $feature = ($div->getAttribute('annotateType') eq 'x-feature' ? $div->getAttribute('annotateRef'):'');
      $id = ($feature ? $feature:&dashCamelCase($div->getAttribute('type')));
      $id = ($id ? $id:'div');
      $id .= ($title ? "_$title":'');
      $id .= ($title || $feature ? ($n != 1 ? "_$n":''):"_$n");
      $id .= "!con";
      $n++;
    } while (defined($ids{$id}));
    $ids{$id}++;
    $div->setAttribute('osisID', $id);
    &Note("Adding osisID ".$div->getAttribute('osisID'));
  }
  
  # Add osisID's to TOC milestones as reference targets
  foreach my $ms (@{$XPC->findnodes('//osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][@n][not(@osisID)]', $xml)}) {
    # ! extension is to quickly differentiate from Scripture osisIDs for osis2xhtml.xsl
    $ms->setAttribute('osisID', &encodeOsisRef($ms->getAttribute('n')).'!toc'); 
  }
  
  # Write these osisID changes before any further steps
  my $tmpf = "$$osisP.2.xml";
  &writeXMLFile($xml, $tmpf);
  
  # Get all notes (excluding generic cross-references added from an external source) and write osisIDs
  my %osisID_note;
  my @splitosis = &splitOSIS($tmpf); # splitOSIS offers a massive speedup here!
  foreach my $sosis (@splitosis) {
    my $xml = $XML_PARSER->parse_file($sosis);
    foreach my $n ($XPC->findnodes('//osis:note[not(@resp)]', $xml)) {
      my @ids = &atomizeContext(&getNodeContext($n));
      my $osisID = @ids[0];
      # Reserve and write an osisID for each note. 
      my $i = 1;
      # The extension has 2 parts: type and instance. Instance is a number prefixed by a single letter.
      # Generic cross-references for the verse system are added from another source and will have the 
      # extensions: crossReference.rN or crossReference.pN (parallel passages).
      my $refext = ($n->getAttribute("placement") eq "foot" ? $FNREFEXT:'!' . ($n->getAttribute("type") ? $n->getAttribute("type"):'tnote') . '.t');
      my $id = "$myMod:$osisID$refext$i";
      while ($osisID_note{$id}) {$i++; $id = "$myMod:$osisID$refext$i";}
      
      if ($n->getAttribute('osisID') && $n->getAttribute('osisID') ne "$osisID$refext$i") {
        &ErrorBug("Overwriting note osisID \"".$n->getAttribute('osisID')."\" with \"$osisID$refext$i\".");
      }

      $n->setAttribute('osisID', "$osisID$refext$i");
      $osisID_note{"$myMod:$osisID$refext$i"}++;
    }
    &writeXMLFile($xml, $sosis);
  }
  &joinOSIS($output);
  $$osisP = $output;
}

sub oc_stringHash($) {
  my $s = shift;
  use Digest::MD5 qw(md5 md5_hex md5_base64);
  return substr(md5_hex(encode('utf8', $s)), 0, 4);
}

sub dashCamelCase($) {
  my $id = shift;
  my @p = split(/\-/, $id);
  for (my $x=1; $x<@p; $x++) {@p[$x] = ucfirst(@p[$x]);}
  return join('', @p);
}


# Check for TOC entries, and write as much TOC information as possible
sub writeTOC($$) {
  my $osisP = shift;
  my $modType = shift;

  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1writeTOC$3/;
  
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
    # Insure there are as many possible TOC entries for each book
    my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
    foreach my $bk (@bks) {
      for (my $t=1; $t<=3; $t++) {
        # Is there a TOC entry if this type? If not, add one if we know what it should be
        my @e = $XPC->findnodes('./osis:milestone[@n][@type="x-usfm-toc'.$t.'"] | ./*[1][self::osis:div]/osis:milestone[@n][@type="x-usfm-toc'.$t.'"]', $bk);
        if (@e && @e[0]) {next;}
        
        if ($t eq $toc && !$WRITETOC_MSG) {
          &Warn("At least one book (".$bk->getAttribute('osisID').") is missing a \\toc$toc SFM tag. 
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
          $name = $BOOKNAMES{$bk->getAttribute('osisID')}{@attrib[$t]};
          if ($name) {$type = @attrib[$t];}
        }
        
        # Otherwise try and get the default TOC from the first applicable title
        if (!$name && $t eq $toc) {
          my @title = $XPC->findnodes('./osis:title[@type="runningHead"]', $bk);
          if (!@title || !@title[0]) {
            @title = $XPC->findnodes('./osis:title[@type="main"]', $bk);
          }
          if (!@title || !@title[0]) {
            $name = $bk->getAttribute("osisID");
            $type = "osisID";
            &Error("writeTOC: Could not locate book name for \"$name\" in OSIS file.");
          }
          else {$name = @title[0]->textContent; $type = 'title';}
        }
        
        if ($name) {
          my $tag = "<milestone type=\"x-usfm-toc$t\" n=\"$name\" resp=\"$ROC\"/>";
          &Note("Inserting $type \\toc$t into \"".$bk->getAttribute('osisID')."\" as $name");
          $bk->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $bk->firstChild);
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
      $insertBefore->parentNode->insertBefore($toc, $insertBefore);
      &Note("Inserting top TOC entry and title within new introduction div as: $translationTitle");
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

      # Add bookGroup introduction TOC entries using OldTestamentTitle and NewTestamentTitle, if:
      # + there is more than one bookGroup
      # + the bookGroup has more than one book
      # + there are no bookSubGroups in the bookGroup
      # + there is no bookGroup introduction already
      if (@bookGroups > 1 && @{$XPC->findnodes('child::osis:div[@type="book"]', $bookGroup)} > 1 && !@bookSubGroupAuto && !$bookGroupIntroTOCM) {
        my $firstBook = @{$XPC->findnodes('descendant::osis:div[@type="book"][1]/@osisID', $bookGroup)}[0]->value;
        my $whichTestament = ($NT_BOOKS =~ /\b$firstBook\b/ ? 'New':'Old');
        my $testamentTitle = &conf($whichTestament.'TestamentTitle');
        my $toc = $XML_PARSER->parse_balanced_chunk('
<div type="introduction" resp="'.$ROC.'">
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1]'.$testamentTitle.'"/>
</div>');
        $bookGroup->insertBefore($toc, $bookGroup->firstChild);
        &Note("Inserting $whichTestament Testament TOC entry within new introduction div as: $testamentTitle");
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
        my $bookOrderP; &getCanon(&conf('Versification'), NULL, \$bookOrderP, NULL);
        if (!@{&scopeToBooks($div->getAttribute('scope'), $bookOrderP)}) {next;} # If scope is not an OSIS scope, then skip it
      }
      
      my $tocTitle;
      my $confentry = 'ARG_'.$div->getAttribute('osisID'); $confentry =~ s/\!.*$//;
      my $confTitle = &conf($confentry);
      my $combinedGlossaryTitle = &conf('CombinedGlossaryTitle');
      my $titleSubPublication = $CONF->{"TitleSubPublication[".$div->getAttribute('scope')."]"};
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
  
  
  &writeXMLFile($xml, $output, $osisP, 1);
}

sub getScopeTitle($) {
  my $scope = shift;
  
  $scope =~ s/\s/_/g;
  if (!$CONF->{"TitleSubPublication[$scope]"}) {
    return '';
  }
  return &conf("TitleSubPublication[$scope]");
}


# Split an OSIS file into separate book OSIS files, plus 1 non-book OSIS 
# file (one that contains everything else). This is intended for use with 
# joinOSIS to allow parsing smaller files for a big speedup. The only 
# assumption this routine makes is that bookGroup elements only contain 
# non-element children, such as text nodes, at the beginning of the 
# bookGroup (never between or after book div elements). If there are no 
# book divs, everything is put in other.osis.
sub splitOSIS($) {
  my $in_osis = shift;
  
  &Log("\nsplitOSIS: ".&encodePrintPaths($in_osis).":\n", 2);
  
  undef(%DOCUMENT_CACHE); # splitOSIS uses the same file paths over again and DOCUMENT_CACHE is keyed on file path!
  
  my @return;
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (-e $tmp) {remove_tree($tmp);}
  make_path($tmp);
  
  my @books; 
  my %bookGroup;
  
  my $xml = $XML_PARSER->parse_file($in_osis);
  my @bookElements = $XPC->findnodes('//osis:div[@type="bookGroup"]/osis:div[@type="book"]', $xml);
  my $isBible = (@bookElements && @bookElements[0]);
  
  if ($isBible) {
    # Mark bookGroup child elements which are between books, so their locations can later be restored
    my @bookGroupChildElements = $XPC->findnodes('//*[parent::osis:div[@type="bookGroup"]][preceding-sibling::osis:div[@type="book"]][following-sibling::osis:div[@type="book"]]', $xml);
    foreach my $bgce (@bookGroupChildElements) {
      $bgce->setAttribute('beforeBook', @{$XPC->findnodes('following-sibling::osis:div[@type="book"][1]', $bgce)}[0]->getAttribute('osisID'));
    }
    
    # Get books, remove them all, and save all remaining stuff as other.osis
    foreach my $book (@bookElements) {
      my $osisID = $book->getAttribute('osisID');
      push(@books, $osisID);
      $bookGroup{$osisID} = scalar(@{$XPC->findnodes('preceding::osis:div[@type="bookGroup"]', $book)});
      if (!$bookGroup{$osisID}) {$bookGroup{$osisID} = 0;}
      $book->unbindNode();
    }
  }
  
  push(@return, "$tmp/other.osis");
  &writeXMLFile($xml, @return[$#return]);
  
  if (!$isBible) {return @return;}
  
  # Prepare an osis file which has only a single book in it
  my $xml = $XML_PARSER->parse_file($in_osis);
  
  # remove books, except the first book (doing this before removing outside material speeds things up a huge amount!)
  my @bookElements = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $book (@bookElements) {
    if (@books[0] && $book->getAttribute('osisID') ne @books[0]) {$book->unbindNode();}
  }
  
  # remove all material outside of the book
  my @dels1 = $XPC->findnodes('//osis:div[@type="book" and @osisID="'.@books[0].'"]/preceding::node()', $xml);
  my @dels2 = $XPC->findnodes('//osis:div[@type="book" and @osisID="'.@books[0].'"]/following::node()', $xml);
  foreach my $del (@dels1) {$del->unbindNode();}
  foreach my $del (@dels2) {$del->unbindNode();}
  
  # Now save separate osis files for each book, encoding their order and bookGroup in the file-name
  my $bookGroup = @{$XPC->findnodes('//osis:div[@type="bookGroup"]', $xml)}[0];
  my $x = 0;
  do {
    my $bk = @books[$x];
    
    if ($x) {
      foreach my $book (@bookElements) {if ($book->getAttribute('osisID') eq $bk) {$bookGroup->appendChild($book);}}
    }
    
    push(@return, sprintf("%s/%02i %i %s.osis", $tmp, $x, $bookGroup{$bk}, $bk));
    
    &writeXMLFile($xml, @return[$#return]);
    
    foreach my $book (@bookElements) {if ($book->getAttribute('osisID') eq $bk) {$book->unbindNode();}}
    
    $x++;
  } while ($x < @books);
  
  return @return;
}
sub joinOSIS($) {
  my $out_osis = shift;
  
  my $tmp = "$TMPDIR/splitOSIS";
  if (!-e $tmp) {die "No splitOSIS tmp directory! \"$tmp\"\n";}
  
  opendir(JOSIS, $tmp) || die "joinOSIS could not open splitOSIS tmp directory \"$tmp\"\n";
  my @files = readdir(JOSIS);
  closedir(JOSIS);
  
  if (!-e "$tmp/other.osis") {die "joinOSIS must have file \"$tmp/other.osis\"!\n";}
  my $xml = $XML_PARSER->parse_file("$tmp/other.osis");
  
  foreach my $f (sort @files) {
    if ($f eq "other.osis" || $f =~ /^\./) {next;}
    if ($f !~ /^(\d+) (\d+) (.*?)\.osis$/) {
      &ErrorBug("joinOSIS bad file name \"$f\"");
    }
    my $x = $1;
    my $bookGroup = $2;
    my $bk = $3;
    $bkxml = $XML_PARSER->parse_file("$tmp/$f");
    my @bookNode = $XPC->findnodes('//osis:div[@type="book"]', $bkxml);
    if (@bookNode != 1) {
      &ErrorBug("joinOSIS file \"$f\" does not have just a single book.");
    }
    my @bookGroupNode = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
    if (!@bookGroupNode || !@bookGroupNode[$bookGroup]) {
      &ErrorBug("bookGroup \"$bookGroup\" for joinOSIS file \"$f\" not found.");
    }
    @bookGroupNode[$bookGroup]->appendChild(@bookNode[0]);
  }
  
  # Move maked bookGroupChildElements to their original inter-book locations
  foreach my $bb ($XPC->findnodes('//*[@beforeBook]', $xml)) {
    $beforeBook = $bb->getAttribute('beforeBook');
    $bb->removeAttribute('beforeBook');
    $bb->parentNode->insertBefore($bb, @{$XPC->findnodes("//osis:div[\@type='book'][\@osisID='$beforeBook'][1]", $xml)}[0]);
  }
  
  &writeXMLFile($xml, $out_osis);
}


sub writeMissingNoteOsisRefsFAST($) {
  my $osisP = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1writeMissingNoteOsisRefsFast$3/;
  
  &Log("\nWriting missing note osisRefs in OSIS file \"$$osisP\".\n");
  
  my @files = &splitOSIS($$osisP);
  
  my $count = 0;
  foreach my $file (@files) {
    &Log("$file\n", 2);
    my $xml = $XML_PARSER->parse_file($file);
    $count = &writeMissingNoteOsisRefs($xml);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($output);
  $$osisP = $output;
  
  &Report("Wrote \"$count\" note osisRefs.");
}

# A note's osisRef contains the passage to which a note applies. For 
# glossaries this is the note's context keyword. For Bibles this is also 
# the note's context, unless the note contains a reference of type 
# annotateRef, in which case the note applies to the annotateRef passage.
sub writeMissingNoteOsisRefs($) {
  my $xml = shift;
  
  my @notes = $XPC->findnodes('//osis:note[not(@osisRef)]', $xml);
  my $refSystem = &getRefSystemOSIS($xml);
  
  my $count = 0;
  foreach my $note (@notes) {
    my $osisRef = &getNodeContextOsisID($note);
    
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

sub removeDefaultWorkPrefixesFAST($) {
  my $osisP = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1removeDefaultWorkPrefixes$3/;
  
  &Log("\nRemoving default work prefixes in OSIS file \"$$osisP\".\n");
  
  my @files = &splitOSIS($$osisP);
  
  my %stats = ('osisRef'=>0, 'osisID'=>0);
  
  foreach my $file (@files) {
    &Log("$file\n", 2);
    my $xml = $XML_PARSER->parse_file($file);
    &removeDefaultWorkPrefixes($xml, \%stats);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($output);
  $$osisP = $output;
  
  &Report("Removed \"".$stats{'osisRef'}."\" redundant Work prefixes from osisRef attributes.");
  &Report("Removed \"".$stats{'osisID'}."\" redundant Work prefixes from osisID attributes.");
}

# Removes work prefixes of all osisIDs and osisRefs which match their
# respective osisText osisIDWork or osisRefWork attribute value (in 
# other words removes work prefixes which are unnecessary).
sub removeDefaultWorkPrefixes($\%) {
  my $xml = shift;
  my $statsP = shift;
  
  # normalize osisRefs
  my @osisRefs = $XPC->findnodes('//@osisRef', $xml);
  my $osisRefWork = &getOsisRefWork($xml);
  my $normedOR = 0;
  foreach my $osisRef (@osisRefs) {
    if ($osisRef->getValue() !~ /^$osisRefWork\:/) {next;}
    $new = $osisRef->getValue();
    $new =~ s/^$osisRefWork\://;
    $osisRef->setValue($new);
    $statsP->{'osisRef'}++;
  }
  
  # normalize osisIDs
  my @osisIDs = $XPC->findnodes('//@osisID', $xml);
  my $osisIDWork = &getOsisIDWork($xml);
  my $normedID = 0;
  foreach my $osisID (@osisIDs) {
    if ($osisID->getValue() !~ /^$osisIDWork\:/) {next;}
    $new = $osisID->getValue();
    $new =~ s/^$osisIDWork\://;
    $osisID->setValue($new);
    $statsP->{'osisID'}++;
  }
}

# Since Perl LibXML's XPATH-1.0 has nothing like the 2.0 "matches"
# function, the following becomes necessary...
sub getVerseTag($$$) {
  my $bkchvs = shift;
  my $xml = shift;
  my $findEID = shift;
  
  my $ida = ($findEID ? 'e':'s');
  
  my @r = $XPC->findnodes('//osis:verse[@'.$ida.'ID="'.$bkchvs.'"]', $xml);
  if (@r[0]) {return @r[0];}
  
  @r = $XPC->findnodes('//osis:verse[contains(@'.$ida.'ID, "'.$bkchvs.'")]', $xml);
  foreach my $rs (@r) {
    if ($rs && $rs->getAttribute($ida.'ID') =~ /\b\Q$bkchvs\E\b/) {return $rs;}
  }
  
  return;
}

# Run a Linux shell script. $flag can have these values:
# -1 = only log file
#  0 = log file (+ console unless $NOCONSOLELOG is set)
#  1 = log file + console (ignoring $NOCONSOLELOG)
#  2 = only console
#  3 = don't log anything
sub shell($$) {
  my $cmd = shift;
  my $flag = shift; # same as Log flag
  
  &Log("\n$cmd\n", $flag);
  my $result = decode('utf8', `$cmd 2>&1`);
  &Log($result."\n", $flag);
  
  return $result;
}

1;
