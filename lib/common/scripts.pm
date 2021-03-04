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

use strict;

our ($DEBUG, $DICTMOD, $INPD, $MOD_OUTDIR, $SCRIPT_NAME);

# Runs an XSLT and/or a Perl script if they have been placed at the
# appropriate input project path by the user. This allows a project to 
# apply custom scripts if needed.
sub runAnyUserScriptsAt {
  my $pathNoExt = shift; # relative path to script, without extension
  my $sourceP = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  $pathNoExt = "$INPD/".$pathNoExt;
  
  if (-e "$pathNoExt.pl") {
    &Note("Running user Perl script: $pathNoExt.pl");
    &runScript("$pathNoExt.pl", $sourceP, $paramsP, $logFlag);
  }
  else {&Note("No user Perl script to run at $pathNoExt.pl");}
  
  if (-e "$pathNoExt.xsl") {
    &Note("Running user XSLT: $pathNoExt.xsl");
    &runScript("$pathNoExt.xsl", $sourceP, $paramsP, $logFlag);
  }
  else {&Note("No user XSLT to run at $pathNoExt.xsl");}
}

# Runs a script according to its type (its extension). The inputP points
# to the input file. If overwrite is set, the input file is overwritten,
# otherwise the output file has the name of the script which created it.
# Upon sucessfull completion, inputP will be updated to point to the 
# newly created output file.
sub runScript {
  my $script = shift;
  my $inputP = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  my $overwrite = shift;
  
  my $name = $script; 
  my $ext;
  if ($name =~ s/^.*?\/([^\/]+)\.([^\.\/]+)$/$1/) {$ext = $2;}
  else {
    &ErrorBug("runScript: Bad script name \"$script\"!");
    return 0;
  }
  
  if (! -e $script) {
    &ErrorBug("runScript: Script not found \"$script\"!");
  }
  
  my $output = &temporaryFile($$inputP, $name);

  my $result;
  if ($ext eq 'xsl')   {$result = &runXSLT($script, $$inputP, $output, $paramsP, $logFlag);}
  elsif ($ext eq 'pl') {$result = &runPerl($script, $$inputP, $output, $paramsP, $logFlag);}
  else {
    &ErrorBug("runScript: Unsupported script extension \"$script\".\n$result", 1);
    return 0;
  }
  
  if (-z $output) {
    &ErrorBug("runScript: Output file $output has 0 size.\n$result", 1);
    return 0;
  }
  elsif ($overwrite) {&copy($output, $$inputP);}
  else {$$inputP = $output;} # change inputP to pass output file name back
  
  return ($result ? $result:1);
}

sub runPerl {
  my $script = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  # Perl scripts need to have the following arguments
  # script-name input-file output-file [key1=value1] [key2=value2]...
  my @args = (&escfile($script), &escfile($source), &escfile($output));
  map(push(@args, &escfile("$_=".$paramsP->{$_})), sort keys %{$paramsP});
  
  return &shell(join(' ', @args), $logFlag);
}

sub runXSLT {
  my $xsl = shift;
  my $source = shift;
  my $output = shift;
  my $paramsP = shift;
  my $logFlag = shift;
  
  my $cmd = "saxonb-xslt -l -ext:on";
  $cmd .= " -xsl:" . &escfile($xsl) ;
  $cmd .= " -s:" . &escfile($source);
  if ($output) {
    $cmd .= " -o:" . &escfile($output);
  }
  if ($paramsP) {
    foreach my $p (sort keys %{$paramsP}) {
      my $v = $paramsP->{$p};
      $v =~ s/(["\\])/\\$1/g; # escape quote since below passes with quote
      $cmd .= " $p=\"$v\"";
    }
  }
  $cmd .= " DEBUG=\"$DEBUG\" DICTMOD=\"$DICTMOD\" SCRIPT_NAME=\"$SCRIPT_NAME\" TMPDIR=\"$MOD_OUTDIR/tmp\"";
  
  return &shell($cmd, $logFlag);
}

1;
