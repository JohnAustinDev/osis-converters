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

use strict;
our ($READLAYER, $APPENDLAYER, $WRITELAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR, $MOD_OUTDIR);
our (@VSYS_INSTR, %VSYS, $XPC, $XML_PARSER, $OSISBOOKSRE, $NT_BOOKS, 
    %ANNOTATE_TYPE, $VSYS_INSTR_RE, $VSYS_PINSTR_RE, $VSYS_SINSTR_RE, $VSYS_UNIVERSE_RE, 
    $SWORD_VERSE_SYSTEMS, $OSIS_NAMESPACE);

my $fitToVerseSystemDoc = "
------------------------------------------------------------------------
------------------------------------------------------------------------
OSIS-CONVERTERS VERSIFICATION INSTRUCTIONS:
The goal is to fit a source Bible translation having a custom verse 
system into a known fixed versification system so that every verse of 
the source system is identified according to the known system. Both the 
fixed and the source verse systems are recorded together in a single 
OSIS file. This process should be as easy as possible for the person 
running the conversion, so only differences between the source and fixed 
verse systems need to be identified, using the small set of instructions
described below. Then the Bible translation can be read from the OSIS
file having either the source or fixed verse system (using a simple 
XSLT) with all Scripture references being correct according to the 
chosen verse system.

IMPORTANT:
In the following descriptions, this:
BK.1.2.3
means this:
Bible book 'BK' chapter '1' verse '2' through '3', or, BK 1:2-3

VSYS_MOVED: BK.1.2.3 -> BK.4.5.6 (fixed -> source)
Specifies that this translation has moved the verses that would be found 
in a range of the fixed verse system to a different position in the 
source verse system, indicated by the range to the right of '->'. The 
two ranges must be the same size. The end verse portion of either range 
may be the keyword 'PART' (such as Gen.4.7.PART), meaning that the 
reference applies to only part of the specified verse. Furthermore the 
VSYS_MOVED instruction also updates the hyperlink targets of externally 
supplied Scripture cross-references so that they correctly point to 
their moved location in the source verse system, and updates internal 
Scripture cross-refernences so they correctly point to their fitted 
locations.

VSYS_EXTRA: BK.1.2.3 <- VERSIFICATION:BK.1.2.3 (source <- universal)
Specifies that the source verse system includes an extra range of verses 
which do not exist in the fixed verse system. The left side verse range 
specifies the extra verses in the source verse system, and the right 
side range is a universal address for those extra verses, which is only 
used to record where the extra verses originated from. So for the fitted 
verse system, the additional verse(s) will be converted to alternate 
verse(s) and appended to the preceding extant verse in the fixed verse 
system. Also, if there are any verses following the extra verses in the 
source verse system, then these will be renumbered downward by the 
number of extra verses, and alternate verse numbers will be appended to 
display their original verse number(s) in the source verse system. 
Additionally in the case of renumbered verses, externally supplied 
Scripture cross-reference to these verses are updated so as to be 
correct for both the source and fitted verse systems. The extra verse 
range may be an entire chapter if it occurs at the end of a book (like 
Psalm 151), in which case an alternate chapter number will be inserted 
and the entire extra chapter will be appended to the last verse of the 
previous extant chapter.

VSYS_CHAPTER_SPLIT_AT: BK.3.6 (fixed)
Specifies that this translation has split a chapter into two chapters.
Verses in the split chapter from the split onward will all be appended 
to the end of the previous verse and given alternate chapter:verse 
designations. The verses of all following chapters will be given alter-
nate chapter:verse designations as well. Like VSYS_MOVED, this instruc-
tion also updates the hyperlink targets of externally supplied Scripture 
cross-references so that they correctly point to their moved location in 
the source verse system, and updates internal Scripture cross-
refernences so they correctly point to their fitted locations.

VSYS_MOVED_ALT: BK.1.2.3 -> BK.4.5.6 (fixed -> source)
Similar to VSYS_MOVED but this should be used when alternate verse 
markup like '\\va 2\\va*' has been used by the translators for the 
verse numbers of the moved verses, rather than regular verse 
markers being used (which is the more common case). If both regular 
verse markers (showing the source system verse number) and alternate 
verse numbers (showing the fixed system verse numbers) have been used by 
the translators, then VSYS_MOVED should be used. This instruction will 
not change the OSIS markup of the alternate verses. It is the same as 
'VSYS_FROM_TO: A -> B'.

VSYS_MISSING: BK.1.2.3 (fixed)
Specifies that this translation does not include a range of verses of
the fixed verse system. So the fitted verse system will have the 
preceeding extant verse id modified to span the missing range, but in no 
case exceeding the end of a chapter. Any externally supplied cross-
references to the missing verses will then be removed. Also, if there 
are source verse(s) already sharing the verse number(s) of the missing 
verse(s), then the fixed verse system will have these, as well as any 
following verses in the chapter renumbered upward by the number of 
missing verses, and alternate verse numbers will be appended to them 
displaying their original source verse system number. Additionally in 
the case of renumbered verses, externally supplied Scripture cross-
reference to these verses are updated so as to be correct for both the 
source and fitted verse systems. An entire missing chapter is not 
currently supported unless it is the last chapter in a book.

VSYS_MISSING_FN: (fixed)
Similar to VSYS_MISSING but is only used if a footnote was included in 
the verse before the missing verse(s) which addresses the missing 
verse(s). This will simply link the verse having the footnote together 
with the missing verse, in the source verse system.

VSYS_EMPTY: BK.1.2.3 (fixed)
Use this if regular verse markers are included in the text, however the 
verses are left empty. This will just remove external Scripture 
cross-references to the removed verse(s).

VSYS_FROM_TO: BK.1.2.3 -> BK.4.5.6 (fixed -> source)
This does not effect any verse or alternate verse markup or locations. 
It only allows references in the source and fixed verse systems to have 
their addresses forwarded to their location in the fitted verse system 
and to each other. It also allows the human readable portion of external 
cross-references to be updated to their locations in the source verse 
system. It could be used if a verse is marked in the text but is left 
empty, while there is a footnote about it in the previous verse (but see 
VSYS_MISSING_FN which is the more common case). VSYS_FROM_TO is usually 
not the right instruction for most use cases; it is used most often 
internally.

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

my $verseSystemDoc = "
------------------------------------------------------------------------
------------------------------------------------------------------------
OSIS-CONVERTERS VERSIFICATION SYSTEM:
Special milestone markers are added to the OSIS file to facilitate 
reference mapping between the source, fixed and fitted verse systems:
source: The custom source verse system created by the translators. 
        Because it is a unique and customized verse system, by itself 
        there is no way to link its verses with external texts or 
        cross-references.
fixed:  A known, unchanging, verse system which is most similar to the 
        source verse system. Because it is a known verse system, its 
        verses can be linked to any other known external text or 
        cross-reference.
fitted: A fusion between the source and fixed verse systems arrived at 
        by applying OSIS-CONVERTERS VERSIFICATION INSTRUCTIONS. The 
        fitted verse system maintains the exact form of the custom verse 
        system, but also exactly fits within the fixed verse system. The
        resulting fitted verse system will have 'missing' verses or 
        'extra' alternate verses appended to the end of a verse if there 
        are differences between the source and fixed verse systems. 
        These differences usually represent moved, split, or joined 
        verses. The OSIS file can then be extracted in either the source 
        or the fixed verse system in such a way that all internal and  
        external reference hyperlinks are made correct and functional.
        
The fitted verse system requires that applicable reference links have 
two osisRef attributes, one for the fixed verse system (osisRef) and 
another for the source (annotateRef with annotateType = source). To 
facilitate this, the following maps are provided:
1) fixed2Source: Given a verse in the fixed verse system, get the id of 
   the source verse system verse which corresponds to it. This is needed 
   to map a readable externally supplied cross-reference in the fixed 
   verse system to the moved location in the source verse system. 
   Example: A fixed verse system cross-reference targets Romans 14:24, 
   but in the source verse system this verse is at Romans 16:25.
2) source2Fitted: Given a verse in the source verse system, get the id 
   of the fitted (fixed verse system) verse which contains it. This is 
   needed to map source references to their location in the fitted verse 
   system. Example: Source verse Rom.16.25 might correspond to a 
   different location in the fixed verse system, but in the fitted 
   (fixed) verse system it is appended to the end of Rom.16.24 (the last 
   verse of the fixed verse system's chapter).
3) fixed2Fitted: Given a verse in the fixed verse system, get the id of 
   the fitted (also a fixed verse system) verse which contains it. This  
   is used to map externally supplied cross-references for the fixed 
   verse system to their actual location in the fitted verse system. 
   Example: A fixed verse system cross-reference targets Rom.14.24, 
   but in the fitted OSIS file, this verse is appended to the end of 
   Rom.16.24. This is a convenience map since it is the same 
   as source2Fitted{fixed2Source{verse}}
4) missing: If a fixed verse system verse is left out of the translation
   and is not even included in a footnote, then there will be no cross
   references pointing to it.
------------------------------------------------------------------------
------------------------------------------------------------------------

";

# The following MAPs were taken from usfm2osis.py and apply to USFM 2.4
our %ID_TYPE_MAP = (
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
our %ID_TYPE_MAP_R = reverse %ID_TYPE_MAP;

our %PERIPH_TYPE_MAP = (
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
our %PERIPH_TYPE_MAP_R = reverse %PERIPH_TYPE_MAP;

our %PERIPH_SUBTYPE_MAP = (
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
our %PERIPH_SUBTYPE_MAP_R = reverse %PERIPH_SUBTYPE_MAP;

our %USFM_DEFAULT_PERIPH_TARGET = (
  'Cover|Title Page|Half Title Page|Promotional Page|Imprimatur|Publication Data|Table of Contents|Table of Abbreviations|Bible Introduction|Foreword|Preface|Chronology|Weights and Measures|Map Index' => 'place-according-to-scope',
  'Old Testament Introduction' => 'osis:div[@type="bookGroup"][1]/node()[1]',
  'NT Quotes from LXX' => 'osis:div[@type="bookGroup"][last()]/node()[1]',
  'Pentateuch Introduction' => 'osis:div[@type="book"][@osisID="Gen"]',
  'History Introduction' => 'osis:div[@type="book"][@osisID="Josh"]',
  'Poetry Introduction' => 'osis:div[@type="book"][@osisID="Ps"]',
  'Prophecy Introduction' => 'osis:div[@type="book"][@osisID="Isa"]',
  'New Testament Introduction' => 'osis:div[@type="bookGroup"][last()]/node()[1]',
  'Gospels Introduction' => 'osis:div[@type="book"][@osisID="Matt"]',
  'Acts Introduction' => 'osis:div[@type="book"][@osisID="Acts"]/node()[1]',
  'Letters Introduction' => 'osis:div[@type="book"][@osisID="Acts"]',
  'Deuterocanon Introduction' => 'osis:div[@type="book"][@osisID="Tob"]'
);

sub parseInstructionVSYS {
  my $t = shift;
  
  if ($t =~ /^VSYS_MISSING:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$value });
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>'' });
  }
  elsif ($t =~ /^VSYS_EXTRA:(?:\s*(?<to>$VSYS_INSTR_RE)\s*(?:<\-\s*(?<from>$VSYS_UNIVERSE_RE)\s*)?)?$/) {
    my $to = $+{to}; my $from = $+{from};
    push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
    if ($from) {
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'universal'=>$from, 'source'=>$to });
    }
  }
  elsif ($t =~ /^VSYS_FROM_TO:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
  }
  elsif ($t =~ /^VSYS_EMPTY:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>'' });
  }
  elsif ($t =~ /^VSYS_MOVED:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
    push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
  }
  elsif ($t =~ /^VSYS_MOVED_ALT:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
  }
  elsif ($t =~ /^VSYS_MISSING_FN:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    my $bk = $+{bk}; my $ch = $+{ch}; my $vs = $+{vs}; my $lv = ($+{lv} ? $+{lv}:$+{vs});
    my $msg = "VSYS_MISSING_FN is used when a previous verse holds a footnote about the missing verse.";
    if ($vs > 1) {
      push(@VSYS_INSTR, { 'inst'=>'VTAG_MISSING', 'fixed'=>$value, 'source'=>"$bk.$ch.".($vs-1).'.PART' });
    }
    else {&Error("VSYS_MISSING_FN cannot be used with verse $vs: $t", "$msg Use different instruction(s) in CF_usfm2osis.txt.");}
  }
  elsif ($t =~ /^VSYS_CHAPTER_SPLIT_AT:(?:\s*(?<val>$VSYS_SINSTR_RE)\s*)?$/) {
    my $value = $+{val};
    my $bk = $+{bk}; my $ch = $+{ch}; my $vs = $+{vs};
    push(@VSYS_INSTR, { 'inst'=>'CHAPTER_SPLIT_AT', 'fixed'=>$value });
  }
  
  return @VSYS_INSTR;
}

sub vsysInstSort {
  my $a = shift;
  my $b = shift;
  
  my $r;
  
  # EXTRA applies to source, while all others (which the exception of  
  # FROM_TO) apply to fixed, so process EXTRA first.
  my @order = ('EXTRA', 'MISSING', 'CHAPTER_SPLIT_AT', 'VTAG_MISSING', 'FROM_TO');

  # order by instruction type
  my $ai; for ($ai=0; $ai<@order; $ai++) {if (@order[$ai] eq $a->{'inst'}) {last;}}
  my $bi; for ($bi=0; $bi<@order; $bi++) {if (@order[$bi] eq $b->{'inst'}) {last;}}
  if ($ai == @order || $bi == @order) {
    &ErrorBug("Unknown VSYS sub-instruction: '".$a->{'inst'}."' or '".$b->{'inst'}."'");
  }
  $r = $ai <=> $bi;
  if ($r) {return $r;}
  
  # otherwise use verse system order (using source if present otherwise fixed)
  my $av = ($a->{'source'} ? $a->{'source'}:$a->{'fixed'});
  my $bv = ($b->{'source'} ? $b->{'source'}:$b->{'fixed'});
  $av =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $av2 = ($2 ? (1*$3):0);
  $bv =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $bv2 = ($2 ? (1*$3):0);
  $r = &osisIDSort($av, $bv);
  if ($r) {return $r;}
  
  # otherwise by last verse
  $r = $av2 <=> $bv2;
  if ($r) {return $r;}

  if (!$r) {
    &ErrorBug("Indeterminent VSYS instruction sort: av=$av, bv=$bv, ai=$ai, bi=$bi");
  }
  return $r;
}

sub orderBooks {
  my $osisP = shift;
  my $vsys = shift;
  my $maintainBookOrder = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nOrdering books of \"$$osisP\" by versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Cannot re-order books in OSIS file because getCanon($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);

  # remove all books
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bk (@books) {$bk->unbindNode();}

  # remove all peripheral file divs for now
  my @xpath;
  foreach my $type (values(%ID_TYPE_MAP)) {
    push(@xpath, '//osis:div[@type="'.$type.'"][not(@subType)]');
  }
  my @idDivs = $XPC->findnodes(join('|', @xpath), $xml);
  foreach my $idDiv (@idDivs) {$idDiv->unbindNode();}
  
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
    if ($bk ne '') {
      if ($bk->getAttribute('osisID') =~ /($OSISBOOKSRE)/i) {
        &Error("Book \"".$bk->getAttribute('osisID')."\" occurred multiple times, so one instance was dropped!", "CF_usfm2osis.txt may have RUN this book multiple times.");
      }
      else {
        &Error("Book \"".$bk->getAttribute('osisID')."\" was not found in $vsys Canon, so it was dropped!", "The id tag of the book's source SFM file may be incorrect.");
      }
    }
  }
  
  foreach my $bookGroup (@bookGroups) {
    if (!$bookGroup->hasChildNodes()) {$bookGroup->unbindNode();}
  }
  
  # Replace all periphs after the header (they still need to be marked and ordered later)
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  foreach my $idDiv (reverse @idDivs) {$header->parentNode->insertAfter($idDiv, $header);}
  
  &writeXMLFile($xml, $osisP);
}

sub applyVsysMissingVTagInstructions {
  my $osisP = shift;
  
  my $update;
  foreach my $argsP (@VSYS_INSTR) {
    if ($argsP->{'inst'} eq 'VTAG_MISSING') {$update++;}
  }
  if (!$update) {return;}
  
  &Log("\nApplying VSYS_MISSING_FN instructions to \"$$osisP\"\n", 1);
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  foreach my $argsP (@VSYS_INSTR) {
    if ($argsP->{'inst'} eq 'VTAG_MISSING') {
      &applyVsysMissingVTag($argsP, $xml);
    }
  }
  
  &writeXMLFile($xml, $osisP);
}

# Update an osis file's internal (source) and external (fixed) osisRefs 
# to the fitted verse system.
sub correctReferencesVSYS {
  my $osisP = shift;
  
  my $in_bible = ($INPD eq $MAININPD ? $$osisP:&getModuleOsisFile($MAINMOD));
  if (! -e $in_bible) {
    &Warn("No OSIS Bible file was found. References effected by VSYS instructions will not be corrected.");
    return;
  }
  &Log("\n\nUpdating osisRef attributes of \"$$osisP\" that require re-targeting after VSYS instructions:\n", 1);
  
  my $altVersesOSISP = &getAltVersesOSIS($XML_PARSER->parse_file($in_bible));
  
  # Process the OSIS file book-by-book for speed
  my ($count, %logH, $logn);
  foreach my $osisbk (&splitOSIS($$osisP)) {
    my $osisXML = $XML_PARSER->parse_file($osisbk);
    my $bkid = @{$XPC->findnodes('//osis:div[@type="book"][1]', $osisXML)}[0];
    if ($bkid) {&Log($bkid->getAttribute('osisID'), 2);}
    my $name_osisXML = &getModNameOSIS($osisXML);
    my @existing = $XPC->findnodes('//osis:reference[@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"][@annotateRef][@osisRef]', $osisXML);
    if (@existing) {next;}

    # Fill a hash table with every element that has an osisRef attribute,
    # except for x-vsys type elements. This technique provides a big 
    # speedup. The internal origin is for elements originating in the  
    # source text. The external origin is for elements originating outside 
    # the source text (which have the fixed verse system).
    my %elems;
    &Log(", finding osisRefs", 2);
    foreach my $e (@{$XPC->findnodes('//*[@osisRef]
        [not(starts-with(@type, "'.$VSYS{'prefix_vs'}.'"))]', $osisXML)}) 
    {
      my $origin = (
        @{$XPC->findnodes('ancestor-or-self::osis:note[@type="crossReference"][@resp]', $e)}[0] ? 
        'external':'internal'
      );
      my $ids = &osisRef2osisID($e->getAttribute('osisRef'), $name_osisXML, 'always');
      foreach my $id (split(/\s+/, $ids)) {
        my $w = ($id =~ s/^([^:]+):// ? $1:'');
        if ($w ne $MAINMOD) {next;}
        push(@{$elems{$id}{$origin}}, $e);
      }
    }
    
    &Log(", mapping osisRefs", 2);
    
    # Perform each mapping function on the applicable elements
    my @maps = ('source2Fitted', 'fixed2Fitted', 'fixed2Source', 'fixedMissing');
    # A hash is used for temporary attributes rather than actual element 
    # attributes in the tree, which buys another speedup.
    my %attribs; 
    foreach my $m (@maps) {
      foreach my $idmap (&normalizeOsisID([ sort keys(%{$altVersesOSISP->{$m}}) ])) {
        my $id = $idmap; $id =~ s/\.PART$//;
        my $origin = ($m =~ /^fixed/ ? 'external':'internal');
        foreach my $e (@{$elems{$id}{$origin}}) {
          my $eky = $e->unique_key;
          if (!defined($attribs{$eky})) {
            my $ids = &osisRef2osisID($e->getAttribute('osisRef'), $MAINMOD, 'not-default');
            $attribs{$eky}{'self'} = $e;
            $attribs{$eky}{'origin'} = $origin;
            $attribs{$eky}{'osisRefFrom'} = $ids;
            $attribs{$eky}{'osisRefTo'} = '';
            $attribs{$eky}{'annotateRefFrom'} = $ids;
            $attribs{$eky}{'annotateRefTo'} = '';
            $attribs{$eky}{'order'} = sprintf('%07i', $logn++);
          }
          # map each id segment one at a time
          my $attrib = ($m eq 'fixed2Source' ? 'annotateRef':'osisRef');
          &attribFromTo($attrib, \%{$attribs{$eky}}, $idmap, $altVersesOSISP->{$m}{$idmap});
          # in addition, apply fixedMissing to annotateRef (as well as to osisRef) 
          if ($m eq 'fixedMissing') {
            &attribFromTo('annotateRef', \%{$attribs{$eky}}, $idmap, $altVersesOSISP->{$m}{$idmap});
          }
        }
      }
    }
    #use Data::Dumper; &Debug("attribs = ".Dumper(\%attribs)."\n", 1);
    
    $count += &applyMaps(\%attribs, $name_osisXML, \%logH);

    &writeXMLFile($osisXML, $osisbk);
  }
  &joinOSIS($osisP);
  
  # Logging these with a sorted hash so reports are in OSIS order
  my ($update, $remove);
  foreach my $k (sort keys %logH) {
    if (defined($logH{$k}{'update'})) {$update .= $logH{$k}{'update'};}
    if (defined($logH{$k}{'remove'})) {$remove .= $logH{$k}{'remove'};}
  }
  if ($update) {&Note("\n$update");}
  if ($remove) {&Note("\n$remove");}
    
  &Report("\"$count\" osisRefs were corrected to account for differences between source and fixed verse systems.");
}

sub attribFromTo {
  my $attrib = shift;
  my $attribHP = shift;
  my $id = shift;
  my $to = shift;
  
  if ($id !~ s/\!PART$//) {
    $attribHP->{$attrib.'From'} = &removeSeg($attribHP->{$attrib.'From'}, $id);
  }
  
  if ($to) {
    $to =~ s/\!PART$//;
    $attribHP->{$attrib.'To'} = &addSeg($attribHP->{$attrib.'To'}, $to);
  }
}

sub removeSeg {
  my $id = shift;
  my $seg = shift;
  
  my @segs;
  foreach my $s (split(/\s+/, $id)) {
    if ($s eq $seg) {next;}
    push(@segs, $s);
  }
  
  return join(' ', @segs);
}

sub addSeg {
  my $id = shift;
  my $seg = shift;
  
  my @segs = split(/\s+/, $id);
  if ($seg) {push (@segs, $seg);}
  
  return join(' ', @segs);
}

sub applyMaps {
  my $attribsHP = shift;
  my $modname = shift;
  my $logHP = shift;
  
  &Log(", applying maps\n", 2);
  
  my $count = 0;
  foreach my $eky (sort keys %{$attribsHP}) {
    my $e = $attribsHP->{$eky}{'self'};

    # get new values for permanent attributes
    our ($osisRef, $annotateRef); # symbolic references must be globals
    foreach my $a ('osisRef', 'annotateRef') {
      my @segs;
      my $value = $attribsHP->{$eky}{$a.'From'}.' '.$attribsHP->{$eky}{$a.'To'};
      push(@segs, (split(/\s+/, $value)));
      my $x1 = join(' ', &normalizeOsisID(\@segs, $MAINMOD, 'not-default'));
      my $x2 = &osisID2osisRef($x1);
      no strict "refs";
      $$a = &fillGapsInOsisRef($x2);
    }
    
    # don't keep references to missing verses (which would be broken)
    if (!$annotateRef || !$osisRef) {
      $logHP->{ $attribsHP->{$eky}{'order'} }{'remove'} = 
        &removeMappedElement($e, $attribsHP->{$eky}{'origin'});
      next;
    }
    
    if ($modname ne $MAINMOD) {
      $osisRef     = "$MAINMOD:$osisRef";
      $annotateRef = "$MAINMOD:$annotateRef";
    }
   
    if ($e->getAttribute('osisRef') eq $osisRef && $osisRef eq $annotateRef) {
      next;
    }
    
    $count++;
    
    $logHP->{ $attribsHP->{$eky}{'order'} }{'update'} = sprintf(
      "UPDATING %s %-10s osisRef: %32s -> %-32s annotateRef: %-32s\n", 
      $attribsHP->{$eky}{'origin'}, 
      $e->nodeName, 
      $e->getAttribute('osisRef'), 
      $osisRef, 
      $annotateRef
    );
    $e->setAttribute('osisRef', $osisRef);
    $e->setAttribute('annotateRef', $annotateRef);
    $e->setAttribute('annotateType', $ANNOTATE_TYPE{'Source'});
  }
  
  return $count;
}

sub removeMappedElement {
  my $e = shift;
  my $origin = shift;
  
  my $delete = ($origin eq 'external');
  my $tag = $e->toString(); $tag =~ s/^(<[^>]*>).*?$/$1/s;
  
  my $msg = '';
  if ($delete) {
    $msg = "DELETING $origin ".$e->nodeName.", because osisRef targets missing verse: $tag\n";
  }
  else {
    $msg = "REMOVING tags for $origin ".$e->nodeName.", because osisRef targets missing verse: $tag \n";
    foreach my $chld ($e->childNodes) {$e->parentNode()->insertBefore($chld, $e);}
  }
  $e->unbindNode();
  
  return $msg;
}

sub getAltVersesOSIS {
  my $mod = &getModNameOSIS(shift);
  
  our %DOCUMENT_CACHE;
  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    &ErrorBug("getAltVersesOSIS: No xml document node!");
    return '';
  }
  
  if (!$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}) {
    $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'exists'}++;
    &Debug("Cache failed for getAltVersesOSIS: $mod\n");
    
    # VSYS changes are recorded in the OSIS file with milestone elements written by applyVsysFromTo()
    my @maps = (
      ['fixed2Source',  'movedto_vs', 'osisRef',     'annotateRef'],
      ['fixedMissing',  'missing_vs', 'osisRef',     ''],
      ['source2Fitted', 'fitted_vs',  'annotateRef', 'osisRef'],
    );
    foreach my $map (@maps) {
      my %hash;
      foreach my $e ($XPC->findnodes('//osis:milestone[@type="'.$VSYS{@$map[1]}.'"]', $xml)) {
        $hash{$e->getAttribute(@$map[2])} = (@$map[3] ? $e->getAttribute(@$map[3]):'');
      }
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{@$map[0]} = \%hash;
    }
    
    # fixed2Fitted is a convenience map since it is the same as source2Fitted{fixed2Source{verse}}
    foreach my $fixed (sort keys (%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}})) {
      my $source = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}{$fixed};
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Fitted'}{$fixed} = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'source2Fitted'}{$source};
    }
    
    use Data::Dumper; &Debug("getAltVersesOSIS = ".Dumper(\%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}})."\n", 1);
  }
  
  return \%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}};
}

sub fitToVerseSystem {
  my $osisP = shift;
  my $vsys = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nFitting OSIS \"$$osisP\" to versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Not Fitting OSIS versification because getCanon($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);
  
  # Check if this osis file has already been fitted, and bail if so
  my @existing = $XPC->findnodes('//osis:milestone[@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"]', $xml);
  if (@existing) {
    &Warn("
There are ".@existing." fitted tags in the text. This OSIS file has 
already been fitted so this step will be skipped!");
  }
  elsif (@VSYS_INSTR) {
  
    # Mark alternate verse numbers which represent the fitted verse system so they can be removed when using the fitted OSIS file
    foreach my $a ($XPC->findnodes('//osis:hi[@subType="x-alternate"]', $xml)) {
      my $prevVerseFirstTextNode = @{$XPC->findnodes('preceding::osis:verse[@sID][1]/following::text()[normalize-space()][1]', $a)}[0];
      my $myTextNode = @{$XPC->findnodes('descendant::text()[normalize-space()][1]', $a)}[0];
      if (!$prevVerseFirstTextNode || !$myTextNode || 
          $prevVerseFirstTextNode->unique_key ne $myTextNode->unique_key) {next;}
      $a->setAttribute('subType', $VSYS{'fixed_altvs'});
    }
    
    # Apply VSYS instructions to the translation
    foreach my $argsP (@VSYS_INSTR) {
      if ($argsP->{'inst'} eq 'VTAG_MISSING') {next;}
      &applyVsysInstruction($argsP, $canonP, $xml);
    }
    
    # Update scope in the OSIS file
    my $scopeElement = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-bible"]]/osis:scope', $xml)}[0];
    if ($scopeElement) {&changeNodeText($scopeElement, &getScope($xml));}
    
    &writeXMLFile($xml, $osisP);
    $xml = $XML_PARSER->parse_file($$osisP);
  }
  
  # Warn that these alternate verse tags in source could require further VSYS intructions
  my @nakedAltTags = $XPC->findnodes('//osis:hi[@subType="x-alternate"]
    [ not(preceding::*[1][self::osis:milestone[starts-with(@type, "'.$VSYS{'prefix_vs'}.'")]]) ]', $xml);
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
}

sub checkVerseSystem {
  my $bibleosis = shift;
  my $vsys = shift;
  
  my $xml = $XML_PARSER->parse_file($bibleosis);
  
  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Leaving checkVerseSystem() because getCanon($vsys) failed.");
    return;
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
          &errMissingVerse("$bk.$ch", $vs, $vmax);
          $fitToVerseSystemDoc = '';
          $errors++;
          next;
        }
        @v[$x] =~/\.(\d+)\s*$/; $vs = ($1*1);
        $x++;
      }
      while (@v[$x] =~ /^\Q$bk.$ch./) {
        &Error("Extra verse: ".@v[$x], 
"This often happens when a verse was split into two verses 
somewhere within the chapter. This situation can be addressed in 
CF_usfm2osis.txt with something like: 
VSYS_MOVED: Gen.2.3.PART -> Gen.2.4\n$fitToVerseSystemDoc");
        $fitToVerseSystemDoc = '';
        $errors++;
        $x++;
      }
      $ch++;
    }
    while (@v[$x] =~ /^\Q$bk./) {
      &Error("Extra chapter: ".@v[$x], 
"This happens for instance when Synodal Pslam 151 is 
included in a SynodalProt translation. This situation can be addressed 
in CF_usfm2osis.txt with something like: 
VSYS_EXTRA: Ps.151 <- Synodal:Ps.151\n$fitToVerseSystemDoc");
      $fitToVerseSystemDoc = '';
      $errors++;
      $x++;
    }
  }
  if ($x == @v) {&Log("\n"); &Note("All verses were checked against verse system $vsys.");}
  else {&Log("\n"); &ErrorBug("Problem checking chapters and verses in verse system $vsys (stopped at $x of @v verses: ".@v[$x].")");}
  
  &Report("$errors verse system problems detected".($errors ? ':':'.'));
  if ($errors) {
    &Note("
      This translation does not fit the $vsys verse system. The errors 
      listed above must be fixed. Add the appropriate instructions:
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED to CF_usfm2osis.txt. $fitToVerseSystemDoc");
    $fitToVerseSystemDoc = '';
  }
}

sub errMissingVerse {
  my $bkch = shift;
  my $vs = shift;
  my $lastVerseInChapter = shift;
  
  my $fixes = 
"possible cause of this error is a verse that has been left out
on purpose. Often there is a related footnote at the end of the previous 
verse which sometimes contains the text of the missing verse. This 
situation can be addressed with:
VSYS_MISSING_FN: $bkch.$vs
But, if there is no footnote and a verse (or verses) have been left out, 
this can be addressed with:
VSYS_MISSING: $bkch.$vs";
  
  if ($vs == $lastVerseInChapter) {
  &Error("Missing verse $bkch.$vs.", 
"Because this is the last verse of a chapter, it is likely 
that multiple verses are joined into a single verse somewhere within the 
chapter. Such a situation can be addressed in CF_usfm2osis.txt with 
something like: 
VSYS_MOVED: $bkch.4 -> $bkch.3.PART\nAnother $fixes\n$fitToVerseSystemDoc");
  }
  else {&Error("Missing verse $bkch.$vs.", "A $fixes\n$fitToVerseSystemDoc");}
}

sub applyVsysInstruction {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  
  &Log("\nVSYS_".$argP->{'inst'}.": fixed=".$argP->{'fixed'}.", source=".$argP->{'source'}.($argP->{'universal'} ? ", universal=".$argP->{'universal'}:'')."\n");

  my $inst = $argP->{'inst'};
  
  # NOTE: 'fixed' always refers to a known fixed verse system, 
  # and 'source' always refers to the customized source verse system
  my $sourceP = ''; my $fixedP = '';
  if ($argP->{'source'}) {
    $sourceP = &parseVsysArgument($argP->{'source'},    $xml, 'source');
  }
  if ($argP->{'fixed'}) {
    $fixedP  = &parseVsysArgument($argP->{'fixed'},     $xml, 'fixed');
  }
  elsif ($argP->{'universal'}) {
    $fixedP  = &parseVsysArgument($argP->{'universal'}, $xml, 'universal');
  }
  
  if ($fixedP && $sourceP && $fixedP->{'count'} != $sourceP->{'count'}) {
    &Error("'From' and 'To' are a different number of verses: $inst: $argP->{'fixed'}($fixedP->{'count'}) -> $argP->{'source'}($sourceP->{'count'})");
    return 0;
  }
  
  if ($sourceP && $sourceP->{'bk'} && !&getBooksOSIS($xml)->{$sourceP->{'bk'}}) {
    &Warn("Skipping VSYS_$inst because ".$sourceP->{'bk'}." is not in the OSIS file.", "Is this instruction correct?");
    return 0;
  }
  
  if    ($inst eq 'MISSING') {&applyVsysMissing($fixedP, $xml);}
  elsif ($inst eq 'EXTRA')   {&applyVsysExtra($sourceP, $canonP, $xml);}
  elsif ($inst eq 'FROM_TO') {&applyVsysFromTo($fixedP, $sourceP, $xml);}
  elsif ($inst eq 'CHAPTER_SPLIT_AT') {&applyVsysChapterSplitAt($fixedP, $xml);}
  else {&ErrorBug("applyVsysInstruction did nothing: $inst");}
  
  return 1;
}

sub parseVsysArgument {
  my $value = shift;
  my $xml = shift;
  my $vsysType = shift;
  
  my %data;
  $data{'value'} = $value;

  # read and preprocess value
  my $bk; my $ch; my $vs; my $lv;
  if ($vsysType eq 'universal') {
    if ($value !~ /^$VSYS_UNIVERSE_RE$/) {
      &ErrorBug("parseVsysArgument: Could not parse universal: $value !~ /^$VSYS_UNIVERSE_RE\$/");
      return \%data;
    }
    $data{'vsys'} = $1;
    $bk = $2; $ch = $3; 
    if (defined($4)) {$vs = $5;}
    if (defined($5)) {$lv = $7;}
    if ($data{'vsys'} !~ /^($SWORD_VERSE_SYSTEMS)$/) {
      &Error("parseVsysArgument: Unrecognized verse system: '".$data{'vsys'}."'", "Use a recognized SWORD verse system: $SWORD_VERSE_SYSTEMS");
    }
  }
  else {
    if ($value !~ /^$VSYS_PINSTR_RE$/) {
      &ErrorBug("parseVsysArgument: Could not parse: $value !~ /^$VSYS_PINSTR_RE\$/");
      return \%data;
    }
    $data{'vsys'} = ($vsysType eq 'source' ? 'source':($vsysType eq 'fixed' ? &getVerseSystemOSIS($xml):''));
    $bk = $1; $ch = $2;
    if (defined($3)) {$vs = $4;}
    if (defined($5)) {$lv = $6;}
  }
  
  $data{'isPartial'} = ($lv =~ s/^PART$/$vs/ ? 1:0);
  $data{'isWholeChapter'} = &isWholeVsysChapter($bk, $ch, \$vs, \$lv, $xml);
  $data{'bk'} = $bk;
  $data{'ch'} = (defined($ch) ? (1*$ch) : undef);
  $data{'vs'} = (defined($vs) ? (1*$vs) : undef);
  $data{'lv'} = (defined($lv) ? (1*$lv) : $vs);
  $data{'count'} = 1 + (defined($data{'vs'}) ? ($data{'lv'} - $data{'vs'}):-1);
  
  return \%data
}

# This does not modify any verse tags. It only inserts milestone markers
# which later can be used to map Scripture references between the source
# and known fixed verse systems. For all VSYS markup, osisRef always 
# refers to the xml file's fixed verse system. But annotateRef may refer 
# to a source verse system osisID or to a universal address (depending 
# on annotateType = x-vsys-source or x-vsys-universal). 
# Types of milestones inserted are:
# $VSYS{'movedto_vs'}, $VSYS{'missing_vs'}, $VSYS{'extra_vs'} and $VSYS{'fitted_vs'} 
sub applyVsysFromTo {
  my $fixedP = shift;
  my $sourceP = shift;
  my $xml = shift;
  
  if (!$fixedP) {
    &ErrorBug("applyVsysFromTo fixedP should not be empty");
    return;
  }
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'}; my $lv = $fixedP->{'lv'};
  
  my $note = "";
  
  # If the fixed vsys is universal (different than $xml) then just insert 
  # extra_vs and fitted_vs marker(s) after the element(s) and return
  if ('Bible.'.$fixedP->{'vsys'} ne &getRefSystemOSIS($xml)) {
    if ($sourceP->{'isWholeChapter'}) {
      my $xpath = '//*
        [@type="'.$VSYS{'prefix_vs'}.'-chapter'.$VSYS{'end_vs'}.'"]
        [@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"]
        [@annotateRef="'.$sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'"][1]';
      my $sch = @{$XPC->findnodes($xpath, $xml)}[0];
      if ($sch) {
        my $osisID = @{$XPC->findnodes('./preceding::osis:verse[@sID][1]', $sch)}[0];
        if (!$osisID) {&ErrorBug("Could not find enclosing verse for element:\n".$sch);}
        else {$osisID = $osisID->getAttribute('osisID');}
        my $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                  'resp="'.$VSYS{'resp_vs'}.'" ' .
                  'type="'.$VSYS{'extra_vs'}.'" '.
                  'annotateRef="'.$fixedP->{'value'}.'" ' .
                  'annotateType="'.$ANNOTATE_TYPE{'Universal'}.'" />'.
                '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                  'resp="'.$VSYS{'resp_vs'}.'" ' .
                  'type="'.$VSYS{'fitted_vs'}.'" '.
                  'osisRef="'.$osisID.'" ' .
                  'annotateRef="'.$sourceP->{'value'}.'" ' .
                  'annotateType="'.$ANNOTATE_TYPE{'Source'}.'" />';
        $sch->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $sch);
        $note .= "[extra_vs chapter ".$sourceP->{'ch'}."][fitted_vs chapter ".$sourceP->{'ch'}."]";
      }
      else {&ErrorBug("Could not find source element:\n$xpath");}
    }
    else {
      for (my $v=$sourceP->{'vs'}; $v<=$sourceP->{'lv'}; $v++) {
        my $sourcevs = $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.$v;
        my $svs = &getSourceVerseTag($sourcevs, $xml, 1);
        if ($svs) {
          my $osisID = @{$XPC->findnodes('./preceding::osis:verse[@sID][1]', $svs)}[0];
          if (!$osisID) {&ErrorBug("Could not find enclosing verse for source verse: ".$sourcevs);}
          else {$osisID = $osisID->getAttribute('osisID'); $osisID =~ s/^.*\s+//;}
          my $univref = $fixedP->{'vsys'}.':'.$fixedP->{'bk'}.'.'.$fixedP->{'ch'}.'.'.($fixedP->{'vs'} + $v - $sourceP->{'vs'});
          my $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                    'resp="'.$VSYS{'resp_vs'}.'" ' .
                    'type="'.$VSYS{'extra_vs'}.'" '.
                    'annotateRef="'.$univref.'" ' .
                    'annotateType="'.$ANNOTATE_TYPE{'Universal'}.'" />'.
                  '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                    'resp="'.$VSYS{'resp_vs'}.'" ' .
                    'type="'.$VSYS{'fitted_vs'}.'" '.
                    'osisRef="'.$osisID.'" ' .
                    'annotateRef="'.$sourceP->{'value'}.'" ' .
                    'annotateType="'.$ANNOTATE_TYPE{'Source'}.'" />';
          $svs->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $svs);
          $note .= "[extra_vs verse $v][fitted_vs verse $v]";
        }
        else {&ErrorBug("Could not find source verse: $sourcevs");}
      }
    }
    &Note("universal vsys ".$fixedP->{'vsys'}.":$note");
    
    return;
  }
  
  for (my $v=$vs; $v<=$lv; $v++) {
    my $baseAnnotateRef = ($sourceP ? $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.($sourceP->{'vs'} + $v - $vs):'');
    my $annotateRef = $baseAnnotateRef;
    if ($sourceP && $sourceP->{'isPartial'}) {$annotateRef .= "!PART";}
    
    # Insert a movedto or missing marker at the end of the verse
    my $fixedVerseEnd = &getVerseTag("$bk.$ch.$v", $xml, 1);
    if (!$fixedVerseEnd) {
      &ErrorBug("Could not find FROM_TO verse $bk.$ch.$v");
      next;
    }
    my $type = (!$sourceP ? 'missing_vs':'movedto_vs');
    my $osisRef = "$bk.$ch.$v";
    if ($fixedP->{'isPartial'}) {$osisRef .= "!PART";}
    my $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
            'resp="'.$VSYS{'resp_vs'}.'" ' .
            'type="'.$VSYS{$type}.'" ' .
            'osisRef="'.$osisRef.'" ';
    if ($annotateRef) {$m .= 'annotateRef="'.$annotateRef.'" annotateType="'.$ANNOTATE_TYPE{'Source'}.'" ';}
    $m .= '/>';
    $fixedVerseEnd->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $fixedVerseEnd);
    $note .= "[$type verse $v]";
    
    if (!$sourceP) {next;}
    
    # Insert a fitted milestone at the end of the source alternate 
    # verse, unless the source destination is empty. The alternate verse 
    # is either a milestone verse end (if the source was originally a 
    # regular verse) or else a hi with subType=x-alternate (if it was 
    # originally an alternate verse).
    my $altVerseEnd = &getSourceVerseTag($baseAnnotateRef, $xml, 1);
    if (!$altVerseEnd) {$altVerseEnd = &getSourceAltVerseTag($baseAnnotateRef, $xml, 1);}
    if (!$altVerseEnd) {
      &ErrorBug("Could not find FROM_TO destination alternate verse $baseAnnotateRef");
      next;
    }
    $osisRef = @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $altVerseEnd)}[0];
    if (!$osisRef || !$osisRef->getAttribute('osisID')) {
      &ErrorBug("Could not find FROM_TO destination verse osisID: ".($osisRef ? 'no osisID':'no verse'));
      next;
    }
    $osisRef = $osisRef->getAttribute('osisID');
    $osisRef =~ s/^.*?\s+(\S+)$/$1/;
    $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
         'resp="'.$VSYS{'resp_vs'}.'" ' . 
         'type="'.$VSYS{'fitted_vs'}.'" ' .
         'osisRef="'.$osisRef.'" ' .
         'annotateRef="'.$annotateRef.'" ' .
         'annotateType="'.$ANNOTATE_TYPE{'Source'}.'"/>';
    $altVerseEnd->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $altVerseEnd);
    $note .= "[fitted_vs verse $v]";
  }
}

# Find the source verse system verse tag (a milestone) associated with 
# an alternate $vid. Failure returns nothing.
sub getSourceVerseTag {
  my $vid = shift;
  my $xml = shift;
  my $isEnd = shift;
  
  my @svts = $XPC->findnodes('//*[@type="'.$VSYS{'prefix_vs'}.'-verse'.($isEnd ? $VSYS{'end_vs'}:$VSYS{'start_vs'}).'"]', $xml);
  foreach my $svt (@svts) {
    my $ref = $svt->getAttribute('annotateRef');
    foreach my $idp (split(/\s+/, &osisRef2osisID($ref))) {
      if ($idp eq $vid) {return $svt;}
    }
  }
  return '';
}

# Find the source verse system alternate verse tag associated with an
# alternate $vid. Failure returns nothing. Beware that this requires
# an alternate verse number which is the source verse system's verse 
# number BUT translators sometimes use the fixed verse system's number 
# for the alternate verse number instead, in which case this will not 
# find the desired verse.
sub getSourceAltVerseTag {
  my $vid = shift;
  my $xml = shift;
  my $isEnd = shift;
  
  if ($vid !~ /^([^\.]+)\.([^\.]+)\.([^\.]+)$/) {
    &ErrorBug("Could not parse $vid !~ /^([^\.]+)\.([^\.]+)\.([^\.]+)\$/");
    return '';
  }
  my $bk = $1; my $ch = $2; my $vs = $3;
  my @altsInChapter = $XPC->findnodes(
    '//osis:div[@type="book"][@osisID="'.$bk.'"]//osis:hi[@subType="x-alternate"]'.
    '[preceding::osis:chapter[1][@sID="'.$bk.'.'.$ch.'"]]'.
    '[following::osis:chapter[1][@eID="'.$bk.'.'.$ch.'"]]', $xml);
  foreach my $alt (@altsInChapter) {
    if ($alt->textContent !~ /\b$vs\w?\b/) {next;}
    if (!$isEnd) {return $alt;}
    my $end = @{$XPC->findnodes('following::*[ancestor::osis:div[@osisID="'.$bk.'"]]
        [self::osis:verse[@eID][1] or self::osis:hi[@subType="x-alternate"][1] or self::milestone[@type="'.$VSYS{'prefix_vs'}.'verse'.$VSYS{'end_vs'}.'"][1]]
        [1]', $alt)}[0];
    if ($end) {return $end;}
    &ErrorBug("Could not find end of $alt");
  }
  
  return '';
}

# Used when a chapter in the fixed verse system has been split into two 
# chapters in the source verse system. All verse tags from the split 
# onward to the end of the book must be re-versified, with alternate 
# chapter and verse tags added. The split chapter's end tag and the
# following chapter's start tag are converted to milestones, while all 
# following chapter tags are re-versified downward by one chapter. 
sub applyVsysChapterSplitAt {
  my $fixedP = shift;
  my $xml = shift;
  
  if (!$fixedP) {return;}
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'};
  my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
  
  # Reversify all verse tags in the book following the split
  my @verses = @{$XPC->findnodes("//osis:verse[starts-with(\@sID, '$bk.')]", $xml)};
  push (@verses, @{$XPC->findnodes("//osis:verse[starts-with(\@eID, '$bk.')]", $xml)});
  foreach my $v (@verses) {
    my $ida = $v->getAttribute('sID');
    if (!$ida) {$ida = $v->getAttribute('eID');}
    foreach my $id (split(/\s+/, $ida)) {
      my $vch = $id; 
      my $vvs = ($vch =~ s/^$bk\.(\d+)\.(\d+)$/$1/ ? $2:'');
      if ($vch <= $ch) {next;}
      &reVersify($bk, $vch, $vvs, -1, ($vch == ($ch + 1) ? $lastV:0), $xml);
    }
  }
  
  # Reversify (or just convert to milestone) all chapter tags in the book following the split
  my @chapters = @{$XPC->findnodes("//osis:chapter[starts-with(\@sID, '$bk.')]", $xml)};
  push (@chapters, @{$XPC->findnodes("//osis:chapter[starts-with(\@eID, '$bk.')]", $xml)});
  foreach my $c (@chapters) {
    my $isStart = 1;
    my $id = $c->getAttribute('sID');
    if (!$id) {
      $isStart = 0;
      $id = $c->getAttribute('eID');
    }
    my $vch = $id; $vch = ($vch =~ /^$bk\.(\d+)$/ ? $1:'');
    if ($vch < $ch) {next;}
    elsif ($vch == $ch &&  $isStart) {next;}
    elsif ($vch == $ch && !$isStart) {&toMilestone($c, 1, 0);}
    elsif ($vch == ($ch + 1) && $isStart) {&toMilestone($c, 1, 0);}
    else {
      my $newChapTag = &toMilestone($c, 0, 0);
      my $newID = $id; $newID = ($newID =~ /^([^\.]+)\.(\d+)$/ ? $1.'.'.($2-1):'');
      &Note("applyVsysChapterSplitAt($bk, $ch, $vs)[Changing chapter osisID from ".$newChapTag->getAttribute('osisID')." to $newID]");
      if ($isStart) {
        $newChapTag->setAttribute('osisID', $newID);
        $newChapTag->setAttribute('sID', $newID);
        $newChapTag->setAttribute('resp', $VSYS{'resp_vs'});
      }
      else {
        $newChapTag->setAttribute('eID', $newID);
        $newChapTag->setAttribute('resp', $VSYS{'resp_vs'});
      }
    }
  }
}

# Used when verses in the verse system were not included in the 
# translation. It modifies the previous verse osisID to include the 
# empty verses and renumbers the following verses in the chapter, also 
# inserting alternate verse numbers there. If the 'missing' verse was
# moved somewhere else (the usual case) that is marked-up by FROM_TO.
sub applyVsysMissing {
  my $fixedP = shift;
  my $xml = shift;
  
  if (!$fixedP) {return;}
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'}; my $lv = $fixedP->{'lv'};
  
  if ($fixedP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  my $verseNumberToModify = ($vs!=1 ? ($vs-1):&getFirstVerseInChapterOSIS($bk, $ch, $xml));
  
  # Handle the rare case when there isn't a previous verse, by creating one.
  my $verseCreated;
  if (!$verseNumberToModify) {
    $verseCreated++;
    if (&getFirstVerseInChapterOSIS($bk, ($ch+1), $xml)) {
      &ErrorBug("Cannot be missing all verses in a chapter, unless the chapter is the last in a book.", 1);
    }
    my $chapterStartTag = @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0];
    if (!$chapterStartTag) {
      # Create a chapter for the verse if needed
      my $prevChapterEndTag = @{$XPC->findnodes('//osis:chapter[@eID="'.$bk.'.'.($ch-1).'"]', $xml)}[0];
      my $tags = "<chapter xmlns='$OSIS_NAMESPACE' sID='$bk.$ch' osisID='$bk.$ch' resp='$VSYS{'resp_vs'}'/>" . 
                 "<chapter xmlns='$OSIS_NAMESPACE' eID='$bk.$ch' resp='$VSYS{'resp_vs'}'/>";
      $prevChapterEndTag->parentNode->insertAfter(
        $XML_PARSER->parse_balanced_chunk($tags), 
        $prevChapterEndTag);
      $chapterStartTag = @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0];
    }
    # Create an empty verse
    my $tags = "<verse xmlns='$OSIS_NAMESPACE' sID='$bk.$ch.1' osisID='$bk.$ch.1' resp='$VSYS{'resp_vs'}'/>" . 
               "<verse xmlns='$OSIS_NAMESPACE' eID='$bk.$ch.1' resp='$VSYS{'resp_vs'}'/>";
    $chapterStartTag->parentNode->insertAfter(
        $XML_PARSER->parse_balanced_chunk($tags), 
        $chapterStartTag);
    $verseNumberToModify = 1;
    $vs++; # Because an empty verse was just created
  }
  
  my $verseTagToModify = &getVerseTag("$bk.$ch.$verseNumberToModify", $xml, 0);
  # For any following verses, advance their verse numbers and add alternate verse numbers if needed
  my $followingVerse = @{$XPC->findnodes('./following::osis:verse[@sID][1]', $verseTagToModify)}[0];
  if ($followingVerse) {
    my $count = (1 + $lv - $vs);
    $followingVerse = $followingVerse->getAttribute('osisID');
    $followingVerse =~ s/^[^\.]+\.\d+\.(\d+)\b.*?$/$1/;
    if ($vs != ($followingVerse-$count) - ($vs!=1 ? 0:1)) {
      for (my $v=&getLastVerseInChapterOSIS($bk, $ch, $xml); $v>=$vs; $v--) {
        &reVersify($bk, $ch, $v, 0, $count, $xml);
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
  }

  push(@missing, $verseTagToModify->getAttribute('osisID'));
  my $newOsisID = join(' ', &normalizeOsisID(\@missing));
  &Note("Changing verse osisID='".$verseTagToModify->getAttribute('osisID')."' to '$newOsisID'");
  if (!$verseCreated) {
    $verseTagToModify = &toMilestone($verseTagToModify, 0, 0);
    $endTag = &toMilestone($endTag, 0, 0);
  }
  $verseTagToModify->setAttribute('osisID', $newOsisID);
  $verseTagToModify->setAttribute('sID', $newOsisID);
  $endTag->setAttribute('eID', $newOsisID);
}

# Used when the translation includes extra verses in a chapter compared
# to the target verse system (and which are marked up as regular 
# verses). For these extra verses, alternate verse numbers are inserted 
# and verse tags are converted into milestone elements. Then they are 
# enclosed within the proceding verse system verse. All following verses 
# in the chapter are renumbered and alternate verses inserted for them.
sub applyVsysExtra {
  my $sourceP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $adjusted = shift;
  
  if (!$sourceP) {return;}
  
  my $bk = $sourceP->{'bk'}; my $ch = $sourceP->{'ch'}; my $vs = $sourceP->{'vs'}; my $lv = $sourceP->{'lv'};
  
  if ($sourceP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  my $isWholeChapter = ($ch > @{$canonP->{$bk}} ? 1:$sourceP->{'isWholeChapter'});
  
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
  my $sid = ($isWholeChapter ?
    "$bk.".($ch-1).".".&getLastVerseInChapterOSIS($bk, ($ch-1), $xml) :
    "$bk.$ch.".($vs!=1 ? ($vs-1):$vs));
  my $eid = "$bk.$ch.".($isWholeChapter || $vs != 1 ? $lv:($lv+1));
  
  my $startTag = &getVerseTag($sid, $xml, 0);
  my $endTag   = &getVerseTag($eid, $xml, 1);
  
  if (!$startTag) {
    &Error("Referenced starting verse tag is missing: $sid.");
    $sid =~ s/^(.*?)\.(\d+)$//;
    &errMissingVerse($1, $2);
    return;
  }
  if (!$endTag) {
    &Error("Referenced ending verse tag is missing: $eid.", "");
    $eid =~ s/^(.*?)\.(\d+)$//;
    &errMissingVerse($1, $2);
    return;
  }
 
  # VSYS_EXTRA references the source verse system, which may have been
  # modified by previous instructions. So adjust our inputs in that case.
  if (!$adjusted && &has_src_milestone($startTag) =~ /^[^\.]+\.\d+\.(\d+)\b/) {
    my $arv = $1;
    $startTag->getAttribute('osisID') =~ /^[^\.]+\.\d+\.(\d+)\b/;
    my $shift = ($1 - $arv);
    if ($shift) {
      &Note("This verse was moved, adjusting position: '$shift'.");
      my $newSourceArgumentP = &parseVsysArgument($bk.'.'.$ch.'.'.($vs+$shift).'.'.($sourceP->{'isPartial'} ? 'PART':($lv+$shift)), $xml, 'source');
      &applyVsysExtra($newSourceArgumentP, $canonP, $xml, 1);
      return;
    }
  }
 
  # If isWholeChapter, then convert chapter tags to alternates and add alternate chapter number
  if ($isWholeChapter) {
    my $chapLabel = @{$XPC->findnodes("//osis:title[\@type='x-chapterLabel'][not(\@canonical='true')]
      [ preceding::osis:chapter[\@osisID][1][\@sID='$bk.$ch'][not(preceding::osis:chapter[\@eID='$bk.$ch'])] ]", $xml)}[0];
    if ($chapLabel) {
      &Note("Converting chapter label \"".$chapLabel->textContent."\" to alternate.");
      $chapLabel->setAttribute('type', 'x-chapterLabel-alternate');
      my $t = $chapLabel->textContent();
      &changeNodeText($chapLabel, '');
      my $alt = "<hi xmlns=\"$OSIS_NAMESPACE\" type=\"italic\" subType=\"x-alternate\">$t</hi>";
      $alt = $XML_PARSER->parse_balanced_chunk();
      foreach my $chld ($chapLabel->childNodes) {$alt->insertAfter($chld, undef);}
      $chapLabel->insertAfter($alt, undef);
    }
    else {
      &Note("No chapter label was found, adding alternate chapter label \"$ch\".");
      my $alt = "<title xmlns=\"$OSIS_NAMESPACE\" " .
      "type=\"x-chapterLabel-alternate\" resp=\"$VSYS{'resp_vs'}\">" .
      "<hi type=\"italic\" subType=\"x-alternate\">$ch</hi></title>";
      $alt = $XML_PARSER->parse_balanced_chunk($alt);
      my $chStart = @{$XPC->findnodes("//osis:chapter[\@osisID='$bk.$ch']", $xml)}[0];
      $chStart->parentNode()->insertAfter($alt, $chStart);
    }
    my $chEnd = &toMilestone(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0], 0, 1);
    $chEnd->setAttribute('eID', "$bk.".($ch-1));
    &toMilestone(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0], 1, 1);
    &toMilestone(@{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0], 1, 1);
  }
  
  # Convert verse tags between startTag and endTag to alternate verse numbers
  # But if there are no in-between tags, then only modify the IDs.
  $startTag = &toMilestone($startTag, 0, 0);
  if ($startTag->getAttribute('sID') eq $endTag->getAttribute('eID')) {
    my %ids; map($ids{$_}++, split(/\s+/, $startTag->getAttribute('osisID')));
    for (my $v = $vs; $v <= $lv; $v++) {if ($ids{"$bk.$ch.$v"}) {delete($ids{"$bk.$ch.$v"});}}
    my $newID = join(' ', &normalizeOsisID([ sort keys(%ids) ]));
    $startTag->setAttribute('osisID', $newID);
    $startTag->setAttribute('sID', $newID);
  }
  else {
    my $v = $startTag;
    my @alts;
    do {
      if ($v->unique_key ne $startTag->unique_key) {push(@alts, $v);}
      $v = @{$XPC->findnodes('following::osis:verse[1]', $v)}[0];
    } while ($v && $v->unique_key ne $endTag->unique_key);
    foreach my $v (@alts) {&toMilestone($v, 1, 1);}
  }
  # Also convert endTag to alternate and update eID 
  $endTag = &toMilestone($endTag, 0, 1);
  $endTag->setAttribute('eID', $startTag->getAttribute('sID'));
  
  # Following verses get decremented verse numbers plus an alternate verse number (unless isWholeChapter)
  if (!$isWholeChapter) {
    my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
    my $count = (1 + $lv - $vs);
    for (my $v = $vs + $count + ($vs!=1 ? 0:1); $v <= $lastV; $v++) {
      &reVersify($bk, $ch, $v, 0, (-1*$count), $xml);
    }
  }
}

# VSYS_MISSING_FN produces VTAG_MISSING instructions indicating verses 
# where verse tags were left out of the source text. This happens when a 
# verse's text was not included in the source verse system, but a 
# footnote indicating the removal (which often includes the verse text 
# itself) is located at the end of the preceding verse. Sometimes, 
# references to these missing verses appear in the source text, even 
# though the verse text itself does not. Linking such missing verses to 
# their previous verse insures there are no broken links in the source 
# text.
sub applyVsysMissingVTag {
  my $argP = shift;
  my $xml = shift;
  
  my $fixedP  = &parseVsysArgument($argP->{'fixed'},  $xml, 'fixed');
  my $sourceP = &parseVsysArgument($argP->{'source'}, $xml, 'source');
  
  my $prevOsisID = $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.$sourceP->{'vs'};
  
  my $prevVerseS = &getVerseTag($prevOsisID, $xml, 0);
  my $prevVerseE = &getVerseTag($prevOsisID, $xml, 1);
  if (!$prevVerseS || !$prevVerseE) {
    &ErrorBug("Could not find verse with osisID '$prevOsisID'");
    return;
  }
  
  my $newOsisID = $prevOsisID;
  for (my $v = $fixedP->{'vs'}; $v <= $fixedP->{'lv'}; $v++) {
    $newOsisID .= ' '.$fixedP->{'bk'}.'.'.$fixedP->{'ch'}.'.'.$v;
  }
  $newOsisID = join(' ', &normalizeOsisID([ split(/\s+/, $newOsisID) ]));
  
  $prevVerseS->setAttribute('osisID', $newOsisID);
  $prevVerseS->setAttribute('sID',    $newOsisID);
  $prevVerseE->setAttribute('eID',    $newOsisID);
  &Note("Applied VSYS_MISSING_FN: ".$argP->{'source'}.", osisID=\"$newOsisID\"");
}

# Markup verse as alternate, increment its chapter by $chCount and its 
# verse by $vsCount and mark it as moved.
sub reVersify {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $chCount = shift;
  my $vsCount = shift;
  my $xml = shift;
  
  my $note = "reVersify($bk, $ch, $vs, $chCount, $vsCount)";
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  if (!$vTagS) {$note .= "[Start tag not found]"; &Note($note); return;}
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  if (!$vTagE) {$note .= "[End tag not found]"; &Note($note); return;}
  
  my $osisID = $vTagS->getAttribute('osisID');
  my $newVerseID;
  my $newID;
  if ($vsCount || $chCount) {
    my @verses = split(/\s+/, $osisID);
    $newVerseID = $bk.'.'.($ch + $chCount).'.'.($vs + $vsCount);
    foreach my $v (@verses) {if ($v  eq "$bk.$ch.$vs") {$v = $newVerseID;}}
    $newID = join(' ', @verses);
  }
  
  if (!$vTagS->hasAttribute('resp') || $vTagS->getAttribute('resp') ne $VSYS{'resp_vs'}) {
    $vTagS = &toMilestone($vTagS, 0, ($chCount ? 2:1));
    $vTagE = &toMilestone($vTagE, 0, ($chCount ? 2:1));
    if ($vsCount || $chCount) {
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$newVerseID, 'source'=>"$bk.$ch.$vs" });
    }
  }
  elsif (&has_src_milestone($vTagS) eq $newID) {
    $vTagS = &undoMilestone(&has_src_milestone($vTagS, 1));
    $vTagE = &undoMilestone(&has_src_milestone($vTagE, 1));
    $osisID = $vTagS->getAttribute('osisID');
    for (my $i=0; $i<@VSYS_INSTR; $i++) {
      if (@VSYS_INSTR[$i]->{'source'} eq "$bk.$ch.$vs") {splice(@VSYS_INSTR, $i, 1); last;}
    }
  }
  else {$note .= "[Alternate verse already set]";}
  
  # Increment/Decrement
  if ($vsCount || $chCount) {
    if ($newID ne $osisID) {
      $note .= "[Changing verse osisID from ".$vTagS->getAttribute('osisID')." to $newID]";
      &osisIDCheckUnique($newVerseID, $xml);
      $vTagS->setAttribute('osisID', $newID);
      $vTagS->setAttribute('sID', $newID);
      $vTagS->setAttribute('resp', $VSYS{'resp_vs'});
      $vTagE->setAttribute('eID', $newID);
      $vTagE->setAttribute('resp', $VSYS{'resp_vs'});
    }
  }
  &Note($note); 
}

# Terminology:
# src_milestone = x-vsys milestone representing an original source verse or chapter tag
# fit_tag       = verse or chapter tag of fitted source text associated with a src_milestone
#
# This function writes a src_milestone for the passed verse or chapter 
# tag, unless it already has one. The passed verse or chapter tag 
# becomes the fit_tag. But if noFitTag is set, the fit_tag is removed 
# from the tree. The fit_tag element is returned, unless noFitTag is set 
# and there was no pre-existing src_milestone, in which case '' is 
# returned. When writeAlternate is set, an alternate verse number will 
# also be written to the tree when the passed element is a starting 
# verse tag.
sub toMilestone {
  my $verse_or_chapter_tag = shift;
  my $noFitTag = shift;
  my $writeAlternate = shift; # 1=verse, 2=verse and chapter
  
  # Typical alternate markup example:
  # <milestone type="x-vsys-verse-start" osisRef="Rom.14.24" annotateRef="Rom.16.25" annotateType="x-vsys-source"/>
  #<hi type="italic" subType="x-alternate" resp="resp_vs"><hi type="super">(25)</hi></hi>
  
  my $start_or_end = ($verse_or_chapter_tag->getAttribute('sID') ? 'start_vs':($verse_or_chapter_tag->getAttribute('eID') ? 'end_vs':''));
  my $s_or_eID = ($start_or_end eq 'start_vs' ? $verse_or_chapter_tag->getAttribute('sID'):$verse_or_chapter_tag->getAttribute('eID'));
  my $isVerseStart = ($start_or_end eq 'start_vs' && $verse_or_chapter_tag->nodeName eq 'verse' ? 1:0);
  if (!$start_or_end) {
    &ErrorBug("Element missing sID or eID: ".$verse_or_chapter_tag->toString());
  }
  if ($start_or_end eq 'start_vs' && $s_or_eID ne $verse_or_chapter_tag->getAttribute('osisID')) {
    &ErrorBug("osisID is different than sID: $s_or_eID != ".$verse_or_chapter_tag->getAttribute('osisID'));
  }
  
  my $note = "toMilestone($s_or_eID, " . $verse_or_chapter_tag->nodeName . ", $start_or_end)";
  
  # Write fit_tag
  my $fit_tag;
  if (&has_src_milestone($verse_or_chapter_tag)) {
    $note .= "[src_milestone exists]";
    $fit_tag = $verse_or_chapter_tag;
    
    if ($noFitTag) {
      $fit_tag->unbindNode();
      $note .= "[remove fit_tag]";
    }
    
    &Note($note);
    
    return $fit_tag;
  }
  else {
    if ($noFitTag) {$note .= "[remove fit_tag]";}
    else {
      $fit_tag = $verse_or_chapter_tag->cloneNode(1);
      if ($fit_tag->getAttribute('type')) {&ErrorBug("Type already set on $fit_tag");}
      $fit_tag->setAttribute('resp', $VSYS{'resp_vs'});
      $verse_or_chapter_tag->parentNode->insertBefore($fit_tag, $verse_or_chapter_tag);
      $note .= "[fit_tag]";
    }
  }
  
  # Write src_milestone
  my $src_milestone = $verse_or_chapter_tag;
  $src_milestone->setAttribute('type', $VSYS{'prefix_vs'}.'-'.$src_milestone->nodeName.$VSYS{$start_or_end});
  $src_milestone->setAttribute('annotateRef', $s_or_eID);
  $src_milestone->setAttribute('annotateType', $ANNOTATE_TYPE{'Source'});
  $src_milestone->setNodeName('milestone');
  if ($src_milestone->hasAttribute('osisID')) {$src_milestone->removeAttribute('osisID');}
  if ($src_milestone->hasAttribute('sID')) {$src_milestone->removeAttribute('sID');}
  if ($src_milestone->hasAttribute('eID')) {$src_milestone->removeAttribute('eID');}
  $note .= "[src_milestone]";
  # Remove any preceding newline or whitespace-only text node
  my $nl = @{$XPC->findnodes(
      'preceding-sibling::node()[1][self::text()]', $src_milestone)}[0];
  if ($nl && $nl->data() =~ /^[\n\s]*$/) {$nl->unbindNode();}
  
  # Write alternate verse number from the osisID
  if ($writeAlternate && $isVerseStart) {
    if ($s_or_eID =~ /^[^\.]+\.(\d+)\.(\d+)\b.*?(\.(\d+))?$/) {
      my $ch = $1; my $vs = $2; my $lv = ($3 ? $4:$vs);
      my $altText = ($vs ne $lv ? "$vs-$lv":"$vs");
      if ($writeAlternate == 2) {$altText = "$ch:$altText";}
      my $alt = '<hi xmlns="'.$OSIS_NAMESPACE.'" ' .
      'type="italic" subType="x-alternate" resp="'.$VSYS{'resp_vs'}.'">' .
      '<hi type="super">('.$altText.') </hi></hi>'; 
      $alt = $XML_PARSER->parse_balanced_chunk($alt);
      my $firstTextNode = @{$XPC->findnodes('following::text()
        [not(ancestor::osis:hi[starts-with(@subType, "x-alternate-")])]
        [normalize-space()][1]', $verse_or_chapter_tag)}[0];
      $firstTextNode->parentNode()->insertBefore($alt, $firstTextNode);
      $note .= "[alternate verse \"$altText\"]";
    }
    else {&ErrorBug("Could not parse: $s_or_eID =~ /^[^\.]+\.\d+\.(\d+)\b.*?(\.(\d+))?\$/");}
  }
  
  &Note($note);
  
  return $fit_tag;
}

# This will take a src_milestone element (of verse or chapter,  
# start or end) and convert it back to the original, undoing everything 
# that toMilestone() did. It returns the original element.
sub undoMilestone {
  my $ms = shift;
  
  my $note = "undoMilestone(".$ms->getAttribute('type').', '.$ms->getAttribute('annotateRef').')';

  my $avn = @{$XPC->findnodes('following::text()
    [not(ancestor::osis:hi[starts-with(@subType, "x-alternate-")])][normalize-space()][1]
    /ancestor-or-self::osis:hi[@subType="x-alternate"][@resp="'.$VSYS{'resp_vs'}.'"][1]', $ms)}[0];
  if ($avn) {
    $avn->unbindNode();
    $note .= "[removed alternate verse ".$avn->textContent."]";
  }
  my $fit_tag = @{$XPC->findnodes('preceding-sibling::*[1][@resp="'.$VSYS{'resp_vs'}.'"]', $ms)}[0];
  if ($fit_tag) {
    $fit_tag->unbindNode();
    $note .= "[removed fit_tag]";
  }
  my $chvsTypeRE = '^'.$VSYS{'prefix_vs'}.'-(chapter|verse)('.$VSYS{'start_vs'}.'|'.$VSYS{'end_vs'}.')$'; $chvsTypeRE =~ s/-/\\-/g;
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
  }
  else {&ErrorBug("Can't parse: ".$ms->getAttribute('type')." !~ /$chvsTypeRE/");}
  
  $note .= "[restored src_milestone to ".$ms->nodeName."]";
  &Note($note);
  
  return $ms;
}

# Report an error if any verse in this hypothetical osisID is already listed 
# in an existing osisID (to catch any bug causing multiple verse tags to cover 
# the same verse)
sub osisIDCheckUnique {
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
sub getFirstVerseInChapterOSIS {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  
  my $fv = 200;
  foreach my $v (@vs) {if ($v->getAttribute('osisID') =~ /^\Q$bk.$ch.\E(\d+)/ && $1 < $fv) {$fv = $1;}}
  if ($fv == 200) {return;}
  
  return $fv;
}

# Reads the osis file to find a chapter's largest verse number
sub getLastVerseInChapterOSIS {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  
  my $lv;
  foreach my $v (@vs) {
    if ($v->getAttribute('osisID') =~ /\b\Q$bk.$ch.\E(\d+)$/ && $1 > $lv) {
      $lv = (1*$1);
    }
  }
  if (!defined($lv)) {
    &ErrorBug("getLastVerseInChapterOSIS($bk, $ch): Could not find last verse.");
  }
  
  return $lv;
}

# Check if $bk.$ch.$$vsP.$$lvP covers an entire chapter. If $$vsP and 
# $$lvP are both undefined set $$vsP to 1 and $$lvP to the last verse in 
# the chapter. If $$lvP is undefined but $$vsP is defined, then set 
# $$lvP to $$vsP. Otherwise $$vsP and $$lvP are left untouched.
sub isWholeVsysChapter {
  my $bk  = shift;
  my $ch  = shift;
  my $vsP  = shift;
  my $lvP  = shift;
  my $xml = shift;
  
  if (!@{$XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml)}[0]) {
    return (!$$vsP);
  }
  
  my $maxv = &getLastVerseInChapterOSIS($bk, $ch, $xml);
  
  if (!defined($$lvP)) {
    if (!defined($$vsP)) {
      $$vsP = 1; $$lvP = $maxv;
    }
    else {
      $$lvP = $$vsP;
    }
  }

  return ($$vsP == 1 && $$lvP == $maxv);
}

# Takes a required verse element and checks for an x-vsys 
# src_milestone. If the verse element has no such src_milestone, meaning it
# was not created by x-vsys instructions, then '' is returned.
# Otherwise, either the milestone's annotateRef value (source osisRef
# value) or the milestone element itself is returned, depending on the 
# value of returnElem.
sub has_src_milestone {
  my $verseElem = shift;
  my $returnElem = shift;
  
  if (!$verseElem) {&ErrorBug("Required verseElem is '$verseElem'"); return '';}
  
  my $ms = @{$XPC->findnodes('following::*[1][name()="milestone"][starts-with(@type, "'.$VSYS{'prefix_vs'}.'-verse")]', $verseElem)}[0];
  
  if (!$ms && $verseElem->getAttribute('resp') eq $VSYS{'resp_vs'}) {
    &ErrorBug($VSYS{'resp_vs'}. " verse tag has no src_milestone");
  }
  if ($ms && $verseElem->getAttribute('resp') ne $VSYS{'resp_vs'}) {
    &ErrorBug("verse tag with src_milestone is not ".$VSYS{'resp_vs'});
  }
    
  if (!$ms) {return '';}
  
  return ($returnElem ? $ms:$ms->getAttribute('annotateRef'));
}

# Writes the chosen verse system to an XML file for easy use by an XSLT.
sub writeVerseSystem {
  my $vsys = shift;
  
  # Read the entire verse system using SWORD
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setIndex(0);
  $vk->normalize();
  my (%sdata, $lastIndex, %bks);
  do {
    $lastIndex = $vk->getIndex;
    if ($vk->getOSISRef() !~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      &ErrorBug("Problem reading SWORD versekey osisRef: ".$vk->getOSISRef(), 1);
    }
    else {
      $bks{$1}++; 
      my $b = sprintf("%03i:%s", scalar keys %bks, $1);
      my $c = sprintf("%03i", $2);
      my $v = sprintf("%03i", $3);
      my $g = ($NT_BOOKS =~ /\b$1\b/ ? 1:0); 
      $sdata{$g}{$b}{$c}{$v}++;
    }
    $vk->increment();
  } while ($vk->getIndex ne $lastIndex);
  
  # Prepare the output directory
  my $outfile = "$MOD_OUTDIR/tmp/versification/$vsys.xml";
  if (-e $outfile) {
    return 1;
  }
  if (! -e "$MOD_OUTDIR/tmp") {
    &ErrorBug("TMPDIR does not exist: $TMPDIR.");
    return;
  }
  if (! -e "$MOD_OUTDIR/tmp/versification") {
    mkdir "$MOD_OUTDIR/tmp/versification";
  }
  
  # Write the XML file
  if (!open(VOUT, $WRITELAYER, $outfile)) {
    &ErrorBug("Could not write verse system to $outfile.");
    return;
  }
  print VOUT 
'<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.bibletechnologies.net/2003/OSIS/namespace http://www.crosswire.org/~dmsmith/osis/osisCore.2.1.1-cw-latest.xsd"> 
<osisText osisRefWork="'.$vsys.'" osisIDWork="'.$vsys.'"> 
<header> 
  <work osisWork="'.$vsys.'">
    <title>CrossWire SWORD Verse System '.$vsys.'</title> 
    <refSystem>Bible.'.$vsys.'</refSystem>
  </work>
</header>
';
  foreach my $gk (sort keys %sdata) {
    print VOUT "<div type=\"bookGroup\">\n";
    foreach my $bk (sort keys %{$sdata{$gk}}) {
      my $b = $bk; $b =~ s/^\d+://;
      print VOUT "  <div type=\"book\" osisID=\"$b\">\n";
      foreach my $ck (sort keys %{$sdata{$gk}{$bk}}) {
        my $c = $ck; $c =~ s/^0+//;
        print VOUT "    <chapter osisID=\"$b.$c\">\n";
        foreach my $vk (sort keys %{$sdata{$gk}{$bk}{$ck}}) {
          my $v = $vk; $v =~ s/^0+//;
          print VOUT "      <verse osisID=\"$b.$c.$v\"/>\n";
        }
        print VOUT "    </chapter>\n";
      }
      print VOUT "  </div>\n";
    }
    print VOUT "</div>\n";
  }
  print VOUT
'</osisText>
</osis>';
  close(VOUT);
  
  return 1;
}

1;
