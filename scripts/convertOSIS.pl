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
sub convertOSIS($) {
  my $convertTo = shift;
  if ($convertTo !~ /^(eBook|html)$/) {
    &ErrorBug("convertOSIS: Conversion of OSIS to \"$convertTo\" is not yet supported.");
  }

  &runAnyUserScriptsAt("$convertTo/preprocess", \$INOSIS);
  
  # update globals from the OSIS file's metadata, namely $CONF, $MOD etc.
  &setConfGlobals(&readConf());
  
  &Log("Updating OSIS header.\n");
  &writeOsisHeader(\$INOSIS);

  # globals used by this script
  $INOSIS_XML = $XML_PARSER->parse_file($INOSIS);
  %CONV_REPORT;
  $CONV_NAME;
  $FULL_PUB_TITLE = @{$XPC->findnodes("/osis:osis/osis:osisText/osis:header/osis:work[\@osisWork='$MAINMOD']/osis:title", $INOSIS_XML)}[0]; $FULL_PUB_TITLE = ($FULL_PUB_TITLE ? $FULL_PUB_TITLE->textContent:'');
  $CREATE_FULL_BIBLE = (&conf('CreateFullBible') !~ /^false$/i);
  $CREATE_SEPARATE_BOOKS = (&conf('CreateSeparateBooks') !~ /^false$/i);
  @CREATE_FULL_PUBLICATIONS = (); my $n=0; while (my $p = &conf('ScopeSubPublication'.(++$n))) {push(@CREATE_FULL_PUBLICATIONS, $n);}
  $FULLSCOPE = (&isChildrensBible($INOSIS_XML) ? '':&getScopeOSIS($INOSIS_XML));

  if (&isChildrensBible($INOSIS_XML)) {&OSIS_To_ePublication($convertTo);}
  else {
    # convert the entire OSIS file
    if ($CREATE_FULL_BIBLE) {&OSIS_To_ePublication($convertTo, $FULLSCOPE);}

    # convert any print publications that are part of the OSIS file (as specified in config.conf: ScopeSubPublication=scope)
    if ($convertTo ne 'html' && @CREATE_FULL_PUBLICATIONS) {
      foreach my $x (@CREATE_FULL_PUBLICATIONS) {
        my $scope = &conf('ScopeSubPublication'.$x); $scope =~ s/_/ /g;
        &OSIS_To_ePublication($convertTo, $scope, 0, &conf('TitleSubPublication'.$x));
      }
    }

    # convert each Bible book within the OSIS file
    if ($CREATE_SEPARATE_BOOKS) {
      @allBooks = $XPC->findnodes('//osis:div[@type="book"]', $INOSIS_XML);
      BOOK: foreach my $aBook (@allBooks) {
        my $bk = $aBook->getAttribute('osisID');
        # don't create this ebook if an identical ebook has already been created
        foreach my $x (@CREATE_FULL_PUBLICATIONS) {
          if ($bk && $bk eq &conf('ScopeSubPublication'.$x)) {next BOOK;}
        }
        if ($CREATE_FULL_BIBLE && $FULLSCOPE eq $bk) {next BOOK;}
        if ($bk) {&OSIS_To_ePublication($convertTo, $bk, 1);}
      }
    }
  }

  # REPORT results
  &Log("\n");
  &Report(uc($convertTo)." files created (".scalar(keys %CONV_REPORT)." instances):");
  my @order = ('Format', 'Name', 'Title', 'Cover', 'Glossary', 'Filtered', 'ScripRefFilter', 'GlossRefFilter');
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

sub OSIS_To_ePublication($$$$) {
  my $convertTo = shift; # type of ePublication to output
  my $scope = shift; # Bible-scope of the ePublication to output
  my $isPartial = shift; # Is the ePublication a single book from a larger publication?
  my $titleOverride = shift; # Use this ePublication title in lieu of any other
  
  my $type = ($isPartial ? 'Part':'Full');
  my $isChildrensBible = ($scope ? 0:1); # Children's Bibles have no scope
  
  $CONV_NAME = &getEbookName($scope, $type);
  if ($CONV_REPORT{$CONV_NAME}) {
    &ErrorBug("$convertTo \"$CONV_NAME\" already created!");
  }
  
  &Log("\n-----------------------------------------------------\nMAKING ".uc($convertTo).": scope=$scope, type=".($type eq 'Part' ? $type:(&isTran($scope) ? 'Tran':'Full')).", name=$CONV_NAME\n\n", 1);
  
  my $tmp = $scope; $tmp =~ s/\s/_/g; $tmp = ($tmp ? "$TMPDIR/$tmp":$TMPDIR);
  make_path("$tmp/tmp/bible");
  my $osis = "$tmp/tmp/bible/$MOD.xml";
  &copy($INOSIS, $osis);
  
  my $pubTitle = $titleOverride;
  my $pubTitlePart;
  if (!$isChildrensBible) {
    &pruneFileOSIS(
      \$osis,
      $scope,
      $CONF,
      \$pubTitle, 
      \$pubTitlePart
    );
  }
  
  my $cover = "$tmp/cover.jpg";
  my $coverSource = &copyCoverTo(\$osis, $cover);
  if (!$coverSource) {$cover = '';}
  $CONV_REPORT{$CONV_NAME}{'Cover'} = '';
  if ($cover) {
    if ($isPartial) {
      &shell("mogrify ".&imageCaption(&imageDimension($cover)->{'w'}, $pubTitlePart, &conf("Font"), 'LightGray')." \"$cover\"", 3);
      $CONV_REPORT{$CONV_NAME}{'Cover'} = ' ('.$pubTitlePart.')';
    }
    my $coverSourceName = $coverSource; $coverSourceName =~ s/^.*\///;
    $CONV_REPORT{$CONV_NAME}{'Cover'} = $coverSourceName . $CONV_REPORT{$CONV_NAME}{'Cover'}; 
    $CONV_REPORT{$CONV_NAME}{'Title'} = ($isPartial ? $pubTitlePart:'no-title');
  }
  else {
    $CONV_REPORT{$CONV_NAME}{'Cover'} = 'random-cover';
    $CONV_REPORT{$CONV_NAME}{'Title'} = $pubTitle;
  }
    
  &runXSLT("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", $osis, "$tmp/$MOD.xml");
  
  # copy osis2xhtml.xsl
  copy("$SCRD/scripts/bible/html/osis2xhtml.xsl", $tmp);
  copy("$SCRD/scripts/functions.xsl", $tmp);
  
  # copy css file(s): always copy html.css and then if needed also copy $convertTo.css if it exists
  mkdir("$tmp/css");
  my $css = &getDefaultFile(($isChildrensBible ? 'childrens_bible':'bible')."/html/css/html.css", -1);
  if ($css) {&copy($css, "$tmp/css/00html.css");}
  if ($convertTo ne 'html') {
    $css = &getDefaultFile(($isChildrensBible ? 'childrens_bible':'bible')."/$convertTo/css/$convertTo.css", -1);
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
    if (open(CSS, ">$tmp/css/10font.css")) {
      my %font_format = ('ttf' => 'truetype', 'otf' => 'opentype', 'woff' => 'woff');
      foreach my $f (keys %{$FONT_FILES{&conf("Font")}}) {
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
      if (open(FCSS, "<$FONTS/".&conf("Font").".eBook.css")) {while(<FCSS>) {print CSS $_;} close(FCSS);}
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
        $CONV_REPORT{$CONV_NAME}{'Glossary'} = 'no-glossary';
        $CONV_REPORT{$CONV_NAME}{'Filtered'} = 'all';
      }
      else {
        $dictTmpOsis = "$tmp/$DICTMOD.xml";
        &copy($outf, $dictTmpOsis);
      }
    }
    else {&Error("OSIS file for dictionary module $DICTMOD could not be found.", 
"Run sfm2osis.pl on the dictionary module, to create an OSIS 
file for it, and then run this script again.");}
    
    $CONV_REPORT{$CONV_NAME}{'Glossary'} = $DICTMOD;
    $CONV_REPORT{$CONV_NAME}{'Filtered'} = ($filter eq '0' ? 'none':$filter);
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
  $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} = 0;
  $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} = 0;
  $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} += &filterScriptureReferences("$tmp/$MOD.xml", $INOSIS);
  $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", $dictTmpOsis, ($convertTo eq 'eBook'));
  
  if ($dictTmpOsis) {
    $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} += &filterScriptureReferences($dictTmpOsis, $INOSIS, "$tmp/$MOD.xml");
    $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} += &filterGlossaryReferences($dictTmpOsis, $dictTmpOsis, ($convertTo eq 'eBook'));
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
  
  &updateOsisFullResourceURL($osis, '.html');
  
  my @cssFileNames = split(/\s*\n/, shell("cd $tmp && find . -name '*.css' -print", 3));
  my %params = ('css' => join(',', map { (my $s = $_) =~ s/^\.\///; $s } @cssFileNames));
  chdir($tmp);
  &runXSLT("osis2xhtml.xsl", $osis, "content.opf", \%params);
  chdir($SCRD);

  mkdir("$HTMLOUT/$CONV_NAME");
  &copy_dir("$tmp/xhtml", "$HTMLOUT/$CONV_NAME/xhtml");
  if (-e "$tmp/css") {&copy_dir("$tmp/css", "$HTMLOUT/$CONV_NAME/css");}
  if (-e "$tmp/images") {&copy_dir("$tmp/images", "$HTMLOUT/$CONV_NAME/images");}
  if ($cover && -e $cover) {
    if (! -e "$HTMLOUT/$CONV_NAME/images") {mkdir("$HTMLOUT/$CONV_NAME/images");}
    &copy($cover, "$HTMLOUT/$CONV_NAME/images");
  }
  if (open(INDX, ">:encoding(UTF-8)", "$HTMLOUT/$CONV_NAME/index.xhtml")) {
    my $tophref = &shell("perl -0777 -ne 'print \"\$1\" if /<manifest[^>]*>.*?<item href=\"([^\"]+)\"/s' \"$tmp/content.opf\"", 3);
    my $header = &shell("perl -0777 -ne 'print \"\$1\" if /^(.*?<\\/head[^>]*>)/s' \"$tmp/$tophref\"", 3);
    $header =~ s/<link[^>]*>//sg;
    $header =~ s/(<title[^>]*>).*?(<\/title>)/$1$CONV_NAME$2/s;
    print INDX $header.'
  <body class="calibre index">
    <a href="'.$tophref.'">'.$CONV_NAME.'</a>';
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
    &ErrorBug("makeHTML: Could not open \"$HTMLOUT/$CONV_NAME/index.xhtml\" for writing");
  }
}

# Returns 1 if $scope covers the entire translation (the entire project) 
# which also includes sub-publications. Returns 0 otherwise.
sub isTran($) {
  my $scope = shift; $scope =~ s/\s+/_/g;
  
  my $subdirs = &shell("find '$MAININPD/sfm' -maxdepth 1 -type d | wc -l", 3); chomp($a); $a--;
  if (!$scope) {return ($subdirs ? 1:0);}
  my $nosubdir = (! -d "$MAININPD/sfm/$scope");
  return ($subdirs && $nosubdir ? 1:0);
}

sub getEbookName($$) {
  my $scope = shift;
  my $type = shift;

  if ($scope eq $FULLSCOPE || &isChildrensBible($INOSIS_XML)) {
    return &getFullEbookName($scope);
  }
  
  my $filename = $scope . "_" . $type;
  $filename =~ s/\s/_/g;
  
  return $filename;
}

sub getFullEbookName($) {
  my $scope = shift;
  
  my $returnNameWithoutExt;
  if (&isChildrensBible($INOSIS_XML)) {
    $returnNameWithoutExt = $FULL_PUB_TITLE.'__Chbl';
  }
  else {
    my $s = $scope; $s =~ s/_/ /g;
    my $FullOrTran = (&isTran($s) ? 'Tran':'Full');
    my $ms = $FULLSCOPE;
    $ms =~ s/\s/_/g;
    $returnNameWithoutExt = ($FULL_PUB_TITLE ? $FULL_PUB_TITLE.'__':$ms.'_').$FullOrTran;
  }
  
  $returnNameWithoutExt =~ s/\s+/-/g;
  
  return $returnNameWithoutExt;
}

sub makeEbook($$$$$) {
  my $tmp = shift;
  my $format = shift; # “epub”, "azw3" or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  
  my $osis = "$tmp/$MOD.xml";
  
  &Log("\n--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  
  &updateOsisFullResourceURL($osis, &getFullEbookName($scope).".$format");
  
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
    # include any sub-directory used by the EBOOK destination URL
    my $subdir = ($EBOOKS =~ /^https?\:\/\// ? &getEbookSubdir($scope, &getHttpFileList("$EBOOKS/$MAINMOD/$MAINMOD")):'');
    my $outdir = $EBOUT.($subdir ? "/$subdir":''); if (!-e $outdir) {&make_path($outdir);}
    copy($out, "$outdir/$CONV_NAME.$format");
    &Note("Created: $outdir/$CONV_NAME.$format\n", 1);
    # include any cover small image along with the eBook
    if (-e $cover) {
      &shell("convert -colorspace sRGB -type truecolor -resize 150x \"$cover\" \"$outdir/image.jpg\"", 3);
      &Note("Created: $outdir/image.jpg\n", 1);
    }
    if (!$CONV_REPORT{$CONV_NAME}{'Format'}) {$CONV_REPORT{$CONV_NAME}{'Format'} = ();}
    push(@{$CONV_REPORT{$CONV_NAME}{'Format'}}, $format);
  }
  else {&Error("No output file: $out");}
}

sub getHttpFileList($) {
  my $url = shift;
  
  my @list;
  
  my $pdir = $url; $pdir =~ s/^.*?([^\/]+)\/?$/$1/;
  my $cdir = $url; $cdir =~ s/^https?\:\/\/[^\/]+\/(.*?)\/?$/$1/; @cd = split(/\//, $cdir); $cdir = @cd-1;

  my $tmp = "$TMPDIR/getHttpFileList";
  mkdir($tmp);
  use Net::Ping;
  my $net = Net::Ping->new;
  my $d = $url; $d =~ s/^https?\:\/\/([^\/]+).*?$/$1/;
  my $r; use Try::Tiny; try {$r = $net->ping($d, 1);} catch {$r = 0;};
  if ($r) {
    &shell("wget -P \"$tmp\" -r -np -nH --cut-dirs=$cdir --accept index.html -X $pdir $url", 3);
    &readHttpFileDir($tmp, \@list);
  }
  if ($tmp =~ /\Q.osis-converters/) {remove_tree($tmp);}
  
  return \@list;
}

sub readHttpFileDir($\@) {
  my $dir = shift;
  my $filesAP = shift;
  
  if (!opendir(DIR, $dir)) {
    &ErrorBug("readHttpFileDir could not open $dir!");
    return;
  }
  my @subs = readdir(DIR);
  closedir(DIR);
  foreach my $sub (@subs) {
    if ($sub =~ /^\./ || $sub =~ /(robots\.txt\.tmp)/) {next;}
    elsif (-d "$dir/$sub") {&readHttpFileDir("$dir/$sub", $filesAP); next;}
    elsif ($sub ne 'index.html') {&ErrorBug("readHttpFileDir encounteed an unexpected file $sub in $dir."); next;}
    my $html = $XML_PARSER->load_html(location  => "$dir/$sub", recover => 1);
    if (!$html) {&ErrorBug("readHttpFileDir could not parse $dir/$sub"); next;}
    foreach my $a ($html->findnodes('//tr//a')) {
      if ($a->textContent() !~ /\.[^\.\/]+$/) {next;} # keep only links to files with extensions
      push(@{$filesAP}, "$dir/".$a->textContent());
      my $d = $dir; $d =~ s/^\Q$TMPDIR\E\/getHttpFileList\///; &Debug("Found $EBOOKS file: $d/".$a->textContent()."\n", 1);
    }
  }
}

sub getEbookSubdir($\@) {
  my $scope = shift;
  my $filesAP = shift;
  
  foreach my $path (@{$filesAP}) {
    my $s = $scope; $s =~ s/\s+/_/g; $s = quotemeta($s);
    # tmp/osis2ebooks/getHttpFileList/BEZ/2005/Prov_Full.azw3
    if ($path =~ /getHttpFileList\/[^\/]+\/(.*?)\/([^\/]+__)?$s(_|\.)[^\/]+$/i) {
      my $sd = $1;
      &Debug("Found $EBOOKS sub-directory containing files with scope '$scope': $sd\n", 1);
      return $sd;
    }
  }

  return '';
}

# To work with osis2xhtml.xsl, the FullResourceURL must have the full eBook's file name and extension (directory URL comes from config.conf)
sub updateOsisFullResourceURL($$) {
  my $osis = shift;
  my $fileName = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my $update;
  foreach my $u ($XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work/osis:description[@type = "x-config-FullResourceURL"]', $xml)) {
    my $url = $u->textContent;
    my $new;
    if ($fileName =~ /\.html$/) {
      $new = 'false';
    }
    elsif (!$url || $url eq 'false') {$new = 'false';}
    else {
      $new = $url; if ($new !~ s/\/\s*$//) {$new =~ s/\/[^\/]*\.[^\.\/]+$//;}
      $new = $new.'/'.$fileName;
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
