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

use strict;
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD);
our (@VSYS_INSTR, %RESP, %VSYS, $XPC, $XML_PARSER, %OSIS_ABBR, 
    %ANNOTATE_TYPE, $VSYS_INSTR_RE, $VSYS_PINSTR_RE, $VSYS_SINSTR_RE, 
    $VSYS_UNIVERSE_RE, @OSIS_GROUPS, %OSIS_GROUP, $OSIS_NAMESPACE, 
    $OSISBOOKSRE, @VERSE_SYSTEMS, $ONS, %ID_TYPE_MAP, 
    %ID_TYPE_MAP_R, %PERIPH_TYPE_MAP, %PERIPH_TYPE_MAP_R, 
    %PERIPH_SUBTYPE_MAP, %PERIPH_SUBTYPE_MAP_R, 
    %USFM_DEFAULT_PERIPH_TARGET);
    
our $VSYS_BOOKGRP_RE  = "(?<bg>".join('|', keys(%OSIS_GROUP)).")(\\[(?<pos>\\d+|$OSISBOOKSRE)\\])?";
our $VSYS_SINSTR_RE   = "(?<bk>$OSISBOOKSRE)\\.(?<ch>\\d+)(\\.(?<vs>\\d+))";
our $VSYS_INSTR_RE    = "(?<bk>$OSISBOOKSRE)\\.(?<ch>\\d+)(\\.(?<vs>\\d+)(\\.(?<vl>\\d+))?)?";
our $VSYS_PINSTR_RE   = "(?<bk>$OSISBOOKSRE)\\.(?<ch>\\d+)(\\.(?<vs>\\d+)(\\.(?<vl>\\d+|PART))?)?";
our $VSYS_UNIVERSE_RE = "(?<vsys>".join('|', @VERSE_SYSTEMS).")\:$VSYS_PINSTR_RE";


# OSIS-CONVERTERS VERSIFICATION SYSTEM:
# Special milestone markers are added to the OSIS file to facilitate 
# reference mapping between the source, fixed and fitted verse systems:
# source: The custom source verse system created by the translators. 
#         Because it is a unique and customized verse system, by itself 
#         there is no way to link its verses with external texts or 
#         cross-references.
# fixed:  A known, unchanging, verse system which is most similar to the 
#         source verse system. Because it is a known verse system, its 
#         verses can be linked to any other known external text or 
#         cross-reference.
# fitted: A fusion between the source and fixed verse systems arrived at 
#         by applying OSIS-CONVERTERS VERSIFICATION INSTRUCTIONS. The 
#         fitted verse system maintains the exact form of the custom verse 
#         system, but also exactly fits within the fixed verse system. The
#         resulting fitted verse system will have 'missing' verses or 
#         'extra' alternate verses appended to the end of a verse if there 
#         are differences between the source and fixed verse systems. 
#         These differences usually represent moved, split, or joined 
#         verses. The OSIS file can then be extracted in either the source 
#         or the fixed verse system in such a way that all internal and  
#         external reference hyperlinks are made correct and functional.
#         
# The fitted verse system requires that applicable reference links have 
# two osisRef attributes, one for the fixed verse system (osisRef) and 
# another for the source (annotateRef with annotateType = source). To 
# facilitate this, the following maps are provided:
# 1) fixed2Source: Given a verse in the fixed verse system, get the id of 
#    the source verse system verse which corresponds to it. This is needed 
#    to map a readable externally supplied cross-reference in the fixed 
#    verse system to the moved location in the source verse system. 
#    Example: A fixed verse system cross-reference targets Romans 14:24, 
#    but in the source verse system this verse is at Romans 16:25.
# 2) source2Fitted: Given a verse in the source verse system, get the id 
#    of the fitted (fixed verse system) verse which contains it. This is 
#    needed to map source references to their location in the fitted verse 
#    system. Example: Source verse Rom.16.25 might correspond to a 
#    different location in the fixed verse system, but in the fitted 
#    (fixed) verse system it is appended to the end of Rom.16.24 (the last 
#    verse of the fixed verse system's chapter).
# 3) fixed2Fitted: Given a verse in the fixed verse system, get the id of 
#    the fitted (also a fixed verse system) verse which contains it. This  
#    is used to map externally supplied cross-references for the fixed 
#    verse system to their actual location in the fitted verse system. 
#    Example: A fixed verse system cross-reference targets Rom.14.24, 
#    but in the fitted OSIS file, this verse is appended to the end of 
#    Rom.16.24. This is a convenience map since it is the same 
#    as source2Fitted{fixed2Source{verse}}
# 4) missing: If a fixed verse system verse is left out of the translation
#    and is not even included in a footnote, then there will be no cross
#    references pointing to it.


sub parseInstructionVSYS {
  my $t = shift;
 
  if ($t =~ /^VSYS_MISSING:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$value });
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>'' });
  }
  elsif ($t =~ /^VSYS_EXTRA:(?:\s*(?<to>$VSYS_INSTR_RE)\s*(?:<\-\s*(?<from>$VSYS_UNIVERSE_RE)\s*)?)?$/) {
    my $to = $+{to}; my $from = $+{from};
    push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
    if ($from) {
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'universal'=>$from, 'source'=>$to });
    }
  }
  elsif ($t =~ /^VSYS_FROM_TO:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)?\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
  }
  elsif ($t =~ /^VSYS_EMPTY:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>'' });
  }
  elsif ($t =~ /^VSYS_MOVED:(\s*(?<from>$VSYS_BOOKGRP_RE)\s*\->\s*bookGroup\[(?<to>\d+)\]\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    if ($+{pos}) {
      $from = $+{bg};
      &Error("VSYS_MOVED here does not need position: $+{from} in $t",
             "Just use '$from' or use another instruction.");
    }
    push(@VSYS_INSTR, { 'inst'=>'MOVED_BOOKGROUP', 'fixed'=>$from, 'position'=>$to });
  }
  elsif ($t =~ /^VSYS_MOVED:(\s*(?<from>$OSISBOOKSRE)\s*\->\s*(?<to>$VSYS_BOOKGRP_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to}; my $bg = $+{bg}; my $pos = $+{pos};
    if (!$pos) {
      $pos = 1;
      &Error("Cannot do VSYS_MOVED here without book position: $t",
             "Use '${bg}[X]' where X is the book number or abbreviation");
    }
    if ($+{ch} || $+{vs}) {
      $from = $+{ch};
      &Error("Cannot do VSYS_MOVED from part of a book: $t",
             "Use just '$from' or use another instruction.");
    }
    push(@VSYS_INSTR, { 'inst'=>'MOVED_BOOK', 'fixed'=>$from, 'bookGroup'=>$bg, 'position'=>$pos });
  }
  elsif ($t =~ /^VSYS_MOVED:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
    my $frbk = ($from =~ /$VSYS_PINSTR_RE/ ? $1:'');
    my $tobk = ($to   =~ /$VSYS_PINSTR_RE/ ? $1:'');
    if ($frbk eq $tobk) {
      push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
      push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
    }
    elsif ($from !~ /$VSYS_INSTR_RE/ || $to !~ /$VSYS_INSTR_RE/) {
      &Error(
"Cannot do VSYS_MOVED from a book to a different book with PART of a verse: $t",
"Remove '.PART' from the reference or use another instruction.");
    }
    else {
      push(@VSYS_INSTR, { 'inst'=>'MOVED', 'fixed'=>$from, 'source'=>$to });
    }
  }
  elsif ($t =~ /^VSYS_MOVED_ALT:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
    my $from = $+{from}; my $to = $+{to};
    push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
    push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
  }
  elsif ($t =~ /^VSYS_MISSING_FN:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
    my $value = $+{val};
    my $bk = $+{bk}; my $ch = $+{ch}; my $vs = $+{vs}; my $vl = ($+{vl} ? $+{vl}:$+{vs});
    my $msg = "VSYS_MISSING_FN is used when a previous verse holds a footnote about the missing verse.";
    if ($vs > 1) {
      push(@VSYS_INSTR, { 'inst'=>'VTAG_MISSING', 'fixed'=>$value, 'source'=>"$bk.$ch.".($vs-1).'.PART' });
    }
    else {&Error(
"VSYS_MISSING_FN cannot be used with verse $vs: $t", 
"$msg Use different instruction(s) in CF_sfm2osis.txt.");}
  }
  elsif ($t =~ /^VSYS_CHAPTER_SPLIT_AT:(?:\s*(?<val>$VSYS_SINSTR_RE)\s*)?$/) {
    my $value = $+{val};
    my $bk = $+{bk}; my $ch = $+{ch}; my $vs = $+{vs};
    push(@VSYS_INSTR, { 'inst'=>'CHAPTER_SPLIT_AT', 'fixed'=>$value });
  }
  elsif ($t =~ /^VSYS_/) {
    &Error("Unhandled VSYS instruction: $t");
  }
  
  return @VSYS_INSTR;
}

sub sortVsysInst {
  my $a = shift;
  my $b = shift;
  
  my $r;
  
  # EXTRA and MOVED modify source, while all others (which the exception of  
  # FROM_TO which is always last) modify fixed, so process EXTRA and MOVED first.
  my @order = ('EXTRA', 'MOVED', 'MISSING', 'CHAPTER_SPLIT_AT', 
        'VTAG_MISSING', 'MOVED_BOOK', 'MOVED_BOOKGROUP', 'FROM_TO');

  # order by instruction type
  my $ai; for ($ai=0; $ai<@order; $ai++) {if (@order[$ai] eq $a->{'inst'}) {last;}}
  my $bi; for ($bi=0; $bi<@order; $bi++) {if (@order[$bi] eq $b->{'inst'}) {last;}}
  if ($ai == @order || $bi == @order) {
    &ErrorBug("Unknown VSYS sub-instruction: '".$a->{'inst'}."' or '".$b->{'inst'}."'");
  }
  $r = $ai <=> $bi;
  if ($r) {return $r;}
  
  # otherwise use verse system order (using source if present otherwise fixed)
  my $av = ($a->{'source'} ? $a->{'source'}:$a->{'fixed'});
  my $bv = ($b->{'source'} ? $b->{'source'}:$b->{'fixed'});
  $av =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $av2 = ($2 ? (1*$3):0);
  $bv =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $bv2 = ($2 ? (1*$3):0);
  $r = &osisIDSort($av, $bv);
  if ($r) {return $r;}
  
  # otherwise by last verse
  $r = $av2 <=> $bv2;
  if ($r) {return $r;}

  if (!$r) {
    &ErrorBug("Indeterminent VSYS instruction sort: av=$av, bv=$bv, ai=$ai, bi=$bi");
  }
  return $r;
}

sub orderBooks {
  my $osisP = shift;
  my $vsys = shift;
  my $maintainBookOrder = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nOrdering books of \"$$osisP\" by versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&swordVsys($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Cannot re-order books in OSIS file because swordVsys($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);

  # remove all books
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bk (@books) {$bk->unbindNode();}

  # remove all peripheral file divs for now
  my @xpath;
  foreach my $type (values(%ID_TYPE_MAP)) {
    push(@xpath, '//osis:div[@type="'.$type.'"][not(@subType)]');
  }
  my @idDivs = $XPC->findnodes(join('|', @xpath), $xml);
  foreach my $idDiv (@idDivs) {$idDiv->unbindNode();}
  
  # create empty bookGroups
  my $osisText = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  foreach my $bg (@OSIS_GROUPS) {
    my $e = $osisText->addNewChild("http://www.bibletechnologies.net/2003/OSIS/namespace", 'div'); 
    $e->setAttribute('type', 'bookGroup');
    $e->setAttribute('osisID', $bg);
  }
  my @bookGroups = $XPC->findnodes('//osis:osisText/osis:div[@type="bookGroup"]', $xml);

  # Place books into SWORD versification's bookGroup and order (SWORD verse
  # systems only have two book groups: OT and NT).
  if ($maintainBookOrder) {
    # maintain original book order
    my $i = 0;
    foreach my $bk (@books) {
      my $bkname = $bk->findvalue('./@osisID');
      # Switch to NT bookGroup upon reaching the first NT book
      if ($i==0 && &defaultBookGroup($bkname) == 1) {$i = 1;}
      @bookGroups[$i]->appendChild($bk);
      $bk = '';
    }
  }
  else {
    # place all books back in canon order
    foreach my $v11nbk (@{$bookArrayP}) {
      if (!$v11nbk) {next;} # bookArrayP[0] is empty
      foreach my $bk (@books) {
        if (!$bk || $bk->findvalue('./@osisID') ne $v11nbk) {next;}
        my $i = ($testamentP->{$v11nbk} eq 'NT' ? 1:0);
        @bookGroups[$i]->appendChild($bk);
        $bk = '';
        last;
      }
    }
  }
  
  # Place any remaining books into default bookGroup and order
  my $n = -1;
  foreach my $bg (@OSIS_GROUPS) {
    $n++;
    if ($bg =~ /^(OT|NT)$/) {next;} # These are already populated in v11n order
    foreach my $bgbk (@{$OSIS_GROUP{$bg}}) {
      foreach my $bk (@books) {
        if (!$bk) {next;}
        my $bkn = $bk->getAttribute('osisID');
        if ($bkn ne $bgbk) {next;}
        &Warn(
"Book '$bkn' is a valid OSIS abbreviation, but is not part of
verse system '$vsys'.",
"This book will not appear in fixed verse system media such as 
SWORD unless you have used VSYS_MOVED to indicate where it was moved from.");
        @bookGroups[$n]->appendChild($bk);
        $bk = '';
      }
    }
  }
    
  # Drop any remaining books with an error
  foreach my $bk (@books) {
    if (!$bk) {next;}
    my $bkn = $bk->getAttribute('osisID'); 
    if ($bkn && defined($OSIS_ABBR{$bkn})) {
      &Error(
"Book '$bkn' occurred multiple times, so this instance was dropped!", 
"CF_sfm2osis.txt may have RUN this book multiple times.");
    }
    else {
      &Error(
"Book '$bkn' is an unrecognized OSIS book, so it was dropped!", 
"The id tag of the book's source SFM file may be incorrect.");
    }
  }
  
  foreach my $bookGroup (@bookGroups) {
    if (!$bookGroup->hasChildNodes()) {$bookGroup->unbindNode();}
  }
  
  # Replace all periphs after the header (they still need to be marked and ordered later)
  my $header = @{$XPC->findnodes('//osis:header', $xml)}[0];
  foreach my $idDiv (reverse @idDivs) {$header->parentNode->insertAfter($idDiv, $header);}
  
  &writeXMLFile($xml, $osisP);
}

sub applyVsysMissingVTagInstructions {
  my $osisP = shift;
  
  my $update;
  foreach my $argsP (@VSYS_INSTR) {
    if ($argsP->{'inst'} eq 'VTAG_MISSING') {$update++;}
  }
  if (!$update) {return;}
  
  &Log("\nApplying VSYS_MISSING_FN instructions to \"$$osisP\"\n", 1);
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  foreach my $argsP (@VSYS_INSTR) {
    if ($argsP->{'inst'} eq 'VTAG_MISSING') {
      &applyVsysMissingVTag($argsP, $xml);
    }
  }
  
  &writeXMLFile($xml, $osisP);
}

# Update an osis file's internal (source) and external (fixed) osisRefs 
# to the fitted verse system.
sub correctReferencesVSYS {
  my $osisP = shift;
  
  my $in_bible = ($INPD eq $MAININPD ? $$osisP:&getModuleOsisFile($MAINMOD));
  if (! -e $in_bible) {
    &Warn("No OSIS Bible file was found. References effected by VSYS instructions will not be corrected.");
    return;
  }
  &Log("\n\nUpdating osisRef attributes of \"$$osisP\" that require re-targeting after VSYS instructions:\n", 1);
  
  my $altVersesOSISP = &getAltVersesOSIS($XML_PARSER->parse_file($in_bible));
  
  # Process the OSIS file book-by-book for speed
  my ($count, %logH, $logn);
  foreach my $osisbk (&splitOSIS($$osisP)) {
    my $osisXML; my $filter;
    my $element = &splitOSIS_element($osisbk, \$osisXML, \$filter);
    if ($element) {&Log($element->getAttribute('osisID'), 2);}
    my $name_osisXML = &getOsisModName($osisXML);
    my @existing = $XPC->findnodes('descendant::osis:reference[@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"][@annotateRef][@osisRef]', $element);
    if (@existing) {next;}

    # Fill a hash table with every element that has an osisRef attribute,
    # except for x-vsys type elements. This technique provides a big 
    # speedup. The internal origin is for elements originating in the  
    # source text. The external origin is for elements originating outside 
    # the source text (which have the fixed verse system).
    my %elems;
    &Log(", finding osisRefs", 2);
    foreach my $e (@{$XPC->findnodes("descendant-or-self::*${filter}[\@osisRef]
        [not(starts-with(\@type, '".$VSYS{'prefix_vs'}."'))]", $element)})
    {
      my $origin = (
        @{$XPC->findnodes('ancestor-or-self::osis:note[@type="crossReference"][@resp]', $e)}[0] ? 
        'external':'internal'
      );
      my $ids = &osisRef2osisID($e->getAttribute('osisRef'), $name_osisXML, 'always');
      foreach my $id (split(/\s+/, $ids)) {
        my $w = ($id =~ s/^([^:]+):// ? $1:'');
        if ($w ne $MAINMOD) {next;}
        push(@{$elems{$id}{$origin}}, $e);
      }
    }
    
    &Log(", mapping osisRefs", 2);
    
    # Perform each mapping function on the applicable elements
    my @maps = ('source2Fitted', 'fixed2Fitted', 'fixed2Source', 'fixedMissing');
    # A hash is used for temporary attributes rather than actual element 
    # attributes in the tree, which buys another speedup.
    my %attribs; 
    foreach my $m (@maps) {
      foreach my $idmap (&normalizeOsisID([ sort keys(%{$altVersesOSISP->{$m}}) ])) {
        my $id = $idmap; $id =~ s/\.PART$//;
        my $origin = ($m =~ /^fixed/ ? 'external':'internal');
        foreach my $e (@{$elems{$id}{$origin}}) {
          my $eky = $e->unique_key;
          if (!defined($attribs{$eky})) {
            my $ids = &osisRef2osisID($e->getAttribute('osisRef'), $MAINMOD, 'not-default');
            $attribs{$eky}{'self'} = $e;
            $attribs{$eky}{'origin'} = $origin;
            $attribs{$eky}{'osisRefFrom'} = $ids;
            $attribs{$eky}{'osisRefTo'} = '';
            $attribs{$eky}{'annotateRefFrom'} = $ids;
            $attribs{$eky}{'annotateRefTo'} = '';
            $attribs{$eky}{'order'} = sprintf('%07i', $logn++);
          }
          # map each id segment one at a time
          my $attrib = ($m eq 'fixed2Source' ? 'annotateRef':'osisRef');
          &attribFromTo($attrib, \%{$attribs{$eky}}, $idmap, $altVersesOSISP->{$m}{$idmap});
          # in addition, apply fixedMissing to annotateRef (as well as to osisRef) 
          if ($m eq 'fixedMissing') {
            &attribFromTo('annotateRef', \%{$attribs{$eky}}, $idmap, $altVersesOSISP->{$m}{$idmap});
          }
        }
      }
    }
    #&Debug("attribs = ".Dumper(\%attribs)."\n", 1);
    
    $count += &applyMaps(\%attribs, $name_osisXML, \%logH);

    &writeXMLFile($osisXML, $osisbk);
  }
  &joinOSIS($osisP);
  
  # Logging these with a sorted hash so reports are in OSIS order
  my ($update, $remove);
  foreach my $k (sort keys %logH) {
    if (defined($logH{$k}{'update'})) {$update .= $logH{$k}{'update'};}
    if (defined($logH{$k}{'remove'})) {$remove .= $logH{$k}{'remove'};}
  }
  if ($update) {&Note("\n$update");}
  if ($remove) {&Note("\n$remove");}
    
  &Report("\"$count\" osisRefs were corrected to account for differences between source and fixed verse systems.");
}

sub attribFromTo {
  my $attrib = shift;
  my $attribHP = shift;
  my $id = shift;
  my $to = shift;
  
  if ($id !~ s/\!PART$//) {
    $attribHP->{$attrib.'From'} = &removeSeg($attribHP->{$attrib.'From'}, $id);
  }
  
  if ($to) {
    $to =~ s/\!PART$//;
    $attribHP->{$attrib.'To'} = &addSeg($attribHP->{$attrib.'To'}, $to);
  }
}

sub removeSeg {
  my $id = shift;
  my $seg = shift;
  
  my @segs;
  foreach my $s (split(/\s+/, $id)) {
    if ($s eq $seg) {next;}
    push(@segs, $s);
  }
  
  return join(' ', @segs);
}

sub addSeg {
  my $id = shift;
  my $seg = shift;
  
  my @segs = split(/\s+/, $id);
  if ($seg) {push (@segs, $seg);}
  
  return join(' ', @segs);
}

sub applyMaps {
  my $attribsHP = shift;
  my $modname = shift;
  my $logHP = shift;
  
  &Log(", applying maps\n", 2);
  
  my $count = 0;
  foreach my $eky (sort keys %{$attribsHP}) {
    my $e = $attribsHP->{$eky}{'self'};

    # get new values for permanent attributes
    our ($osisRef, $annotateRef); # symbolic references must be globals
    foreach my $a ('osisRef', 'annotateRef') {
      my @segs;
      my $value = $attribsHP->{$eky}{$a.'From'}.' '.$attribsHP->{$eky}{$a.'To'};
      push(@segs, (split(/\s+/, $value)));
      my $x1 = join(' ', &normalizeOsisID(\@segs, $MAINMOD, 'not-default'));
      my $x2 = &osisID2osisRef($x1);
      no strict "refs";
      $$a = &fillGapsInOsisRef($x2);
    }
    
    # don't keep references to missing verses (which would be broken)
    if (!$annotateRef || !$osisRef) {
      $logHP->{ $attribsHP->{$eky}{'order'} }{'remove'} = 
        &removeMappedElement($e, $attribsHP->{$eky}{'origin'});
      next;
    }
    
    if ($modname ne $MAINMOD) {
      $osisRef     = "$MAINMOD:$osisRef";
      $annotateRef = "$MAINMOD:$annotateRef";
    }
   
    if ($e->getAttribute('osisRef') eq $osisRef && $osisRef eq $annotateRef) {
      next;
    }
    
    $count++;
    
    $logHP->{ $attribsHP->{$eky}{'order'} }{'update'} = sprintf(
      "UPDATING %s %-10s osisRef: %32s -> %-32s annotateRef: %-32s\n", 
      $attribsHP->{$eky}{'origin'}, 
      $e->nodeName, 
      $e->getAttribute('osisRef'), 
      $osisRef, 
      $annotateRef
    );
    $e->setAttribute('osisRef', $osisRef);
    $e->setAttribute('annotateRef', $annotateRef);
    $e->setAttribute('annotateType', $ANNOTATE_TYPE{'Source'});
  }
  
  return $count;
}

sub removeMappedElement {
  my $e = shift;
  my $origin = shift;
  
  my $delete = ($origin eq 'external');
  my $tag = &pTag($e);
  
  my $msg = '';
  if ($delete) {
    $msg = "DELETING $origin ".$e->nodeName.", because osisRef targets missing verse: $tag\n";
  }
  else {
    $msg = "REMOVING tags for $origin ".$e->nodeName.", because osisRef targets missing verse: $tag \n";
    foreach my $chld ($e->childNodes) {$e->parentNode()->insertBefore($chld, $e);}
  }
  $e->unbindNode();
  
  return $msg;
}

sub getAltVersesOSIS {
  my $mod = &getOsisModName(shift);
  
  our %DOCUMENT_CACHE;
  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    &ErrorBug("getAltVersesOSIS: No xml document node!");
    return '';
  }
  
  if (!$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}) {
    $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'exists'}++;
    &Debug("Cache failed for getAltVersesOSIS: $mod\n");
    
    # VSYS changes are recorded in the OSIS file with milestone elements written by applyVsysFromTo()
    my @maps = (
      ['fixed2Source',  'movedto_vs', 'osisRef',     'annotateRef'],
      ['fixedMissing',  'missing_vs', 'osisRef',     ''],
      ['source2Fitted', 'fitted_vs',  'annotateRef', 'osisRef'],
    );
    foreach my $map (@maps) {
      my %hash;
      foreach my $e ($XPC->findnodes('//osis:milestone[@type="'.$VSYS{@$map[1]}.'"]', $xml)) {
        $hash{$e->getAttribute(@$map[2])} = (@$map[3] ? $e->getAttribute(@$map[3]):'');
      }
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{@$map[0]} = \%hash;
    }
    
    # fixed2Fitted is a convenience map since it is the same as source2Fitted{fixed2Source{verse}}
    foreach my $fixed (sort keys (%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}})) {
      my $source = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Source'}{$fixed};
      $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'fixed2Fitted'}{$fixed} = $DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}{'source2Fitted'}{$source};
    }
    
    &Debug("getAltVersesOSIS = ".Dumper(\%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}})."\n", 1);
  }
  
  return \%{$DOCUMENT_CACHE{$mod}{'getAltVersesOSIS'}};
}

sub fitToVerseSystem {
  my $osisP = shift;
  my $vsys = shift;
  
  if (!$vsys) {$vsys = "KJV";}

  &Log("\nFitting OSIS \"$$osisP\" to versification $vsys\n", 1);

  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  if (!&swordVsys($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP)) {
    &ErrorBug("Not Fitting OSIS versification because swordVsys($vsys) failed.");
    return;
  }

  my $xml = $XML_PARSER->parse_file($$osisP);
  
  # Check if this osis file has already been fitted, and bail if so
  my @existing = $XPC->findnodes('//osis:milestone[@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"]', $xml);
  if (@existing) {
    &Warn("
There are ".@existing." fitted tags in the text. This OSIS file has 
already been fitted so this step will be skipped!");
    return;
  }
  
  # Warn that these alternate verse tags in source could require further VSYS intructions
  my @nakedAltTags = $XPC->findnodes('//osis:hi[@subType="x-alternate"]
    [ not(preceding::*[1][self::osis:milestone[starts-with(@type, "'.$VSYS{'prefix_vs'}.'")]]) ]', $xml);
  if (@nakedAltTags) {
    &Warn("The following alternate verse tags were found.",
"If these represent verses which normally appear somewhere else in the 
$vsys verse system, then a VSYS_MOVED_ALT instruction should be 
added to CF_sfm2osis.txt to allow correction of external cross-
references:");
    foreach my $at (@nakedAltTags) {
      my $verse = @{$XPC->findnodes('preceding::osis:verse[@sID][1]', $at)}[0];
      &Log($verse." ".$at."\n");
    }
  }
  
  if (@VSYS_INSTR) {
  
    # Mark alternate verse numbers which represent the fitted verse system so they can be removed when using the fitted OSIS file
    foreach my $a ($XPC->findnodes('//osis:hi[@subType="x-alternate"]', $xml)) {
      my $prevVerseFirstTextNode = @{$XPC->findnodes('preceding::osis:verse[@sID][1]/following::text()[normalize-space()][1]', $a)}[0];
      my $myTextNode = @{$XPC->findnodes('descendant::text()[normalize-space()][1]', $a)}[0];
      if (!$prevVerseFirstTextNode || !$myTextNode || 
          $prevVerseFirstTextNode->unique_key ne $myTextNode->unique_key) {next;}
      $a->setAttribute('subType', $VSYS{'fixed_altvs'}.&conf('Versification'));
    }
    
    # Apply VSYS instructions to the translation
    foreach my $argsP (@VSYS_INSTR) {
      if ($argsP->{'inst'} eq 'VTAG_MISSING') {next;}
      &applyVsysInstruction($argsP, $canonP, $xml);
    }
    
    # Sort bookGroups and books to place position milestones
    foreach ($XPC->findnodes('//osis:osisText', $xml)) {
      &sortChildrenFixed($_);
    }
    foreach ($XPC->findnodes('//osis:div[@type="bookGroup"]', $xml)) {
      &sortChildrenFixed($_);
    }
    
    # Update scope in the OSIS file
    my $scopeElement = @{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[child::osis:type[@type="x-bible"]]/osis:scope', $xml)}[0];
    if ($scopeElement) {&changeNodeText($scopeElement, &getScopeXML($xml));}
    
    &writeXMLFile($xml, $osisP);
    $xml = $XML_PARSER->parse_file($$osisP);
  }
}

sub applyVsysInstruction {
  my $argP = shift;
  my $canonP = shift;
  my $xml = shift;
  
  my $inst = $argP->{'inst'};
  
  if ($inst eq 'MOVED_BOOKGROUP') {
    &Log("\nVSYS_".$argP->{'inst'}.": fixed=".$argP->{'fixed'}.", position=".$argP->{'position'}."\n");
    &applyVsysMovedBookGroup($argP->{'fixed'}, $argP->{'position'}, $xml);
    return 1;
  }
  if ($inst eq 'MOVED_BOOK') {
    &Log("\nVSYS_".$argP->{'inst'}.": fixed=".$argP->{'fixed'}.", bookGroup=".$argP->{'bookGroup'}.", position=".$argP->{'position'}."\n");
    &applyVsysMovedBook($argP->{'fixed'}, $argP->{'bookGroup'}, $argP->{'position'}, $xml);
    return 1;
  }
  
  &Log("\nVSYS_".$argP->{'inst'}.": fixed=".$argP->{'fixed'}.", source=".$argP->{'source'}.($argP->{'universal'} ? ", universal=".$argP->{'universal'}:'')."\n");
  
  # NOTE: 'fixed' always refers to a known fixed verse system, 
  # and 'source' always refers to the customized source verse system
  my $sourceP = ''; my $fixedP = '';
  if ($argP->{'source'}) {
    $sourceP = &parseVsysArgument($argP->{'source'},    $xml, 'source');
  }
  if ($argP->{'fixed'}) {
    $fixedP  = &parseVsysArgument($argP->{'fixed'},     $xml, 'fixed');
  }
  elsif ($argP->{'universal'}) {
    $fixedP  = &parseVsysArgument($argP->{'universal'}, $xml, 'universal');
  }
  
  if ($fixedP && $sourceP &&
      defined($fixedP->{'count'}) && defined($sourceP->{'count'}) &&
      $fixedP->{'count'} != $sourceP->{'count'}) {
    &Error("'From' and 'To' are a different number of verses: ${inst}: $fixedP->{'value'}($fixedP->{'count'}) -> $sourceP->{'value'}($sourceP->{'count'})");
    return 0;
  }
  
  if ($sourceP && $sourceP->{'bk'} && !&getOsisBooks($xml)->{$sourceP->{'bk'}}) {
    &Warn("Skipping VSYS_$inst because ".$sourceP->{'bk'}." is not in the OSIS file.", "Is this instruction correct?");
    return 0;
  }
  
  if    ($inst eq 'MISSING') {&applyVsysMissing($fixedP, $xml);}
  elsif ($inst eq 'EXTRA')   {&applyVsysExtra($sourceP, $canonP, $xml);}
  elsif ($inst eq 'FROM_TO') {&applyVsysFromTo($fixedP, $sourceP, $xml);}
  elsif ($inst eq 'CHAPTER_SPLIT_AT') {&applyVsysChapterSplitAt($fixedP, $xml);}
  elsif ($inst eq 'MOVED')   {&applyVsysMoved($fixedP, $sourceP, $xml);}
  else {&ErrorBug("Unhandled instruction: $inst");}
  
  return 1;
}

sub parseVsysArgument {
  my $value = shift;
  my $xml = shift;
  my $vsysType = shift;
  
  my %data;
  $data{'value'} = $value;

  # read and preprocess value
  my $bk; my $ch; my $vs; my $vl;
  if ($vsysType eq 'universal') {
    if ($value !~ /^$VSYS_UNIVERSE_RE$/) {
      &ErrorBug("parseVsysArgument: Could not parse universal: $value !~ /^$VSYS_UNIVERSE_RE\$/");
      return \%data;
    }
    $data{'vsys'} = $1;
    $bk = $2; $ch = $3; 
    if (defined($4)) {$vs = $5;}
    if (defined($5)) {$vl = $7;}
    my $vsre = join('|', @VERSE_SYSTEMS);
    if ($data{'vsys'} !~ /^($vsre)$/) {
      &Error(
"parseVsysArgument: Unrecognized verse system: '".$data{'vsys'}."'", 
"Use a recognized SWORD verse system: ".join(', ', @VERSE_SYSTEMS));
    }
  }
  else {
    if ($value !~ /^$VSYS_PINSTR_RE$/) {
      &ErrorBug("parseVsysArgument: Could not parse: $value !~ /^$VSYS_PINSTR_RE\$/");
      return \%data;
    }
    $data{'vsys'} = ($vsysType eq 'source' ? 'source':($vsysType eq 'fixed' ? &getOsisVersification($xml):''));
    $bk = $+{bk}; $ch = $+{ch};
    if (defined($+{vs})) {$vs = $+{vs};}
    if (defined($+{vl})) {$vl = $+{vl};}
  }
  
  $data{'isPartial'} = ($vl =~ s/^PART$/$vs/ ? 1:0);
  $data{'isWholeChapter'} = &isWholeVsysChapter($bk, $ch, \$vs, \$vl, $data{'vsys'}, $xml);

  $data{'bk'} = $bk;
  $data{'ch'} = (defined($ch) ? (1*$ch) : undef);
  $data{'vs'} = (defined($vs) ? (1*$vs) : undef);
  $data{'vl'} = (defined($vl) ? (1*$vl) : $vs);
  $data{'count'} = (defined($data{'vs'}) ? 1 + $data{'vl'} - $data{'vs'}:undef); 

  return \%data
}

# This does not modify any verse tags. It only inserts milestone markers
# which later can be used to map Scripture references between the source
# and known fixed verse systems. For all VSYS markup, osisRef always 
# refers to the xml file's fixed verse system. But annotateRef may refer 
# to a source verse system osisID or to a universal address (depending 
# on annotateType = x-vsys-source or x-vsys-universal). 
# Types of milestones inserted are:
# $VSYS{'movedto_vs'}, $VSYS{'missing_vs'}, $VSYS{'extra_vs'} and $VSYS{'fitted_vs'} 
sub applyVsysFromTo {
  my $fixedP = shift;
  my $sourceP = shift;
  my $xml = shift;
  
  if (!$fixedP) {
    &ErrorBug("fixedP should not be empty");
    return;
  }
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'}; my $vl = $fixedP->{'vl'};
  
  my $note = "";
  
  # If the fixed vsys is universal (different than $xml) then just insert 
  # extra_vs and fitted_vs marker(s) after the element(s) and return
  if ('Bible.'.$fixedP->{'vsys'} ne &getOsisRefSystem($xml)) {
    if ($sourceP->{'isWholeChapter'}) {
      my $xpath = '//*
        [@type="'.$VSYS{'prefix_vs'}.'-chapter'.$VSYS{'end_vs'}.'"]
        [@annotateType="'.$ANNOTATE_TYPE{'Source'}.'"]
        [@annotateRef="'.$sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'"][1]';
      my $sch = @{$XPC->findnodes($xpath, $xml)}[0];
      if ($sch) {
        my $osisID = @{$XPC->findnodes('./preceding::osis:verse[@sID][1]', $sch)}[0];
        if (!$osisID) {&ErrorBug("Could not find enclosing verse for element:\n".$sch);}
        else {$osisID = $osisID->getAttribute('osisID');}
        my $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                  'resp="'.$RESP{'vsys'}.'" ' .
                  'type="'.$VSYS{'extra_vs'}.'" '.
                  'annotateRef="'.$fixedP->{'value'}.'" ' .
                  'annotateType="'.$ANNOTATE_TYPE{'Universal'}.'" />'.
                '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                  'resp="'.$RESP{'vsys'}.'" ' .
                  'type="'.$VSYS{'fitted_vs'}.'" '.
                  'osisRef="'.$osisID.'" ' .
                  'annotateRef="'.$sourceP->{'value'}.'" ' .
                  'annotateType="'.$ANNOTATE_TYPE{'Source'}.'" />';
        $sch->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $sch);
        $note .= "[extra_vs chapter ".$sourceP->{'ch'}."][fitted_vs chapter ".$sourceP->{'ch'}."]";
      }
      else {&ErrorBug("Could not find source element:\n$xpath");}
    }
    else {
      for (my $v=$sourceP->{'vs'}; $v<=$sourceP->{'vl'}; $v++) {
        my $sourcevs = $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.$v;
        my $svs = &getSourceVerseTag($sourcevs, $xml, 1);
        if ($svs) {
          my $osisID = @{$XPC->findnodes('./preceding::osis:verse[@sID][1]', $svs)}[0];
          if (!$osisID) {&ErrorBug("Could not find enclosing verse for source verse: ".$sourcevs);}
          else {$osisID = $osisID->getAttribute('osisID'); $osisID =~ s/^.*\s+//;}
          my $univref = $fixedP->{'vsys'}.':'.$fixedP->{'bk'}.'.'.$fixedP->{'ch'}.'.'.($fixedP->{'vs'} + $v - $sourceP->{'vs'});
          my $m = '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                    'resp="'.$RESP{'vsys'}.'" ' .
                    'type="'.$VSYS{'extra_vs'}.'" '.
                    'annotateRef="'.$univref.'" ' .
                    'annotateType="'.$ANNOTATE_TYPE{'Universal'}.'" />'.
                  '<milestone xmlns="'.$OSIS_NAMESPACE.'" ' .
                    'resp="'.$RESP{'vsys'}.'" ' .
                    'type="'.$VSYS{'fitted_vs'}.'" '.
                    'osisRef="'.$osisID.'" ' .
                    'annotateRef="'.$sourceP->{'value'}.'" ' .
                    'annotateType="'.$ANNOTATE_TYPE{'Source'}.'" />';
          $svs->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $svs);
          $note .= "[extra_vs verse $v][fitted_vs verse $v]";
        }
        else {&ErrorBug("Could not find source verse: $sourcevs");}
      }
    }
    &Note("universal vsys ".$fixedP->{'vsys'}.":$note");
    
    return;
  }
  
  for (my $v=$vs; $v<=$vl; $v++) {
    my $baseAnnotateRef = ($sourceP ? $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.($sourceP->{'vs'} + $v - $vs):'');
    my $annotateRef = $baseAnnotateRef;
    if ($sourceP && $sourceP->{'isPartial'}) {$annotateRef .= "!PART";}
    
    # Insert a movedto or missing marker at the end of the verse
    my $fixedVerseEnd = &getVerseTag("$bk.$ch.$v", $xml, 1);
    if (!$fixedVerseEnd) {
      &ErrorBug("Could not find FROM_TO verse $bk.$ch.$v");
      next;
    }
    my $type = (!$sourceP ? 'missing_vs':'movedto_vs');
    my $osisRef = "$bk.$ch.$v";
    if ($fixedP->{'isPartial'}) {$osisRef .= "!PART";}
    my $m = "<milestone $ONS " .
            "resp='$RESP{'vsys'}' " .
            "type='$VSYS{$type}' " .
            "osisRef='$osisRef' ";
    if ($annotateRef) {$m .= 'annotateRef="'.$annotateRef.'" annotateType="'.$ANNOTATE_TYPE{'Source'}.'" ';}
    $m .= '/>';
    $fixedVerseEnd->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $fixedVerseEnd);
    $note .= "[$type verse $v]";
    
    if (!$sourceP) {next;}
    
    # Insert a fitted milestone at the end of the source alternate 
    # verse, unless the source destination is empty. The alternate verse 
    # is either a milestone verse end (if the source was originally a 
    # regular verse) or else a hi with subType=x-alternate (if it was 
    # originally an alternate verse).
    my $altVerseEnd = &getSourceVerseTag($baseAnnotateRef, $xml, 1);
    if (!$altVerseEnd) {
      $altVerseEnd = &getSourceAltVerseTag($baseAnnotateRef, $xml, 1);
    }
    if (!$altVerseEnd) {
      &Warn("Could not find FROM_TO destination alternate verse $baseAnnotateRef");
      next;
    }
    $osisRef = @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $altVerseEnd)}[0];
    if (!$osisRef || !$osisRef->getAttribute('osisID')) {
      &ErrorBug("Could not find FROM_TO destination verse osisID: ".($osisRef ? 'no osisID':'no verse'));
      next;
    }
    $osisRef = $osisRef->getAttribute('osisID');
    $osisRef =~ s/^.*?\s+(\S+)$/$1/;
    $m = "<milestone $ONS " .
         "resp='$RESP{'vsys'}' " . 
         "type='$VSYS{'fitted_vs'}' " .
         "osisRef='$osisRef' " .
         "annotateRef='$annotateRef' " .
         "annotateType='$ANNOTATE_TYPE{'Source'}'/>";
    $altVerseEnd->parentNode->insertBefore($XML_PARSER->parse_balanced_chunk($m), $altVerseEnd);
    $note .= "[fitted_vs verse $v]";
  }
}

# Find the source verse system verse tag (a milestone) associated with 
# an alternate $vid. Failure returns nothing.
sub getSourceVerseTag {
  my $vid = shift;
  my $xml = shift;
  my $isEnd = shift;
  
  my @svts = $XPC->findnodes('//*[@type="'.$VSYS{'prefix_vs'}.'-verse'.($isEnd ? $VSYS{'end_vs'}:$VSYS{'start_vs'}).'"]', $xml);
  foreach my $svt (@svts) {
    my $ref = $svt->getAttribute('annotateRef');
    foreach my $idp (split(/\s+/, &osisRef2osisID($ref))) {
      if ($idp eq $vid) {return $svt;}
    }
  }
  return '';
}

# Find the source verse system alternate verse tag associated with an
# alternate $vid. Failure returns nothing. Beware that this requires
# an alternate verse number which is the source verse system's verse 
# number BUT translators sometimes use the fixed verse system's number 
# for the alternate verse number instead, in which case this will not 
# find the desired verse.
sub getSourceAltVerseTag {
  my $vid = shift;
  my $xml = shift;
  my $isEnd = shift;
  
  if ($vid !~ /^([^\.]+)\.([^\.]+)\.([^\.]+)$/) {
    &ErrorBug("Could not parse $vid !~ /^([^\.]+)\.([^\.]+)\.([^\.]+)\$/");
    return '';
  }
  my $bk = $1; my $ch = $2; my $vs = $3;
  my @altsInChapter = $XPC->findnodes(
    '//osis:div[@type="book"][@osisID="'.$bk.'"]//osis:hi[@subType="x-alternate"]'.
    '[preceding::osis:chapter[1][@sID="'.$bk.'.'.$ch.'"]]'.
    '[following::osis:chapter[1][@eID="'.$bk.'.'.$ch.'"]]', $xml);
  foreach my $alt (@altsInChapter) {
    if ($alt->textContent !~ /\b$vs\w?\b/) {next;}
    if (!$isEnd) {return $alt;}
    my $end = @{$XPC->findnodes('following::*[ancestor::osis:div[@osisID="'.$bk.'"]]
        [self::osis:verse[@eID][1] or self::osis:hi[@subType="x-alternate"][1] or self::milestone[@type="'.$VSYS{'prefix_vs'}.'verse'.$VSYS{'end_vs'}.'"][1]]
        [1]', $alt)}[0];
    if ($end) {return $end;}
    &ErrorBug("Could not find end of $alt");
  }
  
  return '';
}

# Used when a range of verses in the fixed verse system was, or is to be 
# moved from another book in the source verse system. Markup is added at 
# both locations to facilitate easy destination selection via XSLT:
# - Moved elements are located and enclosed by a marked div. Element(s) 
#   within the div could be a verse or verses, up to a whole chapter.
#   If the div is not already in its fixed verse system location,
#   then it is moved there.
# - Empty fixed verse system elements are created only when necessary: 
#   bookGroup div, book div and chapter tags (unless they already exist). 
#   These elements will be removed when the source verse system is 
#   extracted from the resulting OSIS file.
# - A source target milestone-div is placed to designate where the div con-
#   taining the fixed element(s) will be moved when the OSIS file is
#   rendered as source.
sub applyVsysMoved {
  my $fixedP = shift;
  my $sourceP = shift;
  my $xml = shift;
  
  if (!$fixedP || !$sourceP) {return;}
  
  my $bk = $sourceP->{'bk'};
  my $ch = $sourceP->{'ch'};
  my $vs = $sourceP->{'vs'};
  my $vl = $sourceP->{'vl'};
  
  # Find the first chapter/verse start tag and the last chapter/verse end tag
  my $es = ( $sourceP->{'isWholeChapter'} ? 
      @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0] :
      &getVerseTag("$bk.$ch.$vs", $xml) );
  my $el = ( $sourceP->{'isWholeChapter'} ? 
      @{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0] :
      &getVerseTag("$bk.$ch.$vl", $xml, 1) );
  if (!$es || !$el) {
    &Error("Could not find start and end elements: '$es' '$el'",
    "Check the VSYS_MOVED instructions.");
  }
  
  # Adjust first element to include pre-verse/chapter title(s)
  my $pre = @{$XPC->findnodes('preceding::*[1]', $es)}[0];
  while ($pre && $pre->localname eq 'title') {
    $es = $pre;
    $pre = @{$XPC->findnodes('preceding::*[1]', $pre)}[0];
  }
  my $esp = $es->parentNode;
  if ($esp->localname eq 'div' && 
      @{$XPC->findnodes('child::*[1]', $esp)}[0]->unique_key eq $es->unique_key) {
    $es = $esp;
  }
  
  # If first element is within section container(s), truncate so it's not
  my $con = @{$XPC->findnodes('ancestor::osis:div[contains(@type, "ection")][last()]', $es)}[0];
  if ($con) {&truncateAt($con, $es);}
  
  # Save nodes between first and last inclusive, truncating containers
  # as necessary so first and last are siblings.
  my @nodes;
  while ($es) {
    push(@nodes, $es);
    if ($es->unique_key eq $el->unique_key) {last;}
    if ($es->nodeType eq XML::LibXML::XML_ELEMENT_NODE && $es->hasChildNodes) {
      &truncateAt($es, $el);
    }
    $es = @{$XPC->findnodes('following-sibling::node()[1]', $es)}[0];
  }
  if (!$es) {&ErrorBug("Ran out of nodes.");}
  
  # Enclose them in a marked div
  my $id = 'source_'.$sourceP->{'value'};
  my $div = "<div $ONS annotateType='$VSYS{'moved_type'}' annotateRef='$id' " .
  "resp='$VSYS{'moved_type'}'/>";
  $div = $XML_PARSER->parse_balanced_chunk($div);
  $div = $el->parentNode->insertAfter($div, $el);
  
  # Write source position milestone
  my $ms = "<div $ONS type='$VSYS{'moved_type'}' " .
  "osisID='$id' resp='$VSYS{'moved_type'}'> </div>";
  $ms = $XML_PARSER->parse_balanced_chunk($ms);
  $ms = $el->parentNode->insertAfter($ms, $el);
  
  foreach (@nodes) {$_->unbindNode(); $_ = $div->appendChild($_);}
  
  # Find position in fixed location, creating bookGroup/book/chapter
  # only as necessary.
  my $bk = $fixedP->{'bk'};
  my $ch = $fixedP->{'ch'};
  my $vs = $fixedP->{'vs'};
  my $vl = $fixedP->{'vl'};
  my $bg = &defaultOsisIndex($bk, 3);
  my $bookGroup = @{$XPC->findnodes('//osis:div[@type="bookGroup"]
      [@osisID="'.$bg.'"]', $xml)}[0];
  if (!$bookGroup) {
    $bookGroup = &createNewBookGroup($bg, $xml, $VSYS{'moved_type'});
  }
  my $book = @{$XPC->findnodes('//osis:div[@type="book"]
      [@osisID="'.$bk.'"]', $xml)}[0];
  if (!$book) {$book = &createNewBook($bk, $xml, $VSYS{'moved_type'});}
  my $chapter;
  if ($sourceP->{'isWholeChapter'}) {
    $chapter = @{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0];
  }
  else {
    $chapter = @{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0];
    if (!$chapter) {
      $chapter = &createNewChapter($bk, $ch, $xml, $VSYS{'moved_type'});
    }
  }
  my $verse = &getVerseTag("$bk.$ch.".($vs-1), $xml, 1);
  
  # Move div to fixed location
  $div->unbindNode();
  if ($sourceP->{'isWholeChapter'}) {
    if ($chapter) {$div = $chapter->parentNode->insertAfter($div, $chapter);}
    else {$div = $book->appendChild($div);}
    my $oldid = $sourceP->{'bk'}.'.'.$sourceP->{'ch'};
    my $newid = $fixedP->{'bk'}.'.'.$fixedP->{'ch'};
    foreach my $sl (0, 1) {
      my $ch = @{$XPC->findnodes("//osis:chapter[\@".($sl ? 'eID':'sID')."='$oldid']", $xml)}[0];
      if (!$ch) {last;}
      $ch = &toMilestone($ch);
      if (!$sl) {$ch->setAttribute('osisID', $newid);}
      $ch->setAttribute(($sl ? 'eID':'sID'), $newid);
    }
  }
  else {
    if ($verse) {$div = $verse->parentNode->insertAfter($div, $verse);}
    else {$div = $chapter->parentNode->insertBefore($div, $chapter);}
  }

  for (my $v = $sourceP->{'vs'}; $v <= $sourceP->{'vl'}; $v++) {
    my $oldid = $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.$v;
    my $newid =  $fixedP->{'bk'}.'.'. $fixedP->{'ch'}.'.'.($fixedP->{'vs'} + $v - $sourceP->{'vs'});
    foreach my $sl (0, 1) {
      my $vt = &getVerseTag($oldid, $xml, $sl);
      if (!$vt) {last;}
      $vt = &toMilestone($vt);
      if (!$sl) {$vt->setAttribute('osisID', $newid);}
      $vt->setAttribute(($sl ? 'eID':'sID'), $newid);
    }
  }
}

# If $element contains node $makeSibling, then $makeSibling and all 
# following nodes within $element are moved after $element. So $element 
# and $makeSibling will always end up as siblings, or else $element will 
# be left untouched.
sub truncateAt {
  my $element = shift;
  my $makeSibling = shift;
  my $afterP = shift;
  
  if (!defined($afterP)) {$afterP = \$element;}

  my $truncate = 0;
  foreach my $child ($element->childNodes) {
    if ($child->unique_key eq $makeSibling->unique_key) {$truncate = 1;}
    
    if ($truncate) {
      $child->unbindNode();
      $child = $$afterP->parentNode->insertAfter($child, $$afterP);
      $$afterP = $child;
    }
    elsif ($child->nodeType eq XML::LibXML::XML_ELEMENT_NODE && $child->hasChildNodes) {
      $truncate |= &truncateAt($child, $makeSibling, $afterP);
    }
  }
  
  return $truncate;
}

# Used when an entire book has been moved from its fixed verse system
# position. Markup is added at both locations to facilitate easy dest-
# ination selection via XSLT:
# - The fixed book to be moved is marked. Also mark any preceding 
#   sibling book-introduction divs.
# - An empty source bookGroup is created if it does not already exist.
#   Any created bookGroup will be removed when the fixed verse system is
#   extracted from the resulting OSIS file.
# - A source target milestone-div is placed so as to designate where the 
#   fixed book will be moved to. Also milestones for any preceding
#   sibling book-introduction divs are placed. 
sub applyVsysMovedBook {
  my $book = shift;
  my $bookGroup = shift;
  my $position = shift;
  my $xml = shift;
  
  # Insure position is ordinal
  if ($position !~ /^\d+$/) {
    $position = 1 + &defaultOsisIndex("$bookGroup:$position", 1);
    if (!defined($position)) {
      &Error("Book '$position' is not part of bookGroup '$bookGroup'.",
        "Check the VSYS_MOVED instructions.");
      $position = 0; # position 1 is first valid position
    }
  }
  
  # Find book and intro elements in fixed verse system
  my $bkFixed = @{$XPC->findnodes("//osis:div[\@type='book']
      [\@osisID='$book']", $xml)}[0];
  if (!$bkFixed) {
    &Error("No '$book' book was found in the OSIS file.", 
           "Check the VSYS_MOVED instructions.");
    return;
  }
  my @elements; push(@elements, $bkFixed); 
  my $xpath = 'preceding-sibling::osis:div[not(self::osis:div[@type="book"])]';
  my $ps = @{$XPC->findnodes($xpath, $bkFixed)}[0];
  while ( $ps->hasAttribute('scope') && 
          &bookInScope($book, $ps->getAttribute('scope'), &conf('Versification')) 
        ) {
    push(@elements, $ps);
    $ps = @{$XPC->findnodes($xpath, $ps)}[0];
  }
  
  # Find source bookGroup (creating if necessary)
  my $bgFixed = @{$XPC->findnodes("//osis:div[\@type='bookGroup']
      [\@osisID='$bookGroup']", $xml)}[0];
  if (!$bgFixed) {
    # bookGroups are sorted later
    $bgFixed = &createNewBookGroup($bookGroup, $xml, $VSYS{'moved_type'});
  }
  
  my $n = 0;
  foreach my $e (reverse(@elements)) {
    my $id = 'source_'.$e->getAttribute('osisID');
    
    # Mark div in fixed verse system
    $e->setAttribute('annotateType', $VSYS{'moved_type'});
    $e->setAttribute('annotateRef', $id);

    # Place milestone with source position in bookGroup
    my $ms = "<div $ONS type='$VSYS{'moved_type'}' " . 
    "osisID='$id' resp='$VSYS{'moved_type'}' position='".($position + $n)."'> </div>";
    $ms = $XML_PARSER->parse_balanced_chunk($ms)->firstChild;
    $n += 0.01;
    
    # Place milestone as last child (books are sorted later)
    $ms = $bgFixed->appendChild($ms);
  }
  if ($n >= 0.5) {&ErrorBug("Too many intro divs");}
}

# Used when an entire bookGroup has been moved from its default verse 
# system position in %OSIS_GROUP to another position in the source verse
# system. Markup is added at both locations to facilitate easy dest-
# ination selection via XSLT:
# - The fixed bookGroup to be moved is marked.
# - A source target milestone-div is placed so as to designate the  
#   position of the bookGroup when source is extracted from the OSIS file.
sub applyVsysMovedBookGroup {
  my $bookGroup = shift;
  my $position = shift;
  my $xml = shift;
  
  # Insure position is ordinal
  if ($position !~ /^\d+$/) {
    $position = 1 + &defaultOsisIndex($position, 2);
    if (!defined($position)) {
      &Error("Book group '$position' is unrecognized.",
        "Check the VSYS_MOVED instructions.");
      $position = 0; # position 1 is first valid position
    }
  }
  
  # Find and mark bookGroup in fixed verse system
  my $bgFixed = @{$XPC->findnodes("//osis:div[\@type='bookGroup']
      [\@osisID='$bookGroup']", $xml)}[0];
  if (!$bgFixed) {
    &Error("No '$bookGroup' bookGroup was found in the OSIS file.", 
           "Check the VSYS_MOVED instructions.");
    return;
  }
  $bgFixed->setAttribute('annotateType', $VSYS{'moved_type'});
  $bgFixed->setAttribute('annotateRef', "source_$bookGroup");
  
  # Place milestone with source position in osisText (bookGroups are sorted later)
  # The 'milestone' must be a div this time, to pass OSIS validation for osisText children.
  my $ms = "<div $ONS type='$VSYS{'moved_type'}' " . 
  "osisID='source_$bookGroup' resp='$VSYS{'moved_type'}' position='$position'> </div>";
  $ms = $XML_PARSER->parse_balanced_chunk($ms)->firstChild;
  $ms = $bgFixed->parentNode->appendChild($ms);
}

sub createNewBookGroup {
  my $bookGroup = shift;
  my $xml = shift;
  my $resp = shift;
  
  my $bg = "<div $ONS type='bookGroup' osisID='$bookGroup' ";
  if ($resp) {$bg .= "resp='$resp' ";}
  $bg .= "/>";
  $bg = $XML_PARSER->parse_balanced_chunk($bg)->firstChild;
  my $osisText = @{$XPC->findnodes('//osis:osisText', $xml)}[0];
  return $osisText->appendChild($bg);
}

sub createNewBook {
  my $book = shift;
  my $xml = shift;
  my $resp = shift;
  
  my $bookGroup = &defaultOsisIndex($book, 3);
  
  my $bk = "<div $ONS type='book' osisID='$book' ";
  if ($resp) {$bk .= "resp='$resp' ";}
  $bk .= "/>";
  $bk = $XML_PARSER->parse_balanced_chunk($bk)->firstChild;
  $bookGroup = @{$XPC->findnodes("//osis:div[\@type='bookGroup']
      [\@osisID='$bookGroup']", $xml)}[0];
  return $bookGroup->appendChild($bk);
}

sub createNewChapter {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  my $resp = shift;
  
  my $nchs = "<chapter $ONS osisID='$bk.$ch' sID='$bk.$ch' ";
  my $nche = "<chapter $ONS eID='$bk.$ch' ";
  if ($resp) {
    $nchs .= "resp='$resp' ";
    $nche .= "resp='$resp' ";
  }
  $nchs .= "/>";
  $nche .= "/>";
  $nchs = $XML_PARSER->parse_balanced_chunk($nchs)->firstChild;
  $nche = $XML_PARSER->parse_balanced_chunk($nche)->firstChild;
  
  my $prevch = @{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0];
  if ($prevch) {
    $nchs = $prevch->parentNode->insertAfter($nchs, $prevch);
  }
  else {
    my $book = @{$XPC->findnodes("//osis:div[\@type='book'][\@osisID='$bk']", $xml)}[0];
    $nchs = $book->addChild($nchs);
  }
  $nche = $nchs->parentNode->insertAfter($nche, $nchs);
  
  return $nche;
}

# Sorts bookGroups and books. It places milestone position elements in 
# their correct positions. Sorting is also required because applyVsys  
# functions may have appended new elements. NOTE: All non-element child 
# nodes end up first after this function!
sub sortChildrenFixed {
  my $parent = shift;

  my $childType = ($parent->localname eq 'osisText' ? 'bookGroup':'book');
  
  # Note: Milestone position ordinals correspond to this order:
  # - OT|NT books               -> SWORD versification order (or current
  #                                order if CustomBookOrder is set)
  # - books in other bookGroups -> %OSIS_GROUP{$bg} order
  # - bookGroups themselves     -> @OSIS_GROUPS order
  my %sortOrder; my $pos = 1;
  if ($childType eq 'book' && $parent->getAttribute('osisID') =~ /^(OT|NT)$/) {
    if (&conf('CustomBookOrder')) {
      foreach my $child ($parent->childNodes) {
        if ($child->nodeType ne XML::LibXML::XML_ELEMENT_NODE ||
            $child->getAttribute('type') ne 'book') {next;}
        $sortOrder{$child->getAttribute('osisID')} = $pos++;
      }
    }
    else {
      my $canonP; my $bookOrderP;
      &swordVsys(&conf('Versification'), \$canonP, \$bookOrderP);
      foreach (keys %{$bookOrderP}) {
        $sortOrder{$_} = $bookOrderP->{$_};
      }
    }
  }
  elsif ($childType eq 'book') {
    foreach (@{$OSIS_GROUP{$parent->getAttribute('osisID')}}) {
      $sortOrder{$_} = $pos++;
    }
  }
  else {
    foreach (@OSIS_GROUPS) {
      $sortOrder{$_} = $pos++;
    }
  }
  
  my $pos = 0; my $inc = 0; my %reset; my @unbound;
  foreach my $child ($parent->childNodes) {
    if ($child->localname ne 'div') {next;}
    
    # Write div's position, if not already recorded
    if (!$child->hasAttribute('position')) {
      my $id = ($child->hasAttribute('osisID') ? $child->getAttribute('osisID'):'');
      my $p = $sortOrder{$id};
      if (!$p) {
        if ($child->hasAttribute('scope')) {
          my $s = $child->getAttribute('scope'); $s =~ s/[\- ].*//;
          my $scid = ($childType eq 'bookGroup' ? &defaultOsisIndex($s, 3):$s);
          $p = $sortOrder{$scid};
        }
      }
      if (defined($p)) {$pos = $p;}
      if (!$reset{$p}) {$reset{$p}++; $inc = 0;}
      # < 0.5 reserved for position milestones
      $child->setAttribute('position', ($pos + 0.5 + $inc));
      $inc += 0.01;
      if ($inc >= 0.5) {&ErrorBug("Too many intro divs");}
    }
    
    # Unbind all divs
    push(@unbound, $child);
    $child->unbindNode()
  }
  
  foreach ( sort { $a->getAttribute('position') <=> $b->getAttribute('position') } @unbound ) {
    my $r = $parent->appendChild($_);
    if ($r->hasAttribute('position')) {$r->removeAttribute('position');}
  }
}

# Used when a chapter in the fixed verse system has been split into two 
# chapters in the source verse system. All verse tags from the split 
# onward to the end of the book must be re-versified, with alternate 
# chapter and verse tags added. The split chapter's end tag and the
# following chapter's start tag are converted to milestones, while all 
# following chapter tags are re-versified downward by one chapter. 
sub applyVsysChapterSplitAt {
  my $fixedP = shift;
  my $xml = shift;
  
  if (!$fixedP) {return;}
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'};
  my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
  
  # Reversify all verse tags in the book following the split
  my @verses = @{$XPC->findnodes("//osis:verse[starts-with(\@sID, '$bk.')]", $xml)};
  push (@verses, @{$XPC->findnodes("//osis:verse[starts-with(\@eID, '$bk.')]", $xml)});
  foreach my $v (@verses) {
    my $ida = $v->getAttribute('sID');
    if (!$ida) {$ida = $v->getAttribute('eID');}
    foreach my $id (split(/\s+/, $ida)) {
      my $vch = $id; 
      my $vvs = ($vch =~ s/^$bk\.(\d+)\.(\d+)$/$1/ ? $2:'');
      if ($vch <= $ch) {next;}
      &reVersify($bk, $vch, $vvs, -1, ($vch == ($ch + 1) ? $lastV:0), $xml);
    }
  }
  
  # Reversify (or just convert to milestone) all chapter tags in the book following the split
  my @chapters = @{$XPC->findnodes("//osis:chapter[starts-with(\@sID, '$bk.')]", $xml)};
  push (@chapters, @{$XPC->findnodes("//osis:chapter[starts-with(\@eID, '$bk.')]", $xml)});
  foreach my $c (@chapters) {
    my $isStart = 1;
    my $id = $c->getAttribute('sID');
    if (!$id) {
      $isStart = 0;
      $id = $c->getAttribute('eID');
    }
    my $vch = $id; $vch = ($vch =~ /^$bk\.(\d+)$/ ? $1:'');
    if ($vch < $ch) {next;}
    elsif ($vch == $ch &&  $isStart) {next;}
    elsif ($vch == $ch && !$isStart) {&toMilestone($c, 1, 0);}
    elsif ($vch == ($ch + 1) && $isStart) {&toMilestone($c, 1, 0);}
    else {
      my $newChapTag = &toMilestone($c, 0, 0);
      my $newID = $id; $newID = ($newID =~ /^([^\.]+)\.(\d+)$/ ? $1.'.'.($2-1):'');
      &Note("applyVsysChapterSplitAt($bk, $ch, $vs)[Changing chapter osisID from ".$newChapTag->getAttribute('osisID')." to $newID]");
      if ($isStart) {
        $newChapTag->setAttribute('osisID', $newID);
        $newChapTag->setAttribute('sID', $newID);
        $newChapTag->setAttribute('resp', $RESP{'vsys'});
      }
      else {
        $newChapTag->setAttribute('eID', $newID);
        $newChapTag->setAttribute('resp', $RESP{'vsys'});
      }
    }
  }
}

# Used when verses in the verse system were not included in the 
# translation. It modifies the previous verse osisID to include the 
# empty verses and renumbers the following verses in the chapter, also 
# inserting alternate verse numbers there. If the 'missing' verse was
# moved somewhere else (the usual case) that is marked-up by FROM_TO.
sub applyVsysMissing {
  my $fixedP = shift;
  my $xml = shift;
  
  if (!$fixedP) {return;}
  
  my $bk = $fixedP->{'bk'}; my $ch = $fixedP->{'ch'}; my $vs = $fixedP->{'vs'}; my $vl = $fixedP->{'vl'};
  
  if ($fixedP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  my $verseNumberToModify = ($vs!=1 ? ($vs-1):&getFirstVerseInChapterOSIS($bk, $ch, $xml));
  
  # Handle the rare case when there isn't a previous verse, by creating one.
  my $verseCreated;
  if (!$verseNumberToModify) {
    $verseCreated++;
    if (&getFirstVerseInChapterOSIS($bk, ($ch+1), $xml)) {
      &ErrorBug("Cannot be missing all verses in a chapter, unless the chapter is the last in a book.", 1);
    }
    my $chapterStartTag = @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0];
    if (!$chapterStartTag) {
      # Create a chapter for the verse if needed
      my $prevChapterEndTag = @{$XPC->findnodes('//osis:chapter[@eID="'.$bk.'.'.($ch-1).'"]', $xml)}[0];
      my $tags = "<chapter $ONS sID='$bk.$ch' osisID='$bk.$ch' resp='$RESP{'vsys'}'/>" . 
                 "<chapter $ONS eID='$bk.$ch' resp='$RESP{'vsys'}'/>";
      $prevChapterEndTag->parentNode->insertAfter(
        $XML_PARSER->parse_balanced_chunk($tags), 
        $prevChapterEndTag);
      $chapterStartTag = @{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0];
    }
    # Create an empty verse
    my $tags = "<verse $ONS sID='$bk.$ch.1' osisID='$bk.$ch.1' resp='$RESP{'vsys'}'/>" . 
               "<verse $ONS eID='$bk.$ch.1' resp='$RESP{'vsys'}'/>";
    $chapterStartTag->parentNode->insertAfter(
        $XML_PARSER->parse_balanced_chunk($tags), 
        $chapterStartTag);
    $verseNumberToModify = 1;
    $vs++; # Because an empty verse was just created
  }
  
  my $verseTagToModify = &getVerseTag("$bk.$ch.$verseNumberToModify", $xml, 0);
  # For any following verses, advance their verse numbers and add alternate verse numbers if needed
  my $followingVerse = @{$XPC->findnodes('./following::osis:verse[@sID][1]', $verseTagToModify)}[0];
  if ($followingVerse) {
    my $count = (1 + $vl - $vs);
    $followingVerse = $followingVerse->getAttribute('osisID');
    $followingVerse =~ s/^[^\.]+\.\d+\.(\d+)\b.*?$/$1/;
    if ($vs != ($followingVerse-$count) - ($vs!=1 ? 0:1)) {
      for (my $v=&getLastVerseInChapterOSIS($bk, $ch, $xml); $v>=$vs; $v--) {
        &reVersify($bk, $ch, $v, 0, $count, $xml);
      }
    }
  }
  
  # Add the missing verses (by listing them in an existing osisID)
  # need to get verseTagToModify again since reVersify converted the old one to a milestone
  $verseTagToModify = &getVerseTag("$bk.$ch.".($vs!=1 ? ($vs-1):&getFirstVerseInChapterOSIS($bk, $ch, $xml)), $xml, 0);
  my $endTag = @{$XPC->findnodes('//osis:verse[@eID="'.$verseTagToModify->getAttribute('sID').'"]', $xml)}[0];
  my @missing;
  for (my $v = $vs; $v <= $vl; $v++) {
    my $a = "$bk.$ch.$v";
    &osisIDCheckUnique($a, $xml);
    push(@missing, $a);
  }

  push(@missing, $verseTagToModify->getAttribute('osisID'));
  my $newOsisID = join(' ', &normalizeOsisID(\@missing));
  &Note("Changing verse osisID='".$verseTagToModify->getAttribute('osisID')."' to '$newOsisID'");
  if (!$verseCreated) {
    $verseTagToModify = &toMilestone($verseTagToModify, 0, 0);
    $endTag = &toMilestone($endTag, 0, 0);
  }
  $verseTagToModify->setAttribute('osisID', $newOsisID);
  $verseTagToModify->setAttribute('sID', $newOsisID);
  $endTag->setAttribute('eID', $newOsisID);
}

# Used when the translation includes extra verses in a chapter compared
# to the target verse system (and which are marked up as regular 
# verses). For these extra verses, alternate verse numbers are inserted 
# and verse tags are converted into milestone elements. Then they are 
# enclosed within the proceding verse system verse. All following verses 
# in the chapter are renumbered and alternate verses inserted for them.
sub applyVsysExtra {
  my $sourceP = shift;
  my $canonP = shift;
  my $xml = shift;
  my $adjusted = shift;
  
  if (!$sourceP) {return;}
  
  my $bk = $sourceP->{'bk'}; my $ch = $sourceP->{'ch'}; my $vs = $sourceP->{'vs'}; my $vl = $sourceP->{'vl'};
  
  if ($sourceP->{'isPartial'}) {
    &Note("Verse reference is partial, so nothing to do here.");
    return;
  }
  
  if (!exists($canonP->{$bk})) {
    &Error("VSYS function applyVsysExtra requires verse system to contain '$bk'.");
    return;
  }
  
  my $isWholeChapter = ($ch > @{$canonP->{$bk}} ? 1:$sourceP->{'isWholeChapter'});
  
  # Handle the special case of an extra chapter (like Psalm 151)
  if ($ch > @{$canonP->{$bk}}) {
    if ($ch == (@{$canonP->{$bk}} + 1)) {
      my $lastv = &getLastVerseInChapterOSIS($bk, $ch, $xml);
      if ($vs != 1 || $vl != $lastv) {
        &Error("VSYS_EXTRA($bk, $ch, $vs, $vl): Cannot specify verses for a chapter outside the verse system.", "Use just '$bk.$ch' instead.");
      }
      $vs = 1;
      $vl = $lastv;
    }
    else {
      &ErrorBug("VSYS_EXTRA($bk, $ch, $vs, $vl): Not yet implemented (except when the extra chapter is the last chapter of the book).");
      return;
    }
  }
  
  # All verse tags between this startTag and endTag will become alternate
  my $sid = ($isWholeChapter ?
    "$bk.".($ch-1).".".&getLastVerseInChapterOSIS($bk, ($ch-1), $xml) :
    "$bk.$ch.".($vs!=1 ? ($vs-1):$vs));
  my $eid = "$bk.$ch.".($isWholeChapter || $vs != 1 ? $vl:($vl+1));
  
  my $startTag = &getVerseTag($sid, $xml, 0);
  my $endTag   = &getVerseTag($eid, $xml, 1);
  
  if (!$startTag) {
    &Error("Referenced starting verse tag is missing: $sid.");
    $sid =~ s/^(.*?)\.(\d+)$//;
    &errMissingVerse($1, $2);
    return;
  }
  if (!$endTag) {
    &Error("Referenced ending verse tag is missing: $eid.", "");
    $eid =~ s/^(.*?)\.(\d+)$//;
    &errMissingVerse($1, $2);
    return;
  }
 
  # VSYS_EXTRA references the source verse system, which may have been
  # modified by previous instructions. So adjust our inputs in that case.
  if (!$adjusted && &has_src_milestone($startTag) =~ /^[^\.]+\.\d+\.(\d+)\b/) {
    my $arv = $1;
    $startTag->getAttribute('osisID') =~ /^[^\.]+\.\d+\.(\d+)\b/;
    my $shift = ($1 - $arv);
    if ($shift) {
      &Note("This verse was moved, adjusting position: '$shift'.");
      my $newSourceArgumentP = &parseVsysArgument($bk.'.'.$ch.'.'.($vs+$shift).'.'.($sourceP->{'isPartial'} ? 'PART':($vl+$shift)), $xml, 'source');
      &applyVsysExtra($newSourceArgumentP, $canonP, $xml, 1);
      return;
    }
  }
 
  # If isWholeChapter, then convert chapter tags to alternates and add alternate chapter number
  if ($isWholeChapter) {
    my $chapLabel = @{$XPC->findnodes("//osis:title[\@type='x-chapterLabel'][not(\@canonical='true')]
      [ preceding::osis:chapter[\@osisID][1][\@sID='$bk.$ch'][not(preceding::osis:chapter[\@eID='$bk.$ch'])] ]", $xml)}[0];
    if ($chapLabel) {
      &Note("Converting chapter label \"".$chapLabel->textContent."\" to alternate.");
      $chapLabel->setAttribute('type', 'x-chapterLabel-alternate');
      my $t = $chapLabel->textContent();
      &changeNodeText($chapLabel, '');
      my $alt = "<hi $ONS type='italic' subType='x-alternate'>$t</hi>";
      $alt = $XML_PARSER->parse_balanced_chunk($alt);
      foreach my $chld ($chapLabel->childNodes) {$alt->insertAfter($chld, undef);}
      $chapLabel->insertAfter($alt, undef);
    }
    else {
      &Note("No chapter label was found, adding alternate chapter label \"$ch\".");
      my $alt = "<title $ONS type='x-chapterLabel-alternate' resp='$RESP{'vsys'}'>" .
      "<hi $ONS type='italic' subType='x-alternate'>$ch</hi></title>";
      $alt = $XML_PARSER->parse_balanced_chunk($alt);
      my $chStart = @{$XPC->findnodes("//osis:chapter[\@osisID='$bk.$ch']", $xml)}[0];
      $chStart->parentNode()->insertAfter($alt, $chStart);
    }
    my $chEnd = &toMilestone(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.$ch']", $xml)}[0], 0, 1);
    $chEnd->setAttribute('eID', "$bk.".($ch-1));
    &toMilestone(@{$XPC->findnodes("//osis:chapter[\@eID='$bk.".($ch-1)."']", $xml)}[0], 1, 1);
    &toMilestone(@{$XPC->findnodes("//osis:chapter[\@sID='$bk.$ch']", $xml)}[0], 1, 1);
  }
  
  # Convert verse tags between startTag and endTag to alternate verse numbers
  # But if there are no in-between tags, then only modify the IDs.
  $startTag = &toMilestone($startTag, 0, 0);
  if ($startTag->getAttribute('sID') eq $endTag->getAttribute('eID')) {
    my %ids; map($ids{$_}++, split(/\s+/, $startTag->getAttribute('osisID')));
    for (my $v = $vs; $v <= $vl; $v++) {if ($ids{"$bk.$ch.$v"}) {delete($ids{"$bk.$ch.$v"});}}
    my $newID = join(' ', &normalizeOsisID([ sort keys(%ids) ]));
    $startTag->setAttribute('osisID', $newID);
    $startTag->setAttribute('sID', $newID);
  }
  else {
    my $v = $startTag;
    my @alts;
    do {
      if ($v->unique_key ne $startTag->unique_key) {push(@alts, $v);}
      $v = @{$XPC->findnodes('following::osis:verse[1]', $v)}[0];
    } while ($v && $v->unique_key ne $endTag->unique_key);
    foreach my $v (@alts) {&toMilestone($v, 1, 1);}
  }
  # Also convert endTag to alternate and update eID 
  $endTag = &toMilestone($endTag, 0, 1);
  $endTag->setAttribute('eID', $startTag->getAttribute('sID'));
  
  # Following verses get decremented verse numbers plus an alternate verse number (unless isWholeChapter)
  if (!$isWholeChapter) {
    my $lastV = &getLastVerseInChapterOSIS($bk, $ch, $xml);
    my $count = (1 + $vl - $vs);
    for (my $v = $vs + $count + ($vs!=1 ? 0:1); $v <= $lastV; $v++) {
      &reVersify($bk, $ch, $v, 0, (-1*$count), $xml);
    }
  }
}

# VSYS_MISSING_FN produces VTAG_MISSING instructions indicating verses 
# where verse tags were left out of the source text. This happens when a 
# verse's text was not included in the source verse system, but a 
# footnote indicating the removal (which often includes the verse text 
# itself) is located at the end of the preceding verse. Sometimes, 
# references to these missing verses appear in the source text, even 
# though the verse text itself does not. Linking such missing verses to 
# their previous verse insures there are no broken links in the source 
# text.
sub applyVsysMissingVTag {
  my $argP = shift;
  my $xml = shift;
  
  my $fixedP  = &parseVsysArgument($argP->{'fixed'},  $xml, 'fixed');
  my $sourceP = &parseVsysArgument($argP->{'source'}, $xml, 'source');
  
  my $prevOsisID = $sourceP->{'bk'}.'.'.$sourceP->{'ch'}.'.'.$sourceP->{'vs'};
  
  my $prevVerseS = &getVerseTag($prevOsisID, $xml, 0);
  my $prevVerseE = &getVerseTag($prevOsisID, $xml, 1);
  if (!$prevVerseS || !$prevVerseE) {
    &ErrorBug("Could not find verse with osisID '$prevOsisID'");
    return;
  }
  
  my $newOsisID = $prevOsisID;
  for (my $v = $fixedP->{'vs'}; $v <= $fixedP->{'vl'}; $v++) {
    $newOsisID .= ' '.$fixedP->{'bk'}.'.'.$fixedP->{'ch'}.'.'.$v;
  }
  $newOsisID = join(' ', &normalizeOsisID([ split(/\s+/, $newOsisID) ]));
  
  $prevVerseS->setAttribute('osisID', $newOsisID);
  $prevVerseS->setAttribute('sID',    $newOsisID);
  $prevVerseE->setAttribute('eID',    $newOsisID);
  &Note("Applied VSYS_MISSING_FN: ".$argP->{'source'}.", osisID=\"$newOsisID\"");
}

# Markup verse as alternate, increment its chapter by $chCount and its 
# verse by $vsCount and mark it as moved.
sub reVersify {
  my $bk = shift;
  my $ch = shift;
  my $vs = shift;
  my $chCount = shift;
  my $vsCount = shift;
  my $xml = shift;
  
  my $note = "reVersify($bk, $ch, $vs, $chCount, $vsCount)";
  
  my $vTagS = &getVerseTag("$bk.$ch.$vs", $xml, 0);
  if (!$vTagS) {$note .= "[Start tag not found]"; &Note($note); return;}
  my $vTagE = &getVerseTag("$bk.$ch.$vs", $xml, 1);
  if (!$vTagE) {$note .= "[End tag not found]"; &Note($note); return;}
  
  my $osisID = $vTagS->getAttribute('osisID');
  my $newVerseID;
  my $newID;
  if ($vsCount || $chCount) {
    my @verses = split(/\s+/, $osisID);
    $newVerseID = $bk.'.'.($ch + $chCount).'.'.($vs + $vsCount);
    foreach my $v (@verses) {if ($v  eq "$bk.$ch.$vs") {$v = $newVerseID;}}
    $newID = join(' ', @verses);
  }
  
  if (!$vTagS->hasAttribute('resp') || $vTagS->getAttribute('resp') ne $RESP{'vsys'}) {
    $vTagS = &toMilestone($vTagS, 0, ($chCount ? 2:1));
    $vTagE = &toMilestone($vTagE, 0, ($chCount ? 2:1));
    if ($vsCount || $chCount) {
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$newVerseID, 'source'=>"$bk.$ch.$vs" });
    }
  }
  elsif (&has_src_milestone($vTagS) eq $newID) {
    $vTagS = &undoMilestone(&has_src_milestone($vTagS, 1));
    $vTagE = &undoMilestone(&has_src_milestone($vTagE, 1));
    $osisID = $vTagS->getAttribute('osisID');
    for (my $i=0; $i<@VSYS_INSTR; $i++) {
      if (@VSYS_INSTR[$i]->{'source'} eq "$bk.$ch.$vs") {splice(@VSYS_INSTR, $i, 1); last;}
    }
  }
  else {$note .= "[Alternate verse already set]";}
  
  # Increment/Decrement
  if ($vsCount || $chCount) {
    if ($newID ne $osisID) {
      $note .= "[Changing verse osisID from ".$vTagS->getAttribute('osisID')." to $newID]";
      &osisIDCheckUnique($newVerseID, $xml);
      $vTagS->setAttribute('osisID', $newID);
      $vTagS->setAttribute('sID', $newID);
      $vTagS->setAttribute('resp', $RESP{'vsys'});
      $vTagE->setAttribute('eID', $newID);
      $vTagE->setAttribute('resp', $RESP{'vsys'});
    }
  }
  &Note($note); 
}

# Terminology:
# src_milestone = x-vsys milestone representing an original source verse or chapter tag
# fit_tag       = verse or chapter tag of fitted source text associated with a src_milestone
#
# This function converts a verse or chapter tag into a src_milestone and
# optionally creates a source verse system fit_tag and/or alternate
# verse tag. It writes a src_milestone for the passed verse or chapter 
# tag, unless it already has one. The passed verse or chapter tag 
# becomes the fit_tag. But if noFitTag is set, any fit_tag is removed 
# from the tree. The fit_tag element is returned, unless noFitTag is set 
# and there was no pre-existing src_milestone, in which case '' is 
# returned. When writeAlternate is set, an alternate verse number will 
# also be written to the tree if the passed element is a starting verse
# tag.
sub toMilestone {
  my $verse_or_chapter_tag = shift;
  my $noFitTag = shift;
  my $writeAlternate = shift; # 1=verse, 2=verse and chapter
  
  # Typical alternate markup example:
  # <milestone type="x-vsys-verse-start" osisRef="Rom.14.24" annotateRef="Rom.16.25" annotateType="x-vsys-source"/>
  #<hi type="italic" subType="x-alternate" resp="x-vsys"><hi type="super">(25)</hi></hi>
  
  my $start_or_end = ($verse_or_chapter_tag->getAttribute('sID') ? 'start_vs':($verse_or_chapter_tag->getAttribute('eID') ? 'end_vs':''));
  my $s_or_eID = ($start_or_end eq 'start_vs' ? $verse_or_chapter_tag->getAttribute('sID'):$verse_or_chapter_tag->getAttribute('eID'));
  my $isVerseStart = ($start_or_end eq 'start_vs' && $verse_or_chapter_tag->nodeName eq 'verse' ? 1:0);
  if (!$start_or_end) {
    &ErrorBug("Element missing sID or eID: ".$verse_or_chapter_tag->toString());
  }
  if ($start_or_end eq 'start_vs' && $s_or_eID ne $verse_or_chapter_tag->getAttribute('osisID')) {
    &ErrorBug("osisID is different than sID: $s_or_eID != ".$verse_or_chapter_tag->getAttribute('osisID'));
  }
  
  my $note = "toMilestone($s_or_eID, " . $verse_or_chapter_tag->nodeName . ", $start_or_end)";
  
  # Write fit_tag
  my $fit_tag;
  if (&has_src_milestone($verse_or_chapter_tag)) {
    $note .= "[src_milestone exists]";
    $fit_tag = $verse_or_chapter_tag;
    
    if ($noFitTag) {
      $fit_tag->unbindNode();
      $note .= "[remove fit_tag]";
    }
    
    &Note($note);
    
    return $fit_tag;
  }
  else {
    if ($noFitTag) {$note .= "[remove fit_tag]";}
    else {
      $fit_tag = $verse_or_chapter_tag->cloneNode(1);
      if ($fit_tag->getAttribute('type')) {&ErrorBug("Type already set on $fit_tag");}
      $fit_tag->setAttribute('resp', $RESP{'vsys'});
      $verse_or_chapter_tag->parentNode->insertBefore($fit_tag, $verse_or_chapter_tag);
      $note .= "[fit_tag]";
    }
  }
  
  # Write src_milestone
  my $src_milestone = $verse_or_chapter_tag;
  $src_milestone->setAttribute('type', $VSYS{'prefix_vs'}.'-'.$src_milestone->nodeName.$VSYS{$start_or_end});
  $src_milestone->setAttribute('annotateRef', $s_or_eID);
  $src_milestone->setAttribute('annotateType', $ANNOTATE_TYPE{'Source'});
  $src_milestone->setNodeName('milestone');
  if ($src_milestone->hasAttribute('osisID')) {$src_milestone->removeAttribute('osisID');}
  if ($src_milestone->hasAttribute('sID')) {$src_milestone->removeAttribute('sID');}
  if ($src_milestone->hasAttribute('eID')) {$src_milestone->removeAttribute('eID');}
  $note .= "[src_milestone]";
  # Remove any preceding newline or whitespace-only text node
  my $nl = @{$XPC->findnodes(
      'preceding-sibling::node()[1][self::text()]', $src_milestone)}[0];
  if ($nl && $nl->data() =~ /^[\n\s]*$/) {$nl->unbindNode();}
  
  # Write alternate verse number from the osisID
  if ($writeAlternate && $isVerseStart) {
    if ($s_or_eID =~ /^[^\.]+\.(\d+)\.(\d+)\b.*?(\.(\d+))?$/) {
      my $ch = $1; my $vs = $2; my $vl = ($3 ? $4:$vs);
      my $altText = ($vs ne $vl ? "$vs-$vl":"$vs");
      if ($writeAlternate == 2) {$altText = "$ch:$altText";}
      my $alt = "<hi $ONS type='italic' subType='x-alternate' ".
      "resp='$RESP{'vsys'}'><hi type='super'>($altText) </hi></hi>"; 
      $alt = $XML_PARSER->parse_balanced_chunk($alt);
      my $firstTextNode = @{$XPC->findnodes('following::text()
        [not(ancestor::osis:hi[starts-with(@subType, "x-alternate-")])]
        [normalize-space()][1]', $verse_or_chapter_tag)}[0];
      $firstTextNode->parentNode()->insertBefore($alt, $firstTextNode);
      $note .= "[alternate verse \"$altText\"]";
    }
    else {&ErrorBug("Could not parse: $s_or_eID =~ /^[^\.]+\.\d+\.(\d+)\b.*?(\.(\d+))?\$/");}
  }
  
  &Note($note);
  
  return $fit_tag;
}

# This will take a src_milestone element (of verse or chapter,  
# start or end) and convert it back to the original, undoing everything 
# that toMilestone() did. It returns the original element.
sub undoMilestone {
  my $ms = shift;
  
  my $note = "undoMilestone(".$ms->getAttribute('type').', '.$ms->getAttribute('annotateRef').')';

  my $avn = @{$XPC->findnodes('following::text()
    [not(ancestor::osis:hi[starts-with(@subType, "x-alternate-")])][normalize-space()][1]
    /ancestor-or-self::osis:hi[@subType="x-alternate"][@resp="'.$RESP{'vsys'}.'"][1]', $ms)}[0];
  if ($avn) {
    $avn->unbindNode();
    $note .= "[removed alternate verse ".$avn->textContent."]";
  }
  my $fit_tag = @{$XPC->findnodes('preceding-sibling::*[1][@resp="'.$RESP{'vsys'}.'"]', $ms)}[0];
  if ($fit_tag) {
    $fit_tag->unbindNode();
    $note .= "[removed fit_tag]";
  }
  my $chvsTypeRE = '^'.$VSYS{'prefix_vs'}.'-(chapter|verse)('.$VSYS{'start_vs'}.'|'.$VSYS{'end_vs'}.')$'; $chvsTypeRE =~ s/-/\\-/g;
  if ($ms->getAttribute('type') =~ /$chvsTypeRE/) {
    my $name = $1; my $type = $2;
    $ms->setNodeName($name);
    if ($type eq '-start') {
      $ms->setAttribute('sID', $ms->getAttribute('annotateRef'));
      $ms->setAttribute('osisID', $ms->getAttribute('annotateRef'));
    }
    else {$ms->setAttribute('eID', $ms->getAttribute('annotateRef'));}
    $ms->removeAttribute('annotateRef');
    $ms->removeAttribute('annotateType');
    $ms->removeAttribute('type');
  }
  else {&ErrorBug("Can't parse: ".$ms->getAttribute('type')." !~ /$chvsTypeRE/");}
  
  $note .= "[restored src_milestone to ".$ms->nodeName."]";
  &Note($note);
  
  return $ms;
}

# Report an error if any verse in this hypothetical osisID is already listed 
# in an existing osisID (to catch any bug causing multiple verse tags to cover 
# the same verse)
sub osisIDCheckUnique {
  my $osisID = shift;
  my $xml = shift;
  
  my @verses = split(/\s+/, $osisID);
  foreach my $v (@verses) {
    my $chv = &getVerseTag($v, $xml, 0);
    if ($chv) {
      &ErrorBug("osisIDCheckUnique($osisID): Existing verse osisID=\"".$chv->getAttribute('osisID')."\" includes \"$v\"");
    }
  }
}

# Reads the osis file to find a chapter's smallest verse number
sub getFirstVerseInChapterOSIS {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  
  my $fv = 200;
  foreach my $v (@vs) {if ($v->getAttribute('osisID') =~ /^\Q$bk.$ch.\E(\d+)/ && $1 < $fv) {$fv = $1;}}
  if ($fv == 200) {return;}
  
  return $fv;
}

# Reads the osis file to find a chapter's largest verse number
sub getLastVerseInChapterOSIS {
  my $bk = shift;
  my $ch = shift;
  my $xml = shift;
  my $source = shift; # also read source verse milestones
  my $quiet = shift;
  
  my $vl;
  
  my @vs = $XPC->findnodes("//osis:verse[starts-with(\@osisID, '$bk.$ch.')]", $xml);
  foreach my $v (@vs) {
    if ($v->getAttribute('osisID') =~ /\b\Q$bk.$ch.\E(\d+)$/ && $1 > $vl) {
      $vl = (1*$1);
    }
  }
  
  if ($source) {
    my @ms = $XPC->findnodes("//osis:milestone[starts-with(\@annotateRef, '$bk.$ch.')]", $xml);
    foreach my $v (@ms) {
      if ($v->getAttribute('annotateRef') =~ /\b\Q$bk.$ch.\E(\d+)$/ && $1 > $vl) {
        $vl = (1*$1);
      }
    }
  }
  
  if (!$quiet && !defined($vl)) {
    &ErrorBug("getLastVerseInChapterOSIS($bk, $ch): Could not find last verse.");
  }
  
  return $vl;
}

# Check if $bk.$ch.$$vsP.$$vlP covers an entire chapter. If $$vsP and 
# $$vlP are both undefined set $$vsP to 1 and $$vlP to the last verse in 
# the chapter. If $$vlP is undefined but $$vsP is defined, then set 
# $$vlP to $$vsP. Otherwise $$vsP and $$vlP are left untouched.
sub isWholeVsysChapter {
  my $bk  = shift;
  my $ch  = shift;
  my $vsP  = shift;
  my $vlP  = shift;
  my $vsys = shift;
  my $xml = shift;
  
  my $maxv;
  my $v = ($vsys eq 'source' ? &conf('Versification'):$vsys);
  my $canonP; &swordVsys($v, \$canonP);
  if ($canonP && ref($canonP->{$bk}) && defined($canonP->{$bk}[($ch-1)])) {
    $maxv = $canonP->{$bk}[($ch-1)];
  }
  if (!defined($maxv) && $vsys eq 'source') {
    $maxv = &getLastVerseInChapterOSIS($bk, $ch, $xml, 1, 1);
  }
  if (!defined($maxv)) {return;}
  
  if (!defined($$vlP)) {
    if (!defined($$vsP)) {
      $$vsP = 1; $$vlP = $maxv;
    }
    else {
      $$vlP = $$vsP;
    }
  }

  return ($$vsP == 1 && $$vlP == $maxv);
}

# Takes a required verse element and checks for an x-vsys 
# src_milestone. If the verse element has no such src_milestone, meaning it
# was not created by x-vsys instructions, then '' is returned.
# Otherwise, either the milestone's annotateRef value (source osisRef
# value) or the milestone element itself is returned, depending on the 
# value of returnElem.
sub has_src_milestone {
  my $verseElem = shift;
  my $returnElem = shift;
  
  if (!$verseElem) {&ErrorBug("Required verseElem is '$verseElem'"); return '';}
  
  my $ms = @{$XPC->findnodes('following::*[1][name()="milestone"][starts-with(@type, "'.$VSYS{'prefix_vs'}.'-verse")]', $verseElem)}[0];
  
  if (!$ms && $verseElem->getAttribute('resp') eq $RESP{'vsys'}) {
    &ErrorBug($RESP{'vsys'}. " verse tag has no src_milestone");
  }
  if ($ms && $verseElem->getAttribute('resp') ne $RESP{'vsys'}) {
    &ErrorBug("verse tag with src_milestone is not ".$RESP{'vsys'});
  }
    
  if (!$ms) {return '';}
  
  return ($returnElem ? $ms:$ms->getAttribute('annotateRef'));
}

1;
