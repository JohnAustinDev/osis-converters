#!/usr/bin/perl
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

# usage: xsm.pl [XSM_Directory]

# Run this script to create xulsword modules using a command file

use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  my $dproj = "./Example_XSM";
  print "\nusage: xsm.pl [XSM_Directory]\n";
  print "\n";
  print "run default project $dproj? (Y/N):";
  my $in = <>;
  if ($in !~ /^\s*y\s*$/i) {exit;}
  $INPD = File::Spec->rel2abs($dproj);
}
if (!-e $INPD) {
  print "XSM_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}
$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$COMMANDFILE = "$INPD/CF_xsm.txt";
if (!-e $COMMANDFILE) {print "ERROR: Missing command file: $COMMANDFILE. Exiting.\n"; exit;}
$LOGFILE = "$OUTDIR/OUT_xsm.txt";

my $delete;
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if (-e "$OUTDIR/xsm") {$delete .= "$OUTDIR/xsm\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $LOGFILE) {unlink($LOGFILE);}
if (-e "$OUTDIR/xsm") {remove_tree("$OUTDIR/xsm");}

$TMPDIR = "$OUTDIR/tmp/xsm";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("\n-----------------------------------------------------\nSTARTING xsm.pl\n\n");
if (!-e "$OUTDIR/xsm") {make_path("$OUTDIR/xsm");}

# read the command file to build the xsm module
&normalizeNewLines($COMMANDFILE);
&addRevisionToCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open xsm command file $COMMANDFILE\n";
$AllowSet = "includeIndexes|includeSecurityKeys|swordDirectory";
$includeIndexes = 0;
$includeSecurityKeys = 0;
$swordDirectory = "";
&clearModGlobals();
$line=0;
while (<COMF>) {
  $line++;
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^SET_($AllowSet):(\s*(\S+)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = $val;
      if ($par =~ /^(includeIndexes|includeSecurityKeys)$/) {
        $$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
      }
      &Log("INFO: Setting $par to $$par\n");
    }
  }
  elsif ($_ =~ /^NAME:\s*(.*?)\s*$/) {if ($1) {
    $xsmName = $1;
    if (-e "$TMPDIR/$xsmName") {remove_tree("$TMPDIR/$xsmName");} 
    make_path("$TMPDIR/$xsmName");
  }}
  elsif ($_ =~ /^VERSION:\s*(.*?)\s*$/) {if ($1) {$xsmVersion = $1;}}
  elsif ($_ =~ /^ADD_SWORD:\s*(.*?)\s*$/) {if ($1) {&addModule($1, $xsmVersion);}}
  elsif ($_ =~ /^ADD_UI:\s*(.*?)\s*$/) {if ($1) {&Log("ERROR: ADD_UI not yet implemented\n");}}
  elsif ($_ =~ /^ADD_BOOKMARK:\s*(.*?)\s*$/) {if ($1) {&Log("ERROR: ADD_BOOKMARK not yet implemented\n");}}
  elsif ($_ =~ /^ADD_FONT:\s*(.*?)\s*$/) {if ($1) {&Log("ERROR: ADD_FONT not yet implemented\n");}}
  elsif ($_ =~ /^ADD_AUDIO:\s*(.*?)\s*$/) {if ($1) {&Log("ERROR: ADD_AUDIO not yet implemented\n");}}
  elsif ($_ =~ /^ADD_VIDEO:\s*(.*?)\s*$/) {if ($1) {&Log("ERROR: ADD_VIDEO not yet implemented\n");}}
  elsif ($_ =~ /^CREATE_XSM\s*$/) {&createXSM(); &clearModGlobals();}
  else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}
close (COMF);

sub createXSM() {
  if (!$xsmName) {&Log("ERROR: Must specify NAME in $COMMANEFILE\n"); return;}
  if (!$xsmVersion) {&Log("ERROR: Must specify VERSION in $COMMANEFILE\n"); return;}
  
  # now zip up the finished module
  my $xsmFileName = "$xsmName-$xsmVersion.xsm";
  if ("$^O" =~ /MSWin32/i) {
    `7za a -tzip \"$OUTDIR\\xsm\\$xsmFileName\" -r \"$TMPDIR\\$xsmName\\*\"`;
  }
  else {
    my $td = `pwd`; 
    chomp($td);
    chdir("$TMPDIR/$xsmName");
    `zip -r $xsmFileName .`;
    chdir($td);
    move("$TMPDIR/$xsmName/$xsmFileName", "$OUTDIR/xsm");
  }
}

sub addModule($$$) {
  my $m = shift;
  my $v = shift;
  
  my $d = "$TMPDIR/$xsmName";
  
  # locate the module
  if (!$swordDirectory) {&Log("ERROR: Must set SET_swordDirectory in $COMMANDFILE\n"); return 0;}
  if (!-e $swordDirectory) {&Log("ERROR: Directory does not exist: $swordDirectory\n"); return 0;}
  my $conf = "$swordDirectory/mods.d/".lc($m).".conf";
  if (!-e $conf) {&Log("ERROR: Module conf not found: $conf\n"); return 0;}
  
  # copy the conf
  make_path("$d/mods.d");
  copy($conf, "$d/mods.d");
  my $conf2 = "$d/mods.d/".lc($m).".conf";
  &getInfoFromConf($conf2);

  # copy the module
  my $mdir = "$swordDirectory/$MODPATH";
  if (!-e $mdir) {&Log("ERROR: module directory not found: $mdir\n"); return 0;}
  copy_dir($mdir, "$d/$MODPATH");
  
  # add xsm specific entries to new conf file
  my $xulswordVersion = $v;
  my $minMKVersion = 2.7;
  
  if ($VERSESYS eq "EASTERN") {&Log("ERROR: EASTERN verse system no longer supported.\n"); return 0;}
  elsif ($VERSESYS eq "Synodal") {
    $minMKVersion = 2.13;
    if ($ConfEntry{"MinimumVersion"} && $ConfEntry{"MinimumVersion"} =~ /(\d+)\.(\d+)\.(\d+)/) {
      # if MinimumVersion > 1.6.1, then minMKVersion is 2.21;
      if ($1>1 || ($1==1 && $2>6) || ($1==1 && $2==6 && $3>1)) {$minMKVersion = 2.21;}
    }
  }
  
  my $app;
  if ($ConfEntry{"xulswordVersion"} && $ConfEntry{"xulswordVersion"} ne $xulswordVersion) {
    &Log("WARNING: xulswordVersion=".$ConfEntry{"xulswordVersion"}." already specified in $conf (would have been set to $xulswordVersion).\n");
  }
  else {
    &Log("INFO: ($m) Setting \"xulswordVersion=$xulswordVersion\" to conf.\n");
    $app .= "xulswordVersion=$xulswordVersion\n";
  }
  if ($ConfEntry{"minMKVersion"} && $ConfEntry{"minMKVersion"} ne $minMKVersion) {
    &Log("WARNING: minMKVersion=".$ConfEntry{"minMKVersion"}." already specified in $conf (would have been set to $minMKVersion).\n");
  }
  else {
    &Log("INFO: ($m) Setting \"minMKVersion=$minMKVersion\" to conf.\n");
    $app .= "minMKVersion=$minMKVersion\n";
  }
  if ($app) {
    open(CNF, ">>:encoding(UTF-8)", $conf2) || die "Could not open new conf: \"$conf2\"\n";
    print CNF "\n$app";
    close(CNF);
  }
  
  return 1;
}

sub clearModGlobals(){
  $xsmName = "";
  $xsmVersion = "";
  undef(%swordMod);
  undef(%xsUI);
  undef(%bookmark);
  undef(%font);
  undef(%audio);
  undef(%video);
}

1;
