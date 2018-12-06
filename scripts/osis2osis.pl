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
  $O2O_CurrentContext = shift;
  my $cfdir = shift;
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
  open(COMF, "<:encoding(UTF-8)", $commandFile) || die "Could not open osis2osis command file $commandFile\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^SET_(addScripRefLinks|addFootnoteLinks|addDictLinks|addSeeAlsoLinks|addCrossRefs|reorderGlossaryEntries|customBookOrder|MODE_Transcode|MODE_CCTable|MODE_Script|MODE_Copy|sourceProject|sfm2all_\w+|CONFIG_CONVERT_\w+|CONFIG_\w+|CONVERT_\w+|DEBUG|SKIP_NODES_MATCHING|SKIP_STRINGS_MATCHING):(\s*(.*?)\s*)?$/) {
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
          # osis2osis depends on sourceProject OSIS file, and also on it's sfm hierarchy, so copy that
          $sourceProjectPath = $$par;
          if ($sourceProjectPath =~ /^\./) {
            $sourceProjectPath = File::Spec->rel2abs($sourceProjectPath, $cfdir);
          }
          else {
            if ($$par =~ /(^|\/)([^\/]+)DICT\/?$/) {
              $sourceProjectPath = "$MAININPD/../$2/$$par";
            }
            else {
              $sourceProjectPath = "$MAININPD/../$$par";
            }
          }
          if (! -d $sourceProjectPath) {
            &Error("sourceProject $sourceProjectPath does not exist.", "'SET_sourceProject:$$par' must be the name of, or path to, an existing project.", 1);
          }
          if ($sourceProjectPath !~ /DICT$/) {&makeDirs("$sourceProjectPath/sfm", $INPD);}
        }
      }
    }
    elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
      my $ccpath = $1;
      if ($O2O_CurrentContext ne 'preinit') {next;}
      if (!$sourceProject) {&Error("Unable to run CC", "Specify SET_sourceProject in $commandFile"); next;}
      my $inpath = $ccpath; $inpath =~ s/^(\.\/)[^\/]+DICT\//$1${sourceProject}DICT\//; # special case of CCing a DICT file from the MAIN CC_osis2osis.txt file
      
      foreach my $in (glob "$sourceProjectPath/$inpath") {
        my $out = $in; $out =~ s/\Q$sourceProjectPath\E\//$cfdir\//; $out =~ s/^\/${sourceProject}DICT\//\/$DICTMOD\//;
        &Note("CC processing mode $O2O_CurrentMode, $in -> $out");
        if (! -e $in) {&Error("File does not exist: $in", "Check your CC command path and sourceProject."); next;}
        if ($out =~ /^(.*)\/[^\/]+?$/ && !-e $1) {`mkdir -p $1`;}
        if ($O2O_CurrentMode eq 'MODE_Copy') {&copy($in, $out);}
        elsif ($O2O_CurrentMode eq 'MODE_Script') {&shell("\"$cfdir/$MODE_Script\" \"$in\" \"$out\"");}
        else {&convertFileStrings($in, $out);}
      }
    }
    elsif ($_ =~ /^CCOSIS:\s*(.*?)\s*$/) {
      my $osis = $1;
      if ($O2O_CurrentContext ne 'postinit') {next;}
      if (!$sourceProject) {&Error("Unable to run CCOSIS", "Specify SET_sourceProject in $commandFile"); next;}
      if ($osis =~ /sourceProject/i) {$osis = $sourceProject;}
      if ($osis =~ /\.xml$/i) {
        if ($osis =~ /^\./) {$osis = File::Spec->rel2abs($osis, $cfdir);}
      }
      else {
        if ($OUTDIR eq "$INPD/output") {
          if ($sourceProject =~ /(^|\/)([^\/]+)DICT$/) {
            $osis = "$MAININPD/../$2/$osis/output/$osis.xml";
          }
          else {
            $osis = "$MAININPD/../$osis/output/$osis.xml";
          }
        }
        else {$osis = "$OUTDIR/../$osis/$osis.xml";}
      }
      
      $newOSIS = "$TMPDIR/${MOD}_0.xml";
      &Note("CCOSIS processing mode $O2O_CurrentMode, $osis -> $newOSIS");
      if (! -e $osis) {&Error("Could not find OSIS file $osis", "You may need to specify OUTDIR in paths.pl."); next;}
      
      if ($O2O_CurrentMode eq 'MODE_Copy') {&copy($osis, $newOSIS);}
      elsif ($O2O_CurrentMode eq 'MODE_Script') {&shell("\"$cfdir/$MODE_Script\" \"$osis\" \"$newOSIS\"");}
      else {&convertFileStrings($osis, $newOSIS);}
    }
    else {&Error("Unhandled $commandFile line: $_", "Fix this line so that it contains a valid command.");}
  }
  close(COMF);
  foreach my $par (@wipeGlobals) {$$par = '';}
  
  return $newOSIS;
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
    # By default, only entries (Abbreviation|About|Description|CopyrightHolder_<lang-base>) are converted.
    # CONFIG_<entry> will replace an entry with a new value.
    # CONFIG_CONVERT_<entry> will convert that entry.
    # All other entries are not converted, but WILL have module names in their values updated: OLD -> NEW
    my $confP = &readConf($ccin);
    my $langBase = $confP->{'Lang'}; $langBase =~ s/\-.*$//;
    foreach my $e (keys %{$confP}) {
      my $new = $confP->{$e};
      my $mainsp = $sourceProject; $mainsp =~ s/DICT$//;
      my $lcmsp = lc($mainsp);
      if ($new =~ s/($lcmsp)(dict)?/my $r = lc($MAINMOD).$2;/eg || $new =~ s/($mainsp)(DICT)?/$MAINMOD$2/g) {
        &Note("Modifying entry $e\n\t\twas: ".$confP->{$e}."\n\t\tis:  ".$new);
        $confP->{$e} = $new;
      }
    }
    foreach my $e (keys %{$confP}) {
      if (($e =~ /^(Abbreviation|About|Description|CopyrightHolder_$langBase)/ || ${"CONFIG_CONVERT_$e"})) {
        my $new = &transcodeStringByMode($confP->{$e});
        &Note("Converting entry $e\n\t\twas: ".$confP->{$e}."\n\t\tis:  ".$new);
        $confP->{$e} = $new;
      }
    }
    foreach my $e (keys %O2O_CONFIGS) {
      &Note("Setting entry $e to: ".$O2O_CONFIGS{$e});
      $confP->{$e} = $O2O_CONFIGS{$e};
    }
    &writeConf($ccout, $confP);
    &setConfGlobals(&updateConfData(&readConf($ccout)));
  }
  
  # collections.txt
  elsif ($fname eq "collections.txt") {
    my $newMod = lc($MOD);
    if (!open(INF, "<:encoding(UTF-8)", $ccin)) {&Error("Could not open collections.txt input $ccin"); return;}
    if (!open(OUTF, ">:encoding(UTF-8)", $ccout)) {&Error("Could not open collections.txt output $ccout"); return;}
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
  
  # convert.txt
  elsif ($fname eq "convert.txt") {
    if (!open(INF, "<:encoding(UTF-8)", $ccin)) {&Error("Could not open convert.txt input $ccin"); return;}
    if (!open(OUTF, ">:encoding(UTF-8)", $ccout)) {&Error("Could not open convert.txt output $ccout"); return;}
    while(<INF>) {
      if ($_ =~ /^([\w\d]+)\s*=\s*(.*?)\s*$/) {
        my $e=$1; my $v=$2;
        if ($e =~ /^(Title|TitleFullPublication\d+)$/) {
          my $newv = &transcodeStringByMode($v);
          $_ = "$e=$newv\n";
          &Note("Converted entry $e\n\t\twas: $v\n\t\tis:  $newv");
        }
        if (${"CONVERT_$e"}) {
          $_ = "$e=".${"CONVERT_$e"}."\n";
          $O2O_CONVERTS{$e} = '';
          &Note("Converted entry $e\n\t\twas: $v\n\t\tis:  ".${"CONVERT_$e"});
        }
      }
      print OUTF $_;
    }
    foreach my $e (keys %O2O_CONVERTS) {
      if (!$e) {next;}
      print OUTF "$e=".$O2O_CONVERTS{$e}."\n";
      &Note("Setting entry $e to: ".$O2O_CONVERTS{$e});
    }
    close(INF);
    close(OUTF);
  }
  
  # USFM files
  elsif ($fname =~ /\.sfm$/) {
    if (!open(INF,  "<:encoding(UTF-8)", $ccin)) {&Error("Could not open SFM input $ccin"); return;}
    if (!open(OUTF, ">:encoding(UTF-8)", $ccout)) {&Error("Could not open SFM output $ccout"); return;}
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
    if (!open(INF,  "<:encoding(UTF-8)", $ccin)) {&Error("Could not open input $ccin"); return;}
    if (!open(OUTF, ">:encoding(UTF-8)", $ccout)) {&Error("Could not open output $ccout"); return;}
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
    return &simplecc_convert($s, $MODE_CCTable);
  }
  else {&ErrorBug("Mode $O2O_CurrentMode is not yet supported by transcodeStringByMode()");}
}

1;
