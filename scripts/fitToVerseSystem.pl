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
# system so that each verse can be identified in both the target 
# and the original verse system. This process should be as easy as 
# possible for the person running the conversion, so only differences 
# between the source and target verse systems need to be identified. All
# verse system changes to the osis file should be easily reversible 
# (for instance using a simple XSLT) so as to easily recover the  
# original verse system when needed.
# 
# VSYS_EXTRA:BK.1.2.3
# Specifies that this translation has inserted this range of extra verses 
# which are not found in the target verse system. These verses will all 
# be appended to the preceeding extant verse in the verse system. The 
# additional verses, and any regular verses following them in the chapter, 
# will have alternate verse numbers appended before them, which display 
# their number from the source verse system. Likewise, if the range is an 
# entire chapter, an alternate chapter number will be displayed before the 
# chapter itself and any following chapters in the book.
# 
# VSYS_MISSING:BK.1.2.3
# Specifies that this translation does not include this range of verses of
# the target verse system. The preceeding extant verse id will be modified 
# to span the missing range, but in no case exceeding the end of a chapter. 
# Then, alternate numbers will be appended to any following verses in the 
# chapter. Entire missing chapters are not supported.
# 
# VSYS_MOVED:BK.1.2.3 -> BK.4.5.6 (or either address may be: BK.1.2.PART)
# Specifies that this translation has moved the verses that would be found 
# in range A of the target verse system to range B (ranges A and B must be
# the same size). It is processed as a "VSYS_MISSING:A" followed by a 
# "VSYS_EXTRA:B". The last-verse portion of A or B may also be the
# keyword "PART", meaning that the reference applies to only part of the
# specified verse. The VSYS_MOVED instruction also updates the osisRef
# attribute of externally sourced Scripture references to point to their
# moved location in the translation.
#
# VSYS_MOVED_ALT: Same as VSYS_MOVED but this should be used when alternate
# verse markup (<hi subType="x-alternate">) is used for the moved verses,
# rather than regular verse markers. This instruction will correct 
# external cross-references targetting the alternate verses, but will 
# not change the OSIS markup of the alternate verses.
# 
# SET_customBookOrder:true
# Turns off the book re-ordering step so books will remain in processed order.
# 
# NOTES:
# - Each instruction is evaluated in verse system order regardless of
# their order in the CF_ file.
# - A verse may be effected by multiple instructions.
# - Verse ranges are in the form OSISBK.chapterNum.verseNum.lastVerseNum
# where lastVerseNum and verseNum are optional. This means up to an entire
# chapter may be specified by a single range (if supported for the
# particular instruction).
# - This implementation does not accomodate extra books, or ranges of 
# chapters, and whole chapters are only supported with VSYS_EXTRA for
# chapters at the end of a book, where the chapter was not moved there
# from elsewhere.

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

sub orderBooksPeriphs($$$) {
  my $osis = shift;
  my $vsys = shift;
  my $maintainBookOrder = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nOrdering books and peripherals of \"$osis\" by versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
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
  
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
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

sub fitToVerseSystem($$) {
  my $osis = shift;
  my $vsys = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nFitting OSIS \"$osis\" to versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &Log("ERROR: Not Fitting OSIS versification! No verse system.\n");
    return;
  }

  my $xml = $XML_PARSER->parse_file($osis);
  
  my @existing = $XPC->findnodes('//osis:milestone[@annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"]', $xml);
  if (@existing) {
    &Log("
WARNING: There are ".@existing." fitted tags in the text. This OSIS file 
         has already been fitted so this step will be skipped!\n");
  }
  elsif (@VSYS_INSTR) {
    # Apply alternate VSYS instructions to the translation
    foreach my $argsP (@VSYS_INSTR) {&applyVsysInstruction($argsP, $canonP, $xml);}
    my $scopeElement = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-bible"]]/osis:scope', $xml)}[0];
    if ($scopeElement) {&changeNodeText($scopeElement, &getScope($xml));}
    # Save and re-read osis file now so that new elements will all have osis namespace for later checks
    open(OUTF, ">$osis");
    print OUTF $xml->toString();
    close(OUTF);
    $xml = $XML_PARSER->parse_file($osis);
  }
  
  my @nakedAltTags = $XPC->findnodes('//osis:hi[@subType="x-alternate"][not(preceding::*[1][self::osis:milestone[starts-with(@type, "'.$VSYS{'prefix'}.'")]])]', $xml);
  if (@nakedAltTags) {
    &Log("
WARNING: The following alternate verse tags were found. If these represent 
         verses which normally appear somewhere else in the $vsys verse 
         system, then a VSYS_MOVED_ALT instruction should be added to 
         CF_usfm2osis.txt to correct external cross-references:\n");
    foreach my $at (@nakedAltTags) {
      my $verse = @{$XPC->findnodes('preceding::osis:verse[@sID][1]', $at)}[0];
      &Log($verse." ".$at."\n");
    }
  }
  
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
  
  &Log("\n$MOD REPORT: $errors verse system problems detected".($errors ? ':':'.')."\n");
  if ($errors) {
    &Log("
NOTE: This translation does not fit the $vsys verse system. The errors 
      listed above must be fixed. Add the appropriate instructions:
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED to CF_usfm2osis.txt 
      (see comments at the top of: ".__FILE__.".\n");
  }
}

# Read bibleMod and the osis file and:
# 1) Find all verse osisIDs in $bibleMod which were changed by VSYS 
#    instructions. These are used for updating source osisRefs, but 
#    these do NOT effect osisRefs of addCrossRefs() references. 
# 2) Find all verse osisIDs in $bibleMod which were moved by the 
#    translators with respect to the chosen fixed verse system. These
#    are used for updating external osisRefs.
# 3) Find applicable osisRefs in $osis which point to the osisIDs found 
#    in #2 and #3, and correct them, plus add source target as annotateRef.
sub correctReferencesVSYS($$) {
  my $osis = shift;
  my $bibleMod = shift;
  
  my $bfile = ($bibleMod eq $MOD ? $osis:&getProjectOsisFile($bibleMod));

  if (! -e $bfile) {
    &Log("\nWARNING: No OSIS Bible file was found. References effected by VSYS instructions will not be corrected!\n");
    return;
  }
  &Log("\n\nUpdating osisRef attributes of \"$bfile\" that require re-targeting after VSYS instructions:\n", 1);
  
  my $count = 0;
  
  # Read Bible file
  my $bibleXML = $XML_PARSER->parse_file($bfile);
  my $vsys = &getVerseSystemOSIS($bibleXML);
  
  # Read OSIS file
  my $osisXML = $XML_PARSER->parse_file($osis);
  my @existing = $XPC->findnodes('//osis:reference[@annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"][@annotateRef][@osisRef]', $osisXML);
  if (@existing) {
    &Log("WARNING: ".@existing." references have already been updated, so this step will be skipped!\n");
    return;
  }
  
  # 1) Get osisIDs from the source verse system that need mapping to the target verse system (because of VSYS instructions).
  # This map is used to update references within the translation that were broken by VSYS instructions.
  my %sourceVerseMap;
  my @annotateRefs = $XPC->findnodes('//osis:milestone[@type="'.$VSYS{'prefix'}.'-verse'.$VSYS{'start'}.'"][@annotateRef]', $bibleXML);
  if (@annotateRefs[0]) {
    foreach my $ar (@annotateRefs) {
      my @oids = split(/\s+/, @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $ar)}[0]->getAttribute('osisID'));
      my @aids = split(/\s+/, $ar->getAttribute('annotateRef'));
AIDS:
      foreach my $aid (@aids) {
        foreach my $oid (@oids) {if ($oid eq $aid) {next AIDS;}}
        $sourceVerseMap{$aid} = @oids[$#iods];
      }
    }
  }
    
  # 2) Get osisIDs from the target verse system that need re-mapping to the target verse-system (because of VSYS_MOVED instructions).
  # This map is used to update external references (in the target verse system) that were broken by VSYS_MOVED instructions.
  my $targetVerseMapP = &getMovedVersesOSIS($bibleXML)->{'fromTo'};

  # 3) Look for osisRefs in the osis file that need updating and update them
  my %missing;
  foreach my $m ($XPC->findnodes('//osis:milestone[@type="'.$VSYS{'prefix'}.$VSYS{'missing'}.'"]', $bibleXML)) {
    map($missing{$_}++, split(/\s+/, &osisRef2osisID($m->getAttribute('osisRef'))));
  }
  if (%sourceVerseMap || %{$targetVerseMapP}) {
    my $lastch = '';
    my @checkrefs = ();
    foreach my $verse (&normalizeOsisID([ keys(%sourceVerseMap) ])) {
      $verse =~ /^(.*?)\.\d+$/;
      my $ch = $1;
      if (!$lastch || $lastch ne $ch) {
        # Select all elements having osisRef attributes EXCEPT those within externally sourced 
        # crossReferences since they already match the target verse-system.
        @checkrefs = $XPC->findnodes("//*[contains(\@osisRef, '$ch')][not(ancestor::osis:note[\@type='crossReference'][\@resp])]", $osisXML);
      }
      $lastch = $ch;
      &addrids(\@checkrefs, $verse, \%sourceVerseMap, \%missing);
    }
    
    $lastch = '';
    @checkrefs = ();
    foreach my $verse (&normalizeOsisID([ keys(%{$targetVerseMapP}) ])) {
      $verse =~ /^(.*?)\.\d+$/;
      my $ch = $1;
      if (!$lastch || $lastch ne $ch) {
        # Select ONLY elements having osisRef attributes within externally sourced crossReferences 
        @checkrefs = $XPC->findnodes("//*[contains(\@osisRef, '$ch')][ancestor::osis:note[\@type='crossReference'][\@resp]]", $osisXML);
      }
      $lastch = $ch;
      &addrids(\@checkrefs, $verse, $targetVerseMapP, \%missing);
    }
    
    $count = &applyrids($osisXML, &getMovedVersesOSIS($bibleXML)->{'fromTo'});
  }
  
  # Overwrite OSIS file if anything changed
  if ($count) {
    if (open(OUTF, ">$osis")) {
      print OUTF $osisXML->toString();
      close(OUTF);
    }
    else {&Log("ERROR: Could not open \"$osis\" to write osisRef fixes!\n");}
  }
  
  &Log("\n$MOD REPORT: \"$count\" osisRefs were updated because of VSYS intructions.\n");
}

# If any osisRef in the $checkRefsAP array of osisRefs includes $verse,  
# then add a rids attribute. The rids attribute contains redirected  
# verse osisID(s) that will become the updated osisRef value of the 
# parent element.
sub addrids(\@$\%\%) {
  my $checkRefsAP = shift;
  my $verse = shift;
  my $mapHP = shift;
  my $missingHP = shift;
  
  foreach my $e (@{$checkRefsAP}) {
    my $changed = 0; # only write a rids attrib if there is a change
    my $rids = ($e->hasAttribute('rids') ? $e->getAttribute('rids'):&osisRef2osisID($e->getAttribute('osisRef')));
    my @everses = split(/\s+/, $rids);
    if (@everses == 1 && $missingHP->{@everses[0]}) {
      @everses = ();
      $changed++;
    }
    else {
      foreach my $ev (@everses) {
        if ($ev ne $verse) {next;}
        if ($mapHP->{$verse}) {
          $ev = join(' ', map("x.$_", split(/\s+/, $mapHP->{$verse})));
          $changed++;
        }
        else {&Log("\nERROR: Could not map \"$verse\" to verse system!\n");}
      }
    }
    if ($changed) {$e->setAttribute('rids', join(' ', @everses));}
  }
}

# Apply rids attributes to parent elements and remove rids attributes.
# Also write annotateRefs containing the source verse system targets.
# References to moved verses also have a rids attibute containing fixed 
# verse system addresses to be applied to osisRef, but the annotateRef 
# for these must also be mapped as well (to target the correct location 
# in the source verse system). So %movedHP is used for that.
sub applyrids($\%) {
  my $xml = shift;
  my $movedHP = shift;
  
  my $count = 0;
  foreach my $e ($XPC->findnodes('//*[@rids]', $xml)) {
    my @rid = split(/\s+/, $e->getAttribute('rids'));
    $e->removeAttribute('rids');
    if (@rid[0]) {
      my @annoRefs = split(/\s+/, &osisRef2osisID($e->getAttribute('osisRef')));
      foreach my $ar (@annoRefs) {if ($movedHP->{$ar}) {$ar = $movedHP->{$ar};}}
      my $annoRef = &osisID2osisRef(join(' ', @annoRefs));
      if ($annoRef =~ /\s+/) {
        &Log("ERROR: Mapped reference has multiple segments \"".$e->getAttribute('osisRef')."\" --> \"$annoRef\".\n");
      }
      if ($e->getAttribute('osisRef') ne $annoRef) {
        &Log("NOTE: AnnotateRef type ".$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}." is being mapped from \"".$e->getAttribute('osisRef')."\" to \"$annoRef\"\n");
      }
      foreach my $r (@rid) {$r =~ s/^x\.//;}
      my $newOsisRef = &osisID2osisRef(join(' ', &normalizeOsisID(\@rid)));
      if ($e->getAttribute('osisRef') ne $newOsisRef) {
        my $origRef = $e->getAttribute('osisRef');
        $e->setAttribute('osisRef', $newOsisRef);
        my $ie = ($e->nodeName eq 'reference' ? (@{$XPC->findnodes('./ancestor::osis:note[@resp]', $e)}[0] ? 'external ':'internal '):'');
        my $est = $e; $est =~ s/^(.*?>).*$/$1/;
        &Log("NOTE: Updated $ie".$e->nodeName." osisRef=$origRef to $est\n");
        $count++;
      }
      else {&Log("ERROR: OsisRef update resulted in original value!: $e\n");}
      $e->setAttribute('annotateRef', $annoRef);
      $e->setAttribute('annotateType', $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'});
    }
    else {
      &Log("NOTE: Removing ".$e->nodeName." osisRef=\"".$e->getAttribute('osisRef')."\" pointing to missing verse\n");
      $e->unbindNode();
      $count++;
    }
  }
  
  return $count;
}

sub applyVsysInstruction(\%\@$) {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  
  my $inst = $argP->{'inst'};
  
  my $valueP = &readValue($argP->{'value'});
  my $fromP = ($argP->{'from'} ? &readValue($argP->{'from'}):'');
  my $toP = ($argP->{'to'} ? &readValue($argP->{'to'}):'');
  
  if (($fromP && $fromP->{'count'} != $valueP->{'count'}) || ($toP && $toP->{'count'} != $valueP->{'count'})) {
    &Log("ERROR: 'From' and 'To' are a different number of verses: $inst: ".$argP->{'value'}." -> ".($fromP->{'value'} ? $fromP->{'value'}:$toP->{'value'})."\n");
    return 0;
  }
  
  if (!&getBooksOSIS($xml)->{$valueP->{'bk'}}) {
    &Log("\nWARNING: Skipping VSYS_$inst because ".$valueP->{'bk'}." is not in OSIS file.\n");
    return 0;
  }
  
  if    ($inst eq 'MISSING') {&applyVsysMissing($valueP, $xml, &mapValue($valueP, $toP));}
  elsif ($inst eq 'EXTRA') {&applyVsysExtra($valueP, $canonP, $xml, &mapValue($valueP, $fromP));}
  elsif ($inst eq 'MISSING_ALT') {&applyVsysMissingALT($valueP, $xml, &mapValue($valueP, $toP));}
  elsif ($inst eq 'EXTRA_ALT') {&applyVsysExtraALT($valueP, $canonP, $xml, &mapValue($valueP, $fromP));}
  
  else {&Log("ERROR: applyVsysInstruction(".$valueP->{'value'}."): Unknown instruction: \"$inst\"\n");}
  
  return 1;
}

sub readValue($$) {
  my $value = shift;
  my $canonP = shift;
  
  my %data;
  $data{'value'} = $value;
  
  # read and preprocess value
  if ($value !~ /^$VSYS_PINSTR_RE$/) {
    &Log("ERROR readValue: Could not parse \"$value\"\n");
    return \%data;
  }
  my $bk = $1; my $ch = $2; my $vs = ($3 ? $4:''); my $lv = ($5 ? $6:'');
  
  $data{'isPartial'} = ($lv =~ s/^PART$/$vs/ ? 1:0);
  $data{'isWholeChapter'} = &isWholeVsysChapter($bk, $ch, \$vs, \$lv, $canonP);
  $data{'bk'} = $bk;
  $data{'ch'} = (1*$ch);
  $data{'vs'} = (1*$vs);
  $data{'lv'} = (1*$lv);
  $data{'count'} = 1+($lv-$vs);
  
  return \%data
}

# Returns a map of from -> to verse osisIDs
sub mapValue($$) {
  my $fromP = shift;
  my $toP = shift;
  
  if (!$toP) {return '';}
  
  my %map;
  $map{'from'} = $fromP;
  $map{'to'} = $toP;
  
  my @fromvs = &contextArray($fromP->{'value'});
  my @tovs = &contextArray($toP->{'value'});
  if (@fromvs != @tovs) {
    &Log("ERROR mapValue: Count mismatch: ".$fromP->{'value'}.", ".$toP->{'value'}." (".@fromvs." != ".@tovs.")\n");
  }
  
  for (my $i=0; $i<@fromvs; $i++) {$map{'map'}{@fromvs[$i]} = @tovs[$i];}
  
  return \%map;
}

# Used for empty verses that have verse tags in the translation, but no 
# verse contents. It just inserts moved/missing verse markers.
sub applyVsysMissingALT($$$) {
  my $valueP = shift;
  my $xml = shift;
  my $movedToP = shift;
  
  &Log("\nNOTE: Applying VSYS_MISSING_ALT: ".$valueP->{'value'}." :\n");
  
  if ($valueP->{'PART'}) {
    &Log("NOTE: Verse reference is partial, so nothing to do here.\n");
    return;
  }
  
  if (!$valueP->{'isWholeChapter'}) {
    for (my $v=$valueP->{'vs'}; $v<=$valueP->{'lv'}; $v++) {
      &writeEmptyVerseMarker($valueP->{'bk'}.".".$valueP->{'ch'}, $v, $xml, $movedToP);
    }
  }
  else {&Log("ERROR applyVsysMissingALT: Not supported for entire chapters.\n");}
}

# Used when verses in the verse system were not included in the translation. 
# It inserts empty verses and milestone markers where the verses should be,  
# and renumbers the following verses in the chapter, also inserting alternate 
# verse numbers there.
sub applyVsysMissing($$$) {
  my $valueP = shift;
  my $xml = shift;
  my $movedToP = shift;
  my $bk = $valueP->{'bk'}; my $ch = $valueP->{'ch'}; my $vs = $valueP->{'vs'}; my $lv = $valueP->{'lv'};
  
  &Log("\nNOTE: Applying VSYS_MISSING: ".$valueP->{'value'}." :\n");
  
  if ($valueP->{'PART'}) {
    &Log("NOTE: Verse reference is partial, so nothing to do here.\n");
    return;
  }
  
  if (!$valueP->{'isWholeChapter'}) {
    my $count = (1 + $lv - $vs);
    
    my $verseTagToModify = &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):&getFirstVerseInChapterOSIS($bk, $ch, $xml)), $xml, 0);  
    # For any following verses, advance their verse numbers and add alternate verse numbers if needed
    my $followingVerse = @{$XPC->findnodes('./following::osis:verse[@sID][1]', $verseTagToModify)}[0];
    if ($followingVerse) {
      $followingVerse = $followingVerse->getAttribute('osisID');
      $followingVerse =~ s/^[^\.]+\.\d+\.(\d+)\b.*?$/$1/;
      if ($vs != ($followingVerse-$count) - ($vs!=1 ? 0:1)) {
        for (my $v=&getLastVerseInChapterOSIS($bk, $ch, $xml); $v>=$vs; $v--) {
          &reVersify($bk, $ch, $v, $count, $xml);
        }
      }
    }
    
    # Add the missing verses (by listing them in an existing osisID)
    # need to get verseTagToModify again since reVersify converted the old one to a milestone
    $verseTagToModify = &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):&getFirstVerseInChapterOSIS($bk, $ch, $xml)), $xml, 0);
    my $endTag = @{$XPC->findnodes('//osis:verse[@eID="'.$verseTagToModify->getAttribute('sID').'"]', $xml)}[0];
    my @missing;
    for (my $v = $vs; $v <= $lv; $v++) {
      my $a = "$bk.$ch.$v";
      &osisIDCheckUnique($a, $xml);
      push(@missing, $a);
      &writeEmptyVerseMarker("$bk.$ch", $v, $xml, $movedToP);
    }

    push(@missing, $verseTagToModify->getAttribute('osisID'));
    my $newOsisID = join(' ', &normalizeOsisID(\@missing));
    &Log("NOTE: Changing verse osisID='".$verseTagToModify->getAttribute('osisID')."' to '$newOsisID'\n");
    $verseTagToModify = &toAlternate($verseTagToModify, 0, 1);
    $endTag = &toAlternate($endTag, 0, 1);
    $verseTagToModify->setAttribute('osisID', $newOsisID);
    $verseTagToModify->setAttribute('sID', $newOsisID);
    $endTag->setAttribute('eID', $newOsisID);
  }
  else {
    &Log("ERROR: VSYS_MISSING($bk, $ch, $vs, $lv): An entire missing chapter is not supported.\n");
  }
}

# Insert milestone marker to record a missing verse and whether it was moved or not.
# The VerseID may not apply to an existing verse (since it's probably missing) so the
# next lowest verse end tag is used.
sub writeEmptyVerseMarker($$$$) {
  my $bkch = shift;
  my $v = shift;
  my $xml = shift;
  my $movedToP = shift;
  
  my $verseID = "$bkch.$v";
  if ($movedToP && !$movedToP->{'map'}{$verseID}) {
    &Log("ERROR writeEmptyVerseMarker: No source location for $verseID\n");
  }
  
  my $type = ($movedToP ? 
    'type="'.$VSYS{'prefix'}.$VSYS{'movedto'}.'" annotateRef="'.$movedToP->{'map'}{$verseID}.'" annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"' : 
    "type='".$VSYS{'prefix'}.$VSYS{'missing'}."'"
  );
  
  my $verseEndTag;
  do {
    $verseEndTag = &getVerseTag("$bkch.$v", $xml, 1);
    $v--;
  } while (!$verseEndTag && $v > 0);
  
  if ($verseEndTag) {
    $verseEndTag->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk("<milestone $type osisRef='$verseID'/>"), $verseEndTag);
  }
  else {&Log("ERROR writeEmptyVerseMarker: Starting verse tag not found for \"$verseID\"\n");}
}

# Used when the translation includes extra verses in a chapter compared 
# to the target verse system, which are NOT marked up with verse tags, 
# but rather as alternate verse numbers. This only adds milestone tags 
# recording where the alternate verses were moved from.
sub applyVsysExtraALT($$$$) {
  my $valueP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $movedFromP = shift;
  
  &Log("\nNOTE: Applying VSYS_EXTRA_ALT: ".$valueP->{'value'}." :\n");
  
  if (!$movedFromP) {
    &Log("NOTE: These verses were not moved from somewhere else, so nothing to do here.\n");
    return;
  }
  
  if ($valueP->{'PART'}) {
    &Log("NOTE: Verse reference is partial, so nothing to do here.\n");
    return;
  }
  
  my $isWholeChapter = ($valueP->{'ch'} > @{$canonP->{$valueP->{'bk'}}} ? 1:$valueP->{'isWholeChapter'});
  if (!$isWholeChapter) {
    my $type = $VSYS{'prefix'}.$VSYS{'movedfrom'};
    my $annotateType = $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'};
    for (my $v=$valueP->{'vs'}; $v<=$valueP->{'lv'}; $v++) {
      my $success = 0;
      my $a = $valueP->{'bk'}.".".$valueP->{'ch'}.".$v";
      my @altsInChapter = $XPC->findnodes('//osis:div[@type="book"][@osisID="'.$valueP->{'bk'}.'"]//osis:hi[@subType="x-alternate"][preceding::osis:chapter[1][@sID="'.$valueP->{'bk'}.'.'.$valueP->{'ch'}.'"]][following::osis:chapter[1][@eID="'.$valueP->{'bk'}.'.'.$valueP->{'ch'}.'"]]', $xml);
      foreach my $alt (@altsInChapter) {
        if ($alt->textContent !~ /\b$v\b/) {next;}
        my $annotateRef = @{$XPC->findnodes('preceding::osis:verse[1][@sID]', $alt)}[0];
        if ($annotateRef) {my @tmp = split(/\s+/, $annotateRef->getAttribute('osisID')); $annotateRef = @tmp[-1];}
        if (!$annotateRef) {
          &Log("ERROR applyVsysExtraALT: Could not find verse containing $alt\n");
          last;
        }
        if (!$movedFromP->{'map'}{$a}) {
          &Log("ERROR applyVsysExtraALT: Verse $a not found in movedFrom $alt\n");
          last;
        }
        my $m = "<milestone type='$type' osisRef='".$movedFromP->{'map'}{$a}."' annotateRef='$annotateRef' annotateType='$annotateType'/>";
        $alt->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $alt);
        $success++;
        last;
      }
      if (!$success) {&Log("ERROR applyVsysExtraALT: Couldn't mark alternate verse $v\n");}
    }
  }
  else {&Log("ERROR applyVsysExtraALT: Not supported for entire chapters.\n");}
}

# Used when the translation includes extra verses in a chapter compared
# to the target verse system, which are marked up as regular verses. For 
# these extra verses, alternate verse numbers are inserted and verse 
# tags are converted into milestone elements. Then they are enclosed 
# within the proceding verse system verse. If the extra verses were 
# moved by translators from somewhere else, the milestone's osisRef 
# attribute will contain this location. All following verses in the 
# chapter are renumbered and alternate verses inserted.
sub applyVsysExtra($$$$$) {
  my $valueP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $movedFromP = shift;
  my $adjusted = shift;
  my $bk = $valueP->{'bk'}; my $ch = $valueP->{'ch'}; my $vs = $valueP->{'vs'}; my $lv = $valueP->{'lv'};
  
  &Log("\nNOTE: Applying VSYS_EXTRA: ".$valueP->{'value'}." :\n");
  
  if ($valueP->{'PART'}) {
    &Log("NOTE: Verse reference is partial, so nothing to do here.\n");
    return;
  }
  
  my $isWholeChapter = ($ch > @{$canonP->{$bk}} ? 1:$valueP->{'isWholeChapter'});
  
  # Handle the special case of an extra chapter (like Psalm 151)
  if ($ch > @{$canonP->{$bk}}) {
    if ($ch == (@{$canonP->{$bk}} + 1)) {
      if ($vs || $lv) {
        &Log("ERROR: VSYS_EXTRA($bk, $ch, $vs, $lv): Cannot specify verses for a chapter outside the verse system (use just '$bk.$ch' instead).\n");
      }
      $vs = 1;
      $lv = &getLastVerseInChapterOSIS($bk, $ch, $xml);
    }
    else {
      &Log("ERROR: VSYS_EXTRA($bk, $ch, $vs, $lv): Not yet implemented (except when the extra chapter is the last chapter of the book).\n");
      return;
    }
  }
  
  # All verse tags between this startTag and endTag will become alternate
  my $startTag = (
    $isWholeChapter ?
    &getVerseTag("$bk.".($ch-1).".".&getLastVerseInChapterOSIS($bk, ($ch-1), $xml), $xml, 0) :
    &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):$vs), $xml, 0)
  );
  my $endTag = &getVerseTag("$bk.$ch.".(!$isWholeChapter && $vs==1 ? ($lv+1):$lv), $xml, 1);
  
  # VSYS_EXTRA references the source verse system, which may have been
  # modified by previous instructions. So adjust our inputs in that case.
  if (!$adjusted && &getAltID($startTag) =~ /^[^\.]+\.\d+\.(\d+)\b/) {
    my $arv = $1;
    $startTag->getAttribute('osisID') =~ /^[^\.]+\.\d+\.(\d+)\b/;
    my $shift = ($1 - $arv);
    if ($shift) {
      &Log("NOTE: This verse was moved, adjusting position: '$shift'.\n");
      my $newValueP = &readValue($bk.'.'.$ch.'.'.($vs+$shift).'.'.($valueP->{'partial'} ? 'PART':($lv+$shift)));
      &applyVsysExtra($newValueP, $canonP, $xml, &mapValue($newValueP, $movedFromP), 1);
      return;
    }
  }
  
  if (!$startTag || !$endTag) {
    &Log("ERROR VSYS_EXTRA($bk, $ch, $vs, $lv): Missing start-tag (=$startTag) or end-tag (=$endTag).\n");
    return;
  }
 
  # If isWholeChapter, then convert chapter tags to alterantes and add alternate chapter number
  if ($isWholeChapter) {
    my $chapLabel = @{$XPC->findnodes("//osis:title[\@type='x-chapterLabel'][not(\@canonical='true')][preceding::osis:chapter[\@osisID][1][\@sID='$bk.$ch'][not(preceding::osis:chapter[\@eID='$bk.$ch'])]]", $xml)}[0];
    if ($chapLabel) {
      &Log("NOTE: Converting chapter label \"".$chapLabel->textContent."\" to alternate.\n");
      $chapLabel->setAttribute('type', 'x-chapterLabel-alternate');
      my $alt = $XML_PARSER->parse_balanced_chunk("<hi type=\"italic\" subType=\"x-alternate\"></hi>");
      foreach my $chld ($chapLabel->childNodes) {$alt->insertAfter($chld, undef);}
      $chapLabel->insertAfter($alt, undef);
    }
    else {
      &Log("NOTE: No chapter label was found, adding alternate chapter label \"$ch\".\n");
      my $alt = $XML_PARSER->parse_balanced_chunk("<title type=\"x-chapterLabel-alternate\"><hi type=\"italic\" subType=\"x-alternate\">$ch</hi></title>");
      my $chStart = @{$XPC->findnodes("//osis:chapter[\@osisID='$bk.$ch']", $xml)}[0];
      $chStart->parentNode()->insertAfter($alt, $chStart);
    }
    my $chEnd = &toAlternate(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0]);
    $chEnd->setAttribute('eID', "$bk.".($ch-1));
    &toAlternate(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0], 1);
    &toAlternate(@{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0], 1);
  }
  
  # Convert verse tags between startTag and endTag, and add alternate verse numbers (THIS FINDNODES METHOD IS ULTRA SLOW BUT WORKS)
  my $ns1 = '//osis:verse[@sID="'.$startTag->getAttribute('sID').'"]/following::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
  my $ns2 = '//osis:verse[@eID="'.$endTag->getAttribute('eID').'"]/preceding::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
  my @convert = $XPC->findnodes($ns1.'[count(.|'.$ns2.') = count('.$ns2.')]', $xml);
  
  foreach my $v (@convert) {&toAlternate($v, 1, 0, $movedFromP);}
  $endTag = &toAlternate($endTag);
  $endTag->setAttribute('eID', $startTag->getAttribute('sID'));
  
  # If not isWholeChapter, then any following verses get decremented verse numbers plus an alternate verse number
  if (!$isWholeChapter) {
    my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
    my $count = (1 + $lv - $vs);
    for (my $v = $vs + $count + ($vs!=1 ? 0:1); $v <= $lastV; $v++) {
      &reVersify($bk, $ch, $v, (-1*$count), $xml);
    }
  }
}

# Markup verse as alternate and increment it by count
sub reVersify($$$$$) {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $count = shift;
  my $xml = shift;
  
  &Log("NOTE: reVersify($bk, $ch, $vs, $count): ");
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  if (!$vTagS) {&Log("Start tag not found.\n"); return;}
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  if (!$vTagE) {&Log("End tag not found!\n"); return;}
  &Log("\n");
  
  my $osisID = $vTagS->getAttribute('osisID');
  my $newVerseID;
  my $newID;
  if ($count) {
    my @verses = split(/\s+/, $osisID);
    $newVerseID = "$bk.$ch.".($vs + $count);
    foreach my $v (@verses) {if ($v  eq "$bk.$ch.$vs") {$v = $newVerseID;}}
    $newID = join(' ', @verses);
  }
  
  if (!$vTagS->getAttribute('type') || $vTagS->getAttribute('type') ne $VSYS{'prefix'}.$VSYS{'TypeModified'}) {
    $vTagS = &toAlternate($vTagS);
    $vTagE = &toAlternate($vTagE);
  }
  elsif (&getAltID($vTagS) eq $newID) {
    $vTagS = &undoAlternate(&getAltID($vTagS));
    $vTagE = &undoAlternate(&getAltID($vTagE));
    $osisID = $vTagS->getAttribute('osisID');
  }
  else{&Log("NOTE: Alternate verse already set.\n");}
  
  # Increment/Decrement
  if ($count) {
    if ($newID ne $osisID) {
      &Log("NOTE: Changing verse osisID='".$vTagS->getAttribute('osisID')."' to '$newID'.\n");
      &osisIDCheckUnique($newVerseID, $xml);
      $vTagS->setAttribute('osisID', $newID);
      $vTagS->setAttribute('sID', $newID);
      $vTagS->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
      $vTagE->setAttribute('eID', $newID);
      $vTagE->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
    }
  }
}

# This takes a verse or chapter element (start or end) and marks it as
# part of the alternate verse system, unless already done, by:
# 1) Converting it to a milestone element 
# 2) Cloning a target verse system element (unless noTarget is set)
# 3) Adding an alternate verse number if the element is verse-start (unless noAlt is set)
# This funtion returns the new target verse system element (if any)
sub toAlternate($$$$) {
  my $elem = shift;
  my $noTarget = shift;
  my $noAlt = shift;
  my $movedFromP = shift;
  
  # Typical alternate markup example:
  # <milestone type="x-vsys-verse-start" osisRef="Rom.14.24" annotateRef="Rom.16.25" annotateType="x-vsys-source"/><hi type="italic" subType="x-alternate"><hi type="super">(25)</hi></hi>
  
  my $telem;
  my $type = ($elem->getAttribute('sID') ? 'start':($elem->getAttribute('eID') ? 'end':''));
  my $osisID = ($type eq 'start' ? $elem->getAttribute('sID'):$elem->getAttribute('eID'));
  my $isVerseStart = ($type eq 'start' && $elem->nodeName eq 'verse' ? 1:0);
  
  &Log("NOTE: To alternate $osisID ".$elem->nodeName." $type");
  
  if (&getAltID($elem)) {
    &Log(", already done");
    if ($noTarget && $elem->getAttribute('type') eq $VSYS{'prefix'}.$VSYS{'TypeModified'}) {
      $elem->unbindNode();
      &Log(", removed target tag");
    }
    &Log("\n");
    return $elem;
  }
  
  if (!$noTarget) {
    $telem = $elem->cloneNode(1);
    if ($telem->getAttribute('type')) {&Log("\nERROR: Type already set on $telem\n");}
    $telem->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
    $elem->parentNode->insertBefore($telem, $elem);
    &Log(", cloned");
  }
  
  # Convert to milestone
  if (!$type) {
    &Log("\nERROR: Element missing sID or eID: $elem\n");
  }
  if ($type eq 'start' && $osisID ne $elem->getAttribute('osisID')) {
    &Log("\nERROR: osisID is different that sID: $osisID != ".$elem->getAttribute('osisID')."\n");
  }
  $elem->setAttribute('type', $VSYS{'prefix'}.'-'.$elem->nodeName.$VSYS{$type});
  if ($type eq 'start' && $movedFromP) {
    my @vids;
    foreach my $v (split(/\s+/, $osisID)) {
      if (!$movedFromP->{'map'}{$v}) {&Log("\nERROR: No movedFrom mapped value for $v\n");}
      push(@vids, $movedFromP->{'map'}{$v});
    }
    $elem->setAttribute('osisRef', &osisID2osisRef(join(' ', @vids)));
  }
  $elem->setAttribute('annotateRef', $osisID);
  $elem->setAttribute('annotateType', $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'});
  $elem->setNodeName('milestone');
  if ($elem->hasAttribute('osisID')) {$elem->removeAttribute('osisID');}
  if ($elem->hasAttribute('sID')) {$elem->removeAttribute('sID');}
  if ($elem->hasAttribute('eID')) {$elem->removeAttribute('eID');}
  &Log(", converted");
  
  # Add alternate verse number
  if (!$noAlt && $isVerseStart) {
    if ($osisID =~ /^[^\.]+\.\d+\.(\d+)\b.*?(\.(\d+))?$/) {
      my $newv = ($2 ? "$1-$3":"$1");
      my $alt = $XML_PARSER->parse_balanced_chunk('<hi type="italic" subType="x-alternate"><hi type="super">('.$newv.')</hi></hi>');
      my $firstTextNode = @{$XPC->findnodes('following::text()[normalize-space()][1]', $elem)}[0];
      $firstTextNode->parentNode()->insertBefore($alt, $firstTextNode);
      &Log(", added alternate verse \"$newv\"");
    }
    else {&Log("\nERROR: Could not parse \"$osisID\"!\n");}
  }
  &Log("\n");
  
  return $telem;
}

# This will take an alternate milestone element (verse or chapter, start 
# or end) and convert it back to original by undoing everything 
# toAlternate() did. It returns the original element.
sub undoAlternate($) {
  my $ms = shift;
  
  &Log("NOTE: Undo alternate ".$ms->getAttribute('type').' '.$ms->getAttribute('annotateRef'));
  
  my $avn = @{$XPC->findnodes('following::text()[normalize-space()][1]/preceding-sibling::*[1][@subType="x-alternate"]', $ms)}[0];
  if ($avn) {
    $avn->unbindNode();
    &Log(", removed alternate verse number");
  }
  my $vtag = @{$XPC->findnodes('preceding-sibling::*[1][@type="'.$VSYS{'prefix'}.$VSYS{'TypeModified'}.'"]', $ms)}[0];
  if ($vtag) {
    $vtag->unbindNode();
    &Log(", removed verse tag");
  }
  my $chvsTypeRE = '^\Q'.$VSYS{'prefix'}.'\E'.'\-(chapter|verse)(\Q'.$VSYS{'start'}.'\E|\Q'.$VSYS{'end'}.'\E)$';
  if ($ms->getAttribute('type') =~ /$chvsTypeRE/) {
    my $name = $1; my $type = $2;
    $ms->setNodeName($name);
    if ($type eq 'start') {
      $ms->setAttribute('sID', $ms->getAttribute('annotateRef'));
      $ms->setAttribute('osisID', $ms->getAttribute('annotateRef'));
    }
    else {$ms->setAttribute('eID', $ms->getAttribute('annotateRef'));}
    $ms->removeAttribute('annotateRef');
    $ms->removeAttribute('annotateType');
    $ms->removeAttribute('type');
    if ($ms->hasAttribute('osisRef')) {$ms->removeAttribute('osisRef');}
  }
  else {&Log("\nERROR: Can't parse type=\"".$ms->getAttribute('type')."\"\n");}
  
  &Log(", converted milestone to verse\n");
  
  return $ms;
}

# Report an error if any verse in this hypothetical osisID is already listed 
# in an existing osisID (to catch any bug causing multiple verse tags to cover 
# the same verse)
sub osisIDCheckUnique($$) {
  my $osisID = shift;
  my $xml = shift;
  
  my @verses = split(/\s+/, $osisID);
  foreach my $v (@verses) {
    my $chv = &getVerseTag($v, $xml, 0);
    if ($chv) {
      &Log("ERROR: osisIDCheckUnique($osisID): Existing verse osisID=\"".$chv->getAttribute('osisID')."\" includes \"$v\"!\n");
    }
  }
}

# Reads the osis file to find a chapter's smallest verse number
sub getFirstVerseInChapterOSIS($$$) {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  
  my $fv = 200;
  foreach my $v (@vs) {if ($v->getAttribute('osisID') =~ /^\Q$bk.$ch.\E(\d+)/ && $1 < $fv) {$fv = $1;}}
  if ($fv == 200) {
    &Log("ERROR: getFirstVerseInChapterOSIS($bk, $ch): Could not find first verse.\n");
    return '';
  }
  
  return $fv;
}

# Reads the osis file to find a chapter's largest verse number
sub getLastVerseInChapterOSIS($$$) {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  
  my $lv = 0;
  foreach my $v (@vs) {if ($v->getAttribute('osisID') =~ /\b\Q$bk.$ch.\E(\d+)$/ && $1 > $lv) {$lv = $1;}}
  if (!$lv) {
    &Log("ERROR: getLastVerseInChapterOSIS($bk, $ch): Could not find last verse.\n");
    return '';
  }
  
  return $lv;
}

# Checks that a 4 part verse range covers an entire chapter in the given
# verse system. Also normalizes verses so they never contain empty values.
sub isWholeVsysChapter($$\$\$$) {
  my $bk  = shift;
  my $ch  = shift;
  my $vsP  = shift;
  my $lvP  = shift;
  my $canonP = shift;
  
  my $haveVS = ($$vsP ? 1:0);
  $$vsP = ($haveVS ? $$vsP:1);
  $$lvP = ($$lvP ? $$lvP:($haveVS ? $$vsP:$canonP->{$bk}[($ch-1)]));

  return ($$vsP == 1 && $$lvP == $canonP->{$bk}[($ch-1)]);
}

# Take a verse element and return its alternate id, or '' if there isn't
# one. If returnElem is set the entire milestone element is returned.
sub getAltID($$) {
  my $verseElem = shift;
  my $returnElem = shift;
  
  my $ms = @{$XPC->findnodes('following::*[1][name()="milestone"][starts-with(@type, "'.$VSYS{'prefix'}.'-verse")]', $verseElem)}[0];
  if (!$ms) {return '';}
  return ($returnElem ? $ms:$ms->getAttribute('annotateRef'));
}

1;
