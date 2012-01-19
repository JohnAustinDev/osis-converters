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

# Shorten log output so that it is readable!
open(LOG, "<:encoding(UTF-8)", $LOGFILE) || die "Could not open $LOGFILE\n";
open(TMP, ">:encoding(UTF-8)", "$TMPDIR/log.tmp") || die "Could not open tmp log \"$TMPDIR/log.tmp\"\n";
while(<LOG>) {
  chomp;
  if ($_ =~ /INFO\(LINK\): Linking (\w+)\.(\w+)\.(\w+) to (\w+)\.(\w+)\.(\w+)/) {
    $b2 = $4; $c2 = $5; $v2 = $6;
    if ($b2==$b && $c2==$c && $v2==$v) {$suc++; next;}
    else {
      if ($suc) {print TMP " + $suc more";}
      $suc=0;
    }
    $b = $b2; $c = $c2; $v = $v2;
  }
   
  print TMP "\n".$_;
}
print TMP "\n";
close(LOG);
close(TMP);

unlink($LOGFILE);
rename("$TMPDIR/log.tmp", $LOGFILE);

