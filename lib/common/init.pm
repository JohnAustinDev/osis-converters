# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

use strict;

our ($CONFFILE, $DEBUG, $DEFAULT_DICTIONARY_WORDS, $DICTINPD, 
    $DICTIONARY_WORDS_NAMESPACE, $DICTMOD, $FONTS, $INOSIS, $INPD, 
    $LOGFILE, $MAININPD, $MAINMOD, $MOD, $MODULETOOLS_BIN, $MOD_OUTDIR, 
    $NO_OUTPUT_DELETE, $OSIS_NAMESPACE, $SCRD, $SCRIPT, $SCRIPT_NAME, 
    $TEI_NAMESPACE, $TMPDIR, $XML_PARSER, $XPC, %BOOKNAMES, 
    %CONV_OUTPUT_SUBDIR, %CONV_OUTPUT_FILES);

sub init_linux_script {
  # Global $forkScriptName will only be set when running from fork.pm, in  
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
  if (-e "$INPD/CF_osis2osis.txt" && $SCRIPT =~ /\/osis2osis$/) {
    require("$SCRD/lib/osis2osis.pm");
    &runCF_osis2osis('preinit');
    our $MOD_OUTDIR = &getModuleOutputDir();
    if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
    
    $TMPDIR = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";

    $LOGFILE = &initLogFile($LOGFILE, "$MOD_OUTDIR/OUT_".$SCRIPT_NAME."_$MOD.txt");
    return 1;
  }
  elsif ($SCRIPT_NAME =~ /defaults/) {
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
    "\"$INPD\" may not be an osis-converters project directory. If it is, then run 'defaults' to create a config.conf file.\n", 1);
  }
  
  $MOD_OUTDIR = &getModuleOutputDir();
  if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
  
  $TMPDIR = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";
  if (our $forkScriptName) { # will be set when called by forks.pm
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
  
  if ($SCRIPT_NAME =~ /^defaults$/) {return;}
  
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
  
  # Read BookNames.xml, if found, which can be used for localizing Bible book names
  foreach my $bknxml (split(/\n+/, &shell("find '$MAININPD/sfm' -name 'BookNames.xml' -print", 3, 1))) {
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

sub initInputOutputFiles {
  my $script_name = shift;
  my $inpd = shift;
  my $modOutdir = shift;
  my $tmpdir = shift;
  
  # Prepare the input OSIS file if needed
  if ($script_name =~ /^osis2(?!osis)/) {
    if (-e "$modOutdir/$MOD.xml") {
      &copy("$modOutdir/$MOD.xml", "$tmpdir/$MOD.xml");
      $INOSIS = "$tmpdir/$MOD.xml";
    }
    else {
      &Error(
"$script_name cannot find an input OSIS file at \"$modOutdir/$MOD.xml\".", 
'', 1);
    }
  }

  # Clean the output directory
  our $forkScriptName; # fork results should not be deleted
  if (!$NO_OUTPUT_DELETE && !$forkScriptName) {
    my $subdir = &const($CONV_OUTPUT_SUBDIR{$script_name});
    if ($subdir) {
      my $sd0 = (split(/\//, $subdir))[0];
      if (-e "$modOutdir/$sd0") {remove_tree("$modOutdir/$sd0");}
      make_path("$modOutdir/$subdir");
      $subdir = '/'.$subdir;
    }
    foreach my $glob (@{$CONV_OUTPUT_FILES{$script_name}}) {
      foreach my $f (glob($modOutdir.$subdir.'/'.&const($glob))) {
        unlink($modOutdir.$subdir.'/'.$f);
      }
    }
  }
  
  # init SFM files if needed
  if ($script_name =~ /^defaults$/ && -e "$inpd/sfm") {
    # check for BOM in SFM and clear it if it's there, also normalize line endings to Unix
    &shell("find \"$inpd/sfm\" -type f -exec sed '1s/^\xEF\xBB\xBF//' -i.bak {} \\; -exec rm {}.bak \\;", 3, 1);
    &shell("find \"$inpd/sfm\" -type f -exec dos2unix {} \\;", 3, 1);
  }
}

sub outdir {
  my $script = shift; if (!$script) {$script = $SCRIPT_NAME;}
  
  my $outdir = $MOD_OUTDIR;
  if ($CONV_OUTPUT_SUBDIR{$script}) {
    $outdir .= '/'.&const($CONV_OUTPUT_SUBDIR{$script});
  }
  
  return $outdir;
}

sub initLibXML {

  $XPC = XML::LibXML::XPathContext->new;
  $XPC->registerNs('osis', $OSIS_NAMESPACE);
  $XPC->registerNs('tei', $TEI_NAMESPACE);
  $XPC->registerNs('dw', $DICTIONARY_WORDS_NAMESPACE);
  $XML_PARSER = XML::LibXML->new();
}

1;
