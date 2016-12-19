#!/usr/bin/perl
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

# Convert old style DictionaryWords.txt to new XML DictionaryWords.xml.
#
# Old style entries were always upper case while the new are not. Since
# there is no way to know what the lowercase entries may have been exactly,
# a check will be done when the dictionary source is converted and such
# entries will be corrected then.

$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init();
require("$SCRD/scripts/processGlossary.pl");

my @entry, %pattern;
open(INF, "<:encoding(UTF-8)", "$INPD/DictionaryWords.txt") or die;
while(<INF>) {
  if ($_ =~ /^#/ || $_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^DE(\d+):\s*(.*?)\s*$/) {@entry[$1] = $2;}
  elsif ($_ =~ /^DL(\d+):\s*(.*?)\s*$/) {$pattern{@entry[$1]}{$2}++;}
  else {&Log("ERROR: Could not parse \"$_\"\n", 1);}
}
close(INF);
&convertDWF(\@entry, \%pattern, 0, "$OUTDIR/DictionaryWords.xml");
&convertDWF(\@entry, \%pattern, 1, "$OUTDIR/DictionaryWords_SeeAlsoBackwardCompatible.xml");

&Log("\nOUTPUT FILES CREATED:\n", 1);
&Log("OUTDIR/DictionaryWords.xml\n", 1);
&Log("OUTDIR/DictionaryWords_SeeAlsoBackwardCompatible.xml (the old addSeeAlsoLinks.pl 
implementation never allowed wildcard endings even if they were specified 
in DictionaryWords.txt, so this file emulates that behaviour such that 
new SeeAlso links may still match the old)\n", 1);

sub convertDWF($\@\%$) {
  my $entryP = shift;
  my $patternP = shift;
  my $dict_backwardCompat = shift;
  my $out_file = shift;

  my %prints;
  foreach my $e (@$entryP) {
    if (!$e) {next;}
    $c++;
    my $print = "  <entry osisRef=\"".&entry2osisRef($MOD, $e)."\">\n    <name>$e</name>\n";
    my $matchlen = 999;
    foreach my $p (sort {&sortSearchTermKeys($a, $b);} keys %{$patternP->{$e}}) {
      my $attribs = '';
      my $reflags = "i";
      while ($p =~ s/<([^<>]*)>\s*$//) {
        my $inst = $1;
        if ($inst =~ /^\s*verse must contain "(.*)"\s*$/) {&Log("ERROR: \"verse must contain\" is no longer supported\n");}
        elsif ($inst =~ /^\s*only New Testament\s*$/i) {$attribs .= " onlyNewTestament=\"true\"";}
        elsif ($inst =~ /^\s*only Old Testament\s*$/i) {$attribs .= " onlyOldTestament=\"true\"";}
        elsif ($inst =~ /^\s*only book\(s\)\:\s*(.*)\s*$/i) {$attribs .= " context=\"$1\"";}
        elsif ($inst =~ /^\s*not in book\(s\)\:\s*(.*)\s*$/i) {$attribs .= " notContext=\"$1\"";}
        elsif ($inst =~ /^\s*case sensitive\s*$/i) {$reflags = '';}
        else {&Log("ERROR: Unhandled instruction \"<$inst>\"\n");}
      }
      
      my $p1 = &getPattern($p, $dict_backwardCompat);
      
      $print   .= "    <match$attribs>/\\b(?'link'$p1)\\b/$reflags</match>\n";
      
      if (length($p1) < $matchlen) {$matchlen = length($p1);}
    }
    $print   .= "  </entry>\n\n";
    
    $prints{(($matchlen*10000)+$c)} = $print;
  }

  open(DWORDS, ">:encoding(UTF-8)", $out_file) or die;
  print DWORDS &dictWordsHeader();
  print DWORDS "<dictionaryWords version=\"1.0\">\n<div highlight=\"false\" multiple=\"false\">\n\n";
  foreach my $e (sort {$b <=> $a} keys %prints) {print DWORDS $prints{$e};}
  print DWORDS "</div>\n</dictionaryWords>";
  close(DWORDS);
}

sub getPattern($$) {
  my $p = shift;
  my $dict_bwcompat = shift;
  
  $p =~ s/(^["\s]+|\s+$)//g; # remove fluff
  
  if ($p !~ s/"$//) {
    if (!$dict_bwcompat) {$p .= ".*?";}
  }
  
  #p now holds the pattern which is a combination of text and possibly perl special chars
  $p =~ s/([\s\w$PUNC_AS_LETTER]+)/\\Q$1\\E/g;
  
  $p =~ s/</&lt;/g;
  $p =~ s/>/&gt;/g;
  
  return $p;
}

1;
