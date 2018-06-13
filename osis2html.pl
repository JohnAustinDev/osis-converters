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

# usage: osis2html.pl [Project_Directory]

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();

&runAnyUserScriptsAt("html/preprocess", \$INOSIS);

# get scope and vsys of OSIS file
&setConfGlobals(&updateConfData($ConfEntryP, $INOSIS));

%HTMLCONV = &ebookReadConf("$INPD/html/convert.txt");

&writeHTML($INOSIS, $ConfEntryP);

# REPORT results
&Log("\n$MOD REPORT: HTML files created (".scalar(keys %HTMLREPORT)." instances):\n");
my @order = ('Format', 'Name', 'Title', 'Cover', 'Glossary', 'Filtered', 'ScripRefFilter', 'GlossRefFilter');
my %cm;
foreach my $c (@order) {$cm{$c} = length($c);}
foreach my $n (sort keys %HTMLREPORT) {
  $HTMLREPORT{$n}{'Name'} = $n;
  if (!$cm{$n} || length($HTMLREPORT{$n}) > $cm{$n}) {$cm{$n} = length($HTMLREPORT{$n});}
  foreach my $c (sort keys %{$HTMLREPORT{$n}}) {
    if ($c eq 'Format') {$HTMLREPORT{$n}{$c} = join(',', @{$HTMLREPORT{$n}{$c}});}
    if (length($HTMLREPORT{$n}{$c}) > $cm{$c}) {$cm{$c} = length($HTMLREPORT{$n}{$c});}
  }
}
my $p; foreach my $c (@order) {$p .= "%-".($cm{$c}+4)."s ";} $p .= "\n";
&Log(sprintf($p, @order));
foreach my $n (sort keys %HTMLREPORT) {
  my @a; foreach my $c (@order) {push(@a, $HTMLREPORT{$n}{$c});}
  &Log(sprintf($p, @a));
}

&Log("\nend time: ".localtime()."\n");

########################################################################
########################################################################

sub writeHTML($$) {
  my $inosis = shift;
  my $confP = shift;
  
  my $scope = $confP->{"Scope"};
  
  &Log("\n-----------------------------------------------------\nMAKING HTML\n", 1);
  &Log("\n");
  
  my $tmp = $TMPDIR;
  my $osis = "$tmp/$MOD.xml";
  &runXSLT("$SCRD/scripts/bible/osis2alternateVerseSystem.xsl", $inosis, $osis);
  
  # update osis header with current convert.txt
  &writeOsisHeader($osis, $ConfEntryP, \%HTMLCONV);
  
  # copy osis2xhtml.xsl
  copy("$SCRD/scripts/bible/html/osis2xhtml.xsl", $tmp);
  
  # copy css directory (css directory is the last of the following)
  my $css = "$SCRD/defaults/bible/eBook/css";
  if (-e "$INPD/../defaults/bible/eBook/css") {$css = "$INPD/../defaults/bible/eBook/css";}
  elsif (-e "$INPD/../../defaults/bible/eBook/css") {$css = "$INPD/../../defaults/bible/eBook/css";}
  elsif (-e "$INPD/eBook/css-default") {$css = "$INPD/eBook/css-default";}
  copy_dir($css, "$tmp/css");
  # module css is added to default css directory
  if (-e "$INPD/eBook/css") {copy_dir("$INPD/eBook/css", "$tmp/css", 1);}
  
  # if font is specified, include it
  if ($FONTS && $confP->{"Font"}) {
    &copyFont($confP->{"Font"}, $FONTS, \%FONT_FILES, "$tmp/css", 1);
    if (&runningVagrant()) {
      &shell("if [ -e ~/.fonts ]; then echo Font directory exists; else mkdir ~/.fonts; fi", 3);
      my $home = &shell("echo \$HOME", 3); chomp($home);
      &copyFont($confP->{"Font"}, $FONTS, \%FONT_FILES, "$home/.fonts");
    }
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
      $HTMLREPORT{$EBOOKNAME}{'Title'} = $ebookTitlePart;
      $HTMLREPORT{$EBOOKNAME}{'Cover'} = $covname;
      my $imagewidth = `identify "$INPD/eBook/$covname"`; $imagewidth =~ s/^.*?\bJPEG (\d+)x\d+\b.*$/$1/; $imagewidth = (1*$imagewidth);
      my $pointsize = (4/3)*$imagewidth/length($ebookTitlePart);
      if ($pointsize > 40) {$pointsize = 40;}
      elsif ($pointsize < 10) {$pointsize = 10;}
      my $padding = 20;
      my $barheight = $pointsize + (2*$padding);
      my $font = '';
      if ($FONTS && $confP->{"Font"}) {
        foreach my $f (keys %{$FONT_FILES{$confP->{"Font"}}}) {
          if ($FONT_FILES{$confP->{"Font"}}{$f}{'style'} eq 'regular') {
            $font = $FONT_FILES{$confP->{"Font"}}{$f}{'fullname'};
            $font =~ s/ /-/g;
            last;
          }
        }
      }
      my $cmd = "convert \"$INPD/eBook/$covname\" -gravity North -background LightGray -splice 0x$barheight -pointsize $pointsize ".($font ? "-font $font ":'')."-annotate +0+$padding '$ebookTitlePart' \"$cover\"";
      &shell($cmd, 2);
    }
    else {
      $HTMLREPORT{$EBOOKNAME}{'Title'} = 'no-title';
      $HTMLREPORT{$EBOOKNAME}{'Cover'} = $covname;
      copy("$INPD/eBook/$covname", $cover);
    }
  }
  else {
    $HTMLREPORT{$EBOOKNAME}{'Title'} = $ebookTitle;
    $HTMLREPORT{$EBOOKNAME}{'Cover'} = 'random-cover';
  }
  
  my @skipCompanions;
  my @companionDictFiles;
  foreach my $companion (split(/\s*,\s*/, $confP->{'Companion'})) {
    if (! -e "$tmp/tmp/dict") {make_path("$tmp/tmp/dict");}
  
    # copy companion OSIS file
    my $outf = &getProjectOsisFile($companion);
    my $filter = '0';
    if ($outf) {
      &copy($outf, "$tmp/tmp/dict/$companion.xml"); $outf = "$tmp/tmp/dict/$companion.xml";
      &runAnyUserScriptsAt("$companion/html/preprocess", \$outf);
      if ($companion =~ /DICT$/) {
        require "$SCRD/scripts/dict/processGlossary.pl";
        # A glossary module may contain multiple glossary divs, each with its own scope. So filter out any divs that don't match.
        # This means any non Bible scopes (like SWORD) are also filtered out.
        $filter = &filterGlossaryToScope(\$outf, $scope);
        &Log("NOTE: filterGlossaryToScope('$scope') filtered: ".($filter eq '-1' ? 'everything':($filter eq '0' ? 'nothing':$filter))."\n");
        my $aggfilter = &filterAggregateEntries(\$outf, $scope);
        &Log("NOTE: filterAggregateEntries('$scope') filtered: ".($aggfilter eq '-1' ? 'everything':($aggfilter eq '0' ? 'nothing':$aggfilter))."\n");
        if ($filter eq '-1') { # '-1' means all glossary divs were filtered out
          push(@skipCompanions, $companion);
          $HTMLREPORT{$EBOOKNAME}{'Glossary'} = 'no-glossary';
          $HTMLREPORT{$EBOOKNAME}{'Filtered'} = 'all';
          next;
        }
        else {
          &copy($outf, "$tmp/$companion.xml");
          push(@companionDictFiles, "$tmp/$companion.xml");
        }
      }
    }
    
    $HTMLREPORT{$EBOOKNAME}{'Glossary'} = $companion;
    $HTMLREPORT{$EBOOKNAME}{'Filtered'} = ($filter eq '0' ? 'none':$filter);
  }
  if (@skipCompanions) {
    my $xml = $XML_PARSER->parse_file($osis);
    # remove work elements of skipped companions or else the eBook converter will crash
    foreach my $c (@skipCompanions) {
      my @cn = $XPC->findnodes('//osis:work[@osisWork="'.$c.'"]', $xml);
      foreach my $cnn (@cn) {$cnn->parentNode()->removeChild($cnn);}
    }
    open(OUTF, ">$osis");
    print OUTF $xml->toString();
    close(OUTF);
  }
  
  # copy over only those images referenced in our OSIS files
  &copyReferencedImages($osis, $INPD, $tmp);
  foreach my $osis (@companionDictFiles) {
    my $companion = $osis; $companion =~ s/^.*\/([^\/\.]+)\.[^\.]+$/$1/;
    &copyReferencedImages($osis, &findCompanionDirectory($companion), $tmp);
  }
  
  # filter out any and all references pointing to targets outside our final OSIS file scopes
  $HTMLREPORT{$EBOOKNAME}{'ScripRefFilter'} = 0;
  $HTMLREPORT{$EBOOKNAME}{'GlossRefFilter'} = 0;
  $HTMLREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences($osis, $INOSIS);
  $HTMLREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences($osis, \@companionDictFiles, 1);
  
  foreach my $c (@companionDictFiles) {
    $HTMLREPORT{$EBOOKNAME}{'ScripRefFilter'} += &filterScriptureReferences($c, $INOSIS, $osis);
    $HTMLREPORT{$EBOOKNAME}{'GlossRefFilter'} += &filterGlossaryReferences($c, \@companionDictFiles, 1);
  }

  # run the converter
  &Log("\n--- CREATING HTML FROM $osis FOR $scope\n", 1);
  my @cssFileNames;
  my %params = ('css' => join(',', @cssFileNames));
  chdir($tmp);
  &runXSLT("osis2xhtml.xsl", $osis, "content.opf", \%params);
  chdir($SCRD);

  copy_dir("$tmp/xhtml", "$HTMLOUT/xhtml");
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

1;
