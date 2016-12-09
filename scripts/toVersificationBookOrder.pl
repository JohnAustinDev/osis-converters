# This file is part of "osis-converters".
# 
# Copyright 2015 John Austin (gpl.programs.info@gmail.com)
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

# The following MAPs were taken from usfm2osis.py and apply to USFM 2.4
%ID_TYPE_MAP = (
  # File ID code => <div> type attribute value
  'FRT' => 'front',
  'INT' => 'introduction',
  'BAK' => 'back',
  'CNC' => 'concordance',
  'GLO' => 'glossary',
  'TDX' => 'index',
  'NDX' => 'gazetteer',
  'OTH' => 'x-other'
);

%PERIPH_TYPE_MAP = (
  # Text following \periph => <div> type attribute value
  'Title Page' => 'titlePage', 
  'Half Title Page' => 'x-halfTitlePage', 
  'Promotional Page' => 'x-promotionalPage',
  'Imprimatur' => 'imprimatur', 
  'Publication Data' => 'publicationData', 
  'Foreword' => 'x-foreword', 
  'Preface' => 'preface',
  'Table of Contents' => 'tableofContents', 
  'Alphabetical Contents' => 'x-alphabeticalContents',
  'Table of Abbreviations' => 'x-tableofAbbreviations', 
  'Chronology' => 'x-chronology',
  'Weights and Measures' => 'x-weightsandMeasures', 
  'Map Index' => 'x-mapIndex',
  'NT Quotes from LXX' => 'x-ntQuotesfromLXX', 
  'Cover' => 'coverPage', 
  'Spine' => 'x-spine', 
  'Tables' => 'x-tables', 
  'Verses for Daily Living' => 'x-dailyVerses',
  'Bible Introduction' => 'introduction', 
  'Old Testament Introduction' => 'introduction',
  'Pentateuch Introduction' => 'introduction', 
  'History Introduction' => 'introduction', 
  'Poetry Introduction' => 'introduction',
  'Prophecy Introduction' => 'introduction', 
  'New Testament Introduction' => 'introduction',
  'Gospels Introduction' => 'introduction', 
  'Acts Introduction' => 'introduction', 
  'Epistles Introduction' => 'introduction',
  'Letters Introduction' => 'introduction', 
  'Deuterocanon Introduction' => 'introduction'
);
%PERIPH_TYPE_MAP_R = reverse %PERIPH_TYPE_MAP;

%PERIPH_SUBTYPE_MAP = (
  # Text following \periph => <div type=introduction"> subType attribute value
  'Bible Introduction' => 'x-bible', 
  'Old Testament Introduction' => 'x-oldTestament',
  'Pentateuch Introduction' => 'x-pentateuch', 
  'History Introduction' => 'x-history', 
  'Poetry Introduction' => 'x-poetry',
  'Prophecy Introduction' => 'x-prophecy', 
  'New Testament Introduction' => 'x-newTestament',
  'Gospels Introduction' => 'x-gospels', 
  'Acts Introduction' => 'x-acts', 
  'Epistles Introduction' => 'x-epistles',
  'Letters Introduction' => 'x-letters', 
  'Deuterocanon Introduction' => 'x-deuterocanon'
);
%PERIPH_SUBTYPE_MAP_R = reverse %PERIPH_SUBTYPE_MAP;

sub toVersificationBookOrder($$) {
  my $vsys = shift;
  my $osis = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nOrdering books and peripherals in \"$osis\" according to versification = $vsys\n");

  my $canonP;
  my $bookOrderP;
  my $testamentP;
  my $bookArrayP;
  
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &Log("ERROR: Not re-ordering books in OSIS file!\n");
    return;
  }

  my $xml = $XML_PARSER->parse_file($osis);

  # remove all books
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bk (@books) {$bk->unbindNode();}

  # remove all peripheral file divs
  my @periphs;
  foreach my $type (values(%ID_TYPE_MAP)) {
    push (@periphs, $XPC->findnodes('//osis:div[@type="'.$type.'"][not(@subType)]', $xml));
  }
  foreach my $periph (@periphs) {$periph->unbindNode();}
  
  # remove bookGroups (if any)
  my @removeBookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
  foreach my $removeBookGroup (@removeBookGroups) {$removeBookGroup->unbindNode();}
  
  # create empty bookGroups
  my $bg = @books[0]->cloneNode(0); # start with book node to insure bookGroup has correct context
  foreach my $a ($bg->attributes()) {
    if ($a->nodeType != 2) {next;}
    if ($a->nodeName eq "type") {$a->setValue('bookGroup');}
    else {$bg->removeAttribute($a->nodeName);}
  }
  my @bookGroups = ($bg, $bg->cloneNode());
    
  # place all books back in canon order
  foreach my $v11nbk (@{$bookArrayP}) {
    if (!$v11nbk) {next;} # bookArrayP[0] is empty
    foreach my $bk (@books) {
      if (!$bk || $bk->findvalue('./@osisID') ne $v11nbk) {next;}
      my $i = ($testamentP->{$v11nbk} eq 'OT' ? 0:1);
      @bookGroups[$i]->appendChild($bk);
      $bk = '';
      last;
    }
  }
  
  foreach my $bk (@books) {
    if ($bk ne '') {&Log("ERROR: Book \"$bk\" not found in $vsys Canon\n");}
  }
  
  my $osisText = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  foreach my $bookGroup (@bookGroups) {
    if (!$XPC->findnodes('descendant::*', $bookGroup)) {next;}
    $osisText->appendChild($bookGroup);
  }

  # place all peripheral files, and separately any \periph sections they may contain, each to their proper places
  for (my $i=@periphs-1; $i >= 0; $i--) {
    my $periph = @periphs[$i];
    my $placedPeriph;

    # read the first comment to find desired target location(s) and scope, if any
    my @commentNode = $XPC->findnodes('child::node()[2][self::comment()]', $periph);

    if (!@commentNode || @commentNode[0] !~ /\s\S+ == \S+/) {
      &Log("ERROR: Removing periph(s)! You must specify the location where each peripheral file should be placed within the OSIS file.\n");
      &placementMessage();
      &Log("REMOVED:\n$periph\n");
    }
    else {
      my $comment = @commentNode[0];
      #<!-- id comment - (FRT) titlePage == osis:div[@type='book'], tableofContents == remove, preface == osis:div[@type='bookGroup'][1], preface == osis:div[@type='bookGroup'][1] -->
      $comment =~ s/^<\!\-\-.*?(?=\s\S+ ==)//; # strip beginning stuff
      $comment =~ s/\s*\-\->$//; # strip end stuff
      
      # process comment parts in reverse order to acheive expected element order
      my @parts = split(/(,\s*(?:\S+|"[^"]+") == )/, ", $comment");
      for (my $x=@parts-1; $x>0; $x -= 2) {
        my $part = $parts[$x-1] . $parts[$x];
        $part =~ s/^,\s*//;
        if ($part !~ /^(\S+|"[^"]+") == (.*?)$/) {
          &Log("ERROR: Unhandled location or scope assignment \"$part\" in \"".@commentNode[0]."\" in CF_usfm2osis.txt\n");
        }
        my $emsg = "as specified by \"$part\"";
        my $int = $1;
        my $xpath = $2;
        $int =~ s/"//g; # strip possible quotes
        if ($int eq 'scope') {
          if (!$periph->getAttribute('osisRef')) {
            $periph->setAttribute('osisRef', $xpath); # $xpath is not an xpath in this case but rather a scope
          }
          else {&Log("ERROR: Introduction comment specifies scope == $int, but introduction already has osisRef=\"".$periph->getAttribute('osisRef')."\"\n");}
          next;
        }
        
        my @targXpath = ();
        if ($xpath =~ /^remove$/i) {$xpath = '';}
        else {
          $xpath = '//'.$xpath;
          @targXpath = $XPC->findnodes($xpath, $xml);
          if (!@targXpath) {
            &Log("ERROR: Removing periph! Could not locate xpath:\"$xpath\" $emsg\n");
            next;
          }
        }
        if ($int eq 'location') {
          $placedPeriph = 1;
          if ($xpath) {&placeIntroduction($periph, @targXpath[$#targXpath]);}
        }
        else {
          my $type;
          my $subType;
          if ($int eq 'x-unknown') {$type = $int;}
          elsif (defined($PERIPH_TYPE_MAP{$int})) {
            $type = $PERIPH_TYPE_MAP{$int};
            $subType = $PERIPH_SUBTYPE_MAP{$int};
          }
          elsif (defined($PERIPH_TYPE_MAP_R{$int})) {$type = $int;}
          elsif (defined($PERIPH_SUBTYPE_MAP_R{$int})) {$type = "introduction"; $subType = $int;}
          else {
            &Log("ERROR: Could not place periph! Unable to map \"$int\" to a div element $emsg.\n");
            next;
          }
          my $srcXpath = './/osis:div[@type="'.$type.'"]'.($subType ? '[@subType="'.$subType.'"]':'[not(@subType)]');
          my @ptag = $XPC->findnodes($srcXpath, $periph);
          if (!@ptag) {
            &Log("ERROR: Could not place periph! Did not find \"$srcXpath\" $emsg\n");
            next;
          }
          @ptag[$#ptag]->unbindNode();
          if ($xpath) {&placeIntroduction(@ptag[$#ptag], @targXpath[$#targXpath]);}
        }
        if ($xpath) {
          my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
          &Log("NOTE: Placing $tg as specified by \"$int\" == \"$xpath\"\n");
        }
        else {&Log("NOTE: Removing \"$int\" $emsg\n");}
      }
    }
    if (!$placedPeriph) {
      if (@{$XPC->findnodes('.//*', $periph)} || @{$XPC->findnodes('.//text()[normalize-space()]', $periph)}) {
        &Log(
"ERROR: The placement location for the following peripheral material was 
not specified and its position may be incorrect:
$periph
To position the above material, add location == <XPATH> after the \\id tag.\n"
        );
        &placementMessage();
      }
      else {
        $periph->unbindNode();
        my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
        &Log("NOTE: Removing empty div \"$tg\"\n");
      }
    }
  }
  
  # Don't check that all books/chapters are included in this 
  # OSIS file, but DO insure that all verses are accounted for and in 
  # sequential order without any skipping (required by GoBible Creator).
  my @verses = $XPC->findnodes('//osis:verse[@osisID]', $xml);
  my $lastbkch=''; my $lastv=0; my $lastVerseTag='';
  my $vcounter;
  my %missingVerseReport;
  foreach my $verse (@verses) {
    my $insertBefore = 0;
    my $osisID = $verse->getAttribute('osisID');
    if ($osisID !~ /^([^\.]+\.\d+)\.(\d+)/) {&Log("ERROR: Can't read vfirst \"$v\"\n");}
    my $bkch = $1;
    my $vfirst = (1*$2);
    if ($bkch ne $lastbkch) {
      $vcounter = 1;
      if ($lastbkch) {&checkLastVerse($lastbkch, $lastv, $lastVerseTag, $xml, $canonP, \%missingVerseReport);}
    }
    foreach my $v (split(/\s+/, $osisID)) {
      if ($v !~ /^\Q$bkch\E\.(\d+)(\-(\d+))?$/) {&Log("ERROR: Can't read v \"$v\" in \"$osisID\"\n");}
      my $vv1 = (1*$1);
      my $vv2 = ($3 ? (1*$3):$vv1);
      for (my $vv = $vv1; $vv <= $vv2; $vv++) {
        if ($vcounter > $vv) {&Log("ERROR: Verse number goes backwards \"$osisID\"\n");}
        while ($vcounter < $vv) {
          $insertBefore++; $vcounter++;
        }
        $vcounter++;
      }
    }
    if ($insertBefore) {&spanVerses($lastVerseTag, $insertBefore, $xml, \%missingVerseReport);}
    $lastbkch = $bkch;
    $lastv = ($vcounter-1);
    $lastVerseTag = $verse;
  }
  &checkLastVerse($lastbkch, $lastv, $lastVerseTag, $xml, $canonP, \%missingVerseReport);
  
  &Log("\nREPORT: ".(keys %missingVerseReport)." instance(s) of missing verses in the USFM".((keys %missingVerseReport) ? ':':'.')."\n");
  if (%missingVerseReport) {
    &Log("NOTE: There are verses missing from the USFM, which are included in the \n");
    &Log("$vsys verse system. For this reason, the osisIDs of verses previous to these \n");
    &Log("missing verses have been updated to span the missing verses. These instances \n");
    &Log("should be checked in the USFM to insure this is the intended result. Otherwise \n");
    &Log("you need to adjust the USFM using EVAL_REGEX to somehow include the missing \n");
    &Log("verses as required.\n");
    foreach my $m (sort keys %missingVerseReport) {
      &Log(sprintf("WARNING: osisID %12s became %s\n", $m, $missingVerseReport{$m}));
    }
  }
  
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

sub placementMessage() {
  if ($AlreadyReportedThis) {return;}
  $AlreadyReportedThis = 1;
  &Log(
"------------------------------------------------------------------------
| The location of peripheral file contents and, if desired, the location 
| of each \periph section within the file must be appended to the end of
| the /id line of each peripheral USFM file, like this:
|
| \id INT div-type-or-subType == xpath-expression, div-type-or-subType == xpath-expression,...
|
| Where div-type-or-subType is one of the following:
| \t-The keyword 'location' specifies the location the entire file should go.
| \t-Any peripheral <div>'s type or subType value specifies the next 
| \t\t<div> in the converted file sharing that type or subType.
| \t- Any \periph tag type must be \"IN DOUBLE QUOTES\" and specifies the
| \t\tnext <div> corresponding to that periph type. If the type is not
| \t\tpart of the USFM 2.4 specification, it can only be specified by
| \t\tusing x-unknown WITHOUT QUOTES.
|
| Where xpath-expression is one of:
| \t-The keyword 'remove' to remove it from the OSIS file entirely.
| \t-The keyword 'osis:header' to place it after the header element.
| \t-An XPATH expression for the parent element at the top of which
| \t\tit should be placed. IMPORTANT: You must escape all @ characters 
| \t\twith \\ to make perl happy. 
|
| Optionally, you may also specify the scope of each peripheral file by 
| adding \"scope == Matt-Rev\" for instance. This is used by single Bible-
| book eBooks to duplicate peripheral material in multiple eBooks.
------------------------------------------------------------------------\n"
  );
}

sub checkLastVerse($$$$$) {
  my $lastbkch = shift;
  my $lastv = shift;
  my $lastVerseTag = shift;
  my $xml = shift;
  my $canonP = shift;
  my $missingVerseReportP = shift;
  
  if ($lastbkch =~ /^([^\.]+)\.(\d+)$/) {
    my $lbk=$1; my $lch=(1*$2);
    my $lastmaxv = (1*@{$canonP->{$lbk}}[($lch-1)]);
    if ($lastv != $lastmaxv) {&spanVerses($lastVerseTag, ($lastmaxv - $lastv), $xml, $missingVerseReportP);}
  }
  else {&Log("ERROR: Bad bkch \"$lastbkch\"\n");}
}

sub spanVerses($$$\%) {
  my $verse = shift;
  my $n = shift;
  my $xml = shift;
  my $missingVerseReportP = shift;
  
  my $osisID = $verse->getAttribute('osisID');
  
  if ($n > 0) {
    if ($osisID !~ /\b([^\.]+\.\d+)\.(\d+)$/) {&Log("ERROR: Bad spanVerses osisID \"$osisID\"\n"); return;}
    my $bkch = $1;
    my $v = (1*$2);
    $missingVerseReportP->{$osisID} = $osisID;
    my @veid = $XPC->findnodes('//osis:verse[@eID="'.$verse->getAttributeNode('sID')->getValue().'"]', $xml);
    while ($n--) {
      $v++;
      $missingVerseReportP->{$osisID} .= " $bkch.$v";
      my @ats = ($verse->getAttributeNode('osisID'), $verse->getAttributeNode('sID'), @veid[0]->getAttributeNode('eID'));
      foreach my $at (@ats) {$at->setValue($at->getValue()." $bkch.$v");}
    }
  }
}

sub placeIntroduction($$) {
  my $intro = shift;
  my $dest = shift;
  if ($dest->nodeName =~ /\:?header$/) {$dest->parentNode()->insertAfter($intro, $dest);}
  elsif ($dest->hasChildNodes()) {$dest->insertBefore($intro, $dest->firstChild);}
  else {$dest->parentNode()->insertAfter($intro, $dest);}
}
1;
