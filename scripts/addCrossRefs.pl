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
#   REMOVE_REFS_TO_MISSING_BOOKS - If set to "true" then cross 
#       references targetting books which are not included in the 
#       OSIS file will NOT be placed in the OSIS file.
#   SFM book name abbreviations (one per line) are to be listed for
#   those books which should have cross-references inserted into them.
#   If no books are listed, then cross-references will be added to 
#   ALL books in the OSIS file.
   
$crossRefs = "$SCRD/scripts/CrossReferences/CrossRefs_";
if (!$VERSESYS || $VERSESYS eq "KJV") {$crossRefs .= "KJV.txt";}
else {$crossRefs .= "$VERSESYS.txt";}
if (!-e $crossRefs) {
  &Log("ERROR: Missing cross reference file for \"$VERSESYS\": $crossRefs.\n");
}
else {
  &Log("-----------------------------------------------------\nSTARTING addCrossRefs.pl\n\n");

  &Log("READING COMMAND FILE \"$COMMANDFILE\"\n");
  &normalizeNewLines($COMMANDFILE);
  &addRevisionToCF($COMMANDFILE);
  open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) or die "Could not open command file \"$COMMANDFILE\".\n";
  $books = "";
  while (<COMF>) {
    if ($_ =~ /^\s*$/) {next;}
    if ($_ =~ /^\#/) {next;}
    elsif ($_ =~ /REMOVE_REFS_TO_MISSING_BOOKS:(\s*(.*?)\s*)?$/) {if ($1) {$removeEmptyRefs = $2; next;}}
    elsif ($_ =~ /:/) {next;}
    elsif ($_ =~ /\/(\w+)\.[^\/]+$/) {$bnm=$1;}
    elsif ($_ =~/^\s*(\w+)\s*$/) {$bmn=$1;}
    else {next;}
    $bnm=$1;
    $bookName = &getOsisName($bnm);
    $books = "$books $bookName";
  }
  if ($books =~ /^\s*$/) {
    $useAllBooks = "true";
    &Log("You are including cross references for ALL books.\n\n");
  }
  else {
    $useAllBooks = "false"; 
    &Log("You are including cross references for the following books:\n$books\n\n");
  }

  # Collect cross references from list file...
  &Log("READING CROSS REFERENCE FILE \"$crossRefs\".\n");
  copy($crossRefs, "$crossRefs.tmp");
  &normalizeNewLines("$crossRefs.tmp");
  open(NFLE, "<:encoding(UTF-8)", "$crossRefs.tmp") or die "Could not open cross reference file \"$crossRefs.tmp\".\n";
  $emptyRefs=0;
  $line=0;
  while (<NFLE>) {
    $line++;
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ !~ /(norm:|para:)?(.*?):\s*(.*)/) {next;}
    $typ = $1;
    $bcv = $2;
    $nts = $3;
    
    my $osrf = $bcv;
    my $osid = $osrf."!crossReference.".($typ eq "para:" ? "p":"n");
    $osid .= ++$OSISREF{$osid};
    $nts =~ s/(type="crossReference")/$1 osisRef="$osrf" osisID="$osid"/;
    # If this book is not included in this file, then don't save it
    $bcv =~ /^([^\.]+)\./;
    $bk = $1;
    if (($useAllBooks ne "true") && ($books !~ /(^|\s+)$bk(\s+|$)/)) {next;}
    
    $tmp = $nts;
    $printRefs = "";
    if ($removeEmptyRefs eq "true") {
      # Strip out references to books which aren't included in this module
      while ($tmp =~ s/<reference osisRef="(([^\.]+)\.[^"]+)"><\/reference>//) { #"{
        $thisRef = $1;
        $thisbk = $2;
        $printRefs = "$printRefs$thisRef; ";
        if ($books =~ /$thisbk/) {next;}
        $nts =~ s/<reference osisRef="$thisRef"><\/reference>//;
      }
    }
    # Remove empty cross referece footnotes
    if ($nts =~ /<note type="crossReference">\s*<\/note>/) {
      $emptyRefs++;
      &Log("WARNING line $line: Removed empty cross reference note for $bcv: $printRefs\n");
      next;
    }
    if ($nts =~ /^\s*$/) {
      &Log("ERROR line $line: Removed empty line.\n");
      next;
    }
    my $i=1;
    my $sp=",";
    while($nts =~ s/(<reference[^>]*>)(<\/reference>)/$1$i$sp$2/i) {$i++;}
    $sp = quotemeta($sp);
    $nts =~ s/^(.*)$sp(<\/reference>)(.*?)$/$1$2$3/i;
    $refs{"$typ$bcv"} = $nts;
  }
  close (NFLE);
  unlink("$crossRefs.tmp");
  &Log("Removed $emptyRefs empty cross reference notes.\n");
  &Log("\n");

  &Log("READING OSIS FILE: \"$INPUTFILE\".\n");
  &Log("WRITING OSIS FILE: \"$OUTPUTFILE\".\n");

  &Log("\nSTARTING PASS 1\n");
  &addCrossRefs;

  # Check that all cross references were copied to OSIS
  &Log("FINISHED PASS 1\n\n");
  $failures="false";
  foreach $ch (keys %refs) {
    if ($refs{$ch} ne "placed" && $refs{$ch} ne "moved") {
      $failures="true"; 
      &Log("WARNING: $ch = $refs{$ch} Cross References were not copied to OSIS file\n");
    }
  }

  if ($failures eq "true") {
    &Log("\nSTARTING PASS 2\n");
    rename($OUTPUTFILE, "tmpFile.txt");
    $INPUTFILE = "tmpFile.txt";
    &addCrossRefs;
    unlink("tmpFile.txt");
    &Log("FINISHED PASS 2\n\n");
    $failures="false";
    foreach $ch (keys %refs) {
      if ($refs{$ch} ne "placed" && $refs{$ch} ne "moved") {
        $failures="true"; 
        &Log("WARNING: $ch = $refs{$ch} Cross References were not copied to OSIS file\n"); 
      }
    }
  }
  if ($failures eq "true") {
    &Log("\nSTARTING PASS 3\n");
    rename($OUTPUTFILE, "tmpFile.txt");
    $INPUTFILE = "tmpFile.txt";
    &addCrossRefs;
    unlink("tmpFile.txt");
    &Log("FINISHED PASS 3\n\n");
    $failures="false";
    foreach $ch (keys %refs) {
      if ($refs{$ch} ne "placed" && $refs{$ch} ne "moved") {
        $failures="true"; 
        &Log("WARNING: $ch = $refs{$ch} Cross References were not copied to OSIS file\n");
      }
    }
  }
  if ($failures eq "false") {&Log("All Cross References have been placed.\n");}

}  

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

sub addCrossRefs {
  open(INF, "<:encoding(UTF-8)", $INPUTFILE);
  open(OUTF, ">:encoding(UTF-8)", $OUTPUTFILE);

  $line=0;
  while (<INF>) {
    $line++;
    if ($_ =~ /<chapter /) {$tv = 0;}
    if ($_ =~ /<verse.*?sID="(.*?)\.(\d+)\.([\d-]+)"/) {
      $tag = "$1.$2.$3";
      $bkch = "$1.$2";
      $acrbk = $1;
      $verses = $3;

      # If this container covers multiple verses, we need to check each verse for cross references
      if ($verses =~ /(\d+)-(\d+)/) {$reps=$2-$1+1; $st=$1;}
      else {$reps=1; $st=$verses;}

      $endlessLoop=0;
      while ($reps > 0) {
        $tv++;
  #print "OUTER LOOP: read-$st, internal-$tv\n";
        while ($tv != $st) {
          $endlessLoop++;
          if ($endlessLoop==200) {&Log("ERROR line $line: Endless loop encountered!\n"); die;}
  #print "INNER LOOP: read>$st<, internal>$tv<\n";
          $mkey = "norm:$bkch.$tv";
          if ($refs{$mkey} && $refs{$mkey} ne "moved" && $refs{$mkey} ne "placed") {
            $tmp = $tv-1;
            $refs{"norm:$bkch.$tmp"} = $refs{"norm:$bkch.$tv"};
            $refs{"norm:$bkch.$tv"} = "moved";
            &Log("Moved note norm:$bkch.$tv to norm:$bkch.$tmp\n");
          }
          $mkey = "para:$bkch.$tv";
          if ($refs{$mkey} && $refs{$mkey} ne "moved" && $refs{$mkey} ne "placed") {
            $tmp = $tv-1;
            $refs{"para:$bkch.$tmp"} = $refs{"para:$bkch.$tv"};
            $refs{"para:$bkch.$tv"} = "moved";
            &Log("Moved note para:$bkch.$tv to para:$bkch.$tmp\n");
          }
          $tv++;
        }
        # if there is a cross reference for this verse, then place it appropriately
        $mkey = "norm:$bkch.$st";
        if ($refs{$mkey} && $refs{$mkey} ne "moved" && $refs{$mkey} ne "placed") {
          # Insert cross references before verse end tag and (any other tags in series, and "." or "?" or " ") if any of them exist
          if    ($_ =~ s/(.*?)([\.\?\s]*(\s*<[^\/][^<>]+>\s*)*<verse eID="$tag"\/>\s*$)/$1$refs{$mkey}$2/) {}
          elsif ($_ =~ s/(.*?)([\.\?\s]*(\s*<[^\/][^<>]+>\s*)*<\/verse>\s*$)/$1$refs{$mkey}$2/) {}
          # If no end verse marker, just tack cross references at end of line
          else  {$_ = "$_$refs{$mkey}";}
          $refs{$mkey} = "placed";
        }
        $mkey = "para:$bkch.$st";
        if ($refs{$mkey} && $refs{$mkey} ne "moved" && $refs{$mkey} ne "placed") {
          # Insert these cross references at start of verse, but after any white space and/or titles
          $_ =~ s/(<verse[^>]+>(<milestone type="x-p-indent" \/>|<title[^>]*>.*?<\/title>)*)/$1$refs{$mkey}/;
          $refs{$mkey} = "placed";
        }
        $st++; $reps--;
      }
    }
    print OUTF $_;
  }

  close (OUTF);
  close (INF);
}

1;
