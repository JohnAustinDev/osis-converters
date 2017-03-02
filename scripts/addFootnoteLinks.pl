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
#       form: LOCATION='book.ch.vs' AT='ref text' TARGET='osisID|NONE'
#       If TARGET is NONE, there will be no reference link at all.

$RefStart = "<reference type=\"x-footnote\" osisRef=\"TARGET\">";
$RefEnd = "</reference>";
$RefExt = "!footnote.n";

require("$SCRD/scripts/processGlossary.pl");

%OSISID_FOOTNOTE;
%FNL_FIX;
%TERM_ORDINAL;
%FNL_STATS;

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
        if ($fix !~ s/\bTARGET='(\S+)'//) {&Log("ERROR: Could not find TARGET='book.ch.vs!footnote.nx' in FIX statement: $_\n"); next;}
        my $target = $1;
        if ($fix !~ s/\bAT='(.*?)(?<!\\)'//) {&Log("ERROR: Could not find AT='reference text' in FIX statement: $_\n"); next;}
        my $at = $1; $at =~ s/\\'/'/g;
        $FNL_FIX{$location}{$at} = $target;
        next;
      }
      elsif ($_ =~ /^SKIP_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$skip_xpath = $2;} next;}
      elsif ($_ =~ /^ONLY_XPATH:(\s*(.*?)\s*)?$/) {if ($1) {$only_xpath = $2;} next;}
      elsif ($_ =~ /^SKIP_INTRODUCTIONS:\s*(.*?)\s*$/) {$skipintros = $1; $skipintros = ($skipintros && $skipintros !~ /^false$/i ? 1:0); next;}
      elsif ($_ =~ /^FOOTNOTE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$footnoteTerms = $2;} next;}
      elsif ($_ =~ /^COMMON_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$commonTerms = $2;} next;}
      elsif ($_ =~ /^CURRENT_VERSE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$currentVerseTerms = $2;} next;}
      elsif ($_ =~ /^SUFFIXES:(\s*\((.*?)\)\s*)?$/) {if ($1) {$suffixTerms = $2;} next;}
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
  
  &Log(sprintf("%-13s         %-50s %-18s %s\n", "LOCATION", "OSISREF", 'TYPE', 'LINK-TEXT'));
  &Log(sprintf("%-13s         %-50s %-18s %s\n", "--------", "-------", '----', '---------'));
  
  my @files = &splitOSIS($in_file);
  my %xmls; 
  foreach my $file (@files) {
    $xmls{$file} = $XML_PARSER->parse_file($file);
  }
  foreach my $file (sort keys %xmls) {
    &footnoteXML($xmls{$file}); # Do this first to collect/write all footnote osisID values before processing
  }
  foreach my $file (sort keys %xmls) {
    &processXML($xmls{$file});
    open(OUTF, ">$file") or die "addFootnoteLinks could not open splitOSIS file: \"$file\".\n";
    print OUTF $xmls{$file}->toString();
    close(OUTF);
  }
  &joinOSIS($out_file);

  &Log("Finished adding <reference> tags.\n");
  &Log("\n");
  &Log("\n");
  &Log("#################################################################\n");
  &Log("\n");
  
  foreach my $k (keys %FNL_FIX) {foreach my $t (keys %{$FNL_FIX{$k}}) {if ($FNL_FIX{$k}{$t} ne 'done') {&Log("ERROR: FIX: LOCATION='$k' was not applied!\n");}}}
  &Log("\n");
    
  &Log("REPORT: Grand Total Footnote links: (".&stat()." instances)\n");
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

  &Log("LINK RESULTS FROM: $out_file\n");
  &Log("\n");


}

sub footnoteXML($) {
  my $xml = shift;
  
  # add osisIDs to every footnote
  my @allFootnotes = $XPC->findnodes('//osis:note[@placement="foot"]', $xml);
  foreach my $f (@allFootnotes) {
    my $osisID = &bibleContext($f, 1);
    if ($osisID) {
      if ($osisID !~ s/^(\w+\.\d+\.\d+)\.\d+$/$1/) {
        &Log("ERROR: Bad context for footnote osisID: \"$osisID\"\n");
        next;
      }
    }
    else {
      $osisID = &encodeOsisRef(&glossaryContext($f))."$RefExt$n";
      next;
    }
    my $id = $f->getAttribute('osisID');
    if ($id) {&Log("WARNING: Footnote has pre-existing osisID=\"$id\"!\n");}
    my $n = 1;
    $id = "$osisID$RefExt$n";
    while ($OSISID_FOOTNOTE{$id}) {$n++; $id = "$osisID$RefExt$n";}
    $OSISID_FOOTNOTE{$id}++;
    $f->setAttribute('osisID', $id);
  }
}

sub processXML($) {
  my $xml = shift;

  # get every text node
  my @allTextNodes = $XPC->findnodes('//text()', $xml);

  # apply text node filters and process desired text-nodes
  my %nodeInfo;
  foreach my $textNode (@allTextNodes) {
    if ($textNode =~ /^\s*$/) {next;}
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

    # display progress
    my $thisp = "$BK.$CH.$VS";
    $thisp =~ s/^([^\.]*\.[^\.]*)\..*$/$1/;
    if ($LASTP ne $thisp) {&Log("--> $thisp\n", 2);} $LASTP = $thisp;

    if ($intro && $skipintros) {next;}
    
    my $text = &addFootnoteLinks2TextNode($textNode, $xml);
   
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
  my $xml = shift;
  
  if ($textNode->data() !~ /\b($footnoteTerms)($suffixTerms)*\b/i) {return '';}
  
  my $text = $textNode->data();
  my $ordTerms = join("|", keys(%TERM_ORDINAL));
  
  my %refInfo;
  my $keyRefInfo = 1;
  my $skipSanityCheck = 0;
  while ($text =~ s/^(.*)\b(?<!\>)(($footnoteTerms)($suffixTerms)*)\b(.*?)$/$1$RefStart$2$RefEnd$5/i) {
    my $beg = $1;
    my $term = "$RefStart$2$RefEnd";
    my $end = $5;
    
    my $refType;
    my $refMod = $MOD;
    
    # Work backwards from our term to discover...
    # Ordinal:
    my $ordinal;
    if ($beg =~ s/(\b($ordTerms)($suffixTerms)*\b\s*)$//i) {
      my $ordinalTerm = $1;
      my $ordinalTermKey = $2;
      $term = $ordinalTerm.$term; # was removed from beg so add to term so it's not lost
      $ordinal = $TERM_ORDINAL{$ordinalTermKey};
    }
  
    # Target footnote's osisRef address: (must be either "this verse", or else discovered via a reference element)
    my $osisRef; 
    my @haveRef = $XPC->findnodes('preceding::*[1][self::osis:reference]', $textNode);
    if (@haveRef && @haveRef[0] && $beg =~ /^(($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)*$/i) {
      $osisRef = @haveRef[0]->getAttribute('osisRef');
      $osisRef =~ s/^([^:]*)://;
      if ($1) {$refMod = $1;}
      if (!$osisRef) {
        &Log("ERROR $BK.$CH.$VS: verse reference has no osisRef: ".@haveRef[0]."\n");
        next;
      }
      $refType = 'ref';
    }
    elsif ($beg =~ /($currentVerseTerms)($suffixTerms)*(($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)*$/i) {
      $osisRef = "$BK.$CH.$VS";
      $refType = 'self';
    }
    elsif (exists($FNL_FIX{"$BK.$CH.$VS"})) {
      foreach my $t (keys %{$FNL_FIX{"$BK.$CH.$VS"}}) {
        if ($FNL_FIX{"$BK.$CH.$VS"}{$t} eq 'done') {next;}
        if ("$beg$term" =~ /\Q$t\E/) {
          $osisRef = $FNL_FIX{"$BK.$CH.$VS"}{$t};
          if ($osisRef =~ s/^(([^:]*):)?(.*?)\Q$RefExt\E(\d+)$/$3/) {
            $ordinal = $4;
            if ($2) {$refMod = $2;}
          }
          elsif ($osisRef ne 'NONE') {
            &Log("ERROR $BK.$CH.$VS: Bad Fix osisRef:\"".$osisRef."\"\n");
            next;
          }

          &Log("NOTE $BK.$CH.$VS: Applied FIX \"$t\"\n");
          $refType = 'fix';
          $FNL_FIX{"$BK.$CH.$VS"}{$t} = 'done';
          last;
        }
      }
      if (!$osisRef) {
        &Log("ERROR $BK.$CH.$VS: Failed to apply FIX: $beg$term\n");
        next;
      }
    }
    else {
      &Log("ERROR $BK.$CH.$VS: Could not find target footnote verse: $beg$term\n");
      next;
    }
    
    # Now, other associated ordinal terms become separate links to the same base osisRef, but with different extensions
    if ($osisRef ne 'NONE' && $beg =~ /((($commonTerms)($suffixTerms)*|($ordTerms)($suffixTerms)*|\s)+)$/) {
      my $terms = $1;
      my $initialTerms = $terms;
      while ($terms =~ s/\b(?<!\>)(($ordTerms)($suffixTerms)*)\b/$RefStart$1$RefEnd/) {
        my $ordTermKey = $2;
        
        my $osisID = ($refMod ne $MOD ? "$refMod:":'').&convertOrdinal($TERM_ORDINAL{$ordTermKey}, $osisRef, $textNode, $xml);
        if ($osisID) {
          $terms =~ s/\bTARGET\b/$keyRefInfo=$osisID/;
          $refInfo{$keyRefInfo++} = "$refType-multi-".$TERM_ORDINAL{$ordTermKey};
        }
        else {
          &Log("ERROR: $BK.$CH.$VS: Failed to convert associated ordinal: term=$ordTermKey, ord=".$TERM_ORDINAL{$ordTermKey}.", osisRef=$osisRef, textNode=$textNode\n");
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
    
    my $osisID = ($refMod ne $MOD ? "$refMod:":'').($ordinal ? &convertOrdinal($ordinal, $osisRef, $textNode, $xml):$osisRef.$RefExt.'1');
    if ($osisRef eq 'NONE') {
      $skipSanityCheck = 1;
    }
    elsif ($osisID) {
      $text =~ s/\bTARGET\b/$keyRefInfo=$osisID/;
      $refInfo{$keyRefInfo++} = "$refType-single-".($ordinal ? $ordinal:'d');
    }
    else {
      &Log("ERROR: $BK.$CH.$VS: Failed to convert ordinal: ord=$ordinal, osisRef=$osisRef, textNode=$textNode\n");
    }
    
    if (!$skipSanityCheck && $text =~ /\b(TARGET)\b/) {
      &Log("ERROR $BK.$CH.$VS: Footnote link problem: $text\n");
    }
  }
  
  $text =~ s/$RefStart([^<]*)$RefEnd/$1/g; # undo any failed conversions
  
  # Expand adjacent associated link-texts so links are touching one another (this way front ends can aggregate them)
  my @alks = split(/(\b(?:$footnoteTerms)(?:$suffixTerms)*)\b/, $text);
  foreach my $alk (@alks) {
    $alk =~ s/(<\/reference>)([^<]+)(<reference [^>]*>)/$1$3$2/g;
  }
  $text = join('', @alks);
  
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
    while ($report =~ s/<reference [^>]*osisRef="(\d+)=([^"]*)"[^>]*>([^<]*)<\/reference>//) {
      my $key = $1;
      my $ref = $2;
      my $linkText = $3;
      &Log(sprintf("Linking %-13s %-50s %-18s %s\n", "$BK.$CH.$VS", "osisRef=\"$ref\"", $refInfo{$key}, $linkText));
      $FNL_STATS{$refInfo{$key}}++;
    }
  }
  
  return $text;
}

# returns 0 on error, or else an existing footnote osisID which 
# corresponds to the requested ordinal abbreviation, osisRef and textNode
sub convertOrdinal($$$$) {
  my $ord = shift;
  my $osisRef = shift;
  my $textNode = shift;
  my $xml = shift;
  
  if ($ord =~ /^\d+$/) {return $osisRef.$RefExt.$ord;}
  elsif ($ord eq 'last') {
    my $n = 1;
    my $id = $osisRef.$RefExt.$n;
    while ($OSISID_FOOTNOTE{$id}) {$n++; $id = $osisRef.$RefExt.$n;}
    $n--;
    if ($n < 2) {
      # if this osisRef is compound, then we need to sequentially reverse search each component
      my $refArrayP = &osisRefSegment2array($osisRef);
      if (@{$refArrayP} > 1) {
        for (my $i=(@{$refArrayP}-1); $i>=0; $i--) {
          my $n = 1;
          my $id = @{$refArrayP}[$i].$RefExt.$n;
          while ($OSISID_FOOTNOTE{$id}) {$n++; $id = @{$refArrayP}[$i].$RefExt.$n;}
          if ($n > 1) {return @{$refArrayP}[$i].$RefExt.($n-1);}
        }
      }
      else {
        &Log("ERROR $BK.$CH.$VS: The 'last' ordinal was used for osisRef=\"$osisRef\" having \"$n\" footnote(s). This doesn't make sense.\n");
      }
    }
    return $osisRef.$RefExt.$n;
  }
  elsif ($ord eq 'prev') {
    my $osisID = &getFootnoteOsisID($textNode);
    if ($osisID && $osisID =~ /^(.*?)\Q$RefExt\E(\d+)$/) {
      my $pref = $1;
      my $pord = $2;
      $pord--;
      my $nid = $pref.$RefExt.$pord;
      if (!$pord || !$OSISID_FOOTNOTE{$nid}) {
        &Log("ERROR $BK.$CH.$VS: Footnote has no previous sibling \"$nid\"\n");
      }
      else {return $nid;}
    }
  }
  elsif ($ord eq 'next') {
    my $osisID = &getFootnoteOsisID($textNode);
    if ($osisID && $osisID =~ /^(.*?)\Q$RefExt\E(\d+)$/) {
      my $pref = $1;
      my $nord = $2;
      $nord++;
      my $nid = $pref.$RefExt.$nord;
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
sub getFootnoteOsisID($) {
  my $node = shift;
  
  my @fn = $XPC->findnodes('ancestor-or-self::osis:note[@placement="foot"][1]', $node);
  if (!@fn || !@fn[0]) {
    &Log("ERROR $BK.$CH.$VS: Node must be (in) a footnote!: $node\n");
    return '';
  }
  
  return @fn[0]->getAttribute('osisID');
}

1;
