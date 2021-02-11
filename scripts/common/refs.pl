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

our ($INPD, $MAININPD, $MAINMOD, $ONS, $OSISBOOKSRE, $SCRD, $TMPDIR,
    $XML_PARSER, $XPC, %ANNOTATE_TYPE);

# Sometimes source texts use reference type="annotateRef" to reference
# verses which were not included in the source text. When an annotateRef
# target does not exist, the reference tags are replaced by a span.
sub adjustAnnotateRefs {
  my $osisP = shift;

  &Log("\nChecking annotateRef targets in \"$$osisP\".\n");
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my $osisIDsP = &getVerseOsisIDs($xml);
  
  my $update;
  foreach my $reference (@{$XPC->findnodes('//osis:reference[@type="annotateRef"][@osisRef]', $xml)}) {
    my $remove;
    foreach my $r (split(/\s+/, &osisRef2osisID($reference->getAttribute('osisRef')))) {
      if (!$osisIDsP->{$r}) {$remove++; $update++; last;}
    }
    if ($remove) {
      my $new = $XML_PARSER->parse_balanced_chunk("<hi $ONS type='bold'>".$reference->textContent."</hi>");
      $reference->parentNode->insertAfter($new, $reference);
      $reference->unbindNode();
      &Warn("Removing annotateRef hyperlink to missing verse(s): '".$reference->getAttribute('osisRef')."'",
      "This can happen when the source text has annotateRef references 
targeting purposefully missing verses for instance. In such cases it is
correct to convert these to textual rather than hyperlink references.");
    }
  }

  if ($update) {
    &writeXMLFile($xml, $osisP);
  }
}

sub checkRefs {
  my $osis = shift;
  my $isDict = shift;
  my $prep_xslt = shift;
  
  my $t = ($prep_xslt =~ /fitted/i ? ' FITTED':($prep_xslt =~ /source/i ? ' SOURCE':' '));
  &Log("CHECKING$t OSISREF/OSISIDS IN OSIS: $osis\n");
  
  my $main = ($isDict ? &getModuleOsisFile($MAINMOD):$osis);
  my $dict = ($isDict ? $osis:'');
  
  if ($prep_xslt) {
    &runScript("$SCRD/scripts/$prep_xslt", \$main, '', 3);
    if ($dict) {
      &runScript("$SCRD/scripts/$prep_xslt", \$dict, '', 3);
    }
  }
  
  my %params = ( 
    'MAINMOD_URI' => $main, 
    'DICTMOD_URI' => $dict, 
    'versification' => ($prep_xslt !~ /source/i ? &conf('Versification'):'')
  );
  my $result = &runXSLT("$SCRD/scripts/checkrefs.xsl", ($isDict ? $dict:$main), '', \%params, 3);
  
  &Log($result."\n");
}

# Check all Scripture reference links in the source text. This does not
# look for or check any externally supplied cross-references. This check
# is run before fitToVerseSystem(), so it is checking that the source
# text's references are consistent with itself. Any broken links found
# here are either mis-parsed, or are errors in the source text.
sub checkMarkSourceScripRefLinks {
  my $in_osis = shift;
  
  if (&conf("ARG_SkipSourceRefCheck") =~/^true$/i) {
    &Note("Source references will not be checked because ARG_SkipSourceRefCheck=true");
    return
  }
  
  &Log("\nCHECKING SOURCE SCRIPTURE REFERENCE OSISREF TARGETS IN $in_osis...\n");
  
  my $changes = 0; my $problems = 0; my $checked = 0;
  
  my $in_bible = ($INPD eq $MAININPD ? $in_osis:'');
  if (!$in_bible) {
    # The Bible OSIS needs to be put into the source verse system for this check
    $in_bible = "$TMPDIR/$MAINMOD.xml";
    &copy(&getModuleOsisFile($MAINMOD, 'Error'), $in_bible);
    &runScript("$SCRD/scripts/osis2sourceVerseSystem.xsl", \$in_bible);
  }
  
  my $osis;
  if (-e $in_bible) {
    my $bible = $XML_PARSER->parse_file($in_bible);
    # Get all books found in the Bible
    my %bks;
    foreach my $bk ($XPC->findnodes('//osis:div[@type="book"]', $bible)) {
      $bks{$bk->getAttribute('osisID')}++;
    }
    # Get all chapter and verse osisIDs
    my %ids;
    foreach my $v ($XPC->findnodes('//osis:verse[@osisID] | //osis:chapter[@osisID]', $bible)) {
      foreach my $id (split(/\s+/, $v->getAttribute('osisID'))) {$ids{"$MAINMOD:$id"}++;}
    }
    
    # Check Scripture references in the original text (not those added by addCrossRefs)
    $osis = $XML_PARSER->parse_file($in_osis);
    foreach my $sref ($XPC->findnodes('//osis:reference[not(starts-with(@type, "x-gloss"))][not(ancestor::osis:note[@resp])][@osisRef]', $osis)) {
      $checked++;
      # check beginning and end of range, but not each verse of range (since verses within the range may be purposefully missing)
      my $oref = $sref->getAttribute('osisRef');
      foreach my $id (split(/\-/, $oref)) {
        $id = ($id =~ /\:/ ? $id:"$MAINMOD:$id");
        my $bk = ($id =~ /\:([^\.]+)/ ? $1:'');
        if (!$bk) {
          &ErrorBug("Failed to parse reference from book: $id !~ /\:([^\.]+)/ in $sref.");
        }
        elsif (!$bks{$bk}) {
          &Warn("<>Marking hyperlinks to missing book: $bk", 
"<>Apparently not all 66 Bible books have been included in this 
project, but there are references in the source text to these missing 
books. So these hyperlinks will be marked as x-external until the 
other books are added to the translation.");
          if ($sref->getAttribute('subType') && $sref->getAttribute('subType') ne 'x-external') {
            &ErrorBug("Overwriting subType ".$sref->getAttribute('subType')." with x-external in $sref");
          }
          $sref->setAttribute('subType', 'x-external');
          $changes++;
        }
        elsif (!$ids{$id}) {
          $problems++;
          &Error(
"Scripture reference in source text targets a nonexistant verse: \"$id\"", 
"Maybe this should not have been parsed as a Scripture 
reference, or maybe it was mis-parsed by CF_addScripRefLinks.txt? Or 
else this is a problem with the source text: 
".$sref);
        }
      }
    }
  }
  else {
    $problems++;
    &Error("Cannot check Scripture reference targets because unable to locate $MAINMOD.xml.", "Run sfm2osis on $MAINMOD to generate an OSIS file.");
  }
  
  if ($osis && $changes) {&writeXMLFile($osis, $in_osis);}
  
  &Report("$checked Scripture references checked. ($problems problems)\n");
}

sub removeMissingOsisRefs {
  my $osisP = shift;
  
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my @badrefs = $XPC->findnodes('//osis:reference[not(@osisRef)]', $xml);
  if (!@badrefs[0]) {return;}
  
  &Error("There are ".@badrefs." reference element(s) without osisRef attributes. These reference tags will be removed!", 
"Make sure SET_addScripRefLinks is set to 'true' in CF_usfm2osis.txt, so that reference osisRefs will be parsed.");
  
  foreach my $r (@badrefs) {
    my @children = $r->childNodes();
    foreach my $child (@children) {$r->parentNode->insertBefore($child, $r);}
    $r->unbindNode();
  }
  
  &writeXMLFile($xml, $osisP);
}

sub reportReferences {
  my $refcntP = shift;
  my $errorsP = shift;
  
  my $total = 0; my $errtot = 0;
  foreach my $type (sort keys (%{$refcntP})) {
    &Report("<-\"".$refcntP->{$type}."\" ${type}s checked. (".($errorsP->{$type} ? $errorsP->{$type}:0)." problems)");
    $total += $refcntP->{$type}; $errtot += $errorsP->{$type};
  }
  &Report("<-\"$total\" Grand total osisRefs checked. (".($errtot ? $errtot:0)." problems)");
}


sub writeMissingNoteOsisRefsFAST {
  my $osisP = shift;
  
  &Log("\nWriting missing note osisRefs in OSIS file \"$$osisP\".\n", 1);
  
  my @files = &splitOSIS($$osisP);
  
  my $count = 0;
  foreach my $file (@files) {
    my $xml;
    my $element = &splitOSIS_element($file, \$xml);
    if ($element->hasAttribute('osisID')) {
      &Log($element->getAttribute('osisID')."\n", 2);
    }
    $count += &writeMissingNoteOsisRefs($element);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($osisP);
  
  &Report("Wrote \"$count\" note osisRefs.");
}

# A note's osisRef points to the passage to which a note applies. For 
# glossaries this is the note's context keyword. For Bibles this is also 
# the note's context, unless the note contains a reference of type 
# annotateRef, in which case the note applies to the annotateRef passage.
sub writeMissingNoteOsisRefs {
  my $xml = shift;
  
  my @notes = $XPC->findnodes('descendant::osis:note[not(@osisRef)]', $xml);
  my $refSystem = &getOsisRefSystem($xml);
  
  my $count = 0;
  foreach my $note (@notes) {
    my $osisRef;
    if (&isBible($xml)) {
      # need an actual osisID, so bibleContext output needs fixup
      $osisRef = @{&atomizeContext(&bibleContext($note))}[0];
      if ($osisRef =~ /(BIBLE_INTRO|TESTAMENT_INTRO)/) {
        $osisRef = '';
      }
      $osisRef =~ s/(\.0)+$//;
    }
    if (!$osisRef) {
      $osisRef = @{&atomizeContext(&otherModContext($note))}[0];
    }
    
    # Check if Bible annotateRef should override verse context
    my $con_bc; my $con_vf; my $con_vl;
    if (&isBible($xml) && $osisRef =~ /^($OSISBOOKSRE)\.\d+\.\d+$/) {
      # get notes's context
      $con_bc = &bibleContext($note);
      if ($con_bc !~ /^(($OSISBOOKSRE)\.\d+)(\.(\d+)(\.(\d+))?)?$/) {$con_bc = '';}
      else {
        $con_bc = $1;
        $con_vf = $4;
        $con_vl = $6;
        if ($con_vf == 0 || $con_vl == 0) {$con_bc = '';}
      }
    }
    if ($con_bc) {
      # let annotateRef override context if it makes sense
      my $aror;
      my $rs = @{$XPC->findnodes('descendant::osis:reference[1][@type="annotateRef" and @osisRef]', $note)}[0];
      if ($rs) {
        $aror = $rs->getAttribute('osisRef');
        $aror =~ s/^[\w\d]+\://;
        if ($aror =~ /^([^\.]+\.\d+)(\.(\d+)(-\1\.(\d+))?)?$/) {
          my $ref_bc = $1; my $ref_vf = $3; my $ref_vl = $5;
          if (!$ref_vf) {$ref_vf = 0;}
          if (!$ref_vl) {$ref_vl = $ref_vf;}
          if ($rs->getAttribute('annotateType') ne $ANNOTATE_TYPE{'Source'} && ($con_bc ne $ref_bc || $ref_vl < $con_vf || $ref_vf > $con_vl)) {
            &Warn("writeMissingNoteOsisRefs: Note's annotateRef \"".$rs."\" is outside note's context \"$con_bc.$con_vf.$con_vl\"");
            $aror = '';
          }
        }
        else {
          &Warn("writeMissingNoteOsisRefs: Unexpected annotateRef osisRef found \"".$rs."\"");
          $aror = '';
        }
      }
      
      $osisRef = ($aror ? $aror:"$con_bc.$con_vf".($con_vl != $con_vf ? "-$con_bc.$con_vl":''));
    }

    $note->setAttribute('osisRef', $osisRef);
    $count++;
  }
  
  return $count;
}

sub removeDefaultWorkPrefixesFAST {
  my $osisP = shift;
  
  &Log("\nRemoving default work prefixes in OSIS file \"$$osisP\".\n", 1);
  
  my @files = &splitOSIS($$osisP);
  
  my %stats = ('osisRef'=>0, 'osisID'=>0);
  
  foreach my $file (@files) {
    my $xml; my $filter;
    my $element = &splitOSIS_element($file, \$xml, \$filter);
    if ($element->hasAttribute('osisID')) {
      &Log($element->getAttribute('osisID')."\n", 2);
    }
    &removeDefaultWorkPrefixes($element, \%stats, $filter);
    &writeXMLFile($xml, $file);
  }
  
  &joinOSIS($osisP);
  
  &Report("Removed \"".$stats{'osisRef'}."\" redundant Work prefixes from osisRef attributes.");
  &Report("<-Removed \"".$stats{'osisID'}."\" redundant Work prefixes from osisID attributes.");
}

# Removes work prefixes of all osisIDs and osisRefs which match their
# respective osisText osisIDWork or osisRefWork attribute value (in 
# other words removes work prefixes which are unnecessary).
sub removeDefaultWorkPrefixes {
  my $xml = shift;
  my $statsP = shift;
  my $filter = shift;
  
  # normalize osisRefs
  my @osisRefs = $XPC->findnodes("descendant-or-self::*${filter}/\@osisRef", $xml);
  my $osisRefWork = &getOsisRefWork($xml);
  my $normedOR = 0;
  foreach my $osisRef (@osisRefs) {
    if ($osisRef->getValue() !~ /^$osisRefWork\:/) {next;}
    my $new = $osisRef->getValue();
    $new =~ s/^$osisRefWork\://;
    $osisRef->setValue($new);
    $statsP->{'osisRef'}++;
  }
  
  # normalize osisIDs
  my @osisIDs = $XPC->findnodes("descendant-or-self::*${filter}/\@osisID", $xml);
  my $osisIDWork = &getOsisIDWork($xml);
  my $normedID = 0;
  foreach my $osisID (@osisIDs) {
    if ($osisID->getValue() !~ /^$osisIDWork\:/) {next;}
    my $new = $osisID->getValue();
    $new =~ s/^$osisIDWork\://;
    $osisID->setValue($new);
    $statsP->{'osisID'}++;
  }
}

1;
