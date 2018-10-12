#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
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

# usage: cbsfm2osis.pl [Project_Directory]

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/](osis\-converters|vagrant))[\\\/].*?$/$1/; require "$SCRD/scripts/bootstrap.pl";

# Get SFM files
$List = "-l";
$INPF = "$INPD/SFM_Files.txt";
if (! -e $INPF) {
  &Error("File does not exist: '$INPF'", "You must list sfm files in '$INPF', one file per line, in proper sequence.", 1);
}

# Get any prefix to be added to additional language specific picture file names
$PREFIX = '';
if (-e "$INPD/Image_Prefix.txt") {
  open(INF, "<$INPD/Image_Prefix.txt"); 
  $PREFIX = <INF>; 
  close(INF);
}

# run preprocessor
&Log("\n--- PREPROCESSING USFM\n-----------------------------------------------------\n\n", 1);
$AddFileOpt = (-e "$INPD/SFM_Add.txt" ? "-a \"$INPD/SFM_Add.txt\"":'');
$cmd = "$SCRD/scripts/genbook/childrens_bible/preproc.py $AddFileOpt $List $INPF \"$TMPDIR/".$MOD."_1.sfm\" jpg $PREFIX";
&Log($cmd."\n");
`$cmd`;

# run main conversion script
&Log("\n--- CONVERTING PARATEXT TO OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$SCRD/scripts/genbook/childrens_bible/usfm2osis.py $MOD -o \"$TMPDIR/".$MOD."_1.xml\" -r -g -x \"$TMPDIR/".$MOD."_1.sfm\"";
&Log($cmd."\n");
`$cmd`;

# run postprocessor
&Log("\n--- POSTPROCESSING OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$SCRD/scripts/genbook/childrens_bible/postproc.py \"$TMPDIR/".$MOD."_1.xml\" \"$TMPDIR/".$MOD."_2.xml\"";
&Log($cmd."\n");
`$cmd`;

# run addScripRefLinks.pl
if ($addScripRefLinks ne '0') {
  require("$SCRD/scripts/addScripRefLinks.pl");
  &addScripRefLinks(&getDefaultFile('bible/CF_addScripRefLinks.txt'), "$TMPDIR/".$MOD."_2.xml", $OUTOSIS);
}
else {
  &Log("Skipping Scripture reference parsing.\n");
  rename("$TMPDIR/".$MOD."_2.xml", $OUTOSIS);
}

# check all images targets, report and remove images with missing targets
&checkImages($OUTOSIS);

# compare structure to a reference and report any discrepancies
# this is necessary to insure parallel viewing of Children's Bibles will work
$reference = "$OUTDIR/../RUSCB/RUSCB.xml";
if ($reference) {
  if (-e $reference) {&checkStructure($OUTOSIS, $reference);}
  else {&ErrorBug("Reference \"$reference\" not found.");}
}

#&validateOSIS($OUTOSIS);

########################################################################
########################################################################

sub checkImages($) {
  my $inosis = shift;

  my $xml = $XML_PARSER->parse_file($inosis);

  # get all images
  my @figures = $XPC->findnodes('//osis:figure', $xml);
  
  # check targets
  my @badTargets;
  my @goodTargets;
  foreach my $figure (@figures) {
    my $src = $figure->getAttribute('src');
    if (!$src) {push(@badTargets, $figure); &Error("Figure is missing src attribute: line ".$figure->line_number());}
    elsif (!&srcPath($src) || ! -e &srcPath($src)) {push(@badTargets, $figure); &Error("Figure target not found \"".&srcPath($src)."\": line ".$figure->line_number());}
    else {push(@goodTargets, $figure);}
  }
  &Log("\n");
  &Report( @figures . " figures found in the OSIS file.");
  &Report("". @goodTargets . " figures have valid targets.");
  &Report("". @badTargets . " figure(s) have missing targets.");

  # if there are any missing targets, remove the corresponding figures
  my @removedTargets;
  if (@badTargets) {
    &Log("\n");
    foreach my $f (@badTargets) {
      push(@removedTargets, $f->parentNode->removeChild($f));
      &Warn("Removed figure with missing target: \"".$f."\"");
    }
    &Log("\n");
    my $t = $xml->toString();
    if (open(OSIS, ">$inosis")) {print OSIS $t; close(OSIS);}
    else {&Error("Could not remove bad figures from \"$inosis\""); @removedTargets = ();}
  }
  &Report(@removedTargets . " figure(s) with missing targets were removed from the OSIS file.\n");
}

sub srcPath($) {
  my $src = shift;
  if (-e "$INPD/images") {
    if (! -e "$TMPDIR/images") {&copy_images_to_module("$INPD/images", $TMPDIR);}
    return "$TMPDIR/$src";
  }
  return 0;
}

# Find each majorSection having children in reference file and compare
# its children to those of the OSIS file.
sub checkStructure($$) {
  my $inosis = shift;
  my $refosis = shift;

  my $inmod = $inosis; $inmod =~ s/^.*?([^\/\\]+)$/$1/;
  my $refmod = $refosis; $refmod =~ s/^.*?([^\/\\]+)$/$1/;
  if ($inmod eq $refmod) {&Warn("Not checking structure: OSIS file is $inmod, same as reference file."); return;}

  &Log("\n--- CHECKING STRUCTURE\nOSIS      -> $inosis\nReference -> $refosis\n-----------------------------------------------------\n\n", 1);
  
  my $in = $XML_PARSER->parse_file($inosis);
  my $ref = $XML_PARSER->parse_file($refosis);

  my @refMS = $XPC->findnodes("//osis:div[\@type='majorSection']", $ref);
  if (@refMS) {
    my @inMS = $XPC->findnodes("//osis:div[\@type='majorSection']", $in);
    &Report("OSIS has ".@inMS." majorSection divs, and reference has ".@refMS.".");
    my $j = 0;
    for (my $i=0; $i<@refMS && $j<@inMS; $i++) {
      $i = &nextParent($i, \@refMS);
      $j = &nextParent($j, \@inMS);
      if ($i >= 99) {}
      elsif ($j >= 99) {&Error("Could not locate parent majorSection in OSIS.");}
      else {&compareSection(@inMS[$j], @refMS[$i]);}
      $j++;
    }
  }
  else {&Error("Reference \"$refosis\" has no <div type='majorSection'> tags.");}

  &Report("Structure comparison to reference:");
  foreach my $ix (sort {$a <=> $b} keys(%StructReport)) {
    &Log(sprintf("%03i % 64s % 64s\n", $ix, $StructReport{$ix}{'name_in'}, $StructReport{$ix}{'name_ref'}));
  }
}

# MajorSections without children are ignored by finding the next parent
# by skipping over majorSections without children.
sub nextParent($\@) {
  my $i = shift;
  my $msP = shift;
  my @ss = $XPC->findnodes('./osis:div[@type]', @{$msP}[$i]);
  while ($i < (@{$msP}-1) && !@ss) {
    $i++;
    @ss = $XPC->findnodes('./osis:div[@type]', @{$msP}[$i]);
  }
  return (!@ss ? 99:$i);
}

sub compareSection($$) {
  my $inMS = shift;
  my $refMS = shift;

  if (!$inMS->getAttribute('osisID')) {&Error("OSIS section line ".$inMS->line_number()." has no osisID.");}
  if (!$refMS->getAttribute('osisID')) {&Error("reference section line ".$refMS->line_number()." has no osisID.");} 
  $StructReport{++$StructIndex}{'name_in'} = $inMS->getAttribute('osisID');
  $StructReport{$StructIndex}{'name_ref'} = $refMS->getAttribute('osisID');

  my @inSS = $XPC->findnodes('./osis:div[@type]', $inMS);
  my @refSS = $XPC->findnodes('./osis:div[@type]', $refMS);

  if (@inSS != @refSS) {&Error("Mismatch: ".$inMS->getAttribute('osisID')."(".@inSS.") != ".$refMS->getAttribute('osisID')."(".@refSS.")");}
  elsif (!@refSS) {return;}
  else {
    my $ii;
    for ($ii=0; $ii<@refSS; $ii++) {&compareSection(@inSS[$ii], @refSS[$ii]);}
  }
}
  

1;
