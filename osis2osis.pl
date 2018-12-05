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

# usage: osis2osis.pl [Bible_Directory]

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";
require("$SCRD/utils/simplecc.pl");

if (&runOsis2osis('postinit', $INPD) eq "$TMPDIR/${MOD}_0.xml") {
  require("$SCRD/scripts/processOSIS.pl");
}
else {&ErrorBug("runOsis2osis failed to write OSIS file.");}

########################################################################
########################################################################


sub runOsis2osis($$) {
  $O2O_CurrentContext = shift;
  my $cfdir = shift;
  if ($O2O_CurrentContext !~ /^(preinit|postinit)$/) {
    &ErrorBug("runOsis2osis context '$O2O_CurrentContext' must be 'preinit' or 'postinit'.");
    return;
  }
  
  &Log("\n-----------------------------------------------------\nSTARTING runOsis2osis context=$O2O_CurrentContext, directory=$cfdir)\n\n");

  my $commandFile = "$cfdir/CF_osis2osis.txt";
  if (! -e $commandFile) {&Error("Cannot proceed without command file: $commandFile.", '', 1);}

  $O2O_CurrentMode = 'MODE_Copy';

  my $newOSIS;
  open(COMF, "<:encoding(UTF-8)", $commandFile) || die "Could not open osis2osis command file $commandFile\n";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^SET_(addScripRefLinks|addFootnoteLinks|addDictLinks|addSeeAlsoLinks|addCrossRefs|reorderGlossaryEntries|customBookOrder|MODE_CCTable|MODE_Script|MODE_Sub|MODE_Copy|sourceProject|sfm2all_\w+|CONFIG_CONVERT_\w+|CONFIG_\w+|CONVERT_\w+|DEBUG|SKIP_NODES_MATCHING|SKIP_STRINGS_MATCHING):(\s*(.*?)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
        &Note("Setting $par to $val");
        if ($par =~ /^(MODE_CCTable|MODE_Script|MODE_Sub|MODE_Copy)$/) {
          $O2O_CurrentMode = $par;
          &Note("Setting conversion mode to $par");
          if ($par ne 'MODE_Copy') {
            if ($$par =~ /^\./) {$$par = File::Spec->rel2abs($$par, $cfdir);}
            if (! -e $$par) {&Error("File does not exist: $$par", "Check the SET_$par command path."); next;}
            if ($par eq 'MODE_Sub') {require($MODE_Sub);}
          }
        }
        elsif ($par eq 'SKIP_STRINGS_MATCHING') {
          $$par = decode('utf8', $$par);
        }
        elsif ($par =~ /^CONFIG_(?!CONVERT)(.*)$/) {$O2O_CONFIGS{$1} = $$par;}
        elsif ($par =~ /^CONVERT_(.*)$/) {$O2O_CONVERTS{$1} = $$par;}
      }
    }
    elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
      my $sp = $1;
      if ($O2O_CurrentContext ne 'preinit') {next;}
      if (!$sourceProject) {&Error("Unable to run CC", "Specify SET_sourceProject in $commandFile"); next;}
      my $spin = $sp; $spin =~ s/(^|\/)[^\/]+DICT\//$1$sourceProjectDICT\//;
      my $ccin = "$sourceProject/$spin";
      if ($sourceProject =~ /^\./) {
        $ccin = File::Spec->rel2abs($ccin, $cfdir);
      }
      else {
        if ($sourceProject =~ /(^|\/)([^\/]+)DICT$/) {
          $ccin = "$MAININPD/../$2/$ccin";
        }
        else {
          $ccin = "$MAININPD/../$ccin";
        }
      }
      my $ccout="$cfdir/$sp";
      if ($ccout =~ /^(.*)\/[^\/]+?$/ && !-e $1) {`mkdir -p $1`;}
      
      &Note("CC processing mode $O2O_CurrentMode, $ccin -> $ccout");
      if (! -e $ccin) {&Error("File does not exist: $ccin", "Check your CC command path and sourceProject."); next;}
      
      if ($O2O_CurrentMode eq 'MODE_Copy') {&copy($ccin, $ccout);}
      elsif ($O2O_CurrentMode eq 'MODE_Script') {&shell("\"$cfdir/$MODE_Script\" \"$ccin\" \"$ccout\"");}
      else {&convertFileStrings($ccin, $ccout);}
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
  
  return $newOSIS;
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
      $attr->setValue($com.&convertStringByMode($value));
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
    foreach my $t (@textNodes) {$t->setData(&convertStringByMode($t->data));}
    &Note("Converted ".@textNodes." text nodes.");
    
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
        my $new = &convertStringByMode($confP->{$e});
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
        my $newValue = &convertStringByMode($value);
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
          my $newv = &convertStringByMode($v);
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
          $part = &convertStringByMode($part);
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
    while(<INF>) {print OUTF &convertStringByMode($_);}
    close(INF);
    close(OUTF);
  }
}

sub convertID($) {
  my $osisref = shift;
  
  my $decoded = &decodeOsisRef($osisref);
  my $converted = &convertStringByMode($decoded);
  my $encoded = &encodeOsisRef($converted);
  
  #print encode("utf8", "$osisref, $decoded, $converted, $encoded\n");
  return $encoded;
}

sub convertStringByMode($) {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'MODE_Sub' && !exists(&convertString)) {
      &Error("<>Function convertString() must be defined when using MODE_Sub.", "
<>In MODE_Sub you must define a Perl function called 
convertString(). Then you must tell osis-converters where to find it
using SET_MODE_Sub:<include-file.pl>");
    return $s;
  }
  
  if ($s =~ /$SKIP_NODES_MATCHING/) {return $s;}
  
  my @subs = split(/($SKIP_STRINGS_MATCHING)/, $s);
  foreach my $sub (@subs) {
    if ($sub =~ /$SKIP_STRINGS_MATCHING/) {next;}
    $sub = &convertStringByMode2($sub);
  }
  return join('', @subs);
}
sub convertStringByMode2($) {
  my $s = shift;
  
  if ($O2O_CurrentMode eq 'MODE_Sub') {
    return &convertString($s);
  }
  elsif ($O2O_CurrentMode eq 'MODE_CCTable')  {
    return &simplecc_convert($s, $MODE_CCTable);
  }
  else {&ErrorBug("Mode $O2O_CurrentMode is not yet supported by convertStringByMode()");}
}

1;
