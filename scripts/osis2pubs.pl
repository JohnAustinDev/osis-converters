#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2018 John Austin (gpl.programs.info@gmail.com)
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

# Converts an OSIS file into possibly a number of different ePublications 
# of type $convertTo, where each ePublication covers a different Bible-scope. 
sub osis2pubs($) {
  my $convertTo = shift;
  if ($convertTo !~ /^(eBook|html)$/) {
    &ErrorBug("convertOSIS: Conversion of OSIS to \"$convertTo\" is not yet supported.");
  }

  &runAnyUserScriptsAt("$convertTo/preprocess", \$INOSIS);
  
  &Log("Updating OSIS header.\n");
  &writeOsisHeader(\$INOSIS);
  
  # Global for result reporting
  %CONV_REPORT;

  # Constants used by this script
  $INOSIS_XML = $XML_PARSER->parse_file($INOSIS);
  $IS_CHILDRENS_BIBLE = &isChildrensBible($INOSIS_XML);
  $CREATE_FULL_TRANSLATION = (&conf('CreateFullBible') !~ /^false$/i);
  $CREATE_SEPARATE_BOOKS = (&conf('CreateSeparateBooks') !~ /^false$/i);
  $FULLSCOPE = ($IS_CHILDRENS_BIBLE ? '':&getScopeOSIS($INOSIS_XML)); # Children's Bibles must have empty scope for pruneFileOSIS() to work right
  $SERVER_DIRS_HP = ($EBOOKS =~ /^https?\:\/\// ? &readServerScopes("$EBOOKS/$MAINMOD/$MAINMOD"):'');
  $TRANPUB_SUBDIR = $SERVER_DIRS_HP->{$FULLSCOPE};
  $TRANPUB_TYPE = 'Tran'; foreach my $s (@SUB_PUBLICATIONS) {if ($s eq $FULLSCOPE) {$TRANPUB_TYPE = 'Full';}}
  $TRANPUB_TITLE = ($TRANPUB_TYPE eq 'Tran' ? &conf('TranslationTitle'):&conf("TitleSubPublication[$FULLSCOPE]"));
  if (!$TRANPUB_TITLE) {$TRANPUB_TITLE = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$MAINMOD']/osis:title", $INOSIS_XML)}[0]; $TRANPUB_TITLE = ($TRANPUB_TITLE ? $TRANPUB_TITLE->textContent:'');}
  $TRANPUB_NAME = &getFullEbookName($IS_CHILDRENS_BIBLE, $TRANPUB_TITLE, $FULLSCOPE, $TRANPUB_TYPE);

  # Global variables
  $PUB_SUBDIR = $TRANPUB_SUBDIR;
  $PUB_NAME   = $TRANPUB_NAME;
  $PUB_TYPE   = $TRANPUB_TYPE;
  
  if ($IS_CHILDRENS_BIBLE) {&OSIS_To_ePublication($convertTo, $TRANPUB_TITLE);}
  else {
    my %eBookSubDirs; my %parentPubScope; my $bookOrderP;
    &getCanon(&conf("Versification"), NULL, \$bookOrderP, NULL);
    
    # convert the entire OSIS file
    if ($PUB_TYPE eq 'Tran') {
      $eBookSubDirs{$FULLSCOPE} = $SERVER_DIRS_HP->{$FULLSCOPE};
      foreach my $bk (@{&scopeToBooks($FULLSCOPE, $bookOrderP)}) {$parentPubScope{$bk} = $FULLSCOPE;}
      if ($CREATE_FULL_TRANSLATION) {&OSIS_To_ePublication($convertTo, $TRANPUB_TITLE, $FULLSCOPE);}
    }
    
    # convert any sub publications that are part of the OSIS file
    foreach my $scope (@SUB_PUBLICATIONS) {
      my $pscope = $scope; $pscope =~ s/\s/_/g;
      $PUB_TYPE = 'Full';
      $eBookSubDirs{$scope} = $SERVER_DIRS_HP->{$scope};
      foreach my $bk (@{&scopeToBooks($scope, $bookOrderP)}) {$parentPubScope{$bk} = $scope;}
      if ($scope eq $FULLSCOPE && !$CREATE_FULL_TRANSLATION) {next;}
      if ($convertTo ne 'html') {
        $PUB_SUBDIR = $eBookSubDirs{$scope};
        $PUB_NAME = ($scope eq $FULLSCOPE ? $TRANPUB_NAME:&getEbookName($scope, $PUB_TYPE));
        &OSIS_To_ePublication($convertTo, &conf("TitleSubPublication[".$pscope."]"), $scope); 
      }
    }

    # convert each Bible book within the OSIS file
    if ($CREATE_SEPARATE_BOOKS) {
      $PUB_TYPE = 'Part';
      foreach my $aBook ($XPC->findnodes('//osis:div[@type="book"]', $INOSIS_XML)) {
        my $bk = $aBook->getAttribute('osisID');
        if (defined($eBookSubDirs{$bk})) {next;}
        $PUB_SUBDIR = $eBookSubDirs{$parentPubScope{$bk}};
        $PUB_NAME = &getEbookName($bk, $PUB_TYPE);
        my $pscope = $parentPubScope{$bk}; $pscope =~ s/\s/_/g;
        my $title = ($pscope ? &conf("TitleSubPublication[".$pscope."]"):$TRANPUB_TITLE);
        &OSIS_To_ePublication($convertTo, $title, $bk);
      }
    }
  }

  # REPORT results
  &Log("\n");
  &Report(uc($convertTo)." files created (".scalar(keys %CONV_REPORT)." instances):");
  my @order = ('Format', 'Name', 'Cover', 'Glossary', 'Filtered', 'ScripRefFilter', 'GlossRefFilter');
  my %cm;
  foreach my $c (@order) {$cm{$c} = length($c);}
  foreach my $n (sort keys %CONV_REPORT) {
    $CONV_REPORT{$n}{'Name'} = $n;
    if (!$cm{$n} || length($CONV_REPORT{$n}) > $cm{$n}) {$cm{$n} = length($CONV_REPORT{$n});}
    foreach my $c (sort keys %{$CONV_REPORT{$n}}) {
      if ($c eq 'Format') {$CONV_REPORT{$n}{$c} = join(',', @{$CONV_REPORT{$n}{$c}});}
      if (length($CONV_REPORT{$n}{$c}) > $cm{$c}) {$cm{$c} = length($CONV_REPORT{$n}{$c});}
    }
  }
  my $p; foreach my $c (@order) {$p .= "%-".($cm{$c}+4)."s ";} $p .= "\n";
  &Log(sprintf($p, @order));
  foreach my $n (sort keys %CONV_REPORT) {
    my @a; foreach my $c (@order) {push(@a, $CONV_REPORT{$n}{$c});}
    &Log(sprintf($p, @a));
  }
}



########################################################################
########################################################################

sub OSIS_To_ePublication($$$) {
  my $convertTo = shift; # type of ePublication to output (html or eBook)
  my $pubTitle = shift; # title of ePublication
  my $scope = shift; # scope of ePublication
  
  my $pscope = $scope; $pscope =~ s/\s/_/g;

  if ($CONV_REPORT{$PUB_NAME}) {
    &ErrorBug("$convertTo \"$PUB_NAME\" already created!");
  }
  
  &Log("\n-----------------------------------------------------\nMAKING ".uc($convertTo).": scope=$scope, type=$PUB_TYPE, name=$PUB_NAME, subdir='$PUB_SUBDIR'\n\n", 1);
  
  my $tmp = $pscope; $tmp = ($tmp ? "$TMPDIR/$tmp":$TMPDIR);
  make_path("$tmp/tmp/bible");
  my $osis = "$tmp/tmp/bible/$MOD.xml";
  &copy($INOSIS, $osis);
  
  my $partTitle;
  if (!$IS_CHILDRENS_BIBLE) {
    &pruneFileOSIS(
      \$osis,
      $scope,
      $CONF,
      \$pubTitle, 
      \$partTitle
    );
  }
  
  my $cover = "$tmp/cover.jpg";
  my $coverSource = &copyCoverTo(\$osis, $cover);
  if (!$coverSource) {$cover = '';}
  $CONV_REPORT{$PUB_NAME}{'Cover'} = '';
  if ($cover) {
    if ($PUB_TYPE eq 'Part') {
      &shell("mogrify ".&imageCaption(&imageInfo($cover)->{'w'}, $partTitle, &conf("Font"), 'LightGray')." \"$cover\"", 3);
    }
    my $coverSourceName = $coverSource; $coverSourceName =~ s/^.*\///;
    $CONV_REPORT{$PUB_NAME}{'Cover'} = $coverSourceName . ($PUB_TYPE eq 'Part' ? " ($partTitle)":''); 
  }
  else {
    $CONV_REPORT{$PUB_NAME}{'Cover'} = "random-cover ($pubTitle)";
  }
    
  &runXSLT("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", $osis, "$tmp/$MOD.xml");
  
  # copy osis2xhtml.xsl
  copy("$SCRD/scripts/bible/html/osis2xhtml.xsl", $tmp);
  copy("$SCRD/scripts/functions.xsl", $tmp);
  
  # copy css file(s): always copy html.css and then if needed also copy $convertTo.css if it exists
  mkdir("$tmp/css");
  my $css = &getDefaultFile(($IS_CHILDRENS_BIBLE ? 'childrens_bible':'bible')."/html/css/html.css", -1);
  if ($css) {&copy($css, "$tmp/css/00html.css");}
  if ($convertTo ne 'html') {
    $css = &getDefaultFile(($IS_CHILDRENS_BIBLE ? 'childrens_bible':'bible')."/$convertTo/css/$convertTo.css", -1);
    if ($css) {&copy($css, "$tmp/css/01$convertTo.css");}
  }
  # copy font if specified
  if ($FONTS && &conf("Font")) {
    &copyFont(&conf("Font"), $FONTS, \%FONT_FILES, "$tmp/css", 1);
    # The following allows Calibre to embed fonts (which must be installed locally) when 
    # the '--embed-all-fonts' flag is used with ebook-convert. This has been commented out
    # (and the flag removed from ebook-convert) because embeded fonts are unnecessary 
    # when font files are explicitly provided, and embeding never worked right anyway.
    #&shell("if [ -e ~/.fonts ]; then echo Font directory exists; else mkdir ~/.fonts; fi", 3);
    #my $home = &shell("echo \$HOME", 3); chomp($home);
    #&Note("Calibre can only embed fonts that are installed. Installing ".&conf("Font")." to host.");
    #&copyFont(&conf("Font"), $FONTS, \%FONT_FILES, "$home/.fonts");
    if (open(CSS, ">$WRITELAYER", "$tmp/css/10font.css")) {
      my %font_format = ('ttf' => 'truetype', 'otf' => 'opentype', 'woff' => 'woff');
      foreach my $f (sort keys %{$FONT_FILES{&conf("Font")}}) {
        my $format = $font_format{lc($FONT_FILES{&conf("Font")}{$f}{'ext'})};
        if (!$format) {&Log("WARNNG: Font \"$f\" has an unknown format; src format will not be specified.\n");}
        print CSS '
@font-face {
  font-family:font1;
  src: url(\''.($convertTo eq 'eBook' ? './':'/css/').$f.'\')'.($format ? ' format(\''.$format.'\')':'').';
  font-weight: '.($FONT_FILES{&conf("Font")}{$f}{'style'} =~ /bold/i ? 'bold':'normal').'; font-style: '.($FONT_FILES{&conf("Font")}{$f}{'style'} =~ /italic/i ? 'italic':'normal').';
}
';
      }
      print CSS '
body {font-family: font1;}

';
      if (open(FCSS, "<$READLAYER", "$FONTS/".&conf("Font").".eBook.css")) {while(<FCSS>) {print CSS $_;} close(FCSS);}
      close(CSS);
    }
    else {&ErrorBug("Could not write font css to \"$tmp/css/10font.css\"");}
  }
  
  # copy companion OSIS DICT
  my $dictTmpOsis; # even if $DICTMOD is set, $dictTmpOsis will be unset when all glossaries are filtered from $DICTMOD
  if ($DICTMOD) {
    if (! -e "$tmp/tmp/dict") {make_path("$tmp/tmp/dict");}
    my $outf = &getModuleOsisFile($DICTMOD, 'Error');
    my $filter = '0';
    if ($outf) {
      &copy($outf, "$tmp/tmp/dict/$DICTMOD.xml"); $outf = "$tmp/tmp/dict/$DICTMOD.xml";
      &runAnyUserScriptsAt("$DICTMOD/$convertTo/preprocess", \$outf);
      &runScript("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", \$outf);
      require "$SCRD/scripts/dict/processGlossary.pl";
      # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
      # This means any non Bible scopes (like SWORD) are also filtered out.
      $filter = &filterGlossaryToScope(\$outf, $scope, ($convertTo eq 'eBook'));
      &Note("filterGlossaryToScope('$scope') filtered: ".($filter eq '-1' ? 'everything':($filter eq '0' ? 'nothing':$filter)));
      my $aggfilter = &filterAggregateEntries(\$outf, $scope);
      &Note("filterAggregateEntries('$scope') filtered: ".($aggfilter eq '-1' ? 'everything':($aggfilter eq '0' ? 'nothing':$aggfilter)));
      if ($filter eq '-1') { # '-1' means all glossary divs were filtered out
        $CONV_REPORT{$PUB_NAME}{'Glossary'} = 'no-glossary';
        $CONV_REPORT{$PUB_NAME}{'Filtered'} = 'all';
      }
      else {
        $dictTmpOsis = "$tmp/$DICTMOD.xml";
        &copy($outf, $dictTmpOsis);
      }
    }
    else {&Error("OSIS file for dictionary module $DICTMOD could not be found.", 
"Run sfm2osis.pl on the dictionary module, to create an OSIS 
file for it, and then run this script again.");}
    
    $CONV_REPORT{$PUB_NAME}{'Glossary'} = $DICTMOD;
    $CONV_REPORT{$PUB_NAME}{'Filtered'} = ($filter eq '0' ? 'none':$filter);
  }
  if (!$dictTmpOsis) {
    my $xml = $XML_PARSER->parse_file("$tmp/$MOD.xml");
    # remove work elements of skipped companions or else the eBook converter will crash
    my @cn = $XPC->findnodes('//osis:work[@osisWork="'.$DICTMOD.'"]', $xml);
    foreach my $cnn (@cn) {$cnn->parentNode()->removeChild($cnn);}
    &writeXMLFile($xml, "$tmp/$MOD.xml");
  }
  
  # copy over only those images referenced in our OSIS files
  &copyReferencedImages("$tmp/$MOD.xml", $INPD, $tmp);
  if ($dictTmpOsis) {&copyReferencedImages($dictTmpOsis, $DICTINPD, $tmp);}
  
  # filter out any and all references pointing to targets outside our final OSIS file scopes
  $CONV_REPORT{$PUB_NAME}{'ScripRefFilter'} = 0;
  $CONV_REPORT{$PUB_NAME}{'GlossRefFilter'} = 0;
  $CONV_REPORT{$PUB_NAME}{'ScripRefFilter'} += &filterScriptureReferences("$tmp/$MOD.xml", $INOSIS);
  $CONV_REPORT{$PUB_NAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", $dictTmpOsis, ($convertTo eq 'eBook'));
  
  if ($dictTmpOsis) {
    $CONV_REPORT{$PUB_NAME}{'ScripRefFilter'} += &filterScriptureReferences($dictTmpOsis, $INOSIS, "$tmp/$MOD.xml");
    $CONV_REPORT{$PUB_NAME}{'GlossRefFilter'} += &filterGlossaryReferences($dictTmpOsis, $dictTmpOsis, ($convertTo eq 'eBook'));
  }

  # now do the conversion on the temporary directory's files
  if ($convertTo eq 'html') {
    &makeHTML($tmp, $cover, $scope);
  }
  elsif ($convertTo eq 'eBook') {
    if ($DEBUG !~ /no.?epub/i) {&makeEbook($tmp, 'epub', $cover, $scope);}
    if ($DEBUG !~ /no.?azw3/i) {&makeEbook($tmp, 'azw3', $cover, $scope);}
    # fb2 is disabled until a decent FB2 converter is written
    # &makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp);
  }
}

# Remove the cover div element from the OSIS file and copy the referenced
# image to $coverpath. If there is no div element, or the referenced image
# cannot be found, the empty string is returned, otherwise the path to the
# referenced image is returned.
sub copyCoverTo($$) {
  my $osisP = shift;
  my $coverpath = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my $figure = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[1][local-name()="div"]/osis:figure[@type="x-cover"]', $xml)}[0];
  if (!$figure) {return '';}
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1copyCoverTo$3/;
  $figure->unbindNode();
  &writeXMLFile($xml, $output, $osisP);
  
  my $result;
  my $source = "$MAININPD/".$figure->getAttribute('src');
  if (-e $source && -f $source) {
    &copy($source, $coverpath);
    $result = $source;
  }
  else {&Error("Cover image $source does not exist!", "Add the cover image to the path, or try re-running sfm2osis.pl to retrive cover images.");}
  
  &Log("\n--- COPYING COVER IMAGE $source\n", 1);
  
  return $result;
}

sub makeHTML($$$) {
  my $tmp = shift;
  my $cover = shift;
  my $scope = shift;
  
  my $osis = "$tmp/$MOD.xml";
  my $coverName = $cover; $coverName =~ s/^.*?([^\/\\]+)$/$1/;
  
  &Log("\n--- CREATING HTML FROM $osis FOR $scope\n", 1);
  
  &updateOsisFullResourceURL($osis, 'html');
  
  my @cssFileNames = split(/\s*\n/, shell("cd $tmp && find . -name '*.css' -print", 3));
  my %params = ('css' => join(',', map { (my $s = $_) =~ s/^\.\///; $s } @cssFileNames));
  chdir($tmp);
  &runXSLT("osis2xhtml.xsl", $osis, "content.opf", \%params);
  chdir($SCRD);

  mkdir("$HTMLOUT/$PUB_NAME");
  &copy_dir("$tmp/xhtml", "$HTMLOUT/$PUB_NAME/xhtml");
  if (-e "$tmp/css") {&copy_dir("$tmp/css", "$HTMLOUT/$PUB_NAME/css");}
  if (-e "$tmp/images") {&copy_dir("$tmp/images", "$HTMLOUT/$PUB_NAME/images");}
  if ($cover && -e $cover) {
    if (! -e "$HTMLOUT/$PUB_NAME/images") {mkdir("$HTMLOUT/$PUB_NAME/images");}
    &copy($cover, "$HTMLOUT/$PUB_NAME/images");
  }
  if (open(INDX, ">$WRITELAYER", "$HTMLOUT/$PUB_NAME/index.xhtml")) {
    my $tophref = &shell("perl -0777 -ne 'print \"\$1\" if /<manifest[^>]*>.*?<item href=\"([^\"]+)\"/s' \"$tmp/content.opf\"", 3);
    my $header = &shell("perl -0777 -ne 'print \"\$1\" if /^(.*?<\\/head[^>]*>)/s' \"$tmp/$tophref\"", 3);
    $header =~ s/<link[^>]*>//sg;
    $header =~ s/(<title[^>]*>).*?(<\/title>)/$1$PUB_NAME$2/s;
    print INDX $header.'
  <body class="calibre index">
    <a href="'.$tophref.'">'.$PUB_NAME.'</a>';
    if ($cover && -e $cover) {
      print INDX '
    <a href="'.$tophref.'"><img src="./images/'.$coverName.'"/></a>';
    }
    print INDX '
  </body>
</html>
';
    close(INDX);
  }
  else {
    &ErrorBug("makeHTML: Could not open \"$HTMLOUT/$PUB_NAME/index.xhtml\" for writing");
  }
}

# Return the filename (without file extension)
sub getEbookName($$) {
  my $scope = shift;
  my $type = shift;

  my $fs = $scope; $fs =~ s/\s/_/g;
  return $fs . "_" . $type;
}

# Return the filename of a full eBook publication (without extension).
sub getFullEbookName($$$$) {
  my $isChildrensBible = shift;
  my $tranpubTitle = shift;
  my $fullscope = shift;
  my $type = shift;
  
  my $name;
  if ($isChildrensBible) {
    $name = $tranpubTitle.'__Chbl';
  }
  else {
    my $fs = $fullscope; $fs =~ s/\s/_/g;
    $name = ($tranpubTitle ? $tranpubTitle.'__':$fs.'_').$type;
  }
  
  $name =~ s/\s+/-/g;
  
  return $name;
}

sub makeEbook($$$$$) {
  my $tmp = shift;
  my $format = shift; # “epub”, "azw3" or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  
  my $osis = "$tmp/$MOD.xml";
  
  &Log("\n--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  
  &updateOsisFullResourceURL($osis, $format);
  
  my $biglog = "$TMPDIR/OUT_osis2ebooks.txt"; # keep a separate log since it is huge and only report if there are errors or not in the main log file
  my $cmd = "$SCRD/scripts/bible/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . &escfile($cover) . " >> ".&escfile($biglog);
  &shell($cmd);
  
  my $ercnt = &shell("grep -i -c 'error' '$biglog'", 3); chomp $ercnt; $ercnt =~ s/^\D*(\d+).*?$/$1/s;
  if ($ercnt) {&Error("Error(s) occured during eBook processing.", "See log file: $biglog");}
  &Report("There were \"$ercnt\" problems reported in the eBook long log file: $biglog");
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    if ($format eq 'epub') {
      my $noEpub3Markup = (&conf('NoEpub3Markup') =~ /^true$/i);
      $cmd = "epubcheck \"$out\"";
      my $result = &shell($cmd, 3);
      if ($result =~ /^\s*$/) {
        &ErrorBug("epubcheck did not return anything- reason unknown");
      }
      elsif ($result !~ /\bno errors\b/i) {
        my $failed = 1;
        if (!$noEpub3Markup) {
          $result =~ s/^[^\n]*attribute "epub:type" not allowed here[^\n]*\n//mg;
          if ($result =~ /ERROR/) {&Log($result);}
          else {
            $failed = 0;
            &Note("Epub validates, other than the existence of epub:type: \"$out\"");
          }
        }
        if ($failed) {&Error("epubcheck validation failed for \"$out\"");}
      }
      else {&Note("Epub validates!: \"$out\"");}
    }
    # find any sub-directories used by the EBOOK destination URL 
    my $outdir = $EBOUT.$PUB_SUBDIR; if (!-e $outdir) {&make_path($outdir);}
    copy($out, "$outdir/$PUB_NAME.$format");
    &Note("Created: $outdir/$PUB_NAME.$format\n", 1);
    # include any cover small image along with the eBook
    my $s = $scope; $s =~ s/ /_/g; my $pubcover = "$MAININPD/images/$s.jpg";
    if (-e $pubcover) {
      &shell("convert -colorspace sRGB -type truecolor -resize 150x \"$pubcover\" \"$outdir/image.jpg\"", 3);
      &Note("Created: $outdir/image.jpg\n", 1);
    }
    if (!$CONV_REPORT{$PUB_NAME}{'Format'}) {$CONV_REPORT{$PUB_NAME}{'Format'} = ();}
    push(@{$CONV_REPORT{$PUB_NAME}{'Format'}}, $format);
  }
  else {&Error("No output file: $out");}
}

sub readServerScopes($) {
  my $url = shift;
  
  my %result;
  
  my @fileList; &updateURLCache("$MAINMOD-ebooks", $url, 12, \@fileList);
  
  foreach my $file (@fileList) {
    if ($file =~ /\/$/) {next;} # skip directories
    
    # ./2005/Prov_Full.azw3
    my $dir = $file; 
    my $filename = ($dir =~ s/^\.\/(.*?)\/([^\/]+)\.(pdf|mobi|azw\d?|epub|fb2)$/$1/ ? $2:'');
    if (!$filename) {next;}
    
    # Get scope from $filename, which is [fileNumber-][title__][scope]_[type]
    $filename =~ s/^\d+\-//;
    $filename =~ s/^.*?__//;
    $filename =~ s/(_(Tran|Full|Part|Othr|Chbl|Biqu|Lvpr|Stry|Para|Bibs|Digl|Prel|Intr|OSIS|Supl|Glos|Dict|Hide|Audi))+$//i;
    my $pscope = $filename;
    
    # Test that result is a scope
    $pscope =~ /^([^_\-]+)/; if (!defined($OSISBOOKS{$1})) {next;}
    
    my $scope = $pscope; $scope =~ s/_/ /g;
    if ($result{$scope}) {next;} # keep first found
    $result{$scope} = "/$dir";
  }
  
  return \%result
}

# The osis2xhtml.xsl converter expects the x-config-FullResourceURL 
# description element to include the full eBook's URL, including the 
# file name and extension. But the config.conf FullResourceURL contains
# only the base URL, so it needs updating.
sub updateOsisFullResourceURL($$) {
  my $osis = shift;
  my $format = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my $update;
  foreach my $u ($XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work/osis:description[@type = "x-config-FullResourceURL"]', $xml)) {
    my $url = $u->textContent;
    
    my $new;
    if ($format eq 'html' || !$url || $url eq 'false') {
      $new = 'false';
    }
    else {
      $new = $url;
      # if URL does not end with / then try and remove /name.ext
      if ($new !~ s/\/\s*$//) {$new =~ s/\/[^\/]*\.[^\.\/]+$//;}
      $new = $new."$TRANPUB_SUBDIR/$TRANPUB_NAME.$format"
    }
    
    if ($url ne $new) {
      &Note("Updating FullResourceURL from \"$url\" to \"$new\".");
      &changeNodeText($u, $new);
      $update++;
    }
  }
  
  if ($update) {&writeXMLFile($xml, $osis);}
}

1;
