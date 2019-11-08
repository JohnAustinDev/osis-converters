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
#   VSYS_EXTRA, VSYS_MISSING, VSYS_MOVED - see fitToVerseSystem.pl

$EVAL_REGEX_MSG = 
"IMPORTANT for EVAL_REGEX:
EVAL_REGEX instructions only effect RUN statements which come later on 
in CF_usfm2osis.txt. Also note that:
EVAL_REGEX(someText):s/before/after/
is only effective until an empty
EVAL_REGEX(someText):
statement is encountered, which will cancel all previous 
EVAL_REGEX(someText) statements. OR, if someText is a file path, then it 
will only apply when that particular file is later run.";

sub usfm2osis($$) {
  my $cf = shift;
  my $osis = shift;
  
  &Log("CONVERTING USFM TO OSIS: usfm2osis.pl\n-----------------------------------------------------\n\n", 1);

  open(COMF, "<$READLAYER", $cf) || die "Could not open usfm2osis command file $cf\n";

  #Defaults:
  @EVAL_REGEX;
  
  # Variables for versemap feature
  @VSYS_INSTR = ();

  $line=0;
  while (<COMF>) {
    $line++;
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^SET_(addScripRefLinks|addFootnoteLinks|addDictLinks|addCrossRefs|addSeeAlsoLinks|reorderGlossaryEntries|customBookOrder|sourceProject|sfm2all_\w+|DEBUG):(\s*(.*?)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        if (defined($$par) && $$par ne 'on_by_default') {
          &Error("The SET_$par command may only appear once, and it applies everywhere.", "Remove all but one of the SET_$par commands from $cf");
        }
        else {
          $$par = ($val && $val !~ /^(0|false)$/i ? $val:'');
          &Log("INFO: Setting $par to $val\n");
        }
      }
    }
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
        if ($rg && !$sf) {&Warn("EVAL_REGEX($rg):$rx does not apply to a specific file.", "<>Label \"$rg\" does not apply to a specific file. So this will be applied to all following RUN commands until/unless canceled by: 'EVAL_REGEX($rg):'");}
        push(@EVAL_REGEX, {'group' => $rg, 'regex' => $rx, 'singleFile' => $sf});
      }
      next;
    }
    elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2; next;}}
    elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PUNC_AS_LETTER = $2; next;}}
    elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
      my $runTarget = $1;
      $SFMfileGlob = $runTarget;
      $SFMfileGlob =~ s/\\/\//g;
      $SFMfileGlob =~ s/ /\\ /g; # spaces in file names are possible and need escaping
      if ($SFMfileGlob =~ /^\./) {
        $SFMfileGlob = File::Spec->rel2abs($SFMfileGlob, $INPD);
      }
      if (@EVAL_REGEX) {$USFMfiles .= &evalRegex($SFMfileGlob, $runTarget);}
      else {$USFMfiles .= "$SFMfileGlob ";}
    }
    
    # VSYS INSTRUCTIONS used in fitToVerseSystem.pl
    elsif ($_ =~ /^VSYS_MISSING:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
      my $value = $+{val};
      push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$value });
    }
    elsif ($_ =~ /^VSYS_EXTRA:(?:\s*(?<to>$VSYS_INSTR_RE)\s*<\-\s*(?<from>$VSYS_UNIVERSE_RE)\s*)?$/) {
      my $to = $+{to}; my $from = $+{from};
      push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'universal'=>$from, 'source'=>$to });
    }
    elsif ($_ =~ /^VSYS_FROM_TO:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
      my $from = $+{from}; my $to = $+{to};
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
    }
    elsif ($_ =~ /^VSYS_EMPTY:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
      my $value = $+{val};
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>'' });
    }
    elsif ($_ =~ /^VSYS_MOVED:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
      my $from = $+{from}; my $to = $+{to};
      push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
      push(@VSYS_INSTR, { 'inst'=>'EXTRA',   'source'=>$to });
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
    }
    elsif ($_ =~ /^VSYS_MOVED_ALT:(\s*(?<from>$VSYS_PINSTR_RE)\s*\->\s*(?<to>$VSYS_PINSTR_RE)\s*)?$/) {
      my $from = $+{from}; my $to = $+{to};
      push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$from });
      push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$from, 'source'=>$to });
    }
    elsif ($_ =~ /^VSYS_MISSING_FN:(?:\s*(?<val>$VSYS_INSTR_RE)\s*)?$/) {
      my $value = $+{val};
      my $msg = "VSYS_MISSING_FN is used when a previous verse holds a footnote about the missing verse.";
      my $vp = $value;
      if ($vp =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
        my $bk = $1; my $ch = $2; my $vs = (1*$3);
        my $to = "$bk.$ch.".($vs-1);
        if ($vs > 1) {
          push(@VSYS_INSTR, { 'inst'=>'MISSING', 'fixed'=>$value });
          push(@VSYS_INSTR, { 'inst'=>'FROM_TO', 'fixed'=>$value, 'source'=>"$to.PART" });
        }
        else {&Error("VSYS_MISSING_FN cannot be used with verse 1: $_", "$msg Use different instruction(s) in CF_usfm2osis.txt.");}
      }
      else {&Error("VSYS_MISSING_FN must be used with a single verse: $_", "$msg In CF_usfm2osis.txt, change it to the form: BK.1.2 or use different instruction(s)");}
    }
    
    else {&Error("Unhandled CF_usfm2osis.txt line \"$_\" in $cf", "Remove or fix the syntax of this line.");}
  }
  close(COMF);

  @VSYS_INSTR = sort { &vsysInstSort($a, $b) } @VSYS_INSTR;
#  foreach my $p (@VSYS_INSTR) {&Log($p->{'inst'}.', fixed='.$p->{'fixed'}.', source='.$p->{'source'}."\n", 1);}
  
  if ($NO_OUTPUT_DELETE) {return;} # If we're not deleting previously written output files, we're wanting to skip this initial conversion
  
  my $lang = &conf('Lang'); $lang =~ s/-.*$//;
  $lang = ($lang ? " -l $lang":'');
  my $cmd = &escfile($MODULETOOLS_BIN."usfm2osis.py") . " $MOD -v -s none -x -r".$lang." -o " . &escfile("$osis") . ($DEBUG ? " -d":'') . " $USFMfiles";

  my $use_u2o = 0;
  if (!$use_u2o) {
    &Log($cmd . "\n", 1);
    my $result = `$cmd`;
    &Log("$result\n", 1);
    if ($result =~ /Unhandled/i) {
      &Error("Some SFM was unhandled while generating the usfm2osis.py output.", 
"See 'Unhandled' message(s) above, which are in reference to:
$osis 
This problem is usually due to SFM which is not USFM 2.4 compliant. See 
the USFM 2.4 specification here: 
http://ubs-icap.org/chm/usfm/2.4/index.html 
Or sometimes it is due to a bug or 'feature' of CrossWire's usfm2osis.py 
script or the USFM or OSIS specifications. The solution probably
requires that EVAL_REGEX instructions be added to CF_usfm2osis.txt
to update or remove offending SFM tags. $EVAL_REGEX_MSG");}
  }
  &Log("\n");
  # test/evaluation for u2o.py script
  my $home = `echo \$HOME`; chomp($home);
  my $osis2 = "$MOD_OUTDIR/u2o_evaluation.xml";
  if ($use_u2o) {
    $osis2 = $osis;
    $cmd = &escfile("$home/.osis-converters/src/u2o/u2o.py") . " -e UTF8 -v".$lang." -o " . &escfile($osis2) . ($DEBUG ? " -d":'') . " " .$MOD . " $USFMfiles 2>&1";
    #&Log("The following is a test of u2o.py...\n", 1);
    &Log($cmd . "\n", 1);
    &Log(`$cmd` . "\n", 1);
    #&Log("Failure of u2o.py above does not effect other osis-converters conversions.\n", 1);
  }
  
  return;
}

sub vsysInstSort($$) {
  my $a = shift;
  my $b = shift;
  
  my $r;
  my @order = ('MISSING', 'EXTRA', 'FROM_TO'); # NOTE that FROM_TO are run separately after all other instructions anyway
  my $ai; for ($ai=0; $ai<@order; $ai++) {if (@order[$ai] eq $a->{'inst'}) {last;}}
  my $bi; for ($bi=0; $bi<@order; $bi++) {if (@order[$bi] eq $b->{'inst'}) {last;}}
  if ($ai == @order || $bi == @order) {
    &ErrorBug("Unknown VSYS sub-instruction: '".$a->{'inst'}."' or '".$b->{'inst'}."'");
  }
  
  # order by instruction
  $r = $ai <=> $bi;
  if ($r) {return $r;}
  
  my $av = ($a->{'source'} ? $a->{'source'}:$a->{'fixed'});
  my $bv = ($b->{'source'} ? $b->{'source'}:$b->{'fixed'});
  $av =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $av2 = ($2 ? (1*$3):0);
  $bv =~ s/^([^\.]+\.\d+\.\d+)(\.(\d+))?.*?$/$1/; my $bv2 = ($2 ? (1*$3):0);
  
  # otherwise verse system order
  $r = &osisIDSort($av, $bv);
  if ($r) {return $r;}
  
  # otherwise by last verse
  $r = $av2 <=> $bv2;
  if ($r) {return $r;}

  if (!$r) {&ErrorBug("Indeterminent VSYS instruction sort: av=$av, bv=$bv, ai=$ai, bi=$bi");}
  return $r;
}

sub evalRegex($$) {
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
      &Warn("Running copy $n of $f.", "Is it intentional that an SFM file is being RUN and modified multiple times?");
    }
    copy($f, $df);
    push (@files, $df);
  }
  foreach my $f2 (@files) {
    my %eval_regex_report;
    my %eval_regex_applied;
  
    $outFiles .= "\"".$f2."\" ";
    
    my $fln = $f2; $fln =~ s/^.*\/([^\/]+)$/$1/;
    
    if (!open(SFM, "<$READLAYER", $f2)) {&Error("Could not open SFM file \"$f2\"", "This file was incorrectly specified in a RUN line of CF_usfm2osis.txt. Change or remove it.", 1);}
    my $s = join('', <SFM>); 
    foreach my $r (@EVAL_REGEX) {
      if ($r->{'singleFile'} && $r->{'group'} ne $runTarget) {next;}
      my $num;
      eval("\$num = scalar(\$s =~ ".$r->{'regex'}.");");
      if ($num) {
        $eval_regex_applied{$r->{'regex'}}++;
        $eval_regex_report{$r->{'regex'}} += $num;
      }
    }
    close(SFM);
    
    open(SFM2, ">$WRITELAYER", "$f2.new") or die;
    print SFM2 $s;
    close(SFM2);
    
    unlink($f2);
    rename("$f2.new", "$f2");
    
    foreach my $r (@EVAL_REGEX) {
      if ($r->{'singleFile'} && $r->{'group'} ne $runTarget) {next;}
      if (!$eval_regex_applied{$r->{'regex'}}) {&Log("Never applied: ".$r->{'regex'}."\n");}
      else {&Log(sprintf("Applied sub (%2i): %s\n", $eval_regex_report{$r->{'regex'}}, $r->{'regex'}));}
    }
  }
  &Log("\n");
  
  return $outFiles;
}

1;
