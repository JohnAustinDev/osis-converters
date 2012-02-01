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

# TERMINOLOGY:
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
#   IGNORE - A tag-list for lines which should be ignored.
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

# COMMAND FILE TEXT PROCESSING SETTINGS:
#   BOLD - Perl regular expression to match any bold text.
#   ITALIC - Perl regular expression to match any italic text. 
#   REMOVE - Perl regular expression to match any SFM to be removed. 

# COMMAND FILE FOOTNOTE SETTINGS:
#   FOOTNOTE - A Perl regular expression to match all footnotes.
#   CROSSREF - A Perl regular expression to match all cross references.

# COMMAND FILE GLOSSARY/DICTIONARY RELATED SETTINGS:
#   GLOSSARY_ENTRY - A Perl regular expression to match 
#       glossary entry names in the SFM.
#   SEE_ALSO - A Perl regular expression to match "see-also" SFM tags.

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
$tablerstart = "";
$tablec1 = "none";
$tablec2 = "none";
$tablec3 = "none";
$tablec4 = "none";
$tablerend = "";
$bold = "";
$italic = "";
$remove = "";
$txttags = "";
$notes = "";
$crossrefs = "";
$seealsopat = "";

$tagsintext="";  
$line=0;
while (<COMF>) {
  $line++;
  $_ =~ s/\s+$//;
  
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^\#/) {next;}
  # VARIOUS SETTINGS...
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^VERSE_CONTINUE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$ContinuationTerms = $2; next;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SpecialCapitals = $2; next;}}
  
  # FORMATTING TAGS...
  elsif ($_ =~ /^IGNORE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IgnoreTags = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$normpar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$doublepar = $2; next;}}
  elsif ($_ =~ /^PARAGRAPH3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$triplepar = $2; next;}}
  elsif ($_ =~ /^BLANK_LINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$blankline = $2; next;}}
  elsif ($_ =~ /^TABLE_ROW_START:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablerstart = $2; next;}}
  elsif ($_ =~ /^TABLE_COL1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec1= $2; next;}}
  elsif ($_ =~ /^TABLE_COL2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec2= $2; next;}}
  elsif ($_ =~ /^TABLE_COL3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec3= $2; next;}}
  elsif ($_ =~ /^TABLE_COL4:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec4= $2; next;}}
  elsif ($_ =~ /^TABLE_ROW_END:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablerend= $2; next;}}

  # TEXT PATTERNS... 
  elsif ($_ =~ /^GLOSSARY_ENTRY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$GlossExp = $2; next;}} 
  elsif ($_ =~ /^REMOVE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$remove = $2; next;}}
  elsif ($_ =~ /^BOLD:(\s*\((.*?)\)\s*)?$/) {if ($1) {$bold = $2; next;}}
  elsif ($_ =~ /^ITALIC:(\s*\((.*?)\)\s*)?$/) {if ($1) {$italic = $2; next;}}
  elsif ($_ =~ /^FOOTNOTE:(\s*(.*?)\s*)?$/) {if ($1) {$notes = $2; next;}}
  elsif ($_ =~ /^CROSSREF:(\s*\((.*?)\)\s*)?$/) {if ($1) {$crossrefs = $2; next;}}
  elsif ($_ =~ /^SEE_ALSO:(\s*\((.*?)\)\s*)?$/) {if ($1) {$seealsopat = $2; next;}}
  
  # SFM file name...
  elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {&glossSFMtoIMP($1);}
  elsif ($_ =~ /^APPEND:\s*(.*?)\s*$/) {&appendIMP($1);}
  else {&Log("ERROR: Unhandled command file entry \"$_\" in $COMMANDFILE\n");}
}
close (OUTF);

# Check and report...
&Log("PROCESSING COMPLETE.\n");
&Log("\nFollowing are unhandled tags which where removed from the text:\n$tagsintext");
&Log("\nFollowing tags were removed from entry names:\n");
foreach $k (keys %convertEntryRemoved) {&Log("$k ");}
&Log("\nEnd of listing\n");

# Write DictionaryWords.txt file
open(INF, "<:encoding(UTF-8)", $OUTPUTFILE) || die "ERROR: Could not open $OUTPUTFILE.\n";
while(<INF>) {if ($_ =~ /^\$\$\$\s*(.*?)\s*$/) {push(@AllEntries, $1);}}
close(INF);
open(DWORDS, ">:encoding(UTF-8)", "$INPD/DictionaryWords_autogen.txt") || die "Error: Could not open $INPD/DictionaryWords.txt\n";
for (my $i=0; $i<@AllEntries; $i++) {print DWORDS "DE$i:$AllEntries[$i]\n";}
print DWORDS "\n########################################################################\n\n";
for (my $i=0; $i<@AllEntries; $i++) {print DWORDS "DL$i:$AllEntries[$i]\n";}
close(DWORDS);
1;

########################################################################
########################################################################

sub appendIMP($) {
  my $imp = shift;
  &Log("Appending $imp\n");
  if (open(IMP, "<:encoding(UTF-8)", $imp)) {
    while(<IMP>) {
      if ($_ =~ /^\s*$/) {next;}
      print OUTF $_;
    }
  }
  else {&Log("ERROR: Could not append \"$imp\". File not found.\n");}
}

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
    elsif ($_ =~ /^\s*\\($IgnoreTags)(\s|$)/) {next;}
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
  $e =~ s/\\(\w+[\s\*])/$convertEntryRemoved{"\\$1"}++; my $t="";/eg;
  $e =~ s/<[^>]*>/$convertEntryRemoved{"$1"}++; my $t="";/eg;
  $e =~ s/(^\s*|\s*$)//g;
  $e =~ s/\s+/ /g;
  $e = &suc($e, $SpecialCapitals);
  return $e;
}

sub convertText($) {
  my $l = shift;
  
  # text effect tags
  if ($bold)      {$l =~ s/($bold)/<hi type="bold">$+<\/hi>/g;}
  if ($italic)    {$l =~ s/($italic)/<hi type="italic">$+<\/hi>/g;}
  if ($remove)    {$l =~ s/($remove)//g;}

  # handle table tags
  if ($l =~ /($tablerstart)/) {&convertTable(\$l);}
 
  $l =~ s/\s*\/\/\s*/ /g; # Force carriage return SFM marker
  
  # paragraphs
  if ($blankline) {$l =~ s/\\$blankline(\s|$)/$LB$LB/g;}
  if ($normpar)   {$l =~ s/\\$normpar(\s|$)/$LB$INDENT/g;}
  if ($doublepar) {$l =~ s/\\$doublepar(\s|$)/$LB$INDENT$INDENT/g;}
  if ($triplepar) {$l =~ s/\\$triplepar(\s|$)/$LB$INDENT$INDENT$INDENT/g;}

  # footnotes, cross references, and glossary entries
  if ($seealsopat) {
    $l =~ s/$seealsopat/my $a = $+; my $res = "<reference type=\"x-glosslink\" osisRef=\"$MOD:".&encodeOsisRef(&suc($a, $SpecialCapitals))."\">$a<\/reference>";/ge;
  }
  if ($crossrefs) {$l =~ s/$crossrefs/<note type="crossReference">$+<\/note>/g;}
  if ($notes)     {$l =~ s/$notes/<note>$+<\/note>/g;}
     
  return $l;  
}

sub convertTable(\$) {
  my $tP = shift;

  if ($tablerstart && !$tablerend) {&Log("ERROR: TABLE_ROW_END must be specified if TABLE_ROW_START is specified.\n");}
  
  #my $w1 = "%-".&getWidestW($tP, "\\t[hc]1 ", "\\t[hc]2 ")."s | ";
  #my $w2 = "%-".&getWidestW($tP, "\\t[hc]2 ", "\\t[hc]3 ")."s | ";
  #my $w3 = "%-".&getWidestW($tP, "\\t[hc]3 ", quotemeta($LB))."s";
  
  if ($tablerstart) {
    if ($tablec1) {$$tP =~ s/($tablec1)(.*?)(($tablec2)|($tablerend))/my $a=$2; my $b=$3;my $f = &formatCell($a, $b).$b;/ge;}
    if ($tablec2) {$$tP =~ s/($tablec2)(.*?)(($tablec3)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/ge;}
    if ($tablec3) {$$tP =~ s/($tablec3)(.*?)(($tablec4)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/ge;}
    if ($tablec4) {$$tP =~ s/($tablec4)(.*?)($tablerend)/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/ge;}

     
    $$tP =~ s/($tablerstart)/$LB/g; # add one line-break before start of other rows 
    $$tP =~ s/\s*($tablerend)\s*/$LB$1/g; # add line-breaks after each table row
  }
}

sub formatCell($$) {
  my $t = shift;
  my $e = shift;
 
  my $cs = "%s | ";
  my $cl = "%s"; 
  $t =~ s/(^\s*|\s*$)//g;
  my $f = sprintf(($e =~ /^($tablerend)$/ ? $cl:$cs), $t);
  
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
  
  push(@SFMEntries, $e);
  
  # remove any trailing LBs
  $t =~ s/((\Q$LB\E)|(\s))+$//;
  
  my $print = "\$\$\$$e\n$t\n";
  
  my $save = $print;
  while ($print =~ s/(\\([\w]*)\*?)//) {
    my $msg = "WARNING Before $ThisSFM Line $lineSFM: Tag \"$1\" was REMOVED from $save.\n";
    $tagsintext .= $msg;
  }
  
  print OUTF $print;
}
