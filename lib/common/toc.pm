# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

our ($MOD, $ONS, $ROC, $XML_PARSER, $XPC, %BOOKNAMES, %ID_TYPE_MAP_R,
    %PERIPH_TYPE_MAP_R, @SUB_PUBLICATIONS, %ANNOTATE_TYPE);

# Check for TOC entries, and write as much TOC information as possible
my $WRITETOC_MSG;
sub writeTOC {
  my $osisP = shift;
  my $modType = shift;

  &Log("\nChecking Table Of Content tags...\n");
  
  my $toc = &conf('TOC');
  &Note("Using \"\\toc$toc\" as TOC tag.");
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @tocTags = $XPC->findnodes('//osis:milestone[@n][starts-with(@type, "x-usfm-toc")]', $xml);
  
  if (@tocTags) {
    &Note("Found ".scalar(@tocTags)." table of content milestone tags:");
    foreach my $t (@tocTags) {
      &Log($t->toString()."\n");
    }
  }
  
  if ($modType eq 'bible') {
    # Insure there are as many possible x-usfm-tocN entries for each book,
    # and add book introduction TOC entries where needed.
    my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
    my %bookIntros;
    foreach my $bk (@bks) {
      my $osisID = $bk->getAttribute('osisID');
      my @names;
      for (my $t=1; $t<=3; $t++) {
        # Is there a TOC entry if this type? If not, add one if we know what it should be
        my $e = @{$XPC->findnodes(
          'descendant::osis:milestone[@n][@type="x-usfm-toc'.$t.'"] | 
           descendant::*[1][self::osis:div]
           /osis:milestone[@n][@type="x-usfm-toc'.$t.'"]', $bk)}[0];
        if ($e) {push(@names, $e->getAttribute('n')); next;}
        
        if ($t eq $toc && !$WRITETOC_MSG) {
          &Warn("At least one book ($osisID) is missing a \\toc$toc SFM tag. 
These \\toc tags are used to generate the eBook table of contents. When 
possible, such tags will be automatically inserted.",
"That your eBook TOCs render with proper book names and/or 
hierarchy. If not then you can add \\toc$toc tags to the SFM using 
EVAL_REGEX. Or, if you wish to use a different \\toc tag, you must add 
a TOC=N config setting to: $MOD/config.conf (where N is the \\toc 
tag number you wish to use.)\n");
          $WRITETOC_MSG++;
        }
        
        my $name;
        my $type;
        
        # Try and get the book name from BookNames.xml
        if (%BOOKNAMES) {
          my @attrib = ('', 'long', 'short', 'abbr');
          $name = $BOOKNAMES{$osisID}{@attrib[$t]};
          if ($name) {$type = @attrib[$t];}
        }
        
        # Otherwise try and get the default TOC from the first applicable title
        if (!$name && $t eq $toc) {
          my $title = @{$XPC->findnodes(
            'descendant::osis:title[@type="runningHead"]', $bk)}[0];
          if (!$title) {
            $title = @{$XPC->findnodes(
              'descendant::osis:title[@type="main"]', $bk)}[0];
          }
          if (!$title) {
            $name = $osisID;
            $type = "osisID";
            &Error("writeTOC: Could not locate book name for \"$name\" in OSIS file.");
          }
          else {$name = $title->textContent; $type = 'title';}
        }
        
        if ($name) {
          my $tag = "<milestone $ONS type='x-usfm-toc$t' n='".&escAttribute($name)."' resp='$ROC'/>";
          &Note("Inserting $osisID book $type TOC entry as: $name");
          $bk->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $bk->firstChild);
          push(@names, $name);
        }
      }
    
      # Add book introduction TOC if there is a book introduction but
      # no TOC milestone for it.
      my @bookTOCs = $XPC->findnodes(
        'descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]
        [following::osis:chapter[@osisID="'.$osisID.'.1"]]', $bk); 
      if (@bookTOCs == 1 && 
            @{$XPC->findnodes('descendant::text()[normalize-space()]
            [not(ancestor::osis:title)][not(ancestor::osis:figure)][1]
            [following::osis:chapter[@osisID="'.$osisID.'.1"]]', $bk)}[0]) {
        my $title = &conf('IntroductionTitle', undef, undef, undef, 1); 
        if ($title eq '<bookname>') {
          $title = @bookTOCs[0]->getAttribute('n');
          $title =~ s/^(\[[^\]]*\])+//;
        }
        elsif ($title =~ /DEF$/) {
          # Since IntroductionTitle was not specified, find the first 
          # introduction title, and if it is just the book name again, 
          # then find the following introduction title and use that.
          foreach (@names) {s/^(\[[^\]]*\]+)//;}
          my $nre = join('|', map(quotemeta($_), @names));
          my @introTitles = $XPC->findnodes('descendant::osis:title
              [@subType="x-introduction"][not(@type="runningHead")]
              [following::osis:chapter[@osisID="'.$osisID.'.1"]]', $bk);
          my $use = @introTitles[0];
          if ($use && $use->textContent =~ /^\s*($nre)\s*$/i && @introTitles[1]) {
            $use = @introTitles[1];
          }
          if ($use) {$title = $use->textContent;}
          else {&conf('IntroductionTitle');} # throws an error
        }
        &Note("Inserting $osisID book introduction TOC entry as: $title");
        $bookIntros{$title}++;
        # Add a special osisID since these book intros may all share the same title
        my $toc = $XML_PARSER->parse_balanced_chunk("
<milestone $ONS type='x-usfm-toc".&conf('TOC')."' n='[not_parent]".&escAttribute($title)."' osisID='introduction_$osisID!toc' resp='$ROC'/>");
        # Place the TOC directly after the book TOC, unless the intro starts
        # with a scoped div. Scoped divs may be moved by filterBibleToScope()
        # and so the TOC must be placed within such divs, to move with it.
        my $scopedBookIntroDiv = @{$XPC->findnodes('child::osis:div[@type][1][@scope]
          [following::osis:chapter[@osisID="'.$osisID.'.1"]]', $bk)}[0];
        if ($scopedBookIntroDiv) {
          $scopedBookIntroDiv->insertBefore($toc, $scopedBookIntroDiv->firstChild);
        }
        else {
          @bookTOCs[0]->parentNode->insertAfter($toc, @bookTOCs[0]);
        }
      }
    }
    
    if (keys %bookIntros > 1) {
      &Warn(
"Not all book introduction TOC entries share the same title. Variations are:
" . join("\n", keys %bookIntros), 
"Use IntroductionTitle in config.conf to choose a common TOC 
title for all book introductions or use 'IntroductionTitle=<bookname>'  
to use the book name as the introduction title.");
    }
    
    # Add placeholder introduction divs for any sub-publication that 
    # lacks an introduction. No TOC entry is added, but such divs are 
    # intended as targets for sub-publication covers, appearing before 
    # any book introduction TOC milestone.
    &Log("\nChecking sub-publication osisRefs in \"$$osisP\"\n", 1);
    foreach my $scope (@SUB_PUBLICATIONS) {
      if (@{$XPC->findnodes('//osis:div[@type][@scope="'.$scope.'"]', $xml)}[0]) {
        next;
      }
      &Warn("No div scope was found for sub-publication $scope.");
      my @bks = @{&scopeToBooks($scope, &conf('Versification'))};
      my $multiple = (@bks > 1 ? &oc_stringHash(@bks[0].'book'):'');
      foreach my $bk (@bks) {
        my $bke = @{$XPC->findnodes("//osis:div[\@type='book']
                                               [\@osisID='$bk']", $xml)}[0];
        if (!$bke) {
          &Error("Sub-publication book is missing: $bk");
          next;
        }
        my $tocms = @{$XPC->findnodes('child::osis:milestone
            [@type="x-usfm-toc'.&conf('TOC').'"][1]', $bke)}[0];
        my $before = ($tocms ? $tocms->nextSibling:$bke->firstChild);
        my $div = $XML_PARSER->parse_balanced_chunk(
          "<div $ONS " .
          "type='introduction' " .
          "scope='$scope' " .
          "annotateType='$ANNOTATE_TYPE{'cover'}' " .
          "annotateRef='yes' " .
          ($multiple ? "n='[copy:$multiple]' ":'') . 
          "resp='$ROC'> </div>"
        );
        $before->parentNode->insertBefore($div, $before);
        &Note(
"Added empty introduction div with scope=\"$scope\" within book " .
$bke->getAttribute('osisID') . ' ' . 
( $tocms ? 'after TOC milestone.':'as first child.' ));
      }
    }
    
    # Add translation main TOC entry if not there already
    my $mainTOC = @{$XPC->findnodes('//osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]
      [not(ancestor::osis:div[starts-with(@type, "book")])]
      [not(preceding::osis:div[starts-with(@type, "book")])][1]', $xml)}[0];
    if (!$mainTOC) {
      my $translationTitle = &conf('TranslationTitle');
      my $toc = $XML_PARSER->parse_balanced_chunk("
<div $ONS type='introduction' resp='$ROC'>
  <milestone $ONS type='x-usfm-toc".&conf('TOC')."' n='[level1][not_parent]".&escAttribute($translationTitle)."'/>
</div>");
      my $insertBefore = @{$XPC->findnodes('//osis:header/following-sibling::*[not(self::osis:div[@type="x-cover"])][1]', $xml)}[0];
      if ($insertBefore) {
        $insertBefore->parentNode->insertBefore($toc, $insertBefore);
        &Note("Inserting top TOC entry and title within new introduction div as: $translationTitle");
      }
      else {&Error("No elements follow header");}
    }
    
    # Check if there is a whole book introduction without a TOC entry
    my $wholeBookIntro = @{$XPC->findnodes('//osis:div[@type="introduction" or @type="front"]
        [not(ancestor::osis:div[starts-with(@type,"book")])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml)}[0];
    if ($wholeBookIntro) {
      my $confentry = 'ARG_'.$wholeBookIntro->getAttribute('osisID'); $confentry =~ s/\!.*$//;
      my $confTitle = ($wholeBookIntro->getAttribute('osisID') ? &conf($confentry):'');
      my $intrTitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $wholeBookIntro)}[0];
      my $title = ($confTitle ? $confTitle:($intrTitle ? $intrTitle->textContent():''));
      if ($title) {
        my $toc = $XML_PARSER->parse_balanced_chunk("
<milestone $ONS resp='$ROC' type='x-usfm-toc".&conf('TOC')."' n='[level1][not_parent]".&escAttribute($title)."'/>");
        $wholeBookIntro->insertBefore($toc, $wholeBookIntro->firstChild);
        &Note("Inserting introduction TOC entry as: $title");
      }
      else {
        &Warn("There is a whole-book introduction which is not included in the TOC.",
        "If you want to include it, add to config.conf the entry: $confentry=<title>");
      }
    }
        
    # Check each bookGroup's bookGroup introduction and bookSubGroup introduction 
    # divs (if any), and add TOC entries and/or [not_parent] markers as appropriate. 
    # NOTE: Each bookGroup may have one or both of these: bookGroup introduction
    # and/or bookSubGroup introduction(s) (see below how these are distinguished).
    my @bookGroups = $XPC->findnodes('//osis:div[@type="bookGroup"]', $xml);
    foreach my $bookGroup (@bookGroups) {
      # The bookGroup introduction is defined as first child div of the bookGroup when it 
      # is either the only non-book TOC div or else is immediately followed by another non-book
      # TOC div.

      # Is there already a bookGroup introduction TOC (in other words not autogenerated)?
      my $singleNonBookChild = (@{$XPC->findnodes('child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")]', $bookGroup)} == 1 ? 'true()':'false()');
      my $bookGroupIntroTOCM = @{$XPC->findnodes('child::*[1][self::osis:div[not(@type="book")]][not(@resp="'.$ROC.'")]
      [boolean(following-sibling::*[1][self::osis:div[not(@type="book")][not(@resp="'.$ROC.'")]]) or '.$singleNonBookChild.']
      /child::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $bookGroup)}[0];
      
      # bookGroup child TOC entries will be made [not_parent] IF there already 
      # exists a bookGroup introduction TOC entry (otherwise chapters would end 
      # up as useless level4 which do not appear in eBook readers).
      if ($bookGroupIntroTOCM) {
        foreach my $m ($XPC->findnodes('child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")][count(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]) = 1]/
            osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $bookGroup)) {
          if ($m->getAttribute('n') !~ /\Q[not_parent]\E/ && $m->parentNode->unique_key ne $bookGroupIntroTOCM->parentNode->unique_key) {
            $m->setAttribute('n', '[not_parent]'.$m->getAttribute('n'));
            &Note("Modifying sub-section TOC to: '".$m->getAttribute('n')."' because a Testament introduction TOC already exists: '".$bookGroupIntroTOCM->getAttribute('n')."'.");
          }
        }
      }
        
      # bookSubGroupAuto TOCs are are defined as non-book bookGroup child divs 
      # having a scope, which are either preceded by a book or are the 1st 
      # or 2nd children of their bookGroup, excluding any bookGroup introduction. 
      # Each bookSubGroupAuto will appear in the TOC.
      my @bookSubGroupAuto = $XPC->findnodes(
          'child::osis:div[not(@type="book")][not(@resp="'.$ROC.'")][@scope][preceding-sibling::*[not(@resp="'.$ROC.'")][1][self::osis:div[@type="book"]]] |
           child::*[not(@resp="'.$ROC.'")][position()=1 or position()=2][self::osis:div[not(@type="book")][@scope]]'
      , $bookGroup);
      for (my $x=0; $x<@bookSubGroupAuto; $x++) {
        if (@bookSubGroupAuto[$x] && $bookGroupIntroTOCM && @bookSubGroupAuto[$x]->unique_key eq $bookGroupIntroTOCM->parentNode->unique_key) {
          splice(@bookSubGroupAuto, $x--, 1);
        }
      }
     
      foreach my $div (@bookSubGroupAuto) {
        # Add bookSubGroup TOC milestones when there isn't one yet
        if (@{$XPC->findnodes('child::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]', $div)}[0]) {next;}
        my $tocentry = ($div->hasAttribute('scope') ? &getScopeTitle($div->getAttribute('scope')):'');
        if (!$tocentry) {
          my $nexttitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $div)}[0];
          if ($nexttitle) {$tocentry = $nexttitle->textContent();}
        }
        if (!$tocentry) {
          my $nextbkn = @{$XPC->findnodes('following::osis:div[@type="book"][1]/descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]/@n', $div)}[0];
          if ($nextbkn) {$tocentry = $nextbkn->value(); $tocentry =~ s/^\[[^\]]*\]//;}
        }
        if ($tocentry) {
          # New bookSubGroup TOCs will be [not_parent] if there is already a bookGroup introduction
          my $notParent = ($bookGroupIntroTOCM ? '[not_parent]':'');
          my $tag = "<milestone $ONS type='x-usfm-toc".&conf('TOC')."' n='$notParent".&escAttribute($tocentry)."' resp='$ROC'/>";
          &Note("Inserting Testament sub-section TOC entry into \"".$div->getAttribute('type')."\" div as $tocentry");
          $div->insertBefore($XML_PARSER->parse_balanced_chunk($tag), $div->firstChild);
        }
        else {&Note("Could not insert Testament sub-section TOC entry into \"".$div->getAttribute('type')."\" div because a title could not be determined.");}
      }

      # Add bookGroup introduction TOC entries using BookGroupTitles, if:
      # + there is more than one bookGroup
      # + the bookGroup has more than one book
      # + there are no bookSubGroups in the bookGroup
      # + there is no bookGroup introduction already
      # + the BookGroupTitle is not 'no'
      if (@bookGroups > 1 && 
            @{$XPC->findnodes('child::osis:div[@type="book"]', $bookGroup)} > 1 && 
            !@bookSubGroupAuto && !$bookGroupIntroTOCM) {
        my $firstBook = @{$XPC->findnodes(
            'descendant::osis:div[@type="book"][1]/@osisID', $bookGroup)}[0]->value;
        my $whichBookGroup = &defaultOsisIndex($firstBook, 3);
        my $bookGroupTitle = &conf("BookGroupTitle$whichBookGroup");
        if ($bookGroupTitle eq 'no') {next;}
        my $toc = $XML_PARSER->parse_balanced_chunk("
<div $ONS type='introduction' resp='$ROC'>
  <milestone $ONS type='x-usfm-toc".&conf('TOC')."' n='[level1]".&escAttribute($bookGroupTitle)."'/>
</div>");
        $bookGroup->insertBefore($toc, $bookGroup->firstChild);
        &Note("Inserting $whichBookGroup bookGroup TOC entry within new introduction div as: $bookGroupTitle");
      }
    }
  }
  elsif ($modType eq 'dict') {
    my $maxkw = &conf("ARG_AutoMaxTOC1"); $maxkw = ($maxkw ne '' ? $maxkw:7);
    # Any Paratext div which does not have a TOC entry already and does 
    # not have sub-entries that are specified as level1-TOC, should get 
    # a level1-TOC entry, so that its main contents will be available 
    # there. Such a TOC entry is not added, however, if the div is a 
    # glossary (that is, a div containing keywords) that has less than 
    # ARG_AutoMaxTOC1 keywords, in which case the sub-entries themselves 
    # may be left without a preceding level1-TOC entry so that they will 
    # appear as level1-TOC themselves.
    my $typeRE = '^('.join('|', sort keys(%PERIPH_TYPE_MAP_R), sort keys(%ID_TYPE_MAP_R)).')$';
    $typeRE =~ s/\-/\\-/g;
  
    my @needTOC = $XPC->findnodes('//osis:div[not(@subType = "x-aggregate")]
        [not(@resp="x-oc")]
        [not(descendant::*[contains(@n, "[level1]")])]
        [not(descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"])]', $xml);
        
    my %n;
    foreach my $div (@needTOC) {
      if (!$div->hasAttribute('type') || $div->getAttribute('type') !~ /$typeRE/) {next;}
      my $type = $div->getAttribute('type');
      if ($maxkw && @{$XPC->findnodes('descendant::osis:seg[@type="keyword"]', $div)} <= $maxkw) {next;}
      if ($div->getAttribute('scope')) {
        if (!@{&scopeToBooks($div->getAttribute('scope'), &conf('Versification'))}) {next;} # If scope is not an OSIS scope, then skip it
      }
      
      my $tocTitle;
      my $confentry = 'ARG_'.$div->getAttribute('osisID'); $confentry =~ s/\!.*$//;
      my $confTitle = &conf($confentry);
      my $combinedGlossaryTitle = &conf('CombinedGlossaryTitle');
      my $titleSubPublication = ( $div->getAttribute('scope') ? 
        &conf("TitleSubPublication[".$div->getAttribute('scope')."]") : '' );
      # Look in OSIS file for a title element
      $tocTitle = @{$XPC->findnodes('descendant::osis:title[@type="main"][1]', $div)}[0];
      if ($tocTitle) {
        $tocTitle = $tocTitle->textContent;
      }
      # Or look in config.conf for explicit toc entry
      if (!$tocTitle && $confTitle) {
        if ($confTitle eq 'SKIP') {next;}
        $tocTitle = $confTitle;
      }
      # Or create a toc entry (without title) from SUB_PUBLICATIONS & CombinedGlossaryTitle 
      if (!$tocTitle && $combinedGlossaryTitle && $titleSubPublication) {
        $tocTitle = "$combinedGlossaryTitle ($titleSubPublication)";
      }
      if (!$tocTitle) {
        $tocTitle = $div->getAttribute('osisID');
        &Error("The Paratext div with title '$tocTitle' needs a localized title.",
"A level1 TOC entry for this div has been automatically created, but it 
needs a title. You must provide the localized title for this TOC entry 
by adding the following to config.conf: 
$confentry=The Localized Title. 
If you really do not want this glossary to appear in the TOC, then set
the localized title to 'SKIP'.");
      }
      
      my $toc = $XML_PARSER->parse_balanced_chunk(
        "<milestone $ONS type='x-usfm-toc".&conf('TOC')."' n='[level1]".&escAttribute($tocTitle)."' resp='".$ROC."'/>"
      );
      $div->insertBefore($toc, $div->firstChild);
      &Note("Inserting glossary TOC entry within introduction div as: $tocTitle");
    }
    
    # If a glossary with a TOC entry has only one keyword, don't let that
    # single keyword become a secondary TOC entry.
    foreach my $gloss ($XPC->findnodes('//osis:div[@type="glossary"]
        [descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"]]
        [count(descendant::osis:seg[@type="keyword"]) = 1]', $xml)) {
      my $ms = @{$XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $gloss)}[0];
      if ($ms->getAttribute('n') =~ /^(\[[^\]]*\])*\[no_toc\]/) {next;}
      my $kw = @{$XPC->findnodes('descendant::osis:seg[@type="keyword"][1]', $gloss)}[0];
      if ($kw->getAttribute('n') =~ /^(\[[^\]]*\])*\[no_toc\]/) {next;}
      $kw->setAttribute('n', '[no_toc]');
    }
    
  }
  elsif ($modType eq 'childrens_bible') {return;}
  
  
  &writeXMLFile($xml, $osisP);
}

sub getScopeTitle {
  my $scope = shift;
  
  $scope =~ s/\s/_/g;
  return &conf("TitleSubPublication[$scope]");
}

1;
