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
$OSISSCHEMA = "http://www.crosswire.org/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd";
$INDENT = "<milestone type=\"x-p-indent\" />";
$LB = "<lb />";
$FNREFSTART = "<reference type=\"x-note\" osisRef=\"TARGET\">";
$FNREFEND = "</reference>";
$FNREFEXT = "!note.n";
$MAX_MATCH_WORDS = 3;
@Roman = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX");
$OT_BOOKS = "Gen Exod Lev Num Deut Josh Judg Ruth 1Sam 2Sam 1Kgs 2Kgs 1Chr 2Chr Ezra Neh Esth Job Ps Prov Eccl Song Isa Jer Lam Ezek Dan Hos Joel Amos Obad Jonah Mic Nah Hab Zeph Hag Zech Mal";
$NT_BOOKS = "Matt Mark Luke John Acts Rom 1Cor 2Cor Gal Eph Phil Col 1Thess 2Thess 1Tim 2Tim Titus Phlm Heb Jas 1Pet 2Pet 1John 2John 3John Jude Rev";
{ my $bn = 1;
  foreach my $bk (split(/\s+/, "$OT_BOOKS $NT_BOOKS")) {
    $OSISBOOKS{$bk} = $bn; $bn++;
  }
}
$OSISBOOKSRE = "$OT_BOOKS $NT_BOOKS"; $OSISBOOKSRE =~ s/\s+/|/g;
$VSYS_INSTR_RE  = "($OSISBOOKSRE)\\.(\\d+)(\\.(\\d+)(\\.(\\d+))?)?";
$VSYS_PINSTR_RE = "($OSISBOOKSRE)\\.(\\d+)(\\.(\\d+)(\\.(\\d+|PART))?)?";
@USFM2OSIS_PY_SPECIAL_BOOKS = ('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other');
$DICTIONARY_NotXPATH_Default = "ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb or self::osis:hi]";
$DICTIONARY_WORDS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
$DICTIONARY_WORDS = "DictionaryWords.xml";
$UPPERCASE_DICTIONARY_KEYS = 1;
$NOCONSOLELOG = 1;
$SFM2ALL_SEPARATE_LOGS = 1;
$ROC = 'x-oc'; # meaning osis-converters is responsible for adding this element
$VSYS{'prefix_vs'} = 'x-vsys';
$VSYS{'resp_vs'} = $VSYS{'prefix_vs'};
$VSYS{'AnnoTypeSource'} = $VSYS{'prefix_vs'}.'-source';
$VSYS{'missing_vs'} = $VSYS{'prefix_vs'}.'-missing';
$VSYS{'movedto_vs'} = $VSYS{'prefix_vs'}.'-movedto';
$VSYS{'fitted_vs'} = $VSYS{'prefix_vs'}.'-fitted';
$VSYS{'start_vs'} = '-start';
$VSYS{'end_vs'} = '-end';


require("$SCRD/scripts/bible/getScope.pl");
require("$SCRD/scripts/bible/fitToVerseSystem.pl"); # This defines some globals
require("$SCRD/scripts/osis2osis.pl");
require("$SCRD/scripts/common_cb.pl");

sub init_linux_script() {
  chdir($SCRD);

  $GITHEAD = &shell("git rev-parse HEAD 2>/dev/null", 3); chomp($GITHEAD);
  
  $MODULETOOLS_GITHEAD = &shell("cd \"$MODULETOOLS_BIN\" && git rev-parse HEAD 2>/dev/null", 3); chomp($MODULETOOLS_GITHEAD);
  
  &initLibXML();
  
  &readBookNamesXML();
  
  if ($SCRIPT_NAME =~ /(osis2osis|sfm2all)/ && $INPD !~ /DICT$/ && -e "$DICTINPD/CF_osis2osis.txt") {
    &runOsis2osis('preinit', $DICTINPD);
  }
  if ($SCRIPT_NAME =~ /(osis2osis|sfm2all)/ && -e "$INPD/CF_osis2osis.txt") {
    &runOsis2osis('preinit', $INPD);
  }
  elsif ($SCRIPT_NAME =~ /sfm2all/) {
    &checkAndWriteDefaults(); # do this after readBookNamesXML() so %BOOKNAMES is set
  }
  
  # $DICTMOD will be empty if there is no dictionary module for the project, but $DICTINPD always has a value
  my %c; &readConfFile("$MAININPD/config.conf", \%c); my $cn = "${MAINMOD}DICT";
  $DICTMOD = (%c{'Companion'} =~ /\b$cn\b/ ? $cn:'');
  
  if (!-e $CONFFILE) {
    &Error("Could not find or create a \"$CONFFILE\" file.
\"$INPD\" may not be an osis-converters project directory.
A project directory must, at minimum, contain an \"sfm\" subdirectory.
\n".encode("utf8", $LogfileBuffer), '', 1);
  }
  
  $OUTDIR = &getOUTDIR($INPD);
  if (!-e $OUTDIR) {make_path($OUTDIR);}
  
  $TMPDIR = "$OUTDIR/tmp/$SCRIPT_NAME";
  if (!$NO_OUTPUT_DELETE) {
    if (-e $TMPDIR) {remove_tree($TMPDIR);}
    make_path($TMPDIR);
  }
  
  &initInputOutputFiles($SCRIPT_NAME, $INPD, $OUTDIR, $TMPDIR);
  
  if ($INPD eq $MAININPD && (-e "$INPD/eBook/convert.txt" || -e "$INPD/html/convert.txt")) {
    &update_removeConvertTXT();
  }
  
  if ($DICTMOD && -e "$DICTINPD/config.conf") {
    &update_dictConfig($CONFFILE);
  }
  
  &setConfGlobals(&readConf());
  
  &checkConfGlobals();
  
  &checkRequiredConfEntries();
  
  &checkProjectConfiguration();
  
  # Set default to 'on' for the following OSIS processing steps
  my @CF_files = ('addScripRefLinks', 'addFootnoteLinks');
  foreach my $s (@CF_files) {if (-e "$INPD/CF_$s.txt") {$$s = 'on_by_default';}}
  if ($SCRIPT_NAME !~ /osis2osis/) {
    $addCrossRefs = "on_by_default";
    if ($INPD eq $DICTINPD) {$addSeeAlsoLinks = 'on_by_default';}
    elsif (-e "$INPD/$DICTIONARY_WORDS") {$addDictLinks = 'on_by_default';}
  }
  
  my $appendlog = ($LOGFILE ? 1:0);
  if (!$LOGFILE) {$LOGFILE = "$OUTDIR/OUT_".$SCRIPT_NAME."_$MOD.txt";}
  if (!$appendlog && -e $LOGFILE) {unlink($LOGFILE);}
  
  if ($SCRIPT_NAME !~ /osis2ebook/) {&timer('start');}
  
  &Log("\nUsing ".`calibre --version`);
  &Log("osis-converters git rev: $GITHEAD\n");
  &Log("Module-tools git rev: $MODULETOOLS_GITHEAD at $MODULETOOLS_BIN\n");
  &Log("\n-----------------------------------------------------\nSTARTING $SCRIPT_NAME.pl\n\n");
  
  $DEFAULT_DICTIONARY_WORDS = "$OUTDIR/DictionaryWords_autogen.xml";
  
  if (&conf('Font')) {&checkFont(&conf('Font'));}
  
  if (-e "$INPD/images") {
    my $spaces = &shell("find $INPD/images -type f -name \"* *\" -print", 3);
    if ($spaces) {
      &Error("Image filenames must not contain spaces:\n$spaces", "Remove or replace space characters in these image file names.");
    }
  }
  &Debug("Linux script ".(&runningInVagrant() ? "on virtual machine":"on host").":\n\tOUTDIR=$OUTDIR\n\tTMPDIR=$TMPDIR\n\tLOGFILE=$LOGFILE\n\tMAININPD=$MAININPD\n\tMAINMOD=$MAINMOD\n\tDICTINPD=$DICTINPD\n\tDICTMOD=$DICTMOD\n");
}
# This is only needed to update old osis-converters projects
sub update_removeConvertTXT() {
  &Warn("UPDATE: Found outdated convert.txt. Updating...");
  my $neweb = &updateConvertTXT("$MAININPD/eBook/convert.txt");
  if ($neweb) {$neweb = "\n$neweb";}
  my $newhm = &updateConvertTXT("$MAININPD/html/convert.txt");
  if ($newhm) {$newhm = "\n[osis2html]\n$newhm";}
  my $new = $neweb.$newhm;
  if (!$new) {return;}
  if (!open(ACON, ">>:encoding(UTF-8)", $CONFFILE)) {
    &ErrorBug("update_removeConvertTXT could not append to $CONFFILE");
    return;
  }
  print ACON $new;
  &Warn("<-UPDATE: Appending to config.conf:\n$new");
  close(ACON);
}
# This is only needed to update old osis-converters projects
sub updateConvertTXT($) {
  my $convtxt = shift;
  
  if (! -e $convtxt) {return '';}
  
  my $new = '';
  if (open(CONV, "<:encoding(UTF-8)", $convtxt)) {
    while(<CONV>) {
      if ($_ =~ /^#/) {next;}
      elsif ($_ =~ /^([^=]+?)\s*=\s*(.*?)\s*$/) {
        my $e = $1; my $v = $2;
        my $warn;
        if ($e eq 'MultipleGlossaries') {
          $warn = "Changing $e=$v to";
          $e = 'CombineGlossaries';
          $v = ($v && $v !~ /^(false|0)$/i ? 'false':'true');
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^CreateFullPublication(\d+)/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $e = 'ScopeSubPublication'.$n;
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^TitleFullPublication(\d+)/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $e = 'TitleSubPublication'.$n;
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Group1\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $e = 'OldTestamentTitle';
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Group2\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $e = 'NewTestamentTitle';
          &Warn("<-$warn $e=$v");
        }
        elsif ($e =~ /^Title\s*$/) {
          my $n = $1;
          $warn = "Changing $e=$v to ";
          $e = 'TranslationTitle';
          &Warn("<-$warn $e=$v");
        }
        $new .= "$e=$v\n";
      }
    }
    close(CONV);
  }
  else {&Warn("Did not find \"$convtxt\"");}
  
  &Warn("<-UPDATE: Removing outdated convert.txt: $convtxt");
  &Note("The file: $convtxt which was used for 
various settings has now been replaced by a section in the config.conf 
file. The convert.txt file will be deleted. Your config.conf will have 
a new section with that information.");
  unlink($convtxt);
  
  return $new;
}

# This is only needed to update old osis-converters projects
sub update_dictConfig($) {
  my $mconf = shift;

  &Warn("UPDATE: Found outdated DICT config.conf. Updating...");
  my %mainConf;
  &readConfFile($mconf, \%mainConf);
  my %dictConf;
  my $dconf = "$DICTINPD/config.conf";
  &readConfFile($dconf, \%dictConf);
  &Warn("<-UPDATE: Removing outdated DICT config.conf: $dconf");
  unlink($dconf);
  &Note("The file: $dconf which was used for 
DICT settings has now been replaced by a section in the config.conf 
file. The DICT config.conf file will be deleted. Your config.conf will 
have new section with that information.");
  foreach my $de (sort keys %dictConf) {
    if ($de eq 'ModuleName') {next;}
    if ($mainConf{$de} eq $dictConf{$de}) {next;}
    $mainConf{"$DICTMOD+$de"} = $dictConf{$de};
  }

  return &writeConf($mconf, \%mainConf);
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

sub readBookNamesXML() {
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
        if ($BOOKNAMES{$bk}{$t} && $BOOKNAMES{$bk}{$t} ne $bkelem->getAttribute($t)) {
          my $new = $bkelem->getAttribute($t);
          if (
            ($t eq 'short' && length($new) > length($BOOKNAMES{$bk}{$t})) || 
            ($t eq 'long' && length($new) < length($BOOKNAMES{$bk}{$t}))
          ) {
            $new = $BOOKNAMES{$bk}{$t};
            &Warn("Multiple $t definitions for $bk. Keeping '$new' rather than '".$bkelem->getAttribute($t)."'.", "That the resulting value is correct, and possibly fix the incorrect one.");
          }
          else {
            &Warn("Multiple $t definitions for $bk. Using '$new' rather than '".$BOOKNAMES{$bk}{$t}."'.", "That the resulting value is correct, and possibly fix the incorrect one.");
          }
        }
        $BOOKNAMES{$bk}{$t} = $bkelem->getAttribute($t);
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
  if ($FONTS =~ /^https?\:/) {
    my $p = expandLinuxPath("~/.osis-converters/fonts");
    if (!-e $p) {mkdir($p);}
    shell("cd '$p' && wget -r --quiet --level=1 -erobots=off -nd -np -N -A '*.*' -R '*.html*' '$FONTS'", 3);
    &wgetSyncDel($p);
    $FONTS = $p;
  }

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
        &Note("Using font file \"$f\" as ".$FONT_FILES{$font}{$f}{'style'}." font for \"$font\".\n");
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

# Delete any local files that were not just downloaded by wget
sub wgetSyncDel($) {
  my $p = shift;
  
  $p =~ s/\/\s*$//;
  if ($p !~ /\/\Q.osis-converters\E\//) {return;} # careful with deletes
  my $dname = $p; $dname =~ s/^.*\///;
  my $html = $XML_PARSER->load_html(location  => "$p/$dname.tmp", recover => 1);
  if ($html) {
    my @files = $html->findnodes('//tr//a');
    my @files = map($_->textContent() , @files);
    opendir(PD, $p) or &ErrorBug("Could not open dir $p", '', 1);
    my @locfiles = readdir(PD); closedir(PD);
    foreach my $lf (@locfiles) {
      if (-d "$p/$lf") {next;}
      my $del = 1; foreach my $f (@files) {if ($f eq $lf) {$del = 0;}}
      if ($del) {unlink("$p/$lf");}
    }
  }
  else {&ErrorBug("The $dname.tmp HTML was undreadable: $p/$dname.tmp");}
  shell("cd '$p' && rm *.tmp", 3);
}

sub getOUTDIR($) {
  my $inpd = shift;
  
  my $outdir = ($OUTDIR ? $OUTDIR:"$inpd/output");
  if ($outdir !~ /\/output$/) {
    my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
    $outdir =~ s/[\\\/]\s*$//; # remove any trailing slash
    $outdir .= '/'.$sub;
  }

  return $outdir;
}

# Parse the module's DICTIONARY_WORDS to DWF. Check for outdated 
# DICTIONARY_WORDS markup and update it. Validate DICTIONARY_WORDS 
# entries against a dictionary OSIS file's keywords. Validate 
# DICTIONARY_WORDS xml markup. Return 1 on successful parsing and 
# checking without error, 0 otherwise. 
sub loadDictionaryWordsXML($) {
  my $dictosis = shift;
  my $noupdateMarkup = shift;
  my $noupdateEntries = shift;
  
  if (! -e "$INPD/$DICTIONARY_WORDS") {return 0;}
  $DWF = $XML_PARSER->parse_file("$INPD/$DICTIONARY_WORDS");
  
  # Check for old DICTIONARY_WORDS markup and update or report
  my $errors = 0;
  my $update = 0;
  my $tst = @{$XPC->findnodes('//dw:div', $DWF)}[0];
  if (!$tst) {
    &Error("Missing namespace declaration in: \"$INPD/$DICTIONARY_WORDS\", continuing with default.", "Add 'xmlns=\"$DICTIONARY_WORDS_NAMESPACE\"' to root element of \"$INPD/$DICTIONARY_WORDS\".");
    $errors++;
    my @ns = $XPC->findnodes('//*', $DWF);
    foreach my $n (@ns) {$n->setNamespace($DICTIONARY_WORDS_NAMESPACE, 'dw', 1); $update++;}
  }
  my $tst = @{$XPC->findnodes('//*[@highlight]', $DWF)}[0];
  if ($tst) {
    &Error("Ignoring outdated attribute: \"highlight\" found in: \"$INPD/$DICTIONARY_WORDS\"", "Remove the \"highlight\" attribute and use the more powerful notXPATH attribute instead.");
    $errors++;
  }
  my $tst = @{$XPC->findnodes('//*[@withString]', $DWF)}[0];
  if ($tst) {
    $errors++;
    &Error("\"withString\" attribute is no longer supported.", "Remove withString attributes from $DICTIONARY_WORDS and replace it with XPATH=<xpath-expression> instead.");
  }
  
  # Save any updates back to source dictionary_words_xml and reload
  if ($update) {
    &writeXMLFile($DWF, "$dictionary_words_xml.tmp");
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
  my @r = $XPC->findnodes('//dw:entry/dw:name[translate(text(), "_,;[(", "_____") != text()][count(following-sibling::dw:match) = 1]', $DWF);
  if (!@r[0]) {@r = ();}
  &Log("\n");
  &Report("Compound glossary entry names with a single match element: (".scalar(@r)." instances)");
  if (@r) {
    &Note("Multiple <match> elements should probably be added to $DICTIONARY_WORDS\nto match each part of the compound glossary entry.");
    foreach my $r (@r) {&Log($r->textContent."\n");}
  }
  
  my $valid = 0;
  if ($errors == 0) {$valid = &validateDictionaryWordsXML($DWF);}
  if ($valid) {&Note("$INPD/$DICTIONARY_WORDS has no unrecognized elements or attributes.\n");}
  
  return ($valid && $errors == 0 ? 1:0);
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
  
  # Check that all dictosis keywords (except NAVEMNU keywords) are included as entries in dictionary_words_xml
  foreach my $osisIDa (@dictOsisIDs) {
    if (!$osisIDa || @{$XPC->findnodes('./ancestor::osis:div[@type="glossary"][@scope="NAVMENU"][1]', $osisIDa)}[0]) {next;}
    my $osisID = $osisIDa->value;
    my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
    
    my $match = 0;
    foreach my $dwfOsisRef (@dwfOsisRefs) {
      if (!$dwfOsisRef) {next;}
      my $osisRef = $dwfOsisRef->value;
      my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
    
      my $name = @{$XPC->findnodes('parent::dw:entry/dw:name[1]', $dwfOsisRef)}[0];
      
      if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last;}

      # Update entry osisRefs that need to be, and can be, updated
      elsif ($allowUpdate && &uc2($osisIDa->parentNode->textContent) eq &uc2($name->textContent)) {
        $match = 1;
        $update++;
        $dwfOsisRef->setValue(entry2osisRef($osisID_mod, $osisID));
        foreach my $c ($name->childNodes()) {$c->unbindNode();}
        $name->appendText($osisIDa->parentNode->textContent);
        last;
      }
    }
    if (!$match) {&Warn("Missing entry \"$osisID\" in $dictionary_words_xml", "That you don't want any links to this entry."); $allmatch = 0;}
  }
  
  # Check that all dictionary_words_xml entries are included as keywords in dictosis
  foreach my $dwfOsisRef (@dwfOsisRefs) {
    if (!$dwfOsisRef) {next;}
    my $osisRef = $dwfOsisRef->value;
    my $osisRef_mod = ($osisRef =~ s/^(.*?):// ? $1:'');
    
    my $match = 0;
    foreach my $osisIDa (@dictOsisIDs) {
      if (!$osisIDa) {next;}
      my $osisID = $osisIDa->value;
      my $osisID_mod = ($osisID =~ s/^(.*?):// ? $1:$osismod);
      if ($osisID_mod eq $osisRef_mod && $osisID eq $osisRef) {$match = 1; last;}
    }
    if (!$match) {&Error("Extra entry \"$osisRef\" in $dictionary_words_xml", "Remove this entry from $dictionary_words_xml because does not appear in $DICTMOD."); $allmatch = 0;}
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
  my $outdir = shift;
  my $tmpdir = shift;
  
  my $sub = $inpd; $sub =~ s/^.*?([^\\\/]+)$/$1/;
  
  my @outs;
  if ($script_name =~ /^(osis2osis|sfm2osis)$/) {
    $OUTOSIS = "$outdir/$sub.xml"; push(@outs, $OUTOSIS);
  }
  if ($script_name =~ /^(osis2sword)$/) {
    $OUTZIP = "$outdir/$sub.zip"; push(@outs, $OUTZIP);
    $SWOUT = "$outdir/sword"; push(@outs, $SWOUT);
  }
  if ($script_name =~ /^osis2GoBible$/) {
    $GBOUT = "$outdir/GoBible/$sub"; push(@outs, $GBOUT);
  }
  if ($script_name =~ /^osis2ebooks$/) {
    $EBOUT = "$outdir/eBook"; push(@outs, $EBOUT);
  }
  if ($script_name =~ /^osis2html$/) {
    $HTMLOUT = "$outdir/html"; push(@outs, $HTMLOUT);
  }

  if ($script_name =~ /^(osis2sword|osis2GoBible|osis2ebooks|osis2html)$/) {
    if (-e "$outdir/$sub.xml") {
      &copy("$outdir/$sub.xml", "$tmpdir/$sub.xml");
      $INOSIS = "$tmpdir/$sub.xml";
    }
    else {
      &ErrorBug("$script_name.pl cannot find an input OSIS file at \"$outdir/$sub.xml\".", '', 1);
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
  if ($script_name =~ /^sfm2all$/ && -e "$inpd/sfm") {
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
sub checkAndWriteDefaults() {
  
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
    if (-e "$MAININPD/config.conf") {
      if (my $comps = &readConf()->{'Companion'}) {
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
  
  # Custommize any new default files which need it (in order)
  foreach my $dc (@customDefaults) {
    foreach my $file (@newDefaultFiles) {
      if ($file =~ /\/\Q$dc\E$/) {
        my $modName = ($file =~ /\/$projName\/($projName)DICT\// ? $projName.'DICT':$projName);
        my $modType = ($modName eq $projName ? $projType:'dictionary');
        
        &Note("Customizing $file...");
        if    ($file =~ /config\.conf$/)             {&customize_conf($file, $modName, $modType, $haveDICT);}
        elsif ($file =~ /CF_usfm2osis\.txt$/)        {&customize_usfm2osis($file, $modType);}
        elsif ($file =~ /CF_addScripRefLinks\.txt$/) {&customize_addScripRefLinks($file);}
        else {&ErrorBug("Unknown customization type $dc for $file", "Write a customization function for this type of file.", 1);}
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
    &ErrorBug("The 'dictionary' modType does not have its own config.conf file, but customize_conf was called with modType='dictionary'.", '', 1);
  }
 
  # Save any comments at the end of the default config.conf so they can 
  # be added back after writing the new conf file.
  my $comments = '';
  if (open(MCF, "<:encoding(UTF-8)", $conf)) {
    while(<MCF>) {
      if ($comments) {$comments .= $_;}
      elsif ($_ =~ /^\Q#COMMENTS-ONLY-MUST-FOLLOW-NEXT-LINE/) {$comments = "\n";}
    }
    close(MCF);
  }
 
  # If there is any existing $modName conf that is located in REPOSITORY 
  # then start with that instead. This SWORD conf will only have one 
  # section, and any entries in the repo conf that were added by osis-
  # converters will be dropped.
  if ($REPOSITORY) {
    my $swautogen = join('|', @SWORD_AUTOGEN);
    my $cfile = $REPOSITORY.'/'.lc($modName).".conf";
    my $ctext = &shell("wget \"$cfile\" -q -O -", 3);
    $ctext =~ s/^(.+?)\n\[[^\]]+\].*$/$1/s;    # strip all after next section
    $ctext =~ s/^($swautogen)\s*=[^\n]*\n//mg; # strip @SWORD_AUTOGEN entries
    if ($ctext) {
      &Note("Default conf was located in REPOSITORY: $cfile", 1); &Log("$ctext\n\n");
      if (open(CNF, ">:encoding(UTF-8)", $conf)) {
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
  
  # ScopeSubPublication & TitleSubPublicationN
  my $pubn = 1;
  if (opendir(SFM, "$MAININPD/sfm")) {
    my @subs = readdir(SFM);
    closedir(SFM);
    foreach my $sub (@subs) {
      if (!-d "$MAININPD/sfm/$sub" || $sub =~ /^\./) {next;}
      my $scope = $sub; $scope =~ s/_/ /g;
      &setConfValue(\%newConf, 'ScopeSubPublication'.$pubn, $scope, 1);
      &setConfValue(\%newConf, 'TitleSubPublication'.$pubn, "Title of Sub-Publication $pubn".' DEF', 1);
      $pubn++;
    }
  }
  else {&ErrorBug("customize_conf could not open $MAININPD/sfm");}
  
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
  if (open(MCF, "<:encoding(UTF-8)", $conf)) {
    while(<MCF>) {
      if ($defs && $. != 1 && $_ =~ /^\[/) {$newconf .= "$defs\n"; $defs = '';}
      $newconf .= $_;
    }
    $newconf .= $comments;
    close(MCF);
  }
  else {&ErrorBug("customize_conf could not open config file $conf");}
  if ($newconf) {
    if (open(MCF, ">:encoding(UTF-8)", $conf)) {
      print MCF $newconf;
      close(MCF);
    }
    else {&ErrorBug("customize_conf could not open config file $conf");}
  }
}

sub customize_addScripRefLinks($) {
  my $cf = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  # Collect all available Bible book abbreviations
  my %abbrevs;
  # from BookNames.xml (%BOOKNAMES)
  foreach my $bk (keys %BOOKNAMES) {
    foreach my $type (keys %{$BOOKNAMES{$bk}}) {
      $abbrevs{$BOOKNAMES{$bk}{$type}} = $bk;
    }
  }
  # from SFM files (%USFM)
  foreach my $f (keys %{$USFM{'bible'}}) {
    foreach my $t (keys %{$USFM{'bible'}{$f}}) {
      if ($t !~ /^toc\d$/) {next;}
      $abbrevs{$USFM{'bible'}{$f}{$t}} = $USFM{'bible'}{$f}{'osisBook'};
    }
  }
  
  # Write them to CF_addScripRefLinks.txt in the most user friendly way possible
  @allbks = split(/\s+/, $OT_BOOKS); push(@bks, split(/\s+/, $NT_BOOKS));
  if (!open(CFT, ">:encoding(UTF-8)", "$cf.tmp")) {&ErrorBug("Could not open \"$cf.tmp\"", '', 1);}
  if (!open (CFF, "<:encoding(UTF-8)", $cf)) {&ErrorBug("Could not open \"$cf\"", '', 1);}
  while(<CFF>) {
    if ($_ =~ /^#(\S+)\s*=\s*$/) {
      my $osis = $1;
      my $p = &getAllAbbrevsString($osis, \%abbrevs);
      if ($p) {
        print CFT $p;
        next;
      }
    }
    print CFT $_;
  }
  close(CFF);
  foreach my $osis (@allbks) {print CFT &getAllAbbrevsString($osis, \%abbrevs);}
  close(CFT);
  unlink($cf);
  move("$cf.tmp", $cf);
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
  
  if (!open (CFF, ">>$cf")) {&ErrorBug("Could not open \"$cf\"", '', 1);}
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
    
    # peripherals need a target location in the OSIS file added to their ID
    if ($USFM{$modType}{$f}{'peripheralID'}) {
      #print CFF "\n# Use location == <xpath> to place this peripheral in the proper location in the OSIS file\n";
      if (defined($ID_TYPE_MAP{$USFM{$modType}{$f}{'peripheralID'}})) {
        print CFF "EVAL_REGEX($r):s/^(\\\\id ".$USFM{$modType}{$f}{'peripheralID'}.".*)\$/\$1";
      }
      else {
        print CFF "EVAL_REGEX($r):s/^(\\\\id )".$USFM{$modType}{$f}{'peripheralID'}."(.*)\$/\$1FRT\$2";
      }
      
      my @instructions;
      if ($scope) {push(@instructions, "scope == $scope");} # scope is first instruction because it only effects following instructions
      if ($modType eq 'bible') {
        push(@instructions, &getOsisMap('location', $scope));
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
        print CFF "$line/m\n";
      }
      
    }

    print CFF "RUN:$r\n";
  }
  close(CFF);
}

# Given an official peripheral description and scope, return the
# CF_usfm2osis.txt code for default placement of the peripheral within 
# an OSIS file. When $pt is 'location' (an entire file) it is placed
# in the proper bookGroup, or before the first book of $scope, or else 
# osis:header
sub getOsisMap($) {
  my $pt = shift;
  my $scope = shift;
  
  my $scopePath = 'osis:header';
  if ($scope) {
    if ($scope eq 'Matt-Rev') {$scopePath = 'osis:div[@type="bookGroup"][last()]/node()[1]';}
    elsif ($scope eq 'Gen-Mal') {$scopePath = 'osis:div[@type="bookGroup"][1]/node()[1]';}
    else {
      $scopePath = ($scope =~ /^([^\s\-]+)/ ? $1:'');
      if (!$scopePath || !$OSISBOOKS{$scopePath}) {
        &Error("USFM file's scope \"$scope\" is not recognized.", 
"Make sure the sfm sub-directory is named using a proper OSIS 
book scope, such as: 'Ruth_Esth_Jonah' or 'Matt-Rev'");
        $scopePath = 'osis:header/following-sibling::node()[1]';
      }
      else {$scopePath = 'osis:div[@type="book"][@osisID="'.$scopePath.'"]';}
    }
  }
  if ($pt eq 'location') {return "location == $scopePath";}

  my $periphTypeDescriptor = $PERIPH_TYPE_MAP{$pt};
  if (!$periphTypeDescriptor) {
    &Error("Unrecognized peripheral name \"$pt\"", "Change it to one of the following: " . join(' ', keys %PERIPH_TYPE_MAP));
    return '';
  }
  if ($periphTypeDescriptor eq 'introduction') {$periphTypeDescriptor = $PERIPH_SUBTYPE_MAP{$pt};}

  my $xpath = 'osis:div[@type="book"]/node()[1]'; # default is introduction to first book
  foreach my $t (keys %USFM_DEFAULT_PERIPH_TARGET) {
    if ($pt !~ /^($t)$/i) {next;}
    $xpath = $USFM_DEFAULT_PERIPH_TARGET{$t};
    if ($xpath eq 'place-according-to-scope') {$xpath = $scopePath;}
    last;
  }
  
  return "\"$pt\" == $xpath";
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
  
  &Report("Copied \"$copied\" font file(s) to \"$outdir\".\n");
}


# Copy all images found in the OSIS or TEI file from projdir to outdir. 
# If any images are found, 1 is returned, otherwise 0;
sub copyReferencedImages($$$) {
  my $osis_or_tei = shift;
  my $projdir = shift;
  my $outdir = shift;
  
  &Log("\n--- COPYING images in \"$osis_or_tei\"\n");
  
  $projdir =~ s/\/\s*$//;
  $outdir =~ s/\/\s*$//;
  
  my %copied;
  
  my $xml = $XML_PARSER->parse_file($osis_or_tei);
  my @images = $XPC->findnodes('//*[local-name()="figure"]', $xml);
  foreach my $image (@images) {
    my $src = $image->getAttribute('src');
    if ($src !~ s/^\.\///) {
      &Error("copyReferencedImages found a nonrelative path \"$src\".", "Image src paths specified by SFM \\fig tags need be relative paths (so they should begin with '.').");
      next;
    }
    
    my $localsrc = &getFigureLocalPath($image, $projdir);
    if (! -e $localsrc) {
      &Error("copyReferencedImages: Image \"$src\" not found at \"$localsrc\"", "Add the image to this image path.");
      next;
    }
    
    my $ofile = "$outdir/$src";
    my $odir = $ofile; $odir =~ s/\/[^\/]*$//;
    if (!-e $odir) {`mkdir -p "$odir"`;}
    if (-e $ofile && !$copied{"$localsrc:$ofile"}) {
      &Warn("Image already exists at destination and will not be overwritten: $ofile", "If $localsrc is different than $ofile then you must change the name of one of the images.");
    }
    if ($copied{"$localsrc:$ofile"}) {next;}
    
    &copy($localsrc, $ofile);
    $copied{"$localsrc:$ofile"}++;
    &Note("Copied image \"$ofile\"");
  }
  
  &Report("Copied \"".scalar(keys(%copied))."\" images to \"$outdir\".");
  return scalar(keys(%copied));
}

# Reads an OSIS file and looks for or creates cover images for the full
# OSIS file as well as any sub-publications within it. All referenced
# images will be located in $MAININPD/images
sub addCoverImages($) {
  my $osisP = shift;

  my $coverWidth = 500;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1addCoverImages$3/;
  my $xml = $XML_PARSER->parse_file($$osisP);
  my $mod = &getModNameOSIS($xml);
  my $updated;
  
  if (@{$XPC->findnodes('//osis:figure[@type="x-cover"]', $xml)}[0]) {
    &Note("OSIS file already has x-cover image(s): $$osisP. Skipping addCoverImages()");
    return;
  }
  
  &Log("\n--- INSERTING COVER IMAGES INTO \"$$osisP\"\n", 1);
  
  
  my $imgdir = "$MAININPD/images"; if (! -e $imgdir) {mkdir($imgdir);}
  
  # Find any sub-publication cover image(s) and insert them into the OSIS file
  my %done;
  my @pubcovers = ();
  foreach my $osisRef (map($_->getAttribute('osisRef'), $XPC->findnodes('//osis:div[@type][@osisRef]', $xml))) {
    if ($done{$osisRef}) {next;} else {$done{$osisRef}++;}
    my $scope = $osisRef; $scope =~ s/\s+/_/g;
    my $pubImagePath = &getCoverImageFromScope($mod, $scope);
    if (!$pubImagePath) {next;}
    push (@pubcovers, $pubImagePath);
    my $imgpath = "$imgdir/$scope.jpg";
    if ($pubImagePath ne $imgpath) {&shell("convert -colorspace sRGB -type truecolor -resize ${coverWidth}x \"$pubImagePath\" \"$imgpath\"", 3);}
    &Note("Found sub-publication cover image: $imgpath");
    if (&insertSubpubCover($scope, &getCoverFigure($scope, 'sub'), $xml)) {$updated++;}
    else {&Warn("<-Failed to find introduction with scope $osisRef to insert the cover image.",
"If you want the cover image to appear in the OSIS file, there 
needs to be a USFM \\id or \\periph tag that contains scope==$osisRef
on the same line");}
  }
  
  # Find or create a main publication cover and insert it into the OSIS file
  my $scope = (&isChildrensBible($xml) ? 'Chbl':@{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:scope", $xml)}[0]->textContent);
  $scope =~ s/\s+/_/g;
  my $subType = 'full';
  my $pubImagePath = &getCoverImageFromScope($mod, $scope);
  if (!$pubImagePath && -e "$INPD/images/cover.jpg") {$pubImagePath = "$INPD/images/cover.jpg";}
  elsif (!$pubImagePath && -e "$INPD/eBook/cover.jpg") {$pubImagePath = "$INPD/eBook/cover.jpg"; &Error("This cover location is deprecated: $pubImagePath.", "Move this image to $INPD/images");}
  elsif (!$pubImagePath && -e "$INPD/html/cover.jpg") {$pubImagePath = "$INPD/html/cover.jpg"; &Error("This cover location is deprecated: $pubImagePath.", "Move this image to $INPD/images");}
  my $imgpath = "$imgdir/$scope.jpg";
  if ($pubImagePath eq $imgpath) {
    &Note("Found full publication cover image: $imgpath");
  }
  elsif ($pubImagePath) {
    &shell("convert -colorspace sRGB -type truecolor -resize ${coverWidth}x \"$pubImagePath\" \"$imgpath\"", 3);
    &Note("Copying full publication cover image from $pubImagePath to: $imgpath");
  }
  elsif (@pubcovers) {
    my $title = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:title", $xml)}[0]->textContent;
    my $font = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:description[\@type='x-config-Font']", $xml)}[0];
    $font = ($font ? $font->textContent:'');
    if (&createCompositeCoverImage($imgpath, $mod, $scope, \@pubcovers, $title, $font)) {
      $pubImagePath = $imgpath;
      $subType = 'comp';
      &Note("Created full publication cover image from ".@pubcovers." sub-publication images with title $title: $imgpath");
    }
  }
  if ($pubImagePath && &insertPubCover(&getCoverFigure($scope, $subType), $xml)) {$updated++;}
  
  if ($updated) {&writeXMLFile($xml, $output, $osisP);}
}

# Returns the full path of a cover image for this module and scope, if
# one can be found. The following searches are done to look for a cover 
# image (the first found is used):
# 1) $INDP/images/<scoped-name>
# 2) $COVERS location (if any) looking for <scoped-name>
sub getCoverImageFromScope($$) {
  my $mod = shift;
  my $scope = shift;
  
  $scope =~ s/\s+/_/g;
  
  my $cover = &findCover("$INPD/images", $mod, $scope);
  if (!$cover && $COVERS) {
    if ($COVERS =~ /^https?\:/) {
      my $p = &expandLinuxPath("~/.osis-converters/cover");
      if (!-e $p) {mkdir($p);}
      shell("cd '$p' && wget -r --quiet --level=1 -erobots=off -nd -np -N -A '*.*' -R '*.html*' '$COVERS'", 3);
      &wgetSyncDel($p);
      $COVERS = $p;
    }
    $cover = &findCover($COVERS, $mod, $scope);
  }
  
  return $cover;
}

# Look for a cover image in $dir matching $mod and $scope and return it 
# if found. The image file name may or may not be prepended with $mod_, 
# and may use either space or underscore as scope delimiter.
sub findCover($$$) {
  my $dir = shift;
  my $mod = shift;
  my $scope = shift;
  
  $scope =~ s/\s+/_/g;
  
  if (opendir(EBD, $dir)) {
    my @fs = readdir(EBD);
    closedir(EBD);
    foreach my $f (@fs) {
      my $fscope = $f;
      my $m = $mod.'_';
      if ($fscope !~ s/^($m)?(.*?)\.jpg$/$2/i) {next;}
      if ($scope eq $fscope) {return "$dir/$f";}
    }
  }
  
  return '';
}

sub createCompositeCoverImage($$$\@$) {
  my $cover = shift;
  my $mod = shift;
  my $scope = shift;
  my $coversAP = shift;
  my $title = shift;
  my $font = shift;
  
  my $imgw = 500; my $imgh = 0;
  my $xs = (20 + 40*(5-@{$coversAP})); my $ys = $xs;
  my $xw = $imgw - ((@{$coversAP}-1)*$xs);
  for (my $j=0; $j<@{$coversAP}; $j++) {
    my $dimP = &imageDimension(@{$coversAP}[$j]);
    $sh = int($dimP->{'h'} * ($xw/$dimP->{'w'}));
    if ($imgh < $sh + ($ys*$j)) {$imgh = $sh + ($ys*$j);}
  }
  my $dissolve = "%100"; # in the end dissolve wasn't that great, so disable for now
  my $temp = "$TMPDIR/tmp.png";
  my $out = "$TMPDIR/cover.png"; # png allows dissolve to work right
  for (my $j=0; $j<@{$coversAP}; $j++) {
    my $dimP = &imageDimension(@{$coversAP}[$j]);
    $sh = int($dimP->{'h'} * ($xw/$dimP->{'w'}));
    &shell("convert -resize ${xw}x${sh} ".@{$coversAP}[$j]." \"$temp\"", 3);
    if ($j == 0) {
      &shell("convert -size ${imgw}x${imgh} xc:None \"$temp\" -geometry +".($j*$xs)."+".($j*$ys)." -composite \"$out\"", 3);
    }
    else {
      &shell("composite".($j != (@{$coversAP}-1) ? " -dissolve ".$dissolve:'')." \"$temp\" -geometry +".($j*$xs)."+".($j*$ys)." \"$out\" \"$out\"", 3);
    }
  }
  &shell("convert \"$out\" -colorspace sRGB -background White -flatten ".&imageCaption($imgw, $title, $font)." \"$cover\"", 3);
  if (-e $temp) {unlink($temp);}
  if (-e $out) {unlink($out);}
  
  return (-e $cover ? 1:0);
}

sub imageDimension($) {
  my $image = shift;
  
  my %dim;
  my $r = &shell("identify \"$image\"", 3);
  $dim{'w'} = $r; $dim{'w'} =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $dim{'w'} = (1*$dim{'w'});
  $dim{'h'} = $r; $dim{'h'} =~ s/^.*?\bJPEG \d+x(\d+)\b.*$/$1/; $dim{'h'} = (1*$dim{'h'});
  
  return \%dim;
}

sub imageCaption($$$$) {
  my $width = shift;
  my $title = shift;
  my $font = shift;
  my $background = shift; if ($background) {$background =  " -background $background";}
  
  my $pointsize = (4/3)*$width/length($title);
  if ($pointsize > 40) {$pointsize = 40;}
  elsif ($pointsize < 10) {$pointsize = 10;}
  my $padding = 20;
  my $barheight = $pointsize + (2*$padding);
  my $foundfont = '';
  if ($font) {
    foreach my $f (keys %{$FONT_FILES{$font}}) {
      if ($FONT_FILES{$font}{$f}{'style'} eq 'regular') {
        $foundfont = $FONT_FILES{$font}{$f}{'fullname'};
        $foundfont =~ s/ /-/g;
        last;
      }
    }
  }
  return "-gravity North$background -splice 0x$barheight -pointsize $pointsize ".($foundfont ? "-font $foundfont ":'')."-annotate +0+$padding '$title'";
}

sub insertSubpubCover($$$) {
  my $scope = shift;
  my $figure = shift;
  my $xml = shift;

  $scope =~ s/_/ /g;
  my $insertAfter = @{$XPC->findnodes('//osis:div[@type][@osisRef="'.$scope.'"][1]/osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $xml)}[0];
  if ($insertAfter) {
    $insertAfter->parentNode->insertAfter($figure, $insertAfter);
    &Note("Inserted sub-publication cover image after milestone: $scope");
    return 1;
  }

  my $insertFirstChild = @{$XPC->findnodes('//osis:div[@type][@osisRef="'.$scope.'"][1]', $xml)}[0];
  if ($insertFirstChild) {
    $insertFirstChild->insertBefore($figure, $insertFirstChild->firstChild);
    &Note("Inserted sub-publication cover image as first child of: $scope");
    return 1;
  }

  return 0;
}

# The cover figure must be within a div to pass validation. Place it as
# the first child of the first div if it is not book(Group). Otherwise
# also create a new div of type x-cover.
sub insertPubCover($$) {
  my $figure = shift;
  my $xml = shift;

  my $div = (
    &isChildrensBible($xml) ? 
    @{$XPC->findnodes('//osis:div[1]', $xml)}[0] :
    @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[1][local-name()="div"][not(contains(@type, "book"))]', $xml)}[0]
  );
  if ($div) {
    $div->insertBefore($figure, $div->firstChild);
    &Note("Inserted publication cover image as first child of existing div type=".($div->hasAttribute('type') ? $div->getAttribute('type'):'NO-TYPE'));
  }
  else {
    my $div = $XML_PARSER->parse_balanced_chunk("<div type='x-cover' resp='$ROC'>".$figure->toString()."</div>");
    my $header = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header', $xml)}[0];
    $header->parentNode->insertAfter($div, $header);
    &Note("Inserted publication x-cover div after header.");
  }
}

sub getCoverFigure($$) {
  my $scopename = shift;
  my $type = shift;
  
  return $XML_PARSER->parse_balanced_chunk("<figure type='x-cover' subType='x-$type-publication' src='./images/$scopename.jpg' resp='$ROC'> </figure>");
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
  
  if (!open(SFM, "<:encoding(UTF-8)", $f)) {&ErrorBug("scanUSFM_file could not read \"$f\"", '', 1);}
  
  $info{'scope'} = ($f =~ /\/sfm\/([^\/]+)\/[^\/]+$/ ? $1:'');
  if ($info{'scope'}) {$info{'scope'} =~ s/_/ /g;}
  
  my $id;
  # Only the first of each of the following tag roots (by root meaning 
  # the tag followed by any digit) within an SFM file, will be 
  # recorded.
  my @tags = ('h', 'imt', 'is', 'mt', 'toc1', 'toc2', 'toc3');
  while(<SFM>) {
    if ($_ =~ /^\W*?\\id \s*(.*?)\s*$/) {
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
    elsif ($id =~ /^(FRT|INT|OTH)/i) {
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
  if ($flag == 2 && !$sep) {&ErrorBug("Param '$param' cannot have multiple values, yet setConfValue flag=$flag", '', 1);}
  
  if (!$flag) {return 0;}
  elsif ($flag == 1) {
    $confEntriesP->{$param} = $value;
  }
  elsif ($flag == 2) {
    if ($confEntriesP->{$param}) {$confEntriesP->{$param} .= $sep.$value;}
    else {$confEntriesP->{$param} = $value;}
  }
  else {&ErrorBug("Unexpected setConfValue flag='$flag'", '', 1);}
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
  my $project_dir = shift;
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
  
  open(CONF, ">:encoding(UTF-8)", $conf) || die "Could not open conf $conf\n";
  my $section = '';
  foreach my $elit (sort { &confEntrySort($a, $b); } keys %{$entryValueP} ) {
    my $e = $elit; my $s = ($e =~ s/^(.*?)\+// ? $1:'');
    if ($s eq $MAINMOD) {$s = '';}
    if ($elit eq 'ModuleName') {
      print CONF "[".$entryValueP->{$elit}."]\n";
      next;
    }
    if ($s ne $section) {print CONF "\n[".$s."]\n"; $section = $s;}
    foreach my $val (split(/<nx\/>/, $entryValueP->{$elit})) {
      if ($used{$elit.$val}) {next;}
      print CONF $e."=".$val."\n";
      $used{$elit.$val}++;
    }
  }
  close(CONF);
  
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
      &Warn("Config entry $elit will not be written to SWORD conf.", "This is normal unless the entry should be included in SWORD config.conf.");
      next;
    }
    $swordConf{$e} = &conf($elit, $entryValueP);
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
  foreach my $entry (keys %{$CONF}) {
    my $isConf = &isValidConfig($entry);
    if (!$isConf) {
      &ErrorBug("Unrecognized config entry: $entry");
    }
    elsif ($isConf eq 'sword-autogen') {
      &Error("Config request '$entry' is valid but it should not be set in config.conf because it is auto-generated by osis-converters.", "Remove this entry from the config.conf file.");
    }
  }
  
  if ($INPD ne $DICTINPD) {
    # Check for UI that needs localization
    foreach my $k (keys %CONFIG_DEFAULTS) {
      if (!$DICTMOD && $k eq 'CombinedGlossaryTitle') {next;}
      if ($k =~ /[\:\+]/ || $CONFIG_DEFAULTS{$k} !~ / DEF$/ || $CONF->{$k} ne $CONFIG_DEFAULTS{$k}) {next;}
      &Warn("Title config entry '$k' is not localized: ".$CONFIG_DEFAULTS{$k}, "If you see English in the eBook table of contents for instance, you should localize the title in config.conf with: $k=Localized Title");
    }
    my $n=0;
    while (exists($CONF->{'TitleSubPublication'.++$n})) {
      if ($CONF->{'TitleSubPublication'.$n} && $CONF->{'TitleSubPublication'.$n} !~ / DEF$/) {next;}
      &Warn("Sub publication title config entry 'TitleSubPublication$n' is not localized: ".$CONF->{'TitleSubPublication'.$n}, "If you see English in the eBook table of contents for instance, you should localize the title in config.conf with: TitleSubPublication$n=Localized Title");
    }
  }
}


sub checkRequiredConfEntries($) {
  if (&conf('Abbreviation') eq $MOD) {
    &Warn("Currently the config.conf 'Abbreviation' setting is '$MOD'.",
"This is normally a short user-readable abbreviation for the module, but the module name itself may be acceptable sometimes too.");
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
  if (open(RCMF, "<:encoding(UTF-8)", $f)) {
    if (!open(OCMF, ">:encoding(UTF-8)", "$f.tmp")) {&ErrorBug("removeRevisionFromCF could not open \"$f.tmp\".", '', 1);}
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

  # Apparently \p{L} and \p{N} work different in different regex implementations.
  # So some schema checkers don't validate high order Unicode letters.
  $r =~ s/(.)/my $x = (ord($1) > 1103 ? "_".ord($1)."_":$1)/eg;
  
  $r =~ s/([^\p{L}\p{N}_])/my $x="_".ord($1)."_"/eg;
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
    foreach my $bk (keys %{$CANON_CACHE{$vsys}{'bookOrder'}}) {
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


# Copy inosis to outosis, while pruning books and other bookGroup child 
# elements according to scope. Any changes made during the process are 
# noted in the log file with a note.
#
# If any bookGroup is left with no books in it, then the entire bookGroup 
# element (including its introduction if there is one) is dropped.
#
# If any book (kept or pruned) contains peripheral(s) which pertain to 
# any kept book, the peripheral(s) are kept. If peripheral(s) pertaining 
# to more than one book are within a book, they will be moved up out of 
# the book they're in and inserted before the first applicable kept 
# book, so as to retain the peripheral.
#
# If there is only one bookGroup left, the remaining one's TOC milestone
# will become [not_parent] to so as to prevent an unnecessary TOC level,
# or, if the Testament intro is empty, it will be entirely removed.
#
# If a sub-publication cover matches the scope, it will be moved to 
# replace the main cover. Or when pruning to a single book that matches
# a sub-publication cover, it will be moved to relace the main cover.
#
# If the ebookTitleP is non-empty, its value will always be used as the  
# final ebook title. Otherwise the ebook title will be taken from config 
# Title if present, or else the OSIS file, but appended to it will be the 
# list of books remaining after filtering IF any were filtered out. The 
# final ebook title will then be written to the outosis file and returned 
# in ebookTitleP.
#
# The ebookPartTitleP is overwritten by the list of books left after
# filtering, or else the ebook title itself if no books were filtered out.
#
# Reference hyperlinks with subType="x-external" are removed because
# these targets do not exist in the translation yet and will result in
# broken links.
sub pruneFileOSIS($$\%\$\$) {
  my $osisP = shift;
  my $scope = shift;
  my $confP = shift;
  my $ebookTitleP = shift;
  my $ebookPartTitleP= shift;
  
  my $tocNum = &conf('TOC');
  my $bookTitleTocNum = &conf('TitleTOC');
  
  my $typeRE = '^('.join('|', keys(%PERIPH_TYPE_MAP_R), keys(%ID_TYPE_MAP_R)).')$';
  $typeRE =~ s/\-/\\-/g;
  
  my $inxml = $XML_PARSER->parse_file($$osisP);
  my $fullScope = &getScopeOSIS($inxml);
  
  my $bookOrderP;
  my $booksFiltered = 0;
  if (!&getCanon($confP->{'Versification'}, '', \$bookOrderP, '')) {
    &ErrorBug("pruneFileOSOS getCanon(".$confP->{'Versification'}.") failed, not pruning books in OSIS file");
    return;
  }
  
  my @scopedPeriphs = $XPC->findnodes('//osis:div[@osisRef][parent::osis:div[starts-with(@type, "book")]]', $inxml);
  
  # remove books not in scope
  my %scopeBookNames = map { $_ => 1 } @{&scopeToBooks($scope, $bookOrderP)};
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
  my @filteredBooks;
  foreach my $bk (@books) {
    my $id = $bk->getAttribute('osisID');
    if (!exists($scopeBookNames{$id})) {
      $bk->unbindNode();
      push(@filteredBooks, $id);
      $booksFiltered++;
    }
  }
  
  if ($booksFiltered) {
    &Note("Filtered \"".scalar(@filteredBooks)."\" books that were outside of scope \"$scope\".", 1);
    
    foreach my $d (@scopedPeriphs) {$d->unbindNode();}

    # remove bookGroup if it has no books left (even if it contains other peripheral material)
    my @emptyBookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"][not(osis:div[@type="book"])]', $inxml);
    my $msg = 0;
    foreach my $ebg (@emptyBookGroups) {$ebg->unbindNode(); $msg++;}
    if ($msg) {
      &Note("Filtered \"$msg\" bookGroups which contained no books.", 1);
    }
    
    # if there's only one bookGroup now, change its TOC entry to [not_parent] or remove it, to prevent unnecessary TOC levels and entries
    my @grps = $XPC->findnodes('//osis:div[@type="bookGroup"]', $inxml);
    if (scalar(@grps) == 1 && @grps[0]) {
      my $ms = @{$XPC->findnodes('child::osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1] | child::*[1][not(self::osis:div[@type="book"])]/osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1]', @grps[0])}[0];
      if ($ms) {
        my $resp = @{$XPC->findnodes('ancestor-or-self::*[@resp="'.$ROC.'"][last()]', $ms)}[0];
        my $firstIntroPara = @{$XPC->findnodes('self::*[@n]/ancestor::osis:div[@type="bookGroup"]/descendant::osis:p[child::text()[normalize-space()]][1][not(ancestor::osis:div[@type="book"])]', $ms)}[0];
        my $fipMS = ($firstIntroPara ? @{$XPC->findnodes('preceding::osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1]', $firstIntroPara)}[0]:'');
        if (!$resp && $firstIntroPara && $fipMS->unique_key eq $ms->unique_key) {
          $ms->setAttribute('n', '[not_parent]'.$ms->getAttribute('n'));
          &Note("Changed TOC milestone from bookGroup to n=\"".$ms->getAttribute('n')."\" because there is only one bookGroup in the OSIS file.", 1);
        }
        # don't include in the TOC if there is no intro p or the first intro p is under different TOC entry
        elsif ($resp) {
          &Note("Removed auto-generated TOC milestone from bookGroup because there is only one bookGroup in the OSIS file:\n".$resp->toString."\n", 1);
          $resp->unbindNode();
        }
        else {
          &Note("Removed TOC milestone from bookGroup with n=\"".$ms->getAttribute('n')."\" because there is only one bookGroup in the OSIS file and the entry contains no paragraphs.", 1);
          $ms->unbindNode();
        }
      }
    }
    
    # move multi-book book intros before first kept book.
    my @remainingBooks = $XPC->findnodes('/osis:osis/osis:osisText//osis:div[@type="book"]', $inxml);
    INTRO: foreach my $intro (@scopedPeriphs) {
      my $introBooks = &scopeToBooks($intro->getAttribute('osisRef'), $bookOrderP);
      if (!@{$introBooks}) {next;}
      foreach $introbk (@{$introBooks}) {
        foreach my $remainingBook (@remainingBooks) {
          if ($remainingBook->getAttribute('osisID') ne $introbk) {next;}
          $remainingBook->parentNode()->insertBefore($intro, $remainingBook);
          my $t1 = $intro; $t1 =~ s/>.*$/>/s;
          my $t2 = $remainingBook; $t2 =~ s/>.*$/>/s;
          &Note("Moved peripheral: $t1 before $t2", 1);
          next INTRO;
        }
      }
      my $t1 = $intro; $t1 =~ s/>.*$/>/s;
      &Note("Removed peripheral: $t1", 1);
    }
  }
  
  # determine titles
  my $osisTitle = @{$XPC->findnodes('/descendant::osis:type[@type="x-bible"][1]/ancestor::osis:work[1]/descendant::osis:title[1]', $inxml)}[0];
  my $title = ($$ebookTitleP ? $$ebookTitleP:$osisTitle->textContent);
  if ($booksFiltered) {
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
    my @bookNames;
    foreach my $b (@books) {
      my @t = $XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.$bookTitleTocNum.'"]/@n', $b);
      if (@t[0]) {push(@bookNames, @t[0]->getValue());}
    }
    $$ebookPartTitleP = join(', ', @bookNames);
  }
  else {$$ebookPartTitleP = $title;}
  if ($booksFiltered && !$$ebookTitleP) {$$ebookTitleP = "$title: $$ebookPartTitleP";}
  else {$$ebookTitleP = $title;}
  if ($$ebookTitleP ne $osisTitle->textContent) {
    &changeNodeText($osisTitle, $$ebookTitleP);
    &Note('Updated OSIS title to "'.$osisTitle->textContent."\"", 1);
  }
  
  # remove references beyond OSIS file
  my @rhot = $XPC->findnodes('//osis:reference[@subType="x-external"]', $inxml);
  foreach my $r (@rhot) {
    foreach my $chld ($r->childNodes) {$r->parentNode()->insertBefore($chld, $r);}
    $r->unbindNode();
  }
  if (@rhot[0]) {&Note("Removed ".@rhot." hyperlinks outside of translation.", 1);}
  
  # move matching sub-publication cover to top
  my $s = $scope; $s =~ s/\s+/_/g;
  my $subPubCover = @{$XPC->findnodes("//osis:figure[\@subType='x-sub-publication'][contains(\@src, '/$s.')]", $inxml)}[0];
  if (!$subPubCover && $scope && $scope !~ /[_\s\-]/) {
    foreach $figure ($XPC->findnodes("//osis:figure[\@subType='x-sub-publication'][\@src]", $inxml)) {
      my $sc = $figure->getAttribute('src'); $sc =~ s/^.*\/([^\.]+)\.[^\.]+$/$1/; $sc =~ s/_/ /g;
      my $bkP = &scopeToBooks($sc, $bookOrderP);
      foreach my $bk (@{$bkP}) {if ($bk eq $scope) {$subPubCover = $figure;}}
    }
  }
  if ($subPubCover) {
    $subPubCover->unbindNode();
    $subPubCover->setAttribute('subType', 'x-full-publication');
    my $cover = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[1][local-name()="div"]/osis:figure[@type="x-cover"]', $inxml)}[0];
    if ($cover) {
      &Note("Replacing original cover image with sub-publication cover: ".$subPubCover->getAttribute('src'), 1);
      $cover->parentNode->insertAfter($subPubCover, $cover);
      $cover->unbindNode();
    }
    else {
      &Note("Moving sub-publication cover ".$subPubCover->getAttribute('src')." to publication cover position.", 1);
      &insertPubCover($subPubCover, $inxml);
    }
  }
  if ($scope && $scope ne $fullScope && !$subPubCover) {&Warn("A Sub-Publication cover was not found for $scope.", 
"If a custom cover image is desired for $scope then add a file 
./images/$s.jpg with the image. ".($scope !~ /[_\s\-]/ ? 'Alternatively you may add 
an image whose filename is any scope that contains $scope':''));}
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1pruneFileOSIS$3/;
  &writeXMLFile($inxml, $output, $osisP);
}

sub changeNodeText($$) {
  my $node = shift;
  my $new = shift;
  foreach my $r ($node->childNodes()) {$r->unbindNode();}
  if ($new) {$node->appendText($new)};
}

# Filter all Scripture reference links in a Bible/Dict osis file: A Dict osis file
# must have a Bible companionOsis associated with it, to be the target of its  
# Scripture references. Scripture reference links whose target book isn't in
# itself or a companion, and those missing osisRefs, will be fixed. There are 
# three ways these broken references are handled:
# 1) Delete the reference: It must be entirely deleted if it is not human readable.
#    Cross-reference notes are not readable if they appear as just a number 
#    (because an abbreviation for the book was not available in the translation).
# 2) Redirect: Partial eBooks can redirect to a full eBook if the link is readable,
#    FullResourceURL is provided in config.conf, and the fullOsis resource contains 
#    the target.
# 3) Remove hyper-link: This happens if the link is readable, but it could not be
#    redirected to another resource, or it's missing an osisRef.
sub filterScriptureReferences($$$) {
  my $osis = shift;
  my $fullOsis = shift;
  my $companionBibleOsis = shift;
  
  my $selfOsis = ($companionBibleOsis ? $companionBibleOsis:$osis);
  
  my $xml_osis     = $XML_PARSER->parse_file($osis);
  my $xml_selfOsis = $XML_PARSER->parse_file($selfOsis);
  my $xml_fullOsis = $XML_PARSER->parse_file($fullOsis);
  
  my %selfOsisBooks = map {$_->value, 1} @{$XPC->findnodes('//osis:div[@type="book"]/@osisID', $xml_selfOsis)};
  my %fullOsisBooks = map {$_->value, 1} @{$XPC->findnodes('//osis:div[@type="book"]/@osisID', $xml_fullOsis)};
  
  my $iAmFullOsis = (join(' ', sort keys %selfOsisBooks) eq join(' ', sort keys %fullOsisBooks));
  my $fullResourceURL = @{$XPC->findnodes('/descendant::*[contains(@type, "FullResourceURL")][1]/@type', $xml_selfOsis)}[0];
  if ($fullResourceURL) {$fullResourceURL = $fullResourceURL->value;}
  my $mayRedirect = ($fullResourceURL && !$iAmFullOsis);
  
  &Log("\n--- FILTERING Scripture references in \"$osis\"\n", 1);
  &Log("Deleting unreadable cross-reference notes and removing hyper-links for references which target outside ".($iAmFullOsis ? 'the translation':"\"$selfOsis\""));
  if ($mayRedirect) {
    &Log(", unless they may be redirected to \"$fullResourceURL\"");
  }
  elsif (!$iAmFullOsis) {
    &Log(".\nWARNING: You could redirect some cross-reference notes, rather than removing them, by specifying FullResourceURL in config.conf");
  }
  &Log(".\n");

  # xref = cross-references, sref = scripture-references, nref = no-osisRef-references
  my %delete    = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %deleteBks   = {'xref'=>{},'sref'=>{},'nref'=>{}};
  my %redirect  = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %redirectBks = {'xref'=>{},'sref'=>{},'nref'=>{}};
  my %remove    = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %removeBks   = {'xref'=>{},'sref'=>{},'nref'=>{}};
  
  my @links = $XPC->findnodes('//osis:reference[not(@type="x-glosslink" or @type="x-glossary")]', $xml_osis);
  foreach my $link (@links) {
    if (!$link->getAttribute('osisRef') || $link->getAttribute('osisRef') =~ /^(([^\:]+?):)?([^\.]+)(\.|$)/) {
      my $bk = ($link->getAttribute('osisRef') ? $3:'');
      if ($link->getAttribute('osisRef') && exists($selfOsisBooks{$bk})) {next;}
      my $refType = ($link->getAttribute('osisRef') ? (@{$XPC->findnodes('ancestor::osis:note[@type="crossReference"][1]', $link)}[0] ? 'xref':'sref'):'nref');
      
      # Handle broken link
      if ($refType eq 'xref' && $link->textContent() =~ /^[\s,\d]*$/) {
        # delete unreadable cross-references
        $link->unbindNode();
        $delete{$refType}++; if ($bk) {$deleteBks{$refType}{$bk}++;}
      }
      elsif ($refType ne 'nref' && $mayRedirect && exists($fullOsisBooks{$bk})) {
        # redirect by tagging as x-other-resource
        $link->setAttribute('subType', 'x-other-resource');
        $redirect{$refType}++; if ($bk) {$redirectBks{$refType}{$bk}++;}
      }
      else {
        #remove
        my @children = $link->childNodes();
        foreach my $child (@children) {$link->parentNode()->insertBefore($child, $link);}
        $link->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk(' '), $link);
        $link->unbindNode();
        $remove{$refType}++; if ($bk) {$removeBks{$refType}{$bk}++;}
      }
    }
    else {&Error("filterScriptureReferences: Unhandled osisRef=\"".$link->getAttribute('osisRef')."\"");}
  }
  
  # remove any cross-references with nothing left in them
  my $deletedXRs = 0;
  if ($delete{'xref'}) {
    my @links = $XPC->findnodes('//osis:note[@type="crossReference"][not(descendant::osis:reference[@type != "annotateRef" or not(@type)])]', $xml_osis);
    foreach my $link (@links) {$link->unbindNode(); $deletedXRs++;}
  }
  
  &writeXMLFile($xml_osis, $osis);
  
  foreach my $stat ('redirect', 'remove', 'delete') {
    foreach my $type ('sref', 'xref', 'nref') {
      my $t = ($type eq 'xref' ? 'cross     ':($type eq 'sref' ? 'Scripture ':'no-osisRef'));
      my $s = ($stat eq 'redirect' ? 'Redirected':($stat eq 'remove' ? 'Removed   ':'Deleted   '));
      my $tc; my $bc;
      if ($stat eq 'redirect') {$tc = $redirect{$type}; $bc = scalar(keys(%{$redirectBks{$type}}));}
      if ($stat eq 'remove')   {$tc = $remove{$type};   $bc = scalar(keys(%{$removeBks{$type}}));}
      if ($stat eq 'delete')   {$tc = $delete{$type};   $bc = scalar(keys(%{$deleteBks{$type}}));}
      &Report(sprintf("$s %5i $t references - targeting %2i different book(s)", $tc, $bc));
    }
  }
  &Report("\"$deletedXRs\" Resulting empty cross-reference notes were deleted.");
  
  return ($delete{'sref'} + $redirect{'sref'} + $remove{'sref'});
}

# Filter out glossary reference links that are outside the scope of glossRefOsis
sub filterGlossaryReferences($$$) {
  my $osis = shift;
  my $glossRefOsis = shift;
  my $filterNavMenu = shift;
  
  my %refsInScope;
  my $glossMod = $glossRefOsis; $glossMod =~ s/^.*\///;
  if ($glossRefOsis) {
    my $glossRefXml = $XML_PARSER->parse_file($glossRefOsis);
    my $work = &getOsisIDWork($glossRefXml);
    my @osisIDs = $XPC->findnodes('//osis:seg[@type="keyword"]/@osisID', $glossRefXml);
    my %ids;
    foreach my $osisID (@osisIDs) {
      my $id = $osisID->getValue();
      $id =~ s/^(\Q$work\E)://;
      $ids{$id}++;
    }
    $refsInScope{$work} = \%ids;
  }
  
  &Log("\n--- FILTERING glossary references in \"$osis\"\n", 1);
  &Log("REMOVING glossary references".($glossMod ? " that target outside \"$glossMod\"":'')."\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # filter out x-navmenu lists if they aren't wanted
  if ($filterNavMenu) {
    my @navs = $XPC->findnodes('//osis:list[@subType="x-navmenu"]', $xml);
    foreach my $nav (@navs) {if ($nav) {$nav->unbindNode();}}
  }
  
  # filter out references outside our scope
  my @links = $XPC->findnodes('//osis:reference[@osisRef and (@type="x-glosslink" or @type="x-glossary")]', $xml);
  my %filteredOsisRefs;
  my $total = 0;
  foreach my $link (@links) {
    if ($link->getAttribute('osisRef') =~ /^(([^\:]+?):)?(.+)$/) {
      my $osisRef = $3;
      my $work = ($1 ? $2:&getOsisRefWork($xml));
      if (exists($refsInScope{$work}{$osisRef})) {next;}
      my @children = $link->childNodes();
      foreach my $child (@children) {$link->parentNode()->insertBefore($child, $link);}
      $link->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk(' '), $link);
      $link->unbindNode();
      $filteredOsisRefs{$osisRef}++;
      $total++;
    }
  }

  &writeXMLFile($xml, $osis);
  
  &Report("\"$total\" glossary references filtered:");
  foreach my $r (sort keys %filteredOsisRefs) {
    &Log(&decodeOsisRef($r)." (osisRef=\"".$r."\")\n");
  }
  return $total;
}


sub convertExplicitGlossaryElements(\@) {
  my $indexElementsP = shift;
  
  foreach my $index (@{$indexElementsP}) {
    my $level = $index->getAttribute("level1");
    my $cxstring = &getIndexContextString($index);
    my $before = $index->parentNode->toString();
    
    my $result;
    my @pt = $XPC->findnodes("preceding::text()[1]", $index);
    if (@pt != 1 || @pt[0]->data !~ /\Q$level\E$/) {
      &ErrorBug("Could not locate preceding text node for explicit glossary entry \"$index\".");
      &recordExplicitGlossFail($index, $level, $cxstring);
      next;
    }
    my $tn = @pt[0];
    
    # Check preceding text node
    if ($tn->data !~ /\Q$level\E$/) {
      &ErrorBug("Index tag $index in ".$index->parentNode->toString()." is not preceded by '$level'.");
      &recordExplicitGlossFail($index, $level, $cxstring);
      next;
    }
    
    # Find, write and record the matching reference
    my @tns; push(@tns, $tn);
    &addDictionaryLinks(\@tns, "$level$cxstring", (@{$XPC->findnodes('ancestor::osis:div[@type="glossary"]', $tn)}[0] ? 1:0));
    if ($before eq $index->parentNode->toString()) {
      &recordExplicitGlossFail($index, $level, $cxstring);
      next;
    }
    my $osisRef = @{$XPC->findnodes("preceding::reference[1]", $index)}[0]->getAttribute("osisRef");
    $ExplicitGlossary{$level}{&decodeOsisRef($osisRef)}++;
    
    # Remove index element if successful
    $index->parentNode->removeChild($index);
  }
}

sub recordExplicitGlossFail($$$) {
  my $index = shift;
  my $level = shift;
  my $cxstring = shift;
  
  my $str = $cxstring; $str =~ s/^(.*?)\:CXBEFORE\:(.*?)\:CXAFTER\:(.*)$/$2<index\/>$3/;

  $ExplicitGlossary{$level}{"Failed"}{'count'}++;
  $ExplicitGlossary{$level}{"Failed"}{'context'}{$str}++;
  
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
  my $eP = shift; # array of text-nodes or text-node parent elements (Note: node element child elements are not touched)
  my $ifExplicit = shift; # text context if the node was marked in the text as a glossary link
  my $isGlossary = shift; # true if the node is in a glossary (See-Also linking)
  
  my $bookOrderP;
  foreach my $node (@$eP) {
    my $glossaryContext;
    my $glossaryScopeP;
    
    if ($isGlossary) {
      if (!$bookOrderP) {
        &getCanon(&getVerseSystemOSIS($node), NULL, \$bookOrderP, NULL)
      }
      $glossaryContext = &decodeOsisRef(&glossaryContext($node));
      if (!$glossaryContext) {next;}
      my @gs = ( &getEntryScope($node) );
      $glossaryScopeP = (@gs[0] =~ /[\-\s]/ ? &scopeToBooks(@gs[0], $bookOrderP):\@gs);
      if (!$NoOutboundLinks{'haveBeenRead'}) {
        foreach my $n ($XPC->findnodes('descendant-or-self::dw:entry[@noOutboundLinks=\'true\']', $DWF)) {
          foreach my $r (split(/\s/, $n->getAttribute('osisRef'))) {$NoOutboundLinks{$r}++;}
        }
        $NoOutboundLinks{'haveBeenRead'}++;
      }
      if ($NoOutboundLinks{&entry2osisRef($MOD, $glossaryContext)}) {return;}
    }
  
    my @textchildren;
    my $container = ($node->nodeType == XML::LibXML::XML_TEXT_NODE ? $node->parentNode():$node);
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
          if ($matchedPattern = &addDictionaryLink(\$part, $textchild, $ifExplicit, $glossaryContext, $glossaryScopeP)) {
            if (!$ifExplicit) {$done = 0;}
          }
        }
        $text = join('', @parts);
      } while(!$done);
      $text =~ s/<reference [^>]*osisRef="REMOVE_LATER"[^>]*>(.*?)<\/reference>/$1/g;
      
      # sanity check
      my $check = $text;
      $check =~ s/<[^>]*>//g;
      if ($check ne $textchild->data()) {
        &ErrorBug("addDictionaryLinks: Bible text changed during glossary linking!\nBEFORE=".$textchild->data()."\nAFTER =$check", '', 1);
      }
      
      $text =~ s/(^|\s)&(\s|$)/&amp;/g;
      $textchild->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($text), $textchild);
      $textchild->unbindNode();
    }
  }
}

# Some of the following routines take either nodes or module names as inputs.
# Note: Whereas //osis:osisText[1] is TRULY, UNBELIEVABLY SLOW, /osis:osis/osis:osisText[1] is fast
sub getModNameOSIS($) {
  my $node = shift; # might already be string mod name- in that case just return it
  if (!ref($node)) {return $node;}
  
  # Generate doc data if the root document has not been seen before or was modified
  my $headerDoc = $node->ownerDocument->URI;

  my $mtime = ''; #'mtime'.(stat($headerDoc))[9]; # mtime is only SECOND resolution which is worse than useless
  if (!$DOCUMENT_CACHE{$headerDoc.$mtime}) {
    # When splitOSIS() is used, the document containing the header may be different than the current node's document.
    my $testDoc = $headerDoc;
    if ($testDoc =~ s/[^\/]+$/other.osis/ && -e $testDoc) {$headerDoc = $testDoc;}
  }
  if (!$DOCUMENT_CACHE{$headerDoc.$mtime}) {&initDocumentCache($headerDoc, $mtime, $node);}
  
  if (!$DOCUMENT_CACHE{$headerDoc.$mtime}{'getModNameOSIS'}) {
    &ErrorBug("getModNameOSIS: No value for \"$headerDoc\"!", '', 1);
    return '';
  }
  return $DOCUMENT_CACHE{$headerDoc.$mtime}{'getModNameOSIS'};
}
sub osisCache($$) {
  my $func = shift;
  my $modname = shift;
  
  # First check the current document cache
  if ($DOCUMENT_CACHE{$modname}{$func}) {
    return $DOCUMENT_CACHE{$modname}{$func};
  }
  
  # So it's not in the cache and we don't have an OSIS document for 
  # $modname. Then read and cache the value from the current OSIS document.
  my $osis = ($SCRIPT_NAME =~ /^(osis2sword|osis2GoBible|osis2ebooks|osis2html)$/ ? $INOSIS:$OSIS);
  &Note("$func: $modname is not in DOCUMENT_CACHE. Reading value directly from $osis (which is slower).");
  if (! -e $osis) {
    &ErrorBug("$func: No current osis file to read.", '', 1);
    return '';
  }
  my $found = &getModNameOSIS($XML_PARSER->parse_file($osis));
  if (!$found) {
    &ErrorBug("$func: Could not find header for $modname in $osis.", '', 1);
    return '';
  }
  if (!$DOCUMENT_CACHE{$modname}{$func}) {
    &ErrorBug("$func: Failed in $osis.", '', 1);
  }
  
  return $DOCUMENT_CACHE{$modname}{$func};
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
sub isChildrensBible($) {
  my $mod = &getModNameOSIS(shift);
  my $return = &osisCache('isChildrensBible', $mod);
  if (!$return) {
    &ErrorBug("isChildrensBible: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}
sub getOsisRefWork($) {return &getModNameOSIS(shift);}
sub getOsisIDWork($)  {return &getModNameOSIS(shift);}
sub existsDictionaryWordID($$) {
  my $osisID = shift;
  my $osisIDWork = &getModNameOSIS(shift);
  return existsElementID($osisID, $osisIDWork, 1);
}
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
sub existsElementID($$$) {
  my $osisID = shift;
  my $osisIDWork = &getModNameOSIS(shift);
  my $useDictionaryWordsFile = shift;
  
  my $work = ($osisID =~ s/^([^\:]*\:)// ? $1:$osisIDWork);
  if (!$work) {&ErrorBug("existsElementID: No osisIDWork \"$osisID\""); return '';}
  my $search = ($useDictionaryWordsFile ? 'DWF':$work);
  
  if (!$DOCUMENT_CACHE{$search}{'xml'}) {
    my $file = &getProjectOsisFile($search);
    if (-e $file) {$DOCUMENT_CACHE{$search}{'xml'} = $XML_PARSER->parse_file($file);}
    else {&ErrorBug("existsElementID: No \"$search\" xml file to search for \"$osisID\""); return '';}
  }
  
  if (!$DOCUMENT_CACHE{$search}{$osisID}) {
    $DOCUMENT_CACHE{$search}{$osisID} = 'no';
    # xpath 1.0 does not have "matches" so we need to do some extra work
    my $xpath = ($search eq 'DWF' ? 
      "//*[name()='entry'][contains(\@osisRef, '$osisID')]/\@osisRef" :
      "//*[contains(\@osisID, '$osisID')]/\@osisID"
    );
    my @test = $XPC->findnodes($xpath, $DOCUMENT_CACHE{$search}{'xml'});
    my $found = 0;
    foreach my $t (@test) {
      if ($t->value =~ /(^|\s)(\Q$work:\E)?\Q$osisID\E(\s|$)/) {
        $DOCUMENT_CACHE{$search}{$osisID} = 'yes';
        $found++;
      }
    }
    if (!$found) {return '';}
    if ($found != 1 && $search ne 'DWF') {
      &Error("existsElementID: osisID \"$work:$osisID\" appears $found times in $search.", "All osisID values in $work must be unique values.");
    }
  }
  return ($DOCUMENT_CACHE{$search}{$osisID} eq 'yes');
}
sub getAltVersesOSIS($) {
  my $mod = &getModNameOSIS(shift);
  
  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    &ErrorBug("getAltVersesOSIS: No xml document node!");
    return '';
  }
  
  if (!$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}) {
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
    foreach my $fixed (keys (%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}})) {
      my $source = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}{$fixed};
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Fitted'}{$fixed} = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'source2Fitted'}{$source};
    }
    
    use Data::Dumper; &Debug("getAltVersesOSIS = ".Dumper(\%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}})."\n", 1);
  }
  
  return \%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}};
}
# Associated functions use this cached header data for a big speedup. 
# The cache is cleared and reloaded the first time a node is referenced 
# from an OSIS file URL.
sub initDocumentCache($$$) {
  my $headerDoc = shift;
  my $mtime = shift;
  my $node = shift;
  
  if (-e "$INPD/$DICTIONARY_WORDS") {$DOCUMENT_CACHE{'DWF'}{'xml'} = $DWF;}
  
  undef($DOCUMENT_CACHE);
  my $xml = $node->ownerDocument;
  $DOCUMENT_CACHE{$headerDoc.$mtime}{'xml'} = $xml;
  my $osisIDWork = @{$XPC->findnodes('/osis:osis/osis:osisText[1]', $xml)}[0]->getAttribute('osisIDWork');
  $DOCUMENT_CACHE{$headerDoc.$mtime}{'getModNameOSIS'} = $osisIDWork;
  
  # Save data by MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  undef($DOCUMENT_CACHE{$osisIDWork});
  $DOCUMENT_CACHE{$osisIDWork}{'xml'}                = $xml;
  $DOCUMENT_CACHE{$osisIDWork}{'getModNameOSIS'}     = $osisIDWork;
  $DOCUMENT_CACHE{$osisIDWork}{'getRefSystemOSIS'}   = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[@osisWork="'.$osisIDWork.'"]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'isChildrensBible'}   = ($DOCUMENT_CACHE{$osisIDWork}{'getRefSystemOSIS'} =~ /^Book\w+CB$/ ? 1:0);
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
    $DOCUMENT_CACHE{$w}{'getRefSystemOSIS'}   = @{$XPC->findnodes('./osis:refSystem', $work)}[0]->textContent;
    $DOCUMENT_CACHE{$w}{'isChildrensBible'}   = ($DOCUMENT_CACHE{$w}{'getRefSystemOSIS'} =~ /^Book\w+CB$/ ? 1:0);
    $DOCUMENT_CACHE{$w}{'getVerseSystemOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getVerseSystemOSIS'};
    $DOCUMENT_CACHE{$w}{'getBibleModOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getBibleModOSIS'};
    $DOCUMENT_CACHE{$w}{'getDictModOSIS'} = $DOCUMENT_CACHE{$osisIDWork}{'getDictModOSIS'};
    $DOCUMENT_CACHE{$w}{'xml'} = ''; # force a re-read when again needed (by existsElementID)
  }
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

sub getProjectOsisFile($) {
  my $mod = shift;

  my $osis = '';
  
  # self
  if ($mod eq $MOD) {
    $osis = "$OUTDIR/$MOD.xml";
    return (-e $osis ? $osis:'');
  }
  
  my $dir = $OUTDIR; $dir =~ s/\b$MOD\b/$mod/;
  
  # explicit output location
  if (-e "$dir/$mod.xml") {$osis = "$dir/$mod.xml";}
  # Bible looking for dict
  elsif (-e "$INPD/$mod/output/$mod.xml") {$osis = "$INPD/$mod/output/$mod.xml";}
  # dict looking for Bible
  elsif (-e "$INPD/../output/$mod.xml") {$osis = "$INPD/../output/$mod.xml";}
  # not found
  elsif (!$GETPROJECTOSISFILE_WARN{$mod}) {
    &Warn("Output project OSIS file \"$mod\" could not be found.");
    $GETPROJECTOSISFILE_WARN{$mod}++;
  }
  return $osis;
}


# Searches and replaces $$tP text for a single dictionary link, according 
# to the $DWF file, and logs any result. If a match is found, the proper 
# reference tags are inserted, and the matching pattern is returned. 
# Otherwise the empty string is returned and the input text is unmodified.
sub addDictionaryLink(\$$$$\@) {
  my $textP = shift;
  my $textNode = shift;
  my $explicitContext = shift; # context string if the node was marked in the text as a glossary link
  my $glossaryContext = shift; # for SeeAlso links only
  my $glossaryScopeP = shift; # for SeeAlso links only

  my $matchedPattern = '';
  
  # Cache match related info
  if (!@MATCHES) {
    my $notes;
    $OT_CONTEXTSP =  &getContexts('OT');
    $NT_CONTEXTSP =  &getContexts('NT');
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
      $minfo{'contexts'} = &getContexts($minfo{'context'}, \$notes);
      $minfo{'notContext'} = &getScopedAttribute('notContext', $m);
      $minfo{'notContexts'} = &getContexts($minfo{'notContext'}, \$notes);
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
  if ($glossaryContext) {$context = $glossaryContext; $multiples_context = $glossaryContext;}
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
#@DICT_DEBUG = ($textNode); @DICT_DEBUG_THIS = (decode("utf8", "Ким мени севса ўшани севаман,"));
#&dbg("\nMatch: ".$m->{'node'}->textContent."\n"); foreach my $k (keys %{$m}) {if ($k !~ /^(node|skipRootID)$/) {&dbg("\t\t$k = ".$m->{$k}."\n");}} &dbg("\n");
    &dbg(sprintf("\nNode(type %s, %s): %s\nText: %s\nMatch: %s\n", $textNode->parentNode()->nodeType, $context, $textNode, $$textP, $m->{'node'}));
    
    my $filterMultiples = (!$explicitContext && $m->{'multiple'} !~ /^true$/i);
    my $key = ($filterMultiples ? &getMultiplesKey($m, $m->{'multiple'}, \@contextNote):'');
    
    if ($explicitContext && $m->{'notExplicit'}) {&dbg("00\n"); next;}
    elsif (!$explicitContext && $m->{'onlyExplicit'}) {&dbg("01\n"); next;}
    else {
      if ($glossaryContext && $m->{'skipRootID'}{&getRootID($glossaryContext)}) {&dbg("05\n"); next;} # never add glossary links to self
      if (!$contextIsOT && $m->{'onlyOldTestament'}) {&dbg("filtered at 10\n"); next;}
      if (!$contextIsNT && $m->{'onlyNewTestament'}) {&dbg("filtered at 20\n"); next;}
      if ($filterMultiples) {
        if (@contextNote > 0) {if ($MULTIPLES{$key}) {&dbg("filtered at 35\n"); next;}}
        # $removeLater disallows links within any phrase that was previously skipped as a multiple.
        # This helps prevent matched, but unlinked, phrases inadvertantly being torn into smaller, likely irrelavent, entry links.
        elsif ($MULTIPLES{$key}) {&dbg("filtered at 40\n"); $removeLater = 1;}
      }
      if ($m->{'context'}) {
        my $gs = scalar(@{$glossaryScopeP}); my $ic = &inContext($context, $m->{'contexts'}); my $igc = ($gs ? &inGlossaryContext($glossaryScopeP, $m->{'contexts'}):0);
        if ((!$gs && !$ic) || ($gs && !$ic && !$igc)) {&dbg("filtered at 50\n"); next;}
      }
      if ($m->{'notContext'}) {
        if (&inContext($context, $m->{'notContexts'})) {&dbg("filtered at 60\n"); next;}
      }
      if ($m->{'XPATH'}) {
        my $tst = @{$XPC->findnodes($m->{'XPATH'}, $textNode)}[0];
        if (!$tst) {&dbg("filtered at 70\n"); next;}
      }
      if ($m->{'notXPATH'}) {
        $tst = @{$XPC->findnodes($m->{'notXPATH'}, $textNode)}[0];
        if ($tst) {&dbg("filtered at 80\n"); next;}
      }
    }
    
    my $is; my $ie;
    if (&glossaryMatch($textP, $m->{'node'}, \$is, \$ie, $explicitContext)) {next;}
    if ($is == $ie) {
      &ErrorBug("Match result was zero width!: \"".$m->{'node'}->textContent."\"");
      next;
    }
    
    $MatchesUsed{$m->{'node'}->unique_key}++;
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
      $EntryLink{&decodeOsisRef($m->{'osisRef'})}{$logContext}++;
      
      my $dict;
      foreach my $sref (split(/\s+/, $m->{'osisRef'})) {
        if (!$sref) {next;}
        my $e = &osisRef2Entry($sref, \$dict);
        $Replacements{$e.": ".$match.", ".$dict}++;
      }

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

# Takes the context or notContext attribute value from DWF and determines
# whether it is a Paratext reference list or not. If it is, it's converted
# to a valid osisRef. If there are any errors, the value is returned unchanged.
sub contextAttribute2osisRefAttribute($) {
  my $val = shift;
  
  if ($CONVERTED_P2O{$val}) {return $CONVERTED_P2O{$val};}
  
  my @parts;
  @parts = split(/\s*,\s*/, $val);
  my $reportParatextWarnings = (($val =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1) ? 1:0) || (scalar(@parts) > 3));
  foreach my $part (@parts) {
    if ($part =~ /^([\d\w]\w\w)\b/ && &getOsisName($1, 1)) {next;}
    if ($reportParatextWarnings) {
      &Warn("Attribute part \"$part\" might be a failed Paratext reference in \"$val\".");
    }
    return $val;
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
        &Error("contextAttribute2osisRefAttribute: Bad Paratext book name(s) \"$part\" of \"$val\".");
        return $val;
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
        &Error("contextAttribute2osisRefAttribute: Bad Paratext reference \"$part\" of \"$val\".");
        return $val;
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
        &Error("contextAttribute2osisRefAttribute: Unrecognized Paratext book \"$bk\" of \"$val\".");
        return $val;
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
  if ($ret ne $val) {
    $CONVERTED_P2O{$val} = $ret;
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


# Scoped attributes are hierarchical and cummulative. They occur in both
# positive and negative (not) forms. A positive attribute cancels any
# negative forms of that attribute occuring higher in the hierarchy.
sub getScopedAttribute($$) {
  my $a = shift;
  my $m = shift;
  
  my $ret = '';
  
  my $positive = ($a =~ /^not(.*?)\s*$/ ? lcfirst($1):$a);
  if ($positive =~ /^xpath$/i) {$positive = uc($positive);}
  my $negative = ($a =~ /^not/ ? $a:'not'.ucfirst($a));
    
  my @r = $XPC->findnodes("ancestor-or-self::*[\@$positive or \@$negative]", $m);
  if (@r[0]) {
    my @ps; my @ns;
    foreach my $re (@r) {
      my $p = $re->getAttribute($positive);
      if ($p) {
        if ($positive eq 'context') {$p = &contextAttribute2osisRefAttribute($p);}
        push(@ps, $p);
        @ns = ();
      }
      my $n = $re->getAttribute($negative);
      if ($n) {
        if ($positive eq 'context') {$n = &contextAttribute2osisRefAttribute($n);}
        push(@ns, $n);
      }
    }
    my $retP = ($a eq $positive ? \@ps:\@ns);
    if (@{$retP} && @{$retP}[0]) {
      $ret = join(($a =~ /XPATH/ ? '|':' '), @{$retP});
    }
  }
  
  if ($a eq 'context' && $ret =~ /\bALL\b/) {return '';}
  
  return $ret;
}


sub dbg($$) {
  my $p = shift;

##for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {&Log(@DICT_DEBUG_THIS[$i]." ne ".@DICT_DEBUG[$i]."\n", 1);}
#  
#  if (!@DICT_DEBUG_THIS) {return 0;}
#  for (my $i=0; $i < @DICT_DEBUG_THIS; $i++) {
#    if (@DICT_DEBUG_THIS[$i] ne @DICT_DEBUG[$i]) {return 0;}
#  }
#  
#  &Debug($p);
  return 1;
}


# Takes context/notContext attribute values from DictionaryWords.xml 
# (which are osisRef values) and converts them into a hash containing 
# the contextArray members (which compose the attribute value). 
#
# See contextArray() which outputs only the following forms:
# BIBLE_INTRO.0.0.0 = Bible intro
# TESTAMENT_INTRO.0.0.0 = Old Testament intro
# TESTAMENT_INTRO.1.0.0 = New Testament intro
# Gen.0.0.0 = Gen book intro
# Gen.1.0.0 = Gen chapter 1 intro
# Gen.1.1 = Genesis 1:1
#
# This function also outputs the following possibility for a big speedup
# Gen
sub getContexts($\$) {
  my $refs = shift;
  my $notesP = shift;
  
  my %h;
  foreach my $ref (split(/\s+/, $refs)) {
    # Handle whole book
    if ($OSISBOOKS{$ref}) {$h{'books'}{$ref}++; next;}
    
    # Handle keywords OT and NT
    if ($ref =~ /^(OT|NT)$/) {
      $h{'contexts'}{'TESTAMENT_INTRO.'.($ref eq 'OT' ? '0':'1').'.0.0'}++;
      foreach my $bk (split(/\s+/, ($ref eq 'OT' ? $OT_BOOKS:$NT_BOOKS))) {
        $h{'books'}{$bk}++;
      }
      next;
    }
    
    # Handle special case of BOOK1-BOOK2 for a major speedup
    if ($ref =~ /^($OSISBOOKSRE)-($OSISBOOKSRE)$/) {
      my $bookOrderP; &getCanon(&conf('Versification'), NULL, \$bookOrderP, NULL);
      my $aP = &scopeToBooks($ref, $bookOrderP);
      foreach my $bk (@{$aP}) {$h{'books'}{$bk}++;}
      next;
    }
      
    foreach my $k (split(/\s+/, &osisRef2Contexts($ref))) {
    
      # Normalize to contextArray form
      $k =~ s/^((BIBLE|TESTAMENT)_INTRO\.\d)$/$1.0.0/;
      $k =~ s/^((BIBLE|TESTAMENT)_INTRO\.\d\.\d)$/$1.0/;
      $k =~ s/^([^\.]+\.0)$/$1.0/;
      
      # Handle keyword xALL
      if ($k =~ s/^xALL\b//) {
        foreach my $bk (split(/\s+/, "$OT_BOOKS $NT_BOOKS")) {
          $h{'contexts'}{"$bk$k"}++;
        }
      }
      
      elsif ($k =~ s/^[A-Za-z]+\://) {$h{'contexts'}{&decodeOsisRef($k)}++;}
      else {$h{'contexts'}{$k}++;}
    }
  }
  
  if ($notesP && $refs && !$ALREADY_NOTED_RESULT{$refs}) {
    $ALREADY_NOTED_RESULT{$refs}++;
    $$notesP .= "NOTE: Converted context attribute value to contexts:\n";
    $$notesP .= "  Context  = $refs\n";
    $$notesP .= "  Contexts =".join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'books'}})).' '.join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'contexts'}}))."\n\n";
  }
  
  return \%h;
}

# Return context if there is intersection between context and contextsHashP, else 0.
# $context may be a dictionary entry, bibleContext (see bibleContext()) or book name.
# $contextsHashP is output hash from getContexts()
sub inContext($\%) {
  my $context = shift;
  my $contextsHashP = shift;
  
  foreach my $contextID (&contextArray($context)) {
    if ($contextsHashP->{'contexts'}{$contextID}) {return $context;}
    # check book alone
    if ($contextID =~ s/^([^\.]+).*?$/$1/ && $contextsHashP->{'books'}{$contextID}) {
      return $context;
    }
  }
  
  return 0;
}

sub inGlossaryContext(\@\%) {
  my $bookArrayP = shift;
  my $contextsHashP = shift;
 
  foreach my $bk (@{$bookArrayP}) {
    if (&inContext($bk, $contextsHashP)) {return $bk;}
  }
  
  return 0;
}

# return special Bible context reference for $node:
# BIBLE_INTRO.0.0.0 = Bible intro
# TESTAMENT_INTRO.0.0.0 = Old Testament intro
# TESTAMENT_INTRO.1.0.0 = New Testament intro
# Gen.0.0.0 = Gen book intro
# Gen.1.0.0 = Gen chapter 1 intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext($) {
  my $node = shift;
  
  my $context = '';
  
  # get book
  my $bk = @{$XPC->findnodes('ancestor-or-self::osis:div[@type=\'book\'][@osisID][1]', $node)}[0];
  my $bkID = ($bk ? $bk->getAttribute('osisID'):'');
  
  # no book means we might be a Bible or testament introduction (or else an entirely different type of OSIS file)
  if (!$bkID) {
    my $refSystem = &getRefSystemOSIS($node);
    if ($refSystem !~ /^Bible/) {
      &ErrorBug("bibleContext: OSIS file is not a Bible \"$refSystem\" for node \"$node\"");
      return '';
    }
    my $tst = @{$XPC->findnodes('ancestor-or-self::osis:div[@type=\'bookGroup\'][1]', $node)}[0];
    if ($tst) {
      return "TESTAMENT_INTRO.".(0+@{$XPC->findnodes('preceding::osis:div[@type=\'bookGroup\']', $tst)}).".0.0";
    }
    return "BIBLE_INTRO.0.0.0";
  }

  my $e;
  if ($bk && $bkID) {
    # find most specific osisID associated with elem (assumes milestone verse/chapter tags and end tags which have no osisID attribute)
    my $v = @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $node)}[0];
    if ($v && $v->getAttribute('osisID') !~ /^\Q$bkID.\E/) {$v = '';}

    my $c = @{$XPC->findnodes('preceding::osis:chapter[@osisID][1]', $node)}[0];
    if ($c && $c->getAttribute('osisID') !~ /^\Q$bkID.\E/) {$c = '';}
    
    # if we have verse and chapter, but verse is not within chapter, use chapter instead
    if ($v) {
      if ($c) {
        my $bkch;
        if ($v->getAttribute('osisID') =~ /^([^\.]*\.[^\.]*)(\.|$)/) {
          $bkch = $1;
        }
        if (!$bkch || $c->getAttribute('osisID') !~ /^\Q$bkch\E(\.|$)/) {
          $e = $c;
        }
      }
      if (!$e) {$e = $v;}
    }
    else {$e = $c;}
    
    if (!$e) {$e = $bk;}
  }
  
  # get context from most specific osisID
  if ($e) {
    my $id = $e->getAttribute('osisID');
    $context = ($id ? $id:"unk.0.0.0");
    if ($id =~ /^\w+$/) {$context .= ".0.0.0";}
    elsif ($id =~ /^\w+\.\d+$/) {$context .= ".0.0";}
    elsif ($id =~ /^\w+\.\d+\.(\d+)$/) {$context .= ".$1";}
    elsif ($id =~ /^(\w+\.\d+\.\d+) .*\w+\.\d+\.(\d+)$/) {$context = "$1.$2";}
  }
  else {
    &ErrorBug("bibleContext could not determine context of \"$node\"");
    return 0;
  }
  
  return $context;
}

# returns:
# A keyword osisID if $node is part of a glossary entry.
# Or else "BEFORE_" is prepended to the following keyword osisID if $node is part of a glossary introduction.
sub glossaryContext($) {
  my $node = shift;
  
  # is node in a type div?
  my @typeXPATH; foreach my $sb (@USFM2OSIS_PY_SPECIAL_BOOKS) {push(@typeXPATH, "\@type='$sb'");}
  my $typeDiv = @{$XPC->findnodes('./ancestor::osis:div['.join(' or ', @typeXPATH).'][last()]', $node)}[0];
  if (!$typeDiv) {
    &ErrorBug("glossaryContext: Node is not part of a glossary: $node");
    return '';
  }

  # get preceding keyword or self
  my $prevkw = @{$XPC->findnodes('ancestor-or-self::osis:seg[@type="keyword"][1]', $node)}[0];
  if (!$prevkw) {$prevkw = @{$XPC->findnodes('preceding::osis:seg[@type="keyword"][1]', $node)}[0];}
  
  if ($prevkw) {
    foreach my $kw ($XPC->findnodes('.//osis:seg[@type="keyword"]', $typeDiv)) {
      if ($kw->isSameNode($prevkw)) {
        if (!$prevkw->getAttribute('osisID')) {
          &ErrorBug("glossaryContext: Previous keyword has no osisID \"$prevkw\"");
        }
        return $prevkw->getAttribute('osisID');
      }
    }
  }
  
  # if not, then use BEFORE
  my $nextkw = @{$XPC->findnodes('following::osis:seg[@type="keyword"]', $node)}[0];
  if (!$nextkw) {
    &ErrorBug("glossaryContext: There are no entries in the glossary which contains node $node");
    return '';
  }
  
  if (!$nextkw->getAttribute('osisID')) {
    &ErrorBug("glossaryContext: Next keyword has no osisID \"$nextkw\"");
  }
  return 'BEFORE_'.$nextkw->getAttribute('osisID');
}

# Takes a context and if it is a verse range, returns an array containing
# each verse's osisRef. If it's not a verse range, the returned array
# contains a single element being the input context, unchanged.
sub contextArray($) {
  my $context = shift;
  
  my @out;
  if ($context =~ /^(BIBLE|TESTAMENT)_INTRO/) {push(@out, $context);}
  elsif ($context =~ /^(\w+\.\d+)\.(\d+)\.(\d+)$/) {
    my $bc = $1;
    my $v1 = $2;
    my $v2 = $3;
    for (my $i = $v1; $i <= $v2; $i++) {push(@out, "$bc.$i");}
  }
  else {
    $context =~ s/\.(PART)$/!$1/; # special case from fitToVerseSystem
    push(@out, $context);
  }
  
  return @out;
}

sub osisRef2Contexts($$$) {
  my $osisRefLong = shift;
  my $osisRefWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisRefWorkDefault
  
  # This call for context includes introductions (even though intros do not have osisIDs)
  return &osisRef2osisID($osisRefLong, $osisRefWorkDefault, $workPrefixFlag, 1);
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

# Take an osisID of the form BOOK or BOOK.CH (or BOOK.CH.VS but this 
# only returns itself) and expand it to a list of individual verses of 
# the form BOOK.CH.VS, according to the verse system vsys. Book
# introductions, which have the form BOOK.0, are returned unchanged.
# Expanded osisIDs include book and chapter introductions if 
# expandIntros is set.
sub expandOsisID($$$) {
  my $osisID = shift;
  my $vsys = shift;
  my $expandIntros = shift;
  
  if ($osisID =~ /^[^\.]+\.\d+\.\d+$/ || 
      $osisID =~ /^[^\.]+\.0$/ || 
      !&idInVerseSystem($osisID, $vsys)) {
    return $osisID;
  }
  if ($osisID !~ /^([^\.]+)(\.(\d+))?$/) {
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
  
  &Log("\nCHECKING SOURCE SCRIPTURE REFERENCE OSISREF TARGETS IN $in_osis...\n");
  
  my $changes = 0; my $problems = 0; my $checked = 0;
  
  my $in_bible = ($INPD eq $MAININPD ? $in_osis:'');
  if (!$in_bible) {
    # The Bible OSIS needs to be put into the source verse system for this check
    $in_bible = "$TMPDIR/$MAINMOD.xml";
    &copy(&getProjectOsisFile($MAINMOD), $in_bible);
    &runScript("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", \$in_bible);
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
    &copy(&getProjectOsisFile($MAINMOD), $bibleOSIS);
    $bibleXML = $XML_PARSER->parse_file($bibleOSIS);
    &readOsisIDs(\%osisID, $bibleXML);
  }
  # Check reference links in OSIS file (fixed vsys) NOT including glossary links if OSIS is a Bible
  &checkReferenceLinks2($inXML, \%refcount, \%errors, \%osisID, ($inIsBible ? -1:0));
  &reportReferences(\%refcount, \%errors); undef(%refcount); undef(%errors);
  
  # If OSIS is NOT a Bible, now check glossary reference links in the Bible OSIS
  if (!$inIsBible) {
    &Log("\nCHECKING GLOSSARY OSISREF TARGETS IN BIBLE OSIS $bibleOSIS...\n");
    &checkReferenceLinks2($bibleXML, \%refcount, \%errors, \%osisID, 1);
    &reportReferences(\%refcount, \%errors); undef(%refcount); undef(%errors);
  }

  undef(%osisID); # re-read source vsys OSIS files
  &runScript("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", \$osis);
  &Log("\nCHECKING SOURCE VSYS NON-GLOSSARY OSISREF TARGETS IN $osis");
  $inXML = $XML_PARSER->parse_file($osis);
  &readOsisIDs(\%osisID, $inXML);
  if ($inIsBible) {$bibleOSIS = $osis; $bibleXML = $inXML;}
  else {
    &runScript("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", \$bibleOSIS);
    &Log(" AGAINST $bibleOSIS");
    $bibleXML = $XML_PARSER->parse_file($bibleOSIS);
    &readOsisIDs(\%osisID, $bibleXML);
  }
  &Log("...\n");
  # Check reference links in OSIS (source vsys) NOT including glossary links which are unchanged between fixed/source
  &checkReferenceLinks2($inXML, \%refcount, \%errors, \%osisID, -1);
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
    foreach my $child (@children) {$r->parentNode()->insertBefore($child, $r);}
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
    
    my $osisRef = $r->getAttribute('osisRef');
    if (!$osisRef) {
    &Error("Reference link is missing an osisRef attribute: \"$r\"", 
"Maybe this should not be marked as a reference? Reference tags in OSIS 
require a valid target. When there isn't a valid target, then a 
different USFM tag should be used instead.");
      $errors{$type}++;
      next;
    }
    my $rwork = ($osisRef =~ s/^(\w+):// ? $1:$osisRefWork);
    
    # If this is a reference to a verse, check that it follows some rules:
    # 1) no spaces, since multiple targets are not supported (use multiple elements)
    # 2) warn if a range exceeds the chapter since xulsword and other programs don't support these
    if ($osisRef =~ /(^|\s+)\w+\.\d+(\.\d+)?(\s+|$)/) {
      if ($osisRef =~ /\s+/) {&Error("A Scripture osisRef cannot have multiple targets: $osisRef", "Use multiple reference elements instead.");}
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
    
    $refcountP->{$type}++;
    if ($failed) {
      $errorsP->{$type}++;
      &Error("$type $failed not found: ".$r->toString());
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
  foreach my $k (keys %ids) {
    if ($ids{$k} > 1) {
      &Error("osisID attribute value is not unique: $k (".$ids{$k}.")", "There are multiple elements with this osisID, and this is not allowed.");
    }
  }
  
  &Report("Found ".@osisIDs." unique osisIDs");
}


sub checkFigureLinks($) {
  my $in_osis = shift;
  
  &Log("\nCHECKING OSIS FIGURE TARGETS IN $in_osis...\n");
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  my @links = $XPC->findnodes('//osis:figure', $osis);
  my $errors = 0;
  foreach my $l (@links) {
    my $tag = $l->toString(); $tag =~ s/^(<[^>]*>).*$/$1/s;
    my $localPath = &getFigureLocalPath($l);
    if (!$localPath) {
      &Error("Could not determine figure local path of $l");
      $errors++;
      next;
    }
    if (! -e $localPath) {
      &Error("checkFigureLinks: Figure \"$tag\" src target does not exist at $localPath.");
      $errors++;
    }
    if ($l->getAttribute('src') !~ /^\.\/images\//) {
      &Error("checkFigureLinks: Figure \"$tag\" src target is outside of \"./images\" directory. This image may not appear in e-versions.");
    }
  }

  &Report("\"".@links."\" figure targets found and checked. ($errors unknown or missing targets)");
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
    &Error("Tag on line: ".$t->line_number().", \"$tag\" was used in an introduction that could trigger a bug in osis2mod.cpp, dropping introduction text.", "Replace this tag here with the corresponding introduction tag.");
  }
}

# Print log info for a word file
sub logDictLinks() {
  &Log("\n\n");
  &Report("Explicitly marked words or phrases that were linked to glossary entries: (". (scalar keys %ExplicitGlossary) . " variations)");
  my $mxl = 0; foreach my $eg (sort keys %ExplicitGlossary) {if (length($eg) > $mxl) {$mxl = length($eg);}}
  my %cons;
  foreach my $eg (sort keys %ExplicitGlossary) {
    my @txt;
    foreach my $tg (sort keys %{$ExplicitGlossary{$eg}}) {
      if ($tg eq 'Failed') {
        my @contexts = keys %{$ExplicitGlossary{$eg}{$tg}{'context'}};
        my $mlen = 0;
        foreach my $c (@contexts) {
          if (length($c) > $mlen) {$mlen = length($c);}
          my $ctx = $c; $ctx =~ s/^\s+//; $ctx =~ s/\s+$//; $ctx =~ s/<index\/>.*$//;
          $cons{lc($ctx)}++;
        }
        foreach my $c (@contexts) {$c = sprintf("%".($mlen+5)."s", $c);}
        push(@txt, $tg." (".$ExplicitGlossary{$eg}{$tg}{'count'}.")\n".join("\n", @contexts)."\n");
      }
      else {
        push(@txt, $tg." (".$ExplicitGlossary{$eg}{$tg}.")");
      }
    }
    my $msg = join(", ", sort { ($a =~ /failed/i ? 0:1) <=> ($b =~ /failed/i ? 0:1) } @txt);
    &Log(sprintf("%-".$mxl."s ".($msg !~ /failed/i ? "was linked to ":'')."%s", $eg, $msg) . "\n");
  }
  # Report each unique context ending for failures, since these may represent entries that are missing from the glossary
  my %uniqueConEnd;
  foreach my $c (keys %cons) {
    my $toLastWord;
    for (my $i=2; $i<=length($c) && $c !~ /^\s*$/; $i++) {
      my $end = substr($c, -$i, $i);
      my $keep = 1;
      if (substr($end,0,1) =~ /\s/) {$toLastWord = substr($end, 1, length($end)-1);}
      foreach my $c2 (keys %cons) {
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
    foreach my $dh (keys %EntryHits) {
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
    if ($MatchesUsed{$m->unique_key}) {next;}
    my $entry = @{$XPC->findnodes('./ancestor::dw:entry[1]', $m)}[0];
    if ($entry) {
      my $osisRef = $entry->getAttribute('osisRef'); $osisRef =~ s/^\Q$DICTMOD\E://;
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
  
  my %ematch;
  foreach my $rep (sort keys %Replacements) {
    if ($rep !~ /^(.*?): (.*?), (\w+)$/) {&ErrorBug("logDictLinks bad rep match: $rep !~ /^(.*?): (.*?), (\w+)\$/"); next;}
    $ematch{"$3:$1"}{$2} += $Replacements{$rep};
  }

  # get fields and their lengths
  my %kl;
  my %kas;
  my $mkl = 0;
  my $mas = 0;
  foreach my $ent (sort keys %EntryLink) {
    if (length($ent) > $mkl) {$mkl = length($ent);}
    my $t = 0; foreach my $ctx (keys %{$EntryLink{$ent}}) {$t += $EntryLink{$ent}{$ctx};}
    $kl{$ent} = $t;
    
    my $asp = '';
    if (!$ematch{$ent}) {&ErrorBug("missing ematch key \"$ent\"");}
    my $st = $ent; $st =~ s/^\w*\://; $st =~ s/\.dup\d+$//;
    foreach my $as (sort { sprintf("%06i%s", $ematch{$ent}{$b}, $b) cmp sprintf("%06i%s", $ematch{$ent}{$a}, $a) } keys %{$ematch{$ent}}) {
      my $tp = ($st eq $as ? '':(lc($st) eq lc($as) ? '':'*'));
      $asp .= $as."(".$ematch{$ent}{$as}."$tp) ";
    }
    if (length($asp) > $mas) {$mas = length($asp);}
    $kas{$ent} = $asp;
  }

  # print out the report
  my $gt = 0;
  my $p = '';
  foreach my $ent (sort {sprintf("%06i%s", $kl{$b}, $b) cmp sprintf("%06i%s", $kl{$a}, $a) } keys %kl) {
    my $t = 0;
    my $ctxp = '';
    foreach my $ctx (sort {&matchResultSort($ent, $a, $b);} keys %{$EntryLink{$ent}}) {
      $t  += $EntryLink{$ent}{$ctx};
      $gt += $EntryLink{$ent}{$ctx};
      $ctxp .= $ctx."(".$EntryLink{$ent}{$ctx}.") ";
    }
    
    $p .= sprintf("%4i links to %-".$mkl."s as %-".$mas."s in %s\n", $t, $ent, $kas{$ent}, $ctxp);
  }
  &Note("
The following listing should be looked over to be sure text is
correctly linked to the glossary. Glossary entries are matched in the
text using the match elements found in the $DICTIONARY_WORDS file.\n");
  &Report("Links created: ($gt instances)\n* is textual difference other than capitalization\n$p");
  
}

sub matchResultSort($$$) {
  my $ent = shift;
  my $a = shift;
  my $b = shift;
  
  my $m1 = ($EntryLink{$ent}{$b} <=> $EntryLink{$ent}{$a});
  if ($m1) {return $m1;}
  return ($a cmp $b);
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
  if (!open(TEST, "<$osis")) {&Error("is_usfm2osis could not open $osis", '', 1);}
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
  my $ext; if ($name =~ s/^.*?\/([^\/]+)\.([^\.\/]+)$/$1/) {$ext = $2;}
  else {
    &ErrorBug("runScript: Bad script name \"$script\"!");
    return 0;
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
  map(push(@args, &escfile("$_=".$paramsP->{$_})), keys %{$paramsP});
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
  foreach my $p (keys %{$paramsP}) {
    my $v = $paramsP->{$p};
    $v =~ s/(["\\])/\\$1/g; # escape quote since below passes with quote
    $cmd .= " $p=\"$v\"";
  }
  $cmd .= " SCRIPT_NAME=\"$SCRIPT_NAME\"";
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
      if (open(PRGF, "<:encoding(UTF-8)", "$msg.progress.tmp")) {
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


sub copy_images_to_module($$) {
	my $imgFile = shift;
  my $dest = shift;
  
	&Log("\n--- COPYING $MOD image(s) \"$imgFile\"\n");
	if (-d $imgFile) {
		my $imagePaths = "INCLUDE IMAGE PATHS.txt";
		&copy_dir($imgFile, "$dest/images", 1, 0, 0, quotemeta($imagePaths));
		if (-e "$imgFile/$imagePaths") { # then copy any additional images located in $imagePaths file
			open(IIF, "<$imgFile/$imagePaths") || die "Could not open \"$imgFile/$imagePaths\"\n";
			while (<IIF>) {
				if ($_ =~ /^\s*#/) {next;}
				chomp;
				if ($_ =~ /^\./) {$_ = "$imgFile/$_";}
				if (-e $_) {&copy_images_to_module($_, $dest);}
				else {&Error("Image directory listed in \"$imgFile/$imagePaths\" was not found: \"$_\"");}
			}
			close(IIF);
		}
	}
	else {
		if (-e "$dest/images/$imgFile") {unlink("$dest/images/$imgFile");} 
		copy($imgFile, "$dest/images");
	}
}


# make a zipped copy of a module
sub zipModule($$) {
  my $zipfile = shift;
  my $moddir = shift;
  
  &Log("\n--- COMPRESSING MODULE TO A ZIP FILE.\n");
  chdir($moddir);
  my $cmd = "zip -r ".&escfile($zipfile)." ".&escfile("./*");
  &shell($cmd, 1);
  chdir($SCRD);
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
  
  # Search for any ISBN number(s) in the osis file
  my @isbns;
  my $isbn;
  my @tns = $XPC->findnodes('//text()', $xml);
  foreach my $tn (@tns) {
    if ($tn =~ /\bisbn (number|\#|no\.?)?([\d\-]+)/i) {
      $isbn = $2;
      push(@isbns, $isbn);
    }
  }
  $isbn = join(', ', @isbns);
  
  my $header;
    
  # Add work element for MAINMOD
  my %workElements;
  &getOSIS_Work($MAINMOD, \%workElements, $CONF, ($MOD eq $MAINMOD ? $isbn:''));
  # CAUTION: The workElements indexes must correlate to their assignment in getOSIS_Work()
  if ($workElements{'100000:type'}{'textContent'} eq 'Bible') {
    $workElements{'190000:scope'}{'textContent'} = &getScope($$osisP, &conf('Versification'));
  }
  my %workAttributes = ('osisWork' => $MAINMOD);
  $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  
  # Add work element for DICTMOD
  if ($DICTMOD) {
    my %workElements;
    &getOSIS_Work($DICTMOD, \%workElements, $CONF, ($MOD ne $MAINMOD ? $isbn:''));
    my %workAttributes = ('osisWork' => $DICTMOD);
    $header .= &writeWorkElement(\%workAttributes, \%workElements, $xml);
  }
  
  &writeXMLFile($xml, $output, (ref($osis_or_osisP) ? $osis_or_osisP:''));
  
  return $header;
}

# Write all work children elements for modname to osisWorkP. The modname 
# must be either the value of $MAINMOD or $DICTMOD. Note that each raw 
# conf value is written to the work element matching its section (context 
# specific values from &conf are not written). This means that retreiving 
# the usual context specific value from the header data requires 
# searching both MAIN and DICT work elements. 
sub getOSIS_Work($$$$) {
  my $modname = shift; 
  my $osisWorkP = shift;
  my $confP = shift;
  my $isbn = shift;
  
  my $section = ($modname eq $DICTMOD ? "$DICTMOD+":'');
 
  my @tm = localtime(time);
  my %type;
  if    ($confP->{$section.'ModDrv'} =~ /LD/)   {$type{'type'} = 'x-glossary'; $type{'textContent'} = 'Glossary';}
  elsif ($confP->{$section.'ModDrv'} =~ /Text/) {$type{'type'} = 'x-bible'; $type{'textContent'} = 'Bible';}
  elsif ($confP->{$section.'ModDrv'} =~ /GenBook/ && $MOD =~ /CB$/i) {$type{'type'} = 'x-childrens-bible'; $type{'textContent'} = 'Children\'s Bible';}
  elsif ($confP->{$section.'ModDrv'} =~ /Com/) {$type{'type'} = 'x-commentary'; $type{'textContent'} = 'Commentary';}
  my $idf = ($type{'type'} eq 'x-glossary' ? 'Dict':($type{'type'} eq 'x-childrens-bible' ? 'GenBook':($type{'type'} eq 'x-commentary' ? 'Comm':'Bible')));
  my $refSystem = "Bible.".$confP->{$section.'Versification'};
  if ($type{'type'} eq 'x-glossary') {$refSystem = "Dict.".$confP->{$section.'ModuleName'};}
  if ($type{'type'} eq 'x-childrens-bible') {$refSystem = "Book".$confP->{$section.'ModuleName'};}
  my $isbnID = $isbn;
  $isbnID =~ s/[\- ]//g;
  foreach my $n (split(/,/, $isbnID)) {if ($n && length($n) != 13 && length($n) != 10) {
    &Error("ISBN number \"$n\" is not 10 or 13 digits", "Check that the ISBN number is correct.");
  }}
  
  # map conf info to OSIS Work elements:
  # element order seems to be important for passing OSIS schema validation for some reason (hence the ordinal prefix)
  $osisWorkP->{'000000:title'}{'textContent'} = ($modname eq $DICTMOD ? &conf('CombinedGlossaryTitle'):&conf('TranslationTitle'));
  &mapLocalizedElem(30000, 'subject', $section.'Description', $confP, $osisWorkP, 1);
  $osisWorkP->{'040000:date'}{'textContent'} = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  $osisWorkP->{'040000:date'}{'event'} = 'eversion';
  &mapLocalizedElem(50000, 'description', $section.'About', $confP, $osisWorkP, 1);
  &mapConfig(50008, 59999, 'description', 'x-config', $confP, $osisWorkP, $modname);
  &mapLocalizedElem(60000, 'publisher', $section.'CopyrightHolder', $confP, $osisWorkP);
  &mapLocalizedElem(70000, 'publisher', $section.'CopyrightContactAddress', $confP, $osisWorkP);
  &mapLocalizedElem(80000, 'publisher', $section.'CopyrightContactEmail', $confP, $osisWorkP);
  &mapLocalizedElem(90000, 'publisher', $section.'ShortPromo', $confP, $osisWorkP);
  $osisWorkP->{'100000:type'} = \%type;
  $osisWorkP->{'110000:format'}{'textContent'} = 'text/xml';
  $osisWorkP->{'110000:format'}{'type'} = 'x-MIME';
  $osisWorkP->{'120000:identifier'}{'textContent'} = $isbnID;
  $osisWorkP->{'120000:identifier'}{'type'} = 'ISBN';
  $osisWorkP->{'121000:identifier'}{'textContent'} = "$idf.".$confP->{$section.'ModuleName'};
  $osisWorkP->{'121000:identifier'}{'type'} = 'OSIS';
  $osisWorkP->{'130000:source'}{'textContent'} = ($isbn ? "ISBN: $isbn":'');
  $osisWorkP->{'140000:language'}{'textContent'} = $confP->{$section.'Lang'};
  &mapLocalizedElem(170000, 'rights', $section.'Copyright', $confP, $osisWorkP);
  &mapLocalizedElem(180000, 'rights', $section.'DistributionNotes', $confP, $osisWorkP);
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

sub mapLocalizedElem($$$$$$) {
  my $index = shift;
  my $workElement = shift;
  my $confEntry = shift;
  my $confP = shift;
  my $osisWorkP = shift;
  my $skipTypeAttribute = shift;
  
  foreach my $k (sort {$a cmp $b} keys %{$confP}) {
    if ($k !~ /^$confEntry(_([\w\-]+))?$/) {next;}
    my $lang = ($1 ? $2:'');
    $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'textContent'} = $confP->{$k};
    if (!$skipTypeAttribute) {$osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'type'} = "x-$k";}
    if ($lang) {
      $osisWorkP->{sprintf("%06i:%s", $index, $workElement)}{'xml:lang'} = $lang;
    }
    $index++;
    if (($index % 10) == 6) {&ErrorBug("mapLocalizedConf: Too many \"$workElement\" language variants.");}
  }
}

sub mapConfig($$$$$$$) {
  my $index = shift;
  my $maxindex = shift;
  my $elementName = shift;
  my $prefix = shift;
  my $confP = shift;
  my $osisWorkP = shift;
  my $modname = shift;
  
  foreach my $confEntry (sort keys %{$confP}) {
    if ($index > $maxindex) {&ErrorBug("mapConfig: Too many \"$elementName\" $prefix entries.");}
    elsif ($modname && $confEntry =~ /DICT\+/ && $modname ne $DICTMOD) {next;}
    elsif ($modname && $confEntry !~ /DICT\+/ && $modname eq $DICTMOD) {next;}
    else {
      $osisWorkP->{sprintf("%06i:%s", $index, $elementName)}{'textContent'} = $confP->{$confEntry};
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

sub writeNoteIDs($) {
  my $osisP = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1writeNoteIDs$3/;
  
  my $type;
  if    (&conf('ModDrv') =~ /LD/)   {$type = 'x-glossary';}
  elsif (&conf('ModDrv') =~ /Text/) {$type = 'x-bible';}
  elsif (&conf('ModDrv') =~ /GenBook/) {$type = 'x-childrens-bible';}
  else {return;}
  
  &Log("\nWriting note osisIDs:\n", 1);
  
  my @existing = $XPC->findnodes('//osis:note[not(@resp)][@osisID]', $XML_PARSER->parse_file($$osisP));
  if (@existing) {
    &Warn(@existing." notes already have osisIDs assigned, so this step will be skipped and no new note osisIDs will be written!");
    return;
  }
  
  my %osisID_note;
  
  my @files = &splitOSIS($$osisP);
  foreach my $file (@files) {
    my $xml = $XML_PARSER->parse_file($file);
    
    my $myMod = &getOsisRefWork($xml);
    
    # Get all notes excluding generic cross-references added from an external source
    my @allNotes = $XPC->findnodes('//osis:note[not(@resp)]', $xml);
    foreach my $n (@allNotes) {
      my $osisID;
      
      if ($type eq 'x-bible') {
        $osisID = &bibleContext($n);
        if ($osisID !~ s/^(\w+\.\d+\.\d+)\.\d+$/$1/) {
          &ErrorBug("Bad context for note osisID: $osisID !~ s/^(\w+\.\d+\.\d+)\.\d+\$/\$1/");
          next;
        }
      }
      elsif ($type eq 'x-childrens-bible') {
        $osisID = &chBibleContext($n);
      }
      else {$osisID = &glossaryContext($n);}
      
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
    
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($output);
  $$osisP = $output;
}


# Check for TOC entries, and write as much missing TOC information as possible
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
    # Insure there are as many as possible TOC entries for each book
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
    
    # Add translation main TOC entry and title if not already there
    my $mainTOC = @{$XPC->findnodes('//osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]
      [not(ancestor::osis:div[starts-with(@type, "book")])]
      [not(preceding::osis:div[starts-with(@type, "book")])][1]', $xml)}[0];
    if (!$mainTOC) {
      my $translationTitle = &conf('TranslationTitle');
      my $toc = $XML_PARSER->parse_balanced_chunk('
<div type="introduction" resp="'.$ROC.'">
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1][not_parent]'.$translationTitle.'"/>
  <title level="1" type="main" subType="x-introduction" canonical="false">'.$translationTitle.'</title>
</div>');
      my $insertBefore = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[not(self::osis:div[@type="x-cover"])][1]', $xml)}[0];
      $insertBefore->parentNode->insertBefore($toc, $insertBefore);
      &Note("Inserting top TOC entry and title within new introduction div as: $translationTitle");
    }
    
    # Add Testament TOC entries and titles if they are not already there, using OldTestamentTitle and NewTestamentTitle
    foreach my $missingTOC_Testament ($XPC->findnodes('//osis:div[@type="bookGroup"][descendant::osis:div[@type="book"]]
      [not(descendant::osis:milestone
          [@type="x-usfm-toc'.&conf('TOC').'"]
          [not(ancestor::osis:div[@type="book"])]
          [not(ancestor-or-self::*[parent::osis:div[@type="bookGroup"]][1]/preceding-sibling::osis:div[@type="book"])]
        )]', $xml
    )) {
      if (!$missingTOC_Testament) {next;}
      my $firstBook = @{$XPC->findnodes('descendant::osis:div[@type="book"][1]/@osisID', $missingTOC_Testament)}[0]->value;
      my $whichTestament = ($NT_BOOKS =~ /\b$firstBook\b/ ? 'New':'Old');
      my $testamentTitle = &conf($whichTestament.'TestamentTitle');
      my $toc = $XML_PARSER->parse_balanced_chunk('
<div type="introduction" resp="'.$ROC.'">
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1]'.$testamentTitle.'"/>
  <title level="1" type="main" subType="x-introduction" canonical="false">'.$testamentTitle.'</title>
</div>');
      $missingTOC_Testament->insertBefore($toc, $missingTOC_Testament->firstChild);
      &Note("Inserting $whichTestament Testament TOC entry and title within new introduction div as: $testamentTitle");
    }
    
    # Add Sub-Publication introduction TOC entries if not already there
    my @subPubIntros = $XPC->findnodes('//osis:div[@type="bookGroup"]/osis:div[not(@type="book")]
        [not(preceding-sibling::*[not(self::*[@resp="'.$ROC.'"])]) or boolean(preceding-sibling::*[not(self::*[@resp="'.$ROC.'"])][1][self::osis:div[@type="book"]])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml);
    foreach my $div (@subPubIntros) {
      my $tocentry = ($div->hasAttribute('osisRef') ? &getScopeTitle($div->getAttribute('osisRef')):'');
      if (!$tocentry) {
        my $nextbkn = @{$XPC->findnodes('following::osis:div[@type="book"][1]/descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n', $div)}[0];
        if ($nextbkn) {$tocentry = $nextbkn->value(); $tocentry =~ s/^\[[^\]]*\]//;}
      }
      if (!$tocentry) {
        my $nexttitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $div)}[0];
        if ($nexttitle) {$tocentry = $nexttitle->textContent();}
      }
      if ($tocentry) {
        my $tag = "<milestone type=\"x-usfm-toc".&conf('TOC')."\" n=\"[not_parent]$tocentry\" resp=\"$ROC\"/>";
        &Note("Inserting Sub-Publication TOC entry into \"".$div->getAttribute('type')."\" div as $tocentry");
        $div->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $div->firstChild);
      }
      else {&Note("Could not insert Sub-Publication TOC entry into \"".$div->getAttribute('type')."\" div because a title could not be determined.");}
    }
  }
  elsif ($modType eq 'dict') {
    my $maxkw = 7;
    # Any glossary (a div containing keywords) which has more than $maxkw keywords gets added to the TOC (unless it has level1 TOC entries already or it's already in the TOC)
    my @needTOC = $XPC->findnodes('//osis:div[count(descendant::osis:seg[@type="keyword"]) > '.$maxkw.']
        [not(@subType = "x-aggregate")][not(@resp="x-oc")]
        [not(descendant::*[contains(@n, "[level1]")])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml);
    my $n = 0;
    foreach my $glossDiv (@needTOC) {
      if ($glossDiv->getAttribute('scope')) {
        my $bookOrderP; &getCanon(&conf('Versification'), NULL, \$bookOrderP, NULL);
        if (!@{&scopeToBooks($glossDiv->getAttribute('scope'), $bookOrderP)}) {next;} # If scope is not an OSIS scope, then skip it
      }
      my $hasTitle = 1;
      my $glossTitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $glossDiv)}[0];
      if ($glossTitle) {$glossTitle = $glossTitle->textContent;}
      else {
        $hasTitle = 0;
        $glossTitle = &conf('GlossaryTitle'.++$n);
      }
      if (!$glossTitle) {
        $glossTitle = "Glossary #$n";
        &Error("The glossary with title '$glossTitle' needs a localized title.",
"Any glossary with more than $maxkw keywords which does not 
contain a Table Of Contents entry marked as [level1] will automatically 
be added to the TOC. You must provide the localized glossary title for 
this TOC entry by adding the following to config.conf: 
GlossaryTitle$n=The Localized Glossary Title. 
If you really do not want a title for this glossary to appear in the 
TOC, but rather want its keywords only to appear, then you can do that, 
and eliminate this error, by adding the following USFM to the beginning 
of the glossary:
\\toc".&conf('TOC')." [no_toc]");
      }
      my $toc = $XML_PARSER->parse_balanced_chunk('
  <milestone type="x-usfm-toc'.&conf('TOC').'" n="[level1]'.$glossTitle.'" resp="'.$ROC.'"/>'.($hasTitle ? '':'
  <title level="1" type="main" resp="'.$ROC.'">'.$glossTitle.'</title>'));
      $glossDiv->insertBefore($toc, $glossDiv->firstChild);
      &Note("Inserting glossary TOC entry and title within new introduction div as: $glossTitle");
    }
  }
  elsif ($modType eq 'childrens_bible') {return;}
  
  
  &writeXMLFile($xml, $output, $osisP, 1);
}

sub getScopeTitle($) {
  my $scope = shift;
  
  my $n = 0;
  while (my $s = &conf('ScopeSubPublication'.(++$n))) {
    if ($s eq $scope) {return &conf('TitleSubPublication'.($n));}
  }
  return '';
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
    my $osisRef;
    
    if ($refSystem =~ /^Bible/) {
      # get notes's context
      my $con_bc = &bibleContext($note);
      $con_bc =~ s/\.([^\.]+)\.([^\.]+)$//;
      my $con_vf = $1;
      my $con_vl = $2;
      
      if ($con_vf eq '0' || $con_vl eq '0') {
        &Warn("Not writting introduction note osisRef: ".&bibleContext($note), "<>Since introductions do not have their own osisIDs, these osisRefs have no valid target and should be unnecessary.");
        next;
      }
      
      # let annotateRef override context if it makes sense
      my $aror;
      my @rs = $XPC->findnodes('descendant::osis:reference[1][@type="annotateRef" and @osisRef]', $note);
      if (@rs && @rs[0]) {
        $aror = @rs[0]->getAttribute('osisRef');
        $aror =~ s/^[\w\d]+\://;
        if ($aror =~ /^([^\.]+\.\d+)(\.(\d+)(-\1\.(\d+))?)?$/) {
          my $ref_bc = $1; my $ref_vf = $3; my $ref_vl = $5;
          if (!$ref_vf) {$ref_vf = 0;}
          if (!$ref_vl) {$ref_vl = $ref_vf;}
          if (@rs[0]->getAttribute('annotateType') ne $VSYS{'AnnoTypeSource'} && ($con_bc ne $ref_bc || $ref_vl < $con_vf || $ref_vf > $con_vl)) {
            &Warn("writeMissingNoteOsisRefs: Note's annotateRef \"".@rs[0]."\" is outside note's context \"$con_bc.$con_vf.$con_vl\"");
            $aror = '';
          }
        }
        else {
          &Warn("writeMissingNoteOsisRefs: Unexpected annotateRef osisRef found \"".@rs[0]."\"");
          $aror = '';
        }
      }
      
      $osisRef = ($aror ? $aror:"$con_bc.$con_vf".($con_vl != $con_vf ? "-$con_bc.$con_vl":''));
    }
    
    elsif ($refSystem =~ /^Dict/) {
      $osisRef = &glossaryContext($note);
    }
    
    else {return 0;}

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


sub validateOSIS($) {
  my $osis = shift;
  
  # validate new OSIS file against OSIS schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml")." ".&escfile("xmllint")." --noout --schema \"$OSISSCHEMA\" ".&escfile($osis)." 2>&1";
  &Log("$cmd\n");
  my $res = `$cmd`;
  my $allow = "(element milestone\: Schemas validity )error( \: Element '.*?milestone', attribute 'osisRef'\: The attribute 'osisRef' is not allowed\.)";
  my $fix = $res;
  $fix =~ s/$allow/$1e-r-r-o-r$2/g;
  &Log("$fix\n");
  
  # Generate error if file fails to validate
  my $valid = 1;
  if (!$res || $res =~ /^\s*$/) {
    &Error("\"$osis\" validation problem. No success or failure message was returned from the xmllint validator.", "Check your Internet connection, or try again later.");
    $valid = 0;
  }
  elsif ($res !~ /^\Q$osis validates\E$/) {
    if ($res =~ s/$allow//g) {
      &Note("
      Ignore the above milestone osisRef attribute reports. The schema  
      here apparently deviates from the OSIS handbook which states that 
      the osisRef attribute is allowed on any element. The current usage  
      is both required and sensible.\n");
    }
    if ($res !~ /Schemas validity error/) {
      &Note("All of the above validation failures are being allowed.");
    }
    else {$valid = 0; &Error("\"$osis\" does not validate! See message(s) above.");}
  }
  
  &Log("\n");
  &Report("OSIS ".($valid ? 'passes':'fails')." required validation.\nEND OSIS VALIDATION");
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
