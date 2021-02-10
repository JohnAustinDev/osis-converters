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

our ($APPENDLAYER, $CONFFILE, $DICTINPD, $INPD, $MAININPD, $MAINMOD,
    $READLAYER, $WRITELAYER, %CONFIG_DEFAULTS, %ID_TYPE_MAP, %OSIS_ABBR,
    %OSIS_GROUP, %PERIPH_SUBTYPE_MAP, %PERIPH_TYPE_MAP, 
    %USFM_DEFAULT_PERIPH_TARGET, @OC_CONFIGS, @OSIS_GROUPS, 
    @SUB_PUBLICATIONS, @SWORD_AUTOGEN_CONFIGS);

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
  
  &readSetCONF();
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
# CF_usfm2osis.txt code for default placement of that peripheral within 
# the OSIS file. When $periphType is 'sfmfile' (meaning an entire sfm 
# file) it is placed in the proper bookGroup, or at the beginning of the
# first book of $scope, or else after the osis:header.
sub getOsisMap {
  my $periphType = shift; # a key to %USFM_DEFAULT_PERIPH_TARGET defined in fitToVerseSystem.pl
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

########################################################################
# These functions are only needed to update old osis-converters projects

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

1;
