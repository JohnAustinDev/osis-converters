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

# IMPORTANT TERMINOLOGY:
#   A "reference" is a reference to a contiguous Scripture text. For
#   example: "Matt 1:1-5".
#   An "extended reference" is a list of Scripture references. For
#   example: "John 4:5; 6:7-9, 11, 13; 1 Peter 1:3 and Rev 20:1-5" is 
#   a single extended reference.

# POSSIBLE COMMAND FILE SETTINGS: 
#
#  (NOTE: settings which are not needed can 
#   be left blank or not included at all)
#
#   <OSIS_BOOK_ABBREVIATION>=aTerm - Will associate the Bible book on
#       the left with the matching term on the right. Only one term
#       per line is allowed, but a single book may appear on numerous
#       lines, each with another matching term. Longest terms for a 
#       book should be listed before shorter terms for the same book. 
#       NOTE: terms on the right are NOT Perl regular expressions but 
#       are string literals. However, these terms may be preceeded by 
#       PREFIXES or SUFFIXES (see below) and still match the book.
#
#   REFERENCE_TYPE - The value to use for the type attribute of 
#       <reference> links which are added by this script.
#   FILTER - A Perl regular expression used to select only particular
#       parts of text to search for Scripture references. By default, 
#       everything is searched.
#   CHAPTER_TERMS - A Perl regular expression representing words/phrases
#       which should be understood as meaning "chapter".
#   CURRENT_CHAPTER_TERMS - A Perl regular expression representing 
#       words/phrases which should be understood as meaning 
#       "the current chapter".
#   CURRENT_BOOK_TERMS - A Perl regular expression representing
#       words/phrases which should be understood as meaning 
#       "the current book"
#   VERSE_TERMS- A Perl regular expression representing words/phrases
#       which should be understood as meaning "verse".
#   COMMON_REF_TERMS - A Perl regular expression representing all
#       characters commonly found in extended references.
#   PREFIXES - A Perl regular expression matching possible book
#       prefixes. For example: quotes or "(" characters.
#   REF_END_TERMS - A Perl regular expression to match the end of all
#       extended references.
#   SUFFIXES - A Perl regular expression matching suffixes which may
#       appear at the end of book names and chapter/verse terms. Some
#       Turkic languages have many such suffixes for example.
#   SEPARATOR_TERMS - A Perl regular expression matching terms used
#       to separate references in extended references. For 
#       example: ";" and "and".
#   CHAPTER_TO_VERSE_TERMS - A Perl regular expression matching terms
#       used to separate chapter from verse in a reference. For
#       example: ":" is often used.
#   CONTINUATION_TERMS - A Perl regular expression matching terms
#       used to show a continuous range of numbers. For example: "-".
#   DONT_MATCH_IF_NO_VERSE - Set to "true" to ignore references which
#       do not imply a verse, as in: "Luke 5".
#   SKIP_PSALMS - Set "true" to skip the book of Psalms.
#   SKIP_REFERENCES_FOLLOWING - A Perl regular expression which matches
#       words/terms which should indicate the text following them are 
#       NOT Scripture references.
#   REQUIRE_BOOK - Set to "true" to skip references which do not specify
#       the book. For example: "see chapter 6 verse 5". Normally, these
#       references use context to imply their book target.
#   EXCLUSION - Use to exclude certain references.
#   LINE_EXCLUSION - Use to exclude certain references on certain lines.
#   FIX - Used to fix an incorrectly parsed reference.
#   SKIPVERSE - The osisRef of a verse to skip.
#   SKIPLINE - A line number to skip.
  
$debugLine = 0;
$onlyLine = 0;

$tmpFile = $OUTPUTFILE;
$tmpFile =~ s/(^|\/|\\)([^\/\\\.]+)([^\/\\]+)$/$1TMP_$2$3/;

# Globals
%books;
%UnhandledWords;
%noDigitRef;
%noOSISRef;
%exclusion;
%lineExclusion;
%exclusionREP;
%lineExclusionREP;
%fix;
@skipVerse;
$skipLines;

$BK = "unknown";
$CH = 0;
$VS = 0;
$LV = 0;
$ebookNames = "";
$oneChapterBooks = "Obad|Phlm|Jude|2John|3John";
$refType = "<none>";
$filter = "^.*\$";
$chapTerms = "none";
$currentChapTerms = "none";
$currentBookTerms = "none";
$verseTerms = "none";
$refTerms = "none";
$prefixTerms = "none";
$refEndTerms = "none";
$suffixTerms = "none";
$sepTerms = "none";
$chap2VerseTerms = "none";
$continuationTerms = "none";
$skipUnhandledBook = "none";
$mustHaveVerse = 0;
$skipPsalms = 0;
$require_book = 0;
$sp="\"";
$numUnhandledWords = 0;
$numMissedLeftRefs = 0;
$numNoDigitRef = 0;
$numNoOSISRef = 0;
$line=0;

$Types{"T01 (Book? c:v-c:v)"} = 0;
$Types{"T02 (Book? c:v-lv)"} = 0;
$Types{"T03 (Book? c:v)"} = 0;
$Types{"T04 (Book? c ChapTerm v VerseTerm)"} = 0;
$Types{"T05 (c-c ChapTerm)"} = 0;
$Types{"T06 (Book? c ChapTerm)"} = 0;
$Types{"T07 (Book|CurrentChap? v-v VerseTerms)"} = 0;
$Types{"T08 (Book|CurrentChap? v VerseTerms)"} = 0;
$Types{"T09 (Book|CurrentChap num1-num2?)"} = 0;
$Types{"T10 (num1 ... num2?)"} = 0;

&Log("-----------------------------------------------------\nSTARTING addScripRefLinks.pl\n\n");

&Log("READING COMMAND FILE \"$COMMANDFILE\"\n");
&normalizeNewLines($COMMANDFILE);
&addRevisionToCF($COMMANDFILE);
open(CF, "<:encoding(UTF-8)", $COMMANDFILE);
my @abkn;
while (<CF>) {
  $_ =~ s/\s+$//;

	if ($_ =~ /^(\#.*|\s*)$/) {next;}
  elsif ($_ =~ /^DEBUG_LINE:(\s*(\d+)\s*)?$/) {if ($2) {$debugLine = $2;}}
	elsif ($_ =~ /^FILTER:(\s*\((.*?)\)\s*)?$/) {if ($1) {$filter = $2;} next;}
	elsif ($_ =~ /^CHAPTER_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$chapTerms = $2;} next;}
	elsif ($_ =~ /^CURRENT_CHAPTER_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$currentChapTerms = $2;} next;}
	elsif ($_ =~ /^CURRENT_BOOK_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$currentBookTerms = $2;} next;}
	elsif ($_ =~ /^VERSE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$verseTerms = $2;} next;}
	elsif ($_ =~ /^COMMON_REF_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$refTerms = $2;} next;}
	elsif ($_ =~ /^PREFIXES:(\s*\((.*?)\)\s*)?$/) {if ($1) {$prefixTerms = $2;} next;}
	elsif ($_ =~ /^REF_END_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$refEndTerms = $2;} next;}
	elsif ($_ =~ /^SUFFIXES:(\s*\((.*?)\)\s*)?$/) {if ($1) {$suffixTerms = $2;} next;}
	elsif ($_ =~ /^SEPARATOR_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$sepTerms = $2;} next;}
	elsif ($_ =~ /^CHAPTER_TO_VERSE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$chap2VerseTerms = $2;} next;}
	elsif ($_ =~ /^CONTINUATION_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$continuationTerms = $2;} next;}
	elsif ($_ =~ /^SKIP_REFERENCES_FOLLOWING:(\s*\((.*?)\)\s*)?$/) {if ($1) {$skipUnhandledBook = $2;} next;} 
  elsif ($_ =~ /^REFERENCE_TYPE:(\s*(.*?)\s*)?$/) {if ($1) {$refType = $2;} next;}   
	elsif ($_ =~ /^DONT_MATCH_IF_NO_VERSE:(\s*(.*?)\s*)?$/) {if ($1) {$mustHaveVerse = $2;} next;}
	elsif ($_ =~ /^SKIP_PSALMS:(\s*(.*?)\s*)?$/) {if ($1) {$skipPsalms = $2;} next;}
	elsif ($_ =~ /^REQUIRE_BOOK:(\s*(.*?)\s*)?$/) {if ($1 && $2 !~ /^false$/i) {$require_book = 1;}}
  elsif ($_ =~ /^SKIPVERSE:\s*(.*?)\s*$/) {if ($1) {push(@skipVerse, $2);} next;}
	elsif ($_ =~ /^SKIPLINE:\s*(\d+)\s*$/) {if ($1) {$skipLines .= $sp.$2.$sp} next;}
	elsif ($_ =~ /^EXCLUSION:(Linking)?\s*(.*?): (.*) =/) {$exclusion{$2} .= $sp.$3.$sp; next;}
	elsif ($_ =~ /^EXCLUSION:\s*([^:]+)\s*:\s*(.*?)\s*$/) {$exclusion{$1} .= $sp.$2.$sp; next;}
	elsif ($_ =~ /^LINE_EXCLUSION:(\d+) Linking.*?: (.*?) =/) {$lineExclusion{$1} .= $sp.$2.$sp; next;}
	elsif ($_ =~ /^LINE_EXCLUSION:(\d+)\s+(.*?)\s*$/) {$lineExclusion{$1} .= $sp.$2.$sp; next;}
	elsif ($_ =~ /^FIX:(Check line (\d+):)?\"([^\"]+)\"=(.*?)$/) {$fix{$3} = $4; next;}
	elsif ($_ =~ /^([\S]+)\s*=\s*(.*)\s*$/) {
		my $lb = $2;
		my $elb = quotemeta($2);
		$books{$lb}=$1;
		push(@abkn, $elb);
	}
	else {
		&Log("WARNING: \"$_\" in command file was not handled.\n");
	}
}
if (!@abkn) {$ebookNames="none";}
else {
  my $bktsep="";
  for (my $i=0; $i<@abkn; $i++) {
    my $xg=0;
    my $xi=0;
    for (my $j=0; $j<@abkn; $j++) {if (length(@abkn[$j]) > $xg) {$xg=length(@abkn[$j]); $xi=$j;}}
    if (@abkn[$xi]) {$ebookNames .= $bktsep.@abkn[$xi]; $bktsep="|";}
    @abkn[$xi] = 0;
  }
}
close (CF);

&Log("READING OSIS/IMP FILE: \"$INPUTFILE\".\n");
&Log("WRITING OSIS/IMP FILE: \"$OUTPUTFILE\".\n");
&Log("\n");

open(INF, "<:encoding(UTF-8)", $INPUTFILE);
open(OUTF, ">:encoding(UTF-8)", $tmpFile);
my $intro = 0;
my $psw = 0;
$line=0;
while (<INF>) {
	$line++;

	# The following is for matching IMP verse keys
	if ($_ =~ /^\$\$\$(\w+)\s+(\d+)(:(\d+)(\s*-\s*(\d+))?)?/) {
		$BK = $1;
		$CH = $2;
		$VS = ($4 ? $4:0);
		$intro = ($CH == 0);
    &Log("-> $BK\n", 1);
		goto FINISH_LINE;
	}
	
	# The following is for matching OSIS XML file tags
	if ($_ =~ /<div type="book" osisID="([^\"]*)">/) {
		$BK = $1;
		$CH = 1;
		$VS = 0;
		$intro = 1;
    &Log("-> $BK\n", 1);
		goto FINISH_LINE;
	}
	elsif ($_ =~ /<chapter osisID="([^\.]+)\.([^"]+)">/) {
		$BK = $1;
		$CH = $2;
		$VS = 0;
		$intro = 0;
		goto FINISH_LINE;
	}
	elsif ($_ =~ /<verse sID=\"([^\.]+)\.(\d+)\.(\d+)/) {
		$BK = $1;
		$CH = $2;
		$VS = $3;
	}

	foreach my $av (@skipVerse) {
		if ($av eq "$BK.$CH.$VS") {
			&Log("$line WARNING $BK.$CH.$VS: Skipping verse $av - on SKIP list\n"); 
			goto FINISH_LINE;
		}
	}

	if ($skipPsalms eq "true" && $BK eq "Ps") {
		if (!$psw) {&Log("\nWARNING: SKIPPING THE BOOK OF PSALMS\n\n");}
		$psw = 1;
		goto FINISH_LINE;
	}

	if ($intro) {
    # addLinks cannot handle \n at line's end
    my $lf = "";
    if ($_ =~ s/([\r\n]*)$//) {$lf = $1;}
		&addLinks(\$_, $BK, $CH);
    $_ .= $lf;
	}
	else {
		my @filtered = split(/($filter)/, $_);
		foreach my $chunk (@filtered) {
			if ($chunk !~ /($filter)/) {next;}
			&addLinks(\$chunk, $BK, $CH);
		}
		$_ = join("", @filtered);
	}
	
FINISH_LINE:
	print OUTF $_;
}
close(INF);
close(OUTF);
&Log("Finished adding <reference> tags.\n");
&Log("\n");
&Log("\n");
&Log("#################################################################\n");
&Log("\n");
&Log("\n");
&Log("LINK RESULTS...\n");
&Log("\n");

&Log("REPORT: Checking osisRef attributes of links:\n");
open(INF2, "<:encoding(UTF-8)", $tmpFile);
open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE);
$newLinks=0;
$line=0;
while (<INF2>) {
	$line++;
	@lineLinks = split(/(<newReference osisRef="([^"]+)">(.*?)<\/newReference>)/, $_);
	foreach $lineLink (@lineLinks) {
		if ($lineLink !~ /(<newReference osisRef="([^"]+)">(.*?)<\/newReference>)/) {next;}
		$osisRef = $2;
		$linkText = $3;
		if (&validOSISref($osisRef, $linkText)) {$newLinks++;}
		else {&Log("$line ERROR $BK.$CH.$VS: Link \"$linkText\" has an illegal osisRef \"$osisRef\".\n");}
	}
	if ($refType eq "<none>") {
		$_ =~ s/newReference/reference/g;
	}
	else {
		#$_ =~ s/<newReference osisRef=\"([^"]+)">(.*?)<\/newReference>/<ScripRef passage=\"$1\">$2<\/ScripRef>/g;
		$_ =~ s/<newReference/<reference type=\"$refType\"/g;
		$_ =~ s/newReference/reference/g;
	}

	print OUTF $_;
}
close(INF2);
close(OUTF);
&Log("Finished checking osisRefs.\n");
&Log("\n");

my $tCheckRefs = $CheckRefs;
my $aerefs = ($tCheckRefs =~ tr/\n//);
&Log("REPORT: Listing of extended refs containing ambiguous number(s): ($aerefs instances)\n");
if ($CheckRefs) {
  &Log("NOTE: These are cases where a number could be interpreted as either a verse\n");
  &Log("or a chapter depending upon context. These should be spot checked for accuracy.");
  &Log("$CheckRefs\n");
}
else {&Log("(no extended refs contain ambiguous numbers)\n");}
&Log("\n");

&Log("REPORT: Listing of refs with unknown book names which defaulted to the context book: ($numUnhandledWords instances)\n");
if (scalar(keys %UnhandledWords)) {
  &Log("NOTE: Bible book references in the following list are resulting in incorrect link \n");
  &Log("targets and should have been specified in the command file. Words which do not \n");
  &Log("actually refer to Bible books (\"Koran\" for instance) should have an EXCLUSION\n"); 
  &Log("added to the command file.\n");
  foreach my $uw (sort reverseAlpha keys %UnhandledWords) {
    &Log("<$uw> $UnhandledWords{$uw}\n");
  }
}
else {&Log("(no unknown book names)\n");}
&Log("\n");

&Log("REPORT: Listing of exclusions: (".(scalar(keys %exclusion) + scalar(keys %lineExclusion))." instances)\n");
if (scalar(keys %exclusion) || scalar(keys %lineExclusion)) {
  &reportExclusions(\%exclusion, \%exclusionREP, "verse");
  &reportExclusions(\%lineExclusion, \%lineExclusionREP, "line");
}
else {&Log("(no exclusions were specified in command the file)\n");}
&Log("\n");

&Log("REPORT: Listing of fixes: (".scalar(keys %fix)." instances)\n");
if (scalar(keys %fix)) {
  foreach my $fx (keys %fix) {
    if ($fix{$fx} !~ /^\s*$/) {
      &Log("WARNING: Fix \"$fx\" was not applied.\n");
    }
  }
}
else {&Log("(no fixes were specified in the command file)\n");}
&Log("\n");

&Log("REPORT: Listing of unlocated left refs which were skipped: ($numMissedLeftRefs instances)\n");
if (scalar(keys %missedLeftRefs)) {
  &Log("NOTE: These occur when the end of an extended ref cannot be determined. To fix these, check \n");
  &Log("instances in the log above- modifying REF_END_TERMS in the command file is the usual adjustment.\n");
  foreach my $mlr (sort keys %missedLeftRefs) {
    &Log("<$mlr> $missedLeftRefs{$mlr}\n");
  }
}
else {&Log("(no unlocated left refs)\n");}
&Log("\n");

&Log("REPORT: Listing of refs without digits which were skipped: ($numNoDigitRef instances)\n");
if (scalar(keys %noDigitRef)) {
  &Log("NOTE: These occur when an extended ref or a subref contain no numbers. A large number \n");
  &Log("of these may indicate incorrect command file regular expressions.\n");
  foreach my $mlr (sort keys %noDigitRef) {
    &Log("$mlr $noDigitRef{$mlr}\n");
  }
}
else {&Log("(no refs without digits found)\n");}
&Log("\n");

&Log("REPORT: Listing of subrefs with indeterminate osisRefs which were skipped: ($numNoOSISRef instances)\n");
if (scalar(keys %noOSISRef)) {
  &Log("NOTE: These may indicate a ref which should be an EXCLUSION or a problem \n");
  &Log("with command file regular expressions. \n");
  foreach my $mlr (sort keys %noOSISRef) {
    &Log("<$mlr> $noOSISRef{$mlr}\n");
  }
}
else {&Log("(no subrefs with OSIS ref problems found)\n");}
&Log("\n");

&Log("REPORT: Grand Totals:\n");
foreach my $type (sort keys %Types) {
  &Log(sprintf("%5d - %s\n", $Types{$type}, $type));
}
&Log("Found $newLinks total sub-links.\n");
&Log("FINISHED!\n\n");

unlink("$tmpFile");


##########################################################################
##########################################################################
# 1) SEARCH FOR THE LEFTMOST OCCURRENCE OF ANY REFERENCE TYPE. 
# 2) SEARCH FOR AN EXTENDED REFERENCE BEGINNING WITH THAT LEFTMOST REFERENCE.
# 3) SPLIT THE EXTENDED REFERENCE INTO SUBREFS.
# 4) PARSE EACH SUBREF SEPARATELY, EACH INHERITING MISSING VALUES FROM THE PREVIOUS SUBREF
# 5) REASSEMBLE THE EXTENDED REFERENCE USING OSIS LINKS
# 6) REPEAT FROM STEP 1 UNTIL NO MORE REFERENCES ARE FOUND
sub addLinks(\$$$) {
	my $tP = shift;
	my $bk = shift;
	my $ch = shift;

	if ($onlyLine && $line != $onlyLine) {return;}
	if ($skipLines && $skipLines =~ /$sp$line$sp/) {
		&Log("$line WARNING $BK.$CH.$VS: Skipped line - on SKIPLINE list.\n");
		return;
	}
#&Log("$line: addLinks $bk, $ch, $$tP\n");

  my @notags = split(/(<[^>]*>)/, $$tP);
  for (my $ts = 0; $ts < @notags; $ts++) {
    if (@notags[$ts] =~ /^<[^>]*>$/) {next;}
    my $ttP = \@notags[$ts];

    my $matchedTerm, $type, $unhandledBook;
    while (&leftmostTerm($ttP, \$matchedTerm, \$type, \$unhandledBook)) {
        
      if ($line == $debugLine) {&Log("DEBUG1: MatchedTerm=$matchedTerm Type=$type\n");}
      if (!&termAcceptable($matchedTerm, $line, \%lineExclusion, \%lineExclusionREP)) {&hideTerm($matchedTerm, $ttP); next;}
      if (!&termAcceptable($matchedTerm, "$BK.$CH.$VS", \%exclusion, \%exclusionREP)) {&hideTerm($matchedTerm, $ttP); next;}
      
      #  Look at unhandledBook
      if ($unhandledBook) {
        $numUnhandledWords++;
        my $ubk = $unhandledBook;
        $ubk =~ s/^.*>$/<tag>/;
        $ubk =~ s/^.*\($/(/;
        $UnhandledWords{$ubk} .= $line.", ";
        if ($require_book || $unhandledBook =~ /$skipUnhandledBook/) { # skip if its a tag- this could be a book name, but we can't include it in the link
          &Log("$line WARNING $BK.$CH.$VS: Skipped \"$matchedTerm\" - no BOOK (unhandled:$unhandledBook).\n");
          &hideTerm($matchedTerm, $ttP);
          next;
        }
        else {
          &Log("$line NOTE $BK.$CH.$VS: \"$matchedTerm\" - no BOOK (unhandled:$unhandledBook).\n");
        }
      }	

      my $mtENC = quotemeta($matchedTerm);
      
      if ($$ttP !~ /(($prefixTerms)?$mtENC($suffixTerms)*((($ebookNames|$chapTerms|$verseTerms)($suffixTerms)*)|$sepTerms|$refTerms|\d|\s)*)($refEndTerms)/) {
        &Log("$line WARNING $BK.$CH.$VS: Left-most term \"$matchedTerm\" Type \"$type\" could not find in \"$$ttP\".\n");
        $numMissedLeftRefs++;
        $missedLeftRefs{$matchedTerm} .= $line.", ";
        &hideTerm($matchedTerm, $ttP, 1);
        next;
      }		
      my $extref = $1;
      
      if ($line == $debugLine) {&Log("DEBUG2: extref=\"$extref\" endref=\"$8\"\n");}		
      
      # Skip if no digits
      if ($extref !~ /\d+/) {
        $numNoDigitRef++;
        $noDigitRef{"<$extref> (extref)"} .= $line.", ";
        &Log("$line WARNING $BK.$CH.$VS: Skipped \"$extref\" - no DIGITS.\n");
        &hideTerm($matchedTerm, $ttP);
        next;			
      }
      
      # Skip if on line Exclusion lists
      if (!&termAcceptable($extref, $line, \%lineExclusion, \%lineExclusionREP)) {&hideTerm($extref, $ttP); next;}
      if (!&termAcceptable($extref, "$BK.$CH.$VS", \%exclusion, \%exclusionREP)) {&hideTerm($extref, $ttP); next;}
      
      my $repExtref = "";
      my $shouldCheck = 0;
      
      # Fix if on fix list
      foreach $fx (keys %fix) {
        if ($fx eq $extref) {
          $repExtref = $fix{$fx};
          &Log("$line WARNING $BK.$CH.$VS: Fixed \"$extref\" - on FIX list.\n");
          $repExtref =~ s/<r\s*([^>]+)>(.*?)<\/r>/<newReference osisRef="$1">$2<\/newReference>/g;
          $fix{$fx} = "";
          $shouldCheck = 1;
          goto ADDLINK;
        }
      }

      # Now break ref up into its subrefs, and extract OSIS ref for each subref		
      my $tbk = $bk;
      my $tch = $ch;
      my $bareNumbersAre = "chapters";
      if ($tbk =~ /($oneChapterBooks)/i) {$bareNumbersAre = "verses"; $ch = 1;}
      
      my @subrefArray = split(/($sepTerms)/, $extref);		
      foreach my $subref (@subrefArray) {
        if ($line == $debugLine) {&Log("DEBUG3: subref=\"$subref\"\n");}
        
        # Keep sepTerms
        if ($subref =~ /($sepTerms)/) {
          $repExtref .= $subref;
          next;
        }
        
        if (!$subref) {next;}	
            
        # Skip subrefs without numbers
        if ($subref !~ /\d+/) {
          $numNoDigitRef++;
          $noDigitRef{"<$subref> (subref)"} .= $line.", ";
          $repExtref .= $subref;
          &Log("$line WARNING $BK.$CH.$VS: Skipped subref \"$subref\" - no DIGITS.\n");
          next;
        }		
        
        # Now parse out this subref
        my $osisRef;
        if (!&getOSISRef(\$subref, \$osisRef, \$type, \$tbk, \$tch, \$bareNumbersAre)) {
          $numNoOSISRef++;
          $noOSISRef{$subref} .= $line.", ";
          $repExtref .= $subref;
          &Log("$line WARNING $BK.$CH.$VS: Skipping subref \"$subref\", osisref is \"$osisRef\".\n");
          next;					
        }
        
        if ($line == $debugLine) {&Log("DEBUG4: MatchedTerm=$matchedTerm\n");}
        
        $Types{$type}++;
        if ($type eq "T09 (num1 ... num2?)") {$shouldCheck = 1;}
        
        $repExtref .= "<newReference osisRef=\"".$osisRef."\">".$subref."<\/newReference>";	
        &Log("$line Linking $BK.$CH.$VS: $subref = $osisRef ($type)\n");		
      }
      
      ADDLINK:	
      my $repExtrefENC = &encodeTerm($repExtref);
      if ($$ttP !~ s/\Q$extref/$repExtrefENC/) {&Log("$line ERROR $BK.$CH.$VS: Could not replace \"$extref\".\n");}		
          
      if ($shouldCheck) {
        $prf = $repExtref;
        $prf =~ s/osisRef="([^"]+)"/$1/g;
        $prf =~ s/newReference/r/g;
        $CheckRefs .= "\nCheck line $line:\"$extref\"=$prf";
      }		
    }
    
    &decodeTerms($ttP);
        
    # Now insure consecutive newReference tags don't have anything between them
    while ($$ttP =~ /(<newReference osisRef=[^>]+>)(.*?)(<\/newReference>)(($sepTerms|\s)+)(<newReference osisRef=[^>]+>)/) {
      $$ttP =~ s/(<newReference osisRef=[^>]+>)(.*?)(<\/newReference>)(($sepTerms|\s)+)(<newReference osisRef=[^>]+>)/$1$2$4$3$6/;
    }
  }
  
  $$tP = join("", @notags);
}			

sub termAcceptable($$%%) {
	my $t = shift;
	my $key = shift;
	my $excP = shift;
	my $doneExcP = shift;

	my $tre = quotemeta($t);
	if ($excP->{$key} && $excP->{$key} =~ /$sp$tre$sp/) {
		$doneExcP->{$key} .= $sp.$t.$sp;
		&Log("$line WARNING $key: Skipped \"$t\" - on EXCLUDE list.\n");
		return 0;
	}	
	
	return 1;
}

sub reportExclusions(%%$) {
	my $excP = shift;
	my $doneExcP = shift;
  my $type = shift;
	
  if (!(scalar(keys %{$excP}))) {
    &Log("(no $type exclusions in command file)\n");
    return;
  }
  
  my $ok = 1;
	foreach my $ex (sort keys %$excP) {
		my @exb = split(/$sp(.*?)$sp/, $excP->{$ex});
		foreach my $exbv (@exb) {
			if (!$exbv) {next;}
			my $exbr = quotemeta($exbv);
			if ($doneExcP->{$ex} !~ /$sp$exbr$sp/) {
				&Log("ERROR: Exclusion ".$ex." ".$exbv." was not applied.\n");
        $ok = 0;
			}
		}
	}
  
  if ($ok) {&Log("(all $type exclusions where applied)\n");}
}

sub hideTerm($\$$) {
	my $mt = shift;
	my $tP = shift;
	my $encFirstWordOnly = shift;
	
	my $re1 = quotemeta($mt);
	my $re2 = "";
	if ($encFirstWordOnly) {
		if ($mt =~ /^(\S+?)(\s.*)$/) {
			my $mt1 = $1;
			my $mt2 = $2;
			$re2 = &encodeTerm($mt1).$mt2;
		}
	}
	if (!$re2) {$re2 = &encodeTerm($mt);}
	
	if ($$tP !~ s/$re1/$re2/) {&Log("$line ERROR $BK.$CH.$VS: Could not hide term \"$mt\" in \"$$tP\".\n");}
}

sub encodeTerm($) {
	my $t = shift;
	if ($t =~ /(\{\{\{|\}\}\})/ || $t =~ /(._){2,}/) {
		&Log("$line ERROR $BK.$CH.$VS: String already partially encoded \"$t\".\n");
	}
	$t =~ s/(.)/$1_/g;
	return "{{{".$t."}}}";
}

sub decodeTerms(\$) {
	my $tP = shift;

	while ($$tP =~ /(\{\{\{(.*?)\}\}\})/) {
		my $re1 = $1;
		my $et = $2;
		
		my $re2 = "";
		for (my $i=0; $i<length($et); $i++) {
			my $chr = substr($et, $i, 1);
			if (!($i%2)) {$re2 .= $chr;}
			elsif ($chr ne "_") {&Log("$line ERROR $BK.$CH.$VS: Incorectly encoded reference text \"$re1\".\n");}
		}

		$$tP =~ s/\Q$re1/$re2/;
	}
}

# Finds the left-most reference match.
# Modifies:
#	$matchP - holds the matched text
#	$typeP - holds the type of match
#	$uhbkP - holds the word preceding the matched text IF no book or book-term was matched.
#			 The uhkP value is null only if a book or book-term WAS matched
# Returns:
#	1 if a match was found
#	0 otherwise
sub leftmostTerm(\$\$\$\$) {
	my $tP = shift;
	my $matchP = shift;
	my $typeP = shift;
	my $uhbkP = shift;

	$$matchP = &matchRef(1, $tP, $typeP, $uhbkP);
	if (!$$matchP) {return 0;}
	return 1;
}					

# Finds a single reference match in the subref.
# Modifies:
#	$osisP - holds OSIS ref for the sub-ref
#	$typeP - holds the type of match used
#	$bk, $ch, $barenumsP - holds values associated with the sub-ref that will
#			 carry over to the next sub-ref in its extended ref.
# Returns:
#	1 if a match was found and a valid OSIS ref was parsed
#	0 otherwise		
sub getOSISRef(\$\$\$\$\$\$) {
	my $tP = shift;
	my $osisP = shift;
	my $typeP = shift;
	my $bkP = shift;
	my $chP = shift;
	my $barenumsP = shift;

	my $contextBK = $$bkP;
	my $contextCH = $$chP;
	
	my $uhbk = "";
	my $vs = -1;
	my $lv = -1;	
	if (!&matchRef(0, $tP, $typeP, \$uhbk, $bkP, $chP, \$vs, \$lv, $barenumsP)) {
		return 0;
	}
	
	$$osisP = "";

	# OSIS reference
	if ($vs == -1 && $mustHaveVerse eq "true") {$$osisP = ""; return 0;}
	else {
		$$osisP = $$bkP.".".$$chP;
		# A value of -1 means don't include verse in OSIS ref
		if ($vs != -1) {$$osisP .= ".".$vs;}
		if ($lv != -1 && $lv > $vs) {$$osisP .= "-".$$bkP.".".$$chP.".".$lv;}
	}
	
	return &validOSISref($$osisP, 0, 1);
}		

# Finds a single reference match in a string, matching either the left-most 
# possible, or else the most complete match, depending on the $matchleft parameter.
# Modifies:
#	$typeP - holds the type of match found
#	$uhbkP - holds the word preceding the matched text IF no book or book-term was matched.
#			 The uhkP value should only be null if a book or book-term WAS matched
#	$bk, $ch, $vs, $lv, $bn - holds values associated with the match.
# Returns:
#	The matched reference text	
sub matchRef($\$\$\$\$\$\$\$\$) {
	my $matchleft = shift;
	my $tP = shift;
	my $typeP = shift;
	my $uhbkP = shift;
	my $bkP = shift;
	my $chP = shift;
	my $vsP = shift;
	my $lvP = shift;
	my $barenumsP = shift;

	$$typeP = "";
	$$uhbkP = "";
	my $lowestIndex = length($$tP);
	my $shortestMatch;
	my $matchedTerm = "";
	my $contextBK = ($bkP ? $$bkP:"none");
	my $contextCH = ($chP ? $$chP:0);
	my $PREM = ($matchleft ? ".*?\\W":".*?");
	
	$$tP = " ".$$tP; # allow $PREM to match to beginning of string!

	# The following "IF" code assigns bk, ch, vs, and lv values with the following effect
	#	= -1 means remove from OSIS ref (verses only!)
	#	= 0 or "" means use context value (book & chapter only)
	#	> 0 or !"" means use this value, and return this value so it may be used in next match (book & chapter only)
	
	# Book? c:v-c:v
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?\d+\s*($chap2VerseTerms)\s*\d+\s*($continuationTerms)\s*\d+\s*($chap2VerseTerms)\s*\d+)/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;

		my $index = length($pre);		
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$$typeP = "T01 (Book? c:v-c:v)";
			$lowestIndex = $index;
			$shortestMatch = length($ref);
			if (!$matchleft) {
				$$bkP = $tbook;
				$ref =~ /(\d+)\s*($chap2VerseTerms)\s*(\d+)\s*($continuationTerms)\s*(\d+)\s*($chap2VerseTerms)\s*(\d+)/i;
				$$chP = $1;
				$$vsP = $3;
				my $c2 = $5;
				my $lv = $7;				
				if ($$chP eq $c2) {$$lvP = $lv;}
				else {$$lvP = -1;}
				$$barenumsP = "chapters";
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}
	}

	# Book? c:v-lv
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?\d+\s*($chap2VerseTerms)\s*\d+\s*($continuationTerms)\s*\d+)/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;

		my $index = length($pre);		
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$$typeP = "T02 (Book? c:v-lv)";
			$lowestIndex = $index;
			$shortestMatch = length($ref);
			if (!$matchleft) {
				$$bkP = $tbook;
				$ref =~ /(\d+)\s*($chap2VerseTerms)\s*(\d+)\s*($continuationTerms)\s*(\d+)/i;
				$$chP = $1;
				$$vsP = $3;
				$$lvP = $5;
				$$barenumsP = "verses"; #For: 9:1-17, 15 va 17-boblar, BUT ALSO HAVE китобнинг 10:1-11, 17
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}  
	}

	# Book? c:v
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chap2VerseTerms)\s*(\d+))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;
		my $tch = $6;
		my $tvs = $8;
		my $index = length($pre);		
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$$typeP = "T03 (Book? c:v)";
			$lowestIndex = $index;
			$shortestMatch = length($ref);	
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = $tch;
				$$vsP = $tvs;
				$$lvP = -1;
				$$barenumsP = "verses"; # For: something in UZV(?)
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}		
		}   
	}

	# Book? c ChapTerm v VerseTerm
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chapTerms)($suffixTerms)*\s*(\d+)\s*($verseTerms))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;

		my $index = length($pre);		
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$$typeP = "T04 (Book? c ChapTerm v VerseTerm)";
			$lowestIndex = $index;
			$shortestMatch = length($ref);
			if (!$matchleft) {
				$$bkP = $tbook;
				$ref =~ /(\d+)\s*($chapTerms)($suffixTerms)*\s*(\d+)\s*($verseTerms)/i;
				$$chP = $1;
				$$vsP = $4;
				$$lvP = -1;
				$$barenumsP = "chapters";
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}  
	}

	# Book? c-c ChapTerm
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($continuationTerms)\s*\d+\s*($chapTerms))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;
		my $tch = $6;
		
		my $index = length($pre);
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$$typeP = "T05 (c-c ChapTerm)";
			$lowestIndex = $index;
			$shortestMatch = length($ref);
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = $tch;
				$$vsP = -1;
				$$lvP = -1;
				$$barenumsP = "chapters";
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}   
	}

	# Book? c ChapTerm
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chapTerms))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;
		my $tch = $6;
		
		my $index = length($pre);
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$shortestMatch = length($ref);
			$$typeP = "T06 (Book? c ChapTerm)";
			$lowestIndex = $index;
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = $tch;
				$$vsP = -1;
				$$lvP = -1;
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}   
	}

	# Book|CurrentChap? v-v VerseTerms
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?(\d+)\s*($continuationTerms)\s*(\d+)\s*($verseTerms))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;
		my $tvs = $6;
		my $tlv = $8;
		
		my $index = length($pre);
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$shortestMatch = length($ref);
			$$typeP = "T07 (Book|CurrentChap? v-v VerseTerms)";
			$lowestIndex = $index;
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = "";
				$$vsP = $tvs;
				$$lvP = $tlv;
				$$barenumsP = "verses";  
				if ($$bkP =~ /($currentChapTerms)/i) {
					$$bkP = $contextBK;
					$$chP = $contextCH;
				}	
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}     
	}

	# Book|CurrentChap? v VerseTerms
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?(\d+)\s*($verseTerms))/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $4;
		my $tvs = $6;
				
		my $index = length($pre);
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$shortestMatch = length($ref);
			$$typeP = "T08 (Book|CurrentChap? v VerseTerms)";
			$lowestIndex = $index;
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = "";
				$$vsP = $tvs;
				$$lvP = -1;
				$$barenumsP = "verses";
				if ($$bkP =~ /($currentChapTerms)/i) {
					$$bkP = "";
				}
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}     
	}

	# Book|CurrentChap num1-num2?
	if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)(($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*(\d+)(\s*($continuationTerms)\s*(\d+))?)/i)) {
		my $pre = $1;
		my $ref = $2;
		my $tbook = $3;
		my $num1 = $5;
		my $num2 = $8;
		
		my $index = length($pre);
		if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
			$matchedTerm = $ref;
			$shortestMatch = length($ref);
			$$typeP = "T09 (Book|CurrentChap num1-num2?)";
			$lowestIndex = $index;
			if (!$matchleft) {
				$$bkP = $tbook;
				$$chP = "";
				if ($$bkP =~ /($currentChapTerms)/i) {
					$$bkP = "";
					$$barenumsP = "verses"; # For: шу бобнинг 20, 22, 29–оятларида ҳам иш
				}
				elsif ((($$bkP =~ /($currentBookTerms)/i) && ($contextBK =~ /($oneChapterBooks)/i)) || ($books{$$bkP} =~ /($oneChapterBooks)/i)) {
					$$chP = 1; 
					$$barenumsP = "verses";
				}
				else {$$barenumsP = "chapters";}

				if ($$barenumsP eq "chapters") {
					$$chP = $num1;
					$$vsP = -1;
					$$lvP = -1;
				}
				elsif ($$barenumsP eq "verses") {
					$$vsP = $num1;
					$$lvP = $num2;
					if (!$$lvP) {$$lvP = -1;}
				}
			}
			else {$$uhbkP = &unhandledBook($pre, \$tbook);}
		}     
	}

	# num1 ... num2?
	if ((!$matchleft && !$$typeP) && ($$tP =~ /^($PREM)((\d+)($refTerms)*(\d+)?)/i)) {
		$matchedTerm = $2;
		$$typeP = "T10 (num1 ... num2?)";
		my $num1 = $3;
		my $num2 = $5;
		$$bkP = "";
		$$chP = "";
		if ($contextBK =~ /($oneChapterBooks)/) {$$barenumsP = "verses"; $$chP = 1;}
		if ($$barenumsP eq "chapters") {
			$$chP = $num1;
			$$vsP = $num2;
			$$lvP = -1;
			if (!$$vsP) {$$vsP = -1;}
		}
		elsif ($$barenumsP eq "verses") {
			$$vsP = $num1;
			$$lvP = $num2;
			if (!$$lvP) {$$lvP = -1;}
		}
	}
		
	if ($matchedTerm && !$matchleft) {
		if (!$$bkP) {$$bkP = $contextBK;}
		if (!$$chP) {$$chP = $contextCH;}
		if ($$lvP <= $$vsP) {$$lvP = -1;}
		
		# Book
		if ($$bkP eq $contextBK) {}
		elsif ($$bkP =~ /($ebookNames)/i)                            {$$bkP = $books{$1};}
		elsif ($$bkP =~ /($currentBookTerms|$currentChapTerms)/i)    {$$bkP = $contextBK;}
		else {
			&Log("ERROR: Unexpected book value \"$book\".\n"); 
			$$bkP = $contextBK;
		}
	}
	
	$$tP =~ s/^ //; # undo our added space

#if ($matchleft) {&Log("$$tP, %%typeP, $$uhbkP\n");}

	return $matchedTerm;
}

sub unhandledBook($\$) {
	my $pre = shift;
	my $bkP = shift;
	if ($$bkP) {return "";}

	&decodeTerms(\$pre);
	if ($pre =~ /(^|\W)(\w*[^\w|>]*)$/) {
		my $ub = $2;
		if ($ub =~ /\w+/) {return $ub;}
	}
	return substr($pre, length($pre)-10, 10);
}

sub validOSISref($$$) {
	my $osisRef = shift;
	my $linkText = shift;
	my $noWarn = shift;
	my $bk1, $bk2, $ch1, $ch2, $vs1, $vs2; 
	if ($osisRef eq "") {return 0;}
	elsif ($osisRef =~ /^([^\.]+)\.(\d+)\.(\d+)-([^\.]+)\.(\d+)\.(\d+)$/) {
		$bk1 = $1;
		$ch1 = $2;
		$vs1 = $3;
		$bk2 = $4;
		$ch2 = $5;
		$vs2 = $6;	
		if (!$ch1 || !$ch2 || $ch1 != $ch2 || !$vs1 || !$vs2 || $vs2 <= $vs1) {return 0;}
	}
	elsif ($osisRef =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
		$bk1 = $1;
		$ch1 = $2;
		$vs1 = $3;
		if (!$ch1 || !$vs1) {return 0;}
	}
	elsif ($osisRef =~ /^([^\.]+)\.(\d+)$/) {
		$bk1 = $1;
		$ch1 = $2;
		if (!$ch1) {return 0;}
		if (!$noWarn) {&Log("$line WARNING: Short osisRef \"$osisRef\" found in \"$linkText\"\n");}
	}
	else {
		return 0;
	}
	
	my $bok1, $bok2;
	foreach $b (%books) {
		if ($bk1 && $bk1 eq $b) {$bok1 = 1;}
		if (!$bk2 || $bk2 eq $b) {$bok2 = 1;}
	}
	return ($bok1 && $bok2);
}

sub reverseAlpha($$) {
	my $a = shift;
	my $b = shift;

	my $ar = "";
	for (my $i=length($a)-1; $i>=0; $i--) {$ar .= substr($a, $i, 1);}
	my $br = "";
	for (my $i=length($b)-1; $i>=0; $i--) {$br .= substr($b, $i, 1);}
	if (ord(substr($a, 0, 1)) == ord(uc(substr($a, 0, 1))) && ord(substr($b, 0, 1)) != ord(uc(substr($b, 0, 1)))) {return -1;}
	if (ord(substr($a, 0, 1)) != ord(uc(substr($a, 0, 1))) && ord(substr($b, 0, 1)) == ord(uc(substr($b, 0, 1)))) {return 1;}

	return $a cmp $b;
}

