#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
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

our ($WRITELAYER, $APPENDLAYER, $READLAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($OSIS, @SUB_PUBLICATIONS, $NO_OUTPUT_DELETE, $XPC, $XML_PARSER,
    @OC_LOCALIZABLE_CONFIGS, $OSIS2OSIS_PASS, $O2O_CurrentMode, 
    $O2O_ModeValue, %O2O_CONFIGS, %O2O_CONVERTS);    
   
# Perl symbolic references are always to globals
our ($SkipNodesMatching, $SkipStringsMatching);
    
# Initialized below
our $SourceProject;

sub osis2osis {
  my $commandFile = shift;

  my ($outfile, $sourceProjectPath);
  
  if ($OSIS2OSIS_PASS !~ /^(preinit|postinit)$/) {
    &ErrorBug("'$OSIS2OSIS_PASS' was not 'preinit' or 'postinit'");
    return;
  }
  
  &Log("
-----------------------------------------------------
STARTING osis2osis context=$OSIS2OSIS_PASS, directory=$MAININPD

");

  # This subroutine is run multiple times, for possibly two modules, so settings should never carry over.
  $O2O_CurrentMode = 'copy';
  undef(%O2O_CONFIGS);
  undef(%O2O_CONVERTS);
  
  my $newOSIS;
  open(COMF, $READLAYER, $commandFile) 
      || die "Could not open osis2osis command file $commandFile\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^(Mode\[transcode\]|Mode\[cctable\]|Mode\[script\]|Mode\[copy\]|SourceProject|Config\[.+\]|SkipNodesMatching|SkipStringsMatching):(\s*(.*?)\s*)?$/) {
      no strict "refs";
      if ($2) {
        my $par = $1;
        my $val = $3;
        
        $par =~ s/\[/_/g; $par =~ s/\]//g;
        
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
        &Log("NOTE: Setting $par to $val\n", 1);
        if ($par =~ /^Mode_(cctable|script|transcode|copy)$/) {
          $O2O_CurrentMode = $1;
          $O2O_ModeValue = $$par;
          &Note("Setting conversion mode to $O2O_CurrentMode");
          if ($O2O_CurrentMode ne 'copy') {
            if ($O2O_ModeValue =~ /^\./) {
              $O2O_ModeValue = File::Spec->rel2abs($O2O_ModeValue, $MAININPD);
            }
            if (! -e $O2O_ModeValue) {
              &Error("File does not exist: $O2O_ModeValue", 
                     "Check the Mode[$O2O_CurrentMode] command path.");
              next;
            }
            if ($O2O_CurrentMode eq 'transcode') {require($O2O_ModeValue);}
          }
        }
        elsif ($par =~ /(SkipNodesMatching|SkipStringsMatching)/) {
          $$par =~ s/(?<!\\)\((?!\?)/(?:/g; # Change groups to non-capture!
        }
        elsif ($par =~ /^Config_(.*)$/) {$O2O_CONFIGS{$1} = $$par;}
        elsif ($par eq 'SourceProject') {
          if ($$par =~ /(^|\/)([^\/]+)DICT\/?$/) {
            &Error(
"SourceProject must be name or path to a project main module (not a DICT module).", 
"Remove the letters: 'DICT' from the module name/path in SourceProject of $commandFile.", 1);
          }
          # osis2osis depends on sourceProject OSIS file, and also on 
          # its sfm hierarchy, so copy that
          $sourceProjectPath = $$par;
          if ($sourceProjectPath =~ /^\./) {
            $sourceProjectPath = File::Spec->rel2abs($sourceProjectPath, $MAININPD);
          }
          else {$sourceProjectPath = "$MAININPD/../$$par";}
          if (! -d $sourceProjectPath) {
            &Error(
"sourceProject $sourceProjectPath does not exist.", 
"'SET_sourceProject:$$par' must be the name of, or path to, an existing project (not a DICT).", 1);
          }
          &makeDirs("$sourceProjectPath/sfm", $MAININPD);
          @SUB_PUBLICATIONS = &getSubPublications("$MAININPD/sfm");
        }
        else {
          &Error("Unhandled CF_osis2osis.txt entry: $_");
        }
      }
    }
    elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
      my $ccpath = $1;
      if ($OSIS2OSIS_PASS ne 'preinit') {next;}
      if ($NO_OUTPUT_DELETE) {next;}
      if (!$SourceProject) {&Error(
"Unable to run CC", "Specify SET_sourceProject in $commandFile", 1);
      }
      my $inpath;
      if ($ccpath =~ /^([\.\/\\]+)/) {&Error(
"Paths in CC: instructions cannot start with '$1':$_",  &help('CC', 1), 1);
      }
      $ccpath =~ s/\bDICTMOD\b/${SourceProject}DICT/g;
      foreach my $in (glob "$sourceProjectPath/$ccpath") {
        my $out = $in;
        $out =~ s/\Q$sourceProjectPath\E\//$MAININPD\//;
        my $from = $SourceProject.'DICT'; my $to = $MAINMOD.'DICT';
        $out =~ s/\/$from\//\/$to\//g;
        &Note("CC processing mode $O2O_CurrentMode, $in -> $out");
        if (! -e $in) {&Error(
"File does not exist: $in", 
"Check your CC command path and SourceProject.", 1);
        }
        if ($out =~ /^(.*)\/[^\/]+?$/ && !-e $1) {`mkdir -p $1`;}
        if ($O2O_CurrentMode eq 'copy') {
          &copy($in, $out);
        }
        elsif ($O2O_CurrentMode eq 'script') {
          &shell("\"$O2O_ModeValue\" \"$in\" \"$out\"");
        }
        else {&convertFileStrings($in, $out);}
      }
    }
    elsif ($_ =~ /^CCOSIS:\s*(.*?)\s*$/) {
      my $osis = $1;
      if (!$SourceProject) {
        &Error("Unable to run CCOSIS", 
               "Specify SET_sourceProject in $commandFile", 1);
      }
      my $sourceProject_osis = $SourceProject . 
          ($osis =~ /DICT$/ ? 'DICT':'');
      if ($OSIS2OSIS_PASS ne 'postinit') {next;}
      
      # Since osis2osis is run separately for MAINMOD and DICTMOD,
      # only the current MOD will be run at this time. 
      if ($MOD ne $osis || $NO_OUTPUT_DELETE) {next;}
      
      my $src_osis = &getModuleOsisFile($sourceProject_osis, 'Error');
      
      if (! -e "$TMPDIR/$osis") {&make_path("$TMPDIR/$osis");}
      
      $outfile = "$TMPDIR/$osis/$osis.xml";
      if (-e $outfile) {unlink($outfile);}
      
      &Note("CCOSIS processing mode $O2O_CurrentMode, $src_osis -> $outfile");
      if (! -e $src_osis) {
        &Error("Could not find OSIS file $src_osis", 
        "You may need to specify OUTDIR in the [system] section of 
        config.conf, or create the source project OSIS file(s).", 1);
      }   
      
      if ($O2O_CurrentMode eq 'copy') {
        &copy($src_osis, $outfile);
      }
      elsif ($O2O_CurrentMode eq 'script') {
        &shell("\"$O2O_ModeValue\" \"$src_osis\" \"$outfile\"");
      }
      else  {
        &convertFileStrings($src_osis, $outfile);
      }
    }
    else {
&Error("Unhandled $commandFile line: $_", 
"Fix this line so that it contains a valid command.");
    }
  }
  close(COMF);
  
  $OSIS = $outfile;
  return (-e $outfile);
}

sub makeDirs {
  my $indir = shift;
  my $dest = shift;
  
  my $d = $indir; $d =~ s/\/$//; $d =~ s/^.*\///;
  if (-d $indir && ! -e "$dest/$d") {
    mkdir("$dest/$d");
    &Note("Making empty sfm directory $dest/$d");
  }
  if (opendir(DIR, $indir)) {
    my @subdirs = readdir(DIR);
    closedir(DIR);
    foreach my $subdir (@subdirs) {
      if ($subdir !~ /^\./ && -d "$indir/$subdir") {
        &makeDirs("$indir/$subdir", "$dest/$d");
      }
    }
  }
}

sub convertFileStrings {
  my $ccin = shift;
  my $ccout = shift;
  
  my $fname = $ccin; $fname =~ s/^.*\///;
  
  # OSIS XML
  if ($fname =~ /\.xml/) {
    my $xml = $XML_PARSER->parse_file($ccin);
    
    # Convert milestone n (except initial [command] part)
    my @attributes2Convert = $XPC->findnodes('//osis:milestone/@n', $xml);
    foreach my $n (@attributes2Convert) {
      my $i; my $t = &nTitle($n, \$i);
      $n->setValue($i.&transcodeStringByMode($t));
    }
    &Note("Converted ".@attributes2Convert." milestone n attributes.");
    
    # Convert glossary osisRefs and IDs
    my @a = $XPC->findnodes(
      '//*[@osisRef][contains(@type, "x-gloss")]/@osisRef', $xml);
    my @b = $XPC->findnodes(
      '//osis:seg[@type="keyword"][@osisID]/@osisID', $xml);
    my @glossIDs2Convert; push(@glossIDs2Convert, @a, @b);
    foreach my $id (@glossIDs2Convert) {
      my $idvalue = $id->getValue();
      my $work = ($idvalue =~ s/^([^:]+:)// ? $1:'');
      my $dup = ($idvalue =~ s/(\.dup\d+)$// ? $1:'');
      $id->setValue($work.&convertID($idvalue).$dup);
    }
    &Note("Converted ".@glossIDs2Convert." glossary osisRef values.");
    
    # Convert osisRef, annotateRef and osisID work prefixes
    my $w = $SourceProject;
    my @ids = $XPC->findnodes('//*[
      contains(@osisRef, "'.$w.':") or 
      contains(@osisRef, "'.$w.'DICT:")]', $xml);
    foreach my $id (@ids) {
      my $new = $id->getAttribute('osisRef');
      $new =~ s/^$w((DICT)?:)/$MAINMOD$1/;
      $id->setAttribute('osisRef', $new);
    }
    &Note("Converted ".@ids." osisRef values.");
    
    my @ids = $XPC->findnodes('//*[
      contains(@annotateRef, "'.$w.':") or 
      contains(@annotateRef, "'.$w.'DICT:")]', $xml);
    foreach my $id (@ids) {
      my $new = $id->getAttribute('annotateRef');
      $new =~ s/^$w((DICT)?:)/$MAINMOD$1/;
      $id->setAttribute('annotateRef', $new);
    }
    &Note("Converted ".@ids." annotateRef values.");
    
    my @ids = $XPC->findnodes('//*[
      contains(@osisID, "'.$w.':") or 
      contains(@osisID, "'.$w.'DICT:")]', $xml);
    foreach my $id (@ids) {
      my $new = $id->getAttribute('osisID');
      $new =~ s/^$w((DICT)?:)/$MAINMOD$1/;
      $id->setAttribute('osisID', $new);
    }
    &Note("Converted ".@ids." osisID values.");
    
    # Convert all text nodes after Header (unless skipped)
    my @textNodes = $XPC->findnodes(
      '//osis:header/following::text()', $xml);
    foreach my $t (@textNodes) {
      $t->setData(&transcodeStringByMode($t->data));
    }
    &Note("Converted ".@textNodes." text nodes.");
    
    # Translate src attributes (for images etc.)
    my @srcs = $XPC->findnodes('//@src', $xml);
    foreach my $src (@srcs) {
      $src->setValue(&translateStringByMode($src->getValue()));
    }
    &Note("Translated ".@srcs." src attributes.");
    
    &writeXMLFile($xml, $ccout);
  }
  
  # config.conf
  elsif ($fname eq "config.conf") {
    my $confHP = &readProjectConf($ccin);
    
    # change config.conf keys
    $confHP->{'MAINMOD'} = $MAINMOD;
    foreach my $e (sort keys %{$confHP}) {
      my $new = $e;
      $new =~ s/^$SourceProject((DICT)?)\+/$MAINMOD$1\+/;
      $confHP->{$new} = delete($confHP->{$e});
    }
    
    # replace module names in config values (except AudioCode)
    foreach my $e (sort keys %{$confHP}) {
      if ($e =~ /\+AudioCode/) {next;}
      my $new = $confHP->{$e};
      my $lcSourceProject = lc($SourceProject);
      my $m1 = $new =~ s/\b$lcSourceProject((dict)?)\b/my $r = lc($MAINMOD).$1;/eg;
      my $m2 = $new =~ s/\b$SourceProject((DICT)?)\b/$MAINMOD$1/g;
      if ($m1 || $m2) {
        &Note("Modifying entry $e\n\t\twas: ".$confHP->{$e}."\n\t\tis:  ".$new);
        $confHP->{$e} = $new;
      }
    }
    
    # convert localized entry values
    my @c = ('MATCHES:.*Title.*', 'Abbreviation', 'About', 'Description');
    my $l = &conf('Lang'); $l =~ s/\-.*$//;
    if ($l) {push(@c, "MATCHES:.*_$l");}
    my $locRE = &configRE(@c);
    foreach my $fe (sort keys %{$confHP}) {
      my $e = $fe;
      my $s = ($e =~ s/^([^\+]+)\+// ? $1 : '');
      if ($e !~ /$locRE/) {next;}
      $confHP->{$fe} = 
          &transcodeStringByMode($confHP->{$fe});
      &Note("Converting entry $e to: ".$confHP->{$fe});
    }
    
    # set requested values
    foreach my $e (sort keys %O2O_CONFIGS) {
      my $fullEntry = $e;
      if ($fullEntry !~ /\+/) {$fullEntry = "$MAINMOD+$e";}
      $confHP->{$fullEntry} = $O2O_CONFIGS{$e};
      &Note("Setting entry $e to: ".$confHP->{$fullEntry});
    }
    
    # write new config.conf file
    &writeConf($ccout, $confHP, 1);

    # IMPORTANT: At one time the config.conf file was re-read at this 
    # point, and progress continued. However, global variables are not 
    # re-loaded this way (and cannot be with Vagrant). Therefore, 
    # progress is instead halted after preinit, and the script is 
    # restarted to reload globals.
  }
  
  # USFM files
  elsif ($fname =~ /\.sfm$/) {
    if (!open(INF,  $READLAYER, $ccin)) {
      &Error("Could not open SFM input $ccin");
      return;
    }
    if (!open(OUTF, $WRITELAYER, $ccout)) {
      &Error("Could not open SFM output $ccout");
      return;
    }
    while(<INF>) {
      if ($_ !~ /^\\id/) {
        my @parts = split(/(\\[\w\d]+)/, $_);
        foreach my $part (@parts) {
          if ($part =~ /^(\\[\w\d]+)$/) {next;}
          $part = &transcodeStringByMode($part);
        }
        $_ = join(//, @parts);
      }
      print OUTF $_;
    }
    close(INF);
    close(OUTF);
  }
  
  # other
  else {
    &Warn("Converting unknown file type $fname.", 
          "All text in the file will be converted.");
    if (!open(INF,  $READLAYER, $ccin)) {
      &Error("Could not open input $ccin");
      return;
    }
    if (!open(OUTF, $WRITELAYER, $ccout)) {
      &Error("Could not open output $ccout");
      return;
    }
    while(<INF>) {print OUTF &transcodeStringByMode($_);}
    close(INF);
    close(OUTF);
  }
}

sub convertID {
  my $osisref = shift;
  
  my $decoded = &decodeOsisRef($osisref);
  my $converted = &transcodeStringByMode($decoded);
  my $encoded = &encodeOsisRef($converted);
  
  #print encode("utf8", "$osisref, $decoded, $converted, $encoded\n");
  return $encoded;
}

sub translateStringByMode {
  my $s = shift;
  
  if (exists(&translate)) {return &translate($s);}
  elsif ($O2O_CurrentMode eq 'transcode') {
      &Warn(
"<>Function translate() is usally defined when using MODE_Transcode, but it is not.", "
<>In MODE_Transcode you can define a Perl function called 
translate() which will translate src attributes and other metadata. To 
use it, you must tell osis-converters where to find it by using 
SET_MODE_Transcode:<include-file.pl>");
    return $s;
  }
  elsif ($O2O_CurrentMode eq 'cctable') {return &transcodeStringByMode($s);}
  else {&ErrorBug("Mode $O2O_CurrentMode is not supported.");}
}

sub transcodeStringByMode {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'transcode' && !exists(&transcode)) {
      &Error(
"<>Function transcode() must be defined when using MODE_Transcode.", "
<>" . &help('sfm2osis;CF_osis2osis.txt;MODE_Transcode'));
    return $s;
  }
  
  if ($SkipNodesMatching && $s =~ /$SkipNodesMatching/) {
    &Note("Skipping node: $s");
    return $s;
  }
  
  if (!$SkipStringsMatching) {return &transcodeStringByMode2($s);}
  
  my @subs = split(/($SkipStringsMatching)/, $s);
  foreach my $sub (@subs) {
    if ($sub =~ /$SkipStringsMatching/) {
      &Note("Skipping string: $sub");
      next;
    }
    $sub = &transcodeStringByMode2($sub);
  }
  return join('', @subs);
}
sub transcodeStringByMode2 {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'transcode') {
    return &transcode($s);
  }
  elsif ($O2O_CurrentMode eq 'cctable')  {
    require("$SCRD/utils/simplecc.pl");
    return &simplecc_convert($s, $O2O_ModeValue);
  }
  else {&ErrorBug("Mode $O2O_CurrentMode is not yet supported.");}
}

1;

