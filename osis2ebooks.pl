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

&osisXSLT("$OUTDIR/$MOD.xml", '', "$TMPDIR/".$MOD."_1.xml", 'eBook');
$OSISFILE = "$TMPDIR/".$MOD."_1.xml";

%EBOOKREPORT;
$EBOOKNAME;

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

if ($CREATE_FULL_BIBLE) {&setupAndMakeEbook($ConfEntryP->{"Scope"}, 'Full', '', $ConfEntryP);}

# make eBooks for any print publications that are part of the OSIS file (as specified in convert.txt: CreateFullPublicationN=scope)
if (@CREATE_FULL_PUBLICATIONS) {
  foreach my $x (@CREATE_FULL_PUBLICATIONS) {
    &setupAndMakeEbook($EBOOKCONV{'CreateFullPublication'.$x}, 'Full', $EBOOKCONV{'TitleFullPublication'.$x}, $ConfEntryP);
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
    if ($bk) {&setupAndMakeEbook($bk, 'Part', '', $ConfEntryP);}
  }
}

# REPORT results
&Log("\n$MOD REPORT: EBook files created (".scalar(keys %EBOOKREPORT)." instances):\n");
my @order = ('Format', 'Name', 'Title', 'Cover', 'Glossary', 'Filtered', 'ScripRefFilter', 'GlossRefFilter');
my %cm;
foreach my $c (@order) {$cm{$c} = length($c);}
foreach my $n (sort keys %EBOOKREPORT) {
  $EBOOKREPORT{$n}{'Name'} = $n;
  if (!$cm{$n} || length($EBOOKREPORT{$n}) > $cm{$n}) {$cm{$n} = length($EBOOKREPORT{$n});}
  foreach my $c (sort keys %{$EBOOKREPORT{$n}}) {
    if ($c eq 'Format') {$EBOOKREPORT{$n}{$c} = join(',', @{$EBOOKREPORT{$n}{$c}});}
    if (length($EBOOKREPORT{$n}{$c}) > $cm{$c}) {$cm{$c} = length($EBOOKREPORT{$n}{$c});}
  }
}
my $p; foreach my $c (@order) {$p .= "%-".($cm{$c}+4)."s ";} $p .= "\n";
&Log(sprintf($p, @order));
foreach my $n (sort keys %EBOOKREPORT) {
  my @a; foreach my $c (@order) {push(@a, $EBOOKREPORT{$n}{$c});}
  &Log(sprintf($p, @a));
}

&Log("\nend time: ".localtime()."\n");

########################################################################
########################################################################

sub setupAndMakeEbook($$$) {
  my $scope = shift;
  my $type = shift;
  my $titleOverride = shift;
  my $confP = shift;
  
  $EBOOKNAME = $scope;
  if ($type) {$EBOOKNAME .= "_" . $type;}
  $EBOOKNAME =~ s/\s/_/g;
  if ($EBOOKREPORT{$EBOOKNAME}) {
    &Log("ERROR: eBooks \"$EBOOKNAME\" were already created!\n");
  }
  
  my $scopeIsCompleteOSIS = ($scope eq $confP->{"Scope"});
  
  &Log("\n");
  
  my $tmp = "$TMPDIR/$scope";
  make_path($tmp);
    
  if ($scopeIsCompleteOSIS) {copy($OSISFILE, "$tmp/$MOD.xml");}
  else {&pruneFileOSIS($OSISFILE, "$tmp/$MOD.xml", $scope, $confP->{"Versification"});}
  
  # copy convert.txt
  copy("$INPD/eBook/convert.txt", "$tmp/convert.txt");
  if (!$scopeIsCompleteOSIS) {
    $titleOverride = &ebookUpdateConf("$tmp/convert.txt", "$tmp/$MOD.xml", $titleOverride);
    %EBOOKCONV = &ebookReadConf("$tmp/convert.txt");
  }
  
  # copy css directory (css directory is the last of the following)
  my $css = "$SCRD/eBooks/css";
  if (-e "$INPD/../defaults/eBook/css") {$css = "$INPD/../defaults/eBook/css";}
  elsif (-e "$INPD/../../defaults/eBook/css") {$css = "$INPD/../../defaults/eBook/css";}
  elsif (-e "$INPD/eBook/css-default") {$css = "$INPD/eBook/css-default";}
  copy_dir($css, "$tmp/css");
  # module css is added to default css directory
  if (-e "$INPD/eBook/css") {copy_dir("$INPD/eBook/css", "$tmp/css", 1);}
  
  # copy cover
  my $cover;
  # Cover name is a jpg image named $scope if it exists, or else an 
  # existing jpg image whose name (which is a scope) includes $scope. 
  # Or it's just 'cover.jpg' by default
  my $covname = &findCover("$INPD/eBook", $scope, $confP->{"Versification"});
  if (!-e "$INPD/eBook/$covname") {$covname = 'cover.jpg';}
  if (-e "$INPD/eBook/$covname") {
    $cover = "$tmp/cover.jpg";
    if (!$scopeIsCompleteOSIS && $type eq 'Part') {
      # add specific title to the top of the eBook cover image
      $EBOOKREPORT{$EBOOKNAME}{'Title'} = $titleOverride;
      $EBOOKREPORT{$EBOOKNAME}{'Cover'} = $covname;
      my $imagewidth = `identify "$INPD/eBook/$covname"`; $imagewidth =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $imagewidth = (1*$imagewidth);
      my $pointsize = (4/3)*$imagewidth/length($titleOverride);
      if ($pointsize > 40) {$pointsize = 40;}
      elsif ($pointsize < 10) {$pointsize = 10;}
      my $padding = 20;
      my $barheight = $pointsize + (2*$padding) - 10;
      my $cmd = "convert \"$INPD/eBook/$covname\" -gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize -annotate +0+$padding '$titleOverride' \"$cover\"";
      &Log("$cmd\n");
      `$cmd`;
    }
    else {
      $EBOOKREPORT{$EBOOKNAME}{'Title'} = 'no-title';
      $EBOOKREPORT{$EBOOKNAME}{'Cover'} = $covname;
      copy("$INPD/eBook/$covname", $cover);
    }
  }
  else {
    $EBOOKREPORT{$EBOOKNAME}{'Title'} = $EBOOKCONV{'Title'};
    $EBOOKREPORT{$EBOOKNAME}{'Cover'} = 'random-cover';
  }
  
  my @skipCompanions;
  my @companionDictFiles;
  foreach my $companion (split(/\s*,\s*/, $confP->{'Companion'})) {
    # copy companion OSIS file
    my $outf;
    my $outd = $OUTDIR;
    $outd =~ s/$MOD/$companion/;
    if (-e "$outd/$companion.xml") {$outf = "$outd/$companion.xml";}
    elsif (-e "$INPD/$companion/output/$companion.xml") {$outf = "$INPD/$companion/output/$companion.xml";}
    else {&Log("ERROR: Companion dictionary \"$companion\" was specified in config.conf, but its OSIS file was not found.\n");}
    my $filter = '0';
    if ($outf) {
      &osisXSLT($outf, '', "$tmp/$companion.xml", "$companion/eBook");
      if ($companion =~ /DICT$/) {
        require "$SCRD/scripts/processGlossary.pl";
        # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
        # This means any non Bible scopes (like SWORD) are also filtered out.
        $filter = &filterGlossaryToScope("$tmp/$companion.xml", $scope);
        if ($filter eq '-1') { # '-1' means all glossary divs were filtered out
          push(@skipCompanions, $companion);
          unlink("$tmp/$companion.xml");
          $EBOOKREPORT{$EBOOKNAME}{'Glossary'} = 'no-glossary';
          $EBOOKREPORT{$EBOOKNAME}{'Filtered'} = 'all';
          next;
        }
        else {push(@companionDictFiles, "$tmp/$companion.xml");}
      }
    }
    
    $EBOOKREPORT{$EBOOKNAME}{'Glossary'} = $companion;
    $EBOOKREPORT{$EBOOKNAME}{'Filtered'} = ($filter eq '0' ? 'none':$filter);
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
  
  # copy over only those images referenced in our OSIS files
  &copyReferencedImages("$tmp/$MOD.xml", $INPD, $tmp);
  foreach my $osis (@companionDictFiles) {
    my $companion = $osis; $companion =~ s/^.*\/([^\/\.]+)\.[^\.]+$/$1/;
    &copyReferencedImages($osis, &findCompanionDirectory($companion), $tmp);
  }
  
  # filter out any and all references pointing to targets outside our final OSIS file scopes
  $EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} = 0;
  $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} = 0;
  if (!$scopeIsCompleteOSIS) {$EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences("$tmp/$MOD.xml", "$tmp/$MOD.xml");}
  $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", @companionDictFiles);
  
  foreach my $c (@companionDictFiles) {
    if (!$scopeIsCompleteOSIS) {$EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences($c, "$tmp/$MOD.xml");}
    $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences($c, @companionDictFiles);
  }

  # run the converter
  if (!$DEBUG || $DEBUG =~ /epub/i) {&makeEbook("$tmp/$MOD.xml", 'epub', $cover, $scope, $tmp, $type);}
  if (!$DEBUG || $DEBUG =~ /mobi/i) {&makeEbook("$tmp/$MOD.xml", 'mobi', $cover, $scope, $tmp, $type);}
  if (!$DEBUG || $DEBUG =~ /fb2/i) {&makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp, $type);}
}

# Look for a cover image in $dir matching $scope and return it if found. 
# The image file name may or may not be prepended with $MOD_, and may use
# either " " or "_" as scope delimiter.
sub findCover($$) {
  my $dir = shift;
  my $scope = shift;
  my $vsys = shift;
  
  if (opendir(EBD, $dir)) {
    my @fs = readdir(EBD);
    closedir(EBD);
    my $bookOrderP;
    &getCanon($vsys, NULL, \$bookOrderP, NULL);
    foreach my $f (@fs) {
      my $fscope = $f;
      my $m = $MOD.'_';
      if ($fscope !~ s/^($m)?(.*?)\.jpg$/$2/i) {next;}
      $fscope =~ s/_/ /g;
      if ($scope eq $fscope) {return $f;}
      # if scopes are not a perfect match, then the scope of the eBook is assumed to be a single book!
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
  
  &Log("--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  
  my $cmd = "$SCRD/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . &escfile($cover) . " >> ".&escfile("$TMPDIR/OUT_osis2ebooks.txt");
  &Log($cmd."\n");
  system($cmd);
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    copy($out, "$EBOUT/$EBOOKNAME.$format");
    if (!$EBOOKREPORT{$EBOOKNAME}{'Format'}) {$EBOOKREPORT{$EBOOKNAME}{'Format'} = ();}
    push(@{$EBOOKREPORT{$EBOOKNAME}{'Format'}}, $format);
    &Log("Created: $EBOOKNAME.$format\n", 2);
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
