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

# Peripherals in Bible and Dictionary modules are marked (and/or moved 
# in the case of Bibles) according to special osis-converter instructions 
# found in id comment nodes. These id comment nodes are written by CrossWire's 
# usfm2osis.py script from any text which may follow the \id tag of SFM files.
# In this way, osis-converter instructions appended to the \id tag are used
# to mark (and sometimes move) the peripheral material in the SFM file,
# according to the following instructions:

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($XPC, $XML_PARSER, $ROC, @SUB_PUBLICATIONS, 
    $ORDER_PERIPHS_COMPATIBILITY_MODE, %ANNOTATE_TYPE);
    
# Initialized in /scripts/bible/fitToVerseSystem.pl
our (%ID_TYPE_MAP, %ID_TYPE_MAP_R, %PERIPH_TYPE_MAP, %PERIPH_TYPE_MAP_R, 
     %PERIPH_SUBTYPE_MAP, %PERIPH_SUBTYPE_MAP_R, 
     %USFM_DEFAULT_PERIPH_TARGET);

my $AlreadyReportedThis;

sub placementMessage {
  if ($AlreadyReportedThis) {return '';} $AlreadyReportedThis++;
  return '
  OSIS-CONVERTERS PERIPHERAL INSTRUCTIONS:
  Special instructions for marking peripheral material, and in the case 
  of Bibles also placing that material, may be appended after the \id 
  tags of SFM files. Placement instructions only apply to Bibles because 
  with dictionaries, their material always remains in the order in which 
  it appears in CF_usfm2osis.txt. All instructions appear as a comma 
  separated list of instruction == value pairs.
  
  BIBLES ONLY
  The xpath values below select the element before which a peripheral 
  will be placed. Or to remove a peripheral entirely, the value "remove" 
  (without the quotes) can be used.
  
  INSTRUCTION           ==    VALUE         APPLIES-TO
  location              == <xpath>|remove   The SFM file  
  <div type or subType> == <xpath>|remove   The next periph div with 
                                            that type/subType
  "<USFM periph type>"  == <xpath>|remove   The next periph having that 
                                            USFM type
  x-unknown             == <xpath>|remove   The next periph of any type
  
  BIBLES & DICTIONARIES
  These instructions apply to any periphs that follow in the instruction 
  list, and finally to the containing id periph itself. The value 
  "remove" will cease that marking for the periphs which follow. For 
  dictionaries, in the rare case where there is a peripheral SFM file 
  which contains periph tags, those periphs can be marked differently 
  than the containing id using a Bible instruction above but with the  
  value "mark" rather than an xpath expression.
  
  INSTRUCTION ==  VALUE                      DESCRIPTION
  scope       == <a scope>|remove            The scope to which periphs 
                                             apply
  conversion  == sword|html|epub|none|remove Periphs should appear only  
                                             for the listed conversions
  feature     == INT|INTMENU|remove          Periphs become part of the  
                                             special feature for intro-
                                             ductions.
  ';
}
sub applyPeriphInstructions {
  my $osisP = shift;
  
  &Log("\nApplying periph comments of \"$$osisP\"\n", 1);

  my $xml = $XML_PARSER->parse_file($$osisP);
  
  # Get all id divs
  my @xpath; our %ID_TYPE_MAP;
  foreach my $type (values(%ID_TYPE_MAP)) {
    push(@xpath, '//osis:div[@type="'.$type.'"][not(@subType)]');
  }
  my @idDivs = $XPC->findnodes(join('|', @xpath), $xml);
  
  # For Bibles, remove all id divs
  if (&isBible($xml)) {
    foreach my $idDiv (@idDivs) {$idDiv->unbindNode();}
  }
  
  # Handle each id div
  my %xpathOriginalBeforeNodes;
  foreach my $idDiv (@idDivs) {
    my $placedPeriphFile;
    my $scope; my $conversion; my $feature;

    # read the first comment to find instructions, if any
    my $commentNode = @{$XPC->findnodes('child::node()[2][self::comment()]', $idDiv)}[0];

    my @removedElements = ();
    if ($commentNode && $commentNode =~ /\s\S+ == \S+/) {
      my $comment = $commentNode->textContent;
      #<!-- id comment - (FRT) scope="Gen", titlePage == osis:div[@type='book'], tableofContents == remove, preface == osis:div[@type='bookGroup'][1], preface == osis:div[@type='bookGroup'][1] -->
      $comment =~ s/^.*?(?=\s(?:\S+|"[^"]+") ==)//; $comment =~ s/\s*$//;  # strip beginning/end stuff 
      my @instr = split(/(,\s*(?:\S+|"[^"]+") == )/, ", $comment");
      
      # The last scope, script and feature values in the list will be applied to the container div
      for (my $x=1; $x < @instr; $x += 2) { # start at $x=1 because 0 is always just a leading comma
        my $instruction = @instr[$x] . @instr[($x+1)];
        $instruction =~ s/^,\s*//;
        if ($instruction !~ /^(\S+|"[^"]+") == (.*?)$/) {
          &Error("Unhandled location or scope assignment \"$instruction\" in \"$commentNode\" in CF_usfm2osis.txt");
          next;
        }
        my $inst = $1; my $arg = $2;
        $inst =~ s/(^"|"$)//g; # strip possible quotes
        $arg =~ s/(^"|"$)//g; # quotes are not expected here, but allow them
  
        if ($inst eq 'scope') {
          $scope = ($arg eq 'remove' ? '':$arg);
          next;
        }
        
        if ($inst eq 'conversion') {
          $conversion = ($arg eq 'remove' ? '':$arg);
          next;
        }
        
        if ($inst eq 'feature') {
          $feature = ($arg eq 'remove' ? '':$arg);
          next;
        }
        
        if ($arg eq "osis:header") {
          $ORDER_PERIPHS_COMPATIBILITY_MODE++;
          $arg = "osis:div[\@type='bookGroup'][1]";
          &Error("Introduction comment specifies '$instruction' but this usage has been deprecated.", 
"This xpath was previously interpereted as 'place after the header' but 
it now means 'place as preceding sibling of the header'. Also, the 
peripherals are now processed in the order they appear in the CF file. 
To retain the old meaning, change osis:header to $arg");
          &Warn("Changing osis:header to $arg and switching to compatibility mode.");
        }
        elsif ($ORDER_PERIPHS_COMPATIBILITY_MODE && $arg =~ /div\[\@type=.bookGroup.]\[\d+\]$/) {
          $arg .= "/node()[1]";
          &Error("Introduction comment specifies '$instruction' but this usage has been deprecated.", 
"This xpath was previously interpereted as 'place as first child of the 
bookGroup' but it now is interpereted as 'place as the preceding sibling 
of the bookGroup'. Also, the peripherals are now processed in the order 
they appear in the CF file.");
          &Warn("Changing $instruction to $inst == $arg");
        }
        
        my $elem = ($inst eq 'location' ? $idDiv:&findThisPeriph($idDiv, $inst, $instruction));
        if (!$elem) {next;} # error already given by findThisPeriph()
        
        if ($inst eq 'location') {$placedPeriphFile = 1;}
        else {$elem->unbindNode();}
        
        if ($arg =~ /^mark$/i) {&applyInstructions($elem, $scope, $conversion, $feature);}
        elsif ($arg =~ /^remove$/i) {push(@removedElements, $elem);}
        else {
          # All identical xpath searches must return the same originally found node. 
          # Otherwise sequential order would be reversed with insertBefore */node()[1].
          my $new;
          if (!exists($xpathOriginalBeforeNodes{$arg})) {
            my $beforeNode = @{$XPC->findnodes('//'.$arg, $xml)}[0];
            if (!$beforeNode) {
              &Error("Removing periph! Could not locate xpath:\"$arg\" in command $instruction");
              next;
            }
            $xpathOriginalBeforeNodes{$arg} = $beforeNode;
            $new++;
          }
          # The beforeNode may be a toc or a runningHead or be empty of 
          # text, in which case an appropriate next-sibling will be used 
          # instead (and our beforeNode for this xpath is then updated).
          my $beforeNode = &placeIntroduction($elem, $xpathOriginalBeforeNodes{$arg});
          if ($new) {$xpathOriginalBeforeNodes{$arg} = $beforeNode;}
          &applyInstructions($elem, $scope, $conversion, $feature);
          my $tg = $elem->toString(); $tg =~ s/>.*$/>/s;
          &Note("Placing $inst == $arg for $tg");
        }
      }
      &applyInstructions($idDiv, $scope, $conversion, $feature);
    }
    else {
      if (&isBible($xml)) {
        &Error("Removing periph(s)!", "You must specify the location where each peripheral file should be placed within the OSIS file.");
        &Log(&placementMessage());
        &Warn("REMOVED:\n$idDiv");
      }
    }
    
    foreach my $e (@removedElements) {
      my $e2 = $e->toString(); $e2 =~ s/<\!\-\-.*?\-\->//sg; $e2 =~ s/[\s]+/ /sg; $e2 =~ s/.{60,80}\K(?=\s)/\n/sg;
      &Note("Removing: $e2\n");
    }
    
    if (&isBible($xml) && !$placedPeriphFile) {
      my $tst = @{$XPC->findnodes('.//*', $idDiv)}[0];
      my $tst2 = @{$XPC->findnodes('.//text()[normalize-space()]', $idDiv)}[0];
      if ($tst || $tst2) {
        &Error(
"The placement location for the following peripheral material was 
not specified and its position may be incorrect:
$idDiv
To position the above material, add location == <XPATH> after the \\id tag."
        );
        &Log(&placementMessage());
      }
      else {
        $idDiv->unbindNode();
        my $tg = $idDiv->toString(); $tg =~ s/>.*$/>/s;
        &Note("Removing empty div: $tg");
      }
    }
  }
  
  if (&isBible($xml)) {
    &Log("\nChecking sub-publication osisRefs in \"$$osisP\"\n", 1);
    # Check that all sub-publications are marked
    my $bookOrderP; &getCanon(&conf('Versification'), undef, \$bookOrderP, undef);
    foreach my $scope (@SUB_PUBLICATIONS) {
      if (!@{$XPC->findnodes('//osis:div[@type][@scope="'.$scope.'"]', $xml)}[0]) {
        &Warn("No div scope was found for sub-publication $scope.");
        my $firstbk = @{$XPC->findnodes('//osis:div[@type="book"][@osisID="'.@{&scopeToBooks($scope, $bookOrderP)}[0].'"]', $xml)}[0];
        if (!$firstbk) {next;}
        my $tocms = @{$XPC->findnodes('descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $firstbk)}[0];
        my $before = ($tocms ? $tocms->nextSibling:$firstbk->firstChild);
        my $div = $XML_PARSER->parse_balanced_chunk('<div type="introduction" scope="'.$scope.'" resp="'.$ROC.'"> </div>');
        $before->parentNode->insertBefore($div, $before);
        &Note("Added empty introduction div with scope=\"$scope\" within book ".$firstbk->getAttribute('osisID').' '.($tocms ? 'after TOC milestone.':'as first child.'));
      }
    }
  }

  &writeXMLFile($xml, $osisP);
}

sub findThisPeriph {
  my $parent = shift;
  my $left = shift;
  my $command = shift;
  
  my $type;
  my $subType;
  if ($left eq 'x-unknown') {$type = $left;}
  elsif (defined($PERIPH_TYPE_MAP{$left})) {
    $type = $PERIPH_TYPE_MAP{$left};
    $subType = $PERIPH_SUBTYPE_MAP{$left};
  }
  elsif (defined($PERIPH_TYPE_MAP_R{$left})) {$type = $left;}
  elsif (defined($PERIPH_SUBTYPE_MAP_R{$left})) {$type = "introduction"; $subType = $left;}
  else {
    &Error("Could not place periph! Unable to map $left to a div element in $command.");
    return '';
  }
  my $xpath = './/osis:div[@type="'.$type.'"]'.($subType ? '[@subType="'.$subType.'"]':'[not(@subType)]');
  my $periph = @{$XPC->findnodes($xpath, $parent)}[0];
  if (!$periph) {
    &Error("Could not place periph! Did not find \"$xpath\" in $command.");
    return '';
  }
  
  return $periph;
}

sub applyInstructions {
  my $div = shift;
  my $scope = shift;
  my $conversion = shift;
  my $feature = shift;
  
  my $sdiv = $div->toString(); $sdiv =~ s/(?<=\>).*$//s;
  
  if ($scope) {
    $div->setAttribute('scope', $scope);
    &Note("Applying scope='$scope' to $sdiv");
  }
  if ($conversion) {
    my @parts = split(/\s+/, $conversion);
    my $ok = !($conversion eq 'none' && @parts > 1); 
    foreach my $p (@parts) {if ($p !~ /^(sword|html|epub|none)$/) {$ok = 0;}}
    if ($ok) {
      $div->setAttribute('annotateRef', $conversion);
      $div->setAttribute('annotateType', $ANNOTATE_TYPE{'Conversion'});
      &Note("Applying annotateType='".$ANNOTATE_TYPE{'Conversion'}."' annotateRef='$conversion' to $sdiv");
    }
    else {
      &Error("Unrecognized peripheral instruction: conversion == $conversion", 
        "Only the following values are currently allowed: conversion == sword|html|epub|none");
    }
  }
  if ($feature) {
    $div->setAttribute('annotateRef', $feature);
    $div->setAttribute('annotateType', $ANNOTATE_TYPE{'Feature'});

    # The only 'feature' currently supported is 'INT' which uses translation
    # introductory material to auto-generate navmenus. INTMENU can be used 
    # to customize those menus.
    if ($feature =~ /^(INT)$/) {
      &Note("Applying annotateType='".$ANNOTATE_TYPE{'Feature'}."' annotateRef='$feature' to $sdiv");
    }
    elsif ($feature =~ /^(INTMENU)$/) {
      &Note("Applying annotateType='".$ANNOTATE_TYPE{'Feature'}."' annotateRef='$feature' to $sdiv");
      
      # Also set scope and osisID to that expected by navigationMenu.xsl
      $div->setAttribute('scope', 'NAVMENU');
      $div->setAttribute('osisID', 'uiIntroductionTopMenu');
      &Note("Applying osisID='uiIntroductionTopMenu' scope='NAVMENU' to $sdiv");
    }
    else {
      &Error("Unrecognized peripheral instruction: feature == $feature", 
        "The only currently supported value is: feature == (INT|INTMENU)");
    }
  }
}

# Insert $periph node before $beforeNode. But when $beforeNode is a toc 
# or runningHead element, then insert $periph before the following non-
# toc, non-runningHead node instead. The resulting $beforeNode is returned.
sub placeIntroduction {
  my $periph = shift;
  my $beforeNode = shift;

  # place as first non-toc and non-runningHead element in destination container
  while (@{$XPC->findnodes('
    ./self::text()[not(normalize-space())] | 
    ./self::osis:title[@type="runningHead"] | 
    ./self::osis:milestone[starts-with(@type, "x-usfm-toc")]
  ', $beforeNode)}[0]) {
    $beforeNode = $beforeNode->nextSibling();
  }
  $beforeNode->parentNode->insertBefore($periph, $beforeNode);
  
  return $beforeNode;
}

1;
