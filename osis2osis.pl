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

# Run this script to create an OSIS file from a source OSIS file. 
# There are three possible steps in the process:
# 1) parse and add Scripture reference links to introductions, 
# titles, and footnotes. 2) parse and add dictionary links to words 
# which are described in a separate dictionary module. 3) insert cross 
# reference links into the OSIS file.
#
# Begin by updating the config.conf and CF_osis2osis.txt command 
# file located in the Bible_Directory (see those files for more info). 
# Then check the log file: Bible_Directory/OUT_osis2osis.txt.
 
# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/perl/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/perl/common.pl"; &init();

require("$SCRD/scripts/perl/simplecc.pl");

my $osis_in = "";
my $CCIN;
my $CCOUT;

$COMMANDFILE = "$INPD/CF_osis2osis.txt";
if (! -e $COMMANDFILE) {die "ERROR: Cannot proceed without command file: $COMMANDFILE.";}

open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open osis2osis command file $COMMANDFILE\n";
while (<COMF>) {
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^SET_(addScripRefLinks|addFootnoteLinks|addDictLinks|addCrossRefs|CCTable|CCScript|sourceProject|sfm2all_\w+|CONFIG_\w+|CONFIGCONVERT_\w+|CONFIGdontCONVERT_\w+|CONVERT_\w+|DEBUG):(\s*(.*?)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
      &Log("INFO: Setting $par to $val\n");
    }
  }
  elsif ($_ =~ /^CC:\s*(.*?)\s*$/) {
    my $sp = $1;
    $CCIN = ($sourceProject =~ /^\./ ? "$sourceProject/$sp":"../$sourceProject/$sp");
    $CCIN = File::Spec->rel2abs($CCIN, $INPD);
    $CCOUT="./$sp";
    $CCOUT = File::Spec->rel2abs($CCOUT, $INPD);
    if ($CCOUT =~ /^(.*)\/[^\/]+?$/ && !-e $1) {`mkdir -p $1`;}
    
    &Log("\nINFO: Processing CC $CCIN\n");
    if (! -e $CCIN) {&Log("ERROR Could not find \"$CCIN\" with \"$_\"\n"); next;}
    if (!$CCTable && !$CCScript) {
      &Log("ERROR: Cannot do CC command:\n".$_."You must first specify SET_CCTable:<cctable-path>, or SET_CCScript:<script-path>\n\n");
      next;
    }

    if ($CCTable) {
      if ($CCTable =~ /^\./) {$CCTable = File::Spec->rel2abs($CCTable, $INPD);}
      if (! -e $CCTable) {&Log("ERROR Could not find \"$CCTable\" with:\n$_\n"); next;}
    }
    
    if ($CCScript) {
      if ($CCScript =~ /^\./) {$CCScript = File::Spec->rel2abs($CCScript, $INPD);}
      if (! -e $CCScript) {&Log("ERROR Could not find \"$CCScript\" with:\n$_\n"); next;}
    }
    
    my $fname = $CCIN; $fname =~ s/^.*\///;
    
    if ($fname eq "config.conf") {
      # By default, all entries are converted except entries beginning with Copyright and Distribution.
      # CONFIGCONVERT_<entry> will force conversion of that entry.
      # CONFIGdontCONVERT_<entry> will force that entry to NOT be converted.
      my $confP = &readConf($CCIN);
      foreach my $e (keys %{$confP}) {
        if (${"CONFIGCONVERT_$e"} && ${"CONFIGdontCONVERT_$e"}) {&Log("ERROR: Both CONFIGCONVERT_ and CONFIGdontCONVERT_ are specified for \"$e\"\n");}
        if (($e !~ /^(Copyright|Distribution)/ || ${"CONFIGCONVERT_$e"}) && !${${"CONFIGdontCONVERT_$e"}}) {
          $confP->{$e} = &string_convert($confP->{$e}, $CCTable, $CCScript);
        }
      }
      $confP->{'ModuleName'} = $INPD; $confP->{'ModuleName'} =~ s/^.*?([^\/]+)$/$1/;
      foreach my $ent (keys %{$confP}) {if (${"CONFIG_$ent"}) {$confP->{$ent} = ${"CONFIG_$ent"};}}
      &writeConf($CCOUT, $confP);
      &setConfGlobals(&updateConfData(&readConf($CCOUT)));
    }
    elsif ($fname eq "collections.txt") {
      if (!$sourceProject) {&Log("ERROR: Unable to update collections.txt! To remedy this, specify SET_sourceProject in $COMMANDFILE\n"); next;}
      my $newMod = lc($MOD);
      if (!open(CI, "<encoding(UTF-8)", $CCIN)) {&Log("ERROR: Could not open collections.txt input \"$CCIN\"\n"); next;}
      if (!open(CO, ">encoding(UTF-8)", $CCOUT)) {&Log("ERROR: Coult not open collections.txt output \"$CCOUT\"\n"); next;}
      my %col;
      while(<CI>) {
        if ($_ =~ s/^(Collection\:\s*)(\Q$sourceProject\E)(.*)$/$1$newMod$3/i) {$col{"$2$3"} = "$newMod$3";}
        else {$_ = &string_convert($_, $CCTable, $CCScript);}
        print CO $_;
      }
      close(CO);
      close(CI);
      if (!%col) {&Log("ERROR: Did not update Collection names in collections.txt\n");}
      else {foreach my $c (sort keys %col) {&Log("Updated Collection \"$c\" to \"".$col{$c}."\"\n");}}
    }
    elsif ($fname eq "convert.txt") {
      if (!open(CI, "<encoding(UTF-8)", $CCIN)) {&Log("ERROR: Could not open convert.txt input \"$CCIN\"\n"); next;}
      if (!open(CO, ">encoding(UTF-8)", $CCOUT)) {&Log("ERROR: Coult not open convert.txt output \"$CCOUT\"\n"); next;}
      while(<CI>) {
        if ($_ =~ /^([\w\d]+)\s*=\s*(.*?)\s*$/) {
          my $e=$1; my $v=$2;
          if ($e !~ /^(Language|Publisher|BookTitlesInOSIS|Epub3|TestamentGroups)$/) {
            $_ = "$e=".&string_convert($v, $CCTable, $CCScript)."\n";
          }
          if (${"CONVERT_$e"}) {$_ = "$e=".${"CONVERT_$e"}."\n";}
        }
        print CO $_;
      }
      close(CO);
      close(CI);
    }
    else {&file_convert($CCIN, $CCTable, $CCScript, $CCOUT);}
  }
  elsif ($_ =~ /^CCOSIS:\s*(.*?)\s*$/) {
    my $osis = $1;
    if (!$sourceProject) {&Log("ERROR: Unable to run CCOSIS! To remedy this, specify SET_sourceProject in $COMMANDFILE\n"); next;}
    if ($osis =~ /\.xml$/i) {
      if ($osis =~ /^\./) {$osis = File::Spec->rel2abs($osis, $INPD);}
    }
    else {
      if ($OUTDIR eq "$INPD/output") {$osis = "$INPD/../$osis/output/$osis.xml";}
      else {$osis = "$OUTDIR/../$osis/$osis.xml";}
    }
    if (! -e $osis) {&Log("ERROR Could not find \"$osis\" with:\n".$_."You may need to specify OUTDIR in paths.pl.\n"); next;}
    
    if (!$CCTable && !$CCScript) {&Log("ERROR: Cannot do CCOSIS command:\n".$_."You must first specify SET_CCTable:<cctable-path>, or SET_CCScript:<script-path>\n\n"); next;}
    
    if ($CCTable) {
      if ($CCTable =~ /^\./) {$CCTable = File::Spec->rel2abs($CCTable, $INPD);}
      if (! -e $CCTable) {&Log("ERROR Could not find \"$CCTable\" with:\n$_\n"); next;}
    }
    
    if ($CCScript) {
      if ($CCScript =~ /^\./) {$CCScript = File::Spec->rel2abs($CCScript, $INPD);}
      if (! -e $CCScript) {&Log("ERROR Could not find \"$CCScript\" with:\n$_\n"); next;}
    }
    
    $osis_in = "$TMPDIR/".$MOD."_0.xml";
    &Log("\nINFO: Processing CCOSIS $osis\n");
    &file_convert($osis, $CCTable, $CCScript, $osis_in);
  }
  elsif ($_ =~ /^OSIS_IN:\s*(.*?)\s*$/) {
    $osis_in = $1;
    &Log("\nINFO: Processing OSIS_IN $CCIN\n");
    if ($osis_in =~ /^\./) {$osis_in = File::Spec->rel2abs($osis_in, $INPD);}
    if (! -e $osis_in) {die "ERROR: Specified OSIS file $_ not found. Exiting...\n";}
    copy($osis_in, "$TMPDIR/".$MOD."_0.xml");
  }
  else {&Log("ERROR: Unhandled command:\n".$_."in $COMMANDFILE\n\n");}
}
close(COMF);

if ($osis_in) {require("$SCRD/scripts/perl/processOSIS.pl");}

sub string_convert($$$) {
  my $s = shift;
  my $cctable = shift;
  my $ccscript = shift;
  
  if ($cctable) {return &simplecc_convert($s, $cctable);}
  elsif ($ccscript) {
    &Log("INFO: Performing string_convert of \"$s\" with \"$ccscript\"\n");
    my $tmp = $ccscript;
    $tmp =~ s/\/[^\/]*$//;
    $tmp .= "/tmp_string_convert";
    `mkdir $tmp`;
    
    open(TMP, ">encoding(UTF-8)", "$tmp/string_convert_in.txt") || die;
    print TMP "$s";
    close(TMP);
    
    `"$ccscript" "$tmp/string_convert_in.txt" "$tmp/string_convert_out.txt"`;
    
    open(TMP, "<encoding(UTF-8)", "$tmp/string_convert_out.txt") || die;
    my $r = join('', <TMP>); 
    close(TMP);
   
    `rm -rf $tmp`;

    return $r;
  }
  else {&Log("ERROR osis2osis.pl: No string_convert method\n");}
}

sub file_convert($$$$) {
  my $in = shift;
  my $cctable = shift;
  my $ccscript = shift;
  my $out = shift;
  
  if ($cctable) {&simplecc($in, $cctable, $out);}
  elsif ($ccscript) {
    my $cmd = "\"$ccscript\" \"$in\" \"$out\"";
    &Log("INFO: Performing file_convert with \"$cmd\"\n");
    `$cmd`;
  }
  else {&Log("ERROR osis2osis.pl: No file_convert method\n");}
}

1;
