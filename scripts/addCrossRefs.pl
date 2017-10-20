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

# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   REMOVE_REFS_TO_MISSING_BOOKS - If set to "true" then cross 
#       references targetting books which are not included in the 
#       OSIS file will NOT be placed in the OSIS file.
#   SFM book name abbreviations (one per line) are to be listed for
#   those books which should have cross-references inserted into them.
#   If no books are listed, then cross-references will be added to 
#   ALL books in the OSIS file.

sub addCrossRefs($$) {
  my $in_osis = shift;
  my $out_osis = shift;
  
  $NumNotes = 0;   

  &Log("\n--- ADDING CROSS REFERENCES\n-----------------------------------------------------\n\n", 1);
  
  my $CrossRefFile = (!$VERSESYS ? "KJV":$VERSESYS);
  my @try = (
    "$INPD/Cross_References/$CrossRefFile.xml",
    "$INPD/../Cross_References/$CrossRefFile.xml",
    "$INPD/../../Cross_References/$CrossRefFile.xml",
    "$SCRD/scripts/CrossReferences/$CrossRefFile.xml",
    "$SCRD/scripts/CrossReferences/CrossRefs_$CrossRefFile.txt"
  );
  foreach my $t (@try) {if (-e $t) {$CrossRefFile = $t; last}}
  if (!-e $CrossRefFile) {
    &Log("
WARNING: Could not locate a Cross Reference source file- skipping cross-reference insertion.
NOTE: Cross Reference source files are OSIS files containing only cross-references.  
They have the name of their SWORD Versification system, and are placed in the 
osis-converters/scripts/CrossReferences directory. If reference tags do not contain
presentational text, it will be added. An example OSIS cross-reference:

<div type=\"book\" osisID=\"Gen\">
  <chapter osisID=\"Gen.1\">
    <note type=\"crossReference\" osisRef=\"Gen.1.27\" osisID=\"Gen.1.27!crossReference.r1\">
      <reference osisRef=\"SynodalProt:Matt.19.4\"/>
      <reference osisRef=\"SynodalProt:Mark.10.6\"/>
    </note>
  </chapter>
</div>
");
    return 0;
  }

  $Booklist = "";
  my $commandFile = "$INPD/CF_addCrossRefs.txt";
  if (-e $commandFile) {
    &Log("READING COMMAND FILE \"$commandFile\"\n");
    &removeRevisionFromCF($commandFile);
    open(COMF, "<:encoding(UTF-8)", $commandFile) or die "Could not open command file \"$commandFile\".\n";
    while (<COMF>) {
      if ($_ =~ /^\s*$/) {next;}
      if ($_ =~ /^\#/) {next;}
      elsif ($_ =~ /REMOVE_REFS_TO_MISSING_BOOKS:(\s*(.*?)\s*)?$/) {if ($1) {$RemoveIfMissingTarget = $2; next;}}
      elsif ($_ =~ /:/) {next;}
      elsif ($_ =~ /\/(\w+)\.[^\/]+$/) {}
      elsif ($_ =~/^\s*(\w+)\s*$/) {}
      else {next;}
      $Booklist .= " " . &getOsisName($1);
    }
    close(COMF);
  }

  if (!$Booklist || $Booklist =~ /^\s*$/) {
    $UseAllBooks = "true";
    &Log("You are including cross references for ALL books.\n");
  }
  else {
    $UseAllBooks = "false"; 
    &Log("You are including cross references for the following books:\n$Booklist\n");
  }

  ########################################################################
  &Log("READING OSIS FILE: \"$in_osis\".\n");
  $OSIS = $XML_PARSER->parse_file($in_osis);

  # Save all Book and Verse nodes in the OSIS file to data structures
  %Book;
  foreach my $b ($XPC->findnodes('//osis:div[@type="book"]', $OSIS)) {
    my $bk = $b->findvalue('./@osisID');
    $Book{$bk} = $b;
  }

  %Verse;
  my @verses = $XPC->findnodes('//osis:verse', $OSIS);
  foreach my $v (@verses) {
    if ($v->hasChildNodes()) {&Log("ERROR: addCrossRefs.pl expects milestone verse tags\n"); die;}
    my $tt = 'start';
    my $id = $v->findvalue('./@sID');
    if (!$id) {
      $tt = 'end';
      $id = $v->findvalue('./@eID');
    }
    my @osisRefs = split(/\s+/, $id);
    foreach my $ref (@osisRefs) {$Verse{$ref}{$tt} = $v;}
  }

  ########################################################################
  &Log("READING CROSS REFERENCE FILE \"$CrossRefFile\".\n");
  
  my %localization;
  my @toc3 = $XPC->findnodes('//osis:div[@type="book"][descendant::osis:milestone[@type="x-usfm-toc3"]]', $OSIS);
  if ($BOOKNAMES || @toc3[0]) {
    &Log("NOTE: Applying localization to all cross references (count of BOOKNAMES=\"".scalar(%BOOKNAMES)."\", count of book toc3 tags=\"".scalar(@toc3)."\").\n");
    $localization{'hasLocalization'}++;
    my $ssf;
    if (opendir(SFM, "$INPD/sfm")) {
      my @fs = readdir(SFM);
      foreach my $f (@fs) {
        if (-d $f) {next;}
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
    
    my @books = split(' ', $OT_BOOKS . ' ' . $NT_BOOKS);
    foreach my $book (@books) {
      my $abbr = @{$XPC->findnodes('//osis:div[@type="book"][@osisID="'.$book.'"]//osis:milestone[@type="x-usfm-toc3"][1]/@n', $OSIS)}[0];
      if ($abbr) {$abbr = $abbr->value;}
      if ($BOOKNAMES{$book}{'abbr'}) {
        if (!$abbr) {$abbr = $BOOKNAMES{$book}{'abbr'};}
        elsif ($abbr ne $BOOKNAMES{$book}{'abbr'}) {
          &Log("WARNING: OSIS abbreviation \"$abbr\" differs from SSF abbreviation \"".$BOOKNAMES{$book}{'abbr'}."\"; will use OSIS abbreviation.\n");
        }
      }
      if ($abbr) {$localization{$book} = $abbr;}
      else {&Log("WARNING: Missing translation for \"$book\"\n");}
    }
  }

  # XML is the prefered cross-reference source format, but TXT is still supported
  if ($CrossRefFile =~ /\.xml$/) {
    $NoteXML = $XML_PARSER->parse_file($CrossRefFile);
    my @notes = $XPC->findnodes('//osis:note', $NoteXML);
    # combine all matching notes within a verse
    my %osisRefs;
    my @matchAttribs = ('osisRef', 'type', 'subType');
    for (my $i=0; $i<@notes; $i++) {
      my $key = '';
      foreach my $a (@matchAttribs) {$key .= @notes[$i]->findvalue("./\@$a");}
      if (defined($osisRefs{$key})) {
        foreach my $ref (@notes[$i]->childNodes()) {@notes[$osisRefs{$key}]->insertAfter($ref, undef);}
        @notes[$i] = NULL;
      }
      else {$osisRefs{$key} = $i;}
    }
    foreach my $note (@notes) {
      if (ref($note) ne "XML::LibXML::Element") {next;}
      
      # normalize white space (NOTE: the resulting $note has default namespace (not osis))
      my $strip = $note->toString();
      $strip =~ s/[\s\n]+</</g; $strip =~ s/>[\s\n]+/>/g;
      $note = @{$XML_PARSER->parse_balanced_chunk($strip)->childNodes}[0];
  
      # place note in first verse of multi-verse osisRef spans
      my $osisRef = @{$XPC->findnodes('./@osisRef', $note)}[0];
      my $or = $osisRef->getValue();
      $or =~ s/^[\w\d]+\://; # remove any work reference from note's osisRef
      if ($or !~ /^([^\.]+)\.(\d+)\.(\d+)/) {
        &Log("ERROR: crossReference has unexpected osisRef \"$osisRef\"\n");
        next;
      }
      my $b = $1; my $c = $2; my $v = $3;
      $osisRef->setValue($or);
      if ($v == 0) {$v++;}

      if (&filterNote($note, $b)) {next;}
      if (!$Verse{"$b.$c.$v"}) {&Log("ERROR: $b.$c.$v: Target verse not found.\n"); next;}
      
      if ($localization{'hasLocalization'}) {
        my $anotateRef = "<reference osisRef=\"".$osisRef->value."\" type=\"annotateRef\">$c".$localization{'ChapterVerseSeparator'}."$v</reference> ";
        $note->insertBefore($XML_PARSER->parse_balanced_chunk($anotateRef), $note->firstChild);
      }
      &insertNote($note, \%{$Verse{"$b.$c.$v"}}, \%localization);
    }
  }
  else {
    copy($CrossRefFile, "$CrossRefFile.tmp");
    open(NFLE, "<:encoding(UTF-8)", "$CrossRefFile.tmp") or die "Could not open cross reference file \"$CrossRefFile.tmp\".\n";
    while (<NFLE>) {
      $line++; #if (!($line%100)) {print "$line\n";}
      if ($_ =~ /^\s*$/) {next;}
      elsif ($_ !~ /^(norm:|para:)?([^\.]+)\.(\d+)\.(\d+):\s*(<note .*?<\/note>)\s*$/) {&Log("WARNING: Skipping unrecognized line, $line: $_"); next;}
      my $type = $1;
      my $b = $2;
      my $c = $3;
      my $v = $4;
      my $note = $5;
      chop($type);

      if (&filterNote(\$note, $b)) {next;}
      
      my $osisID = "$b.$c.$v!crossReference." . ($type eq "para" ? "p":"n");
      my $attribs = "osisRef=\"$b.$c.$v\" osisID=\"$osisID" . ++$REFNUM{$osisID} . "\"";
      $note =~ s/(type="crossReference")/$1 $attribs/;
      
      if ($note !~ /^<note type="crossReference" osisRef="[^\.]+\.\d+\.\d+" osisID="[^\.]+\.\d+\.\d+\!crossReference\.(n|p)\d+"( subType="x-parallel-passage")?>(<reference osisRef="([^\.]+\.\d+(\.\d+)?-?)+"><\/reference>)+<\/note>$/) {
        &Log("ERROR: Bad cross reference: \"$note\"\n"); next;
      }

      if (!$Verse{"$b.$c.$v"}) {&Log("ERROR: $type:$b.$c.$v: Target not found.\n"); next;}

      &insertNote(@{$XML_PARSER->parse_balanced_chunk($note)->childNodes}[0], \%{$Verse{"$b.$c.$v"}}, \%localization);
    }
    close (NFLE);
    unlink("$CrossRefFile.tmp");
  }

  ########################################################################
  &Log("WRITING NEW OSIS FILE: \"$out_osis\".\n");
  open(OUTF, ">$out_osis");
  print OUTF $OSIS->toString();
  close(OUTF);

  &Log("$MOD REPORT: Placed $NumNotes".($localization{'hasLocalization'} ? ' localized':'')." cross-reference notes.\n\n");
  
  return 1;
}


sub insertNote($\$) {
  my $noteP = shift;
  my $verseP = shift;
  my $localeP = shift;
  
  # add readable reference text (required by some front ends and eBooks)
  my @refs = $XPC->findnodes("reference", $noteP);
  for (my $i=0; $i<@refs; $i++) {
    my $osisRef = @{$XPC->findnodes('./@osisRef', @refs[$i])}[0];
    my $new = $osisRef->getValue();
    $new =~ s/^.*?://;
    $osisRef->setValue($new);
    if (!@{$XPC->findnodes('./text()', @refs[$i])}) {
      my $t;
      if ($localeP->{'hasLocalization'}) {
        $t = ($i==0 ? '':' ') . &translateRef($osisRef, $localeP) . ($i==@refs-1 ? '':$localeP->{'SequenceIndicator'});
      }
      else {$t = sprintf("%i%s", $i+1, ($i==@refs-1 ? '':','));}
      @refs[$i]->insertAfter(XML::LibXML::Text->new($t), undef);
    }
  }

  # insert in the right place
  # NOTE: the crazy looking while loop approach, and not using normalize-space() but rather $nt =~ /^\s*$/, greatly increases processing speed
  if ($noteP->toString() =~ /x-parallel-passage/) {
    my $nt = @{$XPC->findnodes('following::text()[1]', $verseP->{'start'})}[0];
    while ($nt) {
      if ($nt =~ /^\s*$/ || (my $title = @{$XPC->findnodes('ancestor::osis:title[not(@canonical="true")]', $nt)}[0])) { # next text
        $nt = @{$XPC->findnodes('following::text()[1]', $nt)}[0];
      }
      elsif (my $note = @{$XPC->findnodes('ancestor::osis:note', $nt)}[0]) {$note->parentNode->insertAfter($noteP, $note); last;} # insert after
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $nt)}[0]) {$reference->parentNode->insertBefore($noteP, $reference); last;} #insert before
      else {$nt->parentNode->insertBefore($noteP, $nt); last;}
    }
    if ($nt) {$NumNotes++;}
    else {&Log("ERROR: Could not place para note \"".$noteP->toString()."\"\n");}
  }
  else {
    my $pt = @{$XPC->findnodes('preceding::text()[1]', $verseP->{'end'})}[0];
    while ($pt) {
      if ($pt =~ /^\s*$/ || (my $title = @{$XPC->findnodes('ancestor::osis:title[not(@canonical="true")] | ancestor::osis:l[@type="selah"]', $pt)}[0])) { # next text
        $pt = @{$XPC->findnodes('preceding::text()[1]', $pt)}[0];
      }
      elsif (my $note = @{$XPC->findnodes('ancestor::osis:note', $pt)}[0]) {$note->parentNode->insertAfter($noteP, $note); last;} # insert after
      elsif (my $reference = @{$XPC->findnodes('ancestor::osis:reference', $pt)}[0]) {$reference->parentNode->insertAfter($noteP, $reference); last;} # insert after
      else {
        my $punc = '';
        my $txt = $pt->nodeValue();
        if ($txt =~ s/([\.\?\s]+)$//) {
          $punc = $1;
          $pt->setData($txt);
        }
        $pt->parentNode->insertAfter($noteP, $pt);
        if ($punc) {$noteP->parentNode->insertAfter(XML::LibXML::Text->new($punc), $noteP);}
        last;
      }
    }
    if ($pt) {$NumNotes++;}
    else {&Log("ERROR: Could not place norm note \"".$noteP->toString()."\"\n");}
  }
}

sub filterNote($$) {
  my $nP = shift;
  my $b = shift;

  if (!defined($Book{$b})) {return 1;} # Skip if this note's book is not in the OSIS file
  
  if (($UseAllBooks ne "true") && ($Booklist !~ /\b$b\b/)) {return 1;}
  
  if ($RemoveIfMissingTarget eq "true") {
    my $tmp = (ref($nP) eq "XML::LibXML::Element" ? $nP->toString():$$nP);
    while ($tmp =~ s/(<reference[^>]*osisRef=")(([^\.]+)\.[^"]+)("[^>]*>.*?<\/reference>)//) {
      my $p1 = $1;
      my $p2 = $2;
      my $bk = $3;
      my $p3 = $4;
      if ($Booklist =~ /\b$bk\b/) {next;}
      if (ref($nP) eq "XML::LibXML::Element") {
        my $rem = @{$XPC->findnodes("reference[\@osisRef='$p2']", $nP)}[0];
        $rem->unbindNode();
      }
      else {if ($$nP !~ s/\Q$p1$p2$p3\E//) {&Log("ERROR: Problem filtering note $$np\n");}}
    }
  }
  
  return 0;
}

sub translateRef($$) {
  my $attrib = shift;
  my $localeP = shift;
  
  my $t = $attrib->value;
  if ($t =~ /^([\w\.]+)(\-([\w\.]+))?$/) {
    my $r1 = $1; my $r2 = ($2 ? $3:'');
    $t = &translateSingleRef($r1, $localeP);
    if ($r2) {$t .= $localeP->{'RangeIndicator'} . &translateSingleRef($r2, $localeP);}
  }
  else {
    &Log("ERROR translateRef: malformed osisRef \"".$attrib->value."\"\n");
  }
  
  return $t;
}

sub translateSingleRef($$) {
  my $osisRefSingle = shift;
  my $localeP = shift;

  my $t = $osisRefSingle;
  if ($t =~ /^([^\.]+)(\.([^\.]+)(\.([^\.]+))?)?/) {
    my $b = $1; my $c = ($2 ? $3:''); my $v = ($4 ? $5:'');
    if ($localeP->{$b}) {
      $t = $localeP->{$b} . ($c ? ' ' . $c . ($v ? $localeP->{'ChapterVerseSeparator'} . $v:''):'');
    }
    else {
      &Log("ERROR translateSingleRef: no translation available for \"$b\"\n");
    }
  }
  else {
    &Log("ERROR translateSingleRef: malformed osisRef \"".$osisRefSingle."\"\n");
  }
  
  return $t;
}

1;
