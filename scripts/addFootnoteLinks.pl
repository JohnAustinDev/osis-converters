# This file is part of "osis-converters".
#
# Copyright 2017 John Austin (gpl.programs.info@gmail.com)
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


# POSSIBLE COMMAND FILE SETTINGS:
#
#  (NOTE: settings which are not needed can
#   be left blank or not included at all)
#
#   FOOTNOTE_TERMS - A Perl regular expression matching terms which
#       indicate, and will be converted into, footnote links
#   ORDINAL_TERMS - A | separated list of ordinal:term pairs where the
#       ordinal is either a number, 'prev', 'next', or 'last', and the  
#       term is a translation of that ordinal to be parsed from the text.
#   COMMON_TERMS - A Perl regular expression matching any fluff which may 
#       appear between the Scripture reference and the footnote term
#       (excluding ORDINAL_TERMS and SUFFIXES which are automatically 
#       accounted for)
#   CURRENT_VERSE_TERMS - A Perl regular expression matching "this verse"
#   SUFFIXES - A Perl regular expression matching suffixes which may
#       appear alone or in combination at the end of translated terms. 
#       Some Turkic languages have many such suffixes for example.
#   SKIP_XPATH - An XPATH expression used to skip particular elements
#       of text when searching for Scripture references. By default,
#       nothing is skipped.
#   ONLY_XPATH - An XPATH expression used to select only particular
#       elements of text to search for Scripture references. By default,
#       everything is searched.
#   SKIP_INTRODUCTIONS - Boolean. If true, introductions are skipped.
#   FIX - Used to fix a problematic reference. Each instance has the 
#       form: LOCATION='book.ch.vs' AT='ref-text' and REPLACEMENT=
#       'exact-replacement'. If REPLACEMENT is SKIP, there will be no 
#        reference link at all.
#   STOP_REFERENCE - A Perl regular expression matching text of 
#        back-to-back Scripture references, left of which, refs will no  
#        longer refer to footnotes. For instance: 'See verses 16:7-14 
#        and 16:14 footnotes' requires 'verses[\s\d:-]+and' to 
#        disassociate the left ref from footnote association.

require("$SCRD/scripts/processGlossary.pl");

%OSISID_FOOTNOTE;
%VERSE_FOOTNOTE_IDS;
%FNL_MODULE_BIBLE_VERSE_SYSTEMS;
%FNL_FIX;
%TERM_ORDINAL;
%FNL_STATS;
%FNL_LINKS;
$OSISREFWORK;

sub addFootnoteLinks($$) {
  my $in_file = shift;
  my $out_file = shift;

  &Log("\n--- ADDING FOOTNOTE LINKS\n-----------------------------------------------------\n\n", 1);

  # Globals
  $skip_xpath = '';
  $only_xpath = '';
  $skipintros = 0;
  $footnoteTerms = '';
  $commonTerms = '';
  $currentVerseTerms = '';
  $suffixTerms = '';
  $stopreference = '';
  my $commandFile = "$INPD/CF_addFootnoteLinks.txt";
  if (-e $commandFile) {
    &Log("READING COMMAND FILE \"$commandFile\"\n");
    open(CF, "<:encoding(UTF-8)", $commandFile);
    while (<CF>) {
      $_ =~ s/\s+$//;

      if ($_ =~ /^(\#.*|\s*)$/) {next;}
      elsif ($_ =~ /^ORDINAL_TERMS:(\s*\((.*?)\)\s*)?$/) {
        if ($1) {
          my $ots = $2;
          my @ots = split(/\|/, $ots);
          foreach my $ot (@ots) {
            if ($ot !~ /^(\d+|last|next|prev):(.*)$/) {&Log("ERROR: Malformed entry in ORDINAL_TERMS: \"$ot\"\n"); next;}
            $TERM_ORDINAL{$2} = $1;
          }
        } 
        next;
      }
      elsif ($_ =~ /^FIX:(.*+)$/) {
        my $fix = $1;
        if ($fix !~ s/\bLOCATION='(.*?)(?<!\\)'//) {&Log("ERROR: Could not find LOCATION='book.ch.vs' in FIX statement: $_\n"); next;}
        my $location = $1;
        if ($fix !~ s/\bAT='(.*?)(?<!\\)'//) {&Log("ERROR: Could not find AT='reference text' in FIX statement: $_\n"); next;}
        my $at = $1; $at =~ s/\\'/'/g;
        if ($fix !~ s/\b(REPLACEMENT)='(.*?)(?<!\\)'//) {&Log("ERROR: Could not find REPLACEMENT='exact-replacement' in FIX statement: $_\n"); next;}
        my $type = $1; my $value = $2;
        $FNL_FIX{$location}{$at} = "$type:$value";
        next;
      }
      elsif ($_ =~ /^SKIP_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$skip_xpath = $2;} next;}
      elsif ($_ =~ /^ONLY_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$only_xpath = $2;} next;}
      elsif ($_ =~ /^SKIP_INTRODUCTIONS:\s*(.*?)\s*$/) {$skipintros = $1; $skipintros = ($skipintros && $skipintros !~ /^false$/i ? 1:0); next;}
      elsif ($_ =~ /^FOOTNOTE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$footnoteTerms = $2;} next;}
      elsif ($_ =~ /^COMMON_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$commonTerms = $2;} next;}
      elsif ($_ =~ /^CURRENT_VERSE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$currentVerseTerms = $2;} next;}
      elsif ($_ =~ /^SUFFIXES:(\s*\((.*?)\)\s*)?$/) {if ($1) {$suffixTerms = $2;} next;}
      elsif ($_ =~ /^STOP_REFERENCE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$stopreference = $2;} next;}
      #elsif ($_ =~ /^EXCLUSION:\s*([^:]+)\s*:\s*(.*?)\s*$/) {$exclusion{$1} .= $sp.$2.$sp; next;}
      else {
        &Log("ERROR: \"$_\" in command file was not handled.\n");
      }
    }
    close (CF);
  }
  else {&Log("ERROR: Command file required: $commandFile\n"); die;}

  &Log("READING INPUT FILE: \"$in_file\".\n");
  &Log("WRITING INPUT FILE: \"$out_file\".\n");
  &Log("\n");
  
  my $bibleOsis;
  if ($MODDRV =~ /Text/) {$bibleOsis = $in_file;}
  # If this is a glossary with a companion Bible, parse the companion Bible's OSIS to collect its footnote osisID values
  elsif ($MODDRV =~ /LD/ && $ConfEntryP->{'Companion'}) {
    my $cinpd = $INPD; $cinpd =~ s/\/[^\/]+\/?$//;
    $bibleOsis = &getOUTDIR($cinpd).'/'.$ConfEntryP->{'Companion'}.'.xml';
  }
  if (-e $bibleOsis) {
    my @files = &splitOSIS($bibleOsis);
    my $bmod;
    my $brefSystem;
    foreach my $file (@files) {
      if ($file !~ /other\.osis$/) {next;}
      my $bosisXml = $XML_PARSER->parse_file($file);
      $bmod = &getOsisRefWork($bosisXml);
      $brefSystem = &getRefSystemOSIS($bosisXml);
      $FNL_MODULE_BIBLE_VERSE_SYSTEMS{$bmod} = &getVerseSystemOSIS($bosisXml);
      last;
    }
    if ($brefSystem =~ /^Bible/) {
      foreach my $file (@files) {
        my $bosisXml = $XML_PARSER->parse_file($file);
        my @fns = $XPC->findnodes('//osis:note[@placement="foot"]', $bosisXml);
        foreach my $fn (@fns) {
          my $id = $bmod.':'.$fn->getAttribute('osisID');
          $OSISID_FOOTNOTE{$id}++;
          my $bc = &bibleContext($fn);
          if ($bc) {&recordVersesOfFootnote($fn, $bc, $bmod);}
          else {&Log("ERROR: Could not determine bibleContext of footnote \"$fn\" in \"$bmod\".\n");}
        }
      }
    }
    else {
      &Log("ERROR: OSIS should be a Bible but is not: \"$bibleOsis\"\n");
    }
  }
  else {
    &Log("ERROR: Bible OSIS was not found at \"$bibleOsis\"!\n");
  }
  
  &Log(sprintf("%-13s         %-50s %-18s %s\n", "LOCATION", "OSISREF", 'TYPE', 'LINK-TEXT'));
  &Log(sprintf("%-13s         %-50s %-18s %s\n", "--------", "-------", '----', '---------'));
  
  my @files = &splitOSIS($in_file);
  my %xmls;
  my $myMod;
  my $myRefSystem;
  foreach my $file (@files) {
    $xmls{$file} = $XML_PARSER->parse_file($file);
    if ($file =~ /other\.osis$/) {
      $myMod = &getOsisRefWork($xmls{$file});
      $myRefSystem = &getRefSystemOSIS($xmls{$file});
      $OSISREFWORK = @{$XPC->findnodes('//osis:osisText/@osisRefWork', $xmls{$file})}[0]->getValue();
      $FNL_MODULE_BIBLE_VERSE_SYSTEMS{$myMod} = &getVerseSystemOSIS($xmls{$file});
    }
  }
  if ($myRefSystem =~ /^(Bible|Dict)/) {
    foreach my $file (sort keys %xmls) {
      &processXML($xmls{$file}, $myMod, $myRefSystem);
      open(OUTF, ">$file") or die "addFootnoteLinks could not open splitOSIS file: \"$file\".\n";
      print OUTF $xmls{$file}->toString();
      close(OUTF);
    }
  }
  else {
    &Log("ERROR addFootnoteLinks: Not yet supporting refSystem \"$myRefSystem\"\n");
  }
  &joinOSIS($out_file);

  &Log("Finished adding <reference> tags.\n");
  &Log("\n");
  &Log("\n");
  &Log("#################################################################\n");
  &Log("\n");
  
  foreach my $k (keys %FNL_FIX) {foreach my $t (keys %{$FNL_FIX{$k}}) {if ($FNL_FIX{$k}{$t} ne 'done') {&Log("ERROR: FIX: LOCATION='$k' was not applied!\n");}}}
  &Log("\n");
  
  &Log("$MOD REPORT: Phrases which were converted into footnote links (".scalar(keys(%FNL_LINKS))." different phrases):\n");
  my $x = 0; foreach my $p (sort keys %FNL_LINKS) {if (length($p) > $x) {$x = length($p);}}
  foreach my $p (sort keys %FNL_LINKS) {&Log(sprintf("%-".$x."s (%i)\n", $p, $FNL_LINKS{$p}));}
  &Log("\n");
    
  &Log("$MOD REPORT: Grand Total Footnote links: (".&stat()." instances)\n");
  &Log(sprintf("%5i - Referenced to previous reference\n", &stat('ref')));
  &Log(sprintf("%5i - Referenced to current verse\n", &stat('self')));
  &Log(sprintf("%5i - Fixed references\n", &stat('fix')));
  &Log("\n");
  &Log(sprintf("%5i - Ordinal: default\n", &stat('\-d$')));
  &Log(sprintf("%5i - Ordinal: specific\n", &stat('\d+$')));
  &Log(sprintf("%5i - Ordinal: last\n", &stat('last')));
  &Log(sprintf("%5i - Ordinal: previous\n", &stat('prev')));
  &Log(sprintf("%5i - Ordinal: next\n", &stat('next')));
  &Log("\n");
  &Log(sprintf("%5i - Single references\n", &stat('single')));
  &Log(sprintf("%5i - Multiple consecutive footnote references\n", &stat('multi')));
  &Log("FINISHED!\n\n");
}

# Record each separate verse of a footnote's context and annotateRef. 
# This allows verse -> footnote lookup
sub recordVersesOfFootnote($$$) {
  my $f = shift;
  my $bibleContext = shift;
  my $footnoteModuleName = shift;
  
  if (!$bibleContext) {return;}
  
  my $c = $bibleContext; $c =~ s/^([^\.]*)\..*$/$1/; if ($c ne $AFL_LC) {&Log("recordVersesOfFootnote() \"$c\"\n", 2);} $AFL_LC = $c;
  
  my @verses = &context2array($bibleContext);
  foreach my $verse (@verses) {
    if (@verses > 1) {
      # This footnote is in a linked verse. See if annotateRef tells
      # us which particular verse(s) this footnote refers to. If the annotateRef
      # points to verses outside this link, these are ignored.
      my @annotateRef = $XPC->findnodes('.//osis:reference[@type="annotateRef"][1]', $f);
      if (@annotateRef && @annotateRef[0]) {
        if ($verse !~ /^[^\.]*\.([^\.]*)\.([^\.]*)$/) {&Log("ERROR recordVersesOfFootnote: Bad verse \"$verse\"!\n"); next;}
        my $chv = $1; my $vsv = $2;
        my $ar = @annotateRef[0]->textContent;
        if ($ar =~ /^((\d+):)?(\d+)(\-(\d+))?$/) {
          my $ch = $2; my $v1 = $3; my $v2 = $5;
          if (!$v2) {$v2 = $v1;}
          if ($ch && $ch ne $chv) {
            &Log("ERROR recordVersesOfFootnote: Footnote's annotateRef \"$ar\" has different chapter than footnote's verses \"$bibleContext\"!\n");
          }
          if ($vsv < $v1 || $vsv > $v2) {
            &Log("NOTE: recordVersesOfFootnote Determined that verse \"$verse\" of linked verse \"$bibleContext\" does not apply to footnote because annotateRef is \"$ar\".\n");
            next;
          }
        }
        else {&Log("ERROR recordVersesOfFootnote: Unexpected annotateRef \"$ar\"!\n");}
      }
    }
    my $key = $footnoteModuleName.':'.$verse;
    if (!exists($VERSE_FOOTNOTE_IDS{$key})) {$VERSE_FOOTNOTE_IDS{$key} = ();}
    push(@{$VERSE_FOOTNOTE_IDS{$key}}, $footnoteModuleName.':'.$f->getAttribute('osisID'));
  }
}

sub processXML($$) {
  my $xml = shift;
  my $myMod = shift;
  my $refSystem = shift;

  # get every text node
  my @allTextNodes = $XPC->findnodes('//text()', $xml);

  # apply text node filters and process desired text-nodes
  my %nodeInfo;
  foreach my $textNode (@allTextNodes) {
    if ($textNode->data() =~ /^\s*$/) {next;}
    if ($XPC->findnodes('ancestor::osis:header|ancestor::osis:reference', $textNode)) {next;}
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
    $BK = "unknown";
    $CH = 0;
    $VS = 0;
    $LV = 0;
    $intro = 0;
    if ($refSystem =~ /^Bible/) {
      my $bcontext = &bibleContext($textNode);
      if ($bcontext !~ /^(\w+)\.(\d+)\.(\d+)\.(\d+)$/) {
        &Log("ERROR processXML: Unrecognized textNode Bible context \"$bcontext\"\n");
        next;
      }
      $BK = $1;
      $CH = $2;
      $VS = $3;
      $LV = $4;
      $intro = ($VS ? 0:1);
    }
    else {
      my $entryScope = &getEntryScope($textNode);
      if ($entryScope && $entryScope !~ /[\s\-]/) {$BK = $entryScope;}
      $CH = &decodeOsisRef(&glossaryContext($textNode));
    }

    # display progress
    my $thisp = "$BK.$CH.$VS";
    $thisp =~ s/^([^\.]*\.[^\.]*)\..*$/$1/;
    if ($LASTP ne $thisp) {&Log("--> $thisp\n", 2);} $LASTP = $thisp;

    if ($intro && $skipintros) {next;}
    
    my $text = &addFootnoteLinks2TextNode($textNode, $myMod);
   
    # save changes for later (to avoid messing up line numbers)
    if ($text) {
      $nodeInfo{$textNode->unique_key}{'text'} = $text;
      $nodeInfo{$textNode->unique_key}{'node'} = $textNode;
    }
  }

  # replace the old text nodes with the new
  foreach my $n (keys %nodeInfo) {
    $nodeInfo{$n}{'node'}->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($nodeInfo{$n}{'text'}), $nodeInfo{$n}{'node'});
    $nodeInfo{$n}{'node'}->unbindNode();
  }
}

sub stat($) {
  my $re = shift;
  my $t = 0;
  for my $k (keys %FNL_STATS) {if (!$re || $k =~ /$re/) {$t += $FNL_STATS{$k};}}
  return $t;
}

##########################################################################
##########################################################################
# 1) LOCATE RIGHTMOST UNLINKED FOOTNOTE-TERM
# 2) FIND AND PARSE ITS ASSOCIATED EXTENDED REFERENCE, WHICH BEGINS WITH 
#    EITHER A REFERENCE ELEMENT OR A "THIS VERSE" TERM
# 3) REPEAT FROM STEP 1 UNTIL THERE ARE NO UNLINKED FOOTNOTE-TERMS
sub addFootnoteLinks2TextNode($$) {
  my $textNode = shift;
  my $myMod = shift;
  
  my $xml = $textNode->ownerDocument;
  
  if ($textNode->data() !~ /\b($footnoteTerms)($suffixTerms)*\b/i) {return '';}
  
  my $text = $textNode->data();
  my $ordTerms = join("|", keys(%TERM_ORDINAL));
  
  my %refInfo;
  my $keyRefInfo = 1;
  my $skipSanityCheck = 0;
  
  while ($text =~ s/^(.*)\b(?<!\>)(($footnoteTerms)($suffixTerms)*)\b(.*?)$/$1$FNREFSTART$2$FNREFEND$5/i) {
    my $beg = $1;
    my $term = "$FNREFSTART$2$FNREFEND";
    my $end = $5;
    
    my $refType;
    my $skipTargetReplacement = 0;
    my $skipFixIndexing = 0;
    
    # Work backwards from our term to discover...
    # Ordinal:
    my $ordinal;
    if ($beg =~ s/(\b($ordTerms)($suffixTerms)*\b\s*)$//i) {
      my $ordinalTerm = $1;
      my $ordinalTermKey = $2;
      $term = $ordinalTerm.$term; # was removed from beg so add to term so it's not lost
      $ordinal = $TERM_ORDINAL{$ordinalTermKey};
    }
  
    # Target footnote's osisRef addresses: (must be either "this verse", or else discovered via back-to-back reference elements, or a FIX)
    my @osisRefs = ();
    my $haveRef = &previousAdjacentReference($textNode);
    if ($haveRef && $beg =~ /^(($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)*$/i) {
      $refType = 'ref';
      my $bbrefs = "";
      do {
        $bbrefs = $haveRef->toString().$bbrefs;
        my $nr = &previousAdjacentReference($haveRef);
        $haveRef = $nr;
      } while ($haveRef);
      my $orig = $bbrefs;
      if ($stopreference && $bbrefs =~ s/^.*$stopreference//) {
        $orig =~ s/<[^>]*>//g; my $new = $bbrefs; $new =~ s/<[^>]*>//g;
        &Log("NOTE: $BK.$CH.$VS: STOP_REFERENCE shortened reference from \"$orig\" to \"$new\"\n");
      }
      while ($bbrefs =~ s/^.*?osisRef="([^"]*)"//) {
        my $a = $1;
        if ($a !~ /^\w+\:/) {$a = "$myMod:$a";}
        push(@osisRefs, $a);
      }
    }
    elsif ($beg =~ /($currentVerseTerms)($suffixTerms)*(($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)*$/i) {
      $refType = 'self';
      push(@osisRefs, "$myMod:$BK.$CH.$VS");
    }
    # FIX implementation...
    elsif (exists($FNL_FIX{"$BK.$CH.$VS"})) {
      foreach my $t (keys %{$FNL_FIX{"$BK.$CH.$VS"}}) {
        if ($FNL_FIX{"$BK.$CH.$VS"}{$t} eq 'done') {next;}
        if ("$beg$term" =~ /\Q$t\E/) {
          my $value = $FNL_FIX{"$BK.$CH.$VS"}{$t};
          if ($value !~ s/^(REPLACEMENT)://) {
            &Log("ERROR $BK.$CH.$VS: FIX Bad command value \"$value\"\n");
            next;
          }
          my $type = $1;
          
          # REPLACEMENT was given
          if ($type eq 'REPLACEMENT') {
            if ($value eq 'SKIP') {
              $skipTargetReplacement = 1;
              $skipFixIndexing = 1;
              $skipSanityCheck = 1;
            }
            else {
              if ($value =~ /^(.*)\b(?<!\>)(($footnoteTerms)($suffixTerms)*)\b/) { # copied from main while loop, this check is to ensure it does not go endless!
                &Log("ERROR $BK.$CH.$VS: FIX \"$t\" - BAD Fix REPLACEMENT=\"$value\" must have reference start tag before \"$2\"!\n");
                next;
              }
              if ($text !~ s/\Q$t\E/$value/) {
                &Log("ERROR $BK.$CH.$VS: FIX \"$t\" - REPLACEMENT failed!\n");
                next;
              }
              $skipTargetReplacement = 1;
              $skipSanityCheck = 1;
            }
          }

          &Log("NOTE $BK.$CH.$VS: Applied FIX \"$t\"\n");
          $refType = 'fix';
          $FNL_FIX{"$BK.$CH.$VS"}{$t} = 'done';
          last;
        }
      }
    }
    else {
      &Log("ERROR $BK.$CH.$VS: Could not find target footnote verse: $beg$term\n");
      next;
    }
    
    # Now, other associated ordinal terms become separate links to the same base osisRefs, but with different extensions
    if (!$skipTargetReplacement && $beg =~ /((($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)+)$/) {
      my $terms = $1;
      my $initialTerms = $terms;
      while ($terms =~ s/\b(?<!\>)(($ordTerms)($suffixTerms)*)\b/$FNREFSTART$1$FNREFEND/) {
        my $ordTermKey = $2;
        
        my $osisID = &convertOrdinal($TERM_ORDINAL{$ordTermKey}, \@osisRefs, $textNode, $myMod, $xml);
        if ($osisID) {
          $terms =~ s/\bTARGET\b/$keyRefInfo=$osisID/;
          $refInfo{$keyRefInfo++} = "$refType-multi-".$TERM_ORDINAL{$ordTermKey};
        }
        else {
          &Log("ERROR: $BK.$CH.$VS: Failed to convert associated ordinal: term=$ordTermKey, ord=".$TERM_ORDINAL{$ordTermKey}.", osisRef ".join(' ', @osisRefs).", textNode=".$textNode->data()."\n");
        }
      }
      if ($terms ne $initialTerms) {
        my $initialBeg = $beg;
        if ($beg !~ s/\Q$initialTerms\E$/$terms/) {
          &Log("ERROR $BK.$CH.$VS: Associated ordinal beg term(s) were not replaced!\n");
        }
        if ($text !~ s/^\Q$initialBeg\E/$beg/) {
          &Log("ERROR $BK.$CH.$VS: Associated ordinal text term(s) were not replaced!\n");
        }
      }
    }
   
    if (!$skipTargetReplacement) {
      my $osisID = &convertOrdinal($ordinal, \@osisRefs, $textNode, $myMod, $xml);
      if ($osisID) {
        $text =~ s/\bTARGET\b/$keyRefInfo=$osisID/;
        $refInfo{$keyRefInfo++} = "$refType-single-".($ordinal ? $ordinal:'d');
      }
      else {
        &Log("ERROR: $BK.$CH.$VS: Failed to convert ordinal: ord=$ordinal, osisRefs ".join(' ', @osisRefs).", textNode=".$textNode->data()."\n");
      }
    }
    elsif (!$skipFixIndexing) {
      my $c = 0;
      while ($text =~ s/(\bosisRef=")(?!\d+=)([^"]*")(.*?)$/$1$keyRefInfo=$2$3/) {
        $c++;
        my $or = $2; if ($or =~ /\Q$FNREFEXT\E(\d+)"/) {$or = $1;} else {$or = "?";}
        $refInfo{$keyRefInfo++} = "$refType-".($c == 1 ? 'single':'multi')."-$or";
      }
    }
     
    if (!$skipSanityCheck && $text =~ /\b(TARGET)\b/) {
      &Log("ERROR $BK.$CH.$VS: Footnote link problem: $text\n");
    }
  }
  
  $text =~ s/$FNREFSTART([^<]*)$FNREFEND/$1/g; # undo any failed conversions
  
  # Expand adjacent associated link-texts so links are touching one another (this way front ends can aggregate them)
  my @alks = split(/(\b(?:$footnoteTerms)(?:$suffixTerms)*)\b/, $text);
  foreach my $alk (@alks) {
    $alk =~ s/(<\/reference>)([^<]+)(<reference [^>]*>)/$1$3$2/g;
  }
  $text = join('', @alks);
  
  # The following puts any leading reference directly after target reference, as a harmless work-around for a bug in xulsword <= 3.14
  if (&previousAdjacentReference($textNode)) {$text =~ s/^(\s+)(<reference [^>]*>)/$2$1/;}
  
  # Sanity checks (shouldn't be needed but makes me feel better)
  my $test = $text; $test =~ s/<[^>]*>//g;
  if (!$skipSanityCheck && $text eq $textNode->data()) {
    &Log("ERROR $BK.$CH.$VS: Failed to create any footnote link(s) from existing footnote term(s).\n");
    return '';
  }
  elsif (!$skipSanityCheck && $text !~ /<reference [^>]*osisRef="([^"]*)"[^>]*>([^<]*)<\/reference>/) {
    &Log("ERROR $BK.$CH.$VS: Footnote text was changed, but no links were created!:\n\t\tBEFORE=".$textNode->data()."\n\t\tAFTER =$text\n");
    return '';
  }
  elsif ($textNode->data() ne $test) {
    &Log("ERROR $BK.$CH.$VS: A text node was corrupted!:\n\t\tORIGINAL=".$textNode->data()."\n\t\tPARSED  =$test\n");
    return '';
  }
  else {
    my $report = $text;
    $text =~ s/(osisRef=")\d+=/$1/g; # remove refInfoKey
    $text =~ s/(osisRef=")$OSISREFWORK\:/$1/g; # remove default osisRefWork
    while ($report =~ s/<reference [^>]*osisRef="(\d+)=([^"]*)"[^>]*>([^<]*)<\/reference>//) {
      my $key = $1;
      my $ref = $2;
      my $linkText = $3;
      &Log(sprintf("Linking %-13s %-50s %-18s %s\n", "$BK.$CH.$VS", "osisRef=\"$ref\"", $refInfo{$key}, $linkText));
      $FNL_STATS{$refInfo{$key}}++;
      $FNL_LINKS{$linkText}++;
      if (!$OSISID_FOOTNOTE{$ref}) {
        &Log("ERROR $BK.$CH.$VS: Footnote with osisID=\"$ref\" does not exist!\n");
      }
      elsif ($OSISID_FOOTNOTE{$ref} > 1) {
        &Log("ERROR $BK.$CH.$VS: Multiple footnotes with osisID=\"$ref\"!\n");
      }
    }
  }
  
  return $text;
}

# Returns the previous adjacent reference element if there is one, or else ''
sub previousAdjacentReference($) {
  my $node = shift;
  
  if (!$node) {return '';}
  
  my @r = $XPC->findnodes('preceding-sibling::node()[1]', $node);
  
  if (@r && @r[0] && @r[0]->nodeName eq "reference") {return @r[0];}
  
  return '';
}

# Returns 0 on failure, or else it returns a single footnote's MOD:osisID
# of an existing footnote. This footnote corresponds to the requested 
# ordinal-abbreviation and osisRef-list or textNode (textNode in case of 
# prev/next ordinals). The $ord may be empty which is interepereted as 
# unspecified first (ordinal 1).
sub convertOrdinal($\@$$$) {
  my $ord = shift;
  my $osisRefsP = shift; # ordered array of osisRefs, each beginning with module:
  my $textNode = shift; # required for prev and next ordinals since they apply to self
  my $textMod = shift; # required for prev and next ordinals since they apply to self
  my $xml = shift;
  
  my $ordUnspecified = 0;
  if (!$ord) {
    $ord = 1;
    $ordUnspecified = 1;
  }
  
  if ($ord =~ /^\d+$/ || $ord eq 'last') {
    my $fnOsisIdsP = &getFootnotes($osisRefsP);
    
    if (!@{$fnOsisIdsP} || !@{$fnOsisIdsP}[0]) {
      &Log("ERROR $BK.$CH.$VS: The text targets a footnote in osisRefs \"".join(' ', @{$osisRefsP})."\" but there are no footnotes there!\n");
      return 0;
    }

    if ($ord eq 'last') {
      if (@{$fnOsisIdsP} == 1) {
        &Log("ERROR $BK.$CH.$VS: The 'last' ordinal was used for osisRefs \"".join(' ', @{$osisRefsP})."\" which contain only one footnote. This doesn't make sense.\n");
      }
      return @{$fnOsisIdsP}[$#{$fnOsisIdsP}];
    }
    else {
      if ($ordUnspecified && @{$fnOsisIdsP} > 1) {
        my $txt = $textNode->data();
        my $haveRef = &previousAdjacentReference($textNode);
        while ($haveRef) {
          $txt = $haveRef->toString().$txt;
          my $nr = &previousAdjacentReference($haveRef);
          $haveRef = $nr;
        }
        $txt =~ s/<[^>]*>//g;
        &Log("WARNING $BK.$CH.$VS: ONLY THE FIRST FOOTNOTE IS LINKED even though the target reference(s) \"".join(' ', @{$osisRefsP})."\" contain \"".@{$fnOsisIdsP}."\" footnotes pointed to by the text: \"$txt\".\n");
      }
      if (!@{$fnOsisIdsP}[($ord-1)]) {
        &Log("ERROR $BK.$CH.$VS: The text targets footnote \"$ord\" of osisRefs \"".join(' ', @{$osisRefsP})."\" but such a footnote does not exist!\n");
        return 0;
      }
      return @{$fnOsisIdsP}[($ord-1)];
    }
  }
  
  # Assumes prev/next will always be in the same verse! These are always relative to textNode's footnote, so @osisRefs are ignored
  elsif ($ord eq 'prev') {
    my $osisID = &getOsisIdOfFootnoteNode($textNode);
    if ($osisID && $osisID =~ /^(.*?)\Q$FNREFEXT\E(\d+)$/) {
      my $pref = $1;
      my $pord = $2;
      $pord--;
      my $nid = $textMod.':'.$pref.$FNREFEXT.$pord;
      if (!$pord || !$OSISID_FOOTNOTE{$nid}) {
        &Log("ERROR $BK.$CH.$VS: Footnote has no previous sibling \"$nid\"\n");
      }
      else {return $nid;}
    }
  }
  elsif ($ord eq 'next') {
    my $osisID = &getOsisIdOfFootnoteNode($textNode);
    if ($osisID && $osisID =~ /^(.*?)\Q$FNREFEXT\E(\d+)$/) {
      my $pref = $1;
      my $nord = $2;
      $nord++;
      my $nid = $textMod.':'.$pref.$FNREFEXT.$nord;
      if (!$OSISID_FOOTNOTE{$nid}) {
        &Log("ERROR $BK.$CH.$VS: Footnote has no next sibling: \"$nid\"\n");
      }
      else {return $nid;}
    }    
  }
  else {
    &Log("ERROR $BK.$CH.$VS: Unhandled ordinal type \"$ord\". This footnote is broken.\n");
  }
  
  return 0;
}

# Takes any footnote node (or node within a footnote) and returns the 
# footnote's osisID. Returns '' on error/fail.
sub getOsisIdOfFootnoteNode($) {
  my $node = shift;
  
  my @fn = $XPC->findnodes('ancestor-or-self::osis:note[@placement="foot"][1]', $node);
  if (!@fn || !@fn[0]) {
    &Log("ERROR $BK.$CH.$VS: Node must be (in) a footnote!: $node\n");
    return '';
  }
  
  return @fn[0]->getAttribute('osisID');
}

# Takes an array of Scripture mod:osisRefs, whose elements may contain 
# ranges, and returns sequential osisIDs of all footnotes contained 
# within each osisRef. Each footnote will only appear in the list once, 
# even if there are linked verses etc..
sub getFootnotes($) {
  my $osisRefsP = shift;

  my @verses = (); # verses (in order but duplicates are ok) referred to by osisRefs
  foreach my $or (@{$osisRefsP}) {
    my $osisRef = $or; # never modify array pointer value $or!
    my $m = ($osisRef =~ s/^(\w*):// ? $1:'');
    my $osisID = &osisRef2osisID($osisRef, $MOD);
    foreach my $id (split(/\s+/, $osisID)) {
      push(@verses, "$m:$id");
    }
  }

  # Any "verses" which refer to entire chapters (ie John.3) need separate actual verses spliced into the array
  for (my $i=0; $i<@verses; $i++) {
    if (@verses[$i] !~ /^(\w*):([^\.]*)\.([^\.]*)$/) {next;}
    my $mod = $1; my $bk = $2; my $ch = $3;
    my ($canonP, $bookOrderP, $bookArrayP);
    &getCanon($FNL_MODULE_BIBLE_VERSE_SYSTEMS{$mod}, \$canonP, \$bookOrderP, NULL, \$bookArrayP);
    my @a;
    for (my $vs = 0; $vs <= $canonP->{$bk}->[$ch-1]; $vs++) { # 0 includes chapter intro (for Pslams esp.)
      push(@a, "$mod:$bk.$ch.$vs");
    }
    splice(@verses, $i, 1, @a);
    $i = $i-1+@a;
  }

  my @osisIDs = (); # osisIDs of footnotes in verses (in order, no duplicates)
  foreach $verse (@verses) {
    my $verseOsisIDsP = $VERSE_FOOTNOTE_IDS{$verse};
    if (@{$verseOsisIDsP} && @{$verseOsisIDsP}[0]) {push(@osisIDs, @{$verseOsisIDsP});}
  }

  # Due to linked verses, or other possibilities, the same footnote might 
  # appear more than once in osisIDs list. So remove any duplicate footnotes.
  my %ids;
  for (my $i=0; $i < @osisIDs; $i++) {
    if (!$ids{@osisIDs[$i]}) {$ids{@osisIDs[$i]}++; next;}
    splice(@osisIDs, $i--, 1);
  }
 
  return \@osisIDs;
}


1;
