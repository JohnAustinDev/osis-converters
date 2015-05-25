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

$INPD = shift;
use File::Spec;
$SCRD = File::Spec->rel2abs(__FILE__);
$SCRD =~ s/[\\\/][^\\\/]+$//;
require "$SCRD/scripts/common.pl"; 
&init(__FILE__);

# copy necessary files to tmp
copy("$INPD/eBook/convert.txt", "$TMPDIR/convert.txt");
copy("$OUTDIR/$MOD.xml", "$TMPDIR/$MOD.xml");
copy("$SCRD/eBooks/css/ebible.css", "$TMPDIR/ebible.css");

# get scope for naming output files
&setConfGlobals(updateConfData($ConfEntryP, "$OUTDIR/$MOD.xml"));

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
    my $name = "$MOD.$format";
    if ($ConfEntryP->{"Scope"}) {
      $name = $ConfEntry{"Scope"} . ".$format";
      $name =~ s/\s/_/g;
    }
    copy($out, "$OUTDIR/eBooks/$name");
    &Log("REPORT: Created output file: $name\n");
  }
  else {&Log("ERROR: No output file: $out\n");}
}

