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
our ($XPC, $XML_PARSER, $ROC, %RESP, 
    %ANNOTATE_TYPE, $ONS);
    

our (%ID_TYPE_MAP, %ID_TYPE_MAP_R, %PERIPH_TYPE_MAP, %PERIPH_TYPE_MAP_R, 
     %PERIPH_SUBTYPE_MAP, %PERIPH_SUBTYPE_MAP_R, %ID_DIRECTIVES,
     %USFM_DEFAULT_PERIPH_TARGET, @CONV_PUB_SETS);

my $AlreadyReportedThis;
sub placementMessage {
  if ($AlreadyReportedThis) {return;}
  $AlreadyReportedThis++;
  return &help('SFM ID DIRECTIVES', 1);
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
  &Note("Found ".@idDivs." special ID div elements."); 
  
  # For Bibles, remove all id divs, and add books to the list.
  if (&isBible($xml)) {
    foreach my $idDiv (@idDivs) {$idDiv->unbindNode();}
    my @bks = $XPC->findnodes('//osis:div[@type="book"]', $xml);
    &Note("Found ".@bks." book div elements.");
    push(@idDivs, @bks);
  }
  
  my $location = $ID_DIRECTIVES{'placement'}[0];
  
  # Handle each id div
  my %beforeNodes;
  foreach my $idDiv (@idDivs) {
    my ($placedParent, $markedParent);
    my %mark = map {$_ => undef} @{$ID_DIRECTIVES{'mark'}};

    # read the first comment to find instructions, if any
    my $commentNode = @{$XPC->findnodes('child::node()[2][self::comment()]', $idDiv)}[0];
    if ($commentNode) {
      &Note("Parsing comment of ".$idDiv->getAttribute('type').": ".$commentNode->textContent);
    }

    my @removedDivs = ();
    if ($commentNode && $commentNode->textContent =~ /\s\S+ == \S+/) {
      my $comment = $commentNode->textContent;
      #<!-- id comment - (FRT) scope="Gen", titlePage == osis:div[@type='book'], tableofContents == remove, preface == osis:div[@type='bookGroup'][1], preface == osis:div[@type='bookGroup'][1] -->
      $comment =~ s/\s*$//; # strip end stuff
      $comment =~ s/^(.*?)(?=\s(?:\S+|"[^"]+") ==)//;  # strip beginning stuff 
      my $start = $1;
      if ($start =~ /^\s*id comment\s*\-(.* = .*)$/) {
        &Warn(
"Dropping '$start' from ID directive.", 
'ID directives require \'==\' and not \'=\'. Did you mean to use \'==\' here?');
      }
      my @instr = split(/(,\s*(?:\S+|"[^"]+") == )/, ", $comment");
      
      # The final scope, script and feature values in the list will be applied to the container div
      for (my $x=1; $x < @instr; $x += 2) { # start at $x=1 because 0 is always just a leading comma
        my $instruction = @instr[$x] . @instr[($x+1)];
        $instruction =~ s/^,\s*//;
        if ($instruction !~ /^(\S+|"[^"]+") == (.*?)$/) {
          &Error("Unhandled location or scope assignment \"$instruction\" in \"$commentNode\" in CF_sfm2osis.txt");
          next;
        }
        my $inst = $1; my $arg = $2;
        $inst =~ s/(^"|"$)//g; # strip possible quotes
        $arg =~ s/(^"|"$)//g; # quotes are not expected here, but allow them
        
        if (exists($mark{$inst})) {
          $mark{$inst} = ($arg eq 'stop' ? undef:$arg);
          next;
        }
     
        my $div = ( $inst eq $location ? 
                    $idDiv : 
                    &findThisPeriph($idDiv, $inst, $instruction)
                  );
        if (!$div) {next;} # error already given by findThisPeriph()
        
        if ($inst eq $location) {$placedParent = 1;}
        else {$div->unbindNode();}
        
        if ($arg =~ /^mark$/i) {
          &applyMarks($div, \%mark);
          if ($inst eq $location) {$markedParent = 1;}
          next;
        }
        elsif ($arg =~ /^remove$/i) {
          push(@removedDivs, $div);
          next;
        }
        elsif ($placedParent > 1) {
          &Error(
"Cannot move a periph whose parent file has already been cloned in command $instruction",
"Move the 'location == <xpath>' portion of the command to the end 
of the \id tag's line. Or, change the xpath to a single placement, so
that cloning is no longer required.");
          next;
        }
        elsif ($inst eq $location && !&isBible($xml)) {
          &Error(
"Cannot move this non-Bible div using 'location'.",
"Change the order of RUN statements instead."          
          );
        }
        elsif ($inst eq $location && $idDiv->getAttribute('type') eq 'book') {
          &Error(
"Cannot move book div elements with ID directives.", 
"Use CustomBookOrder: ".&help('CustomBookOrder', 1));
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
        my $placementAP = &placeElement($div, $beforeNodes{$arg}, $arg);
        
        my @beforeNodes;
        foreach my $e (@{$placementAP}) {
          push(@beforeNodes, $e->nextSibling);
          &applyMarks($e, \%mark);
          &Note("Placing $inst == $arg for " . &printTag($e));
        }
        if ($new) {$beforeNodes{$arg} = \@beforeNodes;}
        
        # Once a file has been cloned, any further placement of 
        # descendant div's would result in duplicate content and will 
        # generate an error.
        if (@{$placementAP} > 1 && $inst eq $location) {
          $placedParent = 2;
        }
      }
      if (!$markedParent) {&applyMarks($idDiv, \%mark);}
    }
    else {
      if ($idDiv->getAttribute('type') ne 'book' && &isBible($xml)) {
        &Error(
"Removing periph(s)!", 
"You must specify the location where each peripheral file should be placed within the OSIS file. See: ".&help('sfm id directives'));
        &Log(&placementMessage());
        &Warn("REMOVED:\n$idDiv");
      }
    }
    
    foreach my $e (@removedDivs) {
      my $e2 = $e->toString(); $e2 =~ s/<\!\-\-.*?\-\->//sg; $e2 =~ s/[\s]+/ /sg; $e2 =~ s/.{60,80}\K(?=\s)/\n/sg;
      &Note("Removing: $e2\n");
    }
    
    if ($idDiv->getAttribute('type') ne 'book' && &isBible($xml) && !$placedParent) {
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
  if ($left eq 'x-unknown') {$type = 'x-unknown';}
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

sub applyMarks {
  my $div = shift;
  my $markP = shift;
  
  my $scope = shift;
  my $conversion = shift;
  my $feature = shift;
  
  my $sdiv = &printTag($div);

  my $valid = join('|', &PUB_TYPES(), @CONV_PUB_SETS, 
    'none', 'CF_addDictLinks', 'CF_addDictLinks.bible', 
    'CF_addDictLinks.dict');

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
        &Error("Unrecognized peripheral instruction: $con == ".$markP->{$con}, 
          "Only the following values are currently allowed: $con == $valid");
      }
    }
  }
  if ($markP->{'feature'}) {
    $div->setAttribute('annotateRef', $markP->{'feature'});
    $div->setAttribute('annotateType', $ANNOTATE_TYPE{'Feature'});
    
    # The 'NO_TOC' feature is for material which should not appear in any
    # TOC or NAVMENU.
    if ($markP->{'feature'} =~ /^(NO_TOC)$/) {
      &Note("NO_TOC feature: Applying annotateType='".$ANNOTATE_TYPE{'Feature'}.
        "' annotateRef='".$markP->{'feature'}."' to $sdiv");
    }
    # The 'INT' feature uses translation introductory material to auto-
    # generate navmenus.
    elsif ($markP->{'feature'} =~ /^(INT)$/) {
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
      &Note("cover: Applying annotateRef='".lc($markP->{'cover'}).
        "' annotateType='".$ANNOTATE_TYPE{'cover'}."' to $sdiv");
    }
    else {
      &Error("Unrecognized peripheral instruction cover value:".$markP->{'cover'},
      "The value can only be 'yes' or 'no'.");
    }
  }
}

# Insert the $div (or a clone thereof) before each $beforeNodesAP node. 
# But when the $xpath ends with /node()[1] and the result node is a toc, 
# runningHead, comment or empty text node, then insert the $div before 
# next sibling which is not one of those. An array pointer containing 
# the placed element(s) is returned.
sub placeElement {
  my $div = shift;
  my $beforeNodesAP = shift;
  my $xpath = shift;
  
  my @elements;
  my $multiple;
  if (@{$beforeNodesAP} > 1) {
    $multiple = &oc_stringHash($div->toString());
  }
  
  foreach my $beforeNode (@{$beforeNodesAP}) {
    if ($xpath =~ /(\/|child::)node\(\)\[1\]$/) {
      # place as first non-toc and non-runningHead sibling
      while (@{$XPC->findnodes('
        ./self::comment() |
        ./self::text()[not(normalize-space())] | 
        ./self::osis:title[@type="runningHead"] | 
        ./self::osis:milestone[starts-with(@type, "x-usfm-toc")]
      ', $beforeNode)}[0]) {
        $beforeNode = $beforeNode->nextSibling();
      }
    }
    
    my $element = ($multiple ? $div->cloneNode(1) : $div);
    
    if ($multiple) {$element->setAttribute('n', "[copy:$multiple]");}
    
    $beforeNode->parentNode->insertBefore($element, $beforeNode);
    
    push(@elements, $element);
  }
  
  return \@elements;
}

1;
