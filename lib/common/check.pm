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

# Checks that all verses in verse system vsys are present and accounted 
# for in sequential order. Reports on skipped verses, extra verses and 
# other common problems.

# Check every verse of an OSIS file against a standard versification.
# An error message is generated for each detected deviation. NOTE: This 
# sub cannot detect all possible deviations. For instance if a verse is 
# split into two verses while two other verses in the same chapter are 
# joined, the total number of verses in that chapter remains correct
# according to the standard, and those deviations will not be detected. 
# Also NOTE: when deviations are detected, the resolution is not. For 
# instance, a deviation in a chapter with too many verses will generate
# an error, but any verse in that chapter may have been split into two. 
sub checkVerseSystem {
  my $bibleosis = shift;
  my $vsys = shift;
  
  my $xml = $XML_PARSER->parse_file($bibleosis);
  
  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  &swordVsys($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP);
  
  my $rbk = 'none';
  my $rch = 1;
  my $rvs = 1;
  
  my $errors = 0; my $passed = 0;
  foreach my $v ($XPC->findnodes('//osis:verse[@osisID]', $xml)) {
    foreach my $vid (split(/\s+/, $v->getAttribute('osisID'))) {
      if ($vid !~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
        &ErrorBug("Malformed verse osisID: $vid");
        $errors++;
        next;
      }
      my $bk = $1; my $ch = (1*$2); my $vs = (1*$3);
      
      if (!defined($canonP->{$bk})) {
        if (defined($canonP->{$rbk})) {
          &checkVerseSystemLastVerse(\$rbk, \$rch, \$rvs, $canonP, \$errors);
          &Warn(
"Cannot check verses in book $bk because it is not part of the $vsys verse system.");
        }
        next;
      }
      if ($rbk eq 'none') {$rbk = $bk;}
    
      # Count the passing results
      if    ($bk eq $rbk && 
             $ch == $rch && 
             $vs == $rvs) {
        $passed++;
      }
      elsif ($bk eq $rbk && 
             $ch == ($rch + 1) && 
             $vs == 1 && ($rvs - 1) == @{$canonP->{$rbk}}[$rch-1]) {
        $passed++;
      }
      elsif ($bk ne $rbk &&
             $ch == 1 && $rch == @{$canonP->{$rbk}} && 
             $vs == 1 && ($rvs - 1) == @{$canonP->{$rbk}}[$rch-1]) {
        $passed++;
      }
      
      # Otherwise, report various failing results
      elsif ($vs == 1 && $ch > @{$canonP->{$rbk}}) {
        $errors++;
        &Error("Extra chapter: $bk.$ch", 
&vsmsg("<>This happens for instance when Synodal Pslam 151 is 
included in a SynodalProt translation. Such a situation can be addressed 
in CF_sfm2osis.txt with something like: 
VSYS_EXTRA: Ps.151 <- Synodal:Ps.151
It is also possible some chapter was split into two. This can be 
addressed with something like:
VSYS_CHAPTER_SPLIT_AT: Joel.2.28"));
      }
      elsif ($vs == 1) {
        $errors++;
        my $vl = ($rvs - 1);
        my $vlr = @{$canonP->{$rbk}}[$rch-1];
        if ($vl < $vlr) {
          &Error(
"Chapter ended with ".($vlr-$vl)." missing verse(s): $rbk.$rch",
&vsmsg("<>This often means verses were joined together somewhere 
within the chapter. This can be addressed in CF_sfm2osis.txt with 
something like: 
VSYS_MOVED: Gen.2.4 -> Gen.2.3.PART"));
        }
        else {
          &Error(
"Chapter ended with ".($vl-$vlr)." extra verse(s): $rbk.$rch",
&vsmsg("<>This often means verses were split into smaller 
verses somewhere within the chapter. This can be addressed in 
CF_sfm2osis.txt with something like: 
VSYS_MOVED: Gen.2.3.PART -> Gen.2.4"));
        }
      }
      elsif ($vs > $rvs) {
        $errors++;
        &errMissingVerse("$bk.$ch", $rvs);
      }
      else {
        $errors++;
        &Error(
"Versification problem at $bk.$ch.$vs (expected $rbk.$rch.$rvs)",
"<>Check SFM files for out of order verses, missing or extra chapters.");
      }
      
      $rbk = $bk;
      $rch = $ch;
      $rvs = ($vs+1);
    }
  }
  &checkVerseSystemLastVerse(\$rbk, \$rch, \$rvs, $canonP, \$errors);

  if (!$errors && $passed) {
    &Log("\n"); 
    &Note("All verses were checked against verse system $vsys.");
  }
  
  &Report("$errors verse system problems detected".($errors ? ':':'.'));
  if ($errors) {
    &Note("
      This translation does not fit the $vsys verse system. The errors 
      listed above must be fixed. Add the appropriate instructions:
      VSYS_EXTRA, VSYS_MISSING and/or VSYS_MOVED to CF_sfm2osis.txt.");
  }
}

sub checkVerseSystemLastVerse {
  my $rbkP = shift;
  my $rchP = shift;
  my $rvsP = shift;
  my $canonP = shift;
  my $errorsP = shift;
  
  if (defined($canonP->{$$rbkP})) {
    if ($$rchP != @{$canonP->{$$rbkP}} || ($$rvsP - 1) != @{$canonP->{$$rbkP}}[$$rchP-1]) {
      $$errorsP++;
      &Error(
"The book's last verse, $$rbkP.$$rchP.".($$rvsP-1).", is not the last  
verse of the verse system: $$rbkP.$$rchP.".@{$canonP->{$$rbkP}}[$$rchP-1], 
&vsmsg());
    }
  }
  
  $$rbkP = 'none';
  $$rchP = 1;
  $$rvsP = 1;
}

sub errMissingVerse {
  my $bkch = shift;
  my $vs = shift;
  
&Error("Missing verse $bkch.$vs.", 
&vsmsg("<>A possible cause of this error is that a verse 
has been left out on purpose. Often there is a related footnote at the 
end of the previous verse containing the text of the missing verse. This
situation would be addressed with:
VSYS_MISSING_FN: $bkch.$vs
However, if there is no footnote and a verse (or verses) have been left 
out on purpose, this would be addressed with:
VSYS_MISSING: $bkch.$vs"));
}

our $VSMSG_DONE;
sub vsmsg {
  my $msg = shift;
  
  if ($VSMSG_DONE) {return $msg;}
  $VSMSG_DONE++;
  return "$msg
------------------------------------------------------------------------
------------------------------------------------------------------------
" . &help('VSYS INSTRUCTIONS', 1) . "
------------------------------------------------------------------------
------------------------------------------------------------------------";
}

sub runChecks {

  # Reset the cache
  our %DOCUMENT_CACHE;
  undef(%DOCUMENT_CACHE); 
  &getOsisModName($XML_PARSER->parse_file($OSIS)); 
  
  # Check all osisRef targets
  if ($MOD eq $MAINMOD || -e &getModuleOsisFile($MAINMOD)) {
  
    # Generate an xml file defining the chosen verse system, for XSLT to 
    # compare against
    &swordVsysXML(&conf('Versification'));
    &Log("\n");
    
    # Check references in the fixed verse system OSIS file
    &checkRefs($OSIS, $MOD eq $DICTMOD);
    
    # Check references in the source verse system transform of the OSIS file
    &checkRefs($OSIS, $MOD eq $DICTMOD, "sourceVerseSystem.xsl");
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
  
  if ($MOD eq $MAINMOD && &conf('ProjectType') eq 'childrens_bible') {
    &checkChildrensBibleStructure($OSIS);
  }
  
  if ($DICTMOD && $MOD eq $DICTMOD) {
    foreach my $div ($XPC->findnodes('//osis:div[@type="glossary"]
      [not(descendant::osis:seg[@type="keyword"])]', &getOsisXML($MOD))) {
      &Error(
"This glossary has no keywords: '" . $div . "'.", 
"GLO SFM files must contain at least one keyword. EVAL_REGEX may
be used to add keywords: \\k keyword \\k*. Material before the first keyword 
will not be included in SWORD.");
    }
  }
}

sub checkRefs {
  my $osis = shift;
  my $isDict = shift;
  my $prep_xslt = shift;
  
  my $t = ($prep_xslt =~ /fitted/i ? ' FITTED':($prep_xslt =~ /source/i ? ' SOURCE':''));
  &Log("CHECKING$t OSISREF/OSISIDS IN OSIS: $osis\n");
  
  my $main = ($isDict ? &getModuleOsisFile($MAINMOD):$osis);
  my $dict = ($isDict ? $osis:'');
  
  if ($prep_xslt) {
    &runScript("$SCRD/lib/$prep_xslt", \$main);
    if ($dict) {
      &runScript("$SCRD/lib/$prep_xslt", \$dict);
    }
  }
  
  my %params = ( 
    'MAINMOD_URI' => $main, 
    'DICTMOD_URI' => $dict, 
    'versification' => ($prep_xslt !~ /source/i ? &conf('Versification'):'')
  );
  my $result = &runXSLT("$SCRD/lib/checkrefs.xsl", ($isDict ? $dict:$main), '', \%params);
  
  &Log($result."\n");
}

sub validateOSIS {
  my $osis = shift;
  
  # Validate an OSIS file against OSIS schema
  &Log("\n--- VALIDATING OSIS \n", 1);
  &Log("BEGIN OSIS VALIDATION\n");
  
  my $cmd = "XML_CATALOG_FILES=".&escfile($SCRD."/xml/catalog.xml").' '.
      &escfile("xmllint") . " --noout --schema \"$OSISSCHEMA\" " .
      &escfile($osis);
      
  my $res = &shell($cmd, 3, 1);
  
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
      &getDefaultFile("gobible/simpleChars.txt"), \@from, \@to);
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
