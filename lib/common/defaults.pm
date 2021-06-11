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

our ($APPENDLAYER, $CONFFILE, $DICTINPD, $INPD, $MAININPD, $MOD, $MAINMOD,
    $READLAYER, $WRITELAYER, %CONFIG_DEFAULTS, %ID_TYPE_MAP, %OSIS_ABBR,
    %OSIS_GROUP, %PERIPH_SUBTYPE_MAP, %PERIPH_TYPE_MAP, $DICTMOD, 
    %USFM_DEFAULT_PERIPH_TARGET, @OC_CONFIGS, @OSIS_GROUPS, @CF_FILES,
    @SUB_PUBLICATIONS, @SWORD_AUTOGEN_CONFIGS, $XML_PARSER, $XPC);

# Create default control files for a project (for both MAINMOD and 
# DICTMOD if there is one) from files found in defaults directories. 
# Default files are searched for using getDefaultFile(). Existing 
# project control files are never changed or overwritten. If a 
# template is located, it will be copied and then modified for the 
# project if a sub named &customize_<file>($path,$type,$bookNamesP) is 
# defined, otherwise any default file located will be copied. The order 
# of search is:
#
# 1) <file>_<type>_template.ext
# 2) <file>_template.ext
# 3) <file>_<type>.ext
# 4) <file>.ext
my %USFM;
sub defaults {
  my $booknamesHP = shift;
 
  # First get project type and dictionary module.
  my $projType;
  if (-f $CONFFILE) {$projType = &conf('ProjectType');}
  elsif ($MOD =~ /^\w{2,}CB$/) {$projType = 'childrens_bible';}
  else {$projType = 'bible';}
  
  if (!$DICTMOD) {
    &scanUSFM("$MAININPD/sfm", \%USFM);
    if (exists($USFM{'dictionary'})) {
      $DICTMOD = $MAINMOD.'DICT';
      if (! -e "$MAININPD/$DICTMOD") {mkdir "$MAININPD/$DICTMOD";}
    }
  }
  
  # Include either CF_osis2osis.txt or CF_sfm2osis.txt, not both.
  my $skip = 'CF_osis2osis';
  if (-f "$MAININPD/$skip.txt") {$skip = 'CF_sfm2osis';}
  
  my @mods = (''); if ($DICTMOD) {push(@mods, "DICTMOD/");}
  
  foreach my $m (@mods) {
    my $type = ($m eq 'DICTMOD/' ? 'dictionary' : $projType);
    
    foreach my $c (@CF_FILES) {
      my $cf = $c; my $ext = ($cf =~ s/\.([^\.]+)$// ? $1 : '');
           
      # CF_<vsys>.xml is not project-specific, and CF_addDictLinks.xml 
      # defaults are generated when DICTMOD is read. So skip them.
      if ($cf eq 'CF_<vsys>' || 
          $cf eq 'CF_addDictLinks' || 
          $cf eq $skip) {next;}
      
      my $dest = "$MAININPD/".($m ? "$DICTMOD/" : '')."$cf.$ext";
      
      if (-f $dest) {next;}
      
      # Is there a template of the given type?
      my $t = &getDefaultFile($m . $cf . "_$type" . '_template' . ".$ext", -1);
      if (!$t) {
        # Or a generic template without a type?
        $t = &getDefaultFile($m . $cf . '_template' . ".$ext", -1);
      }
      if ($t) {
        if ($m eq "DICTMOD/" && $cf eq 'config.conf') {
          &ErrorBug("Only MAINMOD may have a config.conf file.", 1);
        }
        &copy($t, $dest);
        &Note("Customizing $t as $dest.");
        my $func = "customize_$cf";
        if (defined(&$func)) {
          no strict 'refs';
          &$func($dest, $type, $booknamesHP);
          if ($cf eq 'config') {&readSetCONF();}
        }
        else {&ErrorBug("No customization sub for $t", 1);}
        next;
      }
      
      # Otherwise is there a default file of the given type?
      my $f = &getDefaultFile($m . $cf . '_' . $type . ".$ext", -1);
      # Or a generic default file without a type?
      if (!$f) {$f = &getDefaultFile($m . $cf . ".$ext", -1);}
      if ($f) {
        &Note("Copying $f to $dest.");
        &copy($f, $dest);
        if ($dest =~ /config\.conf$/) {
          # Change config.conf MAINMOD/DICTMOD names and reload
          &customize_config($dest, $type, undef, 1);
          &readSetCONF();
        }
      }
    }
  }
}

sub customize_config {
  my $conFile = shift;
  my $projType = shift;
  my $unused = shift;
  my $nameonly = shift;
 
  my $defConfP = &readProjectConf($conFile);
  $defConfP->{"$MAINMOD+ProjectType"} = $projType;

  # Change MAINMOD/DICTMOD names
  $defConfP->{'MAINMOD'} = $MAINMOD;
  foreach my $fe (keys %{$defConfP}) {
    my $nfe = $fe;
    $nfe =~ s/^DICTMOD\+/$DICTMOD+/;
    $nfe =~ s/^MAINMOD\+/$MAINMOD+/;
    if ($nfe eq $fe) {next;}
    $defConfP->{$nfe} = delete($defConfP->{$fe});
  }
  
  if ($nameonly) {
    &writeConf($CONFFILE, $defConfP, 1);
    &readSetCONF();
    return 
  }

  # If there is any existing $modName conf that is located in a repository 
  # then replace our default config.conf with a stripped-down version of 
  # the repo version and its dict.
  my $haveRepoConf;
  if ($defConfP->{'system+REPOSITORY'} && 
      $defConfP->{'system+REPOSITORY'} =~ /^http/) {
    
    my $mfile = $defConfP->{'system+REPOSITORY'}.'/'.lc($MAINMOD).".conf";
    my $dfile = $defConfP->{'system+REPOSITORY'}.'/'.lc($MAINMOD)."dict.conf";
   
    &Log("\nReading: $mfile\n", 2);
    my $mtext = &shell("wget \"$mfile\" -q -O -", NULL, 1);
    
    &Log("\nReading: $dfile\n", 2);
    my $dtext = &shell("wget \"$dfile\" -q -O -", NULL, 1);

    # strip these entries
    my $strip = &configRE(@SWORD_AUTOGEN_CONFIGS);
    $strip =~ s/\$$//;
    $mtext =~ s/$strip\s*=[^\n]*\n//mg; 
    $dtext =~ s/$strip\s*=[^\n]*\n//mg;
    
    if ($mtext) {
      if (open(CNF, $WRITELAYER, $CONFFILE)) {
        $haveRepoConf++;
        print CNF $mtext;
        close(CNF);
        my $confP = &readConfFile($CONFFILE);
        foreach my $k (keys %{$confP}) {
          if (!&isValidConfig($k)) {next;}
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
          if (!&isValidConfig($k)) {next;}
          my $e = $k; $e =~ s/^[^\+]+\+//;
          # Don't keep these dict entries since MAIN/DICT are now always the same
          if ($e =~ /^(Version|History_.*)$/) {next;}
          if ($defConfP->{"$MAINMOD+$e"} eq $confP->{$k}) {next;}
          $defConfP->{"$DICTMOD+$e"} = $confP->{$k};
        }
        unlink("$CONFFILE.dict");
      }
      else {&ErrorBug("Could not open conf $CONFFILE.dict");}
    }
  }

  # SubPublicationTitle[scope]
  foreach my $scope (@SUB_PUBLICATIONS) {
    my $sp = $scope; $sp =~ s/\s/_/g;
    $defConfP->{"$MAINMOD+SubPublicationTitle[$sp]"} = 
        "Title of Sub-Publication $sp DEF";
  }
  
  # Template constants
  foreach my $fe (keys %{$defConfP}) {
    $defConfP->{$fe} = &const($defConfP->{$fe});
  }
  
  # Add a [system] section which tells convert this is a oc 1.0 project.
  $defConfP->{'system+DEBUG'} = 0;
  
  &writeConf($conFile, $defConfP, 1);
}

sub customize_CF_addScripRefLinks {
  my $conFile = shift;
  my $type = shift;
  my $booknamesHP = shift;
  
  if (-s $conFile) {
    &ErrorBug("This template must be empty.", 1);
  }
  
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
  if (!open(CFT, $WRITELAYER, "$conFile.tmp")) {&ErrorBug("Could not open \"$conFile.tmp\"", 1);}
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
  unlink($conFile);
  move("$conFile.tmp", $conFile);
}

sub readParatextReferenceSettings {

  my @files = split(/\n/, &shell(
      "find \"$MAININPD/sfm\" -type f " .
      "-exec grep -q \"<RangeIndicator>\" {} \\; -print"
    , 3, 1));
    
  my $settingsFilePATH;
  my $settingsFileXML;
  foreach my $file (@files) {
    if ($file && -e $file && -r $file) {
      &Note("Reading Settings.xml file: $file", 1);
      $settingsFilePATH = $file;
      last;
    }
  }
  if ($settingsFilePATH) {
    $settingsFileXML = $XML_PARSER->parse_file($settingsFilePATH);
  }

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
  
  #&Debug("Paratext settings = ".Dumper(\%settings)."\n", 1); 
  
  return \%settings;
}

sub toCFRegex {
  my $aP = shift;
  
  my @sorted = sort { length $a <=> length $b } @{$aP};
  # remove training spaces from segments
  foreach my $s (@sorted) {if ($s =~ s/(\S)\\?\s+$/$1/) {&Note("Removed trailing space from $s");}}
  return '('.join('|', @sorted).')';
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

sub customize_CF_sfm2osis {
  my $conFile = shift;
  my $modType = shift;
  
  if (!%USFM) {&scanUSFM("$MAININPD/sfm", \%USFM);}
  
  if (!open (CFF, $APPENDLAYER, "$conFile")) {
    &ErrorBug("Could not open \"$conFile\"", 1);
  }

  my $lastScope;
  foreach my $f (sort { usfmFileSort($a, $b, $USFM{$modType}) } 
                 keys %{$USFM{$modType}}) {
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
        if (ref($USFM{$modType}{$f}{'periphType'}) && @{$USFM{$modType}{$f}{'periphType'}}) {
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
# CF_sfm2osis.txt code for default placement of that peripheral within 
# the OSIS file. When $periphType is 'sfmfile' (meaning an entire sfm 
# file) it is placed in the proper bookGroup, or at the beginning of the
# first book of $scope, or else after the osis:header.
sub getOsisMap {
  my $periphType = shift; # a key to %USFM_DEFAULT_PERIPH_TARGET defined in fitToVerseSystem.pm
  my $scope = shift;
  
  # default scopePath is after osis header
  my $defScopePath = 'osis:header/following-sibling::node()[1]';
  
  my $scopePath = $defScopePath;
  if ($scope) {
    if ($scope eq 'Matt-Rev') {$scopePath = $USFM_DEFAULT_PERIPH_TARGET{'New Testament Introduction'};}
    elsif ($scope eq 'Gen-Mal') {$scopePath = $USFM_DEFAULT_PERIPH_TARGET{'Old Testament Introduction'};}
    else {
      my $bookAP = &scopeToBooks($scope, &conf("Versification"));
      $scopePath = 'osis:div[@type="book"]['.join(' or ', map("\@osisID=\"$_\"", @{$bookAP})).']/node()[1]';
      foreach my $bk (@{$bookAP}) {
        if (!defined($OSIS_ABBR{$bk})) {
          &Error("USFM file's scope \"$scope\" contains unrecognized book:$bk.", 
"Make sure the sfm sub-directory is named using a proper OSIS 
book scope, such as: 'Ruth_Esth_Jonah' or 'Matt-Rev'");
          $scopePath = $defScopePath;
        }
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
      $info{'type'} = 'childrens_bible';
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

1;
