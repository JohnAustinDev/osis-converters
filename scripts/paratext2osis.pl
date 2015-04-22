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
#   EXIT - Exit the script at this point. Useful for debug.

# COMMAND FILE FORMATTING RELATED SETTINGS:
#   IGNORE - A tag-list of SFM lines which should be ignored.
#   INTRO_TITLE_1 - A tag-list representing titles used in a 
#       book introduction.
#   INTRO_PARAGRAPH - A tag-list for paragraphs used in a 
#       book introduction.
#   LIST_TITLE - A tag-list for list titles used in a 
#       book introduction.
#   LIST_ENTRY - A tag-list for basic list entries used in a 
#       book introduction.
#   LIST_ENTRY_BULLET - A tag-list for bulleted list entries used in a 
#       book introduction.
#   ENUMERATED_LIST_LEVEL1 - A tag-list for enumerated Roman numeral 
#       capitals primary lists used in a 
#       book introduction.
#   ENUMERATED_LIST_LEVEL2 - A tag-list for enumerated arabic numeral 
#       secondary lists used in a 
#       book introduction.
#   ENUMERATED_LIST_LEVEL3 - A tag-list for enumerated Roman numeral 
#       small tertiary lists used in a 
#       book introduction.
#   TITLE_1 - A tag-list for main headings.
#   TITLE_2 - A tag-list for secondary headings.
#   CANONICAL_TITLE_1 - A tag-list for main canonical headings.
#   CANONICAL_TITLE_2 - A tag-list for secondary canonical headings.
#   PARAGRAPH[0-3] - A tag-list for paragraphs. 0=no-indent, 1=normal, 2+=left-margin indented
#   PARAGRAPH - Same as PARAGRAPH1.
#   LINE[0-3] - Poetry line indented 0 to 3x (the line should NOT cross verse boundaries)
#   ITEM[0-3] - List item indented 0 to 3x (the item should NOT cross verse boundaries)
#   BLANK_LINE - A tag-list for blank lines

# COMMAND FILE TEXT PROCESSING SETTINGS:
#   BOLD - Perl regular expression to match any bold text.
#   ITALIC - Perl regular expression to match any italic text.
#   SUPER - Perl regular expression to match any super script text.
#   SUB - Perl regular expression to match any sub script text.
#   REMOVE - A Perl regular expression for bits to be removed from SFM. 
#   REPLACE - A Perl replacement regular expression to apply to text.     

# COMMAND FILE FOOTNOTE SETTINGS:
#   FOOTNOTE - A Perl regular expression to match all SFM footnotes.
#   CROSSREF - For inline cross references. See FOOTNOTES
#   FOOTNOTES_WITHREFS - (rarely used) A footnote file whose footnotes 
#       have refs
#   FOOTNOTES_NOREFS - (rarely used) A footnote file whose footnotes 
#       don't have refs

# COMMAND FILE GLOSSARY/DICTIONARY RELATED SETTINGS:
#   GLOSSARY - A Perl regular expression to match SFM glossary links.
#   GLOSSARY_NAME - Name of glossary module targetted by glossary links.

&Log("-----------------------------------------------------\nSTARTING paratext2osis.pl\n\n");

# Read the COMMANDFILE, converting each book as it is encountered
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open paratext2osis command file $COMMANDFILE\n";
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
$FstCanonTitle="none";
$SecCanonTitle="none";
@paragraph = ("none", "none", "none", "none");
@poetryline = ("none", "none", "none", "none");
@listitem = ("none", "none", "none", "none");
$boldpattern="";
$italicpattern="";
$superpattern="";
$subpattern="";
$MoveTitleNotes="true";
$MoveChapterNotes="true";
$SpecialCapitals="";
$removepattern="";
$notePattern="";
$NoteType="INLINE";
$replace1="";
$replace2="";
$AllowSet = "addScripRefLinks|addDictLinks|addCrossRefs|usfm2osis";
$addScripRefLink=0;
$addDictLinks=0;
$addCrossRefs=0;
$usfm2osis=0;

$line=0;
while (<COMF>) {
  $line++;
  
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  # VARIOUS SETTINGS...
  elsif ($_ =~ /^SET_($AllowSet):(\s*(\S+)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = $val;
      if ($par =~ /^(addScripRefLinks|addDictLinks|addCrossRefs)$/) {
        $$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
      }
      &Log("INFO: Setting $par to $$par\n");
    }
  }
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
  elsif ($_ =~ /^EXIT:(\s*(.*?)\s*)?$/) {if ($1) {if ($2 !~ /^(0|false)$/i) {last;}}}
  # FORMATTING TAGS...
  elsif ($_ =~ /^IGNORE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IgnoreTags = $2; next;}}    
  elsif ($_ =~ /^INTRO_TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IntroFstTitle = $2; next;}}
  elsif ($_ =~ /^INTRO_PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$intropar = $2; next;}}
  elsif ($_ =~ /^TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$FstTitle = $2; next;}}
  elsif ($_ =~ /^TITLE_2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$SecTitle = $2; next;}}
  elsif ($_ =~ /^CANONICAL_TITLE_1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$FstCanonTitle = $2; next;}}
  elsif ($_ =~ /^CANONICAL_TITLE_2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$SecCanonTitle = $2; next;}}
  elsif ($_ =~ /^LIST_TITLE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$listtitle = $2; next;}}
  elsif ($_ =~ /^LIST_ENTRY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$list1 = $2; next;}}
  elsif ($_ =~ /^LIST_ENTRY_BULLET:(\s*\((.*?)\)\s*)?$/) {if ($1) {$list2 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList1 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList2 = $2; next;}}
  elsif ($_ =~ /^ENUMERATED_LIST_LEVEL3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$enumList3 = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH(\d+):(\s*\((.*?)\)\s*)?$/) {if ($2) {@paragraph[$1] = $3; next;}}
  elsif ($_ =~ /^PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {@paragraph[1] = $2; next;}}
  elsif ($_ =~ /^LINE(\d+):(\s*\((.*?)\)\s*)?$/) {if ($2) {@poetryline[$1] = $3; next;}}
  elsif ($_ =~ /^ITEM(\d+):(\s*\((.*?)\)\s*)?$/) {if ($2) {@listitem[$1] = $3; next;}}
  elsif ($_ =~ /^BLANK_LINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$blankline = $2; next;}}
  elsif ($_ =~ /^REMOVE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$removepattern = $2; next;}}
  # TEXT TAGS...
  elsif ($_ =~ /^BOLD:(\s*\((.*?)\)\s*)?$/) {if ($1) {$boldpattern = $2; next;}}
  elsif ($_ =~ /^ITALIC:(\s*\((.*?)\)\s*)?$/) {if ($1) {$italicpattern = $2; next;}}
  elsif ($_ =~ /^SUPER:(\s*\((.*?)\)\s*)?$/) {if ($1) {$superpattern = $2; next;}}
  elsif ($_ =~ /^SUB:(\s*\((.*?)\)\s*)?$/) {if ($1) {$subpattern = $2; next;}}
  elsif ($_ =~ /^CROSSREF:(\s*\((.*?)\)\s*)?$/) {if ($1) {$crossrefs = $2; next;}}
  elsif ($_ =~ /^GLOSSARY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$glossaryentries = $2; next;}}
  elsif ($_ =~ /^FOOTNOTE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$notePattern = $2; next;}}
  elsif ($_ =~ /^GLOSSARY_NAME:(\s*(.*?)\s*)?$/) {if ($1) {$glossaryname = $2; next;}}
  elsif ($_ =~ /^REPLACE:(\s*s\/(.*?)\/(.*?)\/\s*)?$/) {if ($1) {$replace1 = $2; $replace2 = $3; next;}}

  # OT command...
  elsif ($_ =~ /^OT\s*$/) {
    &Write("<div type=\"bookGroup\">\n", 1);
    $Testament="OT";
    $endTestament="</div>";
  }
  # NT command...
  elsif ($_ =~ /^NT\s*$/) {
    $Testament="NT";
    &Write("$endTestament\n<div type=\"bookGroup\">\n", 1);
    $endTestament="</div>";
  }
  # FOOTNOTES_ command...
  elsif ($_ =~ /^FOOTNOTES_([^:]+)/) {
    $NoteType = $1;
    if (keys %notes > 0) {&checkRemainingNotes;}
    $_ =~ /^[^:]+:\s*(.*)/;
    $NoteFileName = "$INPD/".$1;
    $NoteFileName =~ s/\\/\//g;
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
    if ($SFMfile =~ /^\./) {
      chdir($INPD);
      $SFMfile = File::Spec->rel2abs($SFMfile);
      chdir($SCRD);
    }
    if ($usfm2osis) {$USFMfiles .= $SFMfile . " ";}
    else {&bookSFMtoOSIS;}
  }
  else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}

close(COMF);

if ($usfm2osis) {
  &USFMtoISIS;
}
else {
  # Write closing tags, and close the output file
  &Write("$endTestament\n</osisText>\n</osis>\n", 1);
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
  foreach $tag (sort keys %skippedTags) {
    #&Log("$skippedTags{$tag}"); #complete printout
    &Log("$tag "); #brief printout
  }

  &Log("\nFollowing are unhandled tags which where removed from the text:\n$tagsintext");
}

&Log("\nEnd of listing\n");
1;

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------


sub USFMtoISIS {
  &Log("Processing USFM $USFMfiles\n");
  my $cmd = "usfm2osis.py Bible.$MOD -v -x -r -o $OUTPUTFILE $USFMfiles";
  &Log($cmd . "\n", 1);
  &Log(`$cmd` . "\n", 1);
}

sub bookSFMtoOSIS {
  @AllTags = ();
  @AllLineNums = ();
  @PrintOut = ();

  # Get the name of the book from the file name
  if ($NameMatch eq "") {$SFMfile =~ /\/(\w+)\.[^\/]+$/; $bnm=$1;}
  else {$SFMfile =~ /$NameMatch/; $bnm=$1;}
  $bookName = &getOsisName($bnm);
  
  &Log("Processing $bookName\n");
  &logProgress($bookName);
  
  $NoNestTags = "";
  foreach my $p (@paragraph) {$NoNestTags .= $p."|";}
  foreach my $p (@poetryline) {$NoNestTags .= $p."|";}
  foreach my $p (@listitem) {$NoNestTags .= $p."|";}
  $NoNestTags =~ s/\|$//;
  
  # First make a copy of the SFM file, insuring \v tags always begin a line
  my $sfmname = $SFMfile;
  $sfmname =~ s/^.*?([^\/\\]*)$/$1/;
  $ThisSFM = "$TMPDIR/$sfmname";
  &normalizeNewLines($SFMfile);
  open(TMPI, "<:encoding(UTF-8)", $SFMfile) or print getcwd." ERROR: Could not open file $SFMfile.\n";
  open(TMPO, ">:encoding(UTF-8)", $ThisSFM) or die "ERROR: Could not open temporary SFM file $ThisSFM\n";
  $removedSoftHyphens = 0;
  $removedOnLine = 0;
  $fixedMultiVerseLines = 0;
  $replacedOnLine = 0;
  $line = 0;
  while(<TMPI>) {  
    $line++;
    # Remove soft hyphens
    my $sh = decode("utf8", "­");
    utf8::upgrade($sh);
    if ($_ =~ s/$sh//g) {$removedSoftHyphens++;}
    
    # Global REMOVE
    if ($removepattern) {
      if ($_ =~ s/($removepattern)//g) {$removedOnLine++;}
    }
      
    # Global REPLACE
    if ($replace1) {
      if ($replace2 =~ /\$/) {
        my $r;
        if ($_ =~ s/$replace1/$r = eval($replace2);/eg) {&Log("INFO: Replaced /$replace1/ with /$r/.\n"); {$replacedOnLine++;}}
      }
      else {
        if ($_ =~ s/$replace1/$replace2/g) {&Log("INFO: Replaced /$replace1/ with /$replace2/.\n"); {$replacedOnLine++;}}
      }
    }
    
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
  if ($removedOnLine) {&Log("INFO: Applied REMOVE on $removedOnLine lines.\n");}
  if ($replacedOnLine) {&Log("INFO: Replaced /$replace1/ with /$replace2/ on $replacedOnLine lines.\n");}
  if ($removedSoftHyphens) {&Log("INFO: Removed soft hyphens on $removedSoftHyphens lines.\n");}
  if ($fixedMultiVerseLines) {&Log("INFO: Normalized $fixedMultiVerseLines lines with multiple verses.\n");}
  &Write("<div type=\"book\" osisID=\"$bookName\">\n");
 
  # Prepare vars for reading a new paratext file
  $inst=1;                # to distinguish multiple notes in a verse
  $noteNum=1;             # absolute note number used with footnote files
  $readText="";           # text collection
  
  $endChapter="";         # end tag(s)
  $endVerse="";           # end tag(s)
  $endParagraph="";      # end tag(s)
  $endSection="";        # end tag(s)
  $endTitle="";          # end tag(s)
  
  $lastLineLevel = -99;
  
  $myVerse="";            # current verse number
  $myChap="0";            # current chapter number
  $refChap="1";           # used to check that chapters are sequential
  $inIntroduction="1";    # are we in the introduction?
  $lastline = "";         # used to buffer verse text
  $HasChapterTag = 0;     # insure we find a chapter tag
  
  # BOOK PARSING SCHEME: 
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
   
  # Read the paratext file line by line into memory
  $linem=0;
  $line=0;
  while (<INF>) {
    $linem++;
    $_ =~ s/([^\n\r\f])[\n\r\f]+$/$1/; # Fancy Chop for unicode DOS or Unix file types
    if ($_ =~ /^\s*$/) {next;}
    
    # lines which don't start with tags are first attached to the end of the previous line (so that footnotes which are split across lines can be matched)
    if ($_ !~ /^[\s]*(\\\w+)/) {
      if ($lastline !~ /[\s-]$/ && $_ !~ /^\s/) {$lastline .= " ";} #insure there is white space between lines...
      $lastline .= $_;
      next;
    }
    $tmp = $_;
    push(@AllTags, $lastline);
    push(@AllLineNums, $line);
    $line = $linem;
    $lastline = $tmp;
  }
  if ($lastline ne "") {
    push(@AllTags, $lastline);
    push(@AllLineNums, $line);
  }

  # Now parse each line
  for ($IX = 0; $IX < @AllTags; $IX++) {
    $line = @AllLineNums[$IX];
    my $cline = @AllTags[$IX];
    &parseline($cline);
  }
  
  # Each file now gets this ending
  if ($listStartPrinted eq "true") {$readText = "$readText</list>"; $listStartPrinted = "false";}
  if ($enumList1StartPrinted eq "true") {$readText = "$readText</list>"; $enumList1StartPrinted = "false";}
  if ($enumList2StartPrinted eq "true") {$readText = "$readText</list>"; $enumList2StartPrinted = "false";}
  if ($enumList3StartPrinted eq "true") {$readText = "$readText</list>"; $enumList3StartPrinted = "false";}
  &Write("$readText$endTitle$endParagraph$endVerse$endSection$endChapter\n</div>\n");
  close (INF);
  
  # Now commit print buffer to file
  foreach my $p (@PrintOut) {&Write($p, 1);}
}
############################################

sub parseline($) {
  my $ln = shift;
  $_ = $ln;   
  $_ =~ s/\s*\/\/\s*/ /g; # Force carriage return SFM marker
  
  # replace paratext font tags
  if ($boldpattern)   {$_ =~ s/($boldpattern)/<hi type="bold">$+<\/hi>/g;}
  if ($italicpattern) {$_ =~ s/($italicpattern)/<hi type="italic">$+<\/hi>/g;}
  if ($superpattern) {$_ =~ s/($superpattern)/<hi type="super">$+<\/hi>/g;}
  if ($subpattern) {$_ =~ s/($subpattern)/<hi type="sub">$+<\/hi>/g;}
  
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
  
  # end titles on all tags except title tags
  if ($endTitle && $_ =~ /^[\s\W]*(\\\w+)/ && $_ !~ /^[\s\W]*\\($FstTitle|$SecTitle|$FstCanonTitle|$SecCanonTitle)(\s+|$)(.*)/) {
		$readText .= $endTitle; 
		$endTitle = "";
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
    
    # some SFM projects consistently encode a chapter's top title(s) BEFORE the chapter tag. So FIX!
    my $preCh, $postCh;
    $readText .= $endTitle; $endTitle= "";
    if ($readText =~ s/((<div[^>]*>)?)(<div[^>]*><title[^>]*>.*?<\/title[^>]*>(<div[^>]*>)?)$//) {
			my $prevEndSection = $1;
			my $movedSecTit = $3;
			$preCh  = "$readText$endParagraph$endVerse$prevEndSection";
			$postCh = "$movedSecTit";
		}
    else {
			$preCh  = "$readText$endParagraph$endVerse$endSection";
			$postCh = "";
			$endSection="";
		}
		if ($preCh) {$preCh .= "\n";}
		if ($postCh) {$postCh = "\n".$postCh;}
		
		&Write("$preCh$endChapter\n<chapter osisID=\"$bookName.$myChap\">$postCh\n");
		
    $readText="";
    $endParagraph="";
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
    
    # If readText ends with an empty canonical title, it is meant to apply to the verse, so FIX!
    if ($readText =~ s/(<title[^>]*canonical="true"[^>]*>)<\/title>$/$1/) {$endTitle = "</title>";}
    
    # If this is the first verse of chapter, ignore everything before this first verse, otherwise, print previously collected stuff
    if ($readText !~ /<verse[^>]+>.+/) {
      $prepend = $readText;
      $prepend =~ s/^(<lb[^>]*>|\s)+//;  
    }
    else {
			if ($readText =~ s/((<\w+[^>\/]*>)+)$//) {$prepend = $1;} # move any start tags at end of verse to beginning of next verse
			else {$prepend = ""; }
      my $toWrite = "$readText$endVerse";
      if ($toWrite =~ s/(<verse sID="([^"]+)"[^>]*\/>)\s*(<note[^>]*>.*?<\/note>)\s*(<verse eID="\g2"\/>)/$1-$3$4/) {
        &Log("INFO: Adding verse holder \"-\" to $2 which is only a note.\n");
      }
      &Write($toWrite);
    }
    
    # Save current verse in print buffer 
    if (!$myT && !$prepend) {$myT = " ";} # verse must not be empty or else emptyvss fails
    $readText = "<verse sID=\"$bookName.$myChap.$myV\" osisID=\"$bookName.$myChap.$myV\"/>$prepend$myT";
    $endVerse = "<verse eID=\"$bookName.$myChap.$myV\"/>\n";
  
    $myVerse=$myV;
    $noteV=$nV;
  }
  
  ################## PARATEXT FILE HEADER MARKERS ######################

  # INTRODUCTION MAJOR TITLE TAG
  elsif ($_ =~ /^[\s\W]*\\($IntroFstTitle)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if (!$inIntroduction) {&Log("ERROR: $ThisSFM line $line: $bookName $myChap:$myVerse introduction title is not in introduction.\n");}
    $readText = "$readText<lb /><lb /><title level=\"1\" subType=\"x-introduction\">$myT</title>";
  }
  # INTRODUCTORY PARAGRAPH
  elsif ($_ =~ /^[\s\W]*\\($intropar)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if (!$inIntroduction) {&Log("ERROR: $ThisSFM line $line: $bookName $myChap:$myVerse introduction paragraph is not in introduction.\n");}
    $readText = "$readText$endTitle$endParagraph<p subType=\"x-introduction\">$myT";
    $endParagraph = "</p>";
    $endTitle = "";
  }
  # LIST TITLE MARKER
  elsif ($_ =~ /^[\s\W]*\\($listtitle)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    $readText = "$readText<lb /><lb /><title level=\"2\" subType=\"x-introduction\">$myT</title>";
  }
  # LIST ENTRY
  elsif ($_ =~ /^[\s\W]*\\($list1)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($listStartPrinted ne "true") {$listStart = "<list subType=\"x-list-1\">";}
    else {$listStart = "";}
    $readText = "$readText$listStart<item>$myT</item>";
    $listStartPrinted = "true";
  }
  # BULLET LIST ENTRY
  elsif ($_ =~ /^[\s\W]*\\($list2)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($listStartPrinted ne "true") {$listStart = "<list subType=\"x-list-2\">";}
    else {$listStart = "";}
    $enum4 = chr(8226) . " ";
    $readText = "$readText$listStart<item>$enum4 $myT</item>";
    $listStartPrinted = "true";
  }
  # ENUMERATED LIST 1 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList1)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList1StartPrinted ne "true") {$listStart = "<list subType=\"x-enumlist-1\">";}
    else {$listStart = "";}
    $readText = "$readText$listStart<item>$Roman[$enum1++]. $myT</item>";
    if ($enum1 > 20) {&Log("ERROR $ThisSFM line $line: $bookName $myChap:$myVerse ROMAN ENUMERATION TOO HIGH.\n");}
    $enumList1StartPrinted = "true";
  }
  # ENUMERATED LIST 2 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList2)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList2StartPrinted ne "true") {$listStart = "<list subType=\"x-enumlist-2\">";}
    else {$listStart = "";}
    $enum2++;
    $readText = "$readText$listStart<item>&nbsp;&nbsp;&nbsp;&nbsp;$enum2. $myT</item>";
    $enumList2StartPrinted = "true";
  }
  # ENUMERATED LIST 3 ENTRY
  elsif ($_ =~ /^[\s\W]*\\($enumList3)(\s+|$)(.*)/) {
    $myT=$3;
    while ($myT =~ s/\*//) {&Log("WARNING $ThisSFM line $line: $bookName $myChap:$myVerse Note in introduction ignored.\n");}
    if ($enumList3StartPrinted ne "true") {$listStart = "<list subType=\"x-enumlist-3\">";}
    else {$listStart = "";}
    $enum = lc($Roman[$enum3++]);
    $readText = "$readText$listStart<item>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$enum. $myT</item>";
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
    if ($inIntroduction eq "1") {$readText .= "<title level=\"1\" subType=\"x-introduction\">$myT</title>";}
    else {
			my $startSection = "";
			if ($endTitle) {$endSection = "";} # don't allow multiple sections for multiple titles
			else {$startSection = "<div type=\"section\" sID=\"sec".++$sectionID."\" />";}
			$readText .= "$endTitle$endParagraph$endSection$startSection<title level=\"1\">$myT";
			$endParagraph = "";
			$endTitle = "</title>";
			$endSection = "<div eID=\"sec$sectionID\" />";
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
    if ($inIntroduction eq "1") {$readText .= "<title level=\"2\" subType=\"x-introduction\">$myT</title>";}
    else {
			my $startSection = "";
			if ($endTitle) {$endSection = "";} # don't allow multiple sections for multiple titles
			else {$startSection = "<div type=\"section\" sID=\"sec".++$sectionID."\" />";}
			$readText .= "$endTitle$endParagraph$endSection$startSection<title level=\"2\">$myT"; 
			$endParagraph = "";
			$endTitle = "</title>";
			$endSection = "<div eID=\"sec$sectionID\" />";
    }
  }
  # CANONICAL TITLE LEVEL 1
  elsif ($_ =~ /^[\s\W]*\\($FstCanonTitle)(\s+|$)(.*)/) {
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
    if ($inIntroduction eq "1") {$readText .= "<title canonical=\"true\" level=\"1\" subType=\"x-introduction\">$myT</title>";}
    else {
			my $startSection = "";
			if ($endTitle) {$endSection = "";} # don't allow multiple sections for multiple titles
			else {$startSection = "<div type=\"section\" sID=\"sec".++$sectionID."\" />";}
			$readText .= "$endTitle$endParagraph$endSection$startSection<title canonical=\"true\" level=\"1\">$myT";
			$endParagraph = "";
			$endTitle = "</title>";
			$endSection = "<div eID=\"sec$sectionID\" />";
    }
  }
  # sh - UZV secondary headings in Psalms are canonical!
  # CANONICAL TITLE LEVEL 2
  elsif ($_ =~ /^[\s\W]*\\($SecCanonTitle)(\s+|$)(.*)/) {
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
    if ($inIntroduction eq "1") {$readText .= "<title canonical=\"true\" level=\"2\" subType=\"x-introduction\">$myT</title>";}
    else {
			my $startSection = "";
			if ($endTitle) {$endSection = "";} # don't allow multiple sections for multiple titles
			else {$startSection = "<div type=\"section\" sID=\"sec".++$sectionID."\" />";}
			$readText .= "$endTitle$endParagraph$endSection$startSection<title canonical=\"true\" level=\"2\">$myT";
			$endParagraph = "";
			$endTitle = "</title>";
			$endSection = "<div eID=\"sec$sectionID\" />";
    }
  }
  ################## PARATEXT PARAGRAPH AND POETRY MARKERS ######################
  # PARAGRAPH, LINE GROUP, and LINE MARKERS
  elsif ($_ =~ /^[\s\W]*\\($NoNestTags)(\s+|$)(.*)/) {
    $myT = $3;
    $tag = $1;
    $noteVerseNum = $noteV;
    &encodeNotes;

    # get type and level
    my $type = "paragraph";
    my $level = 1;
    for (my $p=0; $p < @poetryline; $p++) {
      my $pv = @poetryline[$p]; 
      if ($tag =~ /^($pv)$/) {$type = "poetryline"; $level = $p; last;}
    }
    for (my $p=0; $p < @listitem; $p++) {
      my $pv = @listitem[$p]; 
      if ($tag =~ /^($pv)$/) {$type = "listitem"; $level = $p; last;}
    }
    for (my $p=0; $p < @paragraph; $p++) {
      my $pv = @paragraph[$p]; 
      if ($tag =~ /^($pv)$/) {$type = "paragraph"; $level = $p; last;}
    }

    # Note: osis2mod.exe currently (May 20, 2014) converts some tags to milestones when importing them to the module, like this:
    #   <p type="T" subType="ST">  = <div sID="n1" type="x-p" /> (NOTE: type and subType are currently DROPPED! And the type must 
    #   </p>                       = <div eID="n1" type="x-p" />      end up as "x-p" to be handled by SWORD's OSIS filter)
    #
    #   <lg type="T" subType="ST"> = <lg sID="n2" type="T" subType="ST" />
    #   </lg>                      = <lg eID="n2" type="T" subType="ST" />
    #
    #   <l type="T" subType="ST"> = <l sID="n2" type="T" subType="ST" />
    #   </l>                      = <l eID="n2" type="T" subType="ST" />
    #
    # But <list> and <item> are NOT milestonable and so osis2mod.exe imports them without modification.
    #
    #
    # Then, xulsword's OSIS to HTML filter currently (May 20, 2014) converts these to HTML, like this:
    #   <div sID="n1" type="x-p" subType="ST"/> = <div class="p-start ST osis2mod"></div>
    #   <div eID="n1" type="x-p" subType="ST"/> = <div class="p-end ST osis2mod"></div>
    #
    #   <lg sID="n2" type="T" subType="ST" />   = <div class="lg-start T ST"></div>
    #   <lg eID="n2" type="T" subType="ST" />   = <div class="lg-end T ST"></div>
    #
    #   <l sID="n3" type="T" subType="ST" />    = <div class="line indentN ST"> (WHERE N is derived from T)
    #   <l eID="n3" type="T" subType="ST" />    = </div>
    #
    #   <list type="T" subType="ST">            = <div class="x-list T ST">
    #   </list>                                 = </div>
    #
    #   <item type="T" subType="ST">            = <div class="item indentN ST"> (WHERE N is derived from T)
    #   </item>                                 = </div>
    #
    # LINE(N) and ITEM(N) markup should NOT cross verse-tag boundaries:
    # Since these convert to non-empty HTML divs, and since all HTML tags within verse tags MUST be closed,
    # xulsword's OSIS to HTML filter will close any such open divs before the verse's closing tag. This means if an 
    # OSIS <l> crosses a verse boundary, the desired formatting will not be acheived, but the HTML will be valid.
    # You can edit the source to put multiple verses within a single verse tag to fix the formatting when necessary.

    if ($type eq "poetryline") {
      my $eplg = "$readText$endParagraph<lg>";
      if ($eplg !~ s/<\/lg><lg[^>]*>$//) {$lastLineLevel = -99;}
      my $tp = "x-noindent";
      if ($level > 0) {$tp = "x-indent-$level";}

      if ($level == ($lastLineLevel+1)) {
        if ($eplg !~ s/^(.*)(<l [^>]*)(>.*?)$/$1$2 subType="x-to-next-level"$3/) {
        my $ox = @PrintOut-1;
        while ($ox >= 0 && @PrintOut[$ox] !~ s/^(.*)(<l [^>]*)(>.*?)$/$1$2 subType="x-to-next-level"$3/) {$ox--;}
          if ($ox == -1) {&Log("ERROR: $ThisSFM Line $line: Did not find expected poetry line.\n");}
        }
      }
      $lastLineLevel = $level;

      $readText = "$eplg<l level=\"$level\" type=\"$tp\">$myT"; # implemented by osisxhtml.cpp (as of May 2014)
      $endParagraph = "</l></lg>";
    }
    elsif ($type eq "listitem") {
      # ITEM(N) should add <list>...</list> tags around successive <item> elements, but <list> is NOT OSIS milestoneable.
      # This means that osis2mod will create WARNINGS if the list crosses a verse-tag boundary, and this might also 
      # cause problems for some front ends. So <list> in Bible texts are not very usable, since most will cross verses.
      # So instead, <lg>...</lg> is used here, but with subType="x-list-ms" and subType="x-item-ms".
      my $eplg = "$readText$endParagraph<lg subType=\"x-list-ms\">";
      $eplg =~ s/<\/lg><lg[^>]*>$//;
      my $tp = "x-noindent";
      if ($level > 0) {$tp = "x-indent-".$level;}
      $readText = $eplg."<l type=\"".$tp."\" subType=\"x-item-ms\">".$myT; # implemented by osisxhtml.cpp (as of May 2014)
      $endParagraph = "</l></lg>";	
    }
    else {
      my $tp = "x-noindent";
      if ($level == 1) {$tp = "";}
      if ($level > 1) {$tp = "x-indented-".($level-1);}
      $tp = ($tp ? " type=\"$tp\"":"");

      # Currently, osis2mod does not retain paragraph types during import, and it is not clear if/when/how this will change.
      # So zero-indent paragraphs are currently encoded thus:
      if ($level == 0) {
        $readText .= $endTitle.$endParagraph.$myT;
        $endParagraph = ""; 
      }
      else {
        $readText .= $endTitle.$endParagraph."<p$tp>".$myT; # all attributes are dropped by osis2mod (as of April 2014)
        $endParagraph = "</p>";
      }
      $endTitle = "";
    }
  }
  # BLANK LINE MARKER
  elsif ($_ =~ /^[\s\W]*\\($blankline)(\s+|$)(.*)/) {
    $myT = $3;
    $noteVerseNum = $noteV;
    &encodeNotes;
    $EmptyLine = ""; #($myT ? "":"<lb />");
    $readText = "$readText<lb />$EmptyLine$myT";
  }
  # FOOTNOTE STARTS A LINE
  elsif ($NoteType eq "INLINE" && $notePattern && $_ =~ /^[\s\W]*($notePattern)$/) {
    $myT = $_;
    $noteVerseNum = $noteV;
    if (!$noteVerseNum) {$noteVerseNum = 1;}
    &encodeNotes;
    $readText = "$readText $myT";
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
    $myT = $_;
    $noteVerseNum = $noteV;
    if (!$noteVerseNum) {$noteVerseNum = 1;}
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
  &normalizeNewLines($NoteFileName);
  open(NFLE, "<:encoding(UTF-8)", $NoteFileName) or print "ERROR: Could not open file $NoteFileName.\n";
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
      $t = "\[$2-$3\] $4";
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
  &normalizeNewLines($NoteFileName);
  open(NFLE, "<:encoding(UTF-8)", $NoteFileName) or print "ERROR: Could not open file $NoteFileName.\n";
  $NoteFileName =~ /\/(...) Footnotes/; 
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
        if ($v =~ /(\d+)-(\d+)/) {$_ = "[$v] $_";} 
        $notes{$thisNote} = "$bookName,$c,$v,$_";
        #&Log("Read Note: $thisNote $notes{$thisNote}\n");
        $noteNum++;
      }
      elsif ($_ =~ s/^[\s\W]*\\fuz \|b(\d+)\|r //) {
        $c=$1; $v=1;
        if ($v =~ /(\d+)-(\d+)/) {$_ = "[$v] $_";}
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

sub Write($$) {
  my $print = shift;
  my $commit = shift;
  
  if (!fileno(OUTF)) {
    open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) || die "Could not open paratext2osis output file $OUTPUTFILE\n";
    &Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"defaultReferenceScheme\" xml:lang=\"$LANG\"><header><work osisWork=\"$MOD\"><title>$MOD Bible</title><identifier type=\"OSIS\">Bible.$MOD</identifier><refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n", 1);
  }
  
  while ($print =~ s/((\\([\w]*)\*?)|(\|[ibr]))//i) {
    $tagsintext = $tagsintext."WARNING Before $ThisSFM Line $line: Tag \"$+\" in \"$bookName\" was REMOVED.\n";
  }
  
  if (!$commit) {
		push(@PrintOut, $print);
		return;
	}
	
	# Warn about osis2mod <p>
	if ($print =~ /(<verse[^>]*osisID="([^"]*)")?.*(<p [^>]*(type|subType)[^>]*>)/) {
		&Log("Note: $2 <p> attributes are dropped by osis2mod: $3\n");
	}
  
  # Warn if we are breaking a LINE(N) across verses
  if ($MustStartWithCloseLine && $print !~ /<verse sID[^>]*>\s*<\/l/) {
    $print =~ /<verse[^>]*osisID="([^"]*)"/;
    &Log("WARNING: $1: Breaking LINE(N) across verses. This will not display as intended.\n");
  }
  my $ls = -1; my $le = -1;
  if ($print =~ /^(.*)<l[\s>]/) {$ls = length($1);}
  if ($print =~ /^(.*)<\/l[\s>]/) {$le = length($1);}
  if ($ls > $le) {$MustStartWithCloseLine = 1;}
  if (($ls == -1 && $le > -1) || $ls < $le) {$MustStartWithCloseLine = 0;}
  
  # change all book.ch.vs1-vs2 osisIDs to book.ch.vs1 book.ch.vs2 for OSIS schema validation
  while ($print =~ s/(<verse [^>]*osisID=")([^\.]+\.\d+\.)(\d+)-(\d+)"/workingID/) {
    $vt = $1; $bkch = $2; $v1 = 1*$3; $v2 = 1*$4; $sep = "";
    while ($v1 <= $v2) {$vt = "$vt$sep$bkch$v1"; $sep=" " ; $v1++}
    $print =~ s/workingID/$vt\"/;
  }
  
  # make sure we don't get more than one blank line between verses
  $print =~ s/(<lb[^\/]*\/><lb[^\/]*\/>)(<lb[^\/]*\/>)+/$1/g;
	
  print OUTF $print;
}
