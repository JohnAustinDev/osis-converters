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

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($READLAYER, $WRITELAYER, $MOD_OUTDIR, @VSYS_INSTR,
    $NO_OUTPUT_DELETE, $MODULETOOLS_BIN, $DEBUG);
    
# Initialized below
our ($sourceProject);

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   RUN - Process the SFM file or file glob. Multiple RUN commands are allowed.
#   SET_script - Include script during processing (true|false|<option>)
#   EVAL_REGEX(group): example: s/\\col2 /\p /g - evaluates this perl 
#       regexp on the entire file as a single string. Multiple   
#       EVAL_REGEX commands will be applied one after the other, in the
#       order they appear in the CF file. A group name in parenthesis is 
#       optional, and makes the regex a member of a group. Using an 
#       "EVAL_REGEX(group):" with an empty expression field clears all 
#       EVAL_REGEX expressions in that group. Using "EVAL_REGEX:" with 
#       an empty expression field clears all EVAL_REGEX expressions
#       which are not part of any group.
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching word boundaries. 
#       Example for : "PUNC_AS_LETTER:'`" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization which Perl does not handle well. 
#       Example: SPECIAL_CAPITALS:i->İ ı->I
#   VSYS_EXTRA, VSYS_MISSING, VSYS_MOVED - see fitToVerseSystem.pm

my (@EVAL_REGEX, $USFMfiles);
sub sfm2osis {
  my $cf = shift;
  my $osis = shift;
  
  &Log("\nCONVERTING SFM TO OSIS: sfm2osis\n-----------------------------------------------------\n\n", 1);

  open(COMF, $READLAYER, $cf) || die "Could not open sfm2osis command file $cf\n";

  #Defaults:
  @EVAL_REGEX = ();

=pod  
  # By default remove optional line breaks.
  push(@EVAL_REGEX, {
    'group' => 'OPTIONAL_LINE_BREAKS', 
    'regex' => 's/([\n\s]*)\/\/([\n\s]*)/ /g', 
    'singleFile' => ''
  });
  if (!&shell("grep -e '^EVAL_REGEX\(OPTIONAL_LINE_BREAKS\)\:\\s*\$' \"$cf\"", 3, 1)) {
    &Note("Optional line breaks will be removed. To keep them, add the 
following to $cf:\nEVAL_REGEX(OPTIONAL_LINE_BREAKS):");
  }
=cut
  
  # Variables for versemap feature
  @VSYS_INSTR = ();

  my $line=0;
  while (<COMF>) {
    $line++;
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^EVAL_REGEX(\((.*?)\))?:\s*(.*?)\s*$/) {
      my $rg = ($1 ? $2:'');
      my $rx = $3;
      if ($rx =~ /^\s*$/) {
        for (my $i=0; $i<@EVAL_REGEX; $i++) {
          if (${@EVAL_REGEX[$i]}{'group'} ne $rg) {next;}
          splice(@EVAL_REGEX, $i, 1);
          $i--;
        }
      }
      else {
        my $sf = ($rg && -e "$INPD/$rg" ? 1:0); # Is this group a single file?
        if ($rg && !$sf) {
          &Warn("EVAL_REGEX does not apply to a specific file: ($rg):$rx", 
"<>The label does not apply to a specific file. So it will be 
applied to all following RUN commands until/unless canceled by: 
'EVAL_REGEX(the-label):'\n");
        }
        push(@EVAL_REGEX, {'group' => $rg, 'regex' => $rx, 'singleFile' => $sf});
      }
      next;
    }
    elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {our $SPECIAL_CAPITALS = $2; next;}}
    elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {our $PUNC_AS_LETTER = $2; next;}}
    elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
      my $runTarget = $1;
      my $SFMfileGlob = $runTarget;
      $SFMfileGlob =~ s/\\/\//g;
      $SFMfileGlob =~ s/ /\\ /g; # spaces in file names are possible and need escaping
      if ($SFMfileGlob =~ /^\./) {
        $SFMfileGlob = File::Spec->rel2abs($SFMfileGlob, $INPD);
      }
      if (@EVAL_REGEX) {$USFMfiles .= &evalRegex($SFMfileGlob, $runTarget);}
      else {$USFMfiles .= "$SFMfileGlob ";}
    }
    elsif (!&parseInstructionVSYS($_)) {
      &Error("Unhandled CF_sfm2osis.txt line \"$_\" in $cf", 
      "Remove or fix the syntax of this line.");
    }
  }
  close(COMF);

  @VSYS_INSTR = sort { &sortVsysInst($a, $b) } @VSYS_INSTR;

  # If we're not deleting previously written output files, we're wanting 
  # to skip this initial conversion.
  if ($NO_OUTPUT_DELETE) {return;} 
  
  my $lang = &conf('Lang');
  $lang =~ s/-.*$//;
  $lang = ($lang ? " -l $lang":'');
  
  my $cmd = &escfile($MODULETOOLS_BIN."usfm2osis.py") . 
            " $MOD -v -s none -x -r".$lang." -o " . 
            &escfile("$osis") . ($DEBUG ? " -d":'') . " $USFMfiles";

  my $log = &shell($cmd);
  
  if ($log =~ /Unhandled/i) {
    &Error("usfm2osis.py left unhandled SFM tags.", 
      &para("See 'Unhandled' message(s) above. Usually these tags are not USFM 2.4 compliant. See the USFM 2.4 specification at:
\\b
https://ubs-icap.org/chm/usfm/2.4/index.html
\\b
Sometimes there is a bug or feature of CrossWire's usfm2osis.py script or the USFM or OSIS specifications involved. EVAL_REGEX can be used to change or remove offending SFM tags:") .
&help('EVAL_REGEX', 1, 1));
  }
  &Log("\n");

  return;
}

sub evalRegex {
  my $usfmFiles = shift;
  my $runTarget = shift;
  
  my $outFiles = '';
  
  &Log("Processing USFM $usfmFiles\n");
  
  # If needed, preprocess tags before running usfm2osis.py
  my $tmp = "$TMPDIR/sfm";
  make_path($tmp);
  my @files;
  foreach my $f (glob $usfmFiles) {
    my $df = $f;
    $df =~ /^.*?[\\\/]([^\\\/]+)[\\\/]([^\\\/]+)$/;
    my $pd = $1; my $dd = $2;
    if ($pd eq 'sfm') {$df = "$tmp/$2";}
    else {
      if (!-e "$tmp/$1") {mkdir("$tmp/$1");}
      $df = "$tmp/$1/$2";
    }
    my $n = 0;
    while (-e $df) {
      my $m1 = ($n ? "_$n":'');
      $n++;
      my $m2 = ($n ? "_$n":'');
      $df =~ s/$m1(\.[^\.]+)$/$m2$1/;
    }
    if ($n && !$NO_OUTPUT_DELETE) {
      &Warn("Running copy $n of $f.", 
      "Is it intentional that an SFM file is being RUN multiple times?");
    }
    copy($f, $df);
    push (@files, $df);
  }
  foreach my $f2 (@files) {
    my %eval_regex_report;
    my %eval_regex_applied;
  
    $outFiles .= "\"".$f2."\" ";
    
    my $fln = $f2; $fln =~ s/^.*\/([^\/]+)$/$1/;
    
    if (!open(SFM, $READLAYER, $f2)) {
      &Error("Could not open SFM file \"$f2\"", 
      "This file was incorrectly specified in a RUN line of CF_sfm2osis.txt.", 1);
    }
    
    # Variables names in the following block should be uncommon, because 
    # EVAL_REGEX statments may use variables with the e flag, and we 
    # don't want collisions in the eval!
    my $sww = join('', <SFM>); 
    foreach my $rww (@EVAL_REGEX) {
      if ($rww->{'singleFile'} && $rww->{'group'} ne $runTarget) {next;}
      my $numww;
      if (!defined(eval("\$numww = scalar(\$sww =~ ".$rww->{'regex'}.");"))) {
        &Error("Bad EVAL_REGEX expression: ".$rww->{'regex'}." ($@)", 
        "Fix this EVAL_REGEX expression in CF_sfm2osis.txt", 1);
      }
      elsif ($numww) {
        $eval_regex_applied{$rww->{'regex'}}++;
        $eval_regex_report{$rww->{'regex'}} += $numww;
      }
    }
    close(SFM);
    
    open(SFM2, $WRITELAYER, "$f2.new") or die;
    print SFM2 $sww;
    close(SFM2);
    
    unlink($f2);
    rename("$f2.new", "$f2");
    
    foreach my $r (@EVAL_REGEX) {
      if ($r->{'singleFile'} && $r->{'group'} ne $runTarget) {next;}
      if (!$eval_regex_applied{$r->{'regex'}}) {
        if ($r->{'group'} ne 'OPTIONAL_LINE_BREAKS') {
          &Log("Never applied: ".$r->{'regex'}."\n");
        }
      }
      else {&Log(sprintf("Applied sub (%2i): %s\n", $eval_regex_report{$r->{'regex'}}, $r->{'regex'}));}
    }
  }
  &Log("\n");
  
  return $outFiles;
}

1;
