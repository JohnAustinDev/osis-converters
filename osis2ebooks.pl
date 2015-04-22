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

# usage: osis2ebooks.pl [Project_Directory]

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use File::Spec;
use Cwd;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  print "\nusage: osis2ebooks.pl [Project_Directory]\n";
  exit;
}
if (!-e $INPD) {
  print "Project_Directory \"$INPD\" does not exist. Exiting.\n";
  exit;
}

$SCRD = File::Spec->rel2abs( __FILE__ );
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl";
&initPaths();

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE, 1);

$OSISFILE = "$OUTDIR/".$MOD.".xml";
if (!-e $OSISFILE) {print "ERROR: Missing osis file: $OSISFILE. Exiting.\n"; exit;}
$LOGFILE = "$OUTDIR/OUT_osis2ebooks.txt";

my $delete;
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if (-e "$OUTDIR/eBooks") {$delete .= "$OUTDIR/eBooks\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $LOGFILE) {unlink($LOGFILE);}
if (-e "$OUTDIR/eBooks") {remove_tree("$OUTDIR/eBooks");}
make_path("$OUTDIR/eBooks");

$TMPDIR = "$OUTDIR/tmp/osis2ebooks";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

&Log("osis-converters rev: $GITHEAD\n\n");
&Log("\n-----------------------------------------------------\nSTARTING osis2ebooks.pl\n\n");

# copy necessary files to tmp
copy("$INPD/eBook/convert.txt", "$TMPDIR/convert.txt");
copy("$OUTDIR/$MOD.xml", "$TMPDIR/$MOD.xml");
copy("$SCRD/eBooks/css/ebible.css", "$TMPDIR/ebible.css");

# run the converter
&makeEbook("$TMPDIR/$MOD.xml", 'epub');
&makeEbook("$TMPDIR/$MOD.xml", 'mobi');
&makeEbook("$TMPDIR/$MOD.xml", 'fb2');

sub makeEbook($$$) {
  my $osis = shift;
  my $format = shift; # “epub”, “mobi” or “fb2”
  my $cover = shift; # path to cover image
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  
  system("$SCRD/eBooks/osis2ebook.pl " . &escfile($TMPDIR) . " " . &escfile($osis) . " " . $format . " " . $cover . " >> ".&escfile($LOGFILE));
  
  my $out = "$TMPDIR/$MOD.$format";
  if (-e $out) {
    copy($out, "$OUTDIR/eBooks/");
    &Log("REPORT: Created output file: $MOD.$format\n");
  }
  else {&Log("ERROR: No output file: $out\n");}
}
  
1;
