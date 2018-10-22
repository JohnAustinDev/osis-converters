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

$fitToVerseSystemDoc = "
------------------------------------------------------------------------
------------------------------------------------------------------------
OSIS-CONVERTERS VERSIFICATION MAPPING:
The goal is to fit a source Bible translation having a custom verse 
system into a known fixed versification system so that every verse of 
the source system is identified according to the known system. Both the 
fixed and the source verse systems are recorded together in a single 
OSIS file. This process should be as easy as possible for the person 
running the conversion, so only differences between the source and fixed 
verse systems need to be identified, using the small set of instructions
described below. Also the Bible translation can be easily read from the 
OSIS file (for instance using a simple XSLT) with either the source or 
fixed verse system, while at the same time all Scripture references will 
be correct according to the chosen verse system.

IMPORANT:
In the following descriptions, this:
BK.1.2.3
means this:
Bible book 'BK' chapter '1' verse '2' through '3', or, BK 1:2-3

VSYS_MOVED: BK.1.2.3 -> BK.4.5.6
Specifies that this translation has moved the verses that would be found 
in a range of the fixed verse system to a different position in the 
source verse system, indicated by the range to the right of '->'. The 
two ranges must be the same size. It is processed as a 
VSYS_MISSING: <fixed-vsys-range> followed by
VSYS_EXTRA: <source-vsys-range>. The end verse portion of either range 
may be the keyword 'PART' (such as Gen.4.7.PART), meaning that the 
reference applies to only part of the specified verse. The VSYS_MOVED 
instruction also updates the hyperlink targets of externally sourced 
Scripture cross-references so that they correctly point to their moved 
location in the source translation.

VSYS_EXTRA: BK.1.2.3
Specifies that this translation has inserted a range of verses of the 
source verse system which are not found in the target verse system. 
These additional verses will all be appended to the preceeding extant 
verse in the fixed verse system. The additional verses, and any regular 
verses following them in the chapter, will have alternate verse numbers 
appended before them, to display their verse number according to the 
source verse system. The range may be an entire chapter if it occurs at
the end of a book (like Psalm 151), in which case an alternate chapter 
number will be inserted and the chapter will be appended to the last
verse of the previous chapter.

VSYS_MISSING: BK.1.2.3
Specifies that this translation does not include a range of verses of
the fixed verse system. The preceeding extant verse id will be modified 
to span the missing range, but in no case exceeding the end of a 
chapter. Alternate numbers will be appended to any following verses in 
the chapter to display their verse number according to the source verse 
system. Entire missing chapters are not supported.

VSYS_MOVED_ALT: 
Similar to VSYS_MOVED but this should be used when alternate verse 
markup like '\va 2\va*' has already been used by the translators for the 
moved verses (rather than regular verse markers, which is the more 
common case). This instruction will not change the OSIS markup of the 
alternate verses. It is the same as 'VSYS_MISSING: A' followed by 
'VSYS_FROM_TO: A -> B'.

VSYS_MISSING_FN:
Same as VSYS_MISSING but it only accepts a single verse and is only used 
if a footnote was included in the verse before the missing verse which 
addresses the missing verse. This will forward references to the 
missing verses to the previous verse which contains the footnote. This 
instruction is the same as a VSYS_MISSING followed by a VSYS_FROM_TO 
instruction.

VSYS_EMPTY: BK.1.2.3
Use this if regular verse markers are included in the text, however the 
verses are left empty. This will just remove external Scripture 
cross-references to the removed verse.

VSYS_FROM_TO: BK.1.2.3 -> BK.4.5.6
This does not effect any verse or alternate verse markup or locations. 
It only forwards external references from their expected address in the 
fixed verse system to a different location in the source verse system.
It would be used if a verse is marked in the text but is left empty,
while there is a footnote about it in the previous verse (but see 
VSYS_MISSING_FN which is the more comom case). VSYS_FROM_TO is usually 
NOT the right instruction for most use cases (because it is used more 
internally).

SET_customBookOrder:true
Turns off the book re-ordering step so books will remain in processed 
order.

NOTES:
- Each instruction is evaluated in fixed verse system order regardless 
of their order in the CF_ file.
- A verse may be effected by multiple instructions.
- This implementation does not accomodate extra books, or ranges of 
chapters, and whole chapters are only supported with VSYS_EXTRA for
chapters at the end of a book, where the chapter was simply appended 
(such as Psalm 151 of Synodal).
------------------------------------------------------------------------
------------------------------------------------------------------------

";

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
  my $osisP = shift;
  my $vsys = shift;
  my $maintainBookOrder = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1orderBooksPeriphs$3/;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nOrdering books and peripherals of \"$$osisP\" by versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Cannot re-order books in OSIS file because getCanon($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);

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
    if ($bk ne '') {&ErrorBug("Book \"$bk\" was not found in $vsys Canon.");}
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
      push(@mylog, "Error: Removing periph(s)! You must specify the location where each peripheral file should be placed within the OSIS file.");
      push(@mylog, &placementMessage());
      push(@mylog, "REMOVED:\n$periph");
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
          push(@mylog, "Error: Unhandled location or scope assignment \"$part\" in \"".@commentNode[0]."\" in CF_usfm2osis.txt");
        }
        my $emsg = "as specified by \"$part\"";
        my $int = $1;
        my $xpath = $2;
        $int =~ s/"//g; # strip possible quotes
        if ($int eq 'scope') {
          if (!$periph->getAttribute('osisRef')) {
            $periph->setAttribute('osisRef', $xpath); # $xpath is not an xpath in this case but rather a scope
          }
          else {push(@mylog, "Error: Introduction comment specifies scope == $int, but introduction already has osisRef=\"".$periph->getAttribute('osisRef')."\"");}
          next;
        }
        
        my @targXpath = ();
        if ($xpath =~ /^remove$/i) {$xpath = '';}
        else {
          $xpath = '//'.$xpath;
          @targXpath = $XPC->findnodes($xpath, $xml);
          if (!@targXpath) {
            push(@mylog, "Error: Removing periph! Could not locate xpath:\"$xpath\" $emsg");
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
            push(@mylog, "Error: Could not place periph! Unable to map \"$int\" to a div element $emsg.");
            next;
          }
          my $srcXpath = './/osis:div[@type="'.$type.'"]'.($subType ? '[@subType="'.$subType.'"]':'[not(@subType)]');
          my @ptag = $XPC->findnodes($srcXpath, $periph);
          if (!@ptag) {
            push(@mylog, "Error: Could not place periph! Did not find \"$srcXpath\" $emsg.");
            next;
          }
          @ptag[$#ptag]->unbindNode();
          if ($xpath) {&placeIntroduction(@ptag[$#ptag], @targXpath[$#targXpath]);}
        }
        if ($xpath) {
          my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
          push(@mylog, "Note: Placing $tg as specified by \"$int\" == \"$xpath\"");
        }
        else {push(@mylog, "Note: Removing \"$int\" $emsg.");}
      }
    }
    if (!$placedPeriph) {
      my @tst = $XPC->findnodes('.//*', $periph);
      my @tst2 = $XPC->findnodes('.//text()[normalize-space()]', $periph);
      if ((@tst && @tst[0]) || (@tst2 && @tst2[0])) {
        push(@mylog,
"Error: The placement location for the following peripheral material was 
not specified and its position may be incorrect:
$periph
To position the above material, add location == <XPATH> after the \\id tag."
        );
        push(@mylog, &placementMessage());
      }
      else {
        $periph->unbindNode();
        my $tg = $periph->toString(); $tg =~ s/>.*$/>/s;
        push(@mylog, "Note: Removing empty div: $tg");
      }
    }
  }
  foreach my $lg (reverse(@mylog)) {
    if ($lg =~ s/^\s*Error\:\s*//) {&Error($lg);}
    elsif ($lg =~ s/^\s*Note\:\s*//) {&Note($lg);}
    else {&Log($lg);}
  }
  
  open(OUTF, ">$output");
  print OUTF $xml->toString();
  close(OUTF);
  $$osisP = $output;
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
  my $osisP = shift;
  my $vsys = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1fitToVerseSystem$3/;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nFitting OSIS \"$$osisP\" to versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Not Fitting OSIS versification because getCanon($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @existing = $XPC->findnodes('//osis:milestone[@annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"]', $xml);
  if (@existing) {
    &Warn("
There are ".@existing." fitted tags in the text. This OSIS file has 
already been fitted so this step will be skipped!");
  }
  elsif (@VSYS_INSTR) {
    # Apply alternate VSYS instructions to the translation
    foreach my $argsP (@VSYS_INSTR) {&applyVsysInstruction($argsP, $canonP, $xml);}
    my $scopeElement = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-bible"]]/osis:scope', $xml)}[0];
    if ($scopeElement) {&changeNodeText($scopeElement, &getScope($xml));}
    # Save and re-read osis file now so that new elements will all have osis namespace for later checks
    open(OUTF, ">$output");
    print OUTF $xml->toString();
    close(OUTF);
    $$osisP = $output;
    $xml = $XML_PARSER->parse_file($$osisP);
  }
  
  my @nakedAltTags = $XPC->findnodes('//osis:hi[@subType="x-alternate"][not(preceding::*[1][self::osis:milestone[starts-with(@type, "'.$VSYS{'prefix'}.'")]])]', $xml);
  if (@nakedAltTags) {
    &Warn("The following alternate verse tags were found.",
"If these represent verses which normally appear somewhere else in the 
$vsys verse system, then a VSYS_MOVED_ALT instruction should be 
added to CF_usfm2osis.txt to allow correction of external cross-
references:");
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
          &Error("Chapter/verse ordering problem at ".@v[$x]." (expected $ch.$vs)", "Check your SFM for out of order chapter/verses and fix them.");
          $errors++;
          next;
        }
        if (@v[$x] !~ /\b\Q$bk.$ch.$vs\E\b/) {
          &Error("Missing verse $bk.$ch.$vs.", "If this verse is supposed to be missing, then add a VSYS_MISSING instruction to CF_usfm2osis.txt. $fitToVerseSystemDoc");
          $fitToVerseSystemDoc = '';
          $errors++;
          next;
        }
        @v[$x] =~/\.(\d+)\s*$/; $vs = ($1*1);
        $x++;
      }
      while (@v[$x] =~ /^\Q$bk.$ch./) {
        &Error("Extra verse: ".@v[$x], "If this verse is supposed to be extra, then add a VSYS_EXTRA instruction to CF_usfm2osis.txt. $fitToVerseSystemDoc");
        $fitToVerseSystemDoc = '';
        $errors++;
        $x++;
      }
      $ch++;
    }
    while (@v[$x] =~ /^\Q$bk./) {
      &Error("Extra chapter: ".@v[$x], "If this chapter is supposed to be missing, then add a VSYS_EXTRA instruction to CF_usfm2osis.txt. $fitToVerseSystemDoc");
      $fitToVerseSystemDoc = '';
      $errors++;
      $x++;
    }
  }
  if ($x == @v) {&Log("\n"); &Note("All verses were checked against verse system $vsys.");}
  else {&Log("\n"); &ErrorBug("Problem checking chapters and verses in verse system $vsys (stopped at $x of @v verses: ".@v[$x].")");}
  
  &Log("\n");
  &Report("$errors verse system problems detected".($errors ? ':':'.'));
  if ($errors) {
    &Note("
      This translation does not fit the $vsys verse system. The errors 
      listed above must be fixed. Add the appropriate instructions:
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED to CF_usfm2osis.txt. $fitToVerseSystemDoc");
    $fitToVerseSystemDoc = '';
  }
}

# Read bibleMod and the osis file and:
# 1) Find all verse osisIDs in $bibleMod which were changed by VSYS 
#    instructions. These are used for updating source osisRefs, but 
#    these do NOT effect osisRefs of runAddCrossRefs() references. 
# 2) Find all verse osisIDs in $bibleMod which were moved by the 
#    translators with respect to the chosen fixed verse system. These
#    are used for updating external osisRefs.
# 3) Find applicable osisRefs in $osis which point to the osisIDs found 
#    in #2 and #3, and correct them, plus add source target as annotateRef.
sub correctReferencesVSYS($$) {
  my $osisP = shift;
  my $bibleMod = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1correctReferencesVSYS$3/;
  
  my $bfile = ($bibleMod eq $MOD ? $$osisP:&getProjectOsisFile($bibleMod));

  if (! -e $bfile) {
    &Warn("No OSIS Bible file was found. References effected by VSYS instructions will not be corrected.");
    return;
  }
  &Log("\n\nUpdating osisRef attributes of \"$bfile\" that require re-targeting after VSYS instructions:\n", 1);
  
  my $count = 0;
  
  # Read Bible file
  my $bibleXML = $XML_PARSER->parse_file($bfile);
  my $vsys = &getVerseSystemOSIS($bibleXML);
  
  # Read OSIS file
  my $osisXML = $XML_PARSER->parse_file($$osisP);
  my @existing = $XPC->findnodes('//osis:reference[@annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"][@annotateRef][@osisRef]', $osisXML);
  if (@existing) {
    &Warn(@existing." references have already been updated, so this step will be skipped.");
    return;
  }
  
  # 1) Get osisIDs from the source verse system that need mapping to the target verse system.
  # This map is used to update references within the translation that point to alternate verses.
  my $sourceVerseMapP = &getAltVersesOSIS($bibleXML)->{'alt2Fixed'};
    
  # 2) Get osisIDs from the target verse system that need re-mapping to the target verse-system (because of VSYS_MOVED instructions).
  # This map is used to update external references (in the target verse system) that were broken by VSYS_MOVED instructions.
  my $targetVerseMapP = &getAltVersesOSIS($bibleXML)->{'fixed2Fixed'};

  # References which target verses that are purposefully not included in the translation are removed
  my %missing;
  foreach my $m (@{&getAltVersesOSIS($bibleXML)->{'missing'}}) {
    map($missing{$_}++, split(/\s+/, &osisRef2osisID($m->getAttribute('osisRef'))));
  }
  
  # 3) Look for osisRefs in the osis file that need updating and update them
  if (%{$sourceVerseMapP} || %{$targetVerseMapP} || %missing) {
    my $lastch = '';
    my @checkrefs = ();
    foreach my $verse (&normalizeOsisID([ keys(%{$sourceVerseMapP}) ])) {
      $verse =~ /^(.*?)\.\d+$/;
      my $ch = $1;
      if (!$lastch || $lastch ne $ch) {
        # Select all elements having osisRef attributes EXCEPT those within externally sourced 
        # crossReferences since they already match the target verse-system.
        @checkrefs = $XPC->findnodes("//*[contains(\@osisRef, '$ch')][not(starts-with(\@type, '".$VSYS{'prefix'}."'))][not(ancestor-or-self::osis:note[\@type='crossReference'][\@resp])]", $osisXML);
      }
      $lastch = $ch;
      &addrids(\@checkrefs, $verse, $sourceVerseMapP, 'alt2Fixed');
    }
    
    $lastch = '';
    @checkrefs = ();
    my @verses = &normalizeOsisID([ keys(%{$targetVerseMapP}) ]); push(@verses, keys(%missing));
    foreach my $verse (@verses) {
      $verse =~ /^(.*?)\.\d+$/;
      my $ch = $1;
      if (!$lastch || $lastch ne $ch) {
        # Select ONLY elements having osisRef attributes within externally sourced crossReferences 
        @checkrefs = $XPC->findnodes("//*[contains(\@osisRef, '$ch')][not(starts-with(\@type, '".$VSYS{'prefix'}."'))][ancestor-or-self::osis:note[\@type='crossReference'][\@resp]]", $osisXML);
      }
      $lastch = $ch;
      &addrids(\@checkrefs, $verse, $targetVerseMapP, 'fixed2Fixed', \%missing);
    }
    
    $count = &applyrids($osisXML, &getAltVersesOSIS($bibleXML)->{'fixed2Alt'});
  }
  
  # Overwrite OSIS file if anything changed
  if ($count) {
    if (open(OUTF, ">$output")) {
      print OUTF $osisXML->toString();
      close(OUTF);
      $$osisP = $output;
    }
    else {&ErrorBug("Could not open \"$output\" to write osisRef fixes.");}
  }
  
  &Log("\n");
  &Report("\"$count\" osisRefs were corrected to account for differences between source and fixed verse systems.");
}

# If any osisRef in the @checkRefs array of osisRefs includes $verse,  
# then add a rids attribute. The rids attribute contains redirected  
# verse osisID(s) that will become the updated osisRef value of the 
# parent element.
sub addrids(\@$\%$\%) {
  my $checkRefsAP = shift;
  my $verse = shift;
  my $mapHP = shift;
  my $mapType = shift;
  my $missingHP = shift;
  
  foreach my $e (@{$checkRefsAP}) {
    my $changed = 0; # only write a rids attrib if there is a change
    my $ridsAttrib = ($e->hasAttribute('rids') ? $e->getAttribute('rids'):&osisRef2osisID($e->getAttribute('osisRef')));
    my @rids = split(/\s+/, $ridsAttrib);
    foreach my $rid (@rids) {
      # Never modify osisRef segments with extensions, because non verse elements (osisIDs) 
      # are never modified by fitToVerseSystem and references to them should thus not be mapped
      if ($rid =~ /\!/) {next;}
      elsif ($rid ne $verse) {next;}
      elsif ($mapHP->{$verse}) {
        # Any mapped reference is by definition not missing, so $missingHP is never checked
        $rid = join(' ', map("$mapType.$_", split(/\s+/, $mapHP->{$verse})));
        $changed++;
      }
      # This references a fixed osisID which is missing, so mark it as such
      elsif ($mapType =~ /^fixed/i && $missingHP->{$verse}) {
        $rid = "$mapType.$verse!does-not-exist";
        $changed++;
      }
      else {&ErrorBug("Could not map \"$verse\" to verse system.");}
    }
    if ($changed) {$e->setAttribute('rids', join(' ', @rids));}
  }
}

# Applies the rids attribute to an element and removes the rids attribute.
# Also writes an annotateRef containing the source verse system osisRef.
# References that were mapped as fixed2Fixed (external) must have their
# osisRef (which was fixed) mapped to obtain annotateRef (which is source).
# So %movedHP is used for that. Elements with osisRefs pointing to verses 
# labeled as 'does-not-exist' are removed.
sub applyrids($\%) {
  my $xml = shift;
  my $movedHP = shift;
  
  my ($update, $remove, $map);
  my $count = 0;
  foreach my $e ($XPC->findnodes('//*[@rids]', $xml)) {
    my $rids = $e->getAttribute('rids');
    $e->removeAttribute('rids');
    my $tag = $e->toString(); $tag =~ s/^[^<]*(<[^>]+?>).*$/$1/s;
    
    my $isExternal = 0;
    my $removeElement = 1;
    my @rid;
    foreach my $r (split(/\s+/, $rids)) {
      if ($r !~ s/\Q!does-not-exist\E$//) {$removeElement = 0;}
      if ($r =~ /fixed2Fixed/) {$isExternal = 1;}
      $r =~ s/^(alt2Fixed|fixed2Fixed)\.//;
      push(@rid, $r);
    }
    if (!$removeElement) {
      # Add annotateRef and annotateType attributes
      my @annoRefs = split(/\s+/, &osisRef2osisID($e->getAttribute('osisRef')));
      if ($isExternal) {
        foreach my $ar (@annoRefs) {if ($movedHP->{$ar}) {$ar = $movedHP->{$ar};}}
      }
      my $annoRef = &osisID2osisRef(join(' ', @annoRefs));
      if ($annoRef =~ /\s+/) {
        # Sometimes mapped ranges might be split up due to missing verses
        $annoRef = &fillGapsInOsisRef($annoRef);
        if ($annoRef =~ /\s+/) {
          &ErrorBug("Mapped reference has multiple segments \"".$e->getAttribute('osisRef')."\" --> \"$annoRef\"");
        }
        else {&Note("Filled gaps in mapped osisRef: $annoRef");}
      }
      if ($e->getAttribute('osisRef') ne $annoRef) {
        $map .= "MAPPING external AnnotateRef type ".$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}." ".$e->getAttribute('osisRef')." -> $annoRef\n";
      }
      $e->setAttribute('annotateRef', $annoRef);
      $e->setAttribute('annotateType', $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'});
      
      # Update osisRef attribute value
      my $newOsisRef = &osisID2osisRef(join(' ', &normalizeOsisID(\@rid)));
      if ($e->getAttribute('osisRef') ne $newOsisRef) {
        my $origRef = $e->getAttribute('osisRef');
        $e->setAttribute('osisRef', $newOsisRef);
        my $ie = ($e->nodeName =~ /(note|reference)/ ? (@{$XPC->findnodes('./ancestor-or-self::osis:note[@resp]', $e)}[0] ? 'external ':'internal '):'');
        my $est = $e; $est =~ s/^(.*?>).*$/$1/;
        $update .= "UPDATING $ie".$e->nodeName." osisRef $origRef -> $newOsisRef\n";
        $count++;
      }
      else {
        # No need for annotateRef if osisRef was not changed
        if ($e->hasAttribute('annotateRef')) {$e->removeAttribute('annotateRef');}
        if ($e->hasAttribute('annotateType')) {$e->removeAttribute('annotateType');}
      }
    }
    else {
      my $parent = $e->parentNode();
      $parent = $parent->toString(); $parent =~ s/^[^<]*(<[^>]+?>).*$/$1/s;
      if ($e->getAttribute('type') eq "crossReference") {
        $remove .= "REMOVING cross-reference for missing verse: $tag\n";
      }
      else {
        $remove .= "REMOVING tags for missing verse: $tag \n";
        foreach my $chld ($e->childNodes) {$e->parentNode()->insertBefore($chld, $e);}
      }
      $e->unbindNode();
      $count++;
    }
  }
  if ($map)    {&Note("\n$map\n");}
  if ($update) {&Note("\n$update\n");}
  if ($remove) {&Note("\n$remove\n");}
  
  return $count;
}

# Take an osisRef's starting and ending point, and if they are in the
# same chapter, return an osisRef that covers the entire range between
# them. This can be used to 'heal' missing verses in mapped ranges.
sub fillGapsInOsisRef() {
  my $osisRef = shift;
  
  my @id = split(/\s+/, &osisRef2osisID($osisRef));
  @id[0]    =~ /^([^\.]+\.\d+\.)\d+$/; my $chf = $1;
  @id[$#id] =~ /^([^\.]+\.\d+\.)\d+$/; my $chl = $1;
  if ($chf eq $chl) {return @id[0].'-'.@id[$#id];}
  return $osisRef;
}

sub applyVsysInstruction(\%\%$) {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  
  &Log("\nVSYS_".$argP->{'inst'}.": fixed=".$argP->{'fixed'}.", source=".$argP->{'source'}.", ops=".$argP->{'ops'}."\n");

  my $inst = $argP->{'inst'};
  
  # NOTE: 'fixed' always refers to the known fixed verse system, 
  # and 'source' always refers to the customized source verse system
  my $fixedP  = ($argP->{'fixed'}  ? &readValue($argP->{'fixed'},  $xml):'');
  my $sourceP = ($argP->{'source'} ? &readValue($argP->{'source'}, $xml):'');
  
  if ($fixedP && $sourceP && $fixedP->{'count'} != $sourceP->{'count'}) {
    &Error("'From' and 'To' are a different number of verses: $inst: ".$argP->{'fixed'}." -> ".$argP->{'source'});
    return 0;
  }
  
  my $test = ($fixedP->{'bk'} ? $fixedP->{'bk'}:$sourceP->{'bk'});
  if (!&getBooksOSIS($xml)->{$test}) {
    &Warn("Skipping VSYS_$inst because $test is not in the OSIS file.", "Is this instruction correct?");
    return 0;
  }
  
  if    ($inst eq 'MISSING') {&applyVsysMissing($fixedP, $xml, &mapValue($fixedP, $sourceP));}
  elsif ($inst eq 'EXTRA')   {&applyVsysExtra($sourceP, $canonP, $xml, &mapValue($sourceP, $fixedP));}
  elsif ($inst eq 'FROM')    {&applyVsysFrom($sourceP, $canonP, $xml, &mapValue($sourceP, $fixedP));}
  elsif ($inst eq 'TO')      {&applyVsysTo($fixedP, $xml, &mapValue($fixedP, $sourceP));}
  else {&ErrorBug("applyVsysInstruction did nothing: $inst");}
  
  return 1;
}

sub readValue($$) {
  my $value = shift;
  my $xml = shift;
  
  my %data;
  $data{'value'} = $value;
  
  # read and preprocess value
  if ($value !~ /^$VSYS_PINSTR_RE$/) {
    &ErrorBug("readValue: Could not parse: $value !~ /^$VSYS_PINSTR_RE\$/");
    return \%data;
  }
  my $bk = $1; my $ch = $2; my $vs = ($3 ? $4:''); my $lv = ($5 ? $6:'');
  
  $data{'isPartial'} = ($lv =~ s/^PART$/$vs/ ? 1:0);
  $data{'isWholeChapter'} = &isWholeVsysChapter($bk, $ch, \$vs, \$lv, $xml);
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
    &ErrorBug("mapValue: Count mismatch: ".$fromP->{'value'}.", ".$toP->{'value'}." (".@fromvs." != ".@tovs.")");
  }
  
  for (my $i=0; $i<@fromvs; $i++) {$map{'map'}{@fromvs[$i]} = @tovs[$i];}
  
  return \%map;
}

# This only adds milestone markers indicating where material in the 
# source verse system was moved from with respect to the fixed verse  
# system. The location of the milestone is before an alternate verse 
# number when there is one (the usual case), otherwise it will be at the 
# end of the verse.
sub applyVsysFrom($$$$) {
  my $sourceP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $source2FromP = shift;
  
  if (!$source2FromP) {
    &Note("These verses were not moved from somewhere else, so nothing to do here.");
    return;
  }
  
  if ($sourceP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  my $isWholeChapter = ($sourceP->{'ch'} > @{$canonP->{$sourceP->{'bk'}}} ? 1:$sourceP->{'isWholeChapter'});
  if ($isWholeChapter) {
    &Error("applyVsysFrom: Not supported for entire chapters.", "Check your VSYS instructions in CF_usfm2osis.txt");
    return;
  }
  
  my $note = "[applyVsysFrom]";
  my $type = $VSYS{'prefix'}.$VSYS{'movedfrom'};
  my $annotateType = $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'};
  for (my $v=$sourceP->{'vs'}; $v<=$sourceP->{'lv'}; $v++) {
    my $success = 0;
    my $a = $sourceP->{'bk'}.".".$sourceP->{'ch'}.".$v";
    my @altsInChapter = $XPC->findnodes(
      '//osis:div[@type="book"][@osisID="'.$sourceP->{'bk'}.'"]//osis:hi[@subType="x-alternate"]'.
      '[preceding::osis:chapter[1][@sID="'.$sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'"]]'.
      '[following::osis:chapter[1][@eID="'.$sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'"]]' 
    , $xml);
    foreach my $alt (@altsInChapter) {
      if ($alt->textContent !~ /\b$v\b/) {next;}
      my $annotateRef = @{$XPC->findnodes('preceding::osis:verse[1][@sID]', $alt)}[0];
      if ($annotateRef) {my @tmp = split(/\s+/, $annotateRef->getAttribute('osisID')); $annotateRef = @tmp[-1];}
      if (!$annotateRef) {
        &ErrorBug("applyVsysFrom: Could not find verse containing $alt");
        last;
      }
      if (!$source2FromP->{'map'}{$a}) {
        &ErrorBug("applyVsysFrom: Verse $a not found in movedFrom $alt");
        last;
      }
      my $m = "<milestone type='$type' osisRef='".$source2FromP->{'map'}{$a}."' annotateRef='$annotateRef' annotateType='$annotateType'/>";
      $alt->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $alt);
      $success++;
      last;
    }
    if (!$success) {
      $note .= "[no alt verse $v]";
      my $verseEnd = &getVerseTag($a, $xml, 1);
      if ($verseEnd) {
        my $m = "<milestone type='$type' osisRef='".$source2FromP->{'map'}{$a}."' annotateRef='$a' annotateType='$annotateType'/>";
        $verseEnd->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $verseEnd);
        $success++;
      }
      else {&ErrorBug("applyVsysFrom: Verse was not found: $a");}
    }
    if (!$success) {&ErrorBug("applyVsysFrom: Couldn't mark verse $v");}
    else {$note .= "[milestone FROM $v]";}
  }
  
  &Note($note);
  return;
}

# This only adds milestone tags indicating where material in the source
# verse system is missing, or was moved to, with respect to the fixed 
# verse system.
sub applyVsysTo($$$) {
  my $valueP = shift;
  my $xml = shift;
  my $movedToP = shift;
  
  my $note = "[applyVsysFrom]";
  
  if ($valueP->{'isWholeChapter'}) {&ErrorBug("applyVsysTo: Not supported for entire chapters."); return $note;}
  
  for (my $v=$valueP->{'vs'}; $v<=$valueP->{'lv'}; $v++) {
    $note .= &writeMovedToMilestone($valueP->{'bk'}.".".$valueP->{'ch'}, $v, $xml, $movedToP, $valueP->{'isPartial'});
  }
  
  &Note($note);
  return;
}

# Insert milestone marker to record a missing verse and whether it was moved or not.
# The VerseID may not apply to an existing verse (since it's probably missing) so the
# next lowest verse end tag is used.
sub writeMovedToMilestone($$$$$) {
  my $bkch = shift;
  my $v = shift;
  my $xml = shift;
  my $movedToP = shift;
  my $isPartial = shift;
  
  my $verseID = "$bkch.$v";
  if ($movedToP && !$movedToP->{'map'}{$verseID.($isPartial ? '!PART':'')}) {
    &ErrorBug("writeMovedToMilestone: No source location for $verseID");
  }
  
  my $moveType = $VSYS{'prefix'}.($isPartial ? $VSYS{'partMovedTo'}:$VSYS{'movedto'});
  my $type = ($movedToP ? 
    'type="'.$moveType.'" annotateRef="'.$movedToP->{'map'}{$verseID.($isPartial ? '!PART':'')}.'" annotateType="'.$VSYS{'prefix'}.$VSYS{'AnnoTypeSource'}.'"' : 
    "type='".$VSYS{'prefix'}.$VSYS{'missing'}."'"
  );
  
  my $verseEndTag;
  do {
    $verseEndTag = &getVerseTag("$bkch.$v", $xml, 1);
    $v--;
  } while (!$verseEndTag && $v > 0);
  if (!$verseEndTag) {
    my @p = split(/\./, $bkch);
    $verseEndTag = &getVerseTag("$bkch.".&getFirstVerseInChapterOSIS(@p[0], @p[1], $xml), $xml, 1);
  }
  
  if ($verseEndTag) {
    $verseEndTag->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk("<milestone $type osisRef='$verseID'/>"), $verseEndTag);
  }
  else {&ErrorBug("writeMovedToMilestone: Starting verse tag not found for $verseID");}
  
  return "[milestone TO $v]";
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
  
  if ($valueP->{'isPartial'}) {
    &Note("Verse reference is partial, so only writing empty verse markers.");
    for (my $v = $vs; $v <= $lv; $v++) {
      my $a = "$bk.$ch.$v";
      &writeMovedToMilestone("$bk.$ch", $v, $xml, $movedToP, 1);
    }
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
      &writeMovedToMilestone("$bk.$ch", $v, $xml, $movedToP);
    }

    push(@missing, $verseTagToModify->getAttribute('osisID'));
    my $newOsisID = join(' ', &normalizeOsisID(\@missing));
    &Note("Changing verse osisID='".$verseTagToModify->getAttribute('osisID')."' to '$newOsisID'");
    $verseTagToModify = &toAlternate($verseTagToModify, 0, 1);
    $endTag = &toAlternate($endTag, 0, 1);
    $verseTagToModify->setAttribute('osisID', $newOsisID);
    $verseTagToModify->setAttribute('sID', $newOsisID);
    $endTag->setAttribute('eID', $newOsisID);
  }
  else {
    &ErrorBug("VSYS_MISSING($bk, $ch, $vs, $lv): An entire missing chapter is not supported.");
  }
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
  
  if ($valueP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  my $isWholeChapter = ($ch > @{$canonP->{$bk}} ? 1:$valueP->{'isWholeChapter'});
  
  # Handle the special case of an extra chapter (like Psalm 151)
  if ($ch > @{$canonP->{$bk}}) {
    if ($ch == (@{$canonP->{$bk}} + 1)) {
      my $lastv = &getLastVerseInChapterOSIS($bk, $ch, $xml);
      if ($vs != 1 || $lv != $lastv) {
        &Error("VSYS_EXTRA($bk, $ch, $vs, $lv): Cannot specify verses for a chapter outside the verse system.", "Use just '$bk.$ch' instead.");
      }
      $vs = 1;
      $lv = $lastv;
    }
    else {
      &ErrorBug("VSYS_EXTRA($bk, $ch, $vs, $lv): Not yet implemented (except when the extra chapter is the last chapter of the book).");
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
      &Note("This verse was moved, adjusting position: '$shift'.");
      my $newValueP = &readValue($bk.'.'.$ch.'.'.($vs+$shift).'.'.($valueP->{'isPartial'} ? 'PART':($lv+$shift)), $xml);
      &applyVsysExtra($newValueP, $canonP, $xml, &mapValue($newValueP, $movedFromP), 1);
      return;
    }
  }
  
  if (!$startTag || !$endTag) {
    &ErrorBug("VSYS_EXTRA($bk, $ch, $vs, $lv): Missing start-tag (=$startTag) or end-tag (=$endTag)");
    return;
  }
 
  # If isWholeChapter, then convert chapter tags to alterantes and add alternate chapter number
  if ($isWholeChapter) {
    my $chapLabel = @{$XPC->findnodes("//osis:title[\@type='x-chapterLabel'][not(\@canonical='true')][preceding::osis:chapter[\@osisID][1][\@sID='$bk.$ch'][not(preceding::osis:chapter[\@eID='$bk.$ch'])]]", $xml)}[0];
    if ($chapLabel) {
      &Note("Converting chapter label \"".$chapLabel->textContent."\" to alternate.");
      $chapLabel->setAttribute('type', 'x-chapterLabel-alternate');
      my $t = $chapLabel->textContent();
      &changeNodeText($chapLabel, '');
      my $alt = $XML_PARSER->parse_balanced_chunk("<hi type=\"italic\" subType=\"x-alternate\">$t</hi>");
      foreach my $chld ($chapLabel->childNodes) {$alt->insertAfter($chld, undef);}
      $chapLabel->insertAfter($alt, undef);
    }
    else {
      &Note("No chapter label was found, adding alternate chapter label \"$ch\".");
      my $alt = $XML_PARSER->parse_balanced_chunk("<title type=\"x-chapterLabel-alternate\"><hi type=\"italic\" subType=\"x-alternate\">$ch</hi></title>");
      my $chStart = @{$XPC->findnodes("//osis:chapter[\@osisID='$bk.$ch']", $xml)}[0];
      $chStart->parentNode()->insertAfter($alt, $chStart);
    }
    my $chEnd = &toAlternate(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0]);
    $chEnd->setAttribute('eID', "$bk.".($ch-1));
    &toAlternate(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0], 1);
    &toAlternate(@{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0], 1);
  }
  
  # If vs==1 and movedFromP then we need to add a marker to verse 1 even though the tag itself is not changed
  if ($vs == 1 && $movedFromP) {
    my $type = $VSYS{'prefix'}.$VSYS{'movedfrom'};
    my $annotateType = $VSYS{'prefix'}.$VSYS{'AnnoTypeSource'};
    my $m = "<milestone type='$type' osisRef='".$movedFromP->{'map'}{"$bk.$ch.1"}."' annotateRef='$bk.$ch.1' annotateType='$annotateType'/>";
    $startTag->parentNode->insertAfter($XML_PARSER->parse_balanced_chunk($m), $startTag);
  }
  
  # Convert verse tags between startTag and endTag to alternate verse numbers
  # But if there  are no in-between tags, then only modify the IDs.
  if ($startTag->getAttribute('sID') eq $endTag->getAttribute('eID')) {
    $startTag = &toAlternate($startTag, 0, 1, ($vs != 1 ? $movedFromP:0));
    my %ids; map($ids{$_}++, split(/\s+/, $startTag->getAttribute('osisID')));
    for (my $v = $vs; $v <= $lv; $v++) {if ($ids{"$bk.$ch.$v"}) {delete($ids{"$bk.$ch.$v"});}}
    my $newID = join(' ', &normalizeOsisID([ keys(%ids) ]));
    $startTag->setAttribute('osisID', $newID);
    $startTag->setAttribute('sID', $newID);
  }
  else {
    # (THIS FINDNODES METHOD IS ULTRA SLOW BUT WORKS)
    my $ns1 = '//osis:verse[@sID="'.$startTag->getAttribute('sID').'"]/following::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
    my $ns2 = '//osis:verse[@eID="'.$endTag->getAttribute('eID').'"]/preceding::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
    my @convert = $XPC->findnodes($ns1.'[count(.|'.$ns2.') = count('.$ns2.')]', $xml);
    foreach my $v (@convert) {&toAlternate($v, 1, 0, ($vs != 1 ? $movedFromP:0));}
  }
  # Also convert endTag to alternate and update eID 
  $endTag = &toAlternate($endTag);
  $endTag->setAttribute('eID', $startTag->getAttribute('sID'));
  
  # Following verses get decremented verse numbers plus an alternate verse number (unless isWholeChapter)
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
  
  my $note = "reVersify($bk, $ch, $vs, $count)";
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  if (!$vTagS) {$note .= "[Start tag not found]"; &Note($note); return;}
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  if (!$vTagE) {$note .= "[End tag not found]"; &Note($note); return;}
  
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
    $vTagS = &undoAlternate(&getAltID($vTagS, 1));
    $vTagE = &undoAlternate(&getAltID($vTagE, 1));
    $osisID = $vTagS->getAttribute('osisID');
  }
  else {$note .= "[Alternate verse already set]";}
  
  # Increment/Decrement
  if ($count) {
    if ($newID ne $osisID) {
      $note .= "[Changing verse osisID from ".$vTagS->getAttribute('osisID')." to $newID]";
      &osisIDCheckUnique($newVerseID, $xml);
      $vTagS->setAttribute('osisID', $newID);
      $vTagS->setAttribute('sID', $newID);
      $vTagS->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
      $vTagE->setAttribute('eID', $newID);
      $vTagE->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
    }
  }
  &Note($note); 
}

# This takes a verse or chapter element (start or end) and marks it as
# part of the alternate verse system, unless already done, by:
# 1) Converting it to a milestone element 
# 2) Cloning a target verse system element (unless noTarget is set)
# 3) Adding an alternate verse number if the element is verse-start (unless noAlt is set)
# This funtion returns the new target verse system element of #2.
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
  
  my $note = "toAlternate($osisID, ".$elem->nodeName.", $type)";
  
  if (&getAltID($elem)) {
    $note .= "[already done]";
    if ($noTarget && $elem->getAttribute('type') eq $VSYS{'prefix'}.$VSYS{'TypeModified'}) {
      $elem->unbindNode();
      $note .= "[removed target tag]";
    }
    &Note($note);
    return $elem;
  }
  
  if (!$noTarget) {
    $telem = $elem->cloneNode(1);
    if ($telem->getAttribute('type')) {&ErrorBug("Type already set on $telem");}
    $telem->setAttribute('type', $VSYS{'prefix'}.$VSYS{'TypeModified'});
    $elem->parentNode->insertBefore($telem, $elem);
    $note .= "[cloned]";
  }
  
  # Convert to milestone
  if (!$type) {
    &ErrorBug("Element missing sID or eID: $elem");
  }
  if ($type eq 'start' && $osisID ne $elem->getAttribute('osisID')) {
    &ErrorBug("osisID is different than sID: $osisID != ".$elem->getAttribute('osisID'));
  }
  $elem->setAttribute('type', $VSYS{'prefix'}.'-'.$elem->nodeName.$VSYS{$type});
  if ($type eq 'start' && $movedFromP) {
    my @vids;
    foreach my $v (split(/\s+/, $osisID)) {
      if (!$movedFromP->{'map'}{$v}) {&ErrorBug("No movedFrom mapped value for $v");}
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
  $note .= "[converted]";
  
  # Add alternate verse number
  if (!$noAlt && $isVerseStart) {
    if ($osisID =~ /^[^\.]+\.\d+\.(\d+)\b.*?(\.(\d+))?$/) {
      my $newv = ($2 ? "$1-$3":"$1");
      my $alt = $XML_PARSER->parse_balanced_chunk('<hi type="italic" subType="x-alternate"><hi type="super">('.$newv.')</hi></hi>');
      my $firstTextNode = @{$XPC->findnodes('following::text()[normalize-space()][1]', $elem)}[0];
      $firstTextNode->parentNode()->insertBefore($alt, $firstTextNode);
      $note .= "[added alternate verse \"$newv\"]";
    }
    else {&ErrorBug("Could not parse: $osisID =~ /^[^\.]+\.\d+\.(\d+)\b.*?(\.(\d+))?\$/");}
  }
  
  &Note($note);
  return $telem;
}

# This will take an alternate milestone element (verse or chapter, start 
# or end) and convert it back to original by undoing everything 
# toAlternate() did. It returns the original element.
sub undoAlternate($) {
  my $ms = shift;
  
  my $note = "undoAlternate(".$ms->getAttribute('type').', '.$ms->getAttribute('annotateRef').')';

  my $avn = @{$XPC->findnodes('following::text()[normalize-space()][1]/ancestor-or-self::*[name()="hi"][@subType="x-alternate"][1]', $ms)}[0];
  if ($avn) {
    $avn->unbindNode();
    $note .= "[removed alternate verse number]";
  }
  my $vtag = @{$XPC->findnodes('preceding-sibling::*[1][@type="'.$VSYS{'prefix'}.$VSYS{'TypeModified'}.'"]', $ms)}[0];
  if ($vtag) {
    $vtag->unbindNode();
    $note .= "[removed verse tag]";
  }
  my $chvsTypeRE = '^'.$VSYS{'prefix'}.'-(chapter|verse)('.$VSYS{'start'}.'|'.$VSYS{'end'}.')$'; $chvsTypeRE =~ s/-/\\-/g;
  if ($ms->getAttribute('type') =~ /$chvsTypeRE/) {
    my $name = $1; my $type = $2;
    $ms->setNodeName($name);
    if ($type eq '-start') {
      $ms->setAttribute('sID', $ms->getAttribute('annotateRef'));
      $ms->setAttribute('osisID', $ms->getAttribute('annotateRef'));
    }
    else {$ms->setAttribute('eID', $ms->getAttribute('annotateRef'));}
    $ms->removeAttribute('annotateRef');
    $ms->removeAttribute('annotateType');
    $ms->removeAttribute('type');
    if ($ms->hasAttribute('osisRef')) {$ms->removeAttribute('osisRef');}
  }
  else {&ErrorBug("Can't parse: ".$ms->getAttribute('type')." !~ /$chvsTypeRE/");}
  
  $note .= "[converted milestone to verse]";
  &Note($note);
  
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
      &ErrorBug("osisIDCheckUnique($osisID): Existing verse osisID=\"".$chv->getAttribute('osisID')."\" includes \"$v\"");
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
    &ErrorBug("getFirstVerseInChapterOSIS($bk, $ch): Could not find first verse.");
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
    &ErrorBug("getLastVerseInChapterOSIS($bk, $ch): Could not find last verse.");
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
  my $xml = shift;
  
  my $maxv = &getLastVerseInChapterOSIS($bk, $ch, $xml);

  my $haveVS = ($$vsP ? 1:0);
  $$vsP = ($haveVS ? $$vsP:1);
  $$lvP = ($$lvP ? $$lvP:($haveVS ? $$vsP:$maxv));

  return ($$vsP == 1 && $$lvP == $maxv);
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
