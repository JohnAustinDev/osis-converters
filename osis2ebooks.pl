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

&userXSLT("$INPD/eBook/preprocess.xsl", "$OUTDIR/$MOD.xml", "$TMPDIR/".$MOD."_1.xml");
$OSISFILE = "$TMPDIR/".$MOD."_1.xml";
$OSISFILE_XML = $XML_PARSER->parse_file($OSISFILE);

%EBOOKREPORT;
$EBOOKNAME;

# get scope and vsys of OSIS file
&setConfGlobals(&updateConfData($ConfEntryP, $OSISFILE));

%EBOOKCONV = &ebookReadConf("$INPD/eBook/convert.txt");

$CREATE_FULL_BIBLE = (!defined($EBOOKCONV{'CreateFullBible'}) || $EBOOKCONV{'CreateFullBible'} !~ /^(false|0)$/i);
$CREATE_SEPARATE_BOOKS = (!defined($EBOOKCONV{'CreateSeparateBooks'}) || $EBOOKCONV{'CreateSeparateBooks'} !~ /^(false|0)$/i);
@CREATE_FULL_PUBLICATIONS = (); foreach my $k (sort keys %EBOOKCONV) {if ($k =~ /^CreateFullPublication(\d+)$/) {push(@CREATE_FULL_PUBLICATIONS, $1);}}

# make an eBook with the entire OSIS file
if ($CREATE_FULL_BIBLE) {&setupAndMakeEbook($ConfEntryP->{"Scope"}, 'Full', '', $ConfEntryP);}

# make eBooks for any print publications that are part of the OSIS file (as specified in convert.txt: CreateFullPublicationN=scope)
if (@CREATE_FULL_PUBLICATIONS) {
  foreach my $x (@CREATE_FULL_PUBLICATIONS) {
    my $scope = $EBOOKCONV{'CreateFullPublication'.$x}; $scope =~ s/_/ /g;
    &setupAndMakeEbook($scope, 'Full', $EBOOKCONV{'TitleFullPublication'.$x}, $ConfEntryP);
  }
}

# also make separate eBooks from each Bible book within the OSIS file
if ($CREATE_SEPARATE_BOOKS) {
  @allBooks = $XPC->findnodes('//osis:div[@type="book"]', $OSISFILE_XML);
  BOOK: foreach my $aBook (@allBooks) {
    my $bk = $aBook->getAttribute('osisID');
    # don't create this ebook if an identical ebook has already been created
    foreach my $x (@CREATE_FULL_PUBLICATIONS) {
      if ($bk && $bk eq $EBOOKCONV{'CreateFullPublication'.$x}) {next BOOK;}
    }
    if ($CREATE_FULL_BIBLE && $ConfEntryP->{"Scope"} eq $bk) {next BOOK;}
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
  
  &Log("\n-----------------------------------------------------\nMAKING EBOOK: scope=$scope, type=$type, titleOverride=$titleOverride\n", 1);
  
  $EBOOKNAME = $scope;
  if ($type) {$EBOOKNAME .= "_" . $type;}
  $EBOOKNAME =~ s/\s/_/g;
  if ($EBOOKREPORT{$EBOOKNAME}) {
    &Log("ERROR: eBooks \"$EBOOKNAME\" were already created!\n");
  }
  
  &Log("\n");
  
  my $tmp = "$TMPDIR/$scope";
  make_path($tmp);
  
  my $ebookTitle = ($titleOverride ? $titleOverride:$EBOOKCONV{'Title'}); # title will usually still be '' at this point
  my $ebookTitlePart;
  &pruneFileOSIS($OSISFILE, "$tmp/$MOD.xml", $scope,
    $confP,
    \%EBOOKCONV,
    \$ebookTitle, 
    \$ebookTitlePart);
  
  # copy convert.txt
  copy("$INPD/eBook/convert.txt", "$tmp/convert.txt");
  
  # copy css directory (css directory is the last of the following)
  my $css = "$SCRD/eBooks/css";
  if (-e "$INPD/../defaults/eBook/css") {$css = "$INPD/../defaults/eBook/css";}
  elsif (-e "$INPD/../../defaults/eBook/css") {$css = "$INPD/../../defaults/eBook/css";}
  elsif (-e "$INPD/eBook/css-default") {$css = "$INPD/eBook/css-default";}
  copy_dir($css, "$tmp/css");
  # module css is added to default css directory
  if (-e "$INPD/eBook/css") {copy_dir("$INPD/eBook/css", "$tmp/css", 1);}
  
  # if font is specified, include it
  if ($FONTS && $confP->{"Font"}) {
    &copyFont($confP->{"Font"}, $FONTS, \%FONT_FILES, "$tmp/css", 1);
    if (open(CSS, ">$tmp/css/font.css")) {
      my %font_format = ('ttf' => 'truetype', 'otf' => 'opentype', 'woff' => 'woff');
      foreach my $f (keys %{$FONT_FILES{$confP->{"Font"}}}) {
        my $format = $font_format{lc($FONT_FILES{$confP->{"Font"}}{$f}{'ext'})};
        if (!$format) {&Log("WARNNG: Font \"$f\" has an unknown format; src format will not be specified.\n");}
        print CSS '
@font-face {
  font-family:font1;
  src: url(\'./'.$f.'\')'.($format ? ' format(\''.$format.'\')':'').';
  font-weight: '.($FONT_FILES{$confP->{"Font"}}{$f}{'style'} =~ /bold/i ? 'bold':'normal').'; font-style: '.($FONT_FILES{$confP->{"Font"}}{$f}{'style'} =~ /italic/i ? 'italic':'normal').';
}
';
      }
      print CSS '
body {font-family: font1;}

';
      if (open(FCSS, "<$FONTS/".$confP->{"Font"}.".eBook.css")) {while(<FCSS>) {print CSS $_;} close(FCSS);}
      close(CSS);
    }
    else {&Log("ERROR: Could not write font css to \"$tmp/css/font.css\"\n");}
  }
  
  # copy cover
  my $cover;
  # Cover name is a jpg image named $scope if it exists, or else an 
  # existing jpg image whose name (which is a scope) includes $scope. 
  # Or it's just 'cover.jpg' by default
  my $titleType = $type;
  my $covname = &findCover("$INPD/eBook", $scope, $confP->{"Versification"}, \$titleType);
  if (!-e "$INPD/eBook/$covname") {$covname = 'cover.jpg';}
  if (-e "$INPD/eBook/$covname") {
    $cover = "$tmp/cover.jpg";
    if ($titleType eq 'Part') {
      # add specific title to the top of the eBook cover image
      $EBOOKREPORT{$EBOOKNAME}{'Title'} = $ebookTitlePart;
      $EBOOKREPORT{$EBOOKNAME}{'Cover'} = $covname;
      my $imagewidth = `identify "$INPD/eBook/$covname"`; $imagewidth =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $imagewidth = (1*$imagewidth);
      my $pointsize = (4/3)*$imagewidth/length($ebookTitlePart);
      if ($pointsize > 40) {$pointsize = 40;}
      elsif ($pointsize < 10) {$pointsize = 10;}
      my $padding = 20;
      my $barheight = $pointsize + (2*$padding) - 10;
      my $cmd = "convert \"$INPD/eBook/$covname\" -gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize -annotate +0+$padding '$ebookTitlePart' \"$cover\"";
      &shell($cmd, 2);
    }
    else {
      $EBOOKREPORT{$EBOOKNAME}{'Title'} = 'no-title';
      $EBOOKREPORT{$EBOOKNAME}{'Cover'} = $covname;
      copy("$INPD/eBook/$covname", $cover);
    }
  }
  else {
    $EBOOKREPORT{$EBOOKNAME}{'Title'} = $ebookTitle;
    $EBOOKREPORT{$EBOOKNAME}{'Cover'} = 'random-cover';
  }
  
  my @skipCompanions;
  my @companionDictFiles;
  foreach my $companion (split(/\s*,\s*/, $confP->{'Companion'})) {
    # copy companion OSIS file
    my $outf = &getProjectOsisFile($companion);
    my $filter = '0';
    if ($outf) {
      &userXSLT("$INPD/$companion/eBook/preprocess.xsl", $outf, "$tmp/$companion.xml");
      if ($companion =~ /DICT$/) {
        require "$SCRD/scripts/processGlossary.pl";
        # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
        # This means any non Bible scopes (like SWORD) are also filtered out.
        $filter = &filterGlossaryToScope("$tmp/$companion.xml", $scope);
        &Log("NOTE: filterGlossaryToScope('$scope') filtered: ".($filter eq '-1' ? 'everything':($filter eq '0' ? 'nothing':$filter))."\n");
        my $aggfilter = &filterAggregateEntries("$tmp/$companion.xml", $scope);
        &Log("NOTE: filterAggregateEntries('$scope') filtered: ".($aggfilter eq '-1' ? 'everything':($aggfilter eq '0' ? 'nothing':$aggfilter))."\n");
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
    my $xml = $XML_PARSER->parse_file("$tmp/$MOD.xml");
    # remove work elements of skipped companions or else the eBook converter will crash
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
  
  my $tocxr = ($tocCrossRefs ? (1*$tocCrossRefs):3);
  my $hasAllBookAbbreviations = (66 == scalar(@{$XPC->findnodes('//osis:div[@type="book"][descendant::osis:milestone[@type="x-usfm-toc'.$tocxr.'"]]', $OSISFILE_XML)}));
  
  # filter out any and all references pointing to targets outside our final OSIS file scopes
  $EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} = 0;
  $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} = 0;
  $EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences("$tmp/$MOD.xml", "$tmp/$MOD.xml", $OSISFILE, $hasAllBookAbbreviations);
  $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", \@companionDictFiles, 1);
  
  foreach my $c (@companionDictFiles) {
    $EBOOKREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences($c, "$tmp/$MOD.xml", $OSISFILE, $hasAllBookAbbreviations);
    $EBOOKREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences($c, \@companionDictFiles, 1);
  }

  # run the converter
  if ($DEBUG !~ /no.epub/i) {&makeEbook("$tmp/$MOD.xml", 'epub', $cover, $scope, $tmp);}
  if ($DEBUG !~ /no.azw3/i) {&makeEbook("$tmp/$MOD.xml", 'azw3', $cover, $scope, $tmp);}
  # fb2 is disabled until a decent FB2 converter is written
  # &makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp);
}

# Look for a cover image in $dir matching $scope and return it if found. 
# The image file name may or may not be prepended with $MOD_, and may use
# either " " or "_" as scope delimiter.
sub findCover($$\$) {
  my $dir = shift;
  my $scope = shift;
  my $vsys = shift;
  my $titleTypeP = shift;
  
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
      if ($scope eq $fscope) {
        $$titleTypeP = "Full"; 
        return $f;
      }
      # if scopes are not a perfect match, then the scope of the eBook is assumed to be a single book!
      for my $s (@{&scopeToBooks($fscope, $bookOrderP)}) {
        if ($scope eq $s) {
          $$titleTypeP = "Part";
          return $f;
        }
      }
    }
  }
  
  return NULL;
}

sub makeEbook($$$$$) {
  my $osis = shift;
  my $format = shift; # “epub”, "azw3" or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  my $tmp = shift;
  
  &Log("--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  
  my $cmd = "$SCRD/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . &escfile($cover) . " >> ".&escfile("$TMPDIR/OUT_osis2ebooks.txt");
  &shell($cmd);
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    if ($format eq 'epub') {
      my $epub3Markup = (!($EBOOKCONV{'NoEpub3Markup'} =~ /^(true)$/i));
      $cmd = "epubcheck \"$out\"";
      my $result = &shell($cmd, ($epub3Markup ? 3:0));
      if ($result =~ /^\s*$/) {
        &Log("ERROR: epubcheck did not return anything- reason unknown\n");
      }
      elsif ($result !~ /\bno errors\b/i) {
        my $failed = 1;
        if ($epub3Markup) {
          $result =~ s/^[^\n]*attribute "epub:type" not allowed here[^\n]*\n//mg;
          if ($result =~ /ERROR/) {&Log($result);}
          else {
            $failed = 0;
            &Log("NOTE: Epub validates, other than the existence of epub:type: \"$out\"\n");
          }
        }
        if ($failed) {&Log("ERROR: epubcheck validation failed for \"$out\"\n");}
      }
      else {&Log("NOTE: Epub validates!: \"$out\"\n");}
    }
    copy($out, "$EBOUT/$EBOOKNAME.$format");
    if (!$EBOOKREPORT{$EBOOKNAME}{'Format'}) {$EBOOKREPORT{$EBOOKNAME}{'Format'} = ();}
    push(@{$EBOOKREPORT{$EBOOKNAME}{'Format'}}, $format);
    &Log("Created: $EBOOKNAME.$format\n", 2);
  }
  else {&Log("ERROR: No output file: $out\n");}
}

1;
