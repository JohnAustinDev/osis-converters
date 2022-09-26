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

use strict;

# All code here is expected to be run on a Linux Ubuntu 14 to 18 or 
# compatible operating system having all osis-converters dependencies 
# already installed.

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($ROC, $XPC, $XML_PARSER, %OSIS_GROUP, $COVERS, $FONTS, %FONT_FILES, 
    @SUB_PUBLICATIONS, %ANNOTATE_TYPE, $ONS);

# Image file names in osis-converters should not contain spaces
sub checkImageFileNames {
  my $dir = shift;

  my $spaces = &shell("find '$dir' -type f -name '* *' -print", 3, 1);
  if ($spaces) {
    &Error(
"Image filenames must not contain spaces:\n$spaces",
"Remove or replace space characters in these image file names.");
  }
}

# Copy all images found in the OSIS or TEI file from projdir to outdir. 
# Return an array pointer with the relative paths (within the module)
# of each image. If osis_or_tei is passed as a reference, then a check 
# and update of the cover image's width (and possible conversion to png
# to allow a clear background) will be done as well.
sub copyReferencedImages {
  my $osis_or_tei_orP = shift;
  my $projdir = shift;
  my $outdir = shift;
  
  my @imgs;
  
  my $osis_or_tei = (ref($osis_or_tei_orP) ? $$osis_or_tei_orP:$osis_or_tei_orP);
  
  &Log("\n--- COPYING images in \"$osis_or_tei\"\n");
  
  $projdir =~ s/\/\s*$//;
  $outdir =~ s/\/\s*$//;
  
  my %copied;
  
  my $xml = $XML_PARSER->parse_file($osis_or_tei);
  my @images = $XPC->findnodes('//*[local-name()="figure"]', $xml);
  my $update;
  foreach my $image (@images) {
    my $src = $image->getAttribute('src');
    if ($src !~ s/^\.\///) {
      &Error("copyReferencedImages found a nonrelative path \"$src\".", 
"Image src paths specified by SFM \\fig tags need be relative paths (so they should begin with '.').");
      next;
    }
    
    my $path_orig = &getFigureLocalPath($image, $projdir);
    my $path = $path_orig;
    if (! -e $path) {
      &Error("copyReferencedImages: Image \"$src\" not found at \"$path\"", 
"Add the image to this image path.");
      next;
    }
    
    my $opath = "$outdir/$src";
    my $odir = $opath; $odir =~ s/\/[^\/]*$//;
    if (!-e $odir) {`mkdir -p "$odir"`;}
    
    # if osis_or_tei_orP is a reference, increase cover image width if it is very small
    my $pngTmp;
    if ( ref($osis_or_tei_orP) && 
         $image->getAttribute('type') eq "x-cover" && 
         &imageInfo($path)->{'w'} <= 200 ) {
      $pngTmp = $opath; $pngTmp =~ s/([^\/\\]+)$/tmp_$1/;
      if ($opath =~ s/\.(jpe?g|gif)$/\.png/i) {
        $pngTmp =~ s/\.(jpe?g|gif)$/\.png/
        &shell("convert \"$path\" \"$pngTmp\"");
        my $s = $image->getAttribute('src'); $s =~ s/\.(jpe?g|gif)$/\.png/i;
        $image->setAttribute('src', $s);
        $update++;
      }
      else {&copy($path, $pngTmp);}
      &changeImageWidth($pngTmp, 400, 'transparent');
      $path = $pngTmp;
    }
    
    if (-e $opath && $copied{$opath} ne $path_orig) {
      &Warn("Image already exists at with name: $opath", 
"If $copied{$opath} is different than $path_orig then you must change the name of one of the images.");
    }
    $copied{$opath} = $path_orig;
    
    &copy($path, $opath);
    &Note("Copied image \"$opath\"");
    if ($pngTmp) {unlink($pngTmp);}
    $opath =~ s/^\Q$outdir/\./;
    push (@imgs, $opath);
  }
  
  &Report("Copied \"".scalar(keys(%copied))."\" images to \"$outdir\".");
  
  if ($update) {
    &writeXMLFile($xml, $osis_or_tei_orP);
  }
  
  return \@imgs;
}

# Reads an OSIS file and looks for or creates cover images for the full
# OSIS file as well as any sub-publications within it. All referenced
# images will be located in $MAININPD/images. If replaceExisting is set,
# then pre-existing cover images are removed first. All these images
# are figure elements with type="x-cover" and subType="x-(comp|full|sub)-
# publication" where x-comp-publication is used for auto-generated comp-
# osite cover images.
sub addCoverImages {
  my $osisP = shift;
  my $replaceExisting = shift;

  my $coverWidth = 500;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my $mod = &getOsisModName($xml);
  my $vsys = &getOsisVersification($xml);
  my $updated;
  
  my @existing = $XPC->findnodes('//osis:figure[@type="x-cover"]', $xml);
  if (@existing[0]) {
    if (!$replaceExisting) {
      &Note("OSIS file already has x-cover image(s): $$osisP. Skipping addCoverImages()");
      return;
    }
    foreach my $ex (@existing) {$ex->unbindNode();}
  }
  
  &Log("\n--- INSERTING COVER IMAGES INTO \"$$osisP\"\n", 1);
  
  my $imgdir = "$MAININPD/images"; if (! -e $imgdir) {mkdir($imgdir);}
  
  # Find any sub-publication cover image(s) and insert them into the OSIS file
  my %done;
  my @pubcovers = ();
  foreach my $s (@SUB_PUBLICATIONS) {
    if ($done{$s}) {next;} else {$done{$s}++;}
    my $scope = $s; $scope =~ s/\s+/_/g;
    my $pubImagePath = &getCoverImageFromScope($mod, $scope);
    if (!$pubImagePath) {next;}
    push (@pubcovers, $pubImagePath);
    my $imgpath = "$imgdir/$scope.jpg";
    if ($pubImagePath ne $imgpath) {
      &shell("convert " .
        "-colorspace sRGB " .
        "-type truecolor " .
        "-resize ${coverWidth}x " .
        "\"$pubImagePath\" " .
        "\"$imgpath\"", 3);
    }
    &Note("Found sub-publication cover image: $imgpath");
    if (&insertSubpubCover($scope, &getCoverFigure($scope, 'sub'), $xml)) {
      $updated++;
    }
    else {&Warn(
"<-Failed to find introduction with scope $s to insert the cover image.",
"If you want the cover image to appear in the OSIS file, there 
needs to be a USFM \\id or \\periph tag that contains scope==$s
on the same line");
    }
  }
  
  # Find or create a main publication cover and insert it into the OSIS file
  my $scope = (&isChildrensBible($xml) ? 'Chbl' : @{$XPC->findnodes(
    "/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:scope", $xml)
    }[0]->textContent);
  if ($scope ne 'Chbl') {
    $scope = &booksToScope(&scopeToBooks($scope, $vsys), $vsys);
  }
  $scope =~ s/\s+/_/g;
  my $pubImagePath = &getCoverImageFromScope($mod, $scope);
  # Composite cover image names always end with _comp.jpg
  my $subType = ($pubImagePath && $pubImagePath =~ /_(comp)\.[^\.]+$/ ? $1:'full');
  if (!$pubImagePath && -e "$INPD/images/cover.jpg") {
    $pubImagePath = "$INPD/images/cover.jpg";
  }
  elsif (!$pubImagePath && -e "$INPD/ebooks/cover.jpg") {
    $pubImagePath = "$INPD/ebooks/cover.jpg";
    &Error("This cover location is deprecated: $pubImagePath.", "Move this image to $INPD/images");
  }
  elsif (!$pubImagePath && -e "$INPD/html/cover.jpg") {
    $pubImagePath = "$INPD/html/cover.jpg";
    &Error("This cover location is deprecated: $pubImagePath.", "Move this image to $INPD/images");
  }
  my $iname = $scope;
  if ($pubImagePath) {
    if ($pubImagePath !~ /\/([^\/\.]+)\.[^\/\.]+$/) {
      &ErrorBug("Bad pubImagePath: $pubImagePath !~ /\\/([^\\/]*)\\.[^\\/\\.]+\$/", 1);
    }
    $iname = $1;
  }
  my $imgpath = "$imgdir/$iname.jpg";
  if ($pubImagePath eq $imgpath) {
    &Note("Found full publication cover image: $imgpath");
  }
  elsif ($pubImagePath) {
    &shell("convert -colorspace sRGB -type truecolor -resize ${coverWidth}x \"$pubImagePath\" \"$imgpath\"", 3);
    &Note("Copying full publication cover image from $pubImagePath to: $imgpath");
  }
  elsif (@pubcovers) {
    my $title = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:title", $xml)}[0]->textContent;
    my $font = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$mod']/osis:description[\@type='x-config-Font']", $xml)}[0];
    $font = ($font ? $font->textContent:'');

    # Composite cover image names should end with _comp.jpg
    my $inew = "$imgdir/${scope}_comp.jpg";
    if (&createCompositeCoverImage(\@pubcovers, $inew, $title, $font)) {
      $subType = "comp";
      $iname = "${scope}_comp";
      $pubImagePath = $inew;
      &Note("Created full publication cover image from ".@pubcovers." sub-publication images with title $title: $inew");
    }
  }
  if ($pubImagePath && &insertTranCover(&getCoverFigure($iname, $subType), $xml)) {$updated++;}
  
  if (&isFolderEmpty($imgdir)) {rmdir($imgdir);}
  
  if ($updated) {&writeXMLFile($xml, $osisP);}
}

# Place one or more sub-publication cover figure elements in $xml.
# If a candidate location is marked as 'no' it will not receive a cover. 
# If a candidate location is marked as 'yes' it will receive a cover and
# only other candidates marked as 'yes' may additionally receive a cover. 
# Otherwise the first candidate alone will receive the cover.
sub insertSubpubCover {
  my $scope = shift;
  my $figure = shift;
  my $xml = shift;

  $scope =~ s/_/ /g;
  
  my $done;
  foreach my $div ($XPC->findnodes('//osis:div[@type][@scope="'.$scope.'"]
      [@annotateType="'.$ANNOTATE_TYPE{'cover'}.'"][@annotateRef="yes"]', $xml)) {
    $done |= &insertSubpubCoverInDiv($div, $figure, $scope);
  }
  if ($done) {return 1;}
  
  my $candidate = @{$XPC->findnodes('//osis:div[@type][@scope="'.$scope.'"]
      [ not( self::*[@annotateType="'.$ANNOTATE_TYPE{'cover'}.'"]
                    [@annotateRef="no"] ) 
      ][1]', $xml)}[0];

  return &insertSubpubCoverInDiv($candidate, $figure, $scope);
}

sub insertSubpubCoverInDiv {
  my $div = shift;
  my $figure = shift;
  my $scope = shift;
  
  my $clone = $figure->cloneNode(1);
  
  if (!$div) {return;}
  
  my $milestone = @{$XPC->findnodes(
    'child::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $div)}[0];
  if ($milestone) {
    $milestone->parentNode->insertAfter($clone, $milestone);
    &Note(
"Inserted sub-publication cover image after TOC milestone of div having scope=\"$scope\".");
    return 1;
  }
  elsif ($div) {
    $div->insertBefore($clone, $div->firstChild);
    &Note(
"Inserted sub-publication cover image as first child of div having scope=\"$scope\".");
    return 1;
  }
  
  return;
}

sub getCoverFigure {
  my $iname = shift;
  my $type = shift;  

  return $XML_PARSER->parse_balanced_chunk("<figure $ONS type='x-cover' ".
      "subType='x-$type-publication' src='./images/$iname.jpg' ".
      "resp='$ROC'> </figure>");
}


# The cover figure must be within a div to pass validation. Place it as
# the first child of the first div if it is not book(Group). Otherwise
# also create a new div of type x-cover.
sub insertTranCover {
  my $figure = shift;
  my $xml = shift;
  
  my $no = '@annotateType="'.$ANNOTATE_TYPE{'cover'}.'" and @annotateRef="no"';

  my $div = (
    &isChildrensBible($xml) ? 
    @{$XPC->findnodes("//osis:div[not($no)][1]", $xml)}[0] :
    @{$XPC->findnodes("//osis:header/following-sibling::*[not($no)][1]
      [self::osis:div][not(contains(\@type, 'book'))]", $xml)}[0]
  );
  if ($div) {
    $div->insertBefore($figure, $div->firstChild);
    &Note("Inserted publication cover image as first child of existing div type=".
      ($div->hasAttribute('type') ? $div->getAttribute('type'):'NO-TYPE'));
  }
  else {
    my $div = $XML_PARSER->parse_balanced_chunk("<div $ONS type='x-cover' resp='$ROC'>".
      $figure->toString()."</div>");
    my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
    $header->parentNode->insertAfter($div, $header);
    &Note("Inserted publication x-cover div after header.");
  }
}


# Returns the full path of a cover image for this module and scope, if
# one can be found. The following searches are done to look for a cover 
# image (the first found is used):
# 1) $INDP/images/<scoped-name>
# 2) $COVERS location (if any) looking for <scoped-name>
sub getCoverImageFromScope {
  my $mod = shift;
  my $scope = shift;
  
  $scope =~ s/\s+/_/g;
  
  my $cover = &findCover("$INPD/images", $mod, $scope);
  if (!$cover && $COVERS) {
    if ($COVERS =~ /^https?\:/) {$COVERS = &getURLCache('cover', $COVERS, 1, 12);}
    $cover = &findCover($COVERS, $mod, $scope);
  }
  
  return $cover;
}

# Look for a cover image in $dir matching $mod and $scope and return it 
# if found. The image file name may or may not be prepended with $mod_, 
# and may use either space or underscore as scope delimiter.
sub findCover {
  my $dir = shift;
  my $mod = shift;
  my $scope = shift;
  
  $scope =~ s/\s+/_/g;
  
  if (opendir(EBD, $dir)) {
    my @fs = readdir(EBD);
    closedir(EBD);
    foreach my $f (@fs) {
      my $fscope = $f;
      my $m = $mod.'_';
      if ($fscope !~ s/^($m)?(.*?)\.jpg$/$2/i) {next;}
      $fscope =~ s/_comp$//; # remove any composite marker to get scope
      if ($scope eq $fscope) {return "$dir/$f";}
    }
  }
  
  return '';
}

# Takes an array of images and creates a composite image by overlapping 
# small versions of each image over each other, translated by a certain 
# x/y offset.
sub createCompositeCoverImage {
  my $coversAP = shift;
  my $cover = shift;    # output image
  my $title = shift;    # title of output image
  my $font = shift;     # font for title
  
  if (!$title) {
    &ErrorBug("title parameter is required by createCompositeCoverImage()", 1);
  }
  
  my @sorted = sort  { &sortCoverImages($a, $b) } @{$coversAP};
  $coversAP = \@sorted;
 
  # adjustable constants
  my $nmx   =   5; # after this number of images, the composite image's width and height will grow linearly
  my $minxs =  20; # minimum x offset of images
  my $cw    = 360; # width of sub-images when there are two
  my $dw    = 500; # default width of composite image (actual width grows after $nmx images)
  
  # variables
  my $ni = scalar(@{$coversAP});                                    # number of images
  my $imgw = $dw + ($ni > $nmx ? $minxs*($ni-$nmx):0);              # width of composite image
  my $cf = 0; if ($ni <= $nmx) {$cf = ($imgw-$cw-$minxs)/($nmx-2);} # coefficient of overlap
  my $xs = ($minxs + $cf*($nmx-$ni)); my $ys = $xs;                 # x-step and y-step
  my $xw = $imgw - (($ni-1)*$xs);                                   # width of sub-images
  
  # get height of composite image (based on tallest sub-image)
  my $imgh = 0;
  for (my $j=0; $j<$ni; $j++) {
    my $dimP = &imageInfo(@{$coversAP}[$j]);
    my $sh = int($dimP->{'h'} * ($xw/$dimP->{'w'}));
    if ($imgh < $sh + ($ys*$j)) {$imgh = $sh + ($ys*$j);}
  }
  
  my $dissolve = "%100"; # in the end dissolve wasn't that great, so disable for now
  my $temp = "$TMPDIR/tmp.png";
  my $out = "$TMPDIR/cover.png"; # png allows dissolve to work right
  for (my $j=0; $j<$ni; $j++) {
    my $dimP = &imageInfo(@{$coversAP}[$j]);
    my $sh = int($dimP->{'h'} * ($xw/$dimP->{'w'}));
    &shell("convert -resize ${xw}x${sh} \"".@{$coversAP}[$j]."\" \"$temp\"", 3);
    if ($j == 0) {
      &shell("convert -size ${imgw}x${imgh} xc:None \"$temp\" -geometry +".($j*$xs)."+".($j*$ys)." -composite \"$out\"", 3);
    }
    else {
      &shell("composite".($j != ($ni-1) ? " -dissolve ".$dissolve:'')." \"$temp\" -geometry +".($j*$xs)."+".($j*$ys)." \"$out\" \"$out\"", 3);
    }
  }
  &shell("convert \"$out\" -colorspace sRGB -background White -flatten ".&imageCaption($imgw, $title, $font)." \"$cover\"", 3);
  if (-e $temp) {unlink($temp);}
  if (-e $out) {unlink($out);}
  
  return (-e $cover ? 1:0);
}

# Sort cover images. The last image will be fully visible when stacked. 
# Put OT first, in reverse book order. Put NT next, also reverse book 
# order.
sub sortCoverImages {
  my $a = shift;
  my $b = shift;
  
  my $ot = join(' ', @{$OSIS_GROUP{'OT'}});
  my $nt = join(' ', @{$OSIS_GROUP{'NT'}});
  
  my $sa = $a; $sa =~ s/^.*\///; $sa =~ s/\.[^\.]+$//; $sa =~ s/^([^\s_\-]+).*?$/$1/;
  my $sb = $b; $sb =~ s/^.*\///; $sb =~ s/\.[^\.]+$//; $sb =~ s/^([^\s_\-]+).*?$/$1/;
  my $iaOT = index($ot, $sa);
  my $ibOT = index($ot, $sb);
  my $iaNT = index($nt, $sa);
  my $ibNT = index($nt, $sb);
  
  if ($iaOT != -1) {
    if ($ibOT != -1) {
      return $ibOT <=> $iaOT;
    }
    return -1;
  }
  if ($iaNT != -1) {
    if ($ibNT != -1) {
      return $ibNT <=> $iaNT;
    }
    return 1;
  }
  return 0;
}

# Returns a portion of an ImageMagick command line for adding a cation to an image
sub imageCaption {
  my $width = shift;
  my $title = shift;
  my $font = shift;
  my $background = shift; if ($background) {$background =  " -background $background";}
  
  my $pointsize = (4/3)*$width/length($title);
  if ($pointsize > 40) {$pointsize = 40;}
  elsif ($pointsize < 10) {$pointsize = 10;}
  my $padding = 20;
  my $barheight = $pointsize + (2*$padding);
  my $foundfont = '';
  if ($font) {
    foreach my $f (sort keys %{$FONT_FILES{$font}}) {
      if ($FONT_FILES{$font}{$f}{'style'} eq 'regular') {
        $foundfont = "$FONTS/$f";
        last;
      }
    }
  }
  $title =~ s/"/\\"/g;
  return "-gravity North$background -splice 0x$barheight -pointsize $pointsize ".($foundfont ? "-font '$foundfont' ":'')."-annotate +0+$padding \"$title\"";
}

########################################################################
# Utility functions
########################################################################


# Returns a pointer to a hash containing information about an image
sub imageInfo {
  my $image = shift; # path to an image
  
  my %info;
  if (-e $image) {
    $info{'file'} = $image;     # path of image file
    $info{'size'} = -s $image;  # in bytes
    $info{'identify'} = &shell("identify \"$image\"", 3); # output of ImageMagick 'identify'
    if ($info{'identify'} =~ /^(\Q$image\E) (\S+) (\d+)x(\d+) (\S+) (\S+) (\S+)/) {
      $info{'format'} = $2;     # is PNG, JPEG, GIF etc.
      $info{'w'} = (1*$3);      # in pixels
      $info{'h'} = (1*$4);      # in pixels
      $info{'depth'} = $6;      # is 8-bit, 32-bit etc.
      $info{'colorspace'} = $7; # is Gray, sRGB, RGB etc.
    }
  }

  return \%info;
}

sub changeImageWidth {
  my $path = shift;
  my $w = shift;
  my $backgroundColor = shift;
  
  $backgroundColor = ($backgroundColor ? $backgroundColor:'white');
  
  &Note("Adjusted image size from ".&imageInfo($path)->{'w'}." to $w: $path");
  &shell("mogrify -gravity center -background $backgroundColor -extent $w \"$path\"", 3);
}

1;
