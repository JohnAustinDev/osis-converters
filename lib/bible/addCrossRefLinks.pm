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

# This function adds cross-reference notes to a Bible OSIS file. But
# for valid cross-references to be added, the following requirements 
# must be met:
# 1) A set of cross-reference OSIS notes must be supplied in the form of 
#    an external xml file.
# 2) The external cross-reference notes must all exactly follow one of 
#    the standard SWORD verse systems (such as KJV, Synodal or SynodalProt).
# 3) The Bible OSIS file must exactly match the SWORD verse system of  
#    the cross-references.
# 4) The previous requirement means that if the Bible contains any verses 
#    which follow a different verse system than the cross-references 
#    (and this is very common), then those sections must have been marked
#    up and fitted by the fitToVerseSystem() function. However, in this 
#    case, the added cross-reference notes will be placed in the alternate 
#    location (and external references to verses in alternate locations 
#    will later also be modified to target that alternate location by 
#    correctReferencesVSYS() ).

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($XPC, $XML_PARSER, %OSIS_GROUP, %BOOKNAMES, $ONS);

my (%INSERT_NOTE_SPEEDUP, $ADD_CROSS_REF_LOC, $ADD_CROSS_REF_BAD,
   $ADD_CROSS_REF_NUM);
   
sub runAddCrossRefLinks {
  my $osisP = shift;

  &Log("\n--- ADDING CROSS REFERENCES\n-----------------------------------------------------\n\n", 1);
  
  my $def = "bible/Cross_References/".&conf('Versification').".xml";
  my $CrossRefFile = &getDefaultFile($def, -1);
  if (!-e $CrossRefFile) {
    &Warn("Could not locate a Cross Reference source file: $def", "
The cross reference source file is an OSIS file that contains only 
cross-references for the necessary verse system: ".&conf('Versification').". Without 
one, cross-references will not be added to the text. It should be 
typically placed in the following directory:
osis-converters/defaults/bible/CrossReferences/".&conf('Versification').".xml
The reference tags in the file do not need to contain presentational 
text, because it would be replaced with localized text anyway. 
Example OSIS cross-references:

<div type=\"book\" osisID=\"Gen\">
  <chapter osisID=\"Gen.1\">
  
    <note type=\"crossReference\" osisRef=\"Gen.1.27\" osisID=\"Gen.1.27!crossReference.r1\">
      <reference osisRef=\"Matt.19.4\"/>
      <reference osisRef=\"Mark.10.6\"/>
    </note>
    
    <note type=\"crossReference\" subType=\"x-parallel-passage\" osisRef=\"Gen.36.1\" osisID=\"Gen.36.1!crossReference.p1\">
      <reference osisRef=\"1Chr.1.35-1Chr.1.37\" type=\"parallel\"/>
   </note>
   
  </chapter>
</div>
");
    return 0;
  }
  
  my $bookNamesMsg = decode('utf8', 
"Cross-references are localized using a file called 
BookNames.xml in the sfm directory which should contain localized 
'abbr' abbreviations for all 66 Bible books, like this:

<?xml version=\"1.0\" encoding=\"utf-8\"?>
<BookNames>
  <book code=\"1SA\" abbr=\"1Şam\" />
  <book code=\"2SA\" abbr=\"2Şam\" />
</BookNames>
");

  &Log("READING OSIS FILE: \"$$osisP\".\n");
  my $osis = $XML_PARSER->parse_file($$osisP);
  &Log("You are including cross references for ".@{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[@osisWork=/osis:osis/osis:osisText/@osisIDWork]/osis:scope', $osis)}[0]->textContent.".\n");

  # Any presentational text will be removed from cross-references. Then localized  
  # note text will be added using Paratext meta-data and/or \toc tags.
  my $localizationP = &readParatextReferenceSettings();
  foreach my $x (sort keys %{$localizationP}) {&Note("Using Paratext setting $x = '".$localizationP->{$x}."'");}
  
  # find the shortest name in BOOKNAMES and x-usfm-toc milestones, prefering BOOKNAMES when equal length
  my $countLocalizedNames = 0;
  my @bntypes = ('long', 'short', 'abbr');
  my @books; push(@books, @{%OSIS_GROUP{'OT'}}, @{%OSIS_GROUP{'NT'}});
  foreach my $book (@books) {
    my %osisName;
    for (my $x=1; $x<=3; $x++) {
      my $n = @{$XPC->findnodes('//osis:div[@type="book"][@osisID="'.$book.'"]/descendant::osis:milestone[@type="x-usfm-toc'.$x.'"][1]/@n', $osis)}[0];
      if ($n) {$osisName{'toc'.$x} = $n->value;}
    }
    my $shortName;
    for (my $x=1; $x<=3; $x++) {
      if (!$osisName{'toc'.$x}) {next;}
      if ($shortName && length($shortName) < length($osisName{'toc'.$x})) {next;}
      $shortName = $osisName{'toc'.$x};
    }
    for (my $x=0; $x<@bntypes; $x++) {
      if (!$BOOKNAMES{$book}{@bntypes[$x]}) {next;}
      if ($shortName && length($shortName) < length($BOOKNAMES{$book}{@bntypes[$x]})) {next;}
      $shortName = $BOOKNAMES{$book}{@bntypes[$x]};
    }
    if ($shortName) {
      if (!$osisName{'toc3'} && !$BOOKNAMES{$book}{@bntypes[2]}) {
        &Warn("A localized book abbreviation for \"$book\" was not found in a \\toc3 USFM tag or 'abbr' attribute of BookNames.xml file.", 
"<>A Longer book name will be used instead. This will increase
the length of externally added cross-reference notes considerably. If 
you want to shorten them, supply either an 'abbr' attribute value to 
BookNames.xml or add a \\toc3 USFM tag to the top of the USFM file, with 
the abbreviation.");
      }
    
      $countLocalizedNames++;
      $localizationP->{$book} = $shortName;
      &Note("$book = $shortName");
    }
    else {&Warn("Missing translation for \"$book\".", 
"<>That all 66 Bible books have, preferably, the 'abbr' attribute set 
in BookNames.xml. Or else another attribute in BookNames.xml will be 
used, if available, or else \\toc1, \\toc2 or \\toc3 tags in SFM files
will be used. Since none of these were found for some books, some 
cross-references will be unreadable.\n$bookNamesMsg");}
  }
  
  if ($countLocalizedNames == 66) {
    &Note("Applying localization to all cross references.");
  }
  else {
    &Warn("Unable to localize all book names.\n", $bookNamesMsg);
  }
  
  # for a big speed-up, find all verse tags and add them to a hash with a key for every verse
  my %verses;
  foreach my $v ($XPC->findnodes('//osis:verse', $osis)) {
    my $type = 'start'; my $seID = $v->getAttribute('sID');
    if (!$seID) {$type = 'end'; $seID = $v->getAttribute('eID');}
    foreach my $osisIDV (split(/\s+/, $seID)) {$verses{$osisIDV}{$type} = $v;}
  }
  
  # get all books found in the Bible
  my %books;
  foreach my $bk ($XPC->findnodes('//osis:div[@type="book"]', $osis)) {
    $books{$bk->getAttribute('osisID')}++;
  }

  &Log("READING CROSS REFERENCE FILE \"$CrossRefFile\".\n");
  my $xml = $XML_PARSER->parse_file($CrossRefFile);
  
  foreach my $alt ($XPC->findnodes('//osis:hi[@subType="x-alternate"]', $osis)) {
    $INSERT_NOTE_SPEEDUP{@{$XPC->findnodes('following::osis:verse[@eID][1]', $alt)}[0]->getAttribute('eID')}++;
  }
  
  my $osisBooksHP = &getOsisBooks($osis);
NOTE:
  foreach my $note ($XPC->findnodes('//osis:note', $xml)) {
    foreach my $t ($note->childNodes()) {
      if ($t->nodeType == XML::LibXML::XML_TEXT_NODE) {$t->unbindNode();}
    }
    
    # decide where to place this note
    my $fixed = $note->getAttribute('osisID');
    $fixed =~ s/^(.*?)(\!.*)?$/$1/;
    $fixed =~ s/^[^\:]*\://;
    
    # unless the entire target osisRef is included in the source verse system, skip this note
    foreach my $r (split(/\s+/, &osisRef2osisID($note->getAttribute('osisRef')))) {
      if (defined(&getAltVersesOSIS($osis)->{'fixedMissing'}{$r})) {
        &Note("Skipping external cross-reference note for missing verse $r");
        next NOTE;
      }
    }
    
    # map crossReferences to be placed within verses that were moved by translators from their fixed verse-system positions
    my $placement = &getAltVersesOSIS($osis)->{'fixed2Fitted'}{$fixed};
    if (!$placement) {$placement = $fixed;}
    
    # check and filter the note placement
    if ($placement =~ /\.0\b/) {
      &ErrorBug("Cross reference notes should not be placed in an introduction: $placement =~ /\.0\b/");
      next;
    }
    if ($placement !~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      &ErrorBug("CrossReference has unexpected placement: $placement !~ /^([^\.]+)\.(\d+)\.(\d+)\$/");
      next;
    }
    my $b = $1; my $c = $2; my $v = $3;
    if (!$osisBooksHP->{$b}) {next;}
    if (!$verses{$placement}) {next;}
    
    # add annotateRef so readers know where the note belongs
    my $annotateRef = &getAltVersesOSIS($osis)->{'fixed2Source'}{$fixed}; $annotateRef =~ s/!PART$//;
    if (!$annotateRef) {$annotateRef = $fixed};
    if ($annotateRef =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      my $bk = $1; my $ch = $2; my $vs = $3;
      # later, the fixed verse system osisRef here will get mapped and annotateRef added, by correctReferencesVSYS()
      my $elem = "<reference $ONS osisRef='$fixed' type='annotateRef'>$ch$localizationP->{'ChapterVerseSeparator'}$vs</reference> ";
      $note->insertBefore($XML_PARSER->parse_balanced_chunk($elem), $note->firstChild);
    }
    
    # add readable reference text to the note's references (required by some front ends and eBooks)
    # and remove hyperlinks for references whose osisRefs are not included in the translation yet
    my @refs = $XPC->findnodes('osis:reference[@osisRef][not(@type="annotateRef")]', $note);
    for (my $i=0; $i<@refs; $i++) {
      my $ref = @refs[$i];
      my $osisRef = $ref->getAttribute('osisRef');
      my $book = $osisRef; $book =~ s/^([^\.]+)\..*?$/$1/;
      if ($osisRef =~ s/^.*?://) {$ref->setAttribute('osisRef', $osisRef);}
      foreach my $child ($ref->childNodes()) {$child->unbindNode();}

      # later, osisRef attribute value will get mapped and an annotateRef attribute added as necessary, by correctReferencesVSYS()
      my $readRef = &mapOsisRef(&getAltVersesOSIS($osis), 'fixed2Source', $osisRef); $readRef =~ s/!PART$//;
      my $tr = &translateRef($readRef, $localizationP, &conf('Versification'));
      if ($tr) {$ADD_CROSS_REF_LOC++;} else {$ADD_CROSS_REF_BAD++;}
      my $t = ($i==0 ? '':' ') . ($tr ? $tr:($i+1)) . ($i==@refs-1 ? '':$localizationP->{'SequenceIndicator'});
      
      $t = XML::LibXML::Text->new($t);
      $ref->insertAfter($t, undef);
      if (!$books{$book}) {
        &Warn("<>Marking hyperlinks to missing book: $book",
"<>Apparently not all 66 Bible books have been included in this 
project, but there are externally added cross references to these missing 
books. So these hyperlinks will be marked as x-external until the 
other books are added to the translation.");
        if ($ref->getAttribute('subType') && $ref->getAttribute('subType') ne 'x-external') {
          &ErrorBug("Overwriting subType ".$ref->getAttribute('subType')." with x-external in $ref");
        }
        $ref->setAttribute('subType', 'x-external');
      }
    }
      
    # add resp attribute, which identifies this note as an external note
    $note->setAttribute('resp', &getOsisIDWork($xml)."-".&getOsisVersification($xml));  
    
    &insertNote($note, \%{$verses{$placement}}, &getAltVersesOSIS($osis)->{'fixed2Source'}{$fixed});
  }

  &writeXMLFile($osis, $osisP);
  &Log("WRITING NEW OSIS FILE: \"$$osisP\".\n");

  $ADD_CROSS_REF_LOC = ($ADD_CROSS_REF_LOC ? $ADD_CROSS_REF_LOC:0);
  $ADD_CROSS_REF_NUM = ($ADD_CROSS_REF_NUM ? $ADD_CROSS_REF_NUM:0);
  &Report("Placed $ADD_CROSS_REF_NUM cross-reference notes.");
  &Note("$ADD_CROSS_REF_LOC individual reference links were localized.");
  if ($ADD_CROSS_REF_BAD) {
    &Warn("$ADD_CROSS_REF_BAD reference links could not be localized and will appear as numbers, like: '1, 2, 3' unless x-external links are filtered out.");
  }
  
  return 1;
}

# Insert the note near the beginning or end of the verse depending on type.
# Normal cross-references go near the end, but parallel passages go near the 
# beginning of the verse. Sometimes a verse contains alternate verses within
# itself, and in this case, verseNum is used to place the note within the 
# appropriate alternate verse.
sub insertNote {
  my $note = shift;
  my $verseP = shift;
  my $sourceID = shift;
  
  my $verseNum = ($sourceID && $sourceID =~ /\.(\d+)(!PART)?$/ ? $1:'');

  # insert note in the right place
  # NOTE: the crazy looking while loop approach, and not using normalize-space() but rather $nt =~ /^\s*$/, greatly increases processing speed
  if ($note->getAttribute('subType') eq 'x-parallel-passage') {
    my $start = $verseP->{'start'};
    if ($verseNum) {
      while (my $alt = @{$XPC->findnodes('following::osis:hi[@subType="x-alternate"][1][following::osis:verse[1][@eID="'.$verseP->{'end'}->getAttribute('eID').'"]]', $start)}[0]) {
        $start = $alt;
        if ($start->textContent =~ /\b$verseNum\b/) {last;}
      }
    }
    my $nt = @{$XPC->findnodes('following::text()[1]', $start)}[0];
    while ($nt) {
      if ($nt =~ /^\s*$/ || (my $title = @{$XPC->findnodes('ancestor::osis:title[not(@canonical="true")]', $nt)}[0])) { # next text
        $nt = @{$XPC->findnodes('following::text()[1]', $nt)}[0];
      }
      elsif (my $n = @{$XPC->findnodes('ancestor::osis:note', $nt)}[0]) {$n->parentNode->insertAfter($note, $n); last;} # insert after
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $nt)}[0]) {$reference->parentNode->insertBefore($note, $reference); last;} #insert before
      else {$nt->parentNode->insertBefore($note, $nt); last;}
    }
    if ($nt) {$ADD_CROSS_REF_NUM++;}
    else {&ErrorBug("Failed to place parallel passage reference note: \"".$note->toString()."\".");}
  }
  else {
    my $end = $verseP->{'end'};
    if ($INSERT_NOTE_SPEEDUP{$verseP->{'end'}->getAttribute('eID')}) {
      while (my $alt = @{$XPC->findnodes('preceding::osis:hi[@subType="x-alternate"][1][preceding::osis:verse[1][@sID="'.$verseP->{'start'}->getAttribute('sID').'"]]', $end)}[0]) {
        if (!$alt || ($verseNum && $alt->textContent =~ /\b$verseNum\b/) || 
           !@{$XPC->findnodes('preceding::text()[normalize-space()][1][preceding::osis:verse[1][@sID="'.$verseP->{'start'}->getAttribute('sID').'"]]', $alt)}[0]
         ) {last;}
        $end = $alt;
      }
    }
    my $pt = @{$XPC->findnodes('preceding::text()[1]', $end)}[0];
    while ($pt) {
      if ($pt =~ /^\s*$/ || (my $title = @{$XPC->findnodes('ancestor::osis:title[not(@canonical="true")] | ancestor::osis:l[@type="selah"]', $pt)}[0])) { # next text
        $pt = @{$XPC->findnodes('preceding::text()[1]', $pt)}[0];
      }
      elsif (my $n = @{$XPC->findnodes('ancestor::osis:note', $pt)}[0]) {$n->parentNode->insertAfter($note, $n); last;} # insert after
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $pt)}[0]) {$reference->parentNode->insertAfter($note, $reference); last;} # insert after
      else {
        my $punc = '';
        my $txt = $pt->nodeValue();
        if ($txt =~ s/([\.\?\s]+)$//) {
          $punc = $1;
          $pt->setData($txt);
        }
        $pt->parentNode->insertAfter($note, $pt);
        if ($punc) {$note->parentNode->insertAfter(XML::LibXML::Text->new($punc), $note);}
        last;
      }
    }
    if ($pt) {$ADD_CROSS_REF_NUM++;}
    else {&ErrorBug("Failed to place cross reference note: \"".$note->toString()."\".");}
  }
}

sub translateRef {
  my $osisRef = shift;
  my $localeP = shift;
  my $vsys = shift; if (!$vsys) {$vsys = 'KJV';}
  
  my $t = '';
  if ($osisRef =~ /^([\w\.]+)(\-([\w\.]+))?$/) {
    my $r1 = $1; my $r2 = ($2 ? $3:'');
    if ($r1 =~ /^([^\.]+)\.(\d+)\.(\d+)/) {
      my $b1 = $1; my $c1 = $2; my $v1 = $3;
      my $canonP; my $bookOrderP; my $testamentP; &getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP);
      if ($osisRef eq "$b1.$c1.1-$b1.$c1.".$canonP->{$b1}->[$c1-1]) {$r1 = "$b1.$c1"; $r2 = '';}
    }
    $t = &translateSingleRef($r1, $localeP);
    if ($t && $r2) {
      my $t2 = &translateSingleRef($r2, $localeP);
      if ($t2) {
        if ($t =~ /^(.*?)\d+$/) {
          my $baseRE = "^\Q$1\E(\\d+)\$";
          if ($t2 =~ /$baseRE/) {$t2 = $1;}
        }
        $t .= $localeP->{'RangeIndicator'} . $t2;
      }
      else {$t = '';}
    }
  }
  else {
    &ErrorBug("Malformed osisRef: $osisRef !~ /^([\w\.]+)(\-([\w\.]+))?\$/");
  }
  
  return $t;
}

sub translateSingleRef {
  my $osisRefSingle = shift;
  my $localeP = shift;

  my $t = '';
  if ($osisRefSingle =~ /^([^\.]+)(\.([^\.]+)(\.([^\.]+))?)?/) {
    my $b = $1; my $c = ($2 ? $3:''); my $v = ($4 ? $5:'');
    if ($localeP->{$b}) {
      $t = $localeP->{$b} . ($c ? ' ' . $c . ($v ? $localeP->{'ChapterVerseSeparator'} . $v:''):'');
    }
    else {$t = '';}
  }
  else {
    &ErrorBug("Malformed osisRef: $osisRefSingle !~ /^([^\.]+)(\.([^\.]+)(\.([^\.]+))?)?/");
  }
  
  return $t;
}

1;
