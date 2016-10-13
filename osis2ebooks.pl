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

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

&osisXSLT("$OUTDIR/$MOD.xml", $MODULETOOLS_BIN."osis2ebook.xsl", "$TMPDIR/".$MOD."_1.xml");
$OSISFILE = "$TMPDIR/".$MOD."_1.xml";

# get scope and vsys of OSIS file
&setConfGlobals(&updateConfData($ConfEntryP, $OSISFILE));

# make eBooks from the entire OSIS file
my %conv = &ebookReadConf("$INPD/eBook/convert.txt");
$CREATE_FULL_BIBLE = (!defined($conv{'CreateFullBible'}) || $conv{'CreateFullBible'} !~ /^(false|0)$/i);
$CREATE_SEPARATE_BOOKS = (!defined($conv{'CreateSeparateBooks'}) || $conv{'CreateSeparateBooks'} !~ /^(false|0)$/i);

if ($CREATE_FULL_BIBLE) {&setupAndMakeEbooks();}

# also make separate eBooks from each Bible book within the OSIS file
if ($CREATE_SEPARATE_BOOKS) {
  $thisXML = $XML_PARSER->parse_file($OSISFILE);
  @allBooks = $XPC->findnodes('//osis:div[@type="book"]', $thisXML);
  foreach my $aBook (@allBooks) {&setupAndMakeEbooks($aBook->getAttribute('osisID'));}
}

########################################################################
########################################################################

sub setupAndMakeEbooks($) {
  my $scope = shift;
  
  my $tmp = "$TMPDIR/".($scope ? $scope:'all');
  make_path($tmp);
    
  # copy necessary files to tmp
  &pruneFileOSIS($OSISFILE, "$tmp/$MOD.xml", $scope, $ConfEntryP->{"Versification"});
  copy("$INPD/eBook/convert.txt", "$tmp/convert.txt");
  my $scopeTitle;
  if ($scope) {$scopeTitle = &ebookUpdateConf("$tmp/convert.txt", "$tmp/$MOD.xml");}
  my $css = "$SCRD/eBooks/css";
  # see if a more specific eBook css exists 
  if (-e "$INPD/eBook/css") {$css = "$INPD/eBook/css";}
  elsif (-e "$INPD/../defaults/eBook/css") {$css = "$INPD/../defaults/eBook/css";}
  elsif (-e "$INPD/../../defaults/eBook/css") {$css = "$INPD/../../defaults/eBook/css";}
  copy_dir($css, "$tmp/css");
  if (-d "$INPD/images") {&copy_dir("$INPD/images", "$tmp/images", 1, 1);}
  my $cover;
  if (-e "$INPD/eBook/cover.jpg") {
    $cover = "$tmp/cover.jpg";
    if ($scope) {
      # add specific title to the top of the eBook cover image
      my $imagewidth = 600;
      my $pointsize = (4/3)*$imagewidth/length($scopeTitle);
      if ($pointsize > 40) {$pointsize = 40;}
      elsif ($pointsize < 10) {$pointsize = 10;}
      my $padding = 20;
      my $barheight = $pointsize + (2*$padding) - 10;
      my $cmd = "convert \"$INPD/eBook/cover.jpg\" -gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize -annotate +0+$padding '$scopeTitle' \"$cover\"";
      &Log("$cmd\n");
      `$cmd`;
    }
    else {copy("$INPD/eBook/cover.jpg", $cover);}
  }

  # locate files for any dictionaries and copy these
  foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
    my $outf;
    
    my $outd = $OUTDIR;
    $outd =~ s/$MOD/$companion/;
    if (-e "$outd/$companion.xml") {$outf = "$outd/$companion.xml";}
    elsif (-e "$INPD/$companion/output/$companion.xml") {$outf = "$INPD/$companion/output/$companion.xml";}
    else {&Log("ERROR: Companion dictionary \"$companion\" was specified in config.conf, but its OSIS file was not found.\n");}
    
    if ($outf) {copy($outf, "$tmp/$companion.xml");}
  }

  # run the converter
  &makeEbook("$tmp/$MOD.xml", 'epub', $cover, $scope, $tmp);
  &makeEbook("$tmp/$MOD.xml", 'mobi', $cover, $scope, $tmp);
  &makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp);
}

sub makeEbook($$$$) {
  my $osis = shift;
  my $format = shift; # “epub”, “mobi” or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  my $tmp = shift;
  
  &Log("\n--- CREATING $format FROM $osis FOR ".($scope ? $scope:"ALL BOOKS")."\n", 1);
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  
  my $cmd = "$SCRD/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . $cover . " >> ".&escfile("$TMPDIR/OUT_osis2ebooks.txt");
  &Log($cmd."\n");
  system($cmd);
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    my $name = ($scope ? $scope:($ConfEntryP->{"Scope"} ? $ConfEntryP->{"Scope"}:$MOD));
    if ($CREATE_SEPARATE_BOOKS) {
      $name .= "_" . ($scope ? "Part":"Full");
    }
    $name .= ".$format";
    $name =~ s/\s/_/g;

    copy($out, "$EBOUT/$name");
    &Log("REPORT: Created output file: $name\n", 1);
  }
  else {&Log("ERROR: No output file: $out\n");}
}

sub ebookUpdateConf($$) {
  my $convtxt = shift;
  my $osis = shift;
  
  my $title = "";
  my $sep = "";
  
  my %conv = &ebookReadConf($convtxt);
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $abk (@bks) {
    my $k = $abk->getAttribute('osisID');
    if ($conv{$k}) {$title .= $sep.$conv{$k};}
    else {
      my @t = $XPC->findnodes('//text()[1]/ancestor::osis:title', $abk);
      if (@t) {$title .= $sep.@t[0]->textContent;}
    }
    if ($title) {$sep = "\n";}
  }
  my $t = $title; $t =~ s/\n/, /g;
  $conv{'Title'} .= ": $t";
  
  # delete Group1 and Group2 entries
  if (defined($conv{'Group1'})) {delete($conv{'Group1'});}
  if (defined($conv{'Group2'})) {delete($conv{'Group2'});}
  
  if (open(CONV, ">encoding(UTF-8)", $convtxt)) {
    foreach my $k (sort keys %conv) {print CONV "$k=".$conv{$k}."\n";}
    close(CONV);
  }
  else {&Log("ERROR: Could not write ebookUpdateConf \"$convtxt\"\n"); die;}
  
  return $title;
}

sub ebookReadConf($) {
  my $convtxt = shift;
  
  my %conv;
  if (open(CONV, "<encoding(UTF-8)", $convtxt)) {
    while(<CONV>) {
      if ($_ =~ /^#/) {next;}
      elsif ($_ =~ /^([^=]+?)\s*=\s*(.*?)\s*$/) {$conv{$1} = $2;}
    }
    close(CONV);
  }
  else {&Log("ERROR: Could not read ebookReadConf \"$convtxt\"\n"); die;}
  
  return %conv;
}
1;
