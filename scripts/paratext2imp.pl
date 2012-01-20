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
#
########################################################################

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
#  -The CF_paratext2imp.txt command file is executed from top to
#   bottom. All settings remain in effect until/unless changed (so
#   settings may be set more than once). All SFM files are processed 
#   and added to the IMP file in the order in which they appear in 
#   the command file. Books are processed using all settings previously 
#   set in the command file.
#
#  -It might be helpful on the first run of a new SFM project to use 
#   "FIND_ALL_TAGS:true". This will log all tags found in the project
#   after "Following is the list of unhandled tags which were skipped:" 
#   The listed tags can be added to the command file and handled 
#   as desired.

# IMPORTANT TERMINOLOGY:
#   A "tag-list" is a Perl regular expression consisting of SFM tag 
#   names separated by the perl OR ("|") term. Order should be longest
#   tags to shortest. The "\" before the tag is implied. 
#   For example: (toc1|toc2|toc3|ide|rem|id|w\*|h|w)

# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   RUN - Process the SFM file now and add it to the IMP file. 
#       Only one SFM file per RUN command is allowed. 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I

# COMMAND FILE FORMATTING RELATED SETTINGS:
#   IGNORE_LINES - A tag-list for lines which should be ignored.
#   PARAGRAPH - A tag-list for intented paragraphs.
#   PARAGRAPH2 - A tag-list for doubly indented paragraphs.
#   PARAGRAPH3 - A tag-list for triple indented paragraphs.
#   BLANK_LINE - A tag-list for blank lines (or non-indented paragraphs)
#   TABLE_ROW_START - A tag-list for table row's start
#   TABLE_COL1 - A tag-list for beginning of column 1
#   TABLE_COL2 - A tag-list for beginning of column 2
#   TABLE_COL3 - A tag-list for beginning of column 3
#   TABLE_COL4 - A tag-list for beginning of column 4
#   TABLE_ROW_END - A tag-list for table row's end
#   REMOVE - A tag-list of tags to remove from the text. IMPORTANT!: 
#       tags listed in BOLD_PATTERN and ITALIC_PATTERN must also be 
#       included in the REMOVE tag-list.

# COMMAND FILE TEXT PROCESSING SETTINGS:
#   BOLD_PATTERN - Perl regular expression to match any bold text.
#   ITALIC_PATTERN - Perl regular expression to match any italic text.    

# COMMAND FILE FOOTNOTE SETTINGS:
#   FOOTNOTES_INLINE - Use for SFM inline footnotes. A Perl regular 
#       expression to match all footnotes. The last parenthetical 
#       grouping of the regular expression should match the footnote 
#       text which you want retained in the OSIS file.
#   CROSSREFS_INLINE - For inline cross references. See FOOTNOTES_INLINE

# COMMAND FILE GLOSSARY/DICTIONARY RELATED SETTINGS:
#   GLOSSARY_ENTRY - A Perl regular expression to match 
#       glossary entry names in the SFM.
#   SEE_ALSO - A Perl regular expression to match "see-also" SFM tags.
#       The last parenthetical grouping of the regular expression 
#       should match the glossary entry.
#   GLOSSARY_NAME - Name of glossary module targetted by glossary links.

open (OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) || die "Could not open paratext2imp output file $OUTPUTFILE\n";

&Log("-----------------------------------------------------\nSTARTING paratext2imp.pl\n\n");

# Read the COMMANDFILE, converting each file as it is encountered
open (COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open paratext2imp command file $COMMANDFILE\n";

$IgnoreTags = "";
$ContinuationTerms = "";
$SpecialCapitals = "";
$GlossExp = "";
$normpar = "";
$doublepar = "";
$triplepar = "";
$blankline = "";
$tablestart = "";
$tablec1 = "";
$tablec2 = "";
$tablec3 = "";
$tablec4 = "";
$tableend = "";
$bold = "";
$italic = "";
$txttags = "";
$notes = "";
$crossrefs = "";
$glossentries = "";
  
$line=0;
while (<COMF>) {
  $line++;
  $_ =~ s/\s+$//;
  
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^\#/) {next;}
  # VARIOUS SETTINGS...
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^IGNORE_LINES:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IgnoreTags = $2; next;}}
  elsif ($_ =~ /^VERSE_CONTINUE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$ContinuationTerms = $2; next;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SpecialCapitals = $2; next;}}
  
  # FORMATTING TAGS...
  elsif ($_ =~ /^GLOSSARY_ENTRY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$GlossExp = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$normpar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$doublepar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$triplepar = $2; next;}}
  elsif ($_ =~ /^BLANK_LINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$blankline = $2; next;}}
  elsif ($_ =~ /^TABLE_ROW_START:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablestart = $2; next;}}
  elsif ($_ =~ /^TABLE_COL1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec1= $2; next;}}
  elsif ($_ =~ /^TABLE_COL2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec2= $2; next;}}
  elsif ($_ =~ /^TABLE_COL3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec3= $2; next;}}
  elsif ($_ =~ /^TABLE_COL4:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec4= $2; next;}}
  elsif ($_ =~ /^TABLE_ROW_END:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tableend= $2; next;}}

  # TEXT TAGS...  
  elsif ($_ =~ /^REMOVE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$remtag = $2; next;}}
  elsif ($_ =~ /^BOLD_PATTERN:(\s*\((.*?)\)\s*)?$/) {if ($1) {$bold = $2; next;}}
  elsif ($_ =~ /^ITALIC_PATTERN:(\s*\((.*?)\)\s*)?$/) {if ($1) {$italic = $2; next;}}
  elsif ($_ =~ /^FOOTNOTES_INLINE:(\s*(.*?)\s*)?$/) {if ($1) {$notes = $2; next;}}
  elsif ($_ =~ /^CROSSREFS_INLINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$crossrefs = $2; next;}}
  elsif ($_ =~ /^SEE_ALSO:(\s*\((.*?)\)\s*)?$/) {if ($1) {$glossentries = $2; next;}}
  
  # SFM file name...
  elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {&glossSFMtoIMP($1);}
  else {&Log("ERROR: Unhandled command file entry \"$_\" in $COMMANDFILE\n");}
}
close (OUTF);

# Check and report...
&Log("PROCESSING COMPLETE.\n");
&Log("\nFollowing are unhandled tags which where removed from the text:\n$tagsintext");
&Log("\nEnd of listing\n");

# Write DictionaryWords.txt file
open(DWORDS, ">:encoding(UTF-8)", "$INPD/DictionaryWords_autogen.txt") || die "Error: Could not open $INPD/DictionaryWords.txt\n";
for (my $i=0; $i<@AllEntries; $i++) {print DWORDS "DE$i:$AllEntries[$i]\n";}
for (my $i=0; $i<@AllEntries; $i++) {print DWORDS "DL$i:$AllEntries[$i]\n";}
close(DWORDS);
1;

########################################################################
########################################################################


sub glossSFMtoIMP($) {
  my $SFMfile = shift;

  &Log("Processing $SFMfile\n");

  # Read the paratext file and convert it
  open(INF, "<:encoding(UTF-8)", $SFMfile) or print getcwd." ERROR: Could not open file $SFMfile.\n";

  # Read the paratext file line by line
  $lineSFM=0;
  my $parsebuf = "";
  my $e;
  my $t;
  while (<INF>) {
    $lineSFM++;
 
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ s/^$GlossExp//) {
      my $e2 = $+;
      if ($e) {&Write($e, $t);}
      $e = $e2;
      if ($_ !~ /^\s*$/) {$t = $_;}
      else {$t = "";}
    }
    else {$t .= $_;}
  }
  
  if ($e) {&Write($e, $t);}
  else {&Log("ERROR: Failed to find any glossary entries matching pattern: \"^$GlossExp\".\n");}
  close (INF);
}

sub convertEntry($) {
  my $e = shift;
  $e = &suc($e, $SpecialCapitals);
  $e =~ s/<[^>]*>//g;
  return $e;
}

sub convertText($) {
  my $l = shift;
  
  # Ignore tags on ignore-list
  if ($l =~ /^\s*\\($IgnoreTags)(\s|$)/) {return $l;}
  
    # text effect tags
  if ($bold)      {$l =~ s/($boldpattern)/<hi type="bold">$+<\/hi>/g;}
  if ($italic)    {$l =~ s/($italicpattern)/<hi type="italic">$+<\/hi>/g;}
  if ($remtag)    {$l =~ s/\\($remtag)//g;}

  # handle table tags
  if ($l =~ /($tablestart)/) {&convertTable(\$l);}
 
  $l =~ s/\s*\/\/\s*/ /g; # Force carriage return SFM marker
  
  # paragraphs
  if ($blankline) {$l =~ s/\\$blankline(\s|$)/<lb \/>/g;}
  if ($normpar)   {$l =~ s/\\$normpar(\s|$)/<lb \/>$INDENT/g;}
  if ($doublepar) {$l =~ s/\\$doublepar(\s|$)/<lb \/>$INDENT$INDENT/g;}
  if ($triplepar) {$l =~ s/\\$triplepar(\s|$)/<lb \/>$INDENT$INDENT$INDENT/g;}

  # footnotes, cross references, and glossary entries
  if ($notes)        {$l =~ s/$notes/<note>$+<\/note>/g;}
  if ($crossrefs)    {$l =~ s/$crossrefs/<note type="crossReference">$+<\/note>/g;}
  if ($glossentries) {
    $l =~ s/$glossentries/my $a = $+; my $res = "<reference type=\"x-glosslink\" osisRef=\"$MOD:".&encodeOsisRef(&suc($a, $SpecialCapitals))."\">$a<\/reference>";/ge;
  }
  
  return $l;  
}

sub convertTable(\$) {
  my $tP = shift;

  #my $w1 = "%-".&getWidestW($tP, "\\\\t[hc]1 ", "\\\\t[hc]2 ")."s | ";
  #my $w2 = "%-".&getWidestW($tP, "\\\\t[hc]2 ", "\\\\t[hc]3 ")."s | ";
  #my $w3 = "%-".&getWidestW($tP, "\\\\t[hc]3 ", quotemeta($LB))."s";

  $$tP =~ s/\\($tablec1)\s+(.*?)\s*((\\($tablec2) )|($tableend))/my $f = &formatCell($2, $3);/gem;
  $$tP =~ s/\\($tablec2)\s+(.*?)\s*((\\($tablec3) )|($tableend))/my $f = &formatCell($2, $3);/gem;
  $$tP =~ s/\\($tablec3)\s+(.*?)\s*((\\($tablec4) )|($tableend))/my $f = &formatCell($2, $3);/gem;
  $$tP =~ s/\\($tablec4)\s+(.*?)\s*($tableend)/my $f = &formatCell($2, $3);/gem;

  $$tP =~ s/\\($tablestart) /$LB$LB/m; # add a blank line before first row
  $$tP =~ s/\\($tablestart) //gm;
}

sub formatCell($$) {
  my $t = shift;
  my $e = shift;
 
  my $cs = "%s | ";
  my $cl = "%s";
  
  my $f = sprintf(($e =~ /^$tableend$/ ? $cl:$cs), $t).$e;
  if ($e =~ /^$tableend$/) {$f .= "$LB";}
  
  return $f;
}

sub getWidestW(\$$$) {
  my $tP = shift;
  my $ps = shift;
  my $pe = shift;
  
  my $w = 0;
  my $s = $$tP;
  $s =~ s/$ps(.*?)$pe/if (length($1) > $w) {$w = length($1);} my $r = "";/gem;
  
  return $w;
}

sub Write($$) {
  my $e = shift;
  my $t = shift;
  
  $e = &convertEntry($e);
  $t = &convertText($t);
  
  push(@AllEntries, $e);
  
  # remove any trailing LBs
  $t =~ s/((\Q$LB\E)|(\s))+$//;
  
  my $print = "\$\$\$$e\n$t\n";
  
  while ($print =~ s/(\\([\w]*)\*?)//) {
    $tagsintext .= "WARNING Before $ThisSFM Line $lineSFM: Tag \"$1\" was REMOVED.\n";
  }
  
  print OUTF $print;
}
