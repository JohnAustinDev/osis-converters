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
sub addCrossRefs($$) {
  my $in_osis = shift;
  my $out_osis = shift;

  &Log("\n--- ADDING CROSS REFERENCES\n-----------------------------------------------------\n\n", 1);
  
  my $CrossRefFile = (!$VERSESYS ? "KJV":$VERSESYS);
  my @try = (
    "$INPD/Cross_References/$CrossRefFile.xml",
    "$INPD/../Cross_References/$CrossRefFile.xml",
    "$INPD/../../Cross_References/$CrossRefFile.xml",
    "$SCRD/scripts/CrossReferences/$CrossRefFile.xml",
  );
  foreach my $t (@try) {if (-e $t) {$CrossRefFile = $t; last}}
  if (!-e $CrossRefFile) {
    &Log("
WARNING: Could not locate a Cross Reference source file- skipping cross-reference insertion.
NOTE: Cross Reference source files are OSIS files containing only cross-references.  
They have the name of their SWORD Versification system, and are typically placed in the 
osis-converters/scripts/CrossReferences directory. If reference tags do not contain
presentational text, it will be added. Example OSIS cross-references:

<div type=\"book\" osisID=\"Gen\">
  <chapter osisID=\"Gen.1\">
  
    <note type=\"crossReference\" osisRef=\"Gen.1.27\" osisID=\"Gen.1.27!crossReference.r1\">
      <reference osisRef=\"SynodalProt:Matt.19.4\"/>
      <reference osisRef=\"SynodalProt:Mark.10.6\"/>
    </note>
    
    <note type=\"crossReference\" subType=\"x-parallel-passage\" osisRef=\"Gen.36.1\" osisID=\"Gen.36.1!crossReference.p1\">
      <reference osisRef=\"1Chr.1.35-1Chr.1.37\" type=\"parallel\"/>
   </note>
   
  </chapter>
</div>
");
    return 0;
  }

  &Log("READING OSIS FILE: \"$in_osis\".\n");
  my $osis = $XML_PARSER->parse_file($in_osis);
  &Log("You are including cross references for ".@{$XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work[@osisWork=/osis:osis/osis:osisText/@osisIDWork]/osis:scope', $osis)}[0]->textContent.".\n");

  # Any presentational text will be removed from cross-references. Then localized  
  # note text will be added using Paratext meta-data and/or \toc tags.
  my %localization;
  my $tocxr = ($tocCrossRefs ? (1*$tocCrossRefs):3);
  my @toc3 = $XPC->findnodes('//osis:div[@type="book"][descendant::osis:milestone[@type="x-usfm-toc'.$tocxr.'"]]', $osis);
  if ($BOOKNAMES || @toc3[0]) {
    &Log("NOTE: Applying localization to all cross references (count of BOOKNAMES=\"".scalar(%BOOKNAMES)."\", count of book toc".$tocxr." tags=\"".scalar(@toc3)."\").\n");
    $localization{'hasLocalization'}++;
    my $ssf;
    if (opendir(SFM, "$INPD/sfm")) {
      my @fs = readdir(SFM);
      foreach my $f (@fs) {
        if (-d "$INPD/sfm/$f") {next;}
        $ssf = `grep "<RangeIndicator>" "$INPD/sfm/$f"`;
        if ($ssf) {
          $ssf = $XML_PARSER->parse_file("$INPD/sfm/$f");
          &Log("NOTE: Reading localized Scripture reference settings from \"$INPD/sfm/$f\"\n");
          last;
        }
      }
      closedir(SFM);
    }
    
    my %elems = (
      'RangeIndicator' => '-', 
      'SequenceIndicator' => ',', 
      'ReferenceFinalPunctuation' => '.', 
      'ChapterNumberSeparator' => '; ', 
      'ChapterRangeSeparator' => '—', 
      'ChapterVerseSeparator' => ':',
      'BookSequenceSeparator' => '; '
    );
    
    foreach my $k (keys %elems) {
      $v = $elems{$k};
      if ($ssf) {
        my $kv = @{$XPC->findnodes("$k", $ssf)}[0];
        if ($kv && $kv->textContent) {$v = $kv->textContent;}
      }
      $localization{$k} = $v;
    }
    
    my $nametype = ('', 'long', 'short', 'abbr')[$tocxr];
    my @books = split(' ', $OT_BOOKS . ' ' . $NT_BOOKS);
    foreach my $book (@books) {
      my $abbr = @{$XPC->findnodes('//osis:div[@type="book"][@osisID="'.$book.'"]/descendant::osis:milestone[@type="x-usfm-toc'.$tocxr.'"][1]/@n', $osis)}[0];
      if ($abbr) {$abbr = $abbr->value;}
      if ($BOOKNAMES{$book}{$nametype}) {
        if (!$abbr) {$abbr = $BOOKNAMES{$book}{$nametype};}
        elsif ($abbr ne $BOOKNAMES{$book}{$nametype}) {
          &Log("WARNING: OSIS toc$tocxr name \"$abbr\" differs from SSF $nametype name \"".$BOOKNAMES{$book}{$nametype}."\"; will use OSIS name.\n");
        }
      }
      if ($abbr) {$localization{$book} = $abbr;}
      else {&Log("WARNING: Missing translation for \"$book\"\n");}
    }
  }
  else {
    &Log(decode('utf8', "
WARNING: Unable to localize cross-references! This means eBooks will show cross-references
         as '1', '2'... which is unhelpful. To localize cross-references, you should add 
         a file called BookNames.xml to $INPD/sfm containing book abbreviations like this:
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<BookNames>
  <book code=\"1SA\" abbr=\"1Şam\" />
  <book code=\"2SA\" abbr=\"2Şam\" />
</BookNames>
         If you do not know the book abbreviations, then add to $INPD/CF_usfm2osis.txt
         the following: \"SET_tocCrossRefs:2\" to use \\toc2 short names instead of 
         abbreviations (or 1 will use \\toc1 long names, but this is not recommended). 
         If the required \\tocN tags are specified in the USFM files, you  do not 
         need BookNames.xml.\n\n"));
  }
  
  # for a big speed-up, find all verse tags and add them to a hash with a key for every verse
  my %verses;
  foreach my $v ($XPC->findnodes('//osis:verse', $osis)) {
    my $type = 'start'; my $seID = $v->getAttribute('sID');
    if (!$seID) {$type = 'end'; $seID = $v->getAttribute('eID');}
    foreach my $osisIDV (split(/\s+/, $seID)) {$verses{$osisIDV}{$type} = $v;}
  }

  &Log("READING CROSS REFERENCE FILE \"$CrossRefFile\".\n");
  my $xml = $XML_PARSER->parse_file($CrossRefFile);
  
  foreach my $alt ($XPC->findnodes('//osis:hi[@subType="x-alternate"]', $osis)) {
    $INSERT_NOTE_SPEEDUP{@{$XPC->findnodes('following::osis:verse[@eID][1]', $alt)}[0]->getAttribute('eID')}++;
  }
  
  # discover which verses were moved by translators from their fixed verse-system positions
  my %verseWasMovedTo;
  my $movedP = &getMovedVersesOSIS($osis);
  foreach my $moved (keys %{$movedP->{'fromTo'}}) {
    $verseWasMovedTo{$moved}{'dest'} = $movedP->{'fromToFixed'}{$moved};
    $verseWasMovedTo{$moved}{'valt'} = $movedP->{'fromTo'}{$moved}
  }
  
  my $osisBooksHP = &getBooksOSIS($osis);
  foreach my $note ($XPC->findnodes('//osis:note', $xml)) {
    foreach my $t ($note->childNodes()) {if ($t->nodeType == XML::LibXML::XML_TEXT_NODE) {$t->unbindNode();}}
    
    # decide where to place this note
    my $valt = 0;
    my $placement = $note->getAttribute('osisID');
    $placement =~ s/^(.*?)(\!.*)?$/$1/;
    $placement =~ s/^[^\:]*\://;
    if ($verseWasMovedTo{$placement}) {
      $valt = $verseWasMovedTo{$placement}{'valt'};
      $placement = $verseWasMovedTo{$placement}{'dest'};
    }
    
    # check and filter the note placement
    if ($placement =~ /\.0\b/) {
      &Log("ERROR: Cross reference notes should not be placed in an introduction \"$placement\"\n");
      next;
    }
    if ($placement !~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      &Log("ERROR: crossReference has unexpected osisRef \"$osisRef\"\n");
      next;
    }
    my $b = $1; my $c = $2; my $v = $3;
    if (!$osisBooksHP->{$b}) {next;}
    if (!$verses{$placement}) {&Log("ERROR: $placement: Target verse not found.\n"); next;}
    
    # add annotateRef so readers know where the note belongs
    if ($localization{'hasLocalization'}) {
      my $anotateRef = "<reference osisRef=\"$placement\" type=\"annotateRef\">$c".$localization{'ChapterVerseSeparator'}."$v</reference> ";
      $note->insertBefore($XML_PARSER->parse_balanced_chunk($anotateRef), $note->firstChild);
    }
    
    # add resp attribute, which identifies this note as an external note
    $note->setAttribute('resp', &getOsisIDWork($xml)."-".&getVerseSystemOSIS($xml));
    
    &insertNote($note, \%{$verses{$placement}}, $valt, \%localization);
  }

  &Log("WRITING NEW OSIS FILE: \"$out_osis\".\n");
  if (open(OUTF, ">$out_osis")) {
    print OUTF $osis->toString();
    close(OUTF);
  }
  else {&Log("ERROR: Could not open \"$out_osis\" for writing.\n");}

  $ADD_CROSS_REF_LOC = ($ADD_CROSS_REF_LOC ? $ADD_CROSS_REF_LOC:0);
  $ADD_CROSS_REF_NUM = ($ADD_CROSS_REF_NUM ? $ADD_CROSS_REF_NUM:0);
  &Log("\n$MOD REPORT: Placed $ADD_CROSS_REF_NUM cross-reference notes.\n");
  if ($ADD_CROSS_REF_BAD) {
    &Log("WARNING: $ADD_CROSS_REF_LOC individual reference links were localized but $ADD_CROSS_REF_BAD could only be numbered.\n\n");
  }
  else {
    &Log("NOTE: $ADD_CROSS_REF_LOC individual reference links were localized.\n\n");
  }
  
  return 1;
}

# Insert the note near the beginning or end of the verse depending on type.
# Normal cross-references go near the end, but parallel passages go near the 
# beginning of the verse. Sometimes a verse contains alternate verses within
# itself, and in this case, altVerse is used to place the note within the 
# appropriate alternate verse.
sub insertNote($\$) {
  my $note = shift;
  my $verseHP = shift;
  my $altVerse = shift;
  my $localeP = shift;
  
  my $verseNum = ($altVerse =~ s/^.*?\.(\d+)$// ? $1:'');
  
  # add readable reference text to the note's references (required by some front ends and eBooks)
  my @refs = $XPC->findnodes('osis:reference[@osisRef][not(@type="annotateRef")]', $note);
  for (my $i=0; $i<@refs; $i++) {
    my $ref = @refs[$i];
    my $osisRef = $ref->getAttribute('osisRef');
    if ($osisRef =~ s/^.*?://) {$ref->setAttribute('osisRef', $osisRef);}
    foreach my $child ($ref->childNodes()) {$child->unbindNode();}
    my $t;
    if ($localeP->{'hasLocalization'}) {
      my $tr = &translateRef($osisRef, $localeP);
      if ($tr) {$ADD_CROSS_REF_LOC++;} else {$ADD_CROSS_REF_BAD++;}
      $t = ($i==0 ? '':' ') . ($tr ? $tr:($i+1)) . ($i==@refs-1 ? '':$localeP->{'SequenceIndicator'});
    }
    else {$t = sprintf("%i%s", $i+1, ($i==@refs-1 ? '':','));}
    $ref->insertAfter(XML::LibXML::Text->new($t), undef);
  }

  # insert note in the right place
  # NOTE: the crazy looking while loop approach, and not using normalize-space() but rather $nt =~ /^\s*$/, greatly increases processing speed
  if ($note->getAttribute('subType') eq 'x-parallel-passage') {
    my $start = $verseHP->{'start'};
    if ($verseNum) {
      while (my $alt = @{$XPC->findnodes('following::osis:hi[@subType="x-alternate"][1][following::osis:verse[1][@eID="'.$verseHP->{'end'}->getAttribute('eID').'"]]', $start)}[0]) {
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
    else {&Log("ERROR: Could not place para note \"".$note->toString()."\"\n");}
  }
  else {
    my $end = $verseHP->{'end'};
    if ($INSERT_NOTE_SPEEDUP{$verseHP->{'end'}->getAttribute('eID')}) {
      while (my $alt = @{$XPC->findnodes('preceding::osis:hi[@subType="x-alternate"][1][preceding::osis:verse[1][@sID="'.$verseHP->{'start'}->getAttribute('sID').'"]]', $end)}[0]) {
        if (!$alt || ($verseNum && $alt->textContent =~ /\b$verseNum\b/)) {last;}
        $end = $alt;
      }
    }
    $pt = @{$XPC->findnodes('preceding::text()[1]', $end)}[0];
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
    else {&Log("ERROR: Could not place norm note \"".$note->toString()."\"\n");}
  }
}

sub translateRef($$) {
  my $osisRef = shift;
  my $localeP = shift;
  
  my $t = '';
  if ($osisRef =~ /^([\w\.]+)(\-([\w\.]+))?$/) {
    my $r1 = $1; my $r2 = ($2 ? $3:'');
    $t = &translateSingleRef($r1, $localeP);
    if ($t && $r2) {
      my $t2 = &translateSingleRef($r2, $localeP);
      if ($t2) {
        if ($t =~ /^(.*?)\d+$/) {
          my $baseRE = "^$1(\\d+)\$";
          if ($t2 =~ /$baseRE/) {$t2 = $1;}
        }
        $t .= $localeP->{'RangeIndicator'} . $t2;
      }
      else {$t = '';}
    }
  }
  else {
    &Log("ERROR translateRef: malformed osisRef \"$osisRef\"\n");
  }
  
  return $t;
}

sub translateSingleRef($$) {
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
    &Log("ERROR translateSingleRef: malformed osisRef \"".$osisRefSingle."\"\n");
  }
  
  return $t;
}

1;
