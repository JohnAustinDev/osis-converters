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
#       each line. Equivalent to: $_ =~ RegExp in Perl. Multiple  
#       EVAL_REGEX commands are allowed.
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching word boundaries. 
#       Example for : "PUNC_AS_LETTER:'`" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I

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
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:0);
        &Log("INFO: Setting $par to $val\n");
      }
    }
    elsif ($_ =~ /^EVAL_REGEX:\s*(.*?)\s*$/) {push(@EVAL_REGEX, $1); next;}
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
      $USFMfiles .= $SFMfile . " ";
    }
    else {&Log("ERROR: Unhandled entry \"$_\" in $cf\n");}
  }
  close(COMF);

  if (!$DEBUG_SKIP_CONVERSION) {
    &Log("Processing USFM $USFMfiles\n");
    
    # If needed, preprocess tags before running usfm2osis.py
    if (@EVAL_REGEX) {
      my $tmp = "$TMPDIR/sfm";
      make_path($tmp);
      foreach my $f1 (glob $USFMfiles) {copy($f1, $tmp);}
      $USFMfiles = "$tmp/*.*";
      foreach my $f2 (glob $USFMfiles) {
        my $fln = $f2; $fln =~ s/^.*\/([^\/]+)$/$1/;
        open(SFM, "<:encoding(UTF-8)", $f2) || die "ERROR: could not open \"$f2\"\n";
        open(SFM2, ">:encoding(UTF-8)", "$f2.new") || die;
        my $line = 0;
        while(<SFM>) {
          $line++;
          foreach my $r (@EVAL_REGEX) {
            if (eval("\$_ =~ $r;")) {
              if ($DEBUG) {&Log("$fln:$line: Applied EVAL_REGEX: $r\n");}
              $eval_regex_report{$r}++;
            }
          }
          print SFM2 $_;
        }
        close(SFM2);
        close(SFM);
        unlink($f2);
        rename("$f2.new", "$f2");
      }
    }
    foreach my $r (keys %eval_regex_report) {&Log("Applied \"$r\" ".$eval_regex_report{$r}." times\n");}
    &Log("\n");
    
    my $lang = $ConfEntryP->{'Lang'}; $lang =~ s/-.*$//;
    $lang = ($lang ? " -l $lang":'');
    my $cmd = &escfile("$USFM2OSIS/usfm2osis.py") . " $MOD -v -x -r".$lang." -o " . &escfile("$osis") . ($DEBUG ? " -d":'') . " $USFMfiles";
    &Log($cmd . "\n", 1);
    &Log(`$cmd` . "\n", 1);
  }
  else {&Log("\nDebug: skipping conversion\n", 1);}
  
  return $osis;
}

1;
