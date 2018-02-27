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

# OSIS-CONVERTERS VERSIFICATION MAPPING:
# The goal is to fit any Bible translation into a fixed versification 
# system so that each verse's number can be identified in both the target 
# and the original verse system. The idea is to make this as easy as 
# possible, and only differences between the source and target verse 
# systems need to be specified.
# 
# VSYS_EXTRA:BK.1.2.3
# Specifies that this translation inserts this range of extra text. This 
# text will all be appended to the preceeding extant verse in the verse   
# system. The additional verses, and any regular verses following them in 
# the chapter, will have alternate verse numbers appended before them, 
# which display their number from the source verse system. Likewise, if 
# the range is an entire chapter, an alternate chapter number will be 
# displayed before the chapter itself and any following chapters in the 
# book.
# 
# VSYS_MISSING:BK.1.2.3
# Specifies that this translation does not include this range of text. The 
# preceeding extant verse id will be modified to span the missing range, 
# but in no case exceeding the end of a chapter. Then, alternate numbers 
# will be appended to any following verses in the chapter. If the range is
# an entire chapter, then an empty chapter is inserted, and alternate
# chapters are displayed for any following chapters (this is necessary for 
# correct mapping to be maintained).
# 
# VSYS_MOVED:BK.1.2.3 -> BK.1.2.3
# Specifies that this translation has moved the text that would be found 
# in range A of the target verse system to range B (ranges A and B must be
# the same size). It is processed as a "VSYS_MISSING:A" followed by a 
# "VSYS_EXTRA:B".
# 
# SET_customBookOrder:true
# Turns off the book re-ordering step so books remain in processed order.
# 
# NOTES:
# - Each instruction is evaluated in the order it appears in the CF file, so
# any verse in the verse system may be effected by multiple instructions.
# - Verse ranges are in the form OSISBK.chapterNum.verseNum.lastVerseNum
# where lastVerseNum and verseNum are optional. This means up to an entire
# chapter may be specified by a single range.
# - This implementation does not accomodate extra books, or ranges of 
# chapters.

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
%ID_TYPE_MAP_R = reverse %ID_TYPE_MAP;

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

%USFM_DEFAULT_PERIPH_TARGET = (
  'Cover|Title Page|Half Title Page|Promotional Page|Imprimatur|Publication Data|Table of Contents|Table of Abbreviations|Bible Introduction' => 'osis:header',
  'Foreword|Preface|Chronology|Weights and Measures|Map Index|NT Quotes from LXX|Old Testament Introduction' => 'osis:div[@type="bookGroup"][1]',
  'Pentateuch Introduction' => 'osis:div[@type="book"][@osisID="Gen"]',
  'History Introduction' => 'osis:div[@type="book"][@osisID="Josh"]',
  'Poetry Introduction' => 'osis:div[@type="book"][@osisID="Ps"]',
  'Prophecy Introduction' => 'osis:div[@type="book"][@osisID="Isa"]',
  'New Testament Introduction' => 'osis:div[@type="bookGroup"][2]',
  'Gospels Introduction' => 'osis:div[@type="book"][@osisID="Matt"]',
  'Acts Introduction' => 'osis:div[@type="book"][@osisID="Acts"]',
  'Letters Introduction' => 'osis:div[@type="book"][@osisID="Acts"]',
  'Deuterocanon Introduction' => 'osis:div[@type="book"][@osisID="Tob"]'
);

sub fitToVerseSystem($$\@$) {
  my $osis = shift;
  my $vsys = shift;
  my $instArrayP = shift;
  my $maintainBookOrder = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\n\nFitting books and peripherals of \"$osis\" into versification = $vsys\n");

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
  my $xpath;
  my $sep;
  foreach my $type (values(%ID_TYPE_MAP)) {
    $xpath .= $sep.'//osis:div[@type="'.$type.'"][not(@subType)]';
    $sep = '|';
  }
  my @periphs = $XPC->findnodes($xpath, $xml);
  foreach my $periph (@periphs) {$periph->unbindNode();}
  
  # create empty bookGroups
  my $osisText = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  my $bg;
  $bg = $osisText->addNewChild("http://www.bibletechnologies.net/2003/OSIS/namespace", 'div'); $bg->setAttribute('type', 'bookGroup');
  $bg = $osisText->addNewChild("http://www.bibletechnologies.net/2003/OSIS/namespace", 'div'); $bg->setAttribute('type', 'bookGroup');
  my @bookGroups = $XPC->findnodes('//osis:osisText/osis:div[@type="bookGroup"]', $xml);

  # place books into proper bookGroup in proper order
  if ($maintainBookOrder) {
    # maintain original book order
    my $i = 0;
    foreach my $bk (@books) {
      my $bkname = $bk->findvalue('./@osisID');
      # Switch to NT bookGroup upon reaching the first NT book
      if ($i==0 && $NT_BOOKS =~ /\b$bkname\b/i) {$i = 1;}
      @bookGroups[$i]->appendChild($bk);
      $bk = '';
    }
  }
  else {
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
  }
  
  foreach my $bk (@books) {
    if ($bk ne '') {&Log("ERROR: Book \"$bk\" not found in $vsys Canon\n");}
  }
  
  foreach my $bookGroup (@bookGroups) {
    if (!$bookGroup->hasChildNodes()) {$bookGroup->unbindNode();}
  }

  # place all peripheral files, and separately any \periph sections they may contain, each to their proper places
  my @mylog;
  for (my $i=@periphs-1; $i >= 0; $i--) {
    my $periph = @periphs[$i];
    my $placedPeriph;

    # read the first comment to find desired target location(s) and scope, if any
    my @commentNode = $XPC->findnodes('child::node()[2][self::comment()]', $periph);

    if (!@commentNode || @commentNode[0] !~ /\s\S+ == \S+/) {
      push(@mylog, "ERROR: Removing periph(s)! You must specify the location where each peripheral file should be placed within the OSIS file.\n");
      push(@mylog, &placementMessage());
      push(@mylog, "REMOVED:\n$periph\n");
    }
    else {
      my $comment = @commentNode[0];
      #<!-- id comment - (FRT) titlePage == osis:div[@type='book'], tableofContents == remove, preface == osis:div[@type='bookGroup'][1], preface == osis:div[@type='bookGroup'][1] -->
      $comment =~ s/^<\!\-\-.*?(?=\s(?:\S+|"[^"]+") ==)//; # strip beginning stuff
      $comment =~ s/\s*\-\->$//; # strip end stuff
      
      # process comment parts in reverse order to acheive expected element order
      my @parts = split(/(,\s*(?:\S+|"[^"]+") == )/, ", $comment");
      for (my $x=@parts-1; $x>0; $x -= 2) {
        my $part = $parts[$x-1] . $parts[$x];
        $part =~ s/^,\s*//;
        if ($part !~ /^(\S+|"[^"]+") == (.*?)$/) {
          push(@mylog, "ERROR: Unhandled location or scope assignment \"$part\" in \"".@commentNode[0]."\" in CF_usfm2osis.txt\n");
        }
        my $emsg = "as specified by \"$part\"";
        my $int = $1;
        my $xpath = $2;
        $int =~ s/"//g; # strip possible quotes
        if ($int eq 'scope') {
          if (!$periph->getAttribute('osisRef')) {
            $periph->setAttribute('osisRef', $xpath); # $xpath is not an xpath in this case but rather a scope
          }
          else {push(@mylog, "ERROR: Introduction comment specifies scope == $int, but introduction already has osisRef=\"".$periph->getAttribute('osisRef')."\"\n");}
          next;
        }
        
        my @targXpath = ();
        if ($xpath =~ /^remove$/i) {$xpath = '';}
        else {
          $xpath = '//'.$xpath;
          @targXpath = $XPC->findnodes($xpath, $xml);
          if (!@targXpath) {
            push(@mylog, "ERROR: Removing periph! Could not locate xpath:\"$xpath\" $emsg\n");
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
            push(@mylog, "ERROR: Could not place periph! Unable to map \"$int\" to a div element $emsg.\n");
            next;
          }
          my $srcXpath = './/osis:div[@type="'.$type.'"]'.($subType ? '[@subType="'.$subType.'"]':'[not(@subType)]');
          my @ptag = $XPC->findnodes($srcXpath, $periph);
          if (!@ptag) {
            push(@mylog, "ERROR: Could not place periph! Did not find \"$srcXpath\" $emsg\n");
            next;
          }
          @ptag[$#ptag]->unbindNode();
          if ($xpath) {&placeIntroduction(@ptag[$#ptag], @targXpath[$#targXpath]);}
        }
        if ($xpath) {
          my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
          push(@mylog, "NOTE: Placing $tg as specified by \"$int\" == \"$xpath\"\n");
        }
        else {push(@mylog, "NOTE: Removing \"$int\" $emsg\n");}
      }
    }
    if (!$placedPeriph) {
      my @tst = $XPC->findnodes('.//*', $periph);
      my @tst2 = $XPC->findnodes('.//text()[normalize-space()]', $periph);
      if ((@tst && @tst[0]) || (@tst2 && @tst2[0])) {
        push(@mylog,
"ERROR: The placement location for the following peripheral material was 
not specified and its position may be incorrect:
$periph
To position the above material, add location == <XPATH> after the \\id tag.\n"
        );
        push(@mylog, &placementMessage());
      }
      else {
        $periph->unbindNode();
        my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
        push(@mylog, "NOTE: Removing empty div \"$tg\"\n");
      }
    }
  }
  foreach my $lg (reverse(@mylog)) {&Log($lg);}
  
  # Apply any alternate VSYS instructions to translation
  foreach my $argsP (@VSYS_INSTR) {&applyVsysInstruction($argsP, $canonP, $xml);}
  
  # Insure that all verses are accounted for and in sequential order 
  # without any skipping (required by GoBible Creator).
  my @ve = $XPC->findnodes('//osis:verse[@sID]', $xml);
  my @v = map($_->getAttribute('sID'), @ve);
  my $x = 0;
  my $checked = 0;
  my $errors = 0;

BOOK:
  foreach my $bk (map($_->getAttribute('osisID'), $XPC->findnodes('//osis:div[@type="book"]', $xml))) {
    if (@v[$x] !~ /^$bk\./) {next;}
    my $ch = 1;
    foreach my $vmax (@{$canonP->{$bk}}) {
      for (my $vs = 1; $vs <= $vmax; $vs++) {
        @v[$x] =~ /^([^\.]+)\.(\d+)\.(\d+)(\s|$)/; my $ebk = $1; my $ech = (1*$2); my $evs = (1*$3);
        if (($ech != 1 && $ech < $ch) || ($ech == $ch && $evs < $vs)) {
          &Log("ERROR: Chapter/verse ordering problem at ".@v[$x]." (expected $ch.$vs)!\n");
          $errors++;
          next;
        }
        if (@v[$x] !~ /\b\Q$bk.$ch.$vs\E\b/) {
          &Log("ERROR: Missing verse $bk.$ch.$vs!\n");
          $errors++;
          next;
        }
        @v[$x] =~/\.(\d+)\s*$/; $vs = ($1*1);
        $x++;
      }
      while (@v[$x] =~ /^\Q$bk.$ch./) {
        &Log("ERROR: Extra verse ".@v[$x]."!\n");
        $errors++;
        $x++;
      }
      $ch++;
    }
    while (@v[$x] =~ /^\Q$bk./) {
      &Log("ERROR: Extra chapter ".@v[$x]."!\n");
      $errors++;
      $x++;
    }
  }
  if ($x == @v) {&Log("\nNOTE: All verses were checked against verse system $vsys\n");}
  else {&Log("\nERROR: Problem checking chapters and verses in verse system $vsys (stopped at $x of @v verses: ".@v[$x].")\n");}
  
  &Log("\n$MOD REPORT: $errors verse system errors".($errors ? ':':'.')."\n");
  if ($errors) {
    &Log("
NOTE: This translation does not perfectly fit the $vsys verse system, 
      and the errors listed above must be fixed. Add the appropriate 
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED instructions to 
      CF_usfm2osis.txt to describe how this translation deviates from 
      $vsys. Then those verse system differences will automatically be 
      reconciled and the related errors should go away.\n";
  }
  
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

sub placementMessage() {
  if ($AlreadyReportedThis) {return '';}
  $AlreadyReportedThis = 1;
return
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
------------------------------------------------------------------------\n";
}

sub placeIntroduction($$) {
  my $intro = shift;
  my $dest = shift;
  if ($dest->nodeName =~ /\:?header$/) {$dest->parentNode()->insertAfter($intro, $dest);}
  elsif ($dest->hasChildNodes()) {
    # place as first non-toc and non-runningHead element in destination container
    my $before = $dest->firstChild();
    while (@{$XPC->findnodes('./self::text()[not(normalize-space())] | ./self::osis:title[@type="runningHead"] | ./self::osis:milestone[starts-with(@type, "x-usfm-toc")]', $before)}[0]) {
      $before = $before->nextSibling();
    }
    $dest->insertBefore($intro, $before);
  }
  else {$dest->parentNode()->insertAfter($intro, $dest);}
}

sub applyVsysInstruction($$$) {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $inst = $argP->{'inst'};
  my $bk = $argP->{'bk'};
  my $ch = $argP->{'ch'};
  my $vs = $argP->{'vs'};
  my $lv = $argP->{'lv'};
  
  if ($inst eq 'MISSING') {&applyVsysMissing($bk, $ch, $vs, $lv, $canonP, $xml);}
  if ($inst eq 'EXTRA') {&applyVsysExtra($bk, $ch, $vs, $lv, $canonP, $xml);}
  else {&Log("ERROR: applyVsysInstruction($bk, $ch, $vs, $lv): Unknown instruction: \"$inst\"\n");}
}

# Used when a verse in the verse system was not included in the translation. 
# It inserts an empty verse where the verse should be, and renumbers the 
# following verses in the chapter, also applying alternate verse numbers.
sub applyVsysMissing($$$$$$) {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $lv = shift;
  my $canonP = shift
  my $xml = shift;
  
  if (!&isWholeChapter($bk, $ch, \$vs, \$lv, $canonP)) {
    # For any following verses, advance their verse numbers and add alternate verse numbers
    my $count = (1 + $lv - $vs);
    for (my $v=$canonP->{$bk}[($ch-1)]; $v>=$vs; $v--) {
      &altVersifyVerse($bk, $ch, $v, $count, $xml);
    }
    
    # Add empty verses for those which are missing
    my $verseTagToModify;
    if ($vs == 1) {
      $verseTagToModify = $XML_PARSER->parse_balanced_chunk("<verse osisID=\"\" sID=\"$bk.$ch.1\"/><verse eID=\"$bk.$ch.1\"/>");
      my $initialVerseTag = @{$XPC->findnodes('//osis:chapter[@osisID="$bk.$ch"]/following::osis:verse[@sID][1]', $xml)}[0];
      &Log("NOTE: applyVsysMissing($bk, $ch, $vs, $lv): Inserting empty verse before: '".$initialVerseTag->getAttribute('osisID')."\n");
      $initialVerseTag->parentNode()->insertBefore($verseTagToModify, $initialVerseTag);
    }
    else {$verseTagToModify = &getVerseTag("$bk.$ch.".($vs-1), $xml, 0);}
    my $newOsisID = $verseTagToModify->getAttribute('osisID');
    while ($vs && $vs <= $lv) {$newOsisID .= ($newOsisID ? ' ':'')."$bk.$ch.$vs"; if ($lv) {$vs++;} else {$vs = NULL;}}
    &Log("NOTE: applyVsysMissing($bk, $ch, $vs, $lv): Changing verse osisID: '".$verseTagToModify->getAttribute('osisID')."' -> '$newOsisID'\n");
    &osisIDCheckUnique($newOsisID, $xml);
    my $endTag = @{$XPC->findnodes('//osis:verse[@eID="'.$verseTagToModify->getAttribute('sID').'"]', $xml)}[0];
    $verseTagToModify->setAttribute('osisID', $newOsisID);
    $verseTagToModify->setAttribute('sID', $newOsisID);
    $endTag->setAttribute('eID', $newOsisID);
  }
  else {
    &Log("ERROR: applyVsysMissing($bk, $ch, $vs, $lv): An entire missing chapter is not supported.\n");
  }
}

# Used when the translation includes an extra verse not in the verse system. 
# The verse's verse number is converted into an alternate verse number and
# the verse as moved within the proceding verse system verse. All 
# following verses in the chapter are renumbered and alternate verse
# numbers applied.
sub applyVsysExtra($$$$$$) {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $lv = shift;
  my $canonP = shift;
  my $xml = shift;
  
  my $isWholeChapter = &isWholeChapter($bk, $ch, \$vs, \$lv, $canonP);
  
  if ($isWholeChapter && $ch != @{$canonP->{$bk}}) {
    &Log("ERROR: applyVsysExtra($bk, $ch, $vs, $lv): Not yet implemented (except when the extra chapter is the last chapter of the book).\n");
    return;
  }
  
  # All verse tags between this startTag and endTag will be removed
  my $startTag = (
    $isWholeChapter ?
    &getVerseTag("$bk.".($ch-1).".".$canonP->{$bk}[($ch-2)], $xml, 0) :
    &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):$vs), $xml, 0)
  );
  my $endTag = (
    $isWholeChapter ? 
    &getVerseTag("$bk.$ch.$lv"), $xml, 1) :
    &getVerseTag("$bk.$ch.".($vs!=1 ? $vl:($vl+1)), $xml, 1)
  );
  
  # If isWholeChapter, then remove chapter tags and add alternate chapter number
  if ($isWholeChapter) {
    my $chapLabel = @{$XPC->findnodes("//osis:title[\@type='x-chapterLabel'][\@canonical='false'][preceding::osis:chapter[\@osisID][1][\@sID='$bk.$ch'][not(preceding::osis:chapter[\@eID='$bk.$ch'])]", $xml)}[0];
    if ($chapLabel) {
      my $alt = $XML_PARSER->parse_balanced_chunk("<hi type=\"italic\" subType=\"x-alternate\"></hi>");
      foreach my $chld ($chapLabel->childNodes) {$alt->insertAfter($chld, undef);}
      $chapLabel->insertAfter($alt, undef);
    }
    else {&Log("ERROR: applyVsysExtra($bk, $ch, $vs, $lv): Chapter has no chapter label.\n");}
    &Log("NOTE: applyVsysExtra($bk, $ch, $vs, $lv): Removing chapter tags with sID=eID=\"$bk.$ch\".\n");
    @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0]->unbindNode();
    @{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0]->unbindNode();
  }
  
  # Remove verse tags between startTag and endTag and add alternate verse numbers
  for (my $v=$vl; $v>=$vs; $v--) {&altVersifyVerse($bk, $ch, $v, 0, $xml);}
  my $ns1 = '//osis:verse[@sID='.$startTag->getAttribute('sID').']/following::osis:verse';
  my $ns2 = '//osis:verse[@eID='.$endTag->getAttribute('eID').']/preceding::osis:verse';
  my @remove = $XPC->findnodes("$ns1[count(.|$ns2) = count($ns2)]", $xml);
  &Log("NOTE: applyVsysExtra($bk, $ch, $vs, $lv): Removing ".@remove." verse tags.\n");
  foreach my $r (@remove) {$r->unbindNode();}
  $endTag->setAttribute('eID', $startTag->getAttribute('sID'));
  
  # If not isWholeChapter, then any following verses get reduced verse number plus alternate verse number
  if (!$isWholeChapter) {
    my $count = (1 + $lv - $vs);
    for (my $v=$vs+($vs!=1 ? 1:2); $v<=$canonP->{$bk}[($ch-1)]; $v++) {
      &altVersifyVerse($bk, $ch, $v, (-1*$count), $xml);
    }
  }
}

# Markup verse as alternate and increment it by count
sub altVersifyVerse($$$$$) {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $count = shift;
  my $xml = shift;
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  
  # Mark as alternate
  my $altTextNode = @{$XPC->findnodes('//osis:verse[@osisID="'.$vTagS->getAttribute('osisID').'"]/following-sibling::text()[normalize-space()][1][ancestor::osis:hi[@subType="x-alternate"]]', $xml)}[0];
  if ($altTextNode) {
    my $new = $altTextNode->data;
    if ($new =~ /^(\()(.*?)(\))$/) {
      my $s=$1; my $v=$1; my $e=$3;
      my @va = &getVerseArrayFromString();
      @va[$vs]++;
      $v = &getVerseStringFromArray(\@va);
      &Log("NOTE: altVersifyVerse($bk, $ch, $vs, $count): Changing alternate verse \"".$altTextNode->data."\" -> \"$s$v$e\"\n");
      $altTextNode->setData("$s$v$e");
    }
    else {&Log("ERROR: altVersifyVerse($bk, $ch, $vs, $count): Could not parse existing alternate verse \"$new\"\n";}
  }
  else {
    my $alt = $XML_PARSER->parse_balanced_chunk("<hi type=\"italic\" subType=\"x-alternate\"><hi type=\"super\">($vs)</hi></hi>");
    &Log("NOTE: altVersifyVerse($bk, $ch, $vs, $count): Adding alternate verse \"$vs\"\n");
    $vTagS->parentNode()->insertAfter($alt, $vTagS);
  }
  
  # Increment
  if ($count) {
    my $oldID = $vTagS->getAttribute('osisID');
    my @verses = split(/\s+/, $oldID);
    foreach my $v (@verses) {
      if ($v =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
        my $b=$1; my $c=$2; my $vn=(1*$3);
        $vn += $count;
        $v = "$b.$c.$vn";
      }
      else {&Log("ERROR: altVersifyVerse($bk, $ch, $vs, $count): Can't parse verse \"$v\".\n");}
    }
    my $newID = join(' ', @verses);
    &Log("NOTE: altVersifyVerse($bk, $ch, $vs, $count): Changing verse osisID: '".$vTagS->getAttribute('osisID')."' -> '$newID'\n");
    &osisIDCheckUnique($newID, $xml);
    $vTagS->setAttribute('osisID', $newID);
    $vTagS->setAttribute('sID', $newID);
    $vTagE->setAttribute('eID', $newID);
  }
}

sub osisIDCheckUnique($$) {
  my $osisID = shift;
  my $xml = shift;
  
  my @verses = split(/\s+/, $osisID);
  foreach my $v (@verses) {
    my $chv = &getVerseTag($v, $xml, 0);
    if ($chv) {
      &Log("ERROR: osisIDCheckUnique($osisID): Verse osisID=\"".$chv->getAttribute('osisID')."\" already exists having sID containing \"$v\"!\n");
    }
  }
}

sub getVerseArrayFromString($) {
  my $s = shift;
  
  my @va = ();
  my @segs = split(/\s*,\s*/, $s);
  foreach my $seg (@segs) {
    if ($seg =~ /^\s*(\d+)\s*\-\s*(\d+)\s*$/) {
      my $a=$1; my $b=$2;
      for (my $x=$a; $x<=$b; $x++) {@va[$x]++;}
    }
    else {@va[$seg]++;}
  }
  return @va;
}

sub getVerseStringFromArray(\@) {
  my $aP = shift;
  
  my $s = '';
  my $lastv = -1;
  my $inRange = 0;
  for (my $x=0; $x<@{$aP}; $x++) {
    if (!@{$aP}[$x]) {next;}
    if ($lastv == -1) {$s = "$x";}
    elsif ($lastv == ($x-1)) {$inRange = 1;}
    else {
      if ($inRange) {$s .= "-$lastv"; $inRange = 0;}
      $s .= ", $x";
    }
    $lastv = $x;
  }
  if ($inRange) {$s .= "-$lastv"};
  
  return $s;
}

sub isWholeChapter($$$$$) {
  my $bk  = shift;
  my $ch  = shift;
  my $vsP  = shift;
  my $lvP  = shift;
  my $canonP = shift
  
  my $haveVS = ($$vsP ? 1:0);
  $$vsP = ($haveVS ? $$vsP:1);
  $$lvP = ($$lvP ? $$lvP:($haveVS ? $$vsP:$canonP->{$bk}[($ch-1)]));

  return ($$vsP == 1 && $$lvP == $canonP->{$bk}[($ch-1)]);
}
    
1;
