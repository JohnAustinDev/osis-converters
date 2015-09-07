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
#
########################################################################

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   RUN - Process the SFM file or file glob. Multiple RUN commands are allowed.
#   SET_script - Include script during processing (true|false|<option>)
#   EVAL_REGEX: example: s/\\col2 /\p /g -evaluates this perl regexp on  
#       the entire file as a single string. Multiple EVAL_REGEX commands  
#       will be applied one after the other.
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching word boundaries. 
#       Example for : "PUNC_AS_LETTER:'`" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization which Perl does not handle well. 
#       Example: SPECIAL_CAPITALS:i->İ ı->I

sub usfm2osis($$) {
  my $cf = shift;
  my $osis = shift;
  
  &Log("CONVERTING USFM TO OSIS: usfm2osis.pl\n-----------------------------------------------------\n\n", 1);

  open(COMF, "<:encoding(UTF-8)", $cf) || die "Could not open usfm2osis command file $cf\n";

  #Defaults:
  @EVAL_REGEX;

  $line=0;
  while (<COMF>) {
    $line++;
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^SET_(addScripRefLinks|addDictLinks|addCrossRefs|addSeeAlsoLinks):(\s*(\S+)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        if (defined($$par)) {&Log("ERROR: A particular SET command may only appear once, and it applies everywhere.\n");}
        else {
          $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
          &Log("INFO: Setting $par to $val\n");
        }
      }
    }
    elsif ($_ =~ /^EVAL_REGEX:\s*(.*?)\s*$/) {
      my $rx = $1;
      if ($rx =~ /^\s*$/) {@EVAL_REGEX = ();}
      else {push(@EVAL_REGEX, $rx);}
      next;
    }
    elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2; next;}}
    elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PUNC_AS_LETTER = $2; next;}}
    elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
      $SFMfile = $1;
      $SFMfile =~ s/\\/\//g;
      if ($SFMfile =~ /^\./) {
        chdir($INPD);
        $SFMfile = File::Spec->rel2abs($SFMfile);
        chdir($SCRD);
      }
      if (@EVAL_REGEX) {$USFMfiles .= &evalRegex($SFMfile);}
      else {$USFMfiles .= "$SFMfile ";}
    }
    else {&Log("ERROR: Unhandled entry \"$_\" in $cf\n");}
  }
  close(COMF);

  my $lang = $ConfEntryP->{'Lang'}; $lang =~ s/-.*$//;
  $lang = ($lang ? " -l $lang":'');
  my $cmd = &escfile($MODULETOOLS_BIN."usfm2osis.py") . " $MOD -v -x -r".$lang." -o " . &escfile("$osis") . ($DEBUG ? " -d":'') . " $USFMfiles";

  my $use_u2o = 0;
  if (!$use_u2o) {
    &Log($cmd . "\n", 1);
    &Log(`$cmd` . "\n", 1);
  }
  
  # test/evaluation for u2o.py script
  my $home = `echo \$HOME`; chomp($home);
  my $osis2 = "$OUTDIR/u2o_evaluation.xml";
  if ($use_u2o) {$osis2 = $osis;}
  $cmd = &escfile("$home/.osis-converters/src/u2o/u2o.py") . " -e UTF8 -v".$lang." -o " . &escfile($osis2) . ($DEBUG ? " -d":'') . " " .$MOD . " $USFMfiles 2>&1";
  &Log("The following is a test of u2o.py...\n", 1);
  &Log($cmd . "\n", 1);
  &Log(`$cmd` . "\n", 1);
  &Log("Failure of u2o.py above does not effect other osis-converters conversions.\n", 1);
  
  return $osis;
}

sub evalRegex($) {
  my $usfmFiles = shift;
  
  my $outFiles = '';
  my %eval_regex_report;
  
  &Log("Processing USFM $usfmFiles\n");
  
  # If needed, preprocess tags before running usfm2osis.py
  my $tmp = "$TMPDIR/sfm";
  make_path($tmp);
  my @files;
  foreach my $f (glob $usfmFiles) {
    my $df = $f; $df =~ s/^.*?([^\\\/]*)$/$1/; $df = "$tmp/$df";
    copy($f, $df);
    push (@files, $df);
  }
  foreach my $f2 (@files) {
    $outFiles .= $f2 . " ";
    
    my $fln = $f2; $fln =~ s/^.*\/([^\/]+)$/$1/;
    
    if (!open(SFM, "<:encoding(UTF-8)", $f2)) {&Log("ERROR: could not open \"$f2\"\n"); die;}
    my $s = join('', <SFM>); foreach my $r (@EVAL_REGEX) {if (eval("\$s =~ $r;")) {$eval_regex_applied{$r}++;}}
    close(SFM);
    
    open(SFM2, ">:encoding(UTF-8)", "$f2.new") or die;
    print SFM2 $s;
    close(SFM2);
    
    # the following is only for getting replacement line counts, since eval() does not allow this directly
    if (!open(SFM, "<:encoding(UTF-8)", $f2)) {&Log("ERROR: could not open \"$f2\"\n"); die;}
    while (<SFM>) {foreach my $r (@EVAL_REGEX) {if (eval("\$_ =~ $r;")) {$eval_regex_report{$r}++;}}}
    foreach my $r (@EVAL_REGEX) {if ($eval_regex_report{$r} > 1 && $r !~ /\/\w*g\w*$/) {$eval_regex_report{$r} = 1;}}
    close(SFM);
    
    unlink($f2);
    rename("$f2.new", "$f2");
  }
  
  foreach my $r (@EVAL_REGEX) {
    if (!$eval_regex_report{$r} && !$eval_regex_applied{$r}) {&Log("Never applied \"$r\".\n");}
    elsif ($eval_regex_report{$r}) {&Log("Applied \"$r\" on ".$eval_regex_report{$r}." lines.\n");}
    else {&Log("Applied \"$r\ on ?? lines.\n");}
  }
  &Log("\n");
  
  return $outFiles;
}

1;
