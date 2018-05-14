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

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//;
require "$SCRD/scripts/perl/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/perl/common.pl"; &init();

# Get SFM files
$List = "-l";
$INPF = "$INPD/SFM_Files.txt";
if (! -e $INPF) {
  &Log("ERROR: Must list sfm files in \"$INPF\", one file per line, in proper sequence.\n");
  exit;
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
$cmd = "$SCRD/scripts/perl/childrens_bible/scripts/preproc.py $AddFileOpt $List $INPF \"$TMPDIR/".$MOD."_1.sfm\" jpg $PREFIX";
&Log($cmd."\n");
`$cmd`;

# run main conversion script
&Log("\n--- CONVERTING PARATEXT TO OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$SCRD/scripts/perl/childrens_bible/scripts/usfm2osis.py $MOD -o \"$TMPDIR/".$MOD."_1.xml\" -r -g -x \"$TMPDIR/".$MOD."_1.sfm\"";
&Log($cmd."\n");
`$cmd`;

# run postprocessor
&Log("\n--- POSTPROCESSING OSIS\n-----------------------------------------------------\n\n", 1);
$cmd = "$SCRD/scripts/perl/childrens_bible/scripts/postproc.py \"$TMPDIR/".$MOD."_1.xml\" \"$TMPDIR/".$MOD."_2.xml\"";
&Log($cmd."\n");
`$cmd`;

# run addScripRefLinks.pl
if (-e "$INPD/CF_addScripRefLinks.txt") {
  require("$SCRD/scripts/perl/addScripRefLinks.pl");
  &addScripRefLinks("$TMPDIR/".$MOD."_2.xml", $OUTOSIS);
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
  else {&Log("ERROR: Reference \"$reference\" not found!\n");}
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
    if (!$src) {push(@badTargets, $figure); &Log("ERROR: Figure has no target: line ".$figure->line_number()."\n");}
    elsif (!&srcPath($src) || ! -e &srcPath($src)) {push(@badTargets, $figure); &Log("ERROR: Figure target not found \"".&srcPath($src)."\": line ".$figure->line_number()."\n");}
    else {push(@goodTargets, $figure);}
  }
  &Log("\n$MOD REPORT: ". @figures . " figures found in the OSIS file.\n");
  &Log("$MOD REPORT: ". @goodTargets . " figures have valid targets.\n");
  &Log("$MOD REPORT: ". @badTargets . " figure(s) have missing targets.\n");

  # if there are any missing targets, remove the corresponding figures
  my @removedTargets;
  if (@badTargets) {
    &Log("\n");
    foreach my $f (@badTargets) {
      push(@removedTargets, $f->parentNode->removeChild($f));
      &Log("WARNING: Removed figure with missing target: \"".$f."\"\n");
    }
    &Log("\n");
    my $t = $xml->toString();
    if (open(OSIS, ">$inosis")) {print OSIS $t; close(OSIS);}
    else {&Log("ERROR: Could not remove bad figures from \"$inosis\"\n"); @removedTargets = ();}
  }
  &Log("$MOD REPORT: ". @removedTargets . " figure(s) with missing targets were removed from the OSIS file.\n\n");
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
  if ($inmod eq $refmod) {&Log("WARNING: Not checking structure: OSIS file is $inmod, same as reference file.\n"); return;}

  &Log("\n--- CHECKING STRUCTURE\nOSIS      -> $inosis\nReference -> $refosis\n-----------------------------------------------------\n\n", 1);
  
  my $in = $XML_PARSER->parse_file($inosis);
  my $ref = $XML_PARSER->parse_file($refosis);

  my @refMS = $XPC->findnodes("//osis:div[\@type='majorSection']", $ref);
  if (@refMS) {
    my @inMS = $XPC->findnodes("//osis:div[\@type='majorSection']", $in);
    &Log("$MOD REPORT: OSIS has ".@inMS." majorSection divs, and reference has ".@refMS.".\n");
    my $j = 0;
    for (my $i=0; $i<@refMS && $j<@inMS; $i++) {
      $i = &nextParent($i, \@refMS);
      $j = &nextParent($j, \@inMS);
      if ($i >= 99) {}
      elsif ($j >= 99) {&Log("ERROR: Could not locate parent majorSection in OSIS.\n");}
      else {&compareSection(@inMS[$j], @refMS[$i]);}
      $j++;
    }
  }
  else {&Log("ERROR: Reference \"$refosis\" has no <div type='majorSection'> tags.\n");}

  &Log("$MOD REPORT: Structure comparison to reference:\n");
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

  if (!$inMS->getAttribute('osisID')) {&Log("ERROR: OSIS section line ".$inMS->line_number()." has no osisID.\n");}
  if (!$refMS->getAttribute('osisID')) {&Log("ERROR: reference section line ".$refMS->line_number()." has no osisID.\n");} 
  $StructReport{++$StructIndex}{'name_in'} = $inMS->getAttribute('osisID');
  $StructReport{$StructIndex}{'name_ref'} = $refMS->getAttribute('osisID');

  my @inSS = $XPC->findnodes('./osis:div[@type]', $inMS);
  my @refSS = $XPC->findnodes('./osis:div[@type]', $refMS);

  if (@inSS != @refSS) {&Log("ERROR: Mismatch: ".$inMS->getAttribute('osisID')."(".@inSS.") != ".$refMS->getAttribute('osisID')."(".@refSS.")\n");}
  elsif (!@refSS) {return;}
  else {
    my $ii;
    for ($ii=0; $ii<@refSS; $ii++) {&compareSection(@inSS[$ii], @refSS[$ii]);}
  }
}
  

1;
