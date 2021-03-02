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
our ($XPC, $XML_PARSER, $ROC, %RESP, $ORDER_PERIPHS_COMPATIBILITY_MODE, 
    %ANNOTATE_TYPE, $ONS);
    

our (%ID_TYPE_MAP, %ID_TYPE_MAP_R, %PERIPH_TYPE_MAP, %PERIPH_TYPE_MAP_R, 
     %PERIPH_SUBTYPE_MAP, %PERIPH_SUBTYPE_MAP_R, 
     %USFM_DEFAULT_PERIPH_TARGET, @CONV_PUBS, @CONV_PUB_TYPES);

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
  The xpath values below select an element, or elements, before which a 
  peripheral will be placed. If multiple elements are selected a copy of
  the peripheral will be placed before each one. To remove a peripheral 
  entirely, the value "remove" (without the quotes) can be used.
  
  INSTRUCTION           ==    VALUE         APPLIES-TO
  location              == <xpath>|remove   The SFM file  
  <div type or subType> == <xpath>|remove   The next periph div with 
                                            that type/subType
  "<USFM periph type>"  == <xpath>|remove   The next periph having that 
                                            USFM type
  x-unknown             == <xpath>|remove   The next periph of any type
  
  BIBLES & DICTIONARIES
  These instructions will mark any periph divs which may follow in the 
  instruction list, and finally mark the id div itself, with a parti-
  cular processing instruction and value. Multiple values may be applied
  by separating each by a space. The value "remove" will cease that 
  particular marking instruction from being applied to the divs which 
  follow. For dictionaries, when there is an SFM file containing periph 
  tags, those periph divs can be marked differently than the id div 
  itself, using a Bible instruction above having the value "mark".
  
  INSTRUCTION ==  VALUE                      DESCRIPTION
  scope          == <a scope>|remove    The scope to which periphs apply
                                             
  conversion     == @CONV_PUBS|         Periphs should be included only 
                    @CONV_PUB_TYPES|    for the listed conversions
                    none|remove         
                    
  not_conversion == @CONV_PUBS|         Periphs should not be included
                    @CONV_PUB_TYPES|    in the listed conversions
                    remove
                    
  feature        == INT|INTMENU|remove  Periphs are part of the special  
                                        introduction feature 
                                        
  cover          == yes|no              Yes to add a sub-publication 
                                        cover to this div, or no to skip
                                        this div when auto-adding covers
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
  my %beforeNodes;
  foreach my $idDiv (@idDivs) {
    my $placedPeriphFile;
    my %mark = (
      'scope'          => undef, 
      'conversion'     => undef, 
      'not_conversion' => undef, 
      'feature'        => undef, 
      'cover'          => undef,
    );

    # read the first comment to find instructions, if any
    my $commentNode = @{$XPC->findnodes('child::node()[2][self::comment()]', $idDiv)}[0];

    my @removedDivs = ();
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
        
        if (exists($mark{$inst})) {
          $mark{$inst} = ($arg eq 'remove' ? undef:$arg);
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
        
        my $div = ( $inst eq 'location' ? 
                    $idDiv : 
                    &findThisPeriph($idDiv, $inst, $instruction)
                  );
        if (!$div) {next;} # error already given by findThisPeriph()
        
        if ($inst eq 'location') {$placedPeriphFile = 1;}
        else {$div->unbindNode();}
        
        if ($arg =~ /^mark$/i) {
          &applyInstructions($div, \%mark);
          next;
        }
        elsif ($arg =~ /^remove$/i) {
          push(@removedDivs, $div);
          next;
        }
        elsif ($placedPeriphFile > 1) {
          &Error(
"Cannot move a periph whose parent file has already been cloned in command $instruction",
"Move the 'location == <xpath>' portion of the command to the end 
of the \id tag's line. Or, change the xpath to a single placement, so
that cloning is no longer required.");
          next;
        }

        # All identical xpath searches must return the same originally 
        # found nodes. Otherwise sequential order would be reversed with 
        # insertBefore */node()[1].
        my $new;
        if (!ref($beforeNodes{$arg})) {
          my @a; $beforeNodes{$arg} = \@a;
          foreach ($XPC->findnodes('//'.$arg, $xml)) {
            push(@{$beforeNodes{$arg}}, $_);
            $new++;
          }
          if (!@{$beforeNodes{$arg}}) {
            &Error(
"Removing periph! Could not locate xpath:\"$arg\" in command $instruction");
            next;
          }
        }
        
        # The beforeNodes may be a toc or a runningHead etc., in which 
        # case an appropriate following-sibling will be used instead 
        # (and beforeNodes will be updated).
        my $placementAP = &placeElement($div, $beforeNodes{$arg}, $inst);
        
        my @beforeNodes;
        foreach my $e (@{$placementAP}) {
          push(@beforeNodes, $e->nextSibling);
          &applyInstructions($e, \%mark);
          &Note("Placing $inst == $arg for " . &printTag($e));
        }
        if ($new) {$beforeNodes{$arg} = \@beforeNodes;}
        
        # Once a file has been cloned, any further placement of 
        # descendant div's would result in duplicate content and will 
        # generate an error.
        if (@{$placementAP} > 1 && $inst eq 'location') {
          $placedPeriphFile = 2;
        }
      }
      &applyInstructions($idDiv, \%mark);
    }
    else {
      if (&isBible($xml)) {
        &Error("Removing periph(s)!", "You must specify the location where each peripheral file should be placed within the OSIS file.");
        &Log(&placementMessage());
        &Warn("REMOVED:\n$idDiv");
      }
    }
    
    foreach my $e (@removedDivs) {
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

sub printTag {
  my $elem = shift;
  
  my $tag = $elem->toString();
  $tag =~ s/(?<=\>).*$//s;
  $tag =~ s/<\/?default:/</g;
  $tag =~ s/\bxmlns(:default)?="[^"]*" ?//g;
  
  return $tag;
}

sub applyInstructions {
  my $div = shift;
  my $markP = shift;
  
  my $scope = shift;
  my $conversion = shift;
  my $feature = shift;
  
  my $sdiv = &printTag($div);

  my $valid = join('|', @CONV_PUBS, @CONV_PUB_TYPES, 'none');

  if ($markP->{'scope'}) {
    $div->setAttribute('scope', $markP->{'scope'});
    &Note("Applying scope='".$markP->{'scope'}."' to $sdiv");
  }
  foreach my $con ('conversion', 'not_conversion') {
    if ($markP->{$con}) {
      my @parts = split(/\s+/, $markP->{$con});
      my $ok = !($markP->{$con} eq 'none' && @parts > 1); 
      foreach my $p (@parts) {if ($p !~ /^($valid)$/) {$ok = 0;}}
      if ($ok) {
        $div->setAttribute('annotateRef', $markP->{$con});
        $div->setAttribute('annotateType', $ANNOTATE_TYPE{$con});
        &Note("Applying annotateType='".$ANNOTATE_TYPE{$con}.
          "' annotateRef='".$markP->{$con}."' to $sdiv");
      }
      else {
        &Error("Unrecognized peripheral instruction: conversion == ".$markP->{$con}, 
          "Only the following values are currently allowed: conversion == $valid");
      }
    }
  }
  if ($markP->{'feature'}) {
    $div->setAttribute('annotateRef', $markP->{'feature'});
    $div->setAttribute('annotateType', $ANNOTATE_TYPE{'Feature'});

    # The 'INT' feature uses translation introductory material to auto-
    # generate navmenus.
    if ($markP->{'feature'} =~ /^(INT)$/) {
      &Note("INT feature: Applying annotateType='".$ANNOTATE_TYPE{'Feature'}.
        "' annotateRef='".$markP->{'feature'}."' to $sdiv");
    }
    # The 'NAVMENU' feature allows replacement or modification of auto-
    # generated navigational menus.
    elsif ($markP->{'feature'} =~ /^\QNAVMENU./) {
      &Note("NAVMENU feature: Applying annotateType='".$ANNOTATE_TYPE{'Feature'}.
        "' annotateRef='".$markP->{'feature'}."' to $sdiv");
      $div->setAttribute('osisID', $markP->{'feature'}); # used by navigationMenu.xsl
    }
    else {
      &Error("Unrecognized peripheral instruction: feature == $markP->{'feature'}", 
        "The only currently supported value is: feature == (INT|INTMENU)");
    }
  }
  if ($markP->{'cover'}) {
    if ($markP->{'cover'} =~ /^(yes|no)$/i) {
      $div->setAttribute('annotateRef', lc($markP->{'cover'}));
      $div->setAttribute('annotateType', $ANNOTATE_TYPE{'cover'});
    }
    else {
      &Error("Unrecognized peripheral instruction cover value:".$markP->{'cover'},
      "The value can only be 'yes' or 'no'.");
    }
  }
}

# Insert $periph (or a clone thereof) before each $beforeNodesAP node. 
# But when a $beforeNode is a toc or runningHead element etc., then 
# insert the $periph before the following non-toc, non-runningHead node 
# instead. An array pointer containing each placed element is returned.
sub placeElement {
  my $periph = shift;
  my $beforeNodesAP = shift;
  
  my @elements;
  my $multiple;
  if (@{$beforeNodesAP} > 1) {
    $multiple = &oc_stringHash($periph->toString());
  }
  
  foreach my $beforeNode (@{$beforeNodesAP}) {
  
    # place as first non-toc and non-runningHead element in destination container
    while (@{$XPC->findnodes('
      ./self::comment() |
      ./self::text()[not(normalize-space())] | 
      ./self::osis:title[@type="runningHead"] | 
      ./self::osis:milestone[starts-with(@type, "x-usfm-toc")]
    ', $beforeNode)}[0]) {
      $beforeNode = $beforeNode->nextSibling();
    }
    
    my $element = ($multiple ? $periph->cloneNode(1) : $periph);
    
    if ($multiple) {$element->setAttribute('resp', "$RESP{'copy'}-$multiple");}
    
    $beforeNode->parentNode->insertBefore($element, $beforeNode);
    
    push(@elements, $element);
  }
  
  return \@elements;
}

1;
