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
#   RUN - Process the book specified by this SFM abbreviation. Only 
#       one SFM book abbreviation per RUN command is allowed. 
#       NOTE: If there are no RUN commands in the file, all books 
#       are processed sequentially after reading the entire command file.
#   GLOSSARY:mod1,words1.txt; SECONDARY_GLOSSARY:mod2,words2.txt; ...
#       Specifies the main glossary module name to link to, along with
#       its DictionaryWords.txt file listing its words and matching
#       terms. Optionally, a semicolon list of secondary glossaries 
#       and DictionaryWords files can also be specified. When an 
#       entry in the primary glossary is linked, all secondary 
#       glossaries will be checked for the same entry. Identical  
#       entries of secondary glossaries will then be added to the 
#       osisRef of the link.
#   ALLOW_IDENTICAL_LINKS - Set to "true" to allow multiple glossary 
#       links with the same target to be added to the same chapter. 
#       Normally only the first glossary reference to a particular 
#       entry is linked per chapter. 
#   CHECK_ONLY - Set to true to skip parsing for links and only check 
#       existing links. During checking, any broken links are corrected.
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching.  
#       Example for: "PUNC_AS_LETTER:'`-" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I
#   REFERENCE_TYPE - The value of the type attribute for 
#       see-also <reference> links which are added to the glossary.

$DEBUG = 0;

&Log("-----------------------------------------------------\nSTARTING addDictLinks.pl\n\n");

$ReferenceType = "x-glossary";
$AllGlossaryTypes = "x-glossary|x-glosslink";
$LinkOnlyFirst = 1;    # Match only the first occurrence of each word in a chapter
$PAL = "\\w";          # Listing of punctuation to be treated as letters, like '`
$Checkonly = 0;        # If set, don't parse new links, only check existing links

# Read the command file. Processing does not begin until reading is completed.
&Log("READING COMMAND FILE \"$COMMANDFILE\"\n");
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) or die "ERROR: Could not open commandFile \"$COMMANDFILE\".";
$OsisWorkTags = "";
$NoBooks = 1;
while(<COMF>) {
  $_ =~ s/^\s*(.*?)\s*$/$1/;
  if ($_ =~ /^\s*$/) {}
  elsif ($_ =~ /^\#/) {}
  elsif ($_ =~ /^CHECK_ONLY:(\s*(.*?)\s*)?$/) {if ($1) {my $t = $2; if ($t && $t !~ /(false|0)/i) {$Checkonly = 1;}}}
  elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PAL .= $2;}}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2; next;}}
  elsif ($_ =~ /^REFERENCE_TYPE:(\s*(.*?)\s*)?$/) {if ($1) {$ReferenceType = $2; next;}}
  elsif ($_ =~ /^ALLOW_IDENTICAL_LINKS:(\s*(.*?)\s*)?$/) {if ($1) {my $t = $2; if ($t && $t !~ /(false|0)/i) {$LinkOnlyFirst = 0;} next;}}
  
  # Some translations have two glossaries, one for OT and another for NT.
  # Each book is only parsed for a main glossary, but matching definitions
  # from all secondary glossaries will also be included in the osisRef.
  
  #GLOSSARY:mod1,words1.txt; SECONDARY_GLOSSARY:mod2,words2.txt; SECONDARY_GLOSSARY:mod3,words3.txt; ...
  elsif ($_ =~ s/^GLOSSARY:([^,]+),\s*([^;]+);//) {
    $wordFile = $2;
    $dictName = $1;
    $secondaryWordFile = "";
    $secondaryDictName = "";
    $AllWordFiles{$dictName} = $wordFile;
    if ($OsisWorkTags !~ /osisWork="$dictName"/) {
      $OsisWorkTags .= "<work osisWork=\"$dictName\"><type type=\"x-glossary\">Glossary</type></work>";
    }
    my $sep = "";
    while ($_ =~ s/^\s*SECONDARY_GLOSSARY:([^,]+),\s*([^;]+);//) {
      my $sdn = $1;
      my $swf = $2;
      $secondaryDictName .= "$sep$sdn";
      $secondaryWordFile .= "$sep$swf";
      $sep = ",";
      $AllWordFiles{$sdn} = $swf;
      if ($OsisWorkTags !~ /osisWork="$sdn"/) {
        $OsisWorkTags .= "<work osisWork=\"$sdn\"><type type=\"x-glossary\">Glossary</type></work>";
      }
    }
  }
  elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
    my $bookName = &getOsisName($1);
    if ($bookName) {
      $NoBooks = 0;
      $DictNames{$bookName} = $dictName;
      $WordFiles{$bookName} = $wordFile;
      $SecondaryDictNames{$bookName} = $secondaryDictName;
      $SecondaryWordFiles{$bookName} = $secondaryWordFile;
    }
  }
  else {&Log("ERROR: Unhandled command \"$_\" in $COMMANDFILE\n");}
}
close (COMF);

# If no books were listed in the command file, then all books are assumed
if ($NoBooks) {
  my %canon;
  my %bookOrder;
  &getCanon("KJV", \%canon, \%bookOrder); # only book list is important, not order
  foreach my $bookName (keys %canon) {
    $WordFiles{$bookName} = $wordFile;
    $DictNames{$bookName} = $dictName;
    $SecondaryDictNames{$bookName} = $secondaryDictName;
    $SecondaryWordFiles{$bookName} = $secondaryWordFile;
  }
}

if ($Checkonly) {
  &Log("Skipping link search. Checking existing links only.\n");
  copy("$INPUTFILE", "$OUTPUTFILE");
  goto CHECK;
}

&Log("READING OSIS FILE: \"$INPUTFILE\".\n");
&Log("WRITING OSIS FILE: \"$OUTPUTFILE\".\n");

# Parse the input OSIS file, add links, and write results to output OSIS files
open(INF, "<:encoding(UTF-8)", $INPUTFILE) or die "ERROR: Could not open inFile \"$inFile\".";
open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE) or die "ERROR: Could not open outFile \"$OUTPUTFILE\".";
$isIntro = 0;
$SkipTerms = "";
%replacements;
%wordHits;
$line=0;
&logProgress($INPUTFILE, -1);
while (<INF>) {
  $line++;

  $isVerse =  0;
  if ($_ =~ /<verse /) {$isVerse = 1;}
  
  # insert the OSIS work tag if an OSIS header is encountered
  if ($OsisWorkTags && $_ =~ /<\/work>/) {
    $_ =~ s/(<\/work>)/$1$OsisWorkTags/;
    $OsisWorkTags = "";
  }
  
  # Update dictionary information for each new book...
  elsif ($_ =~ /<div type="book" osisID="([^"]+)">/) { #"{
    $thisBookName = $1;
    $isIntro = 1;
    if (!exists($WordFiles{$thisBookName}) || !$WordFiles{$thisBookName}) {
      &Log("Skipping $thisBookName");
      $skipBook = 1;
    }
    else {
      $skipBook = 0;
      
      # If this book uses a new word file, load it now...
      if ($WordFiles{$thisBookName} ne $currentWordFile) {
        my $saveLine = $_;
        
        if ($currentWordFile) {
          &logGlossReplacements($currentWordFile, \@words, \%replacements, \%wordHits);
          undef(%replacements);
          undef(%wordHits);
        }

        # Get the List of dictionary keys
        undef @words;
        undef %dictsForWord;
        undef %searchTerms;
        &readGlossWordFile("$INPD/".$WordFiles{$thisBookName}, $DictNames{$thisBookName}, \@words, \%dictsForWord, \%searchTerms);
        
        # Now add any corresponding secondary glossaries to %dictsForWord entries...
        $secondaryDictName = $SecondaryDictNames{$thisBookName};
        $secondaryWordFile = $SecondaryWordFiles{$thisBookName};
        while ($secondaryDictName =~ s/^([^,]+),?//) {
          my $mydname = $1;
          $secondaryWordFile =~ s/^([^,]+),?//;
          my $myfile = "$INPD/".$1;
          my $secwords = "";
          &normalizeNewLines($myfile);
          open(WORDS, "<:encoding(UTF-8)", $myfile) or die "ERROR: Could not open secondary word list \"$myfile\".\n";
          &Log("Reading secondary glossary file \"$myfile\".\n");
          my $sep = "";
          while (<WORDS>) {
            $_ =~ s/^\s*(.*?)\s*$/$1/;
            if  ($_ =~ /^DE(\d+):(.*?)$/i) {$secwords .= $sep.$2; $sep = ",";}
          }
          close (WORDS);
          &Log("Adding secondary dictionary $mydname for these words:");
          my $sep = "";
          foreach my $word (keys %dictsForWord) {
            if ($secwords =~ /(^|,)\Q$word\E,/) {
              $dictsForWord{$word} .= ";$mydname";
              &Log("$sep$word");
              $sep = ", ";
            }
          }
          &Log("\n");
        }
        $_ = $saveLine;
        $currentWordFile = $WordFiles{$thisBookName};
        
        &logProgress("$thisBookName (using \"$currentWordFile\")", $line);
        &Log("Processing $thisBookName (using \"$currentWordFile\")");
      }
      else {
        &logProgress($thisBookName, $line);
        &Log("Processing $thisBookName");
      }
    }
        
    &Log("\n");
  }
  elsif ($_ =~ /<chapter /) {
    $SkipTerms = "";
    $isIntro = 0;
  }
  elsif (!$isIntro && !$isVerse) {} # Don't parse if not a verse or intro!
  
  # Add glossary links to the line
  elsif (!$skipBook) {
    # Exclude notes and titles
    @notes = split(/(<note.*?<\/note>)|(<title.*?<\/title>)/);
    foreach $sb (@notes){
      if ($sb =~ /(<note.*?<\/note>)|(<title.*?<\/title>)/) {next;}

      # keep trying each text piece until no more glossary links are found
      $tryagain = 1;
      while ($tryagain) {
        $tryagain = 0;
        # Exclude existing references
        @links = split(/(<reference .*?<\/reference>)/,$sb);
        foreach $ln (@links) {
          if ($ln =~ /(<reference .*?<\/reference>)/) {next;}          
          $tryagain = &addGlossLink(\$ln, \%dictsForWord, \%searchTerms, \%replacements, \%wordHits, $LinkOnlyFirst, \$SkipTerms, $ReferenceType, $thisBookName, !$isVerse);
          if ($tryagain) {last;}
        }
        $sb = join("",@links);
      }
    }
    $_ = join("",@notes);
  }

  print OUTF $_;
}
close (INF);
close (OUTF);

&logGlossReplacements($currentWordFile, \@words, \%replacements, \%wordHits);

CHECK:
&checkGlossReferences($OUTPUTFILE, $AllGlossaryTypes, \%AllWordFiles);
1;
