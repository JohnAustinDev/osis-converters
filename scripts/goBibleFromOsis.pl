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

# NOTE: this converter assumes the following:
#   All input OSIS verses are contained on a single line.
#   All input OSIS <div> and <chapter> tags are alone on a line

open(INF, "<:encoding(UTF-8)", $INPUTFILE) || die "Could not open infile $INPUTFILE.\n";
open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) || die "Could not open outfile $OUTPUTFILE.\n";

$line = 0;
&logProgress($INPUTFILE, -1);
$inHeader = true;
while (<INF>) {
  $line++;
  
  if ($_ =~ /<div type="book" osisID="([^"]+)">/) {&logProgress($1, $line);}
  
  # Replace header
  if ($inHeader eq "true") {
    if ($_ !~ s/(<div type="(bookGroup|x-testament)">.*$)/$1/) {next;}
    Write("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<osis>\n<osisText>\n");
    $inHeader = "false";
  }
  
  # Skip these divs
  if ($_ =~ /<div [^>]*type=\"x-([^"]*)(non-canonical|empty)\"/) {next;}
  
  # Reset verse counter used to check Go Bible verse number against osis file's verse number
  if ($_ =~ /<chapter [^>]*osisID="([^\.]+\.(\d+))"/) {
    if ($2 != $cGoBible) {&Log("Error Line $line: Chapter number mismatch in $1\n");}
    $vGoBible = 1;
    $nextOsisVerse = 1;
    $cGoBible++;
  }

  # Skip introductions
  if ($inIntro eq "true" && $_ !~ /<chapter/) {next;}
  else {$inIntro = "false";}
  if ($_ =~ /<div[^>]*type="book"/) {$inIntro = "true"; $cGoBible = 1;}
  
  # Remove titles
  $_ =~ s/<title[^>]*>.*?<\/title>//gi;
  
  # Remove notes
  $_ =~ s/<note[^>]*>.*?<\/note>//gi;
  
  # Remove reference tags
  $_ =~ s/<reference[^>]*>(.*?)<\/reference>/$1/g;

  # Remove milestones
  $_ =~ s/<milestone[^>]*>//gi;
  
  # Remove line breaks
  $_ =~ s/<lb\s*\/>//ig;
  
  # Remove font hilights
  $_ =~ s/<hi [^>]*type="bold"[^>]*>(.*?)<\/hi>/$1/ig;
  $_ =~ s/<hi [^>]*type="italic"[^>]*>(.*?)<\/hi>/$1/ig;
  
  # Remove other OSIS tags
  $_ =~ s/<\/?(list|item)[^>]*>//ig;
  
  # Remove Strongs numbers
  $_ =~ s/<\/?w[^>]*>//g;
  
  # Remove &nbsp;
  $_ =~ s/\&nbsp\;/ /g;
  
  # Collapse white space
  $_ =~ s/\s+/ /g;

  # Change verse tags (and add blank verses as needed)
  if ($_ =~ s/<verse [^>]*osisID=\"([^\"]*)\"[^>]*>(.*?)(<\/verse[^>]*>|<verse[^>]*\/>)/<verse>$2<\/verse>/i) {
    $id = $1;
    $v = $2;
    $blankvs = 0;
    if ($id =~ /[^\.]+\.[^\.]+\.(\d+)-(\d+)$/) {
      $vOsis = $1*1;
      $lv = $2*1;
      $blankvs = ($lv-$vOsis);
    }
    elsif ($id =~ /[^\.]+\.[^\.]+\.(\d+)$/) {$vOsis = $1*1;}
    else {&Log("Error Line $line: Could not determine verse number from $id\n");}
    
    # If input osis verse numbers are ever skipped, insert a blank verse in Go Bible osis
    while ($vOsis > $nextOsisVerse) {$_ = "<verse>.<\/verse>\n".$_; $vGoBible++; $nextOsisVerse++;}
        
    # Check if this input osis verse number matches the Go Bible osis verse number
    if ($vOsis != $vGoBible) {&Log("Error Line $line: Verse number mismatch in $id\n");}
    $nextOsisVerse = ($vOsis+1);
    
    while ($blankvs > 0) {$_ = $_."<verse>.<\/verse>\n"; $blankvs--; $vGoBible++; $nextOsisVerse++;}
    
    $vGoBible++; # point to next verse now
  }
  
  $_ =~ s/((<\/verse>|<\/?div[^>]*>|<\/?chapter[^>]*>)\s*)/$1\n/g;
  
  Write($_);
}
close(INF);
close(OUTF);

# Log tag list
&Log("Listing of tags and entities within verses:\n");
$error = "false";
foreach $tag (keys %tags) {$error = "true"; &Log($tag.":".$tags{$tag}."\n");}
if ($error eq "false") {&Log("Good! No tags or entities were found.\n\n");}
else {&Log("\nERROR: Tags above were found within verses.\n\n");}

sub Write($) {
  my $print = shift;
  my $copy = $print;
  while ($copy =~ s/<verse>(.*?)<\/verse>/$1/) {
    $vtext = $1;
    while ($vtext =~ s/<\/?(\w+)[^>]*>//) {$tags{$1} = $tags{$1}." ".$line;}
    while ($vtext =~ s/(\&.*?\;)//) {$tags{$1} = $tags{$1}." ".$line;}
  }
  print OUTF $print;
}
;1
