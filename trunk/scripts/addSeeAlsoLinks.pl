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

$hs = "<hi type=";
$he = "</hi>";

&Log("-----------------------------------------------------\nSTARTING addSeeAlsoLinks.pl\n\n");

$ReferenceType = "x-glosslink";
$AllGlossaryTypes = "x-glossary|x-glosslink";
$SpecialCapitals = ""; # Mappings like i->I a->A override normal capitalization
$PAL = "\\w";          # Listing of punctuation to be treated as letters, like '`
$Checkonly = 0;        # If set, don't parse new links, only check existing links

&Log("Reading command file  \"$COMMANDFILE\".\n");
open(CF,"<:encoding(UTF-8)", $COMMANDFILE) or die "ERROR: Could not open command file \"$COMMANDFILE\".\n";
while (<CF>) {
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^\#/) {next;}
  elsif ($_ =~ /^SKIP_ENTRIES:(\s*(.*?)\s*)?$/) {if ($1) {$dontAddSeeAlsoLinkTo = $2;}} # ALL ENTRIES MUST BE FOLLOWED BY ";" !!
  elsif ($_ =~ /^DONT_LINK_TO:(\s*(.*?)\s*)?$/) {if ($1) {$dontlinkto = $2;}}
  elsif ($_ =~ /^DONT_LINK_TOA_INB:(\s*(.*?)\s*)?$/) {if ($1) {$dontlinktoainb = $2;}}
  elsif ($_ =~ /^LINK_HILIGHT_TEXT:(\s*(.*?)\s*)?$/) {if ($1) {$linkhilight = $2;}}
  elsif ($_ =~ /^ALLOW_IDENTICAL_LINKS:(\s*(.*?)\s*)?$/) {if ($1) {$allowidentlinks = $2;}}
  elsif ($_ =~ /^CHECK_ONLY:(\s*(.*?)\s*)?$/) {if ($1) {my $t = $2; if ($t && $t !~ /(false|0)/i) {$Checkonly = 1;}}}
  elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PAL .= $2;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SpecialCapitals = $2;}}
  elsif ($_ =~ /^REFERENCE_TYPE:(\s*(.*?)\s*)?$/) {if ($1) {$ReferenceType = $2;}}
}
close (CF);
&Log("Will not add \"See Also\" links to: $dontAddSeeAlsoLinkTo\n");
&Log("Will not create links to these entries: $dontlinkto\n");
&Log("Will not create links to A in B: $dontlinktoainb\n");
if ($linkhilight eq "true") {&Log("Will create links within hilighted text.\n");}
if ($allowidentlinks eq "true") {&Log("Will create muliple links to same target within entry.\n");}

if ($Checkonly) {
  &Log("Skipping link search. Checking existing links only.\n");
  copy("$INPUTFILE", "$OUTPUTFILE");
}
else {
  &Log("PARSING WORD LIST FILE: \"$INPD/$DICTWORDS\".\n");
  open (IN0, "<:encoding(UTF-8)", "$INPD/$DICTWORDS") or die "Could not open word list file $INPD/$DICTWORDS.\n";
  $line=0;
  while (<IN0>) {
    $line++;
    if ($_ =~ /DE(\d+):(.*?)[\n\r\l]/i) {$entry[$1]=$2;}
    if ($_ =~ /DL(\d+):(.*?)[\n\r\l]/i) {$dict[$1]=$2; $index{$2} = $1;}
  }
  close (IN0);

  &Log("ADDING \"SEE ALSO\" LINKS TO \"$INPUTFILE\".\n");
  open (INF, "<:encoding(UTF-8)", $INPUTFILE) or die "Could not open $INPUTFILE.\n";
  open (OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
  $line=0;
  $links=0;
  # Don't make links of bold or italicized words/phrases or titles or footnotes
  $splitter = "(<title.*?<\\/title>|<note.*?<\\/note>|<figure[^>]*>";
  if ($linkhilight ne "true") {$splitter = $splitter . "|<hi type=.*?<\\/hi>";}
  $splitter = $splitter . ")";
  while (<INF>) {
    $line++;
    
    $_ =~ s/\|i(.*?)\|r/<i>$1<\/i>/g;
    $_ =~ s/\|b(.*?)\|r/<b>$1<\/b>/g;
    if ($_ =~ /^\$\$\$(.*)\s*$/) {$currentEntry=$1; $linksInEntry=";";}
    elsif ($dontAddSeeAlsoLinkTo !~ /(^|;)\Q$currentEntry;/i) {
  PARSELINE:
      $startover = "false";
      @parts = split(/$splitter/);
      foreach $sb (@parts){
        if ($sb !~ /$splitter/) {
          foreach $w (sort {length($b) <=> length($a)} @dict) {
            if ($w eq $currentEntry) {next;}
            if ($allowidentlinks ne "true") {if ($linksInEntry =~ /;$w;/i) {next;}}
            if ($dontlinkto =~ /(^|;)$w;/i) {next;}
            if ($dontlinktoainb =~ /(^|;)$w,$currentEntry;/i) {next;}
            # Don't make links within links!
            @links = split(/(<reference .*?<\/reference>)/,$sb);
            foreach $ln (@links) {
              if ($ln !~ /(<reference .*?<\/reference>)/) {
                $tmpln = $ln;
                $wt = $w;
                $wt =~ s/[\(\)\{\}\[\]\$\^\*\+\-]/./g; #allows us to match these special perl chars in entry names!
                # using "if" replaces only the first, but "while" will replace all...
                if ($tmpln =~ s/(^|\W)($wt)(\W|$)/$1$3/i) {
                  $pc=$1; $ww=$2; $sc=$3;
                  if ($pc eq "." && $sc eq "\"") {&Log("$INPUTFILE line $line: Link matched self. Quitting snippet...\n"); last;}
                  $osisRef = $MOD . ":" . encodeOsisRef($entry[$index{$w}]);
                  $ln =~ s/\Q$pc$ww$sc/$pc<reference type=\"x-glosslink\" osisRef="$osisRef">$ww<\/reference>$sc/;
                  &Log("Line $line: Added link \"$w\" to \"$currentEntry\".\n");
                  $linksInEntry = $linksInEntry.$w.";";
                  $entryLength{$currentEntry} = length($_);
                  $links++;
                  $startover = "true";
                }
              }
            }
          $sb = join("",@links);
          if ($startover eq "true") {last;}
          }
          if ($startover eq "true") {last;}
        }
      }
      $_ = join("",@parts);
      if ($startover eq "true") {goto PARSELINE;}
    }
    print OUTF $_;
  }
  close (INF);
  close (OUTF);
  &Log("Added $links \"See Also\" links to \"$OUTPUTFILE\".\n");
}

# Check link targets and repair if needed
$AllWordFiles{$MOD} = $DICTWORDS;
&checkGlossReferences($OUTPUTFILE, $AllGlossaryTypes, \%AllWordFiles);

# LOG ALL CIRCULAR REFERENCES...
&Log("\nCHECKING FOR CIRCULAR ENTRIES...\n");
open(INF, "<:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
$line=0;
while (<INF>) {
  $line++;
  if ($_ =~ /^\$\$\$(.*)\s*$/) {$currentEntry=$1;}
  else {
    while ($_ =~ s/<reference type="x-glosslink" osisRef="$MOD\:([^\"]+)">.*?<\/reference>//) {
      $seeAlsosForWord{$currentEntry} = "$seeAlsosForWord{$currentEntry}$1;";
    }
  }
}
close(INF);
  
open(INF, "<:encoding(UTF-8)", $OUTPUTFILE) or die "Could not open $OUTPUTFILE.\n";
$line=0;
$numfound=0;
while (<INF>) {
  $line++;
  
  if ($_ =~ /^\$\$\$(.*)\s*$/) {$currentEntry=$1;}
  else {
    while ($_ =~ s/<reference type="x-glosslink" osisRef="$MOD\:([^\"]+)">.*?<\/reference>//) {
      $seeAlsoWord = $1;
      $words2check = $seeAlsosForWord{$seeAlsoWord};
      # Does this entry have a link to another entry which has a link back to the original entry?
      if ($words2check eq "") {next;}
      $words2check =~ s/$currentEntry;//g; # remove any circular reference
      # if nothing left, then this is a simple circular reference.
      if ($words2check =~ /^\s*$/) {
        &Log("$INPUTFILE line $line: CIRCULAR REFERENCE \"$seeAlsoWord\" from entry \"$currentEntry\"\n");
        $dontlinkAinB{"$currentEntry,$seeAlsoWord;"}++;
        $numfound++;
        next;
      }
      # if there are other links, we should not say the entry is circular unless all these other links also go back to the original entry
      else {
        $secondaryWordsAreCircular = "true";
        while ($words2check =~ s/^(.*?);//) {
          $secondaryWords2Check = $seeAlsosForWord{$1};
          if ($secondaryWords2Check eq "") {$secondaryWordsAreCircular = "false";}
          $secondaryWords2Check =~ s/$currentEntry;//g;
          if ($secondaryWords2Check !~ /^\s*$/) {$secondaryWordsAreCircular = "false";}
        }
        if ($secondaryWordsAreCircular eq "true") {
          &Log("$INPUTFILE line $line: (SECONDARILY) CIRCULAR REFERENCE \"$seeAlsoWord\" from entry \"$currentEntry\"!\n");
          $dontlinkAinB{"$currentEntry,$seeAlsoWord;"}++;
          $numfound++;
          next;
        }
      }
    }
  }
}
close(INF);
&Log("Found $numfound circular cross references in \"$OUTPUTFILE\".\n");
if (!$Checkonly && $numfound > 0) {
  &Log("Circular references can be eliminated with the following line in the CF file:\n");
  &Log("DONT_LINK_TOA_INB:");
  foreach $dlab (keys %dontlinkAinB) {
    # Circular refs are often cause by compound entries which list many specific related references
    # For instance: entry for "blue ribbon" would say "see ribbons", and ribbons would be a compound entry.
    # We will assume the longer entry is the compound entry, and the shorter entry is the "see ..." entry:
    $dlab =~ /([^,]+),([^;]+);/;
    if ($entryLength{$1} > $entryLength{$2}) {$dlab = "$2,$1;";}
    &Log($dlab);
  }
  &Log("\n");
}

&Log("FINISHED\n\n");

