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

use strict;

our ($READLAYER, $WRITELAYER, $APPENDLAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($INOSIS, $HTMLOUT, $EBOUT, $EBOOKS, $LOGFILE, $XPC, $XML_PARSER, 
    %OSISBOOKS, $FONTS, $DEBUG, $ROC, $CONF, @SUB_PUBLICATIONS);

my ($INOSIS_XML, $IS_CHILDRENS_BIBLE, $CREATE_FULL_TRANSLATION, 
  $CREATE_SEPARATE_BOOKS, $CREATE_SEPARATE_PUBS, $FULLSCOPE, 
  $SERVER_DIRS_HP, $TRANPUB_SUBDIR, $TRANPUB_TYPE, $TRANPUB_TITLE, 
  $TRANPUB_NAME, $PUB_SUBDIR, $PUB_NAME, $PUB_TYPE, %CONV_REPORT);

sub osis2pubs {
  my $convertTo = shift;
  if ($convertTo !~ /^(eBook|html)$/) {
    &ErrorBug("convertOSIS: Conversion of OSIS to \"$convertTo\" is not yet supported.");
  }

  &runAnyUserScriptsAt("$convertTo/preprocess", \$INOSIS);
  
  &Log("Updating OSIS header.\n");
  &writeOsisHeader(\$INOSIS);
  
  my %params = (
    'conversion' => ($convertTo eq 'eBook' ? 'epub':'html'), 
    'MAINMOD_URI' => &getModuleOsisFile($MAINMOD), 
    'DICTMOD_URI' => ($DICTMOD ? &getModuleOsisFile($DICTMOD):'')
  );
  &runScript("$SCRD/scripts/osis2pubs.xsl", \$INOSIS, \%params);
  
  # Global for result reporting
  %CONV_REPORT;

  # Constants used by this script
  $INOSIS_XML = $XML_PARSER->parse_file($INOSIS);
  $IS_CHILDRENS_BIBLE = &isChildrensBible($INOSIS_XML);
  $CREATE_FULL_TRANSLATION = (&conf('CreateFullBible') eq 'AUTO' ? 'true':&conf('CreateFullBible') !~ /^false$/i);
  $CREATE_SEPARATE_BOOKS = (&conf('CreateSeparateBooks') eq 'AUTO' ? 
                           ($convertTo eq 'eBook' ? 'true':''):
                           (&conf('CreateSeparateBooks') =~ /^false$/i ? '':&conf('CreateSeparateBooks')));
  $CREATE_SEPARATE_PUBS = (&conf('CreateSeparatePubs') eq 'AUTO' ? 
                          ($convertTo =~ /(eBook|html)/ ? 'true':''):
                          (&conf('CreateSeparatePubs') =~ /^false$/i ? '':&conf('CreateSeparatePubs')));
                           
  $FULLSCOPE = ($IS_CHILDRENS_BIBLE ? '':&getScopeOSIS($INOSIS_XML)); # Children's Bibles must have empty scope for filterBibleToScope() to work right
  $SERVER_DIRS_HP = ($EBOOKS =~ /^https?\:\/\// ? &readServerScopes("$EBOOKS/$MAINMOD/$MAINMOD"):{});
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
    &getCanon(&conf("Versification"), undef, \$bookOrderP, undef);
    
    # convert the entire OSIS file
    if ($PUB_TYPE eq 'Tran') {
      $eBookSubDirs{$FULLSCOPE} = $SERVER_DIRS_HP->{$FULLSCOPE};
      foreach my $bk (@{&scopeToBooks($FULLSCOPE, $bookOrderP)}) {$parentPubScope{$bk} = $FULLSCOPE;}
      if ($CREATE_FULL_TRANSLATION) {&OSIS_To_ePublication($convertTo, $TRANPUB_TITLE, $FULLSCOPE);}
    }
    
    # convert any sub publications that are part of the OSIS file
    if ($CREATE_SEPARATE_PUBS || $TRANPUB_TYPE eq 'Full') {
      foreach my $scope (@SUB_PUBLICATIONS) {
        my $pscope = $scope; $pscope =~ s/\s/_/g;
        $PUB_TYPE = 'Full';
        $eBookSubDirs{$scope} = $SERVER_DIRS_HP->{$scope};
        foreach my $bk (@{&scopeToBooks($scope, $bookOrderP)}) {$parentPubScope{$bk} = $scope;}
        if ($scope eq $FULLSCOPE && !$CREATE_FULL_TRANSLATION) {next;}
        if ($scope ne $FULLSCOPE && $CREATE_SEPARATE_PUBS !~ /^true$/i && $CREATE_SEPARATE_PUBS ne $scope) {next;}
        $PUB_SUBDIR = $eBookSubDirs{$scope};
        $PUB_NAME = ($scope eq $FULLSCOPE ? $TRANPUB_NAME:&getEbookName($scope, $PUB_TYPE));
        &OSIS_To_ePublication($convertTo, &conf("TitleSubPublication[$pscope]"), $scope); 
      }
    }

    # convert each Bible book within the OSIS file
    if ($CREATE_SEPARATE_BOOKS) {
      $PUB_TYPE = 'Part';
      foreach my $aBook ($XPC->findnodes('//osis:div[@type="book"]', $INOSIS_XML)) {
        my $bk = $aBook->getAttribute('osisID');
        if ($CREATE_SEPARATE_BOOKS !~ /^true$/i && $CREATE_SEPARATE_BOOKS ne $bk) {next;}
        if (defined($eBookSubDirs{$bk})) {next;}
        $PUB_SUBDIR = $eBookSubDirs{$parentPubScope{$bk}};
        $PUB_NAME = &getEbookName($bk, $PUB_TYPE);
        my $pscope = $parentPubScope{$bk}; $pscope =~ s/\s/_/g;
        my $title = ($pscope && &conf("TitleSubPublication[$pscope]") ? &conf("TitleSubPublication[$pscope]"):$TRANPUB_TITLE);
        &OSIS_To_ePublication($convertTo, $title, $bk);
      }
    }
  }

  # REPORT results
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

sub OSIS_To_ePublication {
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
    &filterBibleToScope(
      \$osis,
      $scope,
      \$pubTitle, 
      \$partTitle
    );
  }
  
  my $cover = "$tmp/cover.jpg";
  my $coverSource = &copyCoverTo(\$osis, $cover);

  &copy($osis, "$tmp/$MOD.xml");
  
  if (!$coverSource) {$cover = '';}
  $CONV_REPORT{$PUB_NAME}{'Cover'} = '';
  if ($cover) {
    if ($PUB_TYPE eq 'Part') {
      &shell("mogrify ".&imageCaption(&imageInfo($cover)->{'w'}, $partTitle, &conf("Font"), 'white')." \"$cover\"", 3);
    }
    my $coverSourceName = $coverSource; $coverSourceName =~ s/^.*\///;
    $CONV_REPORT{$PUB_NAME}{'Cover'} = $coverSourceName . ($PUB_TYPE eq 'Part' ? " ($partTitle)":''); 
  }
  else {
    $CONV_REPORT{$PUB_NAME}{'Cover'} = "random-cover ($pubTitle)";
  }
  
  # copy osis2xhtml.xsl
  copy("$SCRD/scripts/bible/html/osis2xhtml.xsl", $tmp);
  &copyFunctionsXSL($tmp);
  
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
    our %FONT_FILES;
    &copyFont(&conf("Font"), $FONTS, \%FONT_FILES, "$tmp/css", 1);
    # The following allows Calibre to embed fonts (which must be installed locally) when 
    # the '--embed-all-fonts' flag is used with ebook-convert. This has been commented out
    # (and the flag removed from ebook-convert) because embeded fonts are unnecessary 
    # when font files are explicitly provided, and embeding never worked right anyway.
    #&shell("if [ -e ~/.fonts ]; then echo Font directory exists; else mkdir ~/.fonts; fi", 3);
    #my $home = &shell("echo \$HOME", 3); chomp($home);
    #&Note("Calibre can only embed fonts that are installed. Installing ".&conf("Font")." to host.");
    #&copyFont(&conf("Font"), $FONTS, \%FONT_FILES, "$home/.fonts");
    if (open(CSS, $WRITELAYER, "$tmp/css/10font.css")) {
      my %font_format = ('ttf' => 'truetype', 'otf' => 'opentype', 'woff' => 'woff');
      foreach my $f (sort keys %{$FONT_FILES{&conf("Font")}}) {
        my $format = $font_format{lc($FONT_FILES{&conf("Font")}{$f}{'ext'})};
        if (!$format) {&Log("WARNNG: Font \"$f\" has an unknown format; src format will not be specified.\n");}
        print CSS '
@font-face {
  font-family:font1;
  src: url(\'./'.$f.'\')'.($format ? ' format(\''.$format.'\')':'').';
  font-weight: '.($FONT_FILES{&conf("Font")}{$f}{'style'} =~ /bold/i ? 'bold':'normal').'; font-style: '.($FONT_FILES{&conf("Font")}{$f}{'style'} =~ /italic/i ? 'italic':'normal').';
}
';
      }
      print CSS '
body {font-family: font1;}

';
      if (open(FCSS, $READLAYER, "$FONTS/".&conf("Font").".eBook.css")) {while(<FCSS>) {print CSS $_;} close(FCSS);}
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
      my %params = (
        'conversion' => ($convertTo eq 'eBook' ? 'epub':'html'), 
        'MAINMOD_URI' => &getModuleOsisFile($MAINMOD), 
        'DICTMOD_URI' => ($DICTMOD ? &getModuleOsisFile($DICTMOD):'')
      );
      &runScript("$SCRD/scripts/osis2pubs.xsl", \$outf, \%params);
      # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
      # This means any non Bible scopes (like SWORD) are also filtered out.
      $filter = &filterGlossaryToScope(\$outf, $scope);
      &Note("filterGlossaryToScope('$scope') filtered: ".($filter eq '-1' ? 'everything':($filter eq '0' ? 'nothing':$filter)));
      my $aggfilter = &filterAggregateEntriesToScope(\$outf, $scope);
      &Note("filterAggregateEntriesToScope('$scope') filtered: ".($aggfilter eq '-1' ? 'everything':($aggfilter eq '0' ? 'nothing':$aggfilter)));
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
  $CONV_REPORT{$PUB_NAME}{'GlossRefFilter'} += &filterGlossaryReferences("$tmp/$MOD.xml", $dictTmpOsis);
  
  if ($dictTmpOsis) {
    $CONV_REPORT{$PUB_NAME}{'ScripRefFilter'} += &filterScriptureReferences($dictTmpOsis, $INOSIS, "$tmp/$MOD.xml");
    $CONV_REPORT{$PUB_NAME}{'GlossRefFilter'} += &filterGlossaryReferences($dictTmpOsis, $dictTmpOsis);
  }

  # now do the conversion on the temporary directory's files
  if ($convertTo eq 'html') {
    &makeHTML($tmp, $cover, $scope, $pubTitle);
    
    # Use linkchecker to check all links of output html
    &Log("--- CHECKING html links in \"$HTMLOUT/$PUB_NAME/index.xhtml\"\n");
    my $result = &shell("linkchecker \"$HTMLOUT/$PUB_NAME/index.xhtml\"", 3);
    if ($result =~ /^That's it\. (\d+) links in (\d+) URLs checked\. (\d+) warnings found\. (\d+) errors found\./m) {
      my $link = 1*$1; my $urls = 1*$2; my $warn = 1*$3; my $err = 1*$4;
      if ($warn || $err) {&Log("$result\n");}
      &Report("Checked $link resulting html links (".($warn+$err)." problems).");
      if ($warn) {&Warn("See above linkchecker warnings.");}
      if ($err) {&Error("See above linkchecker errors.");}
    }
    else {&ErrorBug("Could not parse output of linkchecker:\n$result\n", "Check the version of linkchecker.");}
    
    # Look for any unreachable material
    &Log("\n--- CHECKING for unreachable material in \"$HTMLOUT/$PUB_NAME/xhtml\"\n");
    my @files = split(/\n+/, &shell("find \"$HTMLOUT/$PUB_NAME/xhtml\" -type f", 3));
    push(@files, "$HTMLOUT/$PUB_NAME/index.xhtml");
    my %linkedFiles; 
    $linkedFiles{&shortLinuxPath("$HTMLOUT/$PUB_NAME/index.xhtml")}++;
    foreach my $f (@files) {&getLinkedFiles($f, \%linkedFiles);}
    my $numUnreachable = 0;
    foreach my $f (@files) {
      if (!defined($linkedFiles{&shortLinuxPath($f)})) {
        $numUnreachable++;
        my $sf = $f; $sf =~ s/^.*\/(xhtml\/)/$1/;
        &Warn("File '$sf' is unreachable. It contains:\n".&shell("cat \"$f\"", 3), "If you want to make the above material accesible, add a \\toc".&conf('TOC')." tag to it.");
      }
    }
    &Report("Found $numUnreachable unreachable file(s) in '$HTMLOUT/$PUB_NAME/xhtml'");
  }
  elsif ($convertTo eq 'eBook') {
    if ($DEBUG !~ /no.?epub/i) {&makeEbook($tmp, 'epub', $cover, $scope);}
    if ($DEBUG !~ /no.?azw3/i) {&makeEbook($tmp, 'azw3', $cover, $scope);}
    # fb2 is disabled until a decent FB2 converter is written
    # &makeEbook("$tmp/$MOD.xml", 'fb2', $cover, $scope, $tmp);
  }
}

########################################################################
########################################################################

sub getLinkedFiles {
  my $f = shift;
  my $hP = shift;

  my $dir = $f; $dir =~ s/[^\/]+$//;
  my $html = eval {$XML_PARSER->load_html(location => $f)};
  if ($@ =~ /error/i) {
    &Error("Problem(s) occured reading $f:\n".decode('utf8', $@)."\n");
  }
  if ($html) {
    foreach my $link ($html->findnodes('//a')) {
      my $file = $link->getAttribute('href');
      $file =~ s/[\?\#].*$//;
      if (!$file) {next;}
      $hP->{&shortLinuxPath($dir.$file)}++;
    }
  }
  else {&Error("$f is not a parseable HTML file.", 
  "Fix all previous errors and if the file is still not  
parseable, contact the osis-converters maintainer.\n");}
}


# Copy inosis to outosis, while pruning books and other bookGroup child 
# elements according to scope. Any changes made during the process are 
# noted in the log file with a note.
#
# If any bookGroup is left with no books in it, then the entire bookGroup 
# element (including its introduction if there is one) is dropped.
#
# If any book (kept or pruned) contains or is preceded by peripheral(s) 
# which pertain to any kept book, the peripheral(s) are kept. If 
# peripheral(s) pertaining to more than one book are within a book, they 
# will be moved up out of the book they're in and inserted before the 
# first applicable kept book, so as to retain the peripheral.
#
# If any bookSubGroup introduction is not immediately followed by a book 
# (after book pruning) then that bookSubGroup introduction is removed.
#
# If there is only one bookGroup left, the remaining one's TOC milestone
# will become [not_parent] so as to prevent an unnecessary TOC level,
# or, if the Testament intro is empty, it will be entirely removed.
#
# If a sub-publication cover matches the scope, it will be moved to 
# replace the main cover. Or when pruning to a single book that matches
# a sub-publication cover, it will be moved to relace the main cover.
#
# The ebookTitleP will have appended to it the list of books remaining 
# after filtering IF any were filtered out. The final ebook title will 
# then be written to the outosis file.
#
# The ebookPartTitleP is overwritten by the list of books left after
# filtering IF any were filtered out, otherwise it is set to ''.
sub filterBibleToScope {
  my $osisP = shift;
  my $scope = shift;
  my $ebookTitleP = shift;
  my $ebookPartTitleP= shift;
  
  my $tocNum = &conf('TOC');
  my $bookTitleTocNum = &conf('TitleTOC');
  
  my $inxml = $XML_PARSER->parse_file($$osisP);
  my $fullScope = &getScopeOSIS($inxml);
  my $subPublication;
  foreach my $sp (@SUB_PUBLICATIONS) {
    if ($sp eq $scope) {$subPublication = $sp;}
  }
  
  my $bookOrderP;
  my $booksFiltered = 0;
  if (!&getCanon(&conf('Versification'), '', \$bookOrderP, '')) {
    &ErrorBug("pruneFileOSOS getCanon(".&conf('Versification').") failed, not pruning books in OSIS file");
    return;
  }
  
  my @scopedPeriphs = $XPC->findnodes('//osis:div[@scope]', $inxml);
  
  # remove books not in scope
  my %scopeBookNames = map { $_ => 1 } @{&scopeToBooks($scope, $bookOrderP)};
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
  my @filteredBooks;
  foreach my $bk (@books) {
    my $id = $bk->getAttribute('osisID');
    if (!exists($scopeBookNames{$id})) {
      $bk->unbindNode();
      push(@filteredBooks, $id);
      $booksFiltered++;
    }
  }
  
  if ($booksFiltered) {
    &Note("Filtered \"".scalar(@filteredBooks)."\" books that were outside of scope \"$scope\".", 1);
    
    foreach my $d (@scopedPeriphs) {$d->unbindNode();}

    # remove bookGroup if it has no books left (even if it contains other peripheral material)
    my @emptyBookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"][not(child::osis:div[@type="book"])]', $inxml);
    my $msg = 0;
    foreach my $ebg (@emptyBookGroups) {$ebg->unbindNode(); $msg++;}
    if ($msg) {
      &Note("Filtered \"$msg\" bookGroups which contained no books.", 1);
    }
    
    # if there's only one bookGroup now, change its TOC entry to [not_parent] or remove it, to prevent unnecessary TOC levels and entries
    my @grps = $XPC->findnodes('//osis:div[@type="bookGroup"]', $inxml);
    if (scalar(@grps) == 1 && @grps[0]) {
      my $ms = @{$XPC->findnodes('child::osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1] | child::*[1][not(self::osis:div[@type="book"])]/osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1]', @grps[0])}[0];
      if ($ms) {
        my $resp = @{$XPC->findnodes('ancestor-or-self::*[@resp="'.$ROC.'"][last()]', $ms)}[0];
        my $firstIntroPara = @{$XPC->findnodes('self::*[@n]/ancestor::osis:div[@type="bookGroup"]/descendant::osis:p[child::text()[normalize-space()]][1][not(ancestor::osis:div[@type="book"])]', $ms)}[0];
        my $fipMS = ($firstIntroPara ? @{$XPC->findnodes('preceding::osis:milestone[@type="x-usfm-toc'.$tocNum.'"][1]', $firstIntroPara)}[0]:'');
        if (!$resp && $firstIntroPara && $fipMS->unique_key eq $ms->unique_key) {
          $ms->setAttribute('n', '[not_parent]'.$ms->getAttribute('n'));
          &Note("Changed TOC milestone from bookGroup to n=\"".$ms->getAttribute('n')."\" because there is only one bookGroup in the OSIS file.", 1);
        }
        # don't include in the TOC if there is no intro p or the first intro p is under different TOC entry
        elsif ($resp) {
          &Note("Removed auto-generated TOC milestone from bookGroup because there is only one bookGroup in the OSIS file:\n".$resp->toString."\n", 1);
          $resp->unbindNode();
        }
        else {
          &Note("Removed TOC milestone from bookGroup with n=\"".$ms->getAttribute('n')."\" because there is only one bookGroup in the OSIS file and the entry contains no paragraphs.", 1);
          $ms->unbindNode();
        }
      }
    }
    
    # move relevant scoped periphs before first kept book.
    my @remainingBooks = $XPC->findnodes('/osis:osis/osis:osisText//osis:div[@type="book"]', $inxml);
    INTRO: foreach my $intro (@scopedPeriphs) {
      my $introBooks = &scopeToBooks($intro->getAttribute('scope'), $bookOrderP);
      if (!@{$introBooks}) {next;}
      foreach my $introbk (@{$introBooks}) {
        foreach my $remainingBook (@remainingBooks) {
          if ($remainingBook->getAttribute('osisID') ne $introbk) {next;}
          $remainingBook->parentNode->insertBefore($intro, $remainingBook);
          my $t1 = $intro; $t1 =~ s/>.*$/>/s;
          my $t2 = $remainingBook; $t2 =~ s/>.*$/>/s;
          &Note("Moved peripheral: $t1 before $t2", 1);
          next INTRO;
        }
      }
      my $t1 = $intro; $t1 =~ s/>.*$/>/s;
      &Note("Removed peripheral: $t1", 1);
    }
  }
  
  # Update title references and determine pruned OSIS file's new title
  my $osisTitle = @{$XPC->findnodes('/descendant::osis:type[@type="x-bible"][1]/ancestor::osis:work[1]/descendant::osis:title[1]', $inxml)}[0];
  if ($booksFiltered && !$subPublication) {
    my @books = $XPC->findnodes('//osis:div[@type="book"]', $inxml);
    my @bookNames;
    foreach my $b (@books) {
      my @t = $XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.$bookTitleTocNum.'"]/@n', $b);
      if (@t[0]) {push(@bookNames, @t[0]->getValue());}
    }
    $$ebookPartTitleP = join(', ', @bookNames);
  }
  else {$$ebookPartTitleP = '';}
  if ($$ebookPartTitleP) {$$ebookTitleP .= ": $$ebookPartTitleP";}
  if ($$ebookTitleP ne $osisTitle->textContent) {
    &changeNodeText($osisTitle, $$ebookTitleP);
    &Note('Updated OSIS title to "'.$osisTitle->textContent."\"", 1);
  }
  
  # move matching sub-publication cover to top
  my $s = $scope; $s =~ s/\s+/_/g;
  my $subPubCover = @{$XPC->findnodes("//osis:figure[\@subType='x-sub-publication'][contains(\@src, '/$s.')]", $inxml)}[0];
  if (!$subPubCover && $scope && $scope !~ /[_\s\-]/) {
    foreach my $figure ($XPC->findnodes("//osis:figure[\@subType='x-sub-publication'][\@src]", $inxml)) {
      my $sc = $figure->getAttribute('src'); $sc =~ s/^.*\/([^\.]+)\.[^\.]+$/$1/; $sc =~ s/_/ /g;
      my $bkP = &scopeToBooks($sc, $bookOrderP);
      foreach my $bk (@{$bkP}) {if ($bk eq $scope) {$subPubCover = $figure;}}
    }
  }
  if ($subPubCover) {
    $subPubCover->unbindNode();
    $subPubCover->setAttribute('subType', 'x-full-publication');
    my $cover = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[1][local-name()="div"]/osis:figure[@type="x-cover"]', $inxml)}[0];
    if ($cover) {
      &Note("Replacing original cover image with sub-publication cover: ".$subPubCover->getAttribute('src'), 1);
      $cover->parentNode->insertAfter($subPubCover, $cover);
      $cover->unbindNode();
    }
    else {
      &Note("Moving sub-publication cover ".$subPubCover->getAttribute('src')." to publication cover position.", 1);
      &insertPubCover($subPubCover, $inxml);
    }
  }
  if ($scope && $scope ne $fullScope && !$subPubCover) {&Warn("A Sub-Publication cover was not found for $scope.", 
"If a custom cover image is desired for $scope then add a file 
./images/$s.jpg with the image. ".($scope !~ /[_\s\-]/ ? "Alternatively you may add 
an image whose filename is any scope that contains $scope":''));}
  
  &writeXMLFile($inxml, $osisP);
}

# Returns names of filtered divs, or else '-1' if all were be filtered or '0' if none were be filtered
sub filterGlossaryToScope {
  my $osisP = shift; # OSIS to filter
  my $scope = shift; # scope to filter to
  
  my $bookOrderP; &getCanon(&conf("Versification"), undef, \$bookOrderP, undef);
  
  my @removed;
  my @kept;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my @glossDivs = $XPC->findnodes('//osis:div[@type="glossary"][not(@subType="x-aggregate")]', $xml);
  foreach my $div (@glossDivs) {
    my $divScope = $div->getAttribute('scope');
    
    # keep all glossary divs that don't specify a particular scope
    if (!$divScope) {push(@kept, $divScope); next;}
    
    # keep if scope is not a Bible scope
    my $bksAP = &scopeToBooks($divScope, $bookOrderP);
    if (!@{$bksAP}) {next;}
    
    # keep if any book within the Bible scope matches $scope
    if (&inContext(&getScopeAttributeContext($divScope, $bookOrderP), &getContextAttributeHash($scope))) {
      push(@kept, $divScope);
      next;
    }
    
    $div->unbindNode();
    push(@removed, $divScope);
  }

  if (!@removed) {return '0';}
  
  # since at least one keyword was filtered out, some built in keyword navmenus are now wrong, so just remove them all to be sure
  foreach my $nm ($XPC->findnodes('//osis:div[starts-with(@type, "x-keyword")]/descendant::osis:item[@subType="x-prevnext-link"]', $xml)) {
    $nm->unbindNode();
  }

  if (@removed == @glossDivs) {return '-1';}
  
  &writeXMLFile($xml, $osisP);
  
  return join(',', @removed);
}

# Returns scopes of filtered entries, or else '-1' if all were filtered or '0' if none were filtered
sub filterAggregateEntriesToScope {
  my $osisP = shift;
  my $scope = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my @check = $XPC->findnodes('//osis:div[@type="glossary"][@subType="x-aggregate"]//osis:div[@type="x-aggregate-subentry"]', $xml);
  my $bookOrderP; &getCanon(&conf("Versification"), undef, \$bookOrderP, undef);
  
  my @removed; my $removeCount = 0;
  foreach my $subentry (@check) {
    my $glossScope = $subentry->getAttribute('scope');
    if ($glossScope && !&inContext(&getScopeAttributeContext($glossScope, $bookOrderP), &getContextAttributeHash($scope))) {
      $subentry->unbindNode();
      my %scopes = map {$_ => 1} @removed;
      if (!$scopes{$glossScope}) {push(@removed, $glossScope);}
      $removeCount++;
    }
  }
  
  &writeXMLFile($xml, $osisP);
  
  if ($removeCount == scalar(@check)) {&removeAggregateEntries($osisP);}
  
  return ($removeCount == scalar(@check) ? '-1':(@removed ? join(',', @removed):'0'));
}

# Filter all Scripture reference links in a Bible/Dict osis file: A Dict osis file
# must have a Bible companionOsis associated with it, to be the target of its  
# Scripture references. Scripture reference links whose target book isn't in
# itself or a companion, and those missing osisRefs, will be fixed. There are 
# three ways these broken references are handled:
# 1) Delete the reference: It must be entirely deleted if it is not human readable.
#    Cross-reference notes are not readable if they appear as just a number 
#    (because an abbreviation for the book was not available in the translation).
# 2) Redirect: Partial eBooks can redirect to a full eBook if the link is readable,
#    FullResourceURL is provided in config.conf, and the fullOsis resource contains 
#    the target.
# 3) Remove hyper-link: This happens if the link is readable, but it could not be
#    redirected to another resource, or it's missing an osisRef.
sub filterScriptureReferences {
  my $osisToFilter = shift;    # The osis file to filter (Bible or Dictionary)
  my $osisBibleTran = shift;   # The osis file of the entire Bible translation osis (before pruning)
  my $osisBiblePruned = shift; # The osis file of the pruned Bible osis (if left empty, this will be $osisToFilter) 
  
  if (!$osisBiblePruned) {$osisBiblePruned = $osisToFilter;}
  
  my $xml_osis       = $XML_PARSER->parse_file($osisToFilter);
  my $xmlBiblePruned = $XML_PARSER->parse_file($osisBiblePruned);
  my $xmlBibleTran   = $XML_PARSER->parse_file($osisBibleTran);
  
  my %prunedOsisBooks = map {$_->value, 1} @{$XPC->findnodes('//osis:div[@type="book"]/@osisID', $xmlBiblePruned)};
  my %tranOsisBooks   = map {$_->value, 1} @{$XPC->findnodes('//osis:div[@type="book"]/@osisID', $xmlBibleTran)};
  my $noBooksPruned = (join(' ', sort keys %prunedOsisBooks) eq join(' ', sort keys %tranOsisBooks));
  
  my $fullResourceURL = @{$XPC->findnodes('/descendant::*[contains(@type, "FullResourceURL")][1]', $xmlBiblePruned)}[0];
  if ($fullResourceURL) {$fullResourceURL = $fullResourceURL->textContent;}
  my $mayRedirect = ($fullResourceURL && $fullResourceURL !~ /false/i && !$noBooksPruned);
  
  &Log("\n--- FILTERING Scripture references in \"$osisToFilter\"\n", 1);
  &Log("Deleting unreadable cross-reference notes and removing hyper-links for 
references which target outside ".($noBooksPruned ? 'the translation':"\"$osisBiblePruned\""));
  if ($mayRedirect) {
    &Log(", unless they may be\nredirected to \"$fullResourceURL\"");
  }
  else {
    &Log(".\n");
  }
  
  if (!$noBooksPruned && !$mayRedirect) {
    &Error("Redirect some cross-reference notes, rather than removing them.", 
    "Specify FullResourceURL in config.conf with the URL of the full ePublication.");
  }

  # xref = cross-references, sref = scripture-references, nref = no-osisRef-references
  my %delete    = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %deleteBks   = {'xref'=>{},'sref'=>{},'nref'=>{}};
  my %redirect  = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %redirectBks = {'xref'=>{},'sref'=>{},'nref'=>{}};
  my %remove    = {'xref'=>0,'sref'=>0, 'nref'=>0}; my %removeBks   = {'xref'=>{},'sref'=>{},'nref'=>{}};
  
  my @links = $XPC->findnodes('//osis:reference[not(@type="x-glosslink" or @type="x-glossary")]', $xml_osis);
  foreach my $link (@links) {
    my $bk = ($link->getAttribute('osisRef') && $link->getAttribute('osisRef') =~ /^(([^\:]+?):)?([^\.]+)(\.|$)/ ? $3:'');
    if ($link->getAttribute('osisRef') && !$bk) {
      &Error("filterScriptureReferences: Unhandled osisRef=\"".$link->getAttribute('osisRef')."\"");
    }
    else {
      if ($bk && exists($prunedOsisBooks{$bk})) {next;}
      
      # This links's osisRef is not valid within xml_osis, so choose an action:
      my $refType = ($link->getAttribute('osisRef') ? (@{$XPC->findnodes('ancestor::osis:note[@type="crossReference"][1]', $link)}[0] ? 'xref':'sref'):'nref');
      my $isExternal = ($link->getAttribute('subType') eq 'x-external'); # x-external means it is outside the entire translation
      
      # Delete (entire hyperlink is removed)
      if ($refType eq 'xref' && ($isExternal || $link->textContent() =~ /^[\s,\d]*$/)) {
        $link->unbindNode();
        $delete{$refType}++; if ($bk) {$deleteBks{$refType}{$bk}++;}
      }
      # Redirect (hyperlink target is x-other-resource)
      elsif ($refType ne 'nref' && $mayRedirect && exists($tranOsisBooks{$bk})) {
        $link->setAttribute('subType', 'x-other-resource');
        $redirect{$refType}++; if ($bk) {$redirectBks{$refType}{$bk}++;}
      }
      # Remove (hyperlink changed to text)
      else {
        my @children = $link->childNodes();
        foreach my $child (@children) {$link->parentNode->insertBefore($child, $link);}
        $link->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk(' '), $link);
        $link->unbindNode();
        $remove{$refType}++; if ($bk) {$removeBks{$refType}{$bk}++;}
      }
    }
  }
  
  # remove any cross-references with nothing left in them
  my $deletedXRs = 0;
  if ($delete{'xref'}) {
    my @links = $XPC->findnodes('//osis:note[@type="crossReference"][not(descendant::osis:reference[@type != "annotateRef" or not(@type)])]', $xml_osis);
    foreach my $link (@links) {$link->unbindNode(); $deletedXRs++;}
  }
  
  &writeXMLFile($xml_osis, $osisToFilter);
  
  # REPORT results for osisToFilter
  &Log("\n");
  foreach my $stat ('redirect', 'remove', 'delete') {
    foreach my $type ('sref', 'xref', 'nref') {
      my $t = ($type eq 'xref' ? 'cross     ':($type eq 'sref' ? 'Scripture ':'no-osisRef'));
      my $s = ($stat eq 'redirect' ? 'Redirected':($stat eq 'remove' ? 'Removed   ':'Deleted   '));
      my $tc; my $bc;
      if ($stat eq 'redirect') {$tc = $redirect{$type}; $bc = scalar(keys(%{$redirectBks{$type}}));}
      if ($stat eq 'remove')   {$tc = $remove{$type};   $bc = scalar(keys(%{$removeBks{$type}}));}
      if ($stat eq 'delete')   {$tc = $delete{$type};   $bc = scalar(keys(%{$deleteBks{$type}}));}
      &Report(sprintf("<-$s %5i $t references - targeting %2i different book(s)", $tc, $bc));
    }
  }
  &Report("\"$deletedXRs\" Resulting empty cross-reference notes were deleted.");
  
  return ($delete{'sref'} + $redirect{'sref'} + $remove{'sref'});
}

# Filter out glossary reference links that are outside the scope of glossRefOsis
sub filterGlossaryReferences {
  my $osis = shift;
  my $glossRefOsis = shift;
  
  my %refsInScope;
  my $glossMod = $glossRefOsis; $glossMod =~ s/^.*\///;
  if ($glossRefOsis) {
    my $glossRefXml = $XML_PARSER->parse_file($glossRefOsis);
    my $work = &getOsisIDWork($glossRefXml);
    my @osisIDs = $XPC->findnodes('//osis:seg[@type="keyword"]/@osisID', $glossRefXml);
    push(@osisIDs, @{$XPC->findnodes('//osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]/@osisID', $glossRefXml)});
    my %ids;
    foreach my $osisID (@osisIDs) {
      my $id = $osisID->getValue();
      $id =~ s/^(\Q$work\E)://;
      $ids{$id}++;
    }
    $refsInScope{$work} = \%ids;
    $refsInScope{$MOD}{'BIBLE_TOP'}++;
    $refsInScope{$DICTMOD}{'DICT_TOP'}++;
  }
  
  &Log("\n--- FILTERING glossary references in \"$osis\"\n", 1);
  &Log("REMOVING glossary references".($glossMod ? " that target outside \"$glossMod\"":'')."\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  
  # filter out references outside our scope (but don't check those which 
  # in the INT feature, as they might be forwarded by osis2xhtml.xsl)
  my @links = $XPC->findnodes('//osis:reference[@osisRef][@type="x-glosslink" or @type="x-glossary"]
      [not(ancestor::osis:div[@annotateType="x-feature"][@annotateRef="INT"])]', $xml);
  my %removedOsisRefs; my %modifiedOsisRefs;
  my $totalRemovedOsisRefs = 0; my $totalModifiedOsisRefs = 0;
  my %noteMulti;
  foreach my $link (@links) {
    my $refs = $link->getAttribute('osisRef');
    my @new;
    foreach my $ref (split(/\s+/, $refs)) {
      if ($ref =~ /^(([^\:]+?):)?(.+)$/) {
        my $osisRef = $3;
        my $work = ($1 ? $2:&getOsisRefWork($xml));
        if (exists($refsInScope{$work}{$osisRef})) {
          push(@new, $ref);
        }
      }
    }
    my $newrefs = join(' ', @new);
    if (!$newrefs) {
      my @children = $link->childNodes();
      foreach my $child (@children) {$link->parentNode->insertBefore($child, $link);}
      $link->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk(' '), $link);
      $link->unbindNode();
      $removedOsisRefs{$refs}++;
      $totalRemovedOsisRefs++;
    }
    elsif ($newrefs ne $refs) {
      $link->setAttribute('osisRef', $newrefs);
      $modifiedOsisRefs{$newrefs}++;
      $totalModifiedOsisRefs++;
    }
    if ($link->getAttribute('osisRef') =~ /^(\S+)\s+(.*)$/) {
      $noteMulti{$link->getAttribute('osisRef')} = $1;
    }
  }
  
  # remove resulting empty x-keyword-aggregate divs
  foreach my $empty (@{$XPC->findnodes('//osis:div[@type="x-keyword-aggregate"][not(descendant::osis:div[@type="x-aggregate-subentry"])]', $xml)}) {
    &Note("Removed empty x-keyword-aggregate '".$empty->textContent()."'");
    $empty->unbindNode();
  }

  &writeXMLFile($xml, $osis);
  
  my $mname = &getModNameOSIS($xml);
  
  if (%noteMulti) {
    &Note("Glossary references with multi-target osisRefs exist in $mname, but secondary targets will be ignored:");
    foreach my $osisRef (sort keys %noteMulti) {&Log("\t$osisRef\n");}
  }
  
  &Report("\"$totalRemovedOsisRefs\" glossary references were removed from $mname:");
  foreach my $r (sort keys %removedOsisRefs) {
    &Log(&decodeOsisRef($r)." (osisRef=\"".$r."\")\n");
  }
  &Report("\"$totalModifiedOsisRefs\" multi-target glossary references were filtered in $mname:");
  foreach my $r (sort keys %modifiedOsisRefs) {
    &Log(&decodeOsisRef($r)." (osisRef=\"".$r."\")\n");
  }
  
  return $totalRemovedOsisRefs;
}

# Calibre requires the eBook cover be passed separately from the OSIS file.
# So remove the cover div element from the OSIS file and copy the referenced
# image to $coverpath. If there is no div element, or the referenced image
# cannot be found, the empty string is returned, otherwise the path to the
# referenced image is returned.
sub copyCoverTo {
  my $osisP = shift;
  my $coverpath = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  my $figure = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/following-sibling::*[1][local-name()="div"]/osis:figure[@type="x-cover"]', $xml)}[0];
  if (!$figure) {return '';}
  
  $figure->unbindNode();
  
  &writeXMLFile($xml, $osisP);
  
  my $result;
  my $source = "$MAININPD/".$figure->getAttribute('src');
  if (-e $source && -f $source) {
    &copy($source, $coverpath);
    if (&imageInfo($coverpath)->{'w'} <= 200) {
      # small covers should made wider to prevent pixelation
      &changeImageWidth($coverpath, 400);
    }
    $result = $source;
  }
  else {&Error("Cover image $source does not exist!", "Add the cover image to the path, or try re-running sfm2osis.pl to retrive cover images.");}
  
  &Log("\n--- COPYING COVER IMAGE $source\n", 1);
  
  return $result;
}

sub makeHTML {
  my $tmp = shift;
  my $cover = shift;
  my $scope = shift;
  my $title = shift;
  
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
  if (open(INDX, $WRITELAYER, "$HTMLOUT/$PUB_NAME/index.xhtml")) {
    my $tophref = &shell("perl -0777 -ne 'print \"\$1\" if /<manifest[^>]*>.*?<item href=\"([^\"]+)\"/s' \"$tmp/content.opf\"", 3);
    my $header = &shell("perl -0777 -ne 'print \"\$1\" if /^(.*?<\\/head[^>]*>)/s' \"$tmp/$tophref\"", 3);
    $header =~ s/(<link[^>]+href=")\.(\.\/css\/[^>]*>)/$1$2/sg;
    $header =~ s/(<title[^>]*>).*?(<\/title>)/$1$title$2/s;
    print INDX $header.'
  <body class="calibre index'.($cover && -e $cover ? ' with-cover':'').'">';
    if ($cover && -e $cover) {
      print INDX '
    <a class="cover" href="'.$tophref.'"><img src="./images/'.$coverName.'"/></a>';
    }
    print INDX '
    <a class="text" href="'.$tophref.'">'.$title.'</a>
  </body>
</html>
';
    close(INDX);
  }
  else {
    &ErrorBug("makeHTML: Could not open \"$HTMLOUT/$PUB_NAME/index.xhtml\" for writing");
  }
}

sub makeEbook {
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
      my $noEpub3Markup = (&conf('ARG_noEpub3Markup') =~ /^yes$/i);
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

# Return the filename (without file extension)
sub getEbookName {
  my $scope = shift;
  my $type = shift;

  my $fs = $scope; $fs =~ s/\s/_/g;
  return $fs . "_" . $type;
}

# Return the filename of a full eBook publication (without extension).
sub getFullEbookName {
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

sub readServerScopes {
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
sub updateOsisFullResourceURL {
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
      &changeNodeText($u, urlencode($new));
      $update++;
    }
    &Note("FullResourceURL is \"".$u->textContent."\".");
  }
  
  if ($update) {&writeXMLFile($xml, $osis);}
}

# Add context parameters to the functions.xsl file as a way to pass them 
# through to Calibre. This functions plays the role of runXSLT() allowing
# Calibre to know the script context.
sub copyFunctionsXSL {
  my $dest = shift;
  
  no strict "refs";
  
  my $file = "$SCRD/scripts/functions/functions.xsl";
  my $name = $file; $name =~ s/^.*\///;
  my $c = 0;
  if (open(FUNC, $READLAYER, $file)) {
    if (open(DFUNC, $WRITELAYER, "$dest/$name")) {
      while(<FUNC>) {
        if ($_ =~ s/^\s*\<param [^\>]*name="(SCRIPT_NAME|DICTMOD|DEBUG)"[^\>]*\/>/<variable name="$1" select="'$$1'"\/>/) {$c++;}
        print DFUNC $_;
      }
    }
    else {&ErrorBug("Could not open $dest/$name", 1);}
    close(DFUNC);
  }
  else {&ErrorBug("Could not open $file", 1);}
  close(FUNC);
  if ($c != 3) {&ErrorBug("Failed to add context to '$file' at '$dest/$name'.", 1);}
}

sub removeAggregateEntries {
  my $osisP = shift;

  my $xml = $XML_PARSER->parse_file($$osisP);
  my @dels = $XPC->findnodes('//osis:div[@type="glossary"][@subType="x-aggregate"]', $xml);
  foreach my $del (@dels) {$del->unbindNode();}
  
  &writeXMLFile($xml, $osisP);
}

1;
