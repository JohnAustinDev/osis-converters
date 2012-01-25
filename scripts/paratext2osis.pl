# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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
#
########################################################################

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
#  -The CF_paratext2osis.txt command file is executed from top to
#   bottom. All settings remain in effect until/unless changed (so
#   settings may be set more than once). All SFM files are processed 
#   and added to the OSIS file in the order in which they appear in 
#   the command file. Books are processed using all settings previously 
#   set in the command file. The special terms "OT" and "NT" should 
#   appear before the first Old-Testament and first New-Testament books.
#
#  -It might be helpful on the first run of a new SFM project to use 
#   "FIND_ALL_TAGS:true". This will log all tags found in the project
#   after "FIND_ALL_TAGS listing". The listed tags can be added to 
#   the command file and handled as desired.

# TERMINOLOGY:
#   A "tag-list" is a Perl regular expression consisting of SFM tag 
#   names separated by the perl OR ("|") term. Order should be longest
#   tags to shortest. The "\" before the tag is implied. 
#   For example: (toc1|toc2|toc3|ide|rem|id|w\*|h|w)

# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   RUN - Process the SFM file now and add it to the OSIS file. 
#       Only one SFM file per RUN command is allowed. 
#   SFM_BOOK_NAME - A perl regular expression to match the SFM book 
#       name from the SFM file name.
#   FIND_ALL_TAGS - Set to "true" to produce a list of all tags in 
#       the document. No tags are ignored.
#   MOVE_TITLE_NOTES - Set to "false" to ignore notes in titles, 
#       otherwise such notes are moved to beginning of next verse.
#   MOVE_CHAPTER_NOTES - Set to "false" to ignore notes in \c lines, 
#       otherwise they are moved to verse 1. 
#   VERSE_CONTINUE_TERMS - Characters like "-" in \v4-5, which are 
#       used to indicate multiple verses in \v or \f tags.
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I

# COMMAND FILE FORMATTING RELATED SETTINGS:
#   IGNORE - A tag-list of SFM lines which should be ignored.
#   INTRO_TITLE_1 - A tag-list representing titles used in a 
#       book introduction.
#   INTRO_PARAGRAPH - A tag-list for paragraphs used in a 
#       book introduction.
#   TITLE_1 - A tag-list for main headings.
#   TITLE_2 - A tag-list for secondary headings.
#   CANONICAL_TITLE_1 - A tag-list for main canonical headings.
#   CANONICAL_TITLE_2 - A tag-list for secondary canonical headings.
#   LIST_TITLE - A tag-list for list titles.
#   LIST_ENTRY - A tag-list for basic list entries.
#   LIST_ENTRY_BULLET - A tag-list for bulleted list entries.
#   ENUMERATED_LIST_LEVEL1 - A tag-list for enumerated Roman numeral 
#       capitals primary lists.
#   ENUMERATED_LIST_LEVEL2 - A tag-list for enumerated arabic numeral 
#       secondary lists.
#   ENUMERATED_LIST_LEVEL3 - A tag-list for enumerated Roman numeral 
#       small tertiary lists.
#   PARAGRAPH - A tag-list for intented paragraphs.
#   PARAGRAPH2 - A tag-list for doubly indented paragraphs.
#   PARAGRAPH3 - A tag-list for triple indented paragraphs.
#   BLANK_LINE - A tag-list for blank lines (or non-indented paragraphs)

# COMMAND FILE TEXT PROCESSING SETTINGS:
#   BOLD - Perl regular expression to match any bold text.
#   ITALIC - Perl regular expression to match any italic text.
#   REMOVE - A Perl regular expression for bits to be removed from SFM.     

# COMMAND FILE FOOTNOTE SETTINGS:
#   FOOTNOTES - A Perl regular expression to match all SFM footnotes.
#   CROSSREFS - For inline cross references. See FOOTNOTES_INLINE
#   FOOTNOTES_WITHREFS - (rarely used) A footnote file whose footnotes 
#       have refs
#   FOOTNOTES_NOREFS - (rarely used) A footnote file whose footnotes 
#       don't have refs

# COMMAND FILE GLOSSARY/DICTIONARY RELATED SETTINGS:
#   GLOSSARY - A Perl regular expression to match SFM glossary links.
#   GLOSSARY_NAME - Name of glossary module targetted by glossary links.

open (OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) || die "Could not open paratext2osis output file $OUTPUTFILE\n";
&Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"defaultReferenceScheme\" xml:lang=\"$LANG\"><header><work osisWork=\"$MOD\"><title>$MOD Bible</title><identifier type=\"OSIS\">Bible.$MOD</identifier><refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n");

&Log("-----------------------------------------------------\nSTARTING paratext2osis.pl\n\n");

# Read the COMMANDFILE, converting each book as it is encountered
open (COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open paratext2osis command file $COMMANDFILE\n";
$endTestament="";
$NameMatch="";

#Defaults:
$findalltags="false";
$ContinuationTerms="-";
$FstTitle="none";
$SecTitle="none";
$IntroFstTitle="none";
$list1="none";
$list2="none";
$enumList1="none";
$enumList2="none";
$enumList3="none";
$intropar="none";
$blankline="none";
$listtitle="none";
$canonicaltitle="none";
$canonicaltitle2="none";
$normpar="none";
$doublepar="none";
$triplepar="none";
$boldpattern="";
$italicpattern="";
$MoveTitleNotes="true";
$MoveChapterNotes="true";
$SpecialCapitals="";
$PreverseTitleType = "";
$removepattern="";
$notePattern="";
$NoteType="INLINE";

$line=0;
while (<COMF>) {
  $line++;
  
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^\#/) {next;}
  # VARIOUS SETTINGS...
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^FIND_ALL_TAGS:(\s*(.*?)\s*)?$/) {
    if ($1) {
      $findalltags = $2; 
      if ($findalltags eq "true") {&Log("ERROR: FIND_ALL_TAGS is active. SFM will NOT be processed until this setting is deactivated.\n");} 
      next;
    }
  }
  elsif ($_ =~ /^SFM_BOOK_NAME:(\s*\((.*?)\)\s*)?$/) {if ($1) {$NameMatch = $2; next;}}
  elsif ($_ =~ /^MOVE_TITLE_NOTES:(\s*(.*?)\s*)?$/) {if ($1) {$MoveTitleNotes = $2; next;}}
  elsif ($_ =~ /^MOVE_CHAPTER_NOTES:(\s*(.*?)\s*)?$/) {if ($1) {$MoveChapterNotes = $2; next;}}
  elsif ($_ =~ /^VERSE_CONTINUE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$ContinuationTerms = $2; next;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SpecialCapitals = $2; next;}}
  # FORMATTING TAGS...
  elsif ($_ =~ /^IGNORE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IgnoreTags = $2; next;}}    
  elsif ($_ =~ /^INTRO_TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IntroFstTitle = $2; next;}}
  elsif ($_ =~ /^INTRO_PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$intropar = $2; next;}}
  elsif ($_ =~ /^TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$FstTitle = $2; next;}}
  elsif ($_ =~ /^TITLE_2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$SecTitle = $2; next;}}
  elsif ($_ =~ /^CANONICAL_TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$canonicaltitle = $2; next;}}
  elsif ($_ =~ /^CANONICAL_TITLE_2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$canonicaltitle2 = $2; next;}}
  elsif ($_ =~ /^LIST_TITLE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$listtitle = $2; next;}}
  elsif ($_ =~ /^LIST_ENTRY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$list1 = $2; next;}}
  elsif ($_ =~ /^LIST_ENTRY_BULLET:(\s*\((.*?)\)\s*)?$/) {if ($1) {$list2 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList1 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList2 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList3 = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$normpar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$doublepar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$triplepar = $2; next;}}
  elsif ($_ =~ /^BLANK_LINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$blankline = $2; next;}}
  elsif ($_ =~ /^REMOVE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$removepattern = $2; next;}}
  # TEXT TAGS...
  elsif ($_ =~ /^BOLD:(\s*\((.*?)\)\s*)?$/) {if ($1) {$boldpattern = $2; next;}}
  elsif ($_ =~ /^ITALIC:(\s*\((.*?)\)\s*)?$/) {if ($1) {$italicpattern = $2; next;}}
  elsif ($_ =~ /^CROSSREF:(\s*\((.*?)\)\s*)?$/) {if ($1) {$crossrefs = $2; next;}}
  elsif ($_ =~ /^GLOSSARY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$glossaryentries = $2; next;}}
  elsif ($_ =~ /^FOOTNOTE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$notePattern = $2; next;}}
  elsif ($_ =~ /^GLOSSARY_NAME:(\s*(.*?)\s*)?$/) {if ($1) {$glossaryname = $2; next;}}
  

  
  # OT command...
  elsif ($_ =~ /^OT\s*$/) {
    &Write("<div type=\"bookGroup\">\n");
    $Testament="OT";
    $endTestament="</div>";
  }
  # NT command...
  elsif ($_ =~ /^NT\s*$/) {
    $Testament="NT";
    &Write("$endTestament\n<div type=\"bookGroup\">\n");
    $endTestament="</div>";
  }
  # FOOTNOTES_ command...
  elsif ($_ =~ /^FOOTNOTES_([^:]+)/) {
    $NoteType = $1;
    if (keys %notes > 0) {&checkRemainingNotes;}
    $_ =~ /^[^:]+:\s*(.*)/;
    $NoteFileName = $1;
    $notePattern = "";
    if    ($NoteType eq "WITHREFS") {&readFootNoteFileWithRefs;}
    elsif ($NoteType eq "NOREFS") {&readFootNoteFileWithoutRefs;}
    else {&Log("ERROR: Unknown FOOTNOTE setting \"$_\" in $COMMANDFILE\n");}
    &Log("Begin using FOOTNOTES_$NoteType $NoteFileName\n");
  }
  # SFM file name...
  elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
    $SFMfile = $1;
    $SFMfile =~ s/\\/\//g;
    &bookSFMtoOSIS;
  }
  else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}

# Write closing tags, and close the output file
&Write("$endTestament\n</osisText>\n</osis>\n");
close (OUTF);

# Check and report...
if (keys %notes > 0) {&checkRemainingNotes;}
&Log("PROCESSING COMPLETE.\n");
if ($findalltags ne "true") {
  &Log("Following is the list of unhandled tags which were skipped:\n");
}
else {
  &Log("FIND_ALL_TAGS listing (NOTE that \\c and \\v tags do not need to be mentioned in the command file as they are always handled):\n");
}
foreach $tag (keys %skippedTags) {
  #&Log("$skippedTags{$tag}"); #complete printout
  &Log("$tag "); #brief printout
}

&Log("\nFollowing are unhandled tags which where removed from the text:\n$tagsintext");

&Log("\nEnd of listing\n");
1;

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------


sub bookSFMtoOSIS {

  # Get the name of the book from the file name
  if ($NameMatch eq "") {$SFMfile =~ /\/(\w+)\.[^\/]+$/; $bnm=$1;}
  else {$SFMfile =~ /$NameMatch/; $bnm=$1;}
  $bookName = &getOsisName($bnm);
  
  &Log("Processing $bookName\n");
  
  # First make a copy of the SFM file, insuring \v tags always begin a line
  my $sfmname = $SFMfile;
  $sfmname =~ s/^.*?([^\/]*)$/$1/;
  $ThisSFM = "$TMPDIR/$sfmname";
  open(TMPI, "<:encoding(UTF-8)", $SFMfile) or print getcwd." ERROR: Could not open file $SFMfile.\n";
  open(TMPO, ">:encoding(UTF-8)", $ThisSFM) or die "ERROR: Could not open temporary SFM file $ThisSFM\n";
  $removedSoftHyphens = 0;
  $fixedMultiVerseLines = 0;
  $line = 0;
  while(<TMPI>) {  
    $line++;
    # Remove soft hyphens
    my $sh = decode("utf8", "­");
    utf8::upgrade($sh);
    if ($_ =~ s/$sh//g) {$removedSoftHyphens++;}
    
    # Remove [] around purposefully skipped verses so they will be recognized
    # [\v xxx]
    while ($_ =~ s/(\[(\\v\s+[\s\d$ContinuationTerms]+)\])/$2/) {&Log("INFO: $SFMfile line $line: Removed brackets from verse tag $1 -> $2\n");}
    # \v [xxx]
    while ($_ =~ s/((\\v\s+)\[([\s\d$ContinuationTerms]+)\])/$2$3/) {&Log("INFO: $SFMfile line $line: Removed brackets from verse tag $1 -> $2$3\n");}
    # \v x-[x]
    while ($_ =~ s/((\\v\s+\d+\s*[$ContinuationTerms]\s*)\[(\d+)\])/$2$3/) {&Log("INFO: $SFMfile line $line: Removed brackets from verse tag $1 -> $2$3\n");}
  
    # Each verse must start on new line
    if ($_ =~ s/([^^])\\v /$1\n\\v /g) {$fixedMultiVerseLines++;}
    
    print TMPO $_;
  }
  close(TMPI);
  close(TMPO);

  # Read the paratext file and convert it
  open(INF, "<:encoding(UTF-8)", $ThisSFM) or print getcwd." ERROR: Could not open file $ThisSFM.\n";
  
  if ($removedSoftHyphens) {&Log("INFO: Removed $removedSoftHyphens soft hyphens.\n");}
  if ($fixedMultiVerseLines) {&Log("INFO: Normalized $fixedMultiVerseLines lines with multiple verses.\n");}
  &Write("<div type=\"book\" osisID=\"$bookName\">\n");
 
  # Prepare vars for reading a new paratext file
  $inst=1;                # to distinguish multiple notes in a verse
  $noteNum=1;             # absolute note number used with footnote files
  $readText="";           # text collection
  $titleText="";          # title collection
  $endChapter="";         # end tag(s)
  $endVerse="";           # end tag(s)
  $myVerse="";            # current verse number
  $myChap="0";            # current chapter number
  $refChap="1";           # used to check that chapters are sequential
  $inIntroduction="1";    # are we in the introduction?
  $lastline = "";         # used to buffer verse text
  $HasChapterTag = 0;     # insure we find a chapter tag
  
  # BOOK PARSING SCHEME: 
  # Titles are captured and written at the beginning of the verse because, in SWORD, titles can only display before (and never inside) a verse
  # Verse text and formatting are captured as follows:
  #   Line 1 - >c1 --> Introduction
  #   c1<    - >v1 --> Ignore
  #   v1<    - >v2 --> Verse 1
  #   v2<    - >v3 --> Verse 2
  #   vlast< - >c2 --> Verse last
  #
  # Notes:
  #   Certain Psalm titles are canonical. If a blank CANONICAL_TITLE_1 tag is found, the next line is considered canonical
  #   Footnotes in introductions and titles/headings must be moved to next verse or ignored (see MOVE_TITLE_NOTES, MOVE_CHAPTER_NOTES)
   
  # Read the paratext file line by line
  $linem=0;
  $line=0;
  while (<INF>) {
    $linem++;
    $_ =~ s/([^\n\r\f])[\n\r\f]+$/$1/; # Fancy Chop for unicode DOS or Unix file types
    if ($_ =~ /^\s*$/) {next;}
    
    # lines which don't start with tags are first attached to the end of the previous line (so that footnotes which are split across lines can be matched)
    if ($_ !~ /^[\s]*(\\\w+)/) {
      if ($lastline !~ /[\s-]$/ && $_ !~ /^\s/) {$lastline = $lastline." ";} #insure there is white space between lines...
      $lastline = $lastline.$_;
      next;
    }
    $tmp = $_;
    &parseline($lastline);
    $line = $linem;
    $lastline = $tmp;
  }
  if ($lastline ne "") {&parseline($lastline);}
  
  # Each file now gets this ending
  if ($listStartPrinted eq "true") {$readText = "$readText</list>"; $listStartPrinted = "false";}
  if ($enumList1StartPrinted eq "true") {$readText = "$readText</list>"; $enumList1StartPrinted = "false";}
  if ($enumList2StartPrinted eq "true") {$readText = "$readText</list>"; $enumList2StartPrinted = "false";}
  if ($enumList3StartPrinted eq "true") {$readText = "$readText</list>"; $enumList3StartPrinted = "false";}
  &Write("$readText$endVerse</chapter>\n</div>\n");
  close (INF);
}
############################################

sub parseline($) {
  my $ln = shift;
  $_ = $ln;   
  $_ =~ s/\s*\/\/\s*/ /g; # Force carriage return SFM marker
  
  # replace paratext font tags
  if ($boldpattern)   {$_ =~ s/($boldpattern)/<hi type="bold">$+<\/hi>/g;}
  if ($italicpattern) {$_ =~ s/($italicpattern)/<hi type="italic">$+<\/hi>/g;}
  if ($removepattern) {$_ =~ s/($removepattern)//g;}
  
  if ($MOD eq "TKL" || $MOD eq "TKC") {$_ =~ s/\\ior\*?//g; $_ =~ s/\\iot\*//g;} # the iot* is a MISTAKE in the paratext!!
  
  # Find end of lists. Do this for all tags except $list1 and $list2
  if ($_ !~ /^[\s\W]*\\($list1|$list2)(\s+|$)(.*)/) {
    if ($listStartPrinted eq "true") {$readText = "$readText</list>";}
    $listStartPrinted = "false";
  }

  # selects when to reset enumerated list counters
  if ($_ !~ /^[\s\W]*\\($intropar|$blankline)(\s+|$)(.*)/) {
    # Do this for all tags except $enumList1
    if ($_ !~ /^\s*\\($enumList1)(\s+|$)(.*)/) {
      if ($enumList1StartPrinted eq "true") {$readText = "$readText</list>";}
      $enumList1StartPrinted = "false";
      if ($_ !~ /^[\s\W]*\\($enumList2|$enumList3)(\s+|$)/) {$enum1=0;}
    }
    # Do this for all tags except $enumList2
    if ($_ !~ /^[\s\W]*\\($enumList2)(\s+|$)(.*)/) {
      if ($enumList2StartPrinted eq "true") {$readText = "$readText</list>";}
      $enumList2StartPrinted = "false";
       if ($_ !~ /^\s*\\($enumList3)(\s+|$)/) {$enum2=0;}
    }
    # Do this for all tags except $enumList3
    if ($_ !~ /^[\s\W]*\\($enumList3)(\s+|$)(.*)/) {
      if ($enumList3StartPrinted eq "true") {$readText = "$readText</list>";}
      $enumList3StartPrinted = "false";
      $enum3=0;
    }
  }
  
  # Ignore tags on ignore-list
  if ($findalltags ne "true" && $_ =~ /^[\s\W]*\\($IgnoreTags)(\s|$)/) {} #&Log("WARNING $ThisSFM line $line: Ignoring $_.\n");}
  # FIND ALL TAGS but do nothing else
  elsif ($findalltags eq "true" && $_ =~ /^[\s\W]*(\\\w+)/) {
    $skippedTags{$1} = "$skippedTags{$1} $bookName:$_\n";
  }
  # \c CHAPTER MARKER
  elsif ($_ =~ /^[\s\W]*\\c\s*(\d+)(.*?)$/) {
    $myChap=$1;
    $myT = $2;
    $noteV=0;
    
    $HasChapterTag = 1;
    # sanity check that chapters are sequential (if SFM is bad)
    if ($myChap != $refChap) {&Log("ERROR: $ThisSFM Line $line ($bookName.$myChap)- chapter is not sequential!\n");}
    $refChap++;
    
    $inIntroduction="0";
    &Write("$readText$endVerse$endChapter\n<chapter osisID=\"$bookName.$myChap\">\n");
    $readText="";
    $endVerse="";
    $endChapter="</chapter>";
    if ($MoveChapterNotes eq "true") {
      $noteVerseNum = 1;
      &encodeNotes;
      while ($myT =~ s/(<note.*?<\/note>)//) {
        $titleNotes = "$titleNotes$1";
        &Log("INFO line $line: Note for chapter $bookName $myChap moved to verse 1.\n");
      }
    }
  }
  # \v VERSE MARKER
  elsif ($_ =~ /^[\s\W]*\\v\s+([\d|$ContinuationTerms]+)\s+(.*)/) {
    $inst=1;
    $myV = $1;
    $myT = "$titleNotes$2";
    $titleNotes="";
    $myV =~ s/($ContinuationTerms)+/-/;
    
    if (!$HasChapterTag) {&Log("ERROR: No \"\\c 1\" chapter tag found. This tag is required before verse 1.\n");}
    
    # CLUDGE
    # If this is a hyphenated verse name, then see if left verse number has footnotes. If not, then use right verse number
    if ($myV =~ /(\d+)-(\d+)/) {
      $nV = $1;
      if ($notes{"$bookName,$myChap,$nV,$inst"} eq "") {$nV = $2;}
    }
    else {$nV = $myV;}
    
    $noteVerseNum = $nV;
    &encodeNotes;
    
    # Get any titles that were collected
    $verseTitle = "";
    if ($titleText ne "") {
      $verseTitle = $titleText.$INDENT;
      $titleText="";
    }
    
    # If this is the first verse of chapter, ignore everything before this first verse, otherwise, print previously collected stuff
    if ($readText =~ /<verse[^>]+>.+/) {
      # if an indent will be followed by a title, remove that indent.
      if ($verseTitle ne "") {$readText =~ s/$INDENT$//;}
      &Write("$readText$endVerse");
      $prepend = "";
    }
    else {
      $prepend = $readText;
      # don't allow too much space between verse one's number and the verse text
      if ($prepend =~ s/(<lb \/>|$INDENT)+\s*$/$INDENT/) {
        if ($prepend =~ /^$INDENT$/) {
          $verseTitle =~ s/(<lb \/>|$INDENT)+\s*$//;
        }
      }      
    }
    
    # If an empty canonical title marker was previously found, process the current verse line as a canonical title
    if ($nextVerseIsCanonTitle eq "true") {
      $ignoreNextLB="t";
      $canonTitle="$canonTitle $myT";
      $titleText="";
      $myT="";
    }
    # Save current verse in print buffer 
    $readText = "<verse sID=\"$bookName.$myChap.$myV\" osisID=\"$bookName.$myChap.$myV\"/>$verseTitle$prepend$myT";
    $endVerse = "<verse eID=\"$bookName.$myChap.$myV\"/>\n";
  
    $myVerse=$myV;
    $noteV=$nV;
  }
  
  ################## PARATEXT FILE HEADER MARKERS ######################

  # INTRODUCTION MAJOR TITLE TAG
  elsif ($_ =~ /^[\s\W]*\\($IntroFstTitle)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    $readText = "$readText<lb /><lb /><title level=\"1\" type=\"x-intro\">$myT</title>";
  }
  # INTRODUCTORY PARAGRAPH
  elsif ($_ =~ /^[\s\W]*\\($intropar)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    $readText = "$readText<lb />$INDENT$myT";
  }
  # LIST TITLE MARKER
  elsif ($_ =~ /^[\s\W]*\\($listtitle)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    $readText = "$readText<lb /><lb /><title level=\"2\" type=\"x-intro\">$myT</title>";
  }
  # LIST ENTRY
  elsif ($_ =~ /^[\s\W]*\\($list1)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($listStartPrinted ne "true") {$listStart = "<list type=\"x-list-1\">";}
    else {$listStart = "";}
    $readText = "$readText$listStart<item type=\"x-listitem\">$myT</item>";
    $listStartPrinted = "true";
  }
  # BULLET LIST ENTRY
  elsif ($_ =~ /^[\s\W]*\\($list2)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($listStartPrinted ne "true") {$listStart = "<list type=\"x-list-2\">";}
    else {$listStart = "";}
    $enum4 = chr(8226) . " -";
    $readText = "$readText$listStart<item type=\"x-listitem\">$enum4 $myT</item>";
    $listStartPrinted = "true";
  }
  # ENUMERATED LIST 1 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList1)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList1StartPrinted ne "true") {$listStart = "<list type=\"x-enumlist-1\">";}
    else {$listStart = "";}
    $readText = "$readText$listStart<item type=\"x-listitem\">$Roman[$enum1++]. $myT</item>";
    if ($enum1 > 20) {&Log("ERROR $ThisSFM line $line: $bookName $myChap:$myVerse ROMAN ENUMERATION TOO HIGH.\n");}
    $enumList1StartPrinted = "true";
  }
  # ENUMERATED LIST 2 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList2)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList2StartPrinted ne "true") {$listStart = "<list type=\"x-enumlist-2\">";}
    else {$listStart = "";}
    $enum2++;
    $readText = "$readText$listStart<item type=\"x-listitem\">$enum2. $myT</item>";
    $enumList2StartPrinted = "true";
  }
  # ENUMERATED LIST 3 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList3)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList3StartPrinted ne "true") {$listStart = "<list type=\"x-enumlist-3\">";}
    else {$listStart = "";}
    $enum = lc($Roman[$enum3++]);
    $readText = "$readText$listStart<item type=\"x-listitem\">$enum. $myT</item>";
    if ($enum3 > 20) {&Log("ERROR $ThisSFM line $line: $bookName $myChap:$myVerse ROMAN ENUMERATION TOO HIGH.\n");}
    $enumList3StartPrinted = "true";
  }
  ################## PARATEXT TITLE MARKERS ######################
  # SECTION HEAD MARKERS
  elsif ($_ =~ /^[\s\W]*\\($FstTitle)(\s+|$)(.*)/) {
    $myT=$3;
    if ($MoveTitleNotes eq "true") {
      $noteVerseNum = $noteV+1; #the +1 is because the title corresponds to the NEXT verse
      &encodeNotes;
      while ($myT =~ s/(<note.*?<\/note>)//) {
        $titleNotes = "$titleNotes$1";
        &Log("INFO line $line: Note in title was moved to $bookName $myChap:$noteVerseNum.\n");
      }
    }
    else {while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in heading ignored.\n");}}
    if ($inIntroduction eq "1") {$readText = "$readText<title level=\"1\" type=\"x-intro\">$myT</title>";}
    else {
      $titleText = "$titleText<title ".$PreverseTitleType."subType=\"x-preverse\" level=\"1\">$myT</title>";
    }
  }
  # SECONDARY TITLE MARKER
  elsif ($_ =~ /^[\s\W]*\\($SecTitle)(\s+|$)(.*)/) {
    $myT=$3;
    if ($MoveTitleNotes eq "true") {
      $noteVerseNum = $noteV+1; #the +1 is because the title corresponds to the NEXT verse
      &encodeNotes;
      while ($myT =~ s/(<note.*?<\/note>)//) {
        $titleNotes = "$titleNotes$1";
        &Log("INFO line $line: Note in title was moved to $bookName $myChap:$noteVerseNum.\n");
      }
    }
    else {while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in heading ignored.\n");}}
    if ($inIntroduction eq "1") {$readText = "$readText<title level=\"2\" type=\"x-intro\">$myT</title>";}
    else {
      $titleText = "$titleText<title ".$PreverseTitleType."subType=\"x-preverse\" level=\"2\">$myT</title>";
    }
  }
  # CANONICAL TITLE LEVEL 1
  elsif ($_ =~ /^[\s\W]*\\($canonicaltitle)(\s+|$)(.*)/) {
    $myT=$3;
    # If canonical title marker is blank, then next verse will be formatted as a title
    if ($myT eq "") {$nextVerseIsCanonTitle = "true";}
    else {
      if ($MoveTitleNotes eq "true") {
        $noteVerseNum = $noteV+1; #the +1 is because the title corresponds to the NEXT verse
        &encodeNotes;
        while ($myT =~ s/(<note.*?<\/note>)//) {
          $titleNotes = "$titleNotes$1";
          &Log("INFO line $line: Note in title was moved to $bookName $myChap:$noteVerseNum.\n");
        }
      }
      else {while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in heading ignored.\n");}}
      if ($inIntroduction eq "1") {$readText = "$readText<title canonical=\"true\" level=\"1\" type=\"x-intro\">$myT</title>";}
      else {
        $titleText = "$titleText<title ".$PreverseTitleType."canonical=\"true\" subType=\"x-preverse\" level=\"1\">$myT</title>";
      }
    }
  }
  # sh - UZV secondary headings in Psalms are canonical!
  # CANONICAL TITLE LEVEL 2
  elsif ($_ =~ /^[\s\W]*\\($canonicaltitle2)(\s+|$)(.*)/) {
    $myT=$3;
    if ($MoveTitleNotes eq "true") {
      $noteVerseNum = $noteV+1; #the +1 is because the title corresponds to the NEXT verse
      &encodeNotes;
      while ($myT =~ s/(<note.*?<\/note>)//) {
        $titleNotes = "$titleNotes$1";
        &Log("INFO line $line: Note in title was moved to $bookName $myChap:$noteVerseNum.\n");
      }
    }
    else {while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in heading ignored.\n");}}
    if ($inIntroduction eq "1") {$readText = "$readText$titleText<title canonical=\"true\" level=\"2\" type=\"x-intro\">$myT</title>";}
    else {
      $titleText = "$titleText<title ".$PreverseTitleType."canonical=\"true\" subType=\"x-preverse\" level=\"2\">$myT</title>";
    }
  }
  ################## PARATEXT PARAGRAPH AND POETRY MARKERS ######################
  # PARAGRAPH MARKER
  elsif ($_ =~ /^[\s\W]*\\($normpar|$doublepar|$triplepar)(\s+|$)(.*)/) {
    $myT = $3;
    $tag = $1;
    $noteVerseNum = $noteV;
    &encodeNotes;
    $EmptyLine = ""; #($myT ? "":"<lb />");
    # After canonical title, we need no line break, and if empty, we need nothing at all
    if ($ignoreNextLB eq "t") {
      $ignoreNextLB="";
      $nextVerseIsCanonTitle = "false";
      &Write("$titleText<title ".$PreverseTitleType."canonical=\"true\" subType=\"x-preverse\" level=\"1\">$canonTitle</title>\n");
      $canonTitle="";
      if ($myT ne "") {$readText = "$readText$myT";}
      else {$readText="";}
    }
    elsif($tag =~ /^($doublepar)$/) {$readText = "$readText<lb />$EmptyLine$INDENT$INDENT$myT";}
    elsif($tag =~ /^($triplepar)$/) {$readText = "$readText<lb />$EmptyLine$INDENT$INDENT$INDENT$myT";}
    else {$readText = "$readText<lb />$EmptyLine$INDENT$myT";}
  }
  # BLANK LINE MARKER
  elsif ($_ =~ /^[\s\W]*\\($blankline)(\s+|$)(.*)/) {
    $myT = $3;
    $noteVerseNum = $noteV;
    &encodeNotes;
    $EmptyLine = ""; #($myT ? "":"<lb />");
    $readText = "$readText<lb />$EmptyLine$myT";
  }
  # ALL OTHER TAGS
  elsif ($_ =~ /^[\s\W]*(\\\w+)/) {
    $skippedTags{$1} = "$skippedTags{$1} $bookName:$_\n";
    &Log("ERROR $ThisSFM Line $line: Unhandled tag, line was skipped $_\n");
  }
  # LINE WITH NOTHNG AT ALL
  elsif ($_ =~ /^\s*$/) {}
  # ELSE APPEND TO PREVIOUS TAG
  else {
    &Log("ERROR $ThisSFM Line $line: Line starting without a tag should have been handled already=$_\n");
    $myT = $_;
    $noteVerseNum = $noteV;
    &encodeNotes;
    $readText = "$readText $myT";
  }
}
#####################################
    
sub encodeNotes {
  # Convert cross references if any
  if ($crossrefs ne "") {
    while ($myT =~ /($crossrefs)/) {
      $note = $+;
      if ($inIntroduction eq "1") {
        &Log("WARNING $ThisSFM Line $line: Footnote in intro was removed - \"".$note."\"\n");
        $myT =~ s/($crossrefs)//;
      }
      else {
        my $osrf = "$bookName.$myChap.$myV";
        $osrf =~ s/\s*-\s*\d+$//; # don't allow continuation here
        my $osid = $osrf."!crossReference.r".++$OSISID{$osrf."!crossReference"};
				$myT =~ s/($crossrefs)/<note type=\"crossReference\" osisRef=\"$osrf\" osisID=\"$osid\">$note<\/note>/;
			}
    }
  }
  # Convert glossary entries if any
  if ($glossaryentries) {
    if (!$glossaryname) {&Log("ERROR $ThisSFM line $line: GLOSSARY specified, but GLOSSARY_NAME is null.\n");}
    $myT =~ s/$glossaryentries/my $a = $+; my $res = "<reference type=\"x-glossary\" osisRef=\"$glossaryname:".&encodeOsisRef(&suc($a, $SpecialCapitals))."\">$a<\/reference>";/ge;
  }
  # Use notes read from file...
  if ($NoteType eq "WITHREFS") {
    # Replace all "*"s in line with note data and increment inst after each replacement
    while ($myT =~ s/\*/<note type=\"study\" osisRef=\"$bookName.$myChap.$noteVerseNum\" osisID=\"$bookName.$myChap.$noteVerseNum!$inst\">$notes{"$bookName,$myChap,$noteVerseNum,$inst"}<\/note>/) {
      if ($notes{"$bookName,$myChap,$noteVerseNum,$inst"} eq "") {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$noteVerseNum #$inst Note not found.\n");}
      if ($inIntroduction eq "1") {&Log("ERROR $ThisSFM Line $line: Footnote was placed in introduction.\n");}
      $notes{"$bookName,$myChap,$noteVerseNum,$inst"}="e"; 
      $inst++;
    }
  }
  # Use note read from file, and if note has location in it, remove location and check that refs match.
  elsif ($NoteType eq "NOREFS") {
    # Replace all "*"s in line with note data and increment inst after each replacement
    while ($myT =~ /\*/) {
      if ($notes{"$bookName,$noteNum"} =~ s/^(.*?),(\d+),(.*?),//) {
        $b=$1; $c=$2; $v=$3; $f="false";
        if ($v =~ /(\d+)-(\d+)/) {
          $v1=$1; $v2=$2;
          if (($bookName ne $b) or ($myChap ne $c) or ($noteVerseNum < $v1) or ($noteVerseNum > $v2)) {$f="true";}
        }
        elsif (($bookName ne $b) or ($myChap ne $c) or ($noteVerseNum ne $v)) {$f="true";}
        if ($f eq "true") {&Log("WARNING $ThisSFM line $line: Note marked as \"$b $c:$v\" found in \"$bookName $myChap:$noteVerseNum\".\n");}
      }
      $myT =~ s/\*/<note type=\"study\" osisRef=\"$bookName.$myChap.$noteVerseNum\" osisID=\"$bookName.$myChap.$noteVerseNum!$inst\">$notes{"$bookName,$noteNum"}<\/note>/;
      if ($notes{"$bookName,$noteNum"} eq "") {&Log("ERROR $ThisSFM line $line: $bookName note #$noteNum not found.\n");}
      if ($inIntroduction eq "1") {&Log("ERROR $ThisSFM Line $line: Footnote was placed in introduction.\n");}
      $notes{"$bookName,$noteNum"}="e"; 
      $noteNum++;
      $inst++;
    }
  }
  elsif ($NoteType eq "INLINE" && $notePattern) {
    while ($myT =~ /($notePattern)/) {
      $note = $+;
      if ($inIntroduction eq "1") {
        &Log("WARNING $ThisSFM Line $line: Footnote in intro was removed - \"".$note."\"\n");
        $myT =~ s/($notePattern)//;
      }
      else {$myT =~ s/($notePattern)/<note type=\"study\" osisRef=\"$bookName.$myChap.$noteVerseNum\" osisID=\"$bookName.$myChap.$noteVerseNum!$inst\">$note<\/note>/;}
      $inst++;
    }
  }
  else {
    $myT =~ s/\*//g;
  }
}
#####################################

sub readFootNoteFileWithRefs {
  undef %notes;
  &Log("Processing Footnotes file \"$NoteFileName\" with refs.\n");
  open (NFLE, "<:encoding(UTF-8)", $NoteFileName) or print "ERROR: Could not open file $NoteFileName.\n";
  $line=0;
  while (<NFLE>) {
    $line++;
  
    $_ =~ s/([^\n\r\f]+)[\n\r\f]+/$1/; # Fancy Chomp
    # Find Book Name, chapter, and verse
    if ( ($_ =~ /^\\id\s*(\S+)\s+([\d-]+):?([\d-]+)?/) || ($_ =~ /^\\id\s*(\S+)\s+\[(Intro)duction\]/) ) {
      $bnm = $1;
      if ($2 eq "Intro") {$ct = $2;  $vt = "";} #If this is an introduction footnotes
      elsif ($3 eq "")   {$ct = "1"; $vt = $2;} #If this book has only one chapter
      else               {$ct = $2;  $vt = $3;} #Normal ch:vs reference
      
      if ($vt =~ /(\d+)-(\d+)/) {$vt = $2;}     #If this is a hyphenated verse, use last verse         
      if ($_ =~ /RSO\s+(\d+):(\d+)/) {$ct = $1; $vt = $2;}
      
      $bookName = &getOsisName($bnm);
    }
    # Get text for normal Notes
    elsif ($_ =~ /^\\\w+\s*\|b([\d-]+):?(\d+)?\|r\s*(.*)/) {
      if (($2 eq $v)&&($1 eq $c)) {$inst++;}
      else {$inst = 1;}
      $c = $1;
      $v = $2;
      $t = $3;
      $t =~ s/\|i([^\|]*)\|r/<hi type="italic">$1<\/hi>/g;
      $t =~ s/\|b([^\|]*)\|r/<hi type="bold">$1<\/hi>/g;
      $notes{"$bookName,$ct,$vt,$inst"} = $t;
    }
    # Get text for notes covering multiple verses
    elsif ($_ =~ /^\\\w+\s*\|b(\d+):(\d+)-(\d+)\|r\s*(.*)/) {
      if (($2 eq $v1)&&($3 eq $v2)&&($1 eq $c)) {$inst++;}
      else {$inst = 1;}
      $c = $1;
      $v1 = $2;
      $v2 = $3;
      $t = "\($2-$3\) $4";
      #&Log("INFO 1: $bookName,$c,$v,$inst Footnote covered multiple verses.\n");
      $t =~ s/\|i([^\|]*)\|r/<hi type="italic">$1<\/hi>/g;
      $t =~ s/\|b([^\|]*)\|r/<hi type="bold">$1<\/hi>/g;
      $notes{"$bookName,$ct,$vt,$inst"} = $t;
    }
    # If this is still an "fuz" footnote, check if we're in intro footnote, otherwise it was not recognized so give a message!
    elsif ($_ =~ /^(\\\w+)\s*(.*)/) {
      if ($ct eq "Intro") {$notes{"$bookName,$ct,,1"} = $2;}
      else {&Log("WARNING $ThisSFM line $line: $1 Footnote was not processed.\n");}
    }
    # If blank, ignore
    elsif ($_ =~ /^\s*$/) {}
    # If this is not an "fuz" footnote or blank, assume it is a part of the last footnote: tack this line to last one
    else {
      $t = "$t $_";
      $t =~ s/\|i([^\|]*)\|r/<<hi type="italic">>$1<\/hi>/g;
      $t =~ s/\|b([^\|]*)\|r/<hi type="bold">$1<\/hi>/g;
      $notes{"$bookName,$ct,$vt,$inst"} = $t; 
      #&Log("INFO 2: $bookName,$c,$v,$inst WAS CONTINUED\n");
    }
    
    # Replace i|text|r with OSIS italic marker
    #$t =~ s/\|i([^\|]*)\|r/<hi type=\"italic\">$1<\/hi>/g;
  }
}
#####################################

sub readFootNoteFileWithoutRefs {
  undef %notes;
  open (NFLE, "<:encoding(UTF-8)", $NoteFileName) or print "ERROR: Could not open file $NoteFileName.\n";
  $NoteFileName =~ /\\(...) /; 
  $bookName = &getOsisName($1); 
  $noteNum=1;
  $line=0;
  while (<NFLE>) {
    $line++;
    
    if ($_ =~ /^\s*$/) {next;}
    $_ =~ s/\s+$//; # Fancy Chomp
    $_ =~ s/\|i([^\|]*)\|r/<hi type="italic">$1<\/hi>/g;
    $thisNote = "$bookName,$noteNum";
    # Start of New Book...
    if ($_ =~ /^\w\w\w$/) {
      $noteNum=1;
      $bnm = $_;
      $bookName = &getOsisName($bnm);
    }
    # If no tag, append to previous line...
    elsif ($_ !~ /^[\s\W]*\\/) {
      $prevNoteNum = $noteNum-1;
      $thisNote = "$bookName,$prevNoteNum";
      $notes{$thisNote} = "$notes{$thisNote} $_";
    }
    # fuz tag...
    elsif ($_ =~ /\\fuz/) {
      if ($_ =~ s/^[\s\W]*\\fuz \|b(\d+):(.*?)\|r //) {
        $c=$1; $v=$2;
        if ($v =~ /(\d+)-(\d+)/) {$_ = "($v) $_";} 
        $notes{$thisNote} = "$bookName,$c,$v,$_";
        #&Log("Read Note: $thisNote $notes{$thisNote}\n");
        $noteNum++;
      }
      elsif ($_ =~ s/^[\s\W]*\\fuz \|b(\d+)\|r //) {
        $c=$1; $v=1;
        if ($v =~ /(\d+)-(\d+)/) {$_ = "($v) $_";}
        $notes{$thisNote} = "$bookName,$c,$v,$_";
        #&Log("Read Note: $thisNote $notes{$thisNote}\n");
        $noteNum++;
      }
      else {
        $_ =~ /^(........................)/;
        &Log("WARNING 245 $ThisSFM line $line: Unusual note ignored in $bookName: $1\n");
      }
    }
    # Other tags...
    else {
      $_ =~ s/^\\\w+//;
      $notes{$thisNote} = $_;
      $noteNum++;    
    }
  }
}

sub checkRemainingNotes {
  # Check that all Notes were copied to OSIS
  $placed = 0;
  foreach $ch (keys %notes) {
    if ($notes{$ch} eq "e") {$placed++; next;}
    else {
      $notes{$ch} =~ /^(........................)/;
      &Log("WARNING 5: $ch: Note \"$1\" was not copied to OSIS file\n");
    }
  }
  $numNotes = keys %notes;
  &Log("$placed of $numNotes notes collected from \"$NoteFileName\" were placed.\n");
}

sub Write($) {
  my $print = shift;
  
  # change all book.ch.vs1-vs2 osisIDs to book.ch.vs1 book.ch.vs2 for OSIS schema validation
  while ($print =~ s/(<verse [^>]*osisID=")([^\.]+\.\d+\.)(\d+)-(\d+)"/workingID/) {
    $vt = $1; $bkch = $2; $v1 = 1*$3; $v2 = 1*$4; $sep = "";
    while ($v1 <= $v2) {$vt = "$vt$sep$bkch$v1"; $sep=" " ; $v1++}
    $print =~ s/workingID/$vt\"/;
  }
  
  # make sure we don't get more than one blank line between verses
  $print =~ s/(<lb[^\/]*\/><lb[^\/]*\/>)(<lb[^\/]*\/>)+/$1/g;
  
  while ($print =~ s/(\\([\w]*)\*?)//) {
    $tag = $2;
    $tagsintext = $tagsintext."WARNING Before $ThisSFM Line $line: Tag \"$1\" in \"$bookName\" was REMOVED.\n";
  }
  print OUTF $print;
}
