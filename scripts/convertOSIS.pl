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

  if (&isChildrensBible($INOSIS_XML)) {&OSIS_To_ePublication($convertTo);}
  else {
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
  
  $CONV_NAME = &getEbookName($scope, $FULL_PUB_TITLE, $ConfEntryP, $type);
  if ($CONV_REPORT{$CONV_NAME}) {
    &ErrorBug("$convertTo \"$CONV_NAME\" already created!");
  }
  
  &Log("\n");
  
  my $tmp = $scope; $tmp =~ s/\s/_/g; $tmp = ($tmp ? "$TMPDIR/$tmp":$TMPDIR);
  make_path("$tmp/tmp/bible");
  my $osis = "$tmp/tmp/bible/$MOD.xml";
  &copy($INOSIS, $osis);
  
  my $pubTitle = ($titleOverride ? $titleOverride:$CONVERT_TXT{'Title'}); # title will usually still be '' at this point
  my $pubTitlePart;
  if ($scope) {
    &pruneFileOSIS(
      \$osis,
      $scope,
      $ConfEntryP,
      \%CONVERT_TXT,
      \$pubTitle, 
      \$pubTitlePart
    );
  }
  
  # update osis header with current convert.txt
  if ($DEBUG) {$CONVERT_TXT{'DEBUG'} = 'true';}
  &writeOsisHeader(\$osis, $ConfEntryP, NULL, NULL, \%CONVERT_TXT);
  
  my $cover = "$tmp/cover.jpg";
  my $coverSource = &copyCoverTo(\$osis, $cover);
  if (!$coverSource) {$cover = '';}
  if ($cover) {
    if ($isPartial) {&shell("mogrify ".&imageCaption(&imageDimension($cover)->{'w'}, $pubTitlePart, $ConfEntryP->{"Font"}, 'LightGray')." \"$cover\"", 3);}
    $CONV_REPORT{$CONV_NAME}{'Cover'} = $coverSource; $CONV_REPORT{$CONV_NAME}{'Cover'} =~ s/^.*\///;
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
  
  # copy companion OSIS DICT
  my @skipCompanions;
  my @companionDictFiles;
  if ($DICTMOD) {
    my $companion = $DICTMOD;
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
  
  my $result;
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1copyCoverTo$3/;
  $figure->unbindNode();
  &writeXMLFile($xml, $output, $osisP);
  
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

sub isTran($) {
  my $scope = shift;
  if (!$scope) {return 0;}
  my $subdirs = &shell("find '$MAININPD/sfm' -maxdepth 1 -type d | wc -l", 3); chomp($a); $a--;
  my $nosubdir = (! -d "$MAININPD/sfm/$scope");
  return ($subdirs && $nosubdir ? 1:0);
}

sub getEbookName($$$$) {
  my $scope = shift;
  my $fullPubTitle = shift;
  my $confP = shift;
  my $type = shift;
  
  my $title = $scope . "_" . $type;
  $title =~ s/\s/_/g;
  
  return ($scope eq $confP->{"Scope"} ? &getFullEbookName($scope, $fullPubTitle, $confP):$title);
}

sub getFullEbookName($$$) {
  my $scope = shift;
  my $fullPubTitle = shift;
  my $confP = shift;
  
  my $s = $scope; $s =~ s/_/ /g;
  my $FullOrTran = (&isTran($s) ? 'Tran':'Full');
  my $ms = $confP->{"Scope"};
  $ms =~ s/\s/_/g;
  my $eBookFullPubName = ($fullPubTitle ? $fullPubTitle.'__':$ms.'_').$FullOrTran;
  $eBookFullPubName =~ s/\s+/-/g;
  
  return $eBookFullPubName;
}

sub makeEbook($$$$$) {
  my $tmp = shift;
  my $format = shift; # “epub”, "azw3" or “fb2”
  my $cover = shift; # path to cover image
  my $scope = shift;
  
  my $osis = "$tmp/$MOD.xml";
  
  &Log("\n--- CREATING $format FROM $osis FOR $scope\n", 1);
  
  if (!$format) {$format = 'fb2';}
  
  &updateOsisFullResourceURL($osis, &getFullEbookName($scope, $FULL_PUB_TITLE, $ConfEntryP).".$format");
  
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
    copy($out, "$EBOUT/$CONV_NAME.$format");
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
