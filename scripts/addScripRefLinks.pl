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
#   CONTEXT_BOOK: OSISBK if-result XPATH - Will override the context 
#       book for any node with OSISBK if a result is returned by 
#       XPATH expression.
#   SKIP_XPATH - An XPATH expression used to skip particular elements
#       of text when searching for Scripture references. By default,
#       nothing is skipped.
#   ONLY_XPATH - An XPATH expression used to select only particular
#       elements of text to search for Scripture references. By default,
#       everything is searched.
#   FILTER - (no longer supported) A Perl regular expression used to
#       select only particular parts of text to search for Scripture
#       references. By default, everything is searched.
#   SKIP_INTRODUCTIONS - Boolean if true introductions are skipped.
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
#   LINE_EXCLUSION - (NO LONGER SUPPORTED) Was used to exclude certain 
#       references on certain lines.
#   FIX - Used to fix an incorrectly parsed reference.
#   SKIPVERSE - The osisRef of a verse to skip.

$DEBUG_LOCATION = 0;

require("$SCRD/scripts/processGlossary.pl");

sub addScripRefLinks($$) {
  my $in_file = shift;
  my $out_file = shift;

  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n-----------------------------------------------------\n\n", 1);

  # Globals
  %books;
  %UnhandledWords;
  %noDigitRef;
  %noOSISRef;
  %exclusion;
  %exclusionREP;
  %fix;
  @skipVerse;

  my $none = "nOnE";

  $ebookNames = $none;
  $oneChapterBooks = "Obad|Phlm|Jude|2John|3John";
  $skip_xpath = "";
  $only_xpath = "";
  $chapTerms = $none;
  $currentChapTerms = $none;
  $currentBookTerms = $none;
  $verseTerms = $none;
  $refTerms = $none;
  $prefixTerms = $none;
  $refEndTerms = $none;
  $suffixTerms = $none;
  $sepTerms = $none;
  $chap2VerseTerms = $none;
  $continuationTerms = $none;
  $skipUnhandledBook = $none;
  $mustHaveVerse = 0;
  $skipPsalms = 0;
  $require_book = 0;
  $skipintros = 0;
  $sp="\"";
  $numUnhandledWords = 0;
  $numMissedLeftRefs = 0;
  $numNoDigitRef = 0;
  $numNoOSISRef = 0;
  %xpathIfResultContextBook;

  $Types{"T01 (Book? c:v-c:v)"} = 0;
  $Types{"T02 (Book? c:v-lv)"} = 0;
  $Types{"T03 (Book? c:v)"} = 0;
  $Types{"T04 (Book? c ChapTerm v(-v)? VerseTerm)"} = 0;
  $Types{"T05 (c-c ChapTerm)"} = 0;
  $Types{"T06 (Book? c ChapTerm)"} = 0;
  $Types{"T07 (Book|CurrentChap? v-v VerseTerms)"} = 0;
  $Types{"T08 (Book|CurrentChap? v VerseTerms)"} = 0;
  $Types{"T09 (Book|CurrentChap num1-num2?)"} = 0;
  $Types{"T10 (num1 ... num2?)"} = 0;

  my $commandFile = "$INPD/CF_addScripRefLinks.txt";
  if (-e $commandFile) {
    &Log("READING COMMAND FILE \"$commandFile\"\n");
    &removeRevisionFromCF($commandFile);
    open(CF, "<:encoding(UTF-8)", $commandFile);
    my @abkn;
    while (<CF>) {
      $_ =~ s/\s+$//;

      if ($_ =~ /^(\#.*|\s*)$/) {next;}
      elsif ($_ =~ /^CONTEXT_BOOK:\s*(\S+)\s+(if\-result)\s+(.*?)\s*$/) {
        my $cbk = $1; my $op = $2; my $xp = $3;
        if ($op ne 'if-result' || "$OT_BOOKS $NT_BOOKS" !~ /\b$cbk\b/) {
          &Log("ERROR: Illegal CONTEXT_BOOK command.\n");
        }
        else {$xpathIfResultContextBook{$xp} = $cbk;}
        next;
      }
      elsif ($_ =~ /^SKIP_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$skip_xpath = $2;} next;}
      elsif ($_ =~ /^ONLY_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$only_xpath = $2;} next;}
      elsif ($_ =~ /^FILTER:(\s*\((.*?)\)\s*)?$/) {if ($2) {&Log("ERROR: CF_addScripRefLinks.txt: FILTER is no longer supported. Use ONLY_XPATH instead.\n");} next;}
      elsif ($_ =~ /^SKIP_INTRODUCTIONS:\s*(.*?)\s*$/) {$skipintros = $1; $skipintros = ($skipintros && $skipintros !~ /^false$/i ? 1:0); next;}
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
      elsif ($_ =~ /^DONT_MATCH_IF_NO_VERSE:(\s*(.*?)\s*)?$/) {if ($1) {$mustHaveVerse = $2;} next;}
      elsif ($_ =~ /^SKIP_PSALMS:(\s*(.*?)\s*)?$/) {if ($1) {$skipPsalms = $2;} next;}
      elsif ($_ =~ /^REQUIRE_BOOK:(\s*(.*?)\s*)?$/) {if ($1 && $2 !~ /^false$/i) {$require_book = 1;}}
      elsif ($_ =~ /^SKIPVERSE:\s*(.*?)\s*$/) {if ($1) {push(@skipVerse, $1);} next;}
      elsif ($_ =~ /^EXCLUSION:(Linking|Extended)?\s*(.*?): (.*) =/) {$exclusion{$2} .= $sp.$3.$sp; next;}
      elsif ($_ =~ /^EXCLUSION:\s*([^:]+)\s*:\s*(.*?)\s*$/) {$exclusion{$1} .= $sp.$2.$sp; next;}
      elsif ($_ =~ /^LINE_EXCLUSION:(\d+) Linking.*?: (.*?) =/) {&Log("ERROR CF_addScripRefLinks.txt: LINE_EXCLUSION is no longer supported. Use EXCLUSION instead.\n"); next;}
      elsif ($_ =~ /^LINE_EXCLUSION:(\d+)\s+(.*?)\s*$/) {&Log("ERROR CF_addScripRefLinks.txt: LINE_EXCLUSION is no longer supported. Use EXCLUSION instead.\n"); next;}
      elsif ($_ =~ /^FIX:(Check line (\d+):)?\"([^\"]+)\"=(.*?)$/) {$fix{$3} = $4; next;}
      elsif ($_ =~ /^([\S]+)\s*=\s*(.*)\s*$/) {
        my $lb = $2;
        my $elb = quotemeta($2);
        $books{$lb}=$1;
        push(@abkn, $elb);
      }
      else {
        &Log("ERROR: \"$_\" in command file was not handled.\n");
      }
    }
    close (CF);

    if (@abkn) {
      $ebookNames = '';
      my $bktsep='';
      for (my $i=0; $i<@abkn; $i++) {
        my $xg=0;
        my $xi=0;
        for (my $j=0; $j<@abkn; $j++) {if (length(@abkn[$j]) > $xg) {$xg=length(@abkn[$j]); $xi=$j;}}
        if (@abkn[$xi]) {$ebookNames .= $bktsep.@abkn[$xi]; $bktsep="|";}
        @abkn[$xi] = 0;
      }
    }

  }
  else {&Log("ERROR: Command file required: $commandFile\n"); die;}

  &Log("READING INPUT FILE: \"$in_file\".\n");
  &Log("WRITING INPUT FILE: \"$out_file\".\n");
  &Log("\n");
  
  my @files = &splitOSIS($in_file);
  foreach my $file (@files) {&processFile($file);}
  &joinOSIS($out_file);

  &Log("Finished adding <reference> tags.\n");
  &Log("\n");
  &Log("\n");
  &Log("#################################################################\n");
  &Log("\n");
  &Log("\n");

  # report other collected data
  my $tCheckRefs = $CheckRefs;
  my $aerefs = ($tCheckRefs =~ tr/\n//);
  &Log("$MOD REPORT: Listing of extended refs containing ambiguous number(s): ($aerefs instances)\n");
  if ($CheckRefs) {
    &Log("NOTE: These are cases where a number could be interpreted as either a verse\n");
    &Log("or a chapter depending upon context. These should be spot checked for accuracy.");
    &Log("$CheckRefs\n");
  }
  else {&Log("(no extended refs contain ambiguous numbers)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Listing of refs with unknown book names which defaulted to the context book: ($numUnhandledWords instances)\n");
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
  my $t = 0;
  foreach my $e (keys %exclusion) {my @tmp = split(/$sp$sp/, $exclusion{$e}); $t += @tmp;}
  &Log("$MOD REPORT: Listing of exclusions: ($t instances)\n");
  if (scalar(keys %exclusion)) {
    &reportExclusions(\%exclusion, \%exclusionREP, "verse");
  }
  else {&Log("(no exclusions were specified in command the file)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Listing of fixes: (".scalar(keys %fix)." instances)\n");
  if (scalar(keys %fix)) {
    foreach my $fx (keys %fix) {
      if ($fix{$fx} !~ /^\s*$/) {
        &Log("ERROR: Fix \"$fx\" was not applied.\n");
      }
    }
  }
  else {&Log("(no fixes were specified in the command file)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Listing of unlocated left refs which were skipped: ($numMissedLeftRefs instances)\n");
  if (scalar(keys %missedLeftRefs)) {
    &Log("NOTE: These occur when the end of an extended ref cannot be determined. To fix these, check \n");
    &Log("instances in the log above- modifying REF_END_TERMS in the command file is the usual adjustment.\n");
    foreach my $mlr (sort keys %missedLeftRefs) {
      &Log("<$mlr> $missedLeftRefs{$mlr}\n");
    }
  }
  else {&Log("(no unlocated left refs)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Listing of refs without digits which were skipped: ($numNoDigitRef instances)\n");
  if (scalar(keys %noDigitRef)) {
    &Log("NOTE: These occur when an extended ref or a subref contain no numbers. A large number \n");
    &Log("of these may indicate incorrect command file regular expressions.\n");
    foreach my $mlr (sort keys %noDigitRef) {
      &Log("$mlr $noDigitRef{$mlr}\n");
    }
  }
  else {&Log("(no refs without digits found)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Listing of subrefs with indeterminate osisRefs which were skipped: ($numNoOSISRef instances)\n");
  if (scalar(keys %noOSISRef)) {
    &Log("NOTE: These may indicate a ref which should be an EXCLUSION or a problem \n");
    &Log("with command file regular expressions. \n");
    foreach my $mlr (sort keys %noOSISRef) {
      &Log("<$mlr> $noOSISRef{$mlr}\n");
    }
  }
  else {&Log("(no subrefs with OSIS ref problems found)\n");}
  &Log("\n");

  &Log("$MOD REPORT: Grand Total Scripture Reference links: ($newLinks instances)\n");
  $newLinks = 0;
  foreach my $type (sort keys %Types) {
    &Log(sprintf("%5d - %s\n", $Types{$type}, $type));
    $newLinks += $Types{$type};
  }
  &Log("Found $newLinks total sub-links.\n");
  &Log("FINISHED!\n\n");

  &Log("LINK RESULTS FROM: $out_file\n");
  &Log("\n");

  my $xml = $XML_PARSER->parse_file($out_file);

  # check all reference tags
  &Log("$MOD REPORT: Checking osisRef attributes of links:\n");
  my @refs = $XPC->findnodes('//osis:reference', $xml);
  my $warns = ''; my $errs = '';
  foreach my $ref (@refs) {
    if ($ref->hasAttribute("type") && $ref->getAttribute("type") =~ /^(x-glossary|x-glosslink)$/) {next;}
    if (!$ref->hasAttribute("osisRef")) {
      $warns .= &bibleContext($ref, 1)." WARNING: Link \"".$ref."\" has no osisRef.\n";
    }
    elsif (!&validOSISref($ref->getAttribute("osisRef"), $ref->textContent, 1, 0)) {
      $errs .= &bibleContext($ref, 1)." ERROR: Link \"".$ref."\" has an illegal osisRef.\n";
    }
  }
  &Log("$warns$errs");
  &Log("Finished checking osisRefs.\n");
  &Log("\n");
}

sub processFile($) {
  my $osis = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);

  # get every text node
  my @allTextNodes = $XPC->findnodes('//text()', $xml);

  # apply text node filters and process desired text-nodes
  my %nodeInfo;
  foreach my $textNode (@allTextNodes) {
    if ($textNode =~ /^\s*$/) {next;}
    if ($XPC->findnodes('ancestor::*[@type=\'x-chapterLabel\']', $textNode)) {next;}
    if ($XPC->findnodes('ancestor::osis:header', $textNode)) {next;}
    if ($only_xpath) {
      my @only = $XPC->findnodes($only_xpath, $textNode);
      if (!@only || !@only[0]) {next;}
    }
    if ($skip_xpath) {
      my @skipped = $XPC->findnodes($skip_xpath, $textNode);
      if (@skipped && @skipped[0]) {
        my $t = @skipped[0]->toString();
        if ($t =~ /(<[^>]*>)/ && !$reportedSkipped{$1}) {
          $reportedSkipped{$1}++;
          &Log("NOTE: SKIP_XPATH skipping \"$1\".\n");
        }
        next;
      }
    }

    # get text node's context information
    my $bcontext = &bibleContext($textNode, 1);
    $BK = "unknown"; $CH = 0; $VS = 0; $LV = 0; $intro = 0;
    if ($bcontext =~ /^(\w+)\.(\d+)\.(\d+)\.(\d+)$/) {
      $BK = $1; $CH = $2; $VS = $3; $LV = $4; $intro = ($VS ? 0:1);
    }
    else {
      my $entryScope = &getEntryScope($textNode);
      if ($entryScope && $entryScope !~ /[\s\-]/) {$BK = $entryScope;}
      $CH = &glossaryContext($textNode);
    }
    
    # override context book if requested
    foreach my $xpath (keys %xpathIfResultContextBook) {
      my @r = $XPC->findnodes($xpath, $textNode);
      if (!@r || !@r[0]) {next;}
      $BK = $xpathIfResultContextBook{$xpath};
      last;
    }
    
    $LOCATION = "$BK.$CH.$VS";

    # display progress
    my $thisp = $LOCATION;
    $thisp =~ s/^([^\.]*\.[^\.]*)\..*$/$1/;
    if ($LASTP ne $thisp) {&Log("--> $thisp\n", 2);} $LASTP = $thisp;

    if ($intro && $skipintros) {next;}

    if ($skipPsalms eq "true" && $BK eq "Ps") {
      if (!$psw) {&Log("\nWARNING: SKIPPING THE BOOK OF PSALMS\n\n");} $psw = 1;
      next;
    }

    my $skip = 0;
    foreach my $av (@skipVerse) {
      if ($av eq "$BK.$CH.$VS") {
        &Log("$LOCATION NOTE: Skipping verse $av - on SKIP list\n");
        $skip = 1; last;
      }
    }
    if ($skip) {next;}

    # search for Scripture references in this text node and add newReference tags around them
    my $text = $textNode->data();
    my $isAnnotateRef = ($XPC->findnodes('ancestor-or-self::osis:reference[@type="annotateRef"]', $textNode) ? 1:0);
    &addLinks(\$text, $BK, $CH, $isAnnotateRef);
    if ($text eq $textNode->data()) {
      # handle the special case of <reference type="annotateRef">\d+</reference> which does not match a reference pattern
      # but can still be parsed because such an annotateRef must refer to a verse or chapter in the current scope
      if (!$isAnnotateRef || $text !~ /^\s*(\d+)\b/) {next;}
      my $ar = $1;
      my $or = "$BK.$CH.$ar";
      my @pv = $XPC->findnodes('preceding::osis:verse[@sID][1]', $textNode);
      if (@pv && @pv[0] && @pv[0]->getAttribute('sID') =~ /\.(\d+).(\d+)$/ && $1 ne $CH) {
        $or = "$BK.$ar"
      }
      $text = "<newReference osisRef=\"$or\">$text</newReference>";
    }

    # save changes for later (to avoid messing up line numbers)
    $nodeInfo{$textNode->unique_key}{'node'} = $textNode;
    $nodeInfo{$textNode->unique_key}{'text'} = $text;
  }

  # replace the old text nodes with the new
  foreach my $n (keys %nodeInfo) {
    $nodeInfo{$n}{'node'}->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($nodeInfo{$n}{'text'}), $nodeInfo{$n}{'node'});
    $nodeInfo{$n}{'node'}->unbindNode();
  }

  # complete osisRef attributes by adding the target Bible
  my $bible = "Bible";
  if ($MOD && $MODDRV =~ /Text/) {$bible = $MOD;}
  elsif ($ConfEntryP->{"Companion"}) {$bible = $ConfEntryP->{"Companion"}; $bible =~ s/,.*$//;}
  my @news = $XPC->findnodes('//newReference/@osisRef', $xml);
  foreach my $new (@news) {$new->setValue("$bible:".$new->getValue());}

  # remove (after copying attributes) pre-existing reference tags which contain newReference tags
  my @refs = $XPC->findnodes('//osis:reference[descendant::newReference]', $xml);
  foreach my $ref (@refs) {
    my @attribs = $ref->attributes();
    my @chdrn = $XPC->findnodes('child::node()', $ref);
    foreach $child (@chdrn) {
      $ref->parentNode()->insertBefore($child, $ref);
      if ($child->nodeName ne 'newReference') {next;}
      foreach $a (@attribs) {
        if ($a !~ /^\s*(.*?)="(.*)"$/) {&Log("ERROR: Bad attribute $a\n");}
        my $n = $1; my $v = $2;
        if ($child->hasAttribute($n) && $v ne $child->getAttribute($n)) {
          &Log("ERROR: reference $n=\"".$v."\" is overwriting newReference $n=\"".$child->getAttribute($n)."\"\n");
        }
        $child->setAttribute($n, $v);
      }
    }
    $ref->unbindNode();
  }

  # convert all newReference elements to reference elements
  my @nrefs = $XPC->findnodes('//newReference', $xml);
  $newLinks += scalar(@nrefs);
  foreach my $nref (@nrefs) {
    $nref->setNodeName("reference");
    $nref->setNamespace('http://www.bibletechnologies.net/2003/OSIS/namespace');
  }

  # write to out_file
  open(OUTF, ">$osis") or die "Could not open $osis.\n";
  print OUTF $xml->toString();
  close(OUTF);
}

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
  my $contextBookOK = shift;

#&Log("$LOCATION: addLinks $bk, $ch, $$tP\n");

  my @notags = split(/(<[^>]*>)/, $$tP);
  for (my $ts = 0; $ts < @notags; $ts++) {
    if (@notags[$ts] =~ /^<[^>]*>$/) {next;}
    my $ttP = \@notags[$ts];

    my $matchedTerm, $type, $unhandledBook;
    while (&leftmostTerm($ttP, \$matchedTerm, \$type, \$unhandledBook)) {

      if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG1: MatchedTerm=$matchedTerm Type=$type\n");}
      if (!&termAcceptable($matchedTerm, "$BK.$CH.$VS", \%exclusion, \%exclusionREP)) {&hideTerm($matchedTerm, $ttP); next;}

      #  Look at unhandledBook
      if ($unhandledBook) {
        if (!$contextBookOK && ($require_book || $unhandledBook =~ /$skipUnhandledBook/)) { # skip if its a tag- this could be a book name, but we can't include it in the link
#          &Log("$LOCATION WARNING: Skipped \"$matchedTerm\" - no BOOK (unhandled:$unhandledBook).\n");
          &hideTerm($matchedTerm, $ttP);
          next;
        }
        elsif (!$contextBookOK) {
#          &Log("$LOCATION WARNING: \"$matchedTerm\" - no BOOK (unhandled:$unhandledBook).\n");
        }
      }

      my $mtENC = quotemeta($matchedTerm);

      if ($$ttP !~ /(($prefixTerms)?$mtENC($suffixTerms)*($prefixTerms|$ebookNames|$chapTerms|$verseTerms|$suffixTerms|$sepTerms|$refTerms|\d|\s)*)($refEndTerms)/) {
        &Log("$LOCATION ERROR: Left-most term \"$matchedTerm\" Type \"$type\" could not find in \"$$ttP\".\n");
        $numMissedLeftRefs++;
        $missedLeftRefs{$matchedTerm} .= $LOCATION.", ";
        &hideTerm($matchedTerm, $ttP, 1);
        next;
      }
      my $extref = $1;
      my $pextref = $extref; $pextref =~ s/\n/\\n/g;

      if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG2: extref=\"$pextref\" endref=\"$8\"\n");}

      # Skip if no digits
      if ($extref !~ /\d+/) {
        $numNoDigitRef++;
        $noDigitRef{"<$extref> (extref)"} .= $LOCATION.", ";
        &Log("$LOCATION WARNING: Skipped \"$pextref\" - no DIGITS.\n");
        &hideTerm($matchedTerm, $ttP);
        next;
      }

      # Skip if on line Exclusion lists
      if (!&termAcceptable($extref, "$BK.$CH.$VS", \%exclusion, \%exclusionREP)) {&hideTerm($extref, $ttP); next;}

      my $repExtref = "";
      my $shouldCheck = 0;

      # Fix if on fix list
      foreach $fx (keys %fix) {
        if ($fx eq $extref) {
          $repExtref = $fix{$fx};
          if ($repExtref =~ s/<r\s*([^>]+)>(.*?)<\/r>/<newReference osisRef="$1">$2<\/newReference>/g) {
            &Log("$LOCATION NOTE: Fixed \"$pextref\" - on FIX list.\n");
          }
          else {
            &Log("$LOCATION ERROR: Fix for \"$pextref\" failed!\n");
          }
          $fix{$fx} = "";
          goto ADDLINK;
        }
      }

      # Now break ref up into its subrefs, and extract OSIS ref for each subref
      my $tbk = $bk;
      my $tch = $ch;
      my $bareNumbersAre = "chapters";
      if ($tbk =~ /($oneChapterBooks)/i) {$bareNumbersAre = "verses"; $ch = 1;}

      my @subrefArray = split(/($sepTerms)/, $extref);
      if (@subrefArray > 1) {&Log("$LOCATION Extended: $pextref = \n");}
      foreach my $subref (@subrefArray) {
        my $psubref = $subref; $psubref =~ s/\n/\\n/g;
        if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG3: subref=\"$psubref\"\n");}

        # Keep sepTerms
        if ($subref =~ /($sepTerms)/) {
          $repExtref .= $subref;
          next;
        }

        if (!$subref) {next;}

        # Skip subrefs without numbers
        if ($subref !~ /\d+/) {
          $numNoDigitRef++;
          $noDigitRef{"<$subref> (subref)"} .= $LOCATION.", ";
          $repExtref .= $subref;
          &Log("$LOCATION WARNING: Skipped subref \"$psubref\" - no DIGITS.\n");
          next;
        }

        # Now parse out this subref
        my $osisRef;
        if (!&getOSISRef(\$subref, \$osisRef, \$type, \$tbk, \$tch, \$bareNumbersAre)) {
          $numNoOSISRef++;
          $noOSISRef{$subref} .= $LOCATION.", ";
          $repExtref .= $subref;
          &Log("$LOCATION WARNING: Skipping subref \"$psubref\", osisref is \"$osisRef\".\n");
          next;
        }

        if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG4: MatchedTerm=$matchedTerm\n");}

        $Types{$type}++;
        if ($type eq "T09 (num1 ... num2?)") {$shouldCheck = 1;}

        $repExtref .= "<newReference osisRef=\"".$osisRef."\">".$subref."<\/newReference>";
        &Log("$LOCATION Linking: $psubref = $osisRef ($type)\n");
      }

      ADDLINK:
      if ($unhandledBook) {
        $numUnhandledWords++;
        my $ubk = $unhandledBook;
        $ubk =~ s/^.*>$/<tag>/;
        $ubk =~ s/^.*\($/(/;
        $UnhandledWords{$ubk} .= $LOCATION.", ";
      }
      
      my $repExtrefENC = &encodeTerm($repExtref);
      if ($$ttP !~ s/\Q$extref/$repExtrefENC/) {&Log("$LOCATION ERROR: Could not replace \"$pextref\".\n");}

      if ($shouldCheck) {
        $prf = $repExtref;
        $prf =~ s/osisRef="([^"]+)"/$1/g;
        $prf =~ s/newReference/r/g;
        $CheckRefs .= "\nCheck location $LOCATION:\"$pextref\"=$prf";
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
#&Log("DEBUG: t=$t, key=$key, " . $excP->{$key} . " =~ /$sp$tre$sp/ is " . (($excP->{$key} && $excP->{$key} =~ /$sp$tre$sp/) ? "true":"false") . "\n");
  if ($excP->{$key} && $excP->{$key} =~ /$sp$tre$sp/) {
    $doneExcP->{$key} .= $sp.$t.$sp;
    &Log("$LOCATION NOTE $key: Skipped \"$t\" - on EXCLUDE list.\n");
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

  if ($$tP !~ s/$re1/$re2/) {&Log("$LOCATION ERROR: Could not hide term \"$mt\" in \"$$tP\".\n");}
}

sub encodeTerm($) {
  my $t = shift;
  if ($t =~ /(\{\{\{|\}\}\})/ || $t =~ /(._){2,}/) {
    &Log("LOCATION ERROR: String already partially encoded \"$t\".\n");
  }
  $t =~ s/(.)/$1_/gs;
  return "{{{".$t."}}}";
}

sub decodeTerms(\$) {
  my $tP = shift;

  while ($$tP =~ /(\{\{\{(.*?)\}\}\})/s) {
    my $re1 = $1;
    my $et = $2;

    my $re2 = "";
    for (my $i=0; $i<length($et); $i++) {
      my $chr = substr($et, $i, 1);
      if (!($i%2)) {$re2 .= $chr;}
      elsif ($chr ne "_") {&Log("$LOCATION ERROR: Incorectly encoded reference text \"$re1\".\n");}
    }

    $$tP =~ s/\Q$re1/$re2/;
  }
}

# Finds the left-most reference match.
# Modifies:
#       $matchP - holds the matched text
#       $typeP - holds the type of match
#       $uhbkP - holds the word preceding the matched text IF no book or book-term was matched.
#                        The uhkP value is null only if a book or book-term WAS matched
# Returns:
#       1 if a match was found
#       0 otherwise
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
#       $osisP - holds OSIS ref for the sub-ref
#       $typeP - holds the type of match used
#       $bk, $ch, $barenumsP - holds values associated with the sub-ref that will
#                        carry over to the next sub-ref in its extended ref.
# Returns:
#       1 if a match was found and a valid OSIS ref was parsed
#       0 otherwise
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

    # Some Ps have a verse 0 canonical title, but SWORD does not support verse "0".
    # so move these references so they point to verse 1 and are not just dropped.
    if ($$bkP eq "Ps" && $vs == 0) {$vs++;}

    # A value of -1 means don't include verse in OSIS ref
    if ($vs != -1) {$$osisP .= ".".$vs;}
    if ($lv != -1 && $lv > $vs) {$$osisP .= "-".$$bkP.".".$$chP.".".$lv;}
  }

  return &validOSISref($$osisP, 0, 0, 1);
}

# Finds a single reference match in a string, matching either the left-most
# possible, or else the most complete match, depending on the $matchleft parameter.
# Modifies:
#       $typeP - holds the type of match found
#       $uhbkP - holds the word preceding the matched text IF no book or book-term was matched.
#                        The uhkP value should only be null if a book or book-term WAS matched
#       $bk, $ch, $vs, $lv, $bn - holds values associated with the match.
# Returns:
#       The matched reference text
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
  my $contextBK = ($bkP ? $$bkP:$none);
  my $contextCH = ($chP ? $$chP:0);
  my $PREM = ($matchleft ? ".*?\\W":".*?");

  $$tP = " ".$$tP; # allow $PREM to match to beginning of string!

  # The following "IF" code assigns bk, ch, vs, and lv values with the following effect
  #     = -1 means remove from OSIS ref (verses only!)
  #     = 0 or "" means use context value (book & chapter only)
  #     > 0 or !"" means use this value, and return this value so it may be used in next match (book & chapter only)

  # Book? c:v-c:v
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?\d+\s*($chap2VerseTerms)\s*\d+\s*($continuationTerms)\s*\d+\s*($chap2VerseTerms)\s*\d+)/si)) {
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
        $ref =~ /(\d+)\s*($chap2VerseTerms)\s*(\d+)\s*($continuationTerms)\s*(\d+)\s*($chap2VerseTerms)\s*(\d+)/si;
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
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?\d+\s*($chap2VerseTerms)\s*\d+\s*($continuationTerms)\s*\d+)/si)) {
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
        $ref =~ /(\d+)\s*($chap2VerseTerms)\s*(\d+)\s*($continuationTerms)\s*(\d+)/si;
        $$chP = $1;
        $$vsP = $3;
        $$lvP = $5;
        $$barenumsP = "verses"; #For: 9:1-17, 15 va 17-boblar, BUT ALSO HAVE китобнинг 10:1-11, 17
      }
      else {$$uhbkP = &unhandledBook($pre, \$tbook);}
    }
  }

  # Book? c:v
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chap2VerseTerms)\s*(\d+))/si)) {
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

  # Book? c ChapTerm v(-v)? VerseTerm
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chapTerms)($suffixTerms)*\s*\d+\s*(($continuationTerms)\s*\d+\s*)?($verseTerms))/si)) {
    my $pre = $1;
    my $ref = $2;
    my $tbook = $4;

    my $index = length($pre);
    if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
      $matchedTerm = $ref;
      $$typeP = "T04 (Book? c ChapTerm v(-v)? VerseTerm)";
      $lowestIndex = $index;
      $shortestMatch = length($ref);
      if (!$matchleft) {
        $$bkP = $tbook;
        $ref =~ /(\d+)\s*($chapTerms)($suffixTerms)*\s*(\d+)\s*(($continuationTerms)\s*(\d+)\s*)?($verseTerms)/si;
        $$chP = $1;
        $$vsP = $4;
        $$lvP = ($5 ? $7:-1);
        $$barenumsP = "chapters";
      }
      else {$$uhbkP = &unhandledBook($pre, \$tbook);}
    }
  }

  # Book? c-c ChapTerm
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($continuationTerms)\s*\d+\s*($chapTerms))/si)) {
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
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?(\d+)\s*($chapTerms))/si)) {
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
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?(\d+)\s*($continuationTerms)\s*(\d+)\s*($verseTerms))/si)) {
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
        if ($$bkP =~ /($currentChapTerms)/si) {
          $$bkP = $contextBK;
          $$chP = $contextCH;
        }
      }
      else {$$uhbkP = &unhandledBook($pre, \$tbook);}
    }
  }

  # Book|CurrentChap? v VerseTerms
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?(\d+)\s*($verseTerms))/si)) {
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
        if ($$bkP =~ /($currentChapTerms)/si) {
          $$bkP = "";
        }
      }
      else {$$uhbkP = &unhandledBook($pre, \$tbook);}
    }
  }

  # Book|CurrentChap num1-num2?
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)(($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*(\d+)(\s*($continuationTerms)\s*(\d+))?)/si)) {
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
        if ($$bkP =~ /($currentChapTerms)/si) {
          $$bkP = "";
          $$barenumsP = "verses"; # For: шу бобнинг 20, 22, 29–оятларида ҳам иш
        }
        elsif ((($$bkP =~ /($currentBookTerms)/si) && ($contextBK =~ /($oneChapterBooks)/si)) || ($books{$$bkP} =~ /($oneChapterBooks)/si)) {
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
  if ((!$matchleft && !$$typeP) && ($$tP =~ /^($PREM)((\d+)($refTerms)*(\d+)?)/si)) {
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
    elsif ($$bkP =~ /($ebookNames)/si)                            {$$bkP = $books{$1};}
    elsif ($$bkP =~ /($currentBookTerms|$currentChapTerms)/si)    {$$bkP = $contextBK;}
    else {
      &Log("ERROR: Unexpected book value \"$book\".\n");
      $$bkP = $contextBK;
    }
  }

  $$tP =~ s/^ //; # undo our added space

  if ($LOCATION eq $DEBUG_LOCATION) {&Log(sprintf("DEBUG_matchRef:\nmatchleft=%s\nt=%s\ntype=%s\nuhbk=%s\nbk=%s\nch=%s\nvs=%s\nlv=%s\nbarenums=%s\n\n", $matchleft, $$tP, $$typeP, $$uhbkP, $$bkP, $$chP, $$vsP, $$lvP, $$barenumsP));}
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

sub validOSISref($$$$) {
  my $osisRef = shift;
  my $linkText = shift;
  my $strict = shift;
  my $noWarn = shift;

  my $bk1, $bk2, $ch1, $ch2, $vs1, $vs2;
  if ($strict && $osisRef !~ s/^\w+\://) {return 0;}
  elsif ($osisRef eq "") {return 0;}
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
    if (!$noWarn) {&Log("$LOCATION WARNING: Short osisRef \"$osisRef\" found in \"$linkText\"\n");}
  }
  else {return 0;}

  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($VERSESYS);
  my $bok1 = $vk->getBookNumberByOSISName($bk1) != -1;
  my $bok2 = ($bk2 == "" || $vk->getBookNumberByOSISName($bk2) != -1);

  return ($bok1 && $bok2);
}

sub reverseAlpha($$) {
  my $a = shift;
  my $b = shift;

  my $ar = "";
  for (my $i=length($a)-1; $i>=0; $i--) {$ar .= substr($a, $i, 1);}
  my $br = "";
  for (my $i=length($b)-1; $i>=0; $i--) {$br .= substr($b, $i, 1);}
  if (ord(substr($a, 0, 1)) == ord(&uc2(substr($a, 0, 1))) && ord(substr($b, 0, 1)) != ord(&uc2(substr($b, 0, 1)))) {return -1;}
  if (ord(substr($a, 0, 1)) != ord(&uc2(substr($a, 0, 1))) && ord(substr($b, 0, 1)) == ord(&uc2(substr($b, 0, 1)))) {return 1;}

  return $a cmp $b;
}

1;
