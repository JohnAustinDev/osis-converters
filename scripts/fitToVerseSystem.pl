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
# original verse system if ever needed.
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
# VSYS_MOVED:BK.1.2.3 -> BK.1.2.3
# Specifies that this translation has moved the verses that would be found 
# in range A of the target verse system to range B (ranges A and B must be
# the same size). It is processed as a "VSYS_MISSING:A" followed by a 
# "VSYS_EXTRA:B".
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
# chapters at the end of a book.

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

  &Log("\nOrdering books and peripherals of \"$osis\" by versification $vsys\n");

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

sub fitToVerseSystem($$) {
  my $osis = shift;
  my $vsys = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nFitting OSIS \"$osis\" to versification $vsys\n");

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &Log("ERROR: Not Fitting OSIS versification! No verse system.\n");
    return;
  }

  my $xml = $XML_PARSER->parse_file($osis);
 
  # Apply any alternate VSYS instructions to the translation
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
  
  &Log("\n$MOD REPORT: $errors verse system problems detected".($errors ? ':':'.')."\n");
  if ($errors) {
    &Log("
NOTE: This translation does not fit the $vsys verse system. The errors 
      listed above must be fixed. Add the appropriate instructions:
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED to CF_usfm2osis.txt 
      (see comments at the top of: ".__FILE__.".\n");
  }
  
  open(OUTF, ">$osis");
  print OUTF $xml->toString();
  close(OUTF);
}

# Read bibleMod and find all verse osisIDs which have been changed by  
# VSYS instructions. If there are any, then read the osis file, find all 
# osisRefs which point to those verse osisIDs that were changed, and 
# correct them by changing those osisRefs to point to the new osisID 
# values. It also updates the header scope value.
sub correctReferencesVSYS($$$) {
  my $osis = shift;
  my $bibleMod = shift;
  
  my $bfile = ($bibleMod eq $MOD ? $osis:&getProjectOsisFile($bibleMod));

  if (! -e $bfile) {
    &Log("\nWARNING: No OSIS Bible file was found. References effected by VSYS instructions will not be corrected!\n");
    return;
  }
  &Log("\n\nUpdating osisRef attributes of \"$bfile\" that require re-targeting after VSYS instructions:\n");
  
  my $count = 0;
  
  my $osisXML;
  my $bibleXML = $XML_PARSER->parse_file($bfile);
  my $vsys = &getVerseSystemOSIS($bibleXML);
  my @annotateRefs = $XPC->findnodes('//osis:milestone[@type="x-alt-verse-start"][@annotateRef]', $bibleXML);
  my @changedVerses;
  if (@annotateRefs[0]) {
    # Get a mapping from original verse system id to target verse-system id
    my %vmap;
    foreach my $ar (@annotateRefs) {
      my @oids = split(/\s+/, @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $ar)}[0]->getAttribute('osisID'));
      my @aids = split(/\s+/, $ar->getAttribute('annotateRef'));
      push(@changedVerses, @aids);
      foreach my $aid (@aids) {$vmap{$aid} = @oids[$#iods];}
    }
    @changedVerses = &normalizeOsisID(\@changedVerses, $vsys);

    # Look for osisRefs in the osis file that need updating and update them
    $osisXML = $XML_PARSER->parse_file($osis);
    my $lastch;
    my @checkrefs;
    foreach my $verse (@changedVerses) {
      $verse =~ /^(.*?)\.\d+$/;
      my $ch = $1;
      if (!$lastch || $lastch ne $ch) {
        # Select all elements having osisRef attributes EXCEPT those within crossReferences 
        # that already match the target verse-system. These should NOT be changed.
        @checkrefs = $XPC->findnodes("//*[contains(\@osisRef, '$ch')][not(ancestor::osis:note[\@type='crossReference'][contains(\@osisID, '!crossReference.r')])]", $osisXML);
      }
      $lastch = $ch;
      foreach my $e (@checkrefs) {
        my $changed = 0; # only write a rids attrib if there is a change
        my $rids = ($e->hasAttribute('rids') ? $e->getAttribute('rids'):&osisRef2osisID($e->getAttribute('osisRef')));
        my @everses = split(/\s+/, $rids);
        foreach my $ev (@everses) {
          if ($ev ne $verse) {next;}
          if ($vmap{$verse}) {
            $ev = "x.".$vmap{$verse};
            $changed++;
          }
          else {&Log("\nERROR: Could not map \"$verse\" to verse system!\n");}
        }
        if ($changed) {$e->setAttribute('rids', join(' ', @everses));}
      }
    }
    my @rids = $XPC->findnodes('//*[@rids]', $osisXML);
    foreach my $e (@rids) {
      my @rid = split(/\s+/, $e->getAttribute('rids'));
      $e->removeAttribute('rids');
      $e->setAttribute('annotateRef', $e->getAttribute('osisRef'));
      $e->setAttribute('annotateType', $ALT_VSYS_ARTYPE);
      foreach my $r (@rid) {$r =~ s/^x\.//;}
      my $newOsisRef = &osisID2osisRef(join(' ', &normalizeOsisID(\@rid, 'KJV')));
      if ($e->getAttribute('osisRef') ne $newOsisRef) {
        &Log("NOTE: Updating ".$e->nodeName." osisRef=\"".$e->getAttribute('osisRef')."\" to \"$newOsisRef\"\n");
        $e->setAttribute('osisRef', $newOsisRef);
        $count++;
      }
      else {&Log("ERROR: OsisRef change could not be applied!\n");}
    }
    
    my $scopeElement = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-bible"]]/osis:scope', $osisXML)}[0];
    if ($scopeElement) {&changeNodeText($scopeElement, &getScope($osisXML));}
  }
  
  if ($count) {
    if (open(OUTF, ">$osis")) {
      print OUTF $osisXML->toString();
      close(OUTF);
    }
    else {&Log("ERROR: Could not open \"$osis\" to write osisRef fixes!\n");}
  }
  
  &Log("\n$MOD REPORT: \"$count\" osisRefs were updated because of VSYS intructions.\n");
}

sub applyVsysInstruction(\%\@$) {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  
  my $inst = $argP->{'inst'};
  my $bk = $argP->{'bk'};
  my $ch = $argP->{'ch'};
  my $vs = $argP->{'vs'};
  my $lv = $argP->{'lv'};
  
  if ($inst eq 'MISSING') {&applyVsysMissing($bk, $ch, $vs, $lv, $canonP, $xml);}
  elsif ($inst eq 'EXTRA') {&applyVsysExtra($bk, $ch, $vs, $lv, $canonP, $xml);}
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
  my $canonP = shift;
  my $xml = shift;
  
  &Log("\nNOTE: Applying VSYS_MISSING($bk, $ch, $vs, $lv):\n");
  
  if (!&isWholeVsysChapter($bk, $ch, \$vs, \$lv, $canonP)) {
    my $count = (1 + $lv - $vs);
    
    # For any following verses, advance their verse numbers and add alternate verse numbers
    my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
    for (my $v=$lastV; $v>=$vs; $v--) {
      &reVersify($bk, $ch, $v, $count, $xml);
    }
    
    # Add the missing verses (by listing them in an existing osisID)
    my $verseTagToModify = &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):($vs+$count)), $xml, 0); # $vs was just changed to ($vs+$count)
    my @missing;
    for (my $v = $vs; $v <= $lv; $v++) {
      &osisIDCheckUnique("$bk.$ch.$v", $xml);
      push(@missing, "$bk.$ch.$v");
    }
    my $newOsisID = ($vs!=1 ? $verseTagToModify->getAttribute('osisID').' ':'').join(' ', @missing).($vs!=1 ? '':' '.$verseTagToModify->getAttribute('osisID'));
    &Log("NOTE: Changing verse osisID='".$verseTagToModify->getAttribute('osisID')."' to '$newOsisID'\n");
    my $endTag = @{$XPC->findnodes('//osis:verse[@eID="'.$verseTagToModify->getAttribute('sID').'"]', $xml)}[0];
    $verseTagToModify->setAttribute('osisID', $newOsisID);
    $verseTagToModify->setAttribute('sID', $newOsisID);
    $endTag->setAttribute('eID', $newOsisID);
  }
  else {
    &Log("ERROR: VSYS_MISSING($bk, $ch, $vs, $lv): An entire missing chapter is not supported.\n");
  }
}

# Used when the translation includes extra verses not found in the 
# target verse system. For extra verses, alternate verse numbers are 
# inserted and verse tags are converted into milestone elements. Then 
# they are enclosed within the proceding verse system verse. All 
# following verses in the chapter must be renumbered: they have 
# alternate verse numbers inserted and verse tags converted to milestone 
# elements, and they are enclosed by new verse tags which correspond to 
# their position in the target verse system.
sub applyVsysExtra($$$$$$$) {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $lv = shift;
  my $canonP = shift;
  my $xml = shift;
  my $adjusted = shift;
  
  &Log("\nNOTE: Applying VSYS_EXTRA($bk, $ch, $vs, $lv):\n");
  
  my $isWholeChapter = ($ch > @{$canonP->{$bk}} ? 1:&isWholeVsysChapter($bk, $ch, \$vs, \$lv, $canonP));
  
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
  my $vEndTag = (!$isWholeChapter && $vs==1 ? ($lv+1):$lv);
  my $endTag = &getVerseTag("$bk.$ch.$vEndTag", $xml, 1);
  
  # VSYS_EXTRA references the source verse system, which may have been
  # modified by previous instructions. So adjust our inputs in that case.
  if (!$adjusted && &getAltID($startTag) =~ /^[^\.]+\.\d+\.(\d+)\b/) {
    my $arv = $1;
    $startTag->getAttribute('osisID') =~ /^[^\.]+\.\d+\.(\d+)\b/;
    my $shift = ($1 - $arv);
    if ($shift) {
      &Log("NOTE: This verse was moved, adjusting position: '$shift'.\n");
      &applyVsysExtra($bk, $ch, ($vs+$shift), ($lv+$shift), $canonP, $xml, 1);
      return;
    }
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
  
  # Convert verse tags between startTag and endTag, add alternate verse numbers
  my $ns1 = '//osis:verse[@sID="'.$startTag->getAttribute('sID').'"]/following::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
  my $ns2 = '//osis:verse[@eID="'.$endTag->getAttribute('eID').'"]/preceding::osis:verse[ancestor::osis:div[@type="book"][@osisID="'.$bk.'"]]';
  my @convert = $XPC->findnodes($ns1.'[count(.|'.$ns2.') = count('.$ns2.')]', $xml);
  foreach my $v (@convert) {&toAlternate($v, 1);}
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
  
  &Log("NOTE: reVersify($bk, $ch, $vs, $count):\n");
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  if (!$vTagS) {&Log("\nERROR: reVersify($bk, $ch, $vs, $count): Start tag not found!\n"); return;}
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  if (!$vTagE) {&Log("\nERROR: reVersify($bk, $ch, $vs, $count): End tag not found!\n"); return;}
  
  my $osisID = $vTagS->getAttribute('osisID');
  my $newVerseID;
  my $newID;
  if ($count) {
    my @verses = split(/\s+/, $osisID);
    $newVerseID = "$bk.$ch.".($vs + $count);
    foreach my $v (@verses) {if ($v  eq "$bk.$ch.$vs") {$v = $newVerseID;}}
    $newID = join(' ', @verses);
  }
  
  if (!$vTagS->getAttribute('type') || $vTagS->getAttribute('type') ne $TARG_VSYS_ARTYPE) {
    $vTagS = &toAlternate($vTagS);
    $vTagE = &toAlternate($vTagE);
  }
  elsif (&getAltID($vTagS) eq $newID) {
    $vTagS = &undoAlternate(&getAltID($vTagS, 1));
    $vTagE = &undoAlternate(&getAltID($vTagE, 1));
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
      $vTagS->setAttribute('type', $TARG_VSYS_ARTYPE);
      $vTagE->setAttribute('eID', $newID);
      $vTagE->setAttribute('type', $TARG_VSYS_ARTYPE);
    }
  }
}

# Report an error if any verse in this hypothetical osisID is already listed 
# in an existing osisID (to catch multiple verse tags covering the same verses)
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
  
  my $ms = @{$XPC->findnodes("following::*[1][name()='milestone'][\@annotateType='$ALT_VSYS_ARTYPE']", $verseElem)}[0];
  if (!$ms) {return '';}
  return ($returnElem ? $ms:$ms->getAttribute('annotateRef'));
}

# This takes a verse or chapter element (start or end) and marks it as
# part of the alternate verse system, unless already done, by:
# 1) Converting it to a milestone element 
# 2) Cloning a target verse system element (unless noTarget is set)
# 3) Adding an alternate verse number if the element is verse-start 
# This funtion returns the new target verse system element (if any)
sub toAlternate($$) {
  my $elem = shift;
  my $noTarget = shift;
  
  my $telem;
  my $type = ($elem->getAttribute('sID') ? 'start':($elem->getAttribute('eID') ? 'end':''));
  my $osisID = ($type eq 'start' ? $elem->getAttribute('sID'):$elem->getAttribute('eID'));
  my $isVerseStart = ($type eq 'start' && $elem->nodeName eq 'verse' ? 1:0);
  
  &Log("NOTE: To alternate $osisID ".$elem->nodeName." $type");
  
  if (&getAltID($elem)) {
    &Log(", already done");
    if ($noTarget && $elem->getAttribute('type') eq $TARG_VSYS_ARTYPE) {
      $elem->unbindNode();
      &Log(", removed target tag");
    }
    &Log("\n");
    return $elem;
  }
  
  if (!$noTarget) {
    $telem = $elem->cloneNode(1);
    if ($telem->getAttribute('type')) {&Log("\nERROR: Type already set on $telem\n");}
    $telem->setAttribute('type', $TARG_VSYS_ARTYPE);
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
  $elem->setAttribute('type', "x-alt-".$elem->nodeName."-$type");
  $elem->setAttribute('annotateRef', $osisID);
  $elem->setAttribute('annotateType', $ALT_VSYS_ARTYPE);
  $elem->setNodeName('milestone');
  if ($elem->hasAttribute('osisID')) {$elem->removeAttribute('osisID');}
  if ($elem->hasAttribute('sID')) {$elem->removeAttribute('sID');}
  if ($elem->hasAttribute('eID')) {$elem->removeAttribute('eID');}
  &Log(", converted");
  
  # Add alternate verse number
  if ($isVerseStart) {
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
  my $vtag = @{$XPC->findnodes("preceding-sibling::*[1][\@type='$TARG_VSYS_ARTYPE']", $ms)}[0];
  if ($vtag) {
    $vtag->unbindNode();
    &Log(", removed verse tag");
  }
  if ($ms->getAttribute('type') =~ /^x\-alt\-(chapter|verse)\-(start|end)$/) {
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
  }
  else {&Log("\nERROR: Can't parse type=\"".$ms->getAttribute('type')."\"\n");}
  
  &Log(", converted milestone to verse\n");
  
  return $ms;
}

    
1;
