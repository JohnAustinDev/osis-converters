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
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I
#   EVAL_REGEX: example: s/\\col2 /\p /g -evaluates this perl regexp on  
#       each line. Equivalent to: $_ =~ RegExp in Perl. Multiple  
#       EVAL_REGEX commands are allowed.     

&Log("-----------------------------------------------------\nSTARTING usfm2osis.pl\n\n");

open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open usfm2osis command file $COMMANDFILE\n";

#Defaults:
$AllowSet = "addScripRefLinks|addDictLinks|addCrossRefs|addSeeAlsoLinks";
$addScripRefLink = 0;
$addDictLinks = 0;
$addCrossRefs = 0;
$addSeeAlsoLinks = 0;
@EVAL_REGEX;

$line=0;
while (<COMF>) {
  $line++;
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  elsif ($_ =~ /^SET_($AllowSet):(\s*(\S+)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = $val;
      if ($par =~ /^(addScripRefLinks|addDictLinks|addCrossRefs|addSeeAlsoLinks)$/) {
        $$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
      }
      &Log("INFO: Setting $par to $$par\n");
    }
  }
  elsif ($_ =~ /^EVAL_REGEX:\s*(.*?)\s*$/) {push(@EVAL_REGEX, $1); next;}
  elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2; next;}}
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
  else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
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
      open(SFM, "<:encoding(UTF-8)", $f2) || die "ERROR: could not open \"$f2\"\n";
      open(SFM2, ">:encoding(UTF-8)", "$f2.new") || die;
      my $line = 0;
      while(<SFM>) {
        $line++;
        foreach my $r (@EVAL_REGEX) {
          if (eval("\$_ =~ $r;")) {&Log("Line $line: Applied EVAL_REGEX: $r\n");}
        }
        print SFM2 $_;
      }
      close(SFM2);
      close(SFM);
      unlink($f2);
      rename("$f2.new", "$f2");
    }
  }
  
  my $cmd = &escfile("$USFM2OSIS/usfm2osis.py") . " Bible.$MOD -v -x -r -o " . &escfile("$OUTPUTFILE") . " $USFMfiles";
  &Log($cmd . "\n", 1);
  &Log(`$cmd` . "\n", 1);
}
else {&Log("\nDebug: skipping conversion\n");}

1;
