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
# All conversion settings are provided by a Project_Directory/$convertTo/convert.txt file.
sub convertOSIS($) {
  my $convertTo = shift;
  if ($convertTo !~ /^(eBook|html)$/) {
    &ErrorBug("convertOSIS: Conversion of OSIS to \"$convertTo\" is not yet supported.");
  }

  &runAnyUserScriptsAt("$convertTo/preprocess", \$INOSIS);
  
  # update globals from the OSIS file's metadata, namely $ConfEntryP, $MOD etc.
  &setConfGlobals(&updateConfData($ConfEntryP, $INOSIS));

  # globals used by this script
  $INOSIS_XML = $XML_PARSER->parse_file($INOSIS);
  %CONV_REPORT;
  $CONV_NAME;
  $FULL_PUB_TITLE = @{$XPC->findnodes("/descendant::osis:work[\@osisWork='$MOD'][1]/osis:title[1]", $INOSIS_XML)}[0]; $FULL_PUB_TITLE = ($FULL_PUB_TITLE ? $FULL_PUB_TITLE->textContent:'');
  %CONVERT_TXT = &readConvertTxt(&getDefaultFile("bible/$convertTo/convert.txt"));
  $CREATE_FULL_BIBLE = (!defined($CONVERT_TXT{'CreateFullBible'}) || $CONVERT_TXT{'CreateFullBible'} !~ /^(false|0)$/i);
  $CREATE_SEPARATE_BOOKS = (!defined($CONVERT_TXT{'CreateSeparateBooks'}) || $CONVERT_TXT{'CreateSeparateBooks'} !~ /^(false|0)$/i);
  @CREATE_FULL_PUBLICATIONS = (); foreach my $k (sort keys %CONVERT_TXT) {if ($k =~ /^CreateFullPublication(\d+)$/) {push(@CREATE_FULL_PUBLICATIONS, $1);}}
  $TOCNUMBER = ($CONVERT_TXT{'TOC'} ? $CONVERT_TXT{'TOC'}:$DEFAULT_TOCNUMBER);
  $TITLECASE = ($CONVERT_TXT{'TitleCase'} ? $CONVERT_TXT{'TitleCase'}:$DEFAULT_TITLECASE);

  # convert the entire OSIS file
  if ($CREATE_FULL_BIBLE) {&OSIS_To_ePublication($convertTo, $ConfEntryP->{"Scope"});}

  # convert any print publications that are part of the OSIS file (as specified in convert.txt: CreateFullPublicationN=scope)
  if ($convertTo ne 'html' && @CREATE_FULL_PUBLICATIONS) {
    foreach my $x (@CREATE_FULL_PUBLICATIONS) {
      my $scope = $CONVERT_TXT{'CreateFullPublication'.$x}; $scope =~ s/_/ /g;
      &OSIS_To_ePublication($convertTo, $scope, 0, $CONVERT_TXT{'TitleFullPublication'.$x});
    }
  }

  # convert each Bible book within the OSIS file
  if ($CREATE_SEPARATE_BOOKS) {
    @allBooks = $XPC->findnodes('//osis:div[@type="book"]', $INOSIS_XML);
    BOOK: foreach my $aBook (@allBooks) {
      my $bk = $aBook->getAttribute('osisID');
      # don't create this ebook if an identical ebook has already been created
      foreach my $x (@CREATE_FULL_PUBLICATIONS) {
        if ($bk && $bk eq $CONVERT_TXT{'CreateFullPublication'.$x}) {next BOOK;}
      }
      if ($CREATE_FULL_BIBLE && $ConfEntryP->{"Scope"} eq $bk) {next BOOK;}
      if ($bk) {&OSIS_To_ePublication($convertTo, $bk, 1);}
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
  
  &Log("\n-----------------------------------------------------\nMAKING ".uc($convertTo).": scope=$scope, type=$type, titleOverride=$titleOverride\n", 1);
  
  $CONV_NAME = $scope . "_" . $type;
  $CONV_NAME =~ s/\s/_/g;
  if ($CONV_REPORT{$CONV_NAME}) {
    &ErrorBug("$convertTo \"$CONV_NAME\" already created!");
  }
  
  &Log("\n");
  
  my $tmp = $scope; $tmp =~ s/\s/_/g; $tmp = "$TMPDIR/$tmp";
  make_path("$tmp/tmp/bible");
  my $osis = "$tmp/tmp/bible/$MOD.xml";
  &copy($INOSIS, $osis);
  
  my $pubTitle = ($titleOverride ? $titleOverride:$CONVERT_TXT{'Title'}); # title will usually still be '' at this point
  my $pubTitlePart;
  &pruneFileOSIS(
    \$osis,
    $scope,
    $ConfEntryP,
    \%CONVERT_TXT,
    \$pubTitle, 
    \$pubTitlePart
  );
  
  # update osis header with current convert.txt
  if ($DEBUG) {$CONVERT_TXT{'DEBUG'} = 'true';}
  &writeOsisHeader(\$osis, $ConfEntryP, NULL, NULL, \%CONVERT_TXT);
    
  &runXSLT("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", $osis, "$tmp/$MOD.xml");
  
  # copy osis2xhtml.xsl
  copy("$SCRD/scripts/bible/html/osis2xhtml.xsl", $tmp);
  copy("$SCRD/scripts/functions.xsl", $tmp);
  
  # copy css
  &copy_dir_with_defaults("bible/$convertTo/css", "$tmp/css");
 
  # copy font if specified
  if ($FONTS && $ConfEntryP->{"Font"}) {
    &copyFont($ConfEntryP->{"Font"}, $FONTS, \%FONT_FILES, "$tmp/css", 1);
    # The following allows Calibre to embed fonts (which must be installed locally) when 
    # the '--embed-all-fonts' flag is used with ebook-convert. This has been commented out
    # (and the flag removed from ebook-convert) because embeded fonts are unnecessary 
    # when font files are explicitly provided, and embeding never worked right anyway.
    #&shell("if [ -e ~/.fonts ]; then echo Font directory exists; else mkdir ~/.fonts; fi", 3);
    #my $home = &shell("echo \$HOME", 3); chomp($home);
    #&Note("Calibre can only embed fonts that are installed. Installing ".$ConfEntryP->{"Font"}." to host.");
    #&copyFont($ConfEntryP->{"Font"}, $FONTS, \%FONT_FILES, "$home/.fonts");
    if (open(CSS, ">$tmp/css/font.css")) {
      my %font_format = ('ttf' => 'truetype', 'otf' => 'opentype', 'woff' => 'woff');
      foreach my $f (keys %{$FONT_FILES{$ConfEntryP->{"Font"}}}) {
        my $format = $font_format{lc($FONT_FILES{$ConfEntryP->{"Font"}}{$f}{'ext'})};
        if (!$format) {&Log("WARNNG: Font \"$f\" has an unknown format; src format will not be specified.\n");}
        print CSS '
@font-face {
  font-family:font1;
  src: url(\''.($convertTo eq 'eBook' ? './':'/css/').$f.'\')'.($format ? ' format(\''.$format.'\')':'').';
  font-weight: '.($FONT_FILES{$ConfEntryP->{"Font"}}{$f}{'style'} =~ /bold/i ? 'bold':'normal').'; font-style: '.($FONT_FILES{$ConfEntryP->{"Font"}}{$f}{'style'} =~ /italic/i ? 'italic':'normal').';
}
';
      }
      print CSS '
body {font-family: font1;}

';
      if (open(FCSS, "<$FONTS/".$ConfEntryP->{"Font"}.".eBook.css")) {while(<FCSS>) {print CSS $_;} close(FCSS);}
      close(CSS);
    }
    else {&ErrorBug("Could not write font css to \"$tmp/css/font.css\"");}
  }
  
  # copy cover
  my $titleType = $type; # Full or Part, to be determined also by copyCoverImageTo
  my $coverName = &copyCoverImageTo("$tmp/cover.jpg", $MOD, $scope, $pubTitlePart, $ConfEntryP->{"Versification"}, $convertTo, \$titleType);
  my $cover = ($coverName ? "$tmp/cover.jpg":'');
  if ($coverName) {
    $CONV_REPORT{$CONV_NAME}{'Cover'} = $coverName;
    $CONV_REPORT{$CONV_NAME}{'Title'} = ($titleType eq 'Part' ? $pubTitlePart:'no-title');
  }
  else {
    $CONV_REPORT{$CONV_NAME}{'Cover'} = 'random-cover';
    $CONV_REPORT{$CONV_NAME}{'Title'} = $pubTitle;
  }
  
  # copy companion OSIS file
  my @skipCompanions;
  my @companionDictFiles;
  if ($ConfEntryP->{'Companion'}) {
    my $companion = $ConfEntryP->{'Companion'};
    if (! -e "$tmp/tmp/dict") {make_path("$tmp/tmp/dict");}
    my $outf = &getProjectOsisFile($companion);
    my $filter = '0';
    if ($outf) {
      &copy($outf, "$tmp/tmp/dict/$companion.xml"); $outf = "$tmp/tmp/dict/$companion.xml";
      &runAnyUserScriptsAt("$companion/$convertTo/preprocess", \$outf);
      &runScript("$SCRD/scripts/bible/osis2sourceVerseSystem.xsl", \$outf);
      if ($companion =~ /DICT$/) {
        require "$SCRD/scripts/dict/processGlossary.pl";
        # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
        # This means any non Bible scopes (like SWORD) are also filtered out.
        $filter = &filterGlossaryToScope(\$outf, $scope, ($convertTo eq 'eBook'));
        &Note("filterGlossaryToScope('$scope') filtered: ".($filter eq '-1' ? 'everything':($filter eq '0' ? 'nothing':$filter)));
        my $aggfilter = &filterAggregateEntries(\$outf, $scope);
        &Note("filterAggregateEntries('$scope') filtered: ".($aggfilter eq '-1' ? 'everything':($aggfilter eq '0' ? 'nothing':$aggfilter)));
        if ($filter eq '-1') { # '-1' means all glossary divs were filtered out
          push(@skipCompanions, $companion);
          $CONV_REPORT{$CONV_NAME}{'Glossary'} = 'no-glossary';
          $CONV_REPORT{$CONV_NAME}{'Filtered'} = 'all';
        }
        else {
          &copy($outf, "$tmp/$companion.xml");
          push(@companionDictFiles, "$tmp/$companion.xml");
        }
      }
    }
    
    $CONV_REPORT{$CONV_NAME}{'Glossary'} = $companion;
    $CONV_REPORT{$CONV_NAME}{'Filtered'} = ($filter eq '0' ? 'none':$filter);
  }
  if (@skipCompanions) {
    my $xml = $XML_PARSER->parse_file("$tmp/$MOD.xml");
    # remove work elements of skipped companions or else the eBook converter will crash
    foreach my $c (@skipCompanions) {
      my @cn = $XPC->findnodes('//osis:work[@osisWork="'.$c.'"]', $xml);
      foreach my $cnn (@cn) {$cnn->parentNode()->removeChild($cnn);}
    }
    &writeXMLFile($xml, "$tmp/$MOD.xml");
  }
  
  # copy over only those images referenced in our OSIS files
  &copyReferencedImages("$tmp/$MOD.xml", $INPD, $tmp);
  foreach my $osis (@companionDictFiles) {
    my $companion = $osis; $companion =~ s/^.*\/([^\/\.]+)\.[^\.]+$/$1/;
    &copyReferencedImages($osis, &findCompanionDirectory($companion), $tmp);
  }
  
  # filter out any and all references pointing to targets outside our final OSIS file scopes
  $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} = 0;
  $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} = 0;
  $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} += &filterScriptureReferences("$tmp/$MOD.xml", $INOSIS);
  $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", \@companionDictFiles, ($convertTo eq 'eBook'));
  
  foreach my $c (@companionDictFiles) {
    $CONV_REPORT{$CONV_NAME}{'ScripRefFilter'} += &filterScriptureReferences($c, $INOSIS, "$tmp/$MOD.xml");
    $CONV_REPORT{$CONV_NAME}{'GlossRefFilter'} += &filterGlossaryReferences($c, \@companionDictFiles, ($convertTo eq 'eBook'));
  }
  
  # If this OSIS file contains multiple publications, insert a cover for each, if available.
  if (&isTran($scope)) {
    &Log("\n--- INSERTING cover images for full translation in \"$tmp/$MOD.xml\"\n", 1);
    my $xml = $XML_PARSER->parse_file("$tmp/$MOD.xml");
    my $updated;
    my @pubs = ();
    my $n=1; 
    while ($CONVERT_TXT{"CreateFullPublication$n"}) {
      push(@pubs, $CONVERT_TXT{"CreateFullPublication$n"});
      $n++;
    }
    my @covers = ();
    foreach my $s (@pubs) {
      if ($s eq $scope) {next;}
      my $titleType = 'Full';
      my $sn = $s; $sn =~ s/\s+/_/g;
      if (! -e "$tmp/images") {mkdir("$tmp/images");}
      my $coverName = &copyCoverImageTo("$tmp/images/$sn.jpg", $MOD, $s, $pubTitlePart, $ConfEntryP->{"Versification"}, $convertTo, \$titleType);
      if ($titleType ne 'Full') {
        unlink("$tmp/images/$sn.jpg");
        next;
      }
      my $firstIntToc = @{$XPC->findnodes('//osis:div[@type][@osisRef="'.$s.'"][1]/osis:milestone[@type="x-usfm-toc'.($CONVERT_TXT{'TOC'} ? $CONVERT_TXT{'TOC'}:'2').'"]', $xml)}[0];
      if (!$firstIntToc) {
        unlink("$tmp/images/$sn.jpg");
        next;
      }
      $updated++;
      &Note("Inserting cover image into Tran: $sn.jpg");
      # The ' ' between figure tags is a Unicode non-breaking space to prevent osis2xhtml.xsl from moving titles above the figure
      $firstIntToc->parentNode->insertAfter($XML_PARSER->parse_balanced_chunk("<figure type='x-cover' src='./images/$sn.jpg'></figure>"), $firstIntToc);
      push(@covers, "\"$tmp/images/$sn.jpg\"");
    }
    if ($updated) {&writeXMLFile($xml, "$tmp/$MOD.xml");}
    # Also create a composite cover from the publication covers
    if (@covers && $CONV_REPORT{$CONV_NAME}{'Cover'} eq 'random-cover') {
      my $imgw = 500; my $imgh = 0;
      my $xs = 100; my $ys = 100;
      my $xw = $imgw - ((@covers-1)*$xs);
      my $cmd;
      for (my $j=0; $j<@covers; $j++) {
        my $dimP = &imageDimension(@covers[$j]);
        $sh = int($dimP->{'h'} * ($xw/$dimP->{'w'}));
        if ($imgh < $sh + ($ys*$j)) {$imgh = $sh + ($ys*$j);}
        $cmd .= " \\( ".@covers[$j]." -resize ${xw}x${sh} \\) -geometry +".($j*$xs)."+".($j*$ys)." -composite";
      }
      $cmd = "convert -size ${imgw}x${imgh} xc:white $cmd ";
      $cmd .= &imageCaption($imgw, $pubTitle)." ";
      $cmd .= "\"$tmp/cover.jpg\"";
      &Note("Creating a single montage cover from ".@covers." publication cover images.");
      &shell($cmd);
      $cover = "$tmp/cover.jpg";
      $CONV_REPORT{$CONV_NAME}{'Cover'} = 'composite';
    }
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

# Copy a cover image for this module and scope to the destination. The 
# following searches are done to look for a starting cover image (the
# first found is used):
# 1) $INDP/$convertTo/<scoped-name>
# 2) $COVERS location (if any) looking for <scoped-name>
# 3) $INDP/$convertTo/cover.jpg
# If a cover image is found, it will be determined whether the scope is
# a sub-set of the image's publication. If so, pubTitlePart will be 
# appended to the top of the cover image. The final image is copied to
# the destination. If a cover image is found/copied the name of the 
# starting cover image is returned, or '' otherwise.
sub copyCoverImageTo($$$$$$\$) {
  my $destination = shift; 
  my $mod = shift;
  my $scope = shift;
  my $pubTitlePart = shift;
  my $vsys = shift;
  my $convertTo = shift;
  my $titleTypeP = shift;
  
  my $cover = &findCoverInDir("$INPD/$convertTo", $mod, $scope, $vsys, $titleTypeP);
  if (!$cover && $COVERS) {
    if ($COVERS =~ /^https?\:/) {
      my $p = &expandLinuxPath("~/.osis-converters/cover");
      if (!-e $p) {mkdir($p);}
      shell("cd '$p' && wget -r --quiet --level=1 -erobots=off -nd -np -N -A '*.*' -R '*.html*' '$COVERS'", 3);
      &wgetSyncDel($p);
      $COVERS = $p;
    }
    $cover = &findCoverInDir($COVERS, $mod, $scope, $vsys, $titleTypeP);
  }
  if (!$cover) {$cover = (-e "$INPD/$convertTo/cover.jpg" ? "$INPD/$convertTo/cover.jpg":'');}
  if (!$cover) {return '';}
  
  if ($$titleTypeP eq 'Part') {
    # add specific title to the top of the eBook cover image
    my $dimP = &imageDimension($cover);
    my $cmd = "convert \"$cover\" ".&imageCaption($dimP->{'w'}, $pubTitlePart)." \"$destination\"";
    &shell($cmd, 2);
  }
  else {copy($cover, $destination);}
  &Note("Found a source cover image at: '$cover'");
  
  my $coverName = $cover; $coverName =~ s/^.*\///;
  return $coverName;
}

sub imageDimension($) {
  my $image = shift;
  
  my %dim;
  my $r = `identify "$image"`;
  $dim{'w'} = $r; $dim{'w'} =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $dim{'w'} = (1*$dim{'w'});
  $dim{'h'} = $r; $dim{'h'} =~ s/^.*?\bJPEG \d+x(\d+)\b.*$/$1/; $dim{'h'} = (1*$dim{'h'});
  
  return \%dim;
}

sub imageCaption($$) {
  my $width = shift;
  my $title = shift;
  
  my $pointsize = (4/3)*$width/length($title);
  if ($pointsize > 40) {$pointsize = 40;}
  elsif ($pointsize < 10) {$pointsize = 10;}
  my $padding = 20;
  my $barheight = $pointsize + (2*$padding);
  my $font = '';
  if ($FONTS && $ConfEntryP->{"Font"}) {
    foreach my $f (keys %{$FONT_FILES{$ConfEntryP->{"Font"}}}) {
      if ($FONT_FILES{$ConfEntryP->{"Font"}}{$f}{'style'} eq 'regular') {
        $font = $FONT_FILES{$ConfEntryP->{"Font"}}{$f}{'fullname'};
        $font =~ s/ /-/g;
        last;
      }
    }
  }
  return "-gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize ".($font ? "-font $font ":'')."-annotate +0+$padding '$title'";
}

# Look for a cover image in $dir matching $mod and $scope and return it 
# if found. The image file name may or may not be prepended with $mod_, 
# and may use either space or underscore as scope delimiter. If a match 
# is not found, but a cover exists which encompasses it, then that image
# is selected and $titleTypeP is set to 'Part'.
sub findCoverInDir($$$$\$) {
  my $dir = shift;
  my $mod = shift;
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
      my $m = $mod.'_';
      if ($fscope !~ s/^($m)?(.*?)\.jpg$/$2/i) {next;}
      $fscope =~ s/_/ /g;
      if ($scope eq $fscope) {
        $$titleTypeP = "Full"; 
        return "$dir/$f";
      }
      # if scopes are not a perfect match, then the scope of the eBook is assumed to be a single book!
      for my $s (@{&scopeToBooks($fscope, $bookOrderP)}) {
        if ($scope eq $s) {
          $$titleTypeP = "Part";
          return "$dir/$f";
        }
      }
    }
  }
  
  return '';
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

sub isTran($) {
  my $scope = shift;
  my $subdirs = &shell("find '$MAININPD/sfm' -maxdepth 1 -type d | wc -l", 3); chomp($a); $a--;
  my $nosubdir = (! -d "$MAININPD/sfm/$scope");
  return ($subdirs && $nosubdir ? 1:0);
}

sub makeEbook($$$$$) {
  my $tmp = shift;
  my $format = shift; # “epub”, "azw3" or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  
  my $osis = "$tmp/$MOD.xml";
  
  &Log("\n--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  if (!$cover) {$cover = (-e "$INPD/eBook/cover.jpg" ? &escfile("$INPD/eBook/cover.jpg"):'');}
  my $s = $scope; $s =~ s/_/ /g;
  my $FullOrTran = (&isTran($s) ? 'Tran':'Full');
  my $eBookFullPubName = ($FULL_PUB_TITLE ? $FULL_PUB_TITLE.'__'.$FullOrTran:$ConfEntryP->{"Scope"}.'_'.$FullOrTran).".$format"; $eBookFullPubName =~ s/\s+/-/g;
  my $thisEBookName = ($scope eq $ConfEntryP->{"Scope"} ? $eBookFullPubName:"$CONV_NAME.$format");
  &updateOsisFullResourceURL($osis, $eBookFullPubName);
  
  my $cmd = "$SCRD/scripts/bible/eBooks/osis2ebook.pl " . &escfile($INPD) . " " . &escfile($LOGFILE) . " " . &escfile($tmp) . " " . &escfile($osis) . " " . $format . " Bible " . &escfile($cover) . " >> ".&escfile("$TMPDIR/OUT_osis2ebooks.txt");
  &shell($cmd);
  
  my $out = "$tmp/$MOD.$format";
  if (-e $out) {
    if ($format eq 'epub') {
      my $epub3Markup = (!($CONVERT_TXT{'NoEpub3Markup'} =~ /^(true)$/i));
      $cmd = "epubcheck \"$out\"";
      my $result = &shell($cmd, ($epub3Markup ? 3:0));
      if ($result =~ /^\s*$/) {
        &ErrorBug("epubcheck did not return anything- reason unknown");
      }
      elsif ($result !~ /\bno errors\b/i) {
        my $failed = 1;
        if ($epub3Markup) {
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
    copy($out, "$EBOUT/$thisEBookName");
    if (!$CONV_REPORT{$CONV_NAME}{'Format'}) {$CONV_REPORT{$CONV_NAME}{'Format'} = ();}
    push(@{$CONV_REPORT{$CONV_NAME}{'Format'}}, $format);
    &Log("Created: $CONV_NAME.$format\n", 2);
  }
  else {&Error("No output file: $out");}
}

# To work with osis2xhtml.xsl, the FullResourceURL must have the full eBook's file name and extension (directory URL comes from convert.txt)
sub updateOsisFullResourceURL($$) {
  my $osis = shift;
  my $fileName = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @update = $XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work/osis:description[contains(@type, "FullResourceURL")]', $xml);
  foreach my $u (@update) {
    if ($fileName =~ /\.html$/) {$u->unbindNode(); next;} # Currently unimplemented for html
    my $url = $u->textContent;
    my $new = $url; if ($new !~ s/\/\s*$//) {$new =~ s/\/[^\/]*\.[^\.\/]+$//;}
    $new = $new.'/'.$fileName;
    if ($url ne $new) {
      &Note("Updating FullResourceURL from \"$url\" to \"$new\".");
      &changeNodeText($u, $new);
    }
  }
  
  &writeXMLFile($xml, $osis);
}

1;
