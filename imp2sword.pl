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

# usage: imp2sword.pl [Glossary_Directory]

# Run this script to create a dictionary SWORD module from an IMP 
# file and a config.conf file located in the Glossary_Directory.

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common.pl"; &init(__FILE__);

$IMPFILE = "$OUTDIR/$MOD.imp";
if (!-e $IMPFILE) {print "ERROR: Missing imp file: $IMPFILE. Exiting.\n"; exit;}

# uppercase dictionary keys were necessary to avoid requiring ICU.
# XSLT cannot be used to do this because a custom uc2() Perl function is needed.
if ($UPPERCASE_DICTIONARY_KEYS) {
  my $entryName, %entryText, @entryOrder;
  open(INF, "<:encoding(UTF-8)", $IMPFILE) or die "Could not open $IMPFILE.\n";
  while(<INF>) {
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^\$\$\$\s*(.*)\s*$/) {$entryName = $1; push(@entryOrder, $entryName);}
    else {$entryText{$entryName} .= $_;}
  }
  close(INF);
  
  open(OUTF, ">:encoding(UTF-8)", "$TMPDIR/imp_ucdict.imp") or die "Could not open $TMPDIR/imp_ucdict.imp.\n";
  foreach my $entryName (@entryOrder) {
    print OUTF "\$\$\$".&uc2($entryName)."\n";
    $entryText{$entryName} =~ s/(<reference\b[^>]*type="(x-glossary|x-glosslink)"[^>]*>)/my $r = &referenceUC($1);/ge;
    print OUTF $entryText{$entryName}; 
  }
  close(OUTF);
  
  $IMPFILE = "$TMPDIR/imp_ucdict.imp";
}

my $IMAGEDIR = "$INPD/images";
my $commandFile = "$INPD/CF_paratext2imp.txt";
if (open(COMF, "<:encoding(UTF-8)", $commandFile)) {
  while(<COMF>) {
    if ($_ =~ /^SET_imageDir:\s*(.*?)\s*$/) {if ($1) {$IMAGEDIR = $1;}}
  }
  close(COMF);

  if ($IMAGEDIR && $IMAGEDIR =~ /^\./) {
    chdir($INPD);
    $imageDir = File::Spec->rel2abs($imageDir);
    chdir($SCRD);
  }
}

# create and check module's conf file
make_path("$SWOUT/mods.d");
&writeConf("$SWOUT/mods.d/$MODLC.conf", $ConfEntryP, $CONFFILE, $IMPFILE);
$CONFFILE = "$SWOUT/mods.d/$MODLC.conf";

# create new module files
make_path("$SWOUT/$MODPATH");
chdir("$SWOUT/$MODPATH") || die "Could not cd into \"$SWOUT/$MODPATH\"\n";
&Log("\n--- CREATING $MOD Dictionary OSIS SWORD MODULE (".$VERSESYS.")\n");
$cmd = &escfile($SWORD_BIN."imp2ld")." ".&escfile($IMPFILE)." -o ./$MODLC ".($MODDRV eq "RawLD4" ? "-4 ":"").">> ".&escfile($LOGFILE);
&Log("$cmd\n", 1);
system($cmd);
chdir($INPD);

if (-e $IMAGEDIR) {copy_images_to_module($IMAGEDIR, "$SWOUT/$MODPATH");}

&writeInstallSizeToConf($CONFFILE, "$SWOUT/$MODPATH");

&zipModule($OUTZIP, $SWOUT);

&Log("\n\n");
open(CONF, "<:encoding(UTF-8)", $CONFFILE) || die "Could not open $CONFFILE\n";
while(<CONF>) {&Log("$_", 1);}
close(CONF);

sub referenceUC($) {
  my $r = shift;
  if ($r !~ s/(<reference\b[^>]*osisRef="\w+:)([^"]*")/$1.&uc2($2)/e) {&Log("ERROR: bas osisRef \"$r\"\n");}
  return $r;
}

1;
