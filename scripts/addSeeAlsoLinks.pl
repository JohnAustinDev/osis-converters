# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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
#   SKIP_ENTRIES - A semicolon separated list of glossary entries which 
#       should not be parsed (no see-also links will be added to them).
#   DONT_LINK_TO - A semicolon separated list of glossary entries which
#       will not be linked to by any see-also links.
#   DONT_LINK_TOA_INB: - A semicolon separated list of entry pairs where
#       no see-also links to A will be added to B. Example: A1,B1;A2,B2;A3,B3
#   LINK_HILIGHT_TEXT - Set to "true" if links may be made within 
#       highlighted text. Otherwise bold or italic text will not be
#       parsed for links.
#   ALLOW_IDENTICAL_LINKS - Set to "true" to allow multiple see-also 
#       links with the same target to be added to the same entry. 
#       Normally only the first see-also reference to a particular 
#       entry is linked. 
#   CHECK_ONLY - Set to true to skip parsing for links and only check 
#       existing links. During checking, any broken links are corrected.
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching. 
#       Example for : "PUNC_AS_LETTER:'`-" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I
#   REFERENCE_TYPE - The value of the type attribute for 
#       see-also <reference> links which are added to the glossary.
  
$DEBUG = 0;

&Log("-----------------------------------------------------\nSTARTING addSeeAlsoLinks.pl\n\n");

$ReferenceType = "x-glosslink";
$PAL = "\\w";          # Listing of punctuation to be treated as letters, like '`
$DICTIONARY_WORDS = 'DictionaryWords.txt';
$Linklog = '';
$Links = 0;
    
&Log("READING COMMAND FILE \"$COMMANDFILE\"\n");
&Log("\n");
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(CF,"<:encoding(UTF-8)", $COMMANDFILE) or die "ERROR: Could not open command file \"$COMMANDFILE\".\n";
while (<CF>) {
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^\#/) {next;}
  elsif ($_ =~ /^SKIP_ENTRIES:(\s*(.*?)\s*)?$/) {if ($1) {$SKIP_ENTRIES = $2;}} # ALL ENTRIES MUST BE FOLLOWED BY ";" !!
  elsif ($_ =~ /^DONT_LINK_TO:(\s*(.*?)\s*)?$/) {if ($1) {$DONT_LINK_TO = $2;}}
  elsif ($_ =~ /^DONT_LINK_TOA_INB:(\s*(.*?)\s*)?$/) {if ($1) {$DONT_LINK_TOA_INB = $2;}}
  elsif ($_ =~ /^LINK_HILIGHT_TEXT:(\s*(.*?)\s*)?$/) {if ($1) {my $b = $2; $Linkhilight = ($b !~ /^(false|0)$/i ? 1:0);}}
  elsif ($_ =~ /^ALLOW_IDENTICAL_LINKS:(\s*(.*?)\s*)?$/) {if ($1) {my $b = $2; $Allowidentlinks = ($b !~ /^(false|0)$/i ? 1:0);}}
  elsif ($_ =~ /^CHECK_ONLY:(\s*(.*?)\s*)?$/) {if ($1) {my $b = $2; $Checkonly = ($b !~ /^(false|0)$/i ? 1:0);}}
  elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PAL .= $2;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2;}}
  elsif ($_ =~ /^REFERENCE_TYPE:(\s*(.*?)\s*)?$/) {if ($1) {$ReferenceType = $2;}}
}
close (CF);
&Log("Will not add \"See Also\" links to: $SKIP_ENTRIES\n");
&Log("Will not create links to these entries: $DONT_LINK_TO\n");
&Log("Will not create links to A in B: $DONT_LINK_TOA_INB\n");
if ($Linkhilight) {&Log("Will create links within hilighted text.\n");}
if ($Allowidentlinks) {&Log("Will create muliple links to same target within entry.\n");}
&Log("\n");

&Log("READING INPUT FILE: \"$INPUTFILE\".\n");
&Log("WRITING OUTPUT FILE: \"$OUTPUTFILE\".\n");

my @Words, %DictsForWord, %SearchTerms;
my %ReportList, %EntryCount, %EntryLink;
if ($Checkonly) {
  &Log("Skipping link search. Checking existing links only.\n");
  &Log("\n");
  copy("$INPUTFILE", "$OUTPUTFILE");
}
else {
  &readGlossWordFile("$INPD/$DICTIONARY_WORDS", $MOD, \@Words, \%DictsForWord, \%SearchTerms);

  &Log("PARSING LINKS...\n");
  
  # Process OSIS input file (from usfm2osis.py)
  if ($IS_usfm2osis) {
    
    my $skipnames = "reference|figure|title|note" . (!$Linkhilight ? '|hi':''); # make no links inside these elements
  
    my $xml = $XML_PARSER->parse_file($INPUTFILE);
    my @entries = $XPC->findnodes("//*[count(descendant::".$KEYWORD.")=1]|".$KEYWORD."[count(../child::".$KEYWORD.")>1]", $xml);
    for (my $i=0; $i<@entries; $i++) {
      my $currentEntry=@{$XPC->findnodes("descendant-or-self::".$KEYWORD, $entries[$i])}[0]->textContent();
      &Log("-> $currentEntry\n", 2);
      my $skiplist = '';
      if (&skipEntry($currentEntry, \$skiplist)) {next;}
      my $done;
      do {
        $done = 1;
        my @elems = $XPC->findnodes('self::*|following::*', $entries[$i]);
        for (my $j=0; $j<@elems && ($i==@entries-1 || !@elems[$j]->isSameNode($entries[$i+1])); $j++) {
          if ($elems[$j]->localname =~ /^($skipnames)$/) {next;}
          my @textchildren = $XPC->findnodes('child::text()', $elems[$j]);
          foreach my $textchild (@textchildren) {
            my $text = $textchild->data();
            if (&addGlossLink(\$text, \%DictsForWord, \%SearchTerms, \%ReportList, \%EntryCount, 1, \$skiplist, $ReferenceType, NULL, NULL)) {
              $textchild->parentNode()->insertBefore($XML_PARSER->parse_balanced_chunk($text), $textchild);
              $textchild->unbindNode();
              $text =~ /<reference[^>]*>\s*(.*?)\s*<\/reference[^>]*>/; $EntryLink{$1." in ".$currentEntry}++;
              $done = 0;
            }
          }
        }
      } while(!$done);
    }
    open(OUTF, ">$OUTPUTFILE") or die "Could not open $OUTPUTFILE.\n";
    print OUTF $xml->toString();
    close(OUTF);
    
  }
  
  # Or process IMP input file
  else {
  
    # For backward compatibility with IMP, dictionary search terms should NEVER match any suffixes
    foreach my $w (keys %SearchTerms) {
      my $w2 = $w;
      if ($w2 =~ s/^("?[^"]*?)((\s|<.*?>)*)$/$1"$2/) {
        my $targ = $SearchTerms{$w};
        delete($SearchTerms{$w});
        $SearchTerms{$w2} = $targ;
      }
    }
  
    open(INF, "<:encoding(UTF-8)", $INPUTFILE) or die "Could not open $INPUTFILE.\n";
    open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
    my $line=0;
    &logProgress($INPUTFILE, -1);
    my $skiptags = "(<title.*?<\\/title[^>]*>|<note.*?<\\/note[^>]*>|<figure[^>]*>|<reference.*?<\\/reference[^>]*>";
    if (!$Linkhilight) {$skiptags .= "|<hi.*?<\\/hi[^>]*>";}
    $skiptags .= ")";
    my $skiplist;
    my $skipentry = 0;
    my $currentEntry;
    while (<INF>) {
      $line++;
      if ($_ =~ /^\$\$\$(.*)\s*$/) {
        $currentEntry=$1;
        &logProgress($currentEntry, $line);
        $skiplist = '';
        $skipentry = &skipEntry($currentEntry, \$skiplist);
      }
      elsif (!$skipentry) {
        my $done;
        do {
          $done = 1;
          my @parts = split(/$skiptags/);
          foreach my $sb (@parts) {
            if ($sb =~ /$skiptags/) {next;}
            if (&addGlossLink(\$sb, \%DictsForWord, \%SearchTerms, \%ReportList, \%EntryCount, 1, \$skiplist, $ReferenceType, NULL, NULL)) {
              $sb =~ /<reference[^>]*>\s*(.*?)\s*<\/reference[^>]*>/; $EntryLink{uc2($1)." in ".$currentEntry}++;
              $done = 0;
            }
          }
          $_ = join('', @parts);
        } while (!$done);
      }
      print OUTF $_;
    }
    close (INF);
    close (OUTF);
  }
  
}

# Check link targets and repair if needed
$AllWordFiles{$MOD} = $DICTIONARY_WORDS;
&checkGlossReferences($OUTPUTFILE, "x-glossary|x-glosslink", \%AllWordFiles);

&Log("\nCHECKING FOR CIRCULAR ENTRIES...\n");
my $numfound = 0;
my %seeAlsosForWord;
my %dontlinkAinB;
if ($IS_usfm2osis) {
  my $xml = $XML_PARSER->parse_file($OUTPUTFILE);
  my @refs = $XPC->findnodes('//osis:reference[@type="x-glosslink"]', $xml);
  foreach my $ref (@refs) {
    my $currentEntry = @{$XPC->findnodes("preceding::".$KEYWORD."[1]", $ref)}[0]->textContent();
    my $osisRef;
    if (!&readGlossaryRef(\$ref, \$osisRef)) {next;}
    $seeAlsosForWord{$currentEntry} .= &decodeOsisRef($osisRef).';';
  }
  foreach my $ref (@refs) {
    my $currentEntry = @{$XPC->findnodes("preceding::".$KEYWORD."[1]", $ref)}[0]->textContent();
    my $osisRef;
    if (!&readGlossaryRef(\$ref, \$osisRef)) {next;}
    &checkCircular($currentEntry, &decodeOsisRef($osisRef), \%seeAlsosForWord, \%dontlinkAinB);
  }
}
else {
  my $currentEntry;
  open(INF, "<:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
  while (<INF>) {
    if ($_ =~ /^\$\$\$(.*)\s*$/) {$currentEntry = $1;}
    else {
      while ($_ =~ s/<reference ([^>]*)>.*?<\/reference>//) {
        my $a = $1;
        if ($a !~ /type="x-glosslink"/ || $a !~ /osisRef="$MOD\:([^\"]+)"/) {next;} 
        $seeAlsosForWord{$currentEntry} .= &decodeOsisRef($1).';';
      }
    }
  }
  close(INF);
  open(INF, "<:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
  while (<INF>) {
    if ($_ =~ /^\$\$\$(.*)\s*$/) {$currentEntry = $1;}
    else {
      while ($_ =~ s/<reference ([^>]*)>.*?<\/reference>//) {
        my $a = $1;
        if ($a !~ /type="x-glosslink"/ || $a !~ /osisRef="$MOD\:([^\"]+)"/) {next;} 
        my $seeAlsoWord = &decodeOsisRef($1);
        &checkCircular($currentEntry, $seeAlsoWord, \%seeAlsosForWord, \%dontlinkAinB);
      }
    }
  }
  close(INF);
}

my $numfound = 0;
foreach my $k (keys %dontlinkAinB) {$numfound += $dontlinkAinB{$k}};
&Log("\nREPORT: Found $numfound circular cross references in \"$OUTPUTFILE\".\n");
if (!$Checkonly && $numfound > 0) {
  &Log("Circular references can be eliminated with the following line in the CF file:\n");
  &Log("DONT_LINK_TOA_INB:");
  foreach $dlab (keys %dontlinkAinB) {
    # Circular refs are often cause by compound entries which list many specific related references
    # For instance: entry for "blue ribbon" would say "see ribbons", and ribbons would be a compound entry.
    # We will assume the longer entry is the compound entry, and the shorter entry is the "see ..." entry:
    $dlab =~ /([^,]+),([^;]+);/;
    if ($EntryLength{$1} > $EntryLength{$2}) {$dlab = "$2,$1;";}
    &Log($dlab);
  }
  &Log("\n");
}

&logGlossReplacements("$INPD/$DICTIONARY_WORDS", \@Words, \%ReportList, \%EntryCount);
$n = 0; foreach my $k (keys %EntryLink) {$n++;}
&Log("REPORT: \"See Also\" links added: ($n instances)\n");
foreach my $k (sort keys %EntryLink) {&Log("Linked to $k.\n");}

&Log("FINISHED\n\n");

########################################################################
########################################################################


# returns 1 to skip this entry, or adds terms to skiplist to skip terms
# while linking this entry
sub skipEntry($\$) {
  my $currentEntry = shift;
  my $skiplistP = shift;

  if ($SKIP_ENTRIES =~ /(^|;)\Q$currentEntry\E;/i) {return 1;}

  foreach my $searchTerm (keys %SearchTerms) {
    my $entry = $SearchTerms{$searchTerm};
    my $skip = 0;
    if ($entry eq $currentEntry) {$skip = 1;}
    if ($DONT_LINK_TO =~ /(^|;)\Q$entry\E;/i) {$skip = 1;}
    if ($DONT_LINK_TOA_INB =~ /(^|;)\Q$entry,$currentEntry\E;/i) {$skip = 1;}
    if ($skip) {$$skiplistP .= $searchTerm.';';}
  }

  return 0;
}

sub readGlossaryRef(\$\$) {
  my $refP = shift;
  my $osisRef = shift;
  if (ref($$refP) ne "XML::LibXML::Element") {return 0;}
  $$osisRef = $$refP->getAttribute('osisRef');
  if (!$$osisRef || $$osisRef !~ /^$MOD\:(.*)$/) {$$refP = NULL; return 0;}
  $$osisRef = $1;
  return 1;
}

sub checkCircular($$\%\%) {
  my $entry = shift;
  my $seeAlsoWord = shift;
  my $seeAlsosForWordP = shift;
  my $dontlinkAinBp = shift;

  my $words2check = $seeAlsosForWordP->{$seeAlsoWord};
  # Does this entry have a link to another entry which has a link back to the original entry?
  if (!$words2check) {next;}
  $words2check =~ s/$entry;//g; # remove any circular reference
  # if nothing left, then this is a simple circular reference.
  if ($words2check =~ /^\s*$/) {
    &Log("CIRCULAR REFERENCE: target of link \"$seeAlsoWord\" in entry \"$entry\" only links back to entry.\n");
    $dontlinkAinBp->{"$entry,$seeAlsoWord;"}++;
    next;
  }
  # if there are other links, we should not say the entry is circular unless all these other links also go back to the original entry
  else {
    my $secondaryWordsAreCircular = "true";
    while ($words2check =~ s/^(.*?);//) {
      my $secondaryWords2Check = $seeAlsosForWord{$1};
      if (!$secondaryWords2Check) {$secondaryWordsAreCircular = "false";}
      $secondaryWords2Check =~ s/$entry;//g;
      if ($secondaryWords2Check !~ /^\s*$/) {$secondaryWordsAreCircular = "false";}
    }
    if ($secondaryWordsAreCircular eq "true") {
      &Log("CIRCULAR REFERENCE: target of link \"$seeAlsoWord\" in entry \"$entry\", and its sibling links, all return back to entry.\n");
      $dontlinkAinBp->{"$entry,$seeAlsoWord;"}++;
      next;
    }
  }
}

