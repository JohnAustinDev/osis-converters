# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

sub runChecks {
  my $modType = shift;
  
  # Reset the cache
  our %DOCUMENT_CACHE;
  undef(%DOCUMENT_CACHE); 
  &getOsisModName($XML_PARSER->parse_file($OSIS)); 
  
  # Check all osisRef targets
  if ($modType ne 'dict' || -e &getModuleOsisFile($MAINMOD)) {
  
    # Generate an xml file defining the chosen verse system, for XSLT to 
    # compare against
    &swordVsysXML(&conf('Versification'));
    &Log("\n");
    
    # Check references in the fixed verse system OSIS file
    &checkRefs($OSIS, $modType eq 'dict');
    
    # Check references in the source verse system transform of the OSIS file
    &checkRefs($OSIS, $modType eq 'dict', "sourceVerseSystem.xsl");
  }
  else {
  &Error(
"Glossary and Bible links in the dictionary module cannot be checked.",
"The Bible module OSIS file must be created before the dictionary 
module OSIS file, so that all reference links can be checked. Create the
Bible module OSIS file, then run this dictionary module again.");
  }
  
  &checkFigureLinks($OSIS);
  
  &checkSwordBug($OSIS);
  
  &checkCharacters($OSIS);
  
  my $dwf = &getDWF();
  if ($dwf) {
    &checkAddDictLinksContexts($OSIS, $dwf);
  }
  
  if ($modType eq 'childrens_bible') {
    &checkChildrensBibleStructure($OSIS);
  }
}

sub validateOSIS {
  my $osis = shift;
  
  # Validate an OSIS file against OSIS schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  
  my $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml").' '.
      &escfile("xmllint") . " --noout --schema \"$OSISSCHEMA\" " .
      &escfile($osis);
      
  my $res = &shell($cmd, 0, 3);
  
  my $allow = 
    "(element milestone\: Schemas validity )" . 'error' .
    "( \: Element '.*?milestone', attribute 'osisRef'\: " .
    "The attribute 'osisRef' is not allowed\.)";
  my $fix = $res;
  $fix =~ s/$allow/$1e-r-r-o-r$2/g;
  &Log("$fix\n");
  
  if ($res =~ /failed to load external entity/i) {&Error(
"The validator failed to load an external entity.", 
"Maybe there is a problem with the Internet connection, or with 
one of the input files to the validator.");
  }
  
  # Generate an error if file fails to validate
  my $valid = 0;
  if ($res =~ /^\Q$osis validates\E$/) {$valid = 1;}
  elsif (!$res || $res =~ /^\s*$/) {&Error(
"\"$osis\" validation problem. No success or failure message was 
returned from the xmllint validator.", 
"Check your Internet connection, or try again later.");
  }
  else {
    if ($res =~ s/$allow//g) {
      &Note("
      Ignore the above milestone osisRef attribute reports. The schema  
      here apparently deviates from the OSIS handbook which states that 
      the osisRef attribute is allowed on any element. The current usage  
      is both required and sensible.\n");
    }
    if ($res !~ /Schemas validity error/) {
      &Note("All of the above validation failures are being allowed.");
      $valid = 1;
    }
    else {&Error("\"$osis\" does not validate! See message(s) above.");}
  }
  
  &Report("OSIS " . ($valid ? 'passes':'fails') .
    " required validation.\nEND OSIS VALIDATION");
}

sub checkSwordBug {
  my $inosis = shift;

  my $parser = XML::LibXML->new('line_numbers' => 1);
  my $xml = $parser->parse_file($inosis);
  foreach my $t ( $XPC->findnodes('//osis:div[@type="majorSection"]
      [not(ancestor::osis:div[@type="book"])]', $xml) ) {
    &Error(
"The non-introduction tag on line: ".$t->line_number().", '".&pTag($t)."' 
was used in an introduction. This could trigger a bug in osis2mod.cpp, 
which drops introduction text.", 
'Replace this tag with the proper \imt introduction title tag.');
  }
}

sub checkCharacters {
  my $osis = shift;
  
  open(OSIS, $READLAYER, $osis) || die;
  my %characters;
  while(<OSIS>) {
    foreach my $c (split(/(\X)/, $_)) {
      if ($c =~ /^[\n ]$/) {next;} 
      $characters{$c}++;
    }
  }
  close(OSIS);
  
  my $numchars = keys %characters; my $chars = ''; my %composed;
  foreach my $c (sort { ord($a) <=> ord($b) } keys %characters) {
    my $n=0; foreach my $chr (split(//, $c)) {$n++;}
    if ($n > 1) {$composed{$c} = $characters{$c};}
    $chars .= $c;
  }
  &Report("Characters used in OSIS file:\n$chars($numchars chars)");
  
  # Report composed characters
  my @comp; foreach my $c (sort { 
        ($composed{$b} <=> $composed{$a} ? 
         $composed{$b} <=> $composed{$a} : $a cmp $b)
      } keys %composed) {
    push(@comp, "$c(".$composed{$c}.')');
  }
  &Report("<-Extended grapheme clusters used in OSIS file: " .
    (@comp ? join(' ', @comp) : 'none'));
  
  # Report rarely used characters
  my $rc = 20;
  my @rare; foreach my $c (
    sort { ( !($characters{$a} <=> $characters{$b}) ? 
             ord($a) <=> ord($b) :
             $characters{$a} <=> $characters{$b} ) 
         } keys %characters) {
    if ($characters{$c} >= $rc) {next;}
    push(@rare, $c);
  }
  &Report(
"<-Characters occuring fewer than $rc times in OSIS file (least first): " .
  (@rare ? join(' ', @rare) : 'none'));
  
  # Check for high order Unicode character replacements needed for 
  # gobible/simpleChars.txt
  my %allChars; for my $c (split(//, $chars)) {$allChars{$c}++;}
  my @from; my @to;
  &readReplacementChars(
      &getDefaultFile("bible/gobible/simpleChars.txt"), \@from, \@to);
  foreach my $chr (sort { ord($a) <=> ord($b) } keys %allChars) {
    if (ord($chr) <= $MAX_UNICODE) {next;}
    my $x; for ($x=0; $x<@from; $x++) {
      if (@from[$x] eq $chr) {
        &Note("High Unicode character found ( > $MAX_UNICODE): " .
                ord($chr) . " '$chr' <> '" . @to[$x] . "'");
        last;
      }
    }
    if (@from[$x] ne $chr) {
      &Note("High Unicode character found ( > $MAX_UNICODE): " .
              ord($chr) . " '$chr' <> no-replacement");
      &Warn(
"<-There is no simpleChars.txt replacement for the high 
Unicode character: '$chr'", 
"This character, and its low order replacement, may be added to: 
$SCRIPT/defaults/bible/gobible/simpleChars.txt to remove this warning.");
    }
  }
}

sub readReplacementChars {
  my $replacementsFile = shift;
  my $fromAP = shift;
  my $toAP = shift;

  if (open(INF, $READLAYER, $replacementsFile)) {
    while(<INF>) {
      if ($fromAP && $_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$fromAP}, substr($chars, $i, 1));
        }
      }
      if ($toAP && $_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        my $chars = $1;
        for (my $i=0; substr($chars, $i, 1); $i++) {
          push(@{$toAP}, substr($chars, $i, 1));
        }
      }
      if ($fromAP && $_ =~ /Replace-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$fromAP}, $chars);
      }
      if ($toAP && $_ =~ /With-this-group:\s*(.*?)\s*$/) {
        my $chars = $1;
        push(@{$toAP}, $chars);
      }
    }
    close(INF);
  }
}

# Check figure links in an OSIS file. Checks target URL as well as 
# target image.
my %CHECKFIGURELINKS;
sub checkFigureLinks {
  my $in_osis = shift;
  
  &Log("\nCHECKING OSIS FIGURE TARGETS IN $in_osis...\n");
  
  my $imsg = 
"Figures should be jpg or png image files, generally less than about 
250 KB max size. Image width and height should generally be between 
300 and 1200 pixels. Any text within the figure must be easily readable.";
  my $ierr = 
"This size error may be bypassed by prepending 'xl_' to this file name. 
But do this only if you are sure it is the only solution. It is better 
to use a better compression technique, or shrink the image, to acheive a 
smaller file size.\n";
  
  my $osis = $XML_PARSER->parse_file($in_osis);
  my @links = $XPC->findnodes('//osis:figure', $osis);
  my $errors = 0;
  my $totalsize = 0;
  foreach my $l (@links) {
    my $tag = &pTag($l);
    
    # Check the image path
    my $localPath = &getFigureLocalPath($l);
    if (!$localPath) {
      &Error("Could not determine figure local path of $l");
      $errors++;
      next;
    }
    if (! -e $localPath) {
      &Error(
"checkFigureLinks: Figure \"$tag\" src target does not exist at:
$localPath.");
      $errors++;
    }
    if ($l->getAttribute('src') !~ /^\.\/images\//) {
      &Error(
"checkFigureLinks: Figure \"$tag\" src target is outside of 
\"./images\" directory. This image may not appear in e-versions.");
      $errors++;
    }
    
    # Check the image itself
    if ($CHECKFIGURELINKS{$localPath}) {next;} 
    $CHECKFIGURELINKS{$localPath}++;
    
    my $infoP = &imageInfo($localPath);
    if ($infoP->{'format'}) {
      my $filename = $infoP->{'file'}; $filename =~ s/^.*\/([^\/]+)$/$1/;
      my $ext = $filename; $ext =~ s/^.*\.([^\.]+)$/$1/;
      $totalsize += $infoP->{'size'};
      if ($infoP->{'size'} > 400000 && $filename !~ /^xl_/) {
        &Error(
"Figure image size is too large: $filename = ".&printInt($infoP->{'size'}/1000)." KB", "$imsg
$ierr");
        &Log("\n");
        $errors++;
      }
      elsif ($infoP->{'size'} > 250000) {
        &Warn(
"Figure image file size is large: $filename = ".&printInt($infoP->{'size'}/1000)." KB", $imsg);
        &Log("\n");
      }
      if ($infoP->{'w'} + $infoP->{'h'} > 3000) {
        &Warn(
"Figure image width/height is large: $filename = ".$infoP->{'w'}."px x ".$infoP->{'h'}."px", 
"Normally image width and height should be between 300 and 1200 
pixels. Usually it is best to make the image as small as possible while 
keeping it clear and readable.");
        &Log("\n");
      }
      if ($infoP->{'colorspace'} !~ /^(sRGB|RGB|Gray)$/) {
        &Warn(
"Figure image colorspace is unexpected: $filename = ".$infoP->{'colorspace'}, 
"This may cause problems for some output formats.");
        &Log("\n");
      }
      if ($infoP->{'format'} !~ /^(JPEG|PNG|GIF)$/) {
        &Error(
"Unhandled image type '".$infoP->{'format'}."'.", $imsg);
        &Log("\n");
        $errors++;
      }
      if ($infoP->{'format'} eq 'GIF') {
        &Warn(
"Figure image format GIF may not be supported by some eFormats.", $imsg);
        &Log("\n");
      }
      my $expectedExt = ($infoP->{'format'} eq 'JPEG' ? 'jpg':lc($infoP->{'format'}));
      if ($expectedExt ne $ext) {
        &Error(
"Figure image has the wrong extension: $localPath.", 
"Change this extension to '.$expectedExt'");
        &Log("\n");
        $errors++;
      }
      &Note(sprintf("Figure %-32s %4s   %4s   w=%4i   h=%4i   size=%4s KB", 
        $filename.':', 
        $infoP->{'format'}, 
        $infoP->{'colorspace'}, 
        $infoP->{'w'}, 
        $infoP->{'h'}, 
        &printInt($infoP->{'size'}/1000)
      ));
    }
    else {&Error(
"Could not read necessary image information for $localPath:
".$infoP->{'identify'}, $imsg);}
  }
  
  &Report(
"\"".@links."\" figure targets found and checked. ($errors problem(s))");

  &Report(
"Total size of all images is ".&printInt($totalsize/1000)." KB");
}

1;
