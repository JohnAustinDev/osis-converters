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

use strict;

our ($WRITELAYER, $APPENDLAYER, $READLAYER, $LOGFLAG);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR, $SCRIPT_NAME);
our ($OSISBOOKSRE, %OSIS_ABBR, %OSIS_GROUP, $XPC, $XML_PARSER, $LOGFILE, $NO_FORKS, $DEBUG);

# TERMINOLOGY:
# ----------------------
#   A "reference" is a reference to a contiguous Scripture text. For
#   example: "Matt 1:1-5".
#   An "extended reference" is a list of Scripture references. For
#   example: "John 4:5; 6:7-9, 11, 13; 1 Peter 1:3 and Rev 20:1-5" is
#   a single extended reference.

# NO LONGER SUPPORTED:
# --------------------
#   LINE_EXCLUSION - Use FIX instead.
#   EXCLUSION - Use FIX instead.
#   FILTER - Use SKIP_XPATH and/or ONLY_XPATH instead.
#   SKIP_PSALMS - Use SKIP_XPATH instead.
#   SKIPVERSE - Use SKIP_XPATH instead.
#   SKIP_INTRODUCTIONS - Use SKIP_XPATH instead.

my $DEBUG_LOCATION = 0;

# These must be 'our' because some are accessed via symbolic reference.
our (%UnhandledWords, %noDigitRef, %noOSISRef, %fixDone, 
    $numMissedLeftRefs, $numNoDigitRef, $numNoOSISRef, %Types, 
    $CheckRefs, $newLinks);

# These must be 'our' because some are accessed via symbolic reference.
our (%books, $ebookNames, $oneChapterBooks, $skip_xpath, $only_xpath, 
    $chapTerms, $currentChapTerms, $currentBookTerms, $verseTerms, 
    $refTerms, $prefixTerms, $refEndTerms, $suffixTerms, $sepTerms, 
    $chap2VerseTerms, $continuationTerms, $sp, $numUnhandledWords, %fix,
    %xpathIfResultContextBook, %xpathIfResultWorkPrefix, %asrlworks,
    $LOCATION, $BK, $CH, $VS, $LV, %missedLeftRefs, $LASTP, @OSIS_ABBR,
    %OSIS_ABBR);
   
my $none = "nOnE";
my $fixReplacementMsg = "
   The FIX replacement (after the equal sign) must either be nothing to
   unlink, or of the shorthand form \"<r Gen.1.1>Genesis 1 verse 1</r>\" to
   fix. The replacement must be enclosed by double quotes, and any double
   quotes in the replacement must be escaped with '\'.";
   
require("$SCRD/lib/forks/fork_funcs.pm");

sub addScripRefLinks {
  my $in_file = shift;
  
  my $osis = $$in_file;
  my $out_file = &temporaryFile($osis);

  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n-----------------------------------------------------\n\n", 1);

  &read_CF_ASRL("$INPD/CF_addScripRefLinks.txt");
  
  &Log("READING INPUT FILE: \"$osis\".\n");
  &Log("WRITING INPUT FILE: \"$out_file\".\n");
  &Log("\n");
  
  our %asrlworks; # collect works that are referenced
  
  my @files = &splitOSIS($osis);
  
  # Get the refSystem
  my $xml = $XML_PARSER->parse_file(@files[0]);
  my $refSystem = &getOsisRefSystem($xml);
  
  if ($NO_FORKS =~ /\b(1|true|AddScripRefLinks)\b/) {
    &Warn("Running addScripRefLinks without forks.pm", 
    "Un-set NO_FORKS in the config.conf [system] section to enable parallel processing for improved speed.", 1);
    foreach my $osis (@files) {&asrlProcessFile($osis, $refSystem);}
  }
  else {
    # Run addScripRefLinks2 in parallel on each book
    my $ramkb = 634000; # Approx. KB RAM usage per fork
    my $exv = system(
      &escfile("$SCRD/lib/forks/forks.pm") . ' ' .
      &escfile($INPD) . ' ' .
      &escfile($LOGFILE) . ' ' .
      $SCRIPT_NAME . ' ' .
      &escfile(__FILE__) . ' ' .
      "addScripRefLinks2" . ' ' .
      "ramkb:$ramkb" . ' ' .
      "arg3:$refSystem" . ' ' .
      join(' ', map(&escfile("arg1:$_"), @files))
    );
    &handleAbort($exv, "addScripRefLinks2", __FILE__);
    &reassembleForkData(__FILE__);
  }
  
  &joinOSIS($out_file);
  
  $$in_file = $out_file;
  
  &addWorkElements($in_file, \%asrlworks);
  
  &Log("Finished adding <reference> tags.\n");
  &Log("\n");
  &Log("\n");
  &Log("#################################################################\n");
  &Log("\n");
  
  # Report the reassembled data
  &reportAddScripRefLinks();
}

sub read_CF_ASRL {
  my $commandFile = shift;
  
  # Globals
  $newLinks = 0;
  %books;
  %UnhandledWords;
  %noDigitRef;
  %noOSISRef;
  %fix;
  %fixDone;

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
  $sp="\"";
  $numUnhandledWords = 0;
  $numMissedLeftRefs = 0;
  $numNoDigitRef = 0;
  $numNoOSISRef = 0;
  %xpathIfResultContextBook;
  %xpathIfResultWorkPrefix;

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

  my %bookNamesWithPerlChars;
  if (-e $commandFile) {
    &Log("READING COMMAND FILE \"$commandFile\"\n");
    open(CF, $READLAYER, $commandFile);
    my @abkn;
    while (<CF>) {
      $_ =~ s/\s+$//;

      if ($_ =~ /^(\#.*|\s*)$/) {next;}
      elsif ($_ =~ /^(CONTEXT_BOOK|WORK_PREFIX):\s*(\S+)\s+(if\-xpath)\s+(.*?)\s*$/) {
        my $cmd = $1; my $cbk = $2; my $op = $3; my $xp = $4;
        if ($op eq 'if-xpath') {
          if ($cmd eq 'CONTEXT_BOOK' && !defined($OSIS_ABBR{$cbk})) {
            &Error(
"$cmd \"$cbk\" in CF_addScripRefLinks.txt is not an OSIS book abbreviation.", 
"Change it to an abbreviation from this list: " . join(' ', @{$OSIS_GROUP{'OT'}}, @{$OSIS_GROUP{'NT'}}));
          }
          else {
            &Note("$cmd will be $cbk for nodes returning true for $xp");
            if    ($cmd eq 'CONTEXT_BOOK') {$xpathIfResultContextBook{$xp} = $cbk;}
            elsif ($cmd eq 'WORK_PREFIX')  {$xpathIfResultWorkPrefix{$xp} = $cbk;}
            else {&Error(
"Unknown command $cmd in CF_addScripRefLinks.txt",
"This command must be 'CONTEXT_BOOK' or 'WORK_PREFIX'");
            }
          }
        }
        else {&Error(
"Unknown test-type $op in CF_addScripRefLinks.txt", 
"This test-type must be 'if-xpath'");}
        next;
      }
      elsif ($_ =~ /^SKIP_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$skip_xpath = $2;} next;}
      elsif ($_ =~ /^ONLY_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$only_xpath = $2;} next;}
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
      elsif ($_ =~ /^(FIX:\s*(.*?)\s+(?:Linking:\s*)?(?<!\\)"(.*)(?<!\\)"\s*=)/) { # must match output of logLink
        my $com = $1; my $location = $2; my $printReference = $3;
        my $replacement;
        if ($_ =~ /^\Q$com\E\s*(?<!\\)"(.*<\/r>.*)(?<!\\)"\s*$/) {$replacement = $1;}
        elsif ($_ !~ /^\Q$com\E\s*$/) {
          &Error("Bad FIX command in CF_addScripRefLinks.txt: $_", $fixReplacementMsg);
        }
        $printReference =~ s/\\"/"/g; $replacement =~ s/\\"/"/g; # unescape any escaped double quotes
        $fix{$location}{$printReference} = ($replacement ? $replacement:'skip');
        # If this FIX targets a DICT entry that has duplicate lemmas, fix the aggregate entry as well.
        my $agglocation = $location;
        if ($agglocation =~ s/\.(?=dup\d+\.)/!/) {
          $fix{$agglocation}{$printReference} = ($replacement ? $replacement:'skip');
        }
      }
      elsif ($_ =~ /^([\S]+)\s*=\s*(.+?)\s*$/) {
        my $osisbk = $1; my $lb = $2;
        if ($OSIS_ABBR{$osisbk}) {
          my $elb = quotemeta($lb);
          $books{$lb} = $osisbk;
          if ($lb && $lb =~ /[\.\?\*]/) {$bookNamesWithPerlChars{$lb}++;}
          push(@abkn, $elb);
        }
        else {
          &Error("CF_addScripRefLinks.txt line \"$_\", '$osisbk' is not an OSIS book abbreviation.", "Valid OSIS abbreviations are: @OSIS_ABBR");
        }
      }
      else {
        &Error("CF_addScripRefLinks.txt line \"$_\" was not handled.", "Check the syntax of this line and remove, change, or comment it out with '#'.");
      }
    }
    close (CF);
    
    
    # insure that $refTerms includes $sepTerms, $chap2VerseTerms and $continuationTerms
    {
      my @terms = split(/\|/, $refTerms);
      push(@terms, split(/\|/, $sepTerms));
      push(@terms, split(/\|/, $chap2VerseTerms));
      push(@terms, split(/\|/, $continuationTerms));
      my %seen; @terms = grep(!$seen{$_}++, @terms);
      $refTerms = join('|', sort { length($a) <=> length($b) } @terms);
    }
    
    if (scalar keys %bookNamesWithPerlChars) {
      &Warn(
"Terms to the right of '=' in book name assignments in 
CF_addScripRefLinks.txt are NOT Perl regular expressions but are string 
literals (however, these terms may have PREFIXES before or SUFFIXES 
after the name and still match).", 
"If you are using punctuation in the follwing book terms then all is 
well. But if you are trying to use regular expressions in the following 
book terms, they will not work as regex, but instead add each book name 
that you wish to match on a separate line:");
      foreach my $bname (sort keys %bookNamesWithPerlChars) {&Log("$bname\n");}
    }

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
  else {&ErrorBug("The CF_addScripRefLinks.txt command file is required to run addScripRefLinks.pm and a default file could not be found.", 1); return;}
}

# This function is run in its own thread.
sub addScripRefLinks2 {
  my $osis = shift;
  my $refSystem = shift;

  $LOGFLAG = 3; # Already logged in addScripRefLinks
  &read_CF_ASRL("$INPD/CF_addScripRefLinks.txt");
  $LOGFLAG = undef;
  
  &asrlProcessFile($osis, $refSystem);
}

sub reportAddScripRefLinks {

  # report other collected data
  my $tCheckRefs = $CheckRefs;
  my $aerefs = ($tCheckRefs =~ tr/\n//);
  &Report("Listing of extended refs containing ambiguous number(s): ($aerefs instances)");
  if ($CheckRefs) {
    &Warn("<-These are cases where a number could be interpreted as either a verse
or a chapter depending upon context.", "That these are interpereted correctly.");
    &Log("$CheckRefs\n");
  }
  else {&Log("(no extended refs contain ambiguous numbers)\n");}

  &Report("Listing of refs with unknown book names which defaulted to the context book: ($numUnhandledWords instances)");
  if (scalar(keys %UnhandledWords)) {
    &Warn("<-Any Bible book names or abbreviations appearing between < > in the following 
listing are resulting in incorrect Scripture links.", 
"That you have correctly specified these book names in 
CF_addScripRefLinks.txt with a line such as: Matt = Matthew");
    foreach my $uw (sort keys %UnhandledWords) {
      &Log("<$uw> $UnhandledWords{$uw}\n");
    }
  }
  else {&Log("(no unknown book names)\n");}
  my $t = 0;
  foreach my $loc (sort keys %fix) {foreach my $ref (sort keys %{$fix{$loc}}) {if ($fix{$loc}{$ref} eq 'skip') {$t++;}}}
  &Report("Listing of exclusions: ($t instances)");
  if ($t) {&reportFixes(\%fix, \%fixDone, "skip");}
  else {&Log("(no exclusions were specified in command the file)\n");}

  my $t = 0;
  foreach my $loc (sort keys %fix) {foreach my $ref (sort keys %{$fix{$loc}}) {if ($fix{$loc}{$ref} ne 'skip') {$t++;}}}
  &Report("Listing of fixes: ($t instances)");
  if ($t) {&reportFixes(\%fix, \%fixDone, "fix");}
  else {&Log("(no fixes were specified in the command file)\n");}

  &Report("Listing of unlocated left refs which were skipped: ($numMissedLeftRefs instances)");
  if (scalar(keys %missedLeftRefs)) {
    &Warn("<-This occurs when the end of an extended reference cannot be determined.",
"That REF_END_TERMS in CF_addScripRefLinks.txt includes the end term for
these references (see the errors in the log listing above)");
    foreach my $mlr (sort keys %missedLeftRefs) {
      &Log("<$mlr> $missedLeftRefs{$mlr}\n");
    }
  }
  else {&Log("(no unlocated left refs)\n");}

  &Report("Listing of refs without digits which were skipped: ($numNoDigitRef instances)");
  if (scalar(keys %noDigitRef)) {
    &Warn("<-These occur when an extended reference or a sub-reference contain no numbers.", 
    "That CF_addScripRefLinks.txt file regular expressions are correct.");
    foreach my $mlr (sort keys %noDigitRef) {
      &Log("$mlr $noDigitRef{$mlr}\n");
    }
  }
  else {&Log("(no refs without digits found)\n");}

  &Report("Listing of subrefs with indeterminate osisRefs which were skipped: ($numNoOSISRef instances)");
  if (scalar(keys %noOSISRef)) {
    &Warn("<-These may indicate references which need FIX or 
CF_addScripRefLinks.txt regular expression problems.");
    foreach my $mlr (sort keys %noOSISRef) {
      &Log("<$mlr> ".$noOSISRef{$mlr}."\n");
    }
  }
  else {&Log("(no subrefs with OSIS ref problems found)\n");}

  &Report("Grand Total Scripture Reference links: ($newLinks instances)");
  $newLinks = 0;
  foreach my $type (sort keys %Types) {
    &Log(sprintf("%5d - %s\n", $Types{$type}, $type));
    $newLinks += $Types{$type};
  }
  &Log("Found $newLinks total sub-links.\n");
  &Log("FINISHED!\n\n");
}

sub asrlProcessFile {
  my $osis = shift;
  my $refSystem = shift;
  
  my $xml;
  my $element = &splitOSIS_element($osis, \$xml);
  
  my $work = &getOsisBibleModName($xml);
  $work = ($work eq $MOD ? '':$work);

  # get every text node
  my @allTextNodes = $XPC->findnodes('descendant::text()', $element);

  # apply text node filters and process desired text-nodes
  my %nodeInfo;
  foreach my $textNode (@allTextNodes) {
    if ($textNode =~ /^\s*$/) {next;}
    # Years ago the following line was necessary, but probably is not any longer. Not parsing refs in chapterLabels causes other failures, however.
    #if ($XPC->findnodes('ancestor::*[starts-with(@type, "x-chapterLabel")]', $textNode)) {next;}
    if ($XPC->findnodes('ancestor::osis:header', $textNode)) {next;}
    if ($only_xpath) {
      my @only = $XPC->findnodes($only_xpath, $textNode);
      if (!@only || !@only[0]) {next;}
    }
    if ($skip_xpath) {
      my @skipped = $XPC->findnodes($skip_xpath, $textNode);
      if (@skipped[0]) {
        &Note("SKIP_XPATH is skipping: \"".substr($textNode, 0, 128)."\".");
        next;
      }
    }

    # get text node's context information
    $BK = "unknown";
    $CH = 0;
    $VS = 0;
    $LV = 0;
    if ($refSystem =~ /^Bible/) {
      my $bcontext = &bibleContext($textNode);
      if ($bcontext !~ /^(\w+)\.(\d+)\.(\d+)\.(\d+)$/) {
        &ErrorBug("Unrecognized Bible context \"$bcontext\" in textNode \"$textNode\"");
        next;
      }
      $BK = $1;
      $CH = $2;
      $VS = $3;
      $LV = $4;
    }
    elsif ($refSystem =~ /^Dict/) {
      my $entryScope = &getGlossaryScopeAttribute($textNode);
      if ($entryScope && $entryScope !~ /[\s\-]/) {$BK = $entryScope;}
      $CH = &decodeOsisRef(@{&atomizeContext(&getNodeContext($textNode))}[0]);
    }
    else {
      $CH = @{&atomizeContext(&getNodeContext($textNode))}[0];
    }
    
    # override context book if requested
    foreach my $xpath (sort keys %xpathIfResultContextBook) {
      my @r = $XPC->findnodes($xpath, $textNode);
      if (@r && @r[0]) {$BK = $xpathIfResultContextBook{$xpath};}
    }
    
    $LOCATION = "$BK.$CH.$VS";

    # display progress
    my $thisp = $LOCATION;
    $thisp =~ s/^([^\.]*\.[^\.]*)\..*$/$1/;
    if ($LASTP ne $thisp) {&Log("--> $thisp\n", 2);} $LASTP = $thisp;
    
    # if this is an explicit reference, process it as such
    my $reference = @{$XPC->findnodes('ancestor::osis:reference', $textNode)}[0];
    if ($reference) {
      if ($reference->hasAttribute('osisRef') || 
          $reference->getAttribute('type') =~ /x\-gloss/) {next;}
      my $newRefs = &getLinksReference($work, $reference);
      if ($newRefs) {
        $nodeInfo{$textNode->unique_key}{'node'} = $textNode;
        $nodeInfo{$textNode->unique_key}{'text'} = $newRefs;
      }
      else {
        &Error("Could not determine osisRef of reference element:".$reference->toString());
      }
    }
    else {
      # search for Scripture references in this text node and add newReference tags around them
      my $text = $textNode->data();
      &addLinksText($work, \$text);
      
      if ($text ne $textNode->data()) {
        # save changes for later (to avoid messing up line numbers)
        $nodeInfo{$textNode->unique_key}{'node'} = $textNode;
        $nodeInfo{$textNode->unique_key}{'text'} = $text;
      }
    }
  }

  # replace the old text nodes with the new
  foreach my $n (sort keys %nodeInfo) {
    $nodeInfo{$n}{'node'}->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($nodeInfo{$n}{'text'}), $nodeInfo{$n}{'node'});
    $nodeInfo{$n}{'node'}->unbindNode();
  }

  # remove (after copying attributes) pre-existing reference tags which contain newReference tags
  my @refs = $XPC->findnodes('descendant::osis:reference[descendant::newReference]', $element);
  foreach my $ref (@refs) {
    my @attribs = $ref->attributes();
    my @chdrn = $XPC->findnodes('child::node()', $ref);
    foreach my $child (@chdrn) {
      $ref->parentNode()->insertBefore($child, $ref);
      if ($child->nodeName ne 'newReference') {next;}
      foreach $a (@attribs) {
        if ($a !~ /^\s*(.*?)="(.*)"$/) {&ErrorBug("Bad attribute because $a !~ /^\s*(.*?)=\"(.*)\"\$/");}
        my $n = $1; my $v = $2;
        if ($child->hasAttribute($n) && $v ne $child->getAttribute($n)) {
          &ErrorBug("Reference $n=\"".$v."\" is overwriting newReference $n=\"".$child->getAttribute($n)."\"");
        }
        $child->setAttribute($n, $v);
      }
    }
    $ref->unbindNode();
  }

  # convert all newReference elements to reference elements
  my @nrefs = $XPC->findnodes('descendant::*[local-name()="newReference"]', $element);
  foreach my $nref (@nrefs) {
    $nref->setNodeName("reference");
    $nref->setNamespace('http://www.bibletechnologies.net/2003/OSIS/namespace');
    $newLinks++;
  }
  
  # change any work prefixes and write necessary work elements to header
  foreach my $new ($XPC->findnodes('descendant-or-self::*[@new]', $element)) {
    my $osisRef = $new->getAttribute('osisRef');
    foreach my $xpath (sort keys %xpathIfResultWorkPrefix) {
      if ($osisRef && @{$XPC->findnodes($xpath, $new)}[0]) {
        my $was = ($osisRef =~ s/^(\w+):// ? $1:'none');
        $new->setAttribute('osisRef', $xpathIfResultWorkPrefix{$xpath}.':'.$osisRef);
        &Note("<>Changing work prefix of references matching $xpath from '$was' to '$xpathIfResultWorkPrefix{$xpath}'.");
        $asrlworks{$xpathIfResultWorkPrefix{$xpath}}++;
        last;
      }
    }
    $new->removeAttribute('new');
  }

  &writeXMLFile($xml, $osis);
}

# Takes a reference element, interperets its contents as a Scripture 
# reference from the given context, and attempts to return a valid 
# osisRef value. The returned osisRef value is not checked for
# existence or validity, so this must be done later.
sub getLinksReference {
  my $work = shift;
  my $reference = shift;
  
  my $targ;
  my $tnode = $reference->firstChild;
  if (!$tnode || $tnode->nodeType != XML::LibXML::XML_TEXT_NODE) {
    &Error("First child of reference is not a text node.");
    return '';
  }
  
  my $t = $tnode->data;
  if ($t ne $reference->textContent) {
    &Warn("Reference element has multiple children: ".$reference->toString());
    $t = $reference->textContent;
  }
  # A bare number is interpereted according to the current context
  elsif ($t =~ /^(\d+)$/ && $BK && $CH && $VS) {
    return &newReference($work, "$BK.$CH.$1", $t);
  }
  elsif ($t =~ /^(\d+)$/ && $BK) {
    return &newReference($work, "$BK.$1", $t);
  }
  
  # Check if there is an explicit target as a USFM 3 attribute
  if ($t =~ s/\|.*$//) {
    $targ = &usfm3GetAttribute($tnode->data, 'link-href', 'link-href');
    $tnode->setData($t);
    
    # This might be an osisRef value already, or be Paratext reference
    if ($targ =~ /^($OSISBOOKSRE)\./) {
      return &newReference($work, $targ, $t);
    }
    my $pref = &paratextRefList2osisRef($targ);
    if ($pref) {return &newReference($work, $pref, $t);}
  }
  else {
    $targ = $t;
  }
  
  # Search the text 
  &addLinksText($work, \$targ, 1);
  
  if ($targ eq $t) {return '';}
  
  return $targ;
}

sub newReference {
  my $work = shift;
  my $osisRef = shift;
  my $text = shift;
  
  return '<newReference new="yes" osisRef="'.($work ? "$work:":'').$osisRef.'">'.$text.'</newReference>';
}

##########################################################################
##########################################################################
# 1) SEARCH FOR THE LEFTMOST OCCURRENCE OF ANY REFERENCE TYPE.
# 2) SEARCH FOR AN EXTENDED REFERENCE BEGINNING WITH THAT LEFTMOST REFERENCE.
# 3) SPLIT THE EXTENDED REFERENCE INTO SUBREFS.
# 4) PARSE EACH SUBREF SEPARATELY, EACH INHERITING MISSING VALUES FROM THE PREVIOUS SUBREF
# 5) REASSEMBLE THE EXTENDED REFERENCE USING OSIS LINKS
# 6) REPEAT FROM STEP 1 UNTIL NO MORE REFERENCES ARE FOUND
sub addLinksText {
  my $work = shift;
  my $tP = shift;
  my $isRefElement = shift;

#&Log("$LOCATION: addLinksText $$tP\n");

  my @notags = split(/(<[^>]*>)/, $$tP);
  for (my $ts = 0; $ts < @notags; $ts++) {
    if (@notags[$ts] =~ /^<[^>]*>$/) {next;}
    my $ttP = \@notags[$ts];

    my ($matchedTerm, $type, $unhandledBook);
    while (&leftmostTerm($ttP, \$matchedTerm, \$type, \$unhandledBook)) {

      if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG1: MatchedTerm=$matchedTerm Type=$type\n");}

      my $mtENC = quotemeta($matchedTerm);

      if ($$ttP !~ /(($prefixTerms)?$mtENC($suffixTerms)*($prefixTerms|$ebookNames|$chapTerms|$verseTerms|$suffixTerms|$refTerms|\d|\s)*)($refEndTerms)/) {
        # Skip if this error is marked to be skipped
        my $repExtref = &fixLink($matchedTerm, $work, "$BK.$CH.$VS", \%fix, \%fixDone);
        if ($repExtref) {
          if ($repExtref ne 'skip') {
            &Error("Links with errors can only be skipped.", "The FIX instruction in CF_addScripRefLink.txt must not have anything after the equal sign.");
          }
          &hideTerm($matchedTerm, $ttP, 1);
          next;
        }
        
        # Log this link (even though there is an error) so that the user can skip it if desired
        &logLink($LOCATION, 0, $matchedTerm, 'unknown', $type);
        
        &Error("$LOCATION: Left-most term \"$matchedTerm\" Type \"$type\" could not be found  in \"$$ttP\".", "
        The detected sub-reference could not be located in the text above.
        This usually happens because REF_END_TERMS could not be found in 
        the text after the sub-reference. Examine REF_END_TERMS and try 
        adding a term to match the end of the entire reference above.");
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
        &Warn("$LOCATION: Skipped \"$pextref\" - no DIGITS.");
        &hideTerm($matchedTerm, $ttP);
        next;
      }

      # Skip or fix
      my $isFixed = 0;
      my $repExtref = &fixLink($pextref, $work, "$BK.$CH.$VS", \%fix, \%fixDone);
      if ($repExtref eq 'skip') {&hideTerm($extref, $ttP); next;}
      elsif ($repExtref) {$isFixed++; goto ADDLINK;}
      
      my $shouldCheck = 0;

      # Now break ref up into its subrefs, and extract OSIS ref for each subref
      my $tbk = $BK;
      my $tch = $CH;
      my $bareNumbersAre = "chapters";
      if ($tbk =~ /($oneChapterBooks)/i) {$bareNumbersAre = "verses"; $tch = 1;}

      my @subrefArray = split(/($sepTerms)/, $extref);
      if (@subrefArray > 1) {&logLink($LOCATION, 0, $pextref);}
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
          $repExtref .= $subref;
          if ($subref =~ /^\s*$/) {next;}
          $numNoDigitRef++;
          $noDigitRef{"<$subref> (subref)"} .= $LOCATION.", ";
          &Warn("$LOCATION: Skipped subref \"$psubref\" - no DIGITS.");
          next;
        }

        # Now parse out this subref
        my $osisRef;
        if (!&getOSISRef(\$subref, \$osisRef, \$type, \$tbk, \$tch, \$bareNumbersAre)) {
          $numNoOSISRef++;
          $noOSISRef{$subref} .= $LOCATION.", ";
          $repExtref .= $subref;
          &Warn("$LOCATION: Skipping subref \"$psubref\", osisref is \"$osisRef\".\n");
          next;
        }

        if ($LOCATION eq $DEBUG_LOCATION) {&Log("DEBUG4: MatchedTerm=$matchedTerm\n");}

        $Types{$type}++;
        if ($type eq "T10 (num1 ... num2?)") {$shouldCheck = 1;}

        $repExtref .= &newReference($work, $osisRef, $subref);
        &logLink($LOCATION, @subrefArray > 1, $psubref, $osisRef, "$type $unhandledBook");
      }

      ADDLINK:
      if ($unhandledBook && !$isFixed) {
        $numUnhandledWords++;
        my $ubk = $unhandledBook;
        $ubk =~ s/^.*>$/<tag>/;
        $ubk =~ s/^.*\($/(/;
        $UnhandledWords{$ubk} .= $LOCATION.", ";
      }
      
      my $repExtrefENC = &encodeTerm($repExtref);
      if ($$ttP !~ s/\Q$extref/$repExtrefENC/) {&ErrorBug("$LOCATION: Could not find \"$pextref\" in \"$$ttP\".");}

      if ($shouldCheck) {
        my $prf = $repExtref;
        $prf =~ s/osisRef="([^":]+:)?([^"]+)"/$2/g;
        $prf =~ s/newReference/r/g;
        $prf =~ s/new="yes" //g;
        $CheckRefs .= "\nCheck location $LOCATION:\"$pextref\"=$prf";
      }
    }

    &decodeTerms($ttP);

    # Now insure consecutive newReference tags don't have anything between them
    while ($$ttP =~ /(<newReference [^>]*osisRef=[^>]+>)(.*?)(<\/newReference>)(($sepTerms|\s)+)(<newReference [^>]*osisRef=[^>]+>)/) {
      $$ttP =~ s/(<newReference [^>]*osisRef=[^>]+>)(.*?)(<\/newReference>)(($sepTerms|\s)+)(<newReference [^>]*osisRef=[^>]+>)/$1$2$4$3$6/;
    }
  }

  $$tP = join("", @notags);
}

sub logLink {
  my $location = shift;
  my $isSubReference = shift;
  my $printReference = shift;
  my $osisRef = shift;
  my $type = shift;
  
  $printReference =~ s/"/\\"/g; # required to support FIX commands
  &Log("$location ".($isSubReference ? "sub-reference":"Linking").": \"$printReference\" = ");
  if ($osisRef) {&Log("$osisRef ($type)");}
  &Log("\n");
}

sub fixLink {
  my $reference = shift;
  my $work = shift;
  my $location = shift;
  my $fixP = shift;
  my $fixDoneP = shift;
  
  if (!defined($fixP->{$location}{$reference})) {
    return '';
  }
  
  if ($fixP->{$location}{$reference} eq 'skip') {
    &Note("$location: Skipped \"$reference\" - on FIX list.");
    $fixDoneP->{$location}{$reference}++;
    return 'skip';
  }
  
  my $fixed = $fixP->{$location}{$reference};
  if ($fixed !~ s/<r\s*([^>]+)>(.*?)<\/r>/&newReference($work, $1, $2);/eg) {
    &ErrorBug("Bad FIX replacement $location $reference: \"$fixed\"");
    return '';
  }
  
  &Note("$location: Fixed \"$reference\" - on FIX list.");
  $fixDoneP->{$location}{$reference}++;
  return $fixed;
}

sub reportFixes {
  my $fixP = shift;
  my $fixDoneP = shift;
  my $type = shift;
  
  my $t = 0;
  my $f = 0;
  foreach my $loc (sort keys %{$fixP}) {
    foreach my $ref (sort keys %{$fixP->{$loc}}) {
      if ($type eq 'skip' && $fixP->{$loc}{$ref} ne 'skip') {next;}
      if ($type ne 'skip' && $fixP->{$loc}{$ref} eq 'skip') {next;}
      if (!defined($fixDoneP->{$loc}{$ref})) {
        &Error("Fix \"$loc\" \"$ref\" was not applied.", "
   This FIX was not found in the text. The FIX line should be an exact 
   copy of a line in LOG_sfm2osis.txt beginning with \"Linking\".$fixReplacementMsg");
        $f++;
      }
      else {$t += $fixDoneP->{$loc}{$ref};}
    }
  }
  if ($f == 0) {
    my $tp = ($type eq 'skip' ? 'exclusions':'fixes');
    &Note("All $tp where applied ($t times)");
  }
}

sub hideTerm {
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

  if ($$tP !~ s/$re1/$re2/) {&ErrorBug("$LOCATION: Could not hide term \"$mt\" because $$tP !~ s/$re1/$re2/");}
}

sub encodeTerm {
  my $t = shift;

  if ($t =~ /(\{\{\{|\}\}\})/ || $t =~ /(._){2,}/) {
    &ErrorBug("$LOCATION: String was already partially encoded \"$t\".");
  }
  $t =~ s/(.)/$1_/gs;
  return "{{{".$t."}}}";
}

sub decodeTerms {
  my $tP = shift;

  while ($$tP =~ /(\{\{\{(.*?)\}\}\})/s) {
    my $re1 = $1;
    my $et = $2;

    my $re2 = "";
    for (my $i=0; $i<length($et); $i++) {
      my $chr = substr($et, $i, 1);
      if (!($i%2)) {$re2 .= $chr;}
      elsif ($chr ne "_") {&ErrorBug("$LOCATION: Incorectly encoded reference text \"$re1\" because \"$chr\" ne \"_\"");}
    }

    $$tP =~ s/\Q$re1/$re2/;
  }
}

# Finds the left-most reference match.
# Modifies:
#       $matchP - holds the matched text
#       $typeP - holds the type of match
#       $uhbkP - holds the word preceding the matched text IF no book or book-term was matched.
#                The uhbkP value is null only if a book or book-term WAS matched
# Returns:
#       1 if a match was found
#       0 otherwise
sub leftmostTerm {
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
sub getOSISRef {
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
  $$osisP = $$bkP.".".$$chP;

  # Some Ps have a verse 0 canonical title, but SWORD does not support verse "0".
  # so move these references so they point to verse 1 and are not just dropped.
  if ($$bkP eq "Ps" && $vs == 0) {$vs++;}

  # A value of -1 means don't include verse in OSIS ref
  if ($vs != -1) {$$osisP .= ".".$vs;}
  if ($lv != -1 && $lv > $vs) {$$osisP .= "-".$$bkP.".".$$chP.".".$lv;}

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
sub matchRef {
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
  if ($contextBK =~ /^($oneChapterBooks)$/i) {$contextCH = 1;}
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
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?(\d+)\s*($verseTerms)?\s*($continuationTerms)\s*(\d+)\s*($verseTerms))/si)) {
    my $pre = $1;
    my $ref = $2;
    my $tbook = $4;
    my $tvs = $6;
    my $tlv = $9;

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

  # Book? ChapTerm c VerseTerm v
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?($chapTerms)($suffixTerms)*\s*(\d+)\s*($verseTerms)($suffixTerms)*\s*(\d+))/si)) {
    my $pre = $1;
    my $ref = $2;
    my $tbook = $4;

    my $index = length($pre);
    if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
      $matchedTerm = $ref;
      $$typeP = "T11 (Book? ChapTerm c VerseTerm v)";
      $lowestIndex = $index;
      $shortestMatch = length($ref);
      if (!$matchleft) {
        $$bkP = $tbook;
        $ref =~ /($chapTerms)($suffixTerms)*\s*(\d+)\s*($verseTerms)($suffixTerms)*\s*(\d+)/si;
        $$chP = $3;
        $$vsP = $6;
        $$lvP = -1;
        $$barenumsP = "verses";
      }
      else {$$uhbkP = &unhandledBook($pre, \$tbook);}
    }
  }
  
  # Book? ChapTerm c 
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms)($suffixTerms)*\s*)?($chapTerms)\s*(\d+))/si)) {
    my $pre = $1;
    my $ref = $2;
    my $tbook = $4;
    my $tch = $7;

    my $index = length($pre);
    if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
      $matchedTerm = $ref;
      $shortestMatch = length($ref);
      $$typeP = "T12 (Book? ChapTerm c)";
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
  
  # Book|CurrentChap? VerseTerms v 
  if (($matchleft || !$$typeP) && ($$tP =~ /^($PREM)((($ebookNames|$currentBookTerms|$currentChapTerms)($suffixTerms)*\s*)?($verseTerms)\s*(\d+))/si)) {
    my $pre = $1;
    my $ref = $2;
    my $tbook = $4;
    my $tvs = $7;

    my $index = length($pre);
    if (!$matchleft || $index < $lowestIndex || ($index == $lowestIndex && length($ref) < $shortestMatch)) {
      $matchedTerm = $ref;
      $shortestMatch = length($ref);
      $$typeP = "T13 (Book|CurrentChap? VerseTerms v)";
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

    # OSIS book abbreviation of the reference
    # Due to Perl (5.22) Unicode weirdness, it has been observed that  
    # using the i flag can fail a match that passes without i. So both 
    # are used separately here.
    if ($$bkP eq $contextBK) {}
    elsif ($$bkP =~ /($ebookNames)/si)                            {$$bkP = $books{$1};}
    elsif ($$bkP =~ /($ebookNames)/s)                             {$$bkP = $books{$1};}
    elsif ($$bkP =~ /($currentBookTerms|$currentChapTerms)/si)    {$$bkP = $contextBK;}
    elsif ($$bkP =~ /($currentBookTerms|$currentChapTerms)/s)     {$$bkP = $contextBK;}
    else {
      &ErrorBug("Could not determine OSIS abbreviation of book:\n$$bkP !~ /($ebookNames)/si\n$$bkP !~ /($currentBookTerms|$currentChapTerms)/si");
      $$bkP = $contextBK;
    }
  }

  $$tP =~ s/^ //; # undo our added space

  if ($LOCATION eq $DEBUG_LOCATION) {&Log(sprintf("DEBUG_matchRef:\nmatchleft=%s\nt=%s\ntype=%s\nuhbk=%s\nbk=%s\nch=%s\nvs=%s\nlv=%s\nbarenums=%s\n\n", $matchleft, $$tP, $$typeP, $$uhbkP, $$bkP, $$chP, $$vsP, $$lvP, $$barenumsP));}
  return $matchedTerm;
}

sub unhandledBook {
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

sub validOSISref {
  my $osisRef = shift;
  my $linkText = shift;
  my $strict = shift;
  my $noWarn = shift;

  my ($bk1, $bk2, $ch1, $ch2, $vs1, $vs2);
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
    if (!$noWarn) {&Warn("$LOCATION: Short osisRef \"$osisRef\" found in \"$linkText\"");}
  }
  else {return 0;}

  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem(&conf('Versification'));
  my $bok1 = $vk->getBookNumberByOSISName($bk1) != -1;
  my $bok2 = ($bk2 == "" || $vk->getBookNumberByOSISName($bk2) != -1);

  return ($bok1 && $bok2);
}

1;
