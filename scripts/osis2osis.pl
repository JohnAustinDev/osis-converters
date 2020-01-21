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

# usage: osis2osis.pl [Bible_Directory]

sub runOsis2osis($$) {
  $O2O_CurrentContext = shift; # During 'preinit', CC commands are run. During 'postinit', CCOSIS command(s) run. 
  my $cfdir = shift;

  my @outmods = ();
  
  if ($O2O_CurrentContext !~ /^(preinit|postinit)$/) {
    &ErrorBug("runOsis2osis context '$O2O_CurrentContext' must be 'preinit' or 'postinit'.");
    return;
  }
  
  &Log("\n-----------------------------------------------------\nSTARTING runOsis2osis context=$O2O_CurrentContext, directory=$cfdir\n\n");

  my $commandFile = "$cfdir/CF_osis2osis.txt";
  if (! -e $commandFile) {&Error("Cannot proceed without command file: $commandFile.", '', 1);}

  # This subroutine is run multiple times, for possibly two modules, so settings should never carry over.
  my @wipeGlobals = ('sourceProjectPath');
  $O2O_CurrentMode = 'MODE_Copy';
  undef(%O2O_CONFIGS);
  undef(%O2O_CONVERTS);
  
  my $newOSIS;
  open(COMF, "<$READLAYER", $commandFile) || die "Could not open osis2osis command file $commandFile\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^SET_(addScripRefLinks|addFootnoteLinks|addDictLinks|addSeeAlsoLinks|addCrossRefs|reorderGlossaryEntries|customBookOrder|MODE_Transcode|MODE_CCTable|MODE_Script|MODE_Copy|sourceProject|sfm2all_\w+|CONFIG_CONVERT_[\w\+]+|CONFIG_[\w\+]+|CONVERT_\w+|DEBUG|SKIP_NODES_MATCHING|SKIP_STRINGS_MATCHING):(\s*(.*?)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        
        # be sure to wipe subroutine specific globals after we're done, so they don't carry over to next call
        if ($par !~ /(sfm2all_\w+|DEBUG|addScripRefLinks|addFootnoteLinks|addDictLinks|addSeeAlsoLinks|addCrossRefs|reorderGlossaryEntries|customBookOrder)/) {
          push(@wipeGlobals, $par);
        }
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
        &Note("Setting $par to $val");
        if ($par =~ /^(MODE_CCTable|MODE_Script|MODE_Transcode|MODE_Copy)$/) {
          $O2O_CurrentMode = $par;
          &Note("Setting conversion mode to $par");
          if ($par ne 'MODE_Copy') {
            if ($$par =~ /^\./) {$$par = File::Spec->rel2abs($$par, $cfdir);}
            if (! -e $$par) {&Error("File does not exist: $$par", "Check the SET_$par command path."); next;}
            if ($par eq 'MODE_Transcode') {require($MODE_Transcode);}
          }
        }
        elsif ($par =~ /(SKIP_NODES_MATCHING|SKIP_STRINGS_MATCHING)/) {
          $$par =~ s/(?<!\\)\((?!\?)/(?:/g; # Change groups to non-capture!
        }
        elsif ($par =~ /^CONFIG_(?!CONVERT)(.*)$/) {$O2O_CONFIGS{$1} = $$par;}
        elsif ($par =~ /^CONVERT_(.*)$/) {$O2O_CONVERTS{$1} = $$par;}
        elsif ($par eq 'sourceProject') {
          if ($$par =~ /(^|\/)([^\/]+)DICT\/?$/) {
            &Error("SET_sourceProject must be name or path to a project main module (not a DICT module).", "Remove the letters: 'DICT' from the module name/path in SET_sourceProject of $commandFile.", 1);
          }
          # osis2osis depends on sourceProject OSIS file, and also on it's sfm hierarchy, so copy that
          $sourceProjectPath = $$par;
          if ($sourceProjectPath =~ /^\./) {$sourceProjectPath = File::Spec->rel2abs($sourceProjectPath, $cfdir);}
          else {$sourceProjectPath = "$MAININPD/../$$par";}
          if (! -d $sourceProjectPath) {
            &Error("sourceProject $sourceProjectPath does not exist.", "'SET_sourceProject:$$par' must be the name of, or path to, an existing project (not a DICT).", 1);
          }
          &makeDirs("$sourceProjectPath/sfm", $MAININPD);
        }
      }
    }
    elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
      my $ccpath = $1;
      if ($O2O_CurrentContext ne 'preinit') {next;}
      if ($NO_OUTPUT_DELETE) {next;}
      if (!$sourceProject) {&Error("Unable to run CC", "Specify SET_sourceProject in $commandFile", 1);}
      my $inpath;
      if ($ccpath =~ /^\./) {&Error("Paths in CC: instructions cannot start with '.':$_", "The path is intended for use by getDefaultFile() of sourceProject.", 1);}
      my $glob = ($ccpath =~ s/^(.*?)(\/[^\/]*\*[^\/]*)$/$1/ ? $2:'');
      $inpath = &getDefaultFile($ccpath, 0, $sourceProjectPath);
      foreach my $in (glob $inpath.$glob) {
        my $out = $in;
        $out =~ s/\Q$sourceProjectPath\E\//$cfdir\//;
        my $from = $sourceProject.'DICT'; my $to = $MAINMOD.'DICT';
        $out =~ s/\/$from\//\/$to\//g;
        &Note("CC processing mode $O2O_CurrentMode, $in -> $out");
        if (! -e $in) {&Error("File does not exist: $in", "Check your CC command path and sourceProject.", 1);}
        if ($out =~ /^(.*)\/[^\/]+?$/ && !-e $1) {`mkdir -p $1`;}
        if ($O2O_CurrentMode eq 'MODE_Copy') {&copy($in, $out);}
        elsif ($O2O_CurrentMode eq 'MODE_Script') {&shell("\"$MODE_Script\" \"$in\" \"$out\"");}
        else {&convertFileStrings($in, $out);}
      }
    }
    elsif ($_ =~ /^CCOSIS:\s*(.*?)\s*$/) {
      my $osis = $1;
      if ($O2O_CurrentContext ne 'postinit') {next;}
      if (!$sourceProject) {&Error("Unable to run CCOSIS", "Specify SET_sourceProject in $commandFile", 1);}
      if ($osis =~ /sourceProject/i) {$osis = $sourceProject;}
      if ($osis =~ /\.xml$/i) {
        if ($osis =~ /^\./) {$osis = File::Spec->rel2abs($osis, $cfdir);}
      }
      else {$osis = &getModuleOsisFile($osis, 'Error');}
      
      my $outmod = $MAINMOD.($osis =~ /DICT\.xml$/ ? 'DICT':'');
      if (! -e "$TMPDIR/$outmod") {&make_path("$TMPDIR/$outmod");}
      my $outfile = "$TMPDIR/$outmod/$outmod.xml";
      if ($NO_OUTPUT_DELETE) {push(@outmods, $outmod); next;}
      
      &Note("CCOSIS processing mode $O2O_CurrentMode, $osis -> $oufile");
      if (! -e $osis) {&Error("Could not find OSIS file $osis", "You may need to specify OUTDIR in the [system] section of config.conf, or create the source project OSIS file(s).", 1);}   
      if ($O2O_CurrentMode eq 'MODE_Copy') {&copy($osis, $outfile);}
      elsif ($O2O_CurrentMode eq 'MODE_Script') {&shell("\"$MODE_Script\" \"$osis\" \"$outfile\"");}
      else {&convertFileStrings($osis, $outfile);}
      push(@outmods, $outmod);
    }
    else {&Error("Unhandled $commandFile line: $_", "Fix this line so that it contains a valid command.");}
  }
  close(COMF);
  foreach my $par (@wipeGlobals) {$$par = '';}
  
  return @outmods;
}

sub makeDirs($$) {
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

sub convertFileStrings($$) {
  my $ccin = shift;
  my $ccout = shift;
  
  my $fname = $ccin; $fname =~ s/^.*\///;
  
  # OSIS XML
  if ($fname =~ /\.xml/) {
    my $xml = $XML_PARSER->parse_file($ccin);
    
    # Convert milestone n (except initial [command] part)
    my @attributes2Convert = $XPC->findnodes('//osis:milestone/@n', $xml);
    foreach my $attr (@attributes2Convert) {
      my $value = $attr->getValue();
      my $com = ($value =~ s/^((\[[^\]]*\])+)// ? $1:'');
      $attr->setValue($com.&transcodeStringByMode($value));
    }
    &Note("Converted ".@attributes2Convert." milestone n attributes.");
    
    # Convert glossary osisRefs and IDs
    my @a = $XPC->findnodes('//*[@osisRef][contains(@type, "x-gloss")]/@osisRef', $xml);
    my @b = $XPC->findnodes('//osis:seg[@type="keyword"][@osisID]/@osisID', $xml);
    my @glossIDs2Convert; push(@glossIDs2Convert, @a, @b);
    foreach my $id (@glossIDs2Convert) {
      my $idvalue = $id->getValue();
      my $work = ($idvalue =~ s/^([^:]+:)// ? $1:'');
      my $dup = ($idvalue =~ s/(\.dup\d+)$// ? $1:'');
      $id->setValue($work.&convertID($idvalue).$dup);
    }
    &Note("Converted ".@glossIDs2Convert." glossary osisRef values.");
    
    # Convert osisRef and ID work prefixes
    my $w = $sourceProject; $w =~ s/DICT$//;
    my @ids = $XPC->findnodes('//*[contains(@osisRef, "'.$w.':") or contains(@osisRef, "'.$w.'DICT:")]', $xml);
    foreach my $id (@ids) {my $new = $id->getAttribute('osisRef'); $new =~ s/^$w((DICT)?:)/$MAINMOD$1/; $id->setAttribute('osisRef', $new);}
    my @ids = $XPC->findnodes('//*[contains(@osisID, "'.$w.':") or contains(@osisID, "'.$w.'DICT:")]', $xml);
    foreach my $id (@ids) {my $new = $id->getAttribute('osisID'); $new =~ s/^$w((DICT)?:)/$MAINMOD$1/; $id->setAttribute('osisID', $new);}
    
    # Convert all text nodes after Header (unless skipped)
    my @textNodes = $XPC->findnodes('/osis:osis/osis:osisText/osis:header/following::text()', $xml);
    foreach my $t (@textNodes) {$t->setData(&transcodeStringByMode($t->data));}
    &Note("Converted ".@textNodes." text nodes.");
    
    # Translate src attributes (for images etc.)
    my @srcs = $XPC->findnodes('//@src', $xml);
    foreach my $src (@srcs) {$src->setValue(&translateStringByMode($src->getValue()));}
    &Note("Translated ".@srcs." src attributes.");
    
    &writeXMLFile($xml, $ccout);
  }
  
  # config.conf
  elsif ($fname eq "config.conf") {
    # Entries in @OC_LOCALIZABLE_CONFIGS are converted.
    # CONFIG_<entry> will replace an entry with a new value.
    # CONFIG_CONVERT_<entry> will convert that entry.
    # All other entries are not converted, but WILL have module names in their values updated: OLD -> NEW (except AudioCode!)
    my %confH; &readConfFile($ccin, \%confH);
    my $origMainmod = $confH{'ModuleName'};
    
    # replace module names in all config keys
    foreach my $e (sort keys %confH) {
      my $e2 = $e; if ($e2 !~ s/^${origMainmod}DICT\+/${MAINMOD}DICT\+/) {next;}
      $confH{$e2} = delete $confH{$e};
    }
    
    # replace module names in all config values
    foreach my $e (sort keys %confH) {
      if ($e eq 'AudioCode') {next;}
      my $new = $confH{$e};
      my $mainsp = $sourceProject; $mainsp =~ s/DICT$//;
      my $lcmsp = lc($mainsp);
      my $m1 = $new =~ s/($lcmsp)(dict)?/my $r = lc($MAINMOD).$2;/eg;
      my $m2 = $new =~ s/($mainsp)(DICT)?/$MAINMOD$2/g;
      if ($m1 || $m2) {
        &Note("Modifying entry $e\n\t\twas: ".$confH{$e}."\n\t\tis:  ".$new);
        $confH{$e} = $new;
      }
    }
    
    # convert appropriate entry values
    my @regexs; push(@regexs, @OC_LOCALIZABLE_CONFIGS); foreach my $regex (@regexs) {$regex =~ s/^MATCHES\://;}
    foreach my $e (sort keys %confH) {
      if (${"CONVERT_$e"}) {&Error("The setting SET_CONVERT_$e is no longer supported.", "Change it to SET_CONFIG_$e instead.");}
      my $doConvert = (${"CONFIG_CONVERT_$e"} ? 1:0); # -1 means don't, 0 means keep checking but don't, 1 means do
      if (!$doConvert) {foreach my $regex (@regexs) {if ($e =~ /$regex/) {$doConvert = 1;}}}
      if ($doConvert) {
        my $new = &transcodeStringByMode($confH{$e});
        &Note("Converting entry $e\n\t\twas: ".$confH{$e}."\n\t\tis:  ".$new);
        $confH{$e} = $new;
      }
    }
    
    # set requested values
    foreach my $e (sort keys %O2O_CONFIGS) {
      &Note("Setting entry $e to: ".$O2O_CONFIGS{$e});
      $confH{$e} = $O2O_CONFIGS{$e};
    }
    
    # apply new conf entries/values
    &writeConf($ccout, \%confH);
    
    # re-read project config.conf (which is probably $cout)
    &readSetCONF();
    
  }
  
  # collections.txt
  elsif ($fname eq "collections.txt") {
    my $newMod = lc($MOD);
    if (!open(INF, "<$READLAYER", $ccin)) {&Error("Could not open collections.txt input $ccin"); return;}
    if (!open(OUTF, ">$WRITELAYER", $ccout)) {&Error("Could not open collections.txt output $ccout"); return;}
    my %col;
    while(<INF>) {
      if ($_ =~ s/^(Collection\:\s*)(\Q$sourceProject\E)(.*)$/$1$newMod$3/i) {$col{"$2$3"} = "$newMod$3";}
      elsif ($_ =~ /^(Info|Application-Name)\s*(:.*$)/) {
        my $entry = $1; my $value = $2;
        my $newValue = &transcodeStringByMode($value);
        $_ = "$entry$newValue\n";
        &Note("Converted entry $entry\n\t\twas: $value\n\t\tis:  $newValue");
      }
      print OUTF $_;
    }
    close(INF);
    close(OUTF);
    if (!%col) {&Error("Did not update Collection names in collections.txt");}
    else {foreach my $c (sort keys %col) {&Note("Updated Collection $c to ".$col{$c});}}
  }
  
  # USFM files
  elsif ($fname =~ /\.sfm$/) {
    if (!open(INF,  "<$READLAYER", $ccin)) {&Error("Could not open SFM input $ccin"); return;}
    if (!open(OUTF, ">$WRITELAYER", $ccout)) {&Error("Could not open SFM output $ccout"); return;}
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
    &Warn("Converting unknown file type $fname.", "All text in the file will be converted.");
    if (!open(INF,  "<$READLAYER", $ccin)) {&Error("Could not open input $ccin"); return;}
    if (!open(OUTF, ">$WRITELAYER", $ccout)) {&Error("Could not open output $ccout"); return;}
    while(<INF>) {print OUTF &transcodeStringByMode($_);}
    close(INF);
    close(OUTF);
  }
}

sub convertID($) {
  my $osisref = shift;
  
  my $decoded = &decodeOsisRef($osisref);
  my $converted = &transcodeStringByMode($decoded);
  my $encoded = &encodeOsisRef($converted);
  
  #print encode("utf8", "$osisref, $decoded, $converted, $encoded\n");
  return $encoded;
}

sub translateStringByMode($) {
  my $s = shift;
  
  if (exists(&translate)) {return &translate($s);}
  elsif ($O2O_CurrentMode eq 'MODE_Transcode') {
      &Warn("<>Function translate() is usally defined when using MODE_Transcode, but it is not.", "
<>In MODE_Transcode you can define a Perl function called 
translate() which will translate src attributes and other metadata. To 
use it, you must tell osis-converters where to find it by using 
SET_MODE_Transcode:<include-file.pl>");
    return $s;
  }
  elsif ($O2O_CurrentMode eq 'MODE_CCTable') {return &transcodeStringByMode($s);}
  else {&ErrorBug("Mode $O2O_CurrentMode is not yet supported by translateStringByMode()");}
}

sub transcodeStringByMode($) {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'MODE_Transcode' && !exists(&transcode)) {
      &Error("<>Function transcode() must be defined when using MODE_Transcode.", "
<>In MODE_Transcode you must define a Perl function called 
transcode(). Then you must tell osis-converters where to find it
using SET_MODE_Transcode:<include-file.pl>");
    return $s;
  }
  
  if ($SKIP_NODES_MATCHING && $s =~ /$SKIP_NODES_MATCHING/) {
    &Note("Skipping node: $s");
    return $s;
  }
  
  if (!$SKIP_STRINGS_MATCHING) {return &transcodeStringByMode2($s);}
  
  my @subs = split(/($SKIP_STRINGS_MATCHING)/, $s);
  foreach my $sub (@subs) {
    if ($sub =~ /$SKIP_STRINGS_MATCHING/) {
      &Note("Skipping string: $sub");
      next;
    }
    $sub = &transcodeStringByMode2($sub);
  }
  return join('', @subs);
}
sub transcodeStringByMode2($) {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'MODE_Transcode') {
    return &transcode($s);
  }
  elsif ($O2O_CurrentMode eq 'MODE_CCTable')  {
    require("$SCRD/utils/simplecc.pl");
    return &simplecc_convert($s, $MODE_CCTable);
  }
  else {&ErrorBug("Mode $O2O_CurrentMode is not yet supported by transcodeStringByMode()");}
}

1;
