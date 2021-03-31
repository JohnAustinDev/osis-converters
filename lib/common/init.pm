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

our ($CONFFILE, $DEBUG, $DICTINPD, $OUTDIR, $ADDDICTLINKS_NAMESPACE, 
    $DICTMOD, $FONTS, $INOSIS, $INPD, $LOGFILE, $MAININPD, $MAINMOD, 
    $MOD, $MODULETOOLS_BIN, $MOD_OUTDIR, $NO_OUTPUT_DELETE, 
    $OSIS_NAMESPACE, $SCRD, $SCRIPT, $SCRIPT_NAME, $TEI_NAMESPACE, 
    $TMPDIR, $XML_PARSER, $XPC, %BOOKNAMES, %CONV_OUTPUT_SUBDIR, 
    %CONV_OUTPUT_FILES, $OC_VERSION, %ARGS, $APPENDLOG);

sub init_linux_script {
  &Log("Running $SCRIPT_NAME version $OC_VERSION
-----------------------------------------------------\n\n");
  
  &logGitRevs();
  
  &timer('start');
  
  &initLibXML();
  
  %BOOKNAMES; &readBookNamesXML(\%BOOKNAMES);
  
  if ($SCRIPT_NAME =~ /defaults/) {
    &defaults(\%BOOKNAMES); # do this after readBookNamesXML() so %BOOKNAMES is set
    
    &readSetCONF();
    
    # $DICTMOD will be empty if there is no dictionary module for the project, but $DICTINPD always has a value
    $DICTMOD = ( -d $DICTINPD ? $MAINMOD . 'DICT' : '' );
  }
  
  if (!-e $CONFFILE) {
    &Error("There is no config.conf file: \"$CONFFILE\".", 
    "\"$INPD\" may not be an osis-converters project directory. If it is, then run 'defaults' to create a config.conf file.\n", 1);
  }
  
  $MOD_OUTDIR = &getModuleOutputDir();
  if (!-e $MOD_OUTDIR) {&make_path($MOD_OUTDIR);}
  
  $TMPDIR = &initTMPDIR();

  $LOGFILE = &initLOGFILE();
  
  &initModuleFiles();
  
  if ($SCRIPT_NAME =~ /^defaults$/) {return;}
  
  &checkConfGlobals();
    
  &checkProjectConfiguration();
    
  &checkRequiredConfEntries();
  
  if (&conf('Font')) {
    &checkFont(&conf('Font'));
  }
  
  if (-e "$INPD/images") {
    &checkImageFileNames("$INPD/images");
  }
  
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

# Return a module's root output directory. 
# Requires $OUTDIR and $MAININPD already be set.
sub getModuleOutputDir {
  my $mod = shift; if (!$mod) {$mod = $MOD;}
  
  if ($OUTDIR && ! -d $OUTDIR) {
    $OUTDIR = undef;
    &Error("OUTDIR is not an existing directory: " . &findConf('OUTDIR'),
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

# Delete/create/return $TMPDIR as needed. If $TMPDIR is already
# set (such as by a fork) it does nothing but return the value of 
# $TMPDIR.
sub initTMPDIR {
  if (!$SCRIPT_NAME) {&ErrorBug("SCRIPT_NAME not set.", 1);}
  if (!$MOD_OUTDIR)  {&ErrorBug("MOD_OUTDIR not set.", 1);}
  
  if ($TMPDIR) {return $TMPDIR;}
  
  my $tmpdir = "$MOD_OUTDIR/tmp/$SCRIPT_NAME";
  
  # Only delete $TMPDIR if this is not a fork, &scriptName() eq $SCRIPT_NAME
  if (-d $tmpdir && !$NO_OUTPUT_DELETE && 
        &scriptName() eq $SCRIPT_NAME) {
    remove_tree($tmpdir);
  }
  
  if (! -e $tmpdir) {make_path($tmpdir);}
  
  return $tmpdir;
}

# Delete/set/return $LOGFILE as needed.
sub initLOGFILE {
  if (!$SCRIPT_NAME) {&ErrorBug("SCRIPT_NAME not set.", 1);}
  if (!$MOD_OUTDIR)  {&ErrorBug("MOD_OUTDIR not set.", 1);}

  my $log = ( $LOGFILE ? $LOGFILE : "$MOD_OUTDIR/LOG_$SCRIPT_NAME.txt" );
  
  if (-f $log && !$APPENDLOG) {
    unlink($log);
  }
  
  $LOGFILE = $log; &Log(); # clear the log buffer
  
  return $log;
}

sub initModuleFiles {
  if (!$MOD)         {&ErrorBug("MOD not set.", 1);}
  if (!$INPD)        {&ErrorBug("INPD not set.", 1);}
  if (!$TMPDIR)      {&ErrorBug("TMPDIR not set.", 1);}
  if (!$SCRIPT_NAME) {&ErrorBug("SCRIPT_NAME not set.", 1);}
  if (!$MOD_OUTDIR)  {&ErrorBug("MOD_OUTDIR not set.", 1);}

  # Copy the input OSIS file if needed
  if ($SCRIPT_NAME =~ /^osis2(?!osis)/) {
    if (-e "$MOD_OUTDIR/$MOD.xml") {
      &copy("$MOD_OUTDIR/$MOD.xml", "$TMPDIR/00_$MOD.xml");
      $INOSIS = "$TMPDIR/00_$MOD.xml";
    }
    else {
      &Error("$SCRIPT_NAME cannot find an input OSIS file at " . 
        "\"$MOD_OUTDIR/$MOD.xml\".", '', 1);
    }
  }

  # Delete old output files/directories
  if (!$NO_OUTPUT_DELETE && &scriptName() eq $SCRIPT_NAME) {
    my $subdir = &const($CONV_OUTPUT_SUBDIR{$SCRIPT_NAME});
    if ($subdir) {
      my $sd0 = (split(/\//, $subdir))[0];
      if (-e "$MOD_OUTDIR/$sd0") {
        remove_tree("$MOD_OUTDIR/$sd0");
      }
      make_path("$MOD_OUTDIR/$subdir");
      $subdir = '/'.$subdir;
    }
    foreach my $glob (@{$CONV_OUTPUT_FILES{$SCRIPT_NAME}}) {
      foreach my $f (glob($MOD_OUTDIR.$subdir.'/'.&const($glob))) {
        if (! -e $f) {next;}
        if (-d $f) {remove_tree($f);}
        else {unlink($f);}
      }
    }
  }
  
  # init SFM files if needed
  if ($SCRIPT_NAME =~ /^defaults$/ && -e "$INPD/sfm") {
    # check for BOM in SFM and clear it if it's there, also normalize line endings to Unix
    &shell("find \"$INPD/sfm\" -type f -exec sed '1s/^\xEF\xBB\xBF//' -i.bak {} \\; -exec rm {}.bak \\;", 3, 1);
    &shell("find \"$INPD/sfm\" -type f -exec dos2unix {} \\;", 3, 1);
  }
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
  
  if ($MOD eq $MAINMOD && &conf('ProjectType') eq 'childrens_bible') {
    if ($MOD !~ /CB$/) {
      &Error("Children's Bible project codes should end with 'CB'.", '', 1);
    }
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
  $XPC->registerNs('dw', $ADDDICTLINKS_NAMESPACE);
  $XML_PARSER = XML::LibXML->new();
}

1;
