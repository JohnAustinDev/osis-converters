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
%EBOOKCONV = &ebookReadConf("$INPD/eBook/convert.txt");
# This script supports the following special settings in convert.txt:
#  CreateFullBible=(0|1)        - Run/skip full Bible build
#  CreateSeparateBooks=(0|1)    - Run/skip individual book builds
#  CreateFullPublicationN=scope - Create extra full publication (N is a number)
#  TitleFullPublicationN=text   - Title of extra full publication N (if cover image is not supplied)
$CREATE_FULL_BIBLE = (!defined($EBOOKCONV{'CreateFullBible'}) || $EBOOKCONV{'CreateFullBible'} !~ /^(false|0)$/i);
$CREATE_SEPARATE_BOOKS = (!defined($EBOOKCONV{'CreateSeparateBooks'}) || $EBOOKCONV{'CreateSeparateBooks'} !~ /^(false|0)$/i);
@CREATE_FULL_PUBLICATIONS = (); foreach my $k (sort keys %EBOOKCONV) {if ($k =~ /^CreateFullPublication(\d+)$/) {push(@CREATE_FULL_PUBLICATIONS, $1);}}

if ($CREATE_FULL_BIBLE) {&setupAndMakeEbook('', 'Full');}

# make eBooks for any print publications that are part of the OSIS file (as specified in convert.txt: CreateFullPublicationN=scope)
if (@CREATE_FULL_PUBLICATIONS) {
  foreach my $x (@CREATE_FULL_PUBLICATIONS) {
    &setupAndMakeEbook($EBOOKCONV{'CreateFullPublication'.$x}, 'Full', $EBOOKCONV{'TitleFullPublication'.$x});
  }
}

# also make separate eBooks from each Bible book within the OSIS file
if ($CREATE_SEPARATE_BOOKS) {
  $thisXML = $XML_PARSER->parse_file($OSISFILE);
  @allBooks = $XPC->findnodes('//osis:div[@type="book"]', $thisXML);
  foreach my $aBook (@allBooks) {
    my $bk = $aBook->getAttribute('osisID');
    foreach my $x (@CREATE_FULL_PUBLICATIONS) {
      # don't create single ebook if an identical single ebook publication has already been created
      if ($bk && $bk eq $EBOOKCONV{'CreateFullPublication'.$x}) {$bk = '';}
    }
    if ($bk) {&setupAndMakeEbook($bk, 'Part');}
  }
}

########################################################################
########################################################################

sub setupAndMakeEbook($$$) {
  my $scope = shift;
  my $type = shift;
  my $title = shift;
  
  my $tmp = "$TMPDIR/".($scope ? $scope:'all');
  make_path($tmp);
    
  &pruneFileOSIS($OSISFILE, "$tmp/$MOD.xml", $scope, $ConfEntryP->{"Versification"});
  
  # copy convert.txt
  copy("$INPD/eBook/convert.txt", "$tmp/convert.txt");
  my $scopeTitle;
  if ($scope) {
    $scopeTitle = &ebookUpdateConf("$tmp/convert.txt", "$tmp/$MOD.xml", $title);
    %EBOOKCONV = &ebookReadConf("$tmp/convert.txt");
  }
  
  # copy css
  my $css = "$SCRD/eBooks/css";
  if (-e "$INPD/eBook/css") {$css = "$INPD/eBook/css";}
  elsif (-e "$INPD/../defaults/eBook/css") {$css = "$INPD/../defaults/eBook/css";}
  elsif (-e "$INPD/../../defaults/eBook/css") {$css = "$INPD/../../defaults/eBook/css";}
  copy_dir($css, "$tmp/css");
  
  # copy images
  if (-d "$INPD/images") {&copy_dir("$INPD/images", "$tmp/images", 1, 1);}
  
  # copy cover
  my $cover;
  # Cover name is 'cover' by default, or $scope if that image exists, or in 
  # the case of a single book eBook, the name of an existing image whose scope 
  # includes our book.
  my $covname = ($scope ? &findCover("$INPD/eBook", $scope):'cover.jpg');
  if (-e "$INPD/eBook/$covname") {
    $cover = "$tmp/cover.jpg";
    if ($scope && $type eq 'Part') {
      # add specific title to the top of the eBook cover image
      &Log("\nREPORT: Using \"$covname\" with extra title \"$scopeTitle\" as cover of \"$MOD:".($scope ? $scope:'all')."\".\n");
      my $imagewidth = `identify "$INPD/eBook/$covname"`; $imagewidth =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $imagewidth = (1*$imagewidth);
      my $pointsize = (4/3)*$imagewidth/length($scopeTitle);
      if ($pointsize > 40) {$pointsize = 40;}
      elsif ($pointsize < 10) {$pointsize = 10;}
      my $padding = 20;
      my $barheight = $pointsize + (2*$padding) - 10;
      my $cmd = "convert \"$INPD/eBook/$covname\" -gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize -annotate +0+$padding '$scopeTitle' \"$cover\"";
      &Log("$cmd\n");
      `$cmd`;
    }
    else {
      &Log("\nREPORT: Using \"$covname\" as cover of \"$MOD:".($scope ? $scope:'all')."\".\n");
      copy("$INPD/eBook/$covname", $cover);
    }
  }
  else {&Log("\nREPORT: Using random cover with title \"".$EBOOKCONV{'Title'}."\" as cover of \"$MOD:".($scope ? $scope:'all')."\".\n");}
  
  my @skipCompanions;
  foreach my $companion (split(/\s*,\s*/, $ConfEntryP->{'Companion'})) {
    # copy companion OSIS file
    my $outf;
    my $outd = $OUTDIR;
    $outd =~ s/$MOD/$companion/;
    if (-e "$outd/$companion.xml") {$outf = "$outd/$companion.xml";}
    elsif (-e "$INPD/$companion/output/$companion.xml") {$outf = "$INPD/$companion/output/$companion.xml";}
    else {&Log("ERROR: Companion dictionary \"$companion\" was specified in config.conf, but its OSIS file was not found.\n");}
    my $filter = 0;
    if ($outf) {
      copy($outf, "$tmp/$companion.xml");
      if ($companion =~ /DICT$/) {
        require "$SCRD/scripts/processGlossary.pl";
        # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
        $filter = &filterGlossaryToScope("$tmp/$companion.xml", $scope);
        if ($filter == -1) { # -1 means all glossary divs were filtered out
          push(@skipCompanions, $companion);
          unlink("$tmp/$companion.xml");
          &Log("REPORT: Will NOT include \"$companion\" in \"$MOD:".($scope ? $scope:'all')."\" because the glossary contained nothing which matched the scope.\n");
          next;
        }
      }
    }
  
    &Log("REPORT: Including".($filter ? ' (filtered)':'')." \"$companion\" in \"$MOD:".($scope ? $scope:'all')."\"\n");
    
    # copy companion images
    my $compDir = &findCompanionDirectory($companion);
    if (!$compDir) {next;}
    if (-d "$compDir/images") {
      if (-e "$tmp/images") {
        if (opendir(IDIR, "$compDir/images")) {
          my @images = readdir(IDIR);
          closedir(IDIR);
          foreach my $image (@images) {
            if (-d "$compDir/images/$image" || ! -e "$tmp/images/$image") {next;}
            &Log("ERROR: Images cannot have the same name:\"$compDir/images/$image\" and \"$tmp/images/$image\".\n");
          }
        }
        else {&Log("ERROR: Cannot open image directory \"$compDir/images\"\n");}
      }
      &copy_dir("$compDir/images", "$tmp/images", 1, 1);
    }
  }
  if (@skipCompanions) {
    # remove work elements of skipped companions or else the eBook converter will crash
    my $xml = $XML_PARSER->parse_file("$tmp/$MOD.xml");
    foreach my $c (@skipCompanions) {
      my @cn = $XPC->findnodes('//osis:work[@osisWork="'.$c.'"]', $xml);
      foreach my $cnn (@cn) {$cnn->parentNode()->removeChild($cnn);}
    }
    open(OUTF, ">$tmp/$MOD.xml");
    print OUTF $xml->toString();
    close(OUTF);
  }

  # run the converter
  &makeEbook("$tmp/$MOD.xml", 'epub', $cover, $scope, $tmp, $type);
  &makeEbook("$tmp/$MOD.xml", 'mobi', $cover, $scope, $tmp, $type);
  &makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp, $type);
}

# Look for a cover image in $dir matching $scope and return it if found. 
# The image file name may or may not be prepended with $MOD_, and may use
# either " " or "_" as scope delimiter.
sub findCover($$) {
  my $dir = shift;
  my $scope = shift;
  
  if (opendir(EBD, $dir)) {
    my @fs = readdir(EBD);
    closedir(EBD);
    my $bookOrderP;
    &getCanon($ConfEntryP->{"Versification"}, NULL, \$bookOrderP, NULL);
    foreach my $f (@fs) {
      my $fscope = $f;
      my $m = $MOD.'_';
      if ($fscope !~ s/^($m)?(.*?)\.jpg$/$2/i) {next;}
      $fscope =~ s/_/ /g;
      if ($scope eq $fscope) {return $f;}
      for my $s (@{&scopeToBooks($fscope, $bookOrderP)}) {if ($scope eq $s) {return $f;}}
    }
  }
  
  return NULL;
}

sub makeEbook($$$$$$) {
  my $osis = shift;
  my $format = shift; # “epub”, “mobi” or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  my $tmp = shift;
  my $type = shift;
  
  &Log("--- CREATING $format FROM $osis FOR ".($scope ? $scope:"ALL BOOKS")."\n", 1);
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  
  my $cmd = "$SCRD/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . &escfile($cover) . " >> ".&escfile("$TMPDIR/OUT_osis2ebooks.txt");
  &Log($cmd."\n");
  system($cmd);
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    my $name = ($scope ? $scope:($ConfEntryP->{"Scope"} ? $ConfEntryP->{"Scope"}:$MOD));
    if ($type) {$name .= "_" . $type;}
    $name .= ".$format";
    $name =~ s/\s/_/g;

    copy($out, "$EBOUT/$name");
    &Log("REPORT: Created output file: $name\n", 1);
  }
  else {&Log("ERROR: No output file: $out\n");}
}

sub ebookUpdateConf($$$) {
  my $convtxt = shift;
  my $osis = shift;
  my $title = shift;
  
  my %conv = &ebookReadConf($convtxt);
  
  if (!$title) {
    my $sep = "";
    
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
