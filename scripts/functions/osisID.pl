# This file is part of "osis-converters".
# 
# Copyright 2020 John Austin (gpl.programs.info@gmail.com)
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

# All code here is expected to be run on a Linux Ubuntu 14 to 18 or 
# compatible operating system having all osis-converters dependencies 
# already installed.

# Returns an equivalent osisRef from an osisID. The osisRef will contain 
# one or more hyphenated continuation segments if sequential osisID 
# verses are present (osisIDs cannot contain continuations). If 
# onlySpanVerses is set, then hyphenated segments returned may cover at 
# most one chapter (and in this case, the verse system is irrelevant). 
# Note: it is always assumed that osisRefWork = osisIDWork

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($XPC, $XML_PARSER, $FNREFEXT, %OSIS_GROUP, $OSISBOOKSRE, %OSIS_ABBR);

sub osisID2osisRef {
  my $osisID = shift;
  my $osisIDWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisIDWorkDefault
  my $onlySpanVerses = shift; # if true, ranges will only span verses (not chapters or books)
  
  if ($osisID =~ /^\s*$/) {return '';}
  
  my $osisRef = '';
  
  my @segs = &normalizeOsisID([ split(/\s+/, $osisID) ], $osisIDWorkDefault, $workPrefixFlag);
  my $inrange = 0;
  my $lastwk = '';
  my $lastbk = '';
  my $lastch = '';
  my $lastvs = '';
  my $vk;
  foreach my $seg (@segs) {
    my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
    my $pwork = ($workPrefixFlag =~ /always/i ? "$osisIDWorkDefault:":'');
    if ($seg =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
    if (!$work && $workPrefixFlag =~ /always/i) {
      &ErrorBug("osisID2osisRef: workPrefixFlag is set to 'always' but osisIDWorkDefault is null for \"$seg\"!");
    }
    if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisIDWorkDefault:") {$pwork = '';}
    
    if ($vk) {$vk->increment();}
    
    if ($vk && $lastwk eq $work && $vk->getOSISRef() eq $seg) {
      $inrange = 1;
      $lastbk = $vk->getOSISBookName();
      $lastch = $vk->getChapter();
      $lastvs = $vk->getVerse();
      next;
    }
    elsif ($seg =~ /^([^\.]+)\.(\d+)\.(\d+)$/) {
      my $bk = $1; my $ch = $2; my $vs = $3;
      if ($lastwk eq $work && $lastbk eq $bk && $lastch && $lastch eq $ch && $vs == ($lastvs+1)) {
        $inrange = 1;
      }
      else {
        if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs"; $inrange = 0;}
        $osisRef .= " $pwork$seg";
      }
      $lastwk = $work;
      $lastbk = $bk;
      $lastch = $ch;
      $lastvs = $vs;
    }
    else {
      if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs"; $inrange = 0;}
      $osisRef .= " $pwork$seg";
      $lastbk = '';
      $lastch = '';
      $lastvs = '';
    }
    $vk = ($onlySpanVerses ? '':&swordVerseKey($seg, $work));
  }
  if ($inrange) {$osisRef .= "-$lastbk.$lastch.$lastvs";}
  $osisRef =~ s/^\s*//;
  
  return $osisRef;
}

# Returns an atomized equivalent osisID from an osisRef. By atomized 
# meaning each segment of the result is an introduction context, verse ID 
# or keyword ID. The osisRef may contain one or more hyphenated continuation 
# segments whereas osisIDs cannot contain continuations. If expandIntros is 
# set, then expanded osisRefs will also include introductions. Note: it is 
# always assumed that osisRefWork = osisIDWork.
sub osisRef2osisID {
  my $osisRefLong = shift;
  my $osisRefWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisRefWorkDefault
  my $expandIntros = shift;
  
  if ($osisRefLong =~ /^\s*$/) {return '';}
  
  my (@osisIDs, @verses);
  
  my $logTheResult;
  foreach my $osisRef (split(/\s+/, $osisRefLong)) {
    my $work = ($osisRefWorkDefault ? $osisRefWorkDefault:'');
    my $pwork = ($workPrefixFlag =~ /always/i ? "$osisRefWorkDefault:":'');
    if ($osisRef =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
    if (!$work && $workPrefixFlag =~ /always/i) {
      &Error("osisRef2osisID: workPrefixFlag is set to 'always' but osisRefWorkDefault is null for \"$osisRef\" in \"$osisRefLong\"!");
    }
    if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisRefWorkDefault:") {$pwork = '';}
    my $bible = $work; $bible =~ s/DICT$//;
    my $vsys = ($work ? &getVerseSystemOSIS($bible):&conf('Versification'));
  
    if ($osisRef eq 'OT') {
      $osisRef = "Gen-Mal"; 
      if ($expandIntros) {push(@osisIDs, $pwork."TESTAMENT_INTRO.0");}
    }
    elsif ($osisRef eq 'NT') {
      $osisRef = "Matt-Rev"; 
      if ($expandIntros) {push(@osisIDs, $pwork."TESTAMENT_INTRO.1");}
    }

    if ($osisRef !~ /^(.*?)\-(.*)$/) {push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($osisRef, $vsys, $expandIntros)))); next;}
    my $r1 = $1; my $r2 = $2;
    
    if ($r1 !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?/) {push(@osisIDs, "$pwork$osisRef"); next;}
    my $b1 = $1; my $c1 = ($2 ? $3:''); my $v1 = ($4 ? $5:'');
    if ($r2 !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?/) {push(@osisIDs, "$pwork$osisRef"); next;}
    my $b2 = $1; my $c2 = ($2 ? $3:''); my $v2 = ($4 ? $5:'');
    
    # The task is to output every verse in the range, not to limit or test the input
    # with respect to the verse system. But outputing ranges greater than a chapter 
    # requires knowledge of the verse system, so SWORD is used for this.
    push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($r1, $vsys, $expandIntros))));
    if ($r1 ne $r2) {
      push(@osisIDs, map("$pwork$_", split(/\s+/, &expandOsisID($r2, $vsys, $expandIntros))));
      # if r1 is verse 0, it has already been pushed to osisIDs above 
      # but it cannot be incremented as VerseKey since it's not a valid 
      # verse. So take care of that situation on the next line.
      if ($r1 =~ s/^([^\.]+\.\d+)\.0$/$1.1/) {push(@osisIDs, "$r1");}
      # The end points are now recorded, but all verses in between must be pushed to osisIDs
      # (duplicates are ok). If b and c are the same in $r1 and $r2 then this is easy:
      if ($b1 eq $b2 && $c2 && $c1 == $c2) {
        for (my $v=$v1; $v<=$v2; $v++) {push(@osisIDs, "$pwork$b2.$c2.$v");}
        next;
      }
      # Otherwise verse key increment must be used until we reach the same book and chapter
      # as $r2, then simple verse incrementing can be used.
      my $ir1 = &idInVerseSystem($r1, $vsys);
      if (!$ir1) {
        &Warn("osisRef2osisID: Start verse \"$r1\" is not in \"$vsys\" so the following range may be incorrect: ");
        $logTheResult++;
        next;
      }
      my $ir2 = &idInVerseSystem($b2.($c2 ? ".$c2.1":''), $vsys);
      if (!$ir2) {
        &Error("osisRef2osisID: End point \"".$b2.($c2 ? ".$c2.1":'')."\" was not found in \"$vsys\" so the following range is likely incorrect: ");
        $logTheResult++;
        next;
      }
      if ($ir2 < $ir1) {
        &Error("osisRef2osisID: Range end is before start: \"$osisRef\". Changing to \"$r1\"");
        next;
      }
      my $vk = new Sword::VerseKey();
      $vk->setVersificationSystem($vsys); 
      $vk->setText($b2.($c2 ? ".$c2.1":''));
      if (!$c2) {$vk->setChapter($vk->getChapterMax()); $c2 = $vk->getChapter();}
      if (!$v2) {$vk->setVerse($vk->getVerseMax()); $v2 = $vk->getVerse();}
      $ir2 = $vk->getIndex();
      $vk->setText($r1);
      $ir1 = $vk->getIndex();
      while ($ir1 != $ir2) {
        if ($expandIntros && $vk->getChapter() == 1 && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".0");}
        if ($expandIntros && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".".$vk->getChapter().".0");}
        push(@osisIDs, $pwork.$vk->getOSISRef());
        $vk->increment();
        $ir1 = $vk->getIndex();
      }
      if ($expandIntros && $vk->getChapter() == 1 && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".0");}
      if ($expandIntros && $vk->getVerse() == 1) {push(@verses, $vk->getOSISBookName().".".$vk->getChapter().".0");}
      for (my $v=$vk->getVerse(); $v<=$v2; $v++) {push(@osisIDs, "$pwork$b2.$c2.$v");}
    }
  }

  my $r = join(' ', &normalizeOsisID(\@osisIDs, $osisRefWorkDefault, $workPrefixFlag));
  if ($logTheResult) {&Log(" '$osisRefLong' = '$r' ?\n");}
  return $r;
}

# Checks that every segment of an osisID is part of the given workid and 
# the verse system. Zero is returned if any segment is from a different
# work or is outside the verse system.
sub inVersesystem {
  my $osisID = shift;
  my $workid = shift;
  my $wkvsys = shift;
  
  foreach my $id (split(/\s+/, $osisID)) {
    my $ext = ($id =~ s/(\!.*)$// ? $1:'');
    my $osisIDWork = $workid;
    my $wktype = 'Bible';
    if ($id =~ s/^([\w\d]+)\://) {$osisIDWork = $1;}
    if (!&isChildrensBible($MOD) && $osisIDWork && $osisIDWork !~ /^bible$/i) {
      &getRefSystemOSIS($osisIDWork) =~ /^([^\.]+)\.(.*)$/;
      $wktype = $1; $wkvsys = $2;
    }
    
    if ($id !~ /^([\w\d]+)(\.(\d+)(\.(\d+))?)?$/) {
      &Error("Could not parse osisID $id.");
      return 0;
    }
    my $b = $1; my $c = ($2 ? $3:''); my $v = ($4 ? $5:'');
    if (!defined($OSIS_ABBR{$b}))  {
      &Error("Unrecognized OSIS book abbreviation $b in osisID $id.");
      return 0;
    }
    my ($canonP, $bookOrderP, $bookArrayP);
    &getCanon($wkvsys, \$canonP, \$bookOrderP, undef, \$bookArrayP);
    if ($c && ($c < 0 || $c > @{$canonP->{$b}})) {
      &Error("Chapter $c of osisID $id is outside of verse system $wkvsys.");
      return 0;
    }
    if ($v && ($v < 0 || $v > @{$canonP->{$b}}[$c-1])) {
      &Error("Verse $v of osisID $id is outside of verse system $wkvsys.");
      return 0;
    }
  }
  
  return 1;
}

# Return index if osisID is in verse-system vsys, or 0 otherwise
sub idInVerseSystem {
  my $osisID = shift; if (ref($osisID)) {$osisID = $osisID->getOSISRef();}
  my $vsys = shift;
 
  if ($osisID !~ /^([^\.]+)(\.\d+(\.\d+)?)?$/) {return 0;}
  my $bk = $1;
  if ($bk !~ /\b($OSISBOOKSRE)\b/) {return 0;}

  my $vk = new Sword::VerseKey();
  $vk->setAutoNormalize(0); # The default VerseKey will NOT allow a verse that doesn't exist in the verse system
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setText($osisID);
  my $before = $vk->getOSISRef();
  $vk->normalize();
  my $after = $vk->getOSISRef();

  return ($before eq $after ? $vk->getIndex():0);
}

# Take an osisID of the form DIVID, BOOK or BOOK.CH (or BOOK.CH.VS but 
# this only returns itself) and expand it to a list of individual verses 
# of the form BOOK.CH.VS, according to the verse system vsys. Book
# introductions, which have the form BOOK.0, are returned unchanged.
# When osisID is a DIVID it returns itself and all ancestor DIVIDs. All 
# expanded osisIDs also include book and chapter introductions if 
# expandIntros is set.
sub expandOsisID {
  my $osisID = shift;
  my $vsys = shift;
  my $expandIntros = shift;
  
  if ($osisID =~ /\!/) {return $osisID;}
  elsif ($osisID =~ /^[^\.]+\.\d+\.\d+$/ || $osisID =~ /^[^\.]+\.0$/) {
    return $osisID;
  }
  elsif (!&idInVerseSystem($osisID, $vsys)) {
    return join(' ', &osisID2Contexts($osisID, $expandIntros));
  }
  elsif ($osisID !~ /^([^\.]+)(\.(\d+))?$/) {
    return $osisID;
  }
  my $bk = $1; my $ch = ($2 ? $3:'');
  
  my @verses;
  if ($expandIntros && $ch eq '') {push(@verses, "$bk.0");}
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys ? $vsys:'KJV'); 
  $vk->setText($osisID);
  $vk->normalize();
  
  if ($expandIntros && $vk->getVerse() == 1) {push(@verses, "$bk.".$vk->getChapter().".0");}
  push(@verses, $vk->getOSISRef());
  my $lastIndex = $vk->getIndex();
  $vk->increment();
  while ($lastIndex ne $vk->getIndex && 
         $vk->getOSISBookName() eq $bk && 
         (!$ch || $vk->getChapter() == $ch)) {
    if ($expandIntros && $vk->getVerse() == 1) {push(@verses, "$bk.".$vk->getChapter().".0");}
    push(@verses, $vk->getOSISRef());
    $lastIndex = $vk->getIndex();
    $vk->increment();
  }
  
  return join(' ', @verses);
}

# Return a SWORD verse key with the osisID. If the osisID does not exist
# in the verse system, then 0 is returned, unless dontCheck is set, in
# which case the key is returned anyway (however bugs or errors will 
# appear if such a key is later incremented, so use dontCheck with caution).
sub swordVerseKey {
  my $osisID = shift;
  my $osisIDWorkDefault = shift;
  my $dontCheck = shift;
  
  my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
  if ($osisID =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1;}
  my $vsys = $work ? &getVerseSystemOSIS($work):&conf('Versification');
  
  if (!$dontCheck && !&idInVerseSystem($osisID, $vsys)) {return 0;}
  
  my $vk = new Sword::VerseKey();
  $vk->setVersificationSystem($vsys);
  $vk->setAutoNormalize(0);
  $vk->setText($osisID);

  return $vk;
}

# Takes an array of osisIDs, splits each into segments, removes duplicates 
# and empty values, normalizes work prefixes if desired, and sorts each
# resulting segment in verse system order.
sub normalizeOsisID {
  my $aP = shift;
  my $osisIDWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisIDWorkDefault
  my $vsys = shift;
  
  my @avs;
  foreach my $osisID (@{$aP}) {
    foreach my $seg (split(/\s+/, $osisID)) {
      my $work = ($osisIDWorkDefault ? $osisIDWorkDefault:'');
      my $pwork = ($workPrefixFlag =~ /always/i ? "$osisIDWorkDefault:":'');
      if ($seg =~ s/^([\w\d]+)\:(.*)$/$2/) {$work = $1; $pwork = "$1:";}
      if (!$work && $workPrefixFlag =~ /always/i) {
        &ErrorBug("normalizeOsisID: workPrefixFlag is set to 'always' but osisIDWorkDefault is null for \"$seg\" in \"$osisID\"!");
      }
      if ($workPrefixFlag =~ /not\-default/i && $pwork eq "$osisIDWorkDefault:") {$pwork = '';}
      push(@avs, "$pwork$seg");
    }
  }
  
  my %seen;
  return sort { osisIDSort($a, $b, $osisIDWorkDefault, $vsys) } grep(($_ && !$seen{$_}++), @avs);
}

# Sort osisID segments (ie. Rom.14.23) in verse system order
sub osisIDSort {
  my $a = shift;
  my $b = shift;
  my $osisIDWorkDefault = shift;
  my $vsys = shift; if (!$vsys) {$vsys = &conf('Versification');}
  
  my $awp = ($a =~ s/^([^\:]*\:)(.*)$/$2/ ? $1:($osisIDWorkDefault ? "$osisIDWorkDefault:":''));
  my $bwp = ($b =~ s/^([^\:]*\:)(.*)$/$2/ ? $1:($osisIDWorkDefault ? "$osisIDWorkDefault:":''));
  my $r = $awp cmp $bwp;
  if ($r) {return $r;}

  my $aNormal = 1; my $bNormal = 1;
  if ($a !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?(\!.*)?$/) {$aNormal = 0;}
  my $abk = $1; my $ach = (1*$3); my $avs = (1*$5);
  if ($b !~ /^([^\.]+)(\.(\d*)(\.(\d*))?)?(\!.*)?$/) {$bNormal = 0;}
  my $bbk = $1; my $bch = (1*$3); my $bvs = (1*$5);
  if    ( $aNormal && !$bNormal) {return 1;}
  elsif (!$aNormal &&  $bNormal) {return -1;}
  elsif (!$aNormal && !$bNormal) {return $a cmp $b;}
  
  my $canonP; my $bookOrderP; my $testamentP; my $bookArrayP;
  &getCanon($vsys, \$canonP, \$bookOrderP, \$testamentP, \$bookArrayP);
  my $abi = (defined($bookOrderP->{$abk}) ? $bookOrderP->{$abk}:-1);
  my $bbi = (defined($bookOrderP->{$bbk}) ? $bookOrderP->{$bbk}:-1);
  if    ($abi != -1 && $bbi == -1) {return 1;}
  elsif ($abi == -1 && $bbi != -1) {return -1;}
  elsif ($abi == -1 && $bbi == -1) {return $abk cmp $bbk;}
  $r = $bookOrderP->{$abk} <=> $bookOrderP->{$bbk};
  if ($r) {return $r;}
  
  $r = $ach <=> $bch;
  if ($r) {return $r;}
  
  return $avs <=> $bvs;
}

sub readOsisIDs {
  my $hashP = shift;
  my $xml = shift;
  
  my $mod = &getOsisIDWork($xml);
  foreach my $elem ($XPC->findnodes('//*[@osisID]', $xml)) {
    my $id = $elem->getAttribute('osisID');
    foreach my $i (split(/\s+/, $id)) {$hashP->{$mod}{$i}++;}
  }
}

sub encodeOsisRef {
  my $r = shift;

  # Apparently \p{gc=L} and \p{gc=N} work different in different regex implementations.
  # So some schema checkers don't validate high order Unicode letters.
  $r =~ s/(.)/my $x = (ord($1) > 1103 ? "_".ord($1)."_":$1)/eg;
  
  $r =~ s/([^\p{gc=L}\p{gc=N}_])/my $x="_".ord($1)."_"/eg;
  $r =~ s/;/ /g;
  return $r;
}

sub decodeOsisRef {
  my $r = shift;

  while ($r =~ /(_(\d+)_)/) {
    my $rp = quotemeta($1);
    my $n = $2;
    $r =~ s/$rp/my $ret = chr($n);/e;
  }
  return $r;
}

# Take in osisRef and map the whole thing. Mapping gaps are healed and
# PART verses are always treated as whole verses.
sub mapOsisRef {
  my $mapP = shift;
  my $map = shift;
  my $osisRef = shift;
  
  my @mappedOsisRefs;
  foreach my $ref (split(/\s+/, $osisRef)) {
    my @mappedOsisIDs;
    foreach my $osisID (split(/\s+/, &osisRef2osisID($ref))) {
      my $idin = $osisID;
      $idin =~ s/!PART$//;
      my $id = $idin;
      if    ($mapP->{$map}{$idin})        {$id = $mapP->{$map}{$idin};}
      elsif ($mapP->{$map}{"$idin!PART"}) {$id = $mapP->{$map}{"$idin!PART"}; push(@mappedOsisIDs, $idin);}
      $id =~ s/!PART$//; # if part is included, include the whole thing
      push(@mappedOsisIDs, $id);
    }
    push(@mappedOsisRefs, &fillGapsInOsisRef(&osisID2osisRef(join(' ', &normalizeOsisID(\@mappedOsisIDs)))));
  }

  return join(' ', @mappedOsisRefs);
}

# Take an osisRef's starting and ending point, and return an osisRef 
# that covers the entire range between them. This can be used to 'heal' 
# missing verses in mapped ranges.
sub fillGapsInOsisRef {
  my $osisRef = shift;
  
  $osisRef =~ s/(^\s+|\s+$)//g;
  if ($osisRef =~ /^\s*$/) {return '';}
  
  my @id = split(/\s+/, &osisRef2osisID($osisRef));
  if ($#id == 0) {return $osisRef;}
  return @id[0].'-'.@id[$#id];
}

# Converts a DICT module osisRef having a work prefix (unless loose is 
# set) to the entry name it corresponds to. If a modP pointer is provided,
# it will be filled with the work prefix value.
sub osisRef2Entry {
  my $osisRef = shift;
  my $modP = shift;
  my $loose = shift;
  
  if ($osisRef !~ /^(\w+):(.*)$/) {
    if ($loose) {return &decodeOsisRef($osisRef);}
    &Error("osisRef2Entry loose=0, problem with osisRef: $osisRef !~ /^(\w+):(.*)\$/");
  }
  if ($modP) {$$modP = $1;}
  return &decodeOsisRef($2);
}

sub entry2osisRef {
  my $mod = shift;
  my $ref = shift;

  return $mod.":".encodeOsisRef($ref);
}

# Find in xml the verse whose sID or eID covers the given osisID segment. 
# This complex search is only needed because Perl LibXML's XPATH-1.0 does 
# not have the XPATH 2.0 matches() function.
sub getVerseTag {
  my $ID_segment = shift;
  my $xml = shift;
  my $sID_or_eID = shift;
  
  my $idse = ($sID_or_eID ? 'e':'s');
  
  my $v = @{$XPC->findnodes('//osis:verse[@'.$idse.'ID="'.$ID_segment.'"]', $xml)}[0];
  if ($v) {return $v;}
  
  foreach my $v (@{$XPC->findnodes('//osis:verse[contains(@'.$idse.'ID, "'.$ID_segment.'")]', $xml)}) {
    if ($v && $v->getAttribute($idse.'ID') =~ /\b\Q$ID_segment\E\b/) {return $v;}
  }
  
  return;
}

# This functions returns a hash with keys for all verse osisIDs, providing
# a big speed-us as compared to searching for each osisID one at a time. 
sub getVerseOsisIDs {
  my $xml = shift;
  
  my %osisIDs;
  foreach my $v (@{$XPC->findnodes('//osis:verse[@osisID]', $xml)}) {
    foreach my $seg (split(/\s+/, $v->getAttribute('osisID'))) {$osisIDs{$seg}++;}
  }
  return \%osisIDs;
}

# Write unique osisIDs to any element that requires one. Only elements
# with osisID attributes may be targetted by an osisRef link. Certain 
# elements have special id features for 'duplicates':
#  glossary keyword - ends with .dup1, .dup2... but there is also a
#                     combined glossary where the .dupN ending is
#                     not present in the osisID of a combined entry.
#  TOC milestone    - ends with !toc, .dup2!toc, .dup3!toc... but the
#                     .dupN part is removed from osisRefs, because it is
#                     assumed that only one TOC target will remain for
#                     any particular conversion.
sub write_osisIDs {
  my $osisP = shift;
  
  &Log("\nWriting osisIDs:\n", 1);
  
  my %ids;
  # splitOSIS offers a massive speedup for note osisIDs
  foreach my $osis (&splitOSIS($$osisP)) {
    my $xml;
    my $element = &splitOSIS_element($osis, \$xml);
    
    # Glossary and other divs
    my @elems = @{$XPC->findnodes('descendant-or-self::osis:div[@type][not(@osisID)]
        [not(@resp="x-oc")]
        [not(starts-with(@type, "book"))]
        [not(starts-with(@type, "x-keyword"))]
        [not(starts-with(@type, "x-aggregate"))]
        [not(contains(@type, "ection"))]', $element)};
        
    # TOC milestones so they can be used as reference targets
    push(@elems, @{$XPC->findnodes('descendant::osis:milestone
        [@type="x-usfm-toc'.&conf('TOC').'"][@n][not(@osisID)]', $element)});
        
    # notes (excluding external cross-references which already have osisIDs)
    push(@elems, @{$XPC->findnodes('descendant::osis:note[not(@resp)]', $element)});
    
    foreach my $e (@elems) {
      $e->setAttribute('osisID', &create_osisID($e, \%ids));
      if ($e->nodeName =~ /div$/) {
        &Note("Adding osisID ".$e->getAttribute('osisID'));
      }
    }
    
    &writeXMLFile($xml, $osis);
  }
  &joinOSIS($osisP);
}


# This functions returns unique osisID values to assign to any element.
# But in order for it to work, $usedHP pointer must be provided, whose 
# keys are the osisIDs of all elements appearing earlier in the OSIS
# file sharing the same nodeName (ie. div or milestone) so as not to
# duplicate those osisID values.
sub create_osisID {
  my $e = shift;
  my $usedHP = shift;
  
  my $id;
  
  my $baseName = &osisID_baseName($e);
  if ($baseName) {
    my $nodeName = $e->nodeName;
    $nodeName =~ s/^[^\:]+\://; # could be osis:milestone etc.
  
    my $ext = $nodeName; 
    # A ! extension is always added to quickly differentiate from 
    # Scripture osisIDs, which never have extensions and are often 
    # treated differently.
    if ($e->getAttribute('type') eq "x-usfm-toc".&conf('TOC')) {
      $ext = 'toc';
    }
    elsif ($nodeName eq 'note') {
      # The note extension has 2 parts: type and instance. Instance is 
      # a number prefixed by a single letter. External cross-references 
      # for the verse system are added from another source and will have 
      # the extensions: crossReference.rN or crossReference.pN (for 
      # parallel passages).
      $ext = ( $e->getAttribute("placement") eq "foot" ? $FNREFEXT : 
      ($e->getAttribute("type") ? $e->getAttribute("type").'.t' : 'tnote.t') );
    }
  
    my $n = 1;
    do {
      if ($nodeName eq 'note') {
        $id = $baseName.'!'.$ext.$n;
      }
      elsif ($nodeName eq 'milestone' && $ext eq 'toc') {
        $id = $baseName.($n > 1 ? ".dup$n":'').'!'.$ext;
      }
      else {
        $id = $baseName.($n > 1 ? "_$n":'').'!'.$ext;
      }
      $n++;
    } while (exists($usedHP->{$id}));
    $usedHP->{$id}++;
  }
  else {
    &ErrorBug("Could not create osisID for ".$e->toString(), 1);
  }
  
  return $id;
}

# Returns an informative base osisID for an element, based on its 
# nodeName, attributes and/or context. It is not necessarily unique.
sub osisID_baseName {
  my $e = shift;
  
  my $nodeName = $e->nodeName;
  $nodeName =~ s/^[^\:]+\://; # could be osis:milestone etc.
  
  my $feature = ($e->getAttribute('annotateType') eq 'x-feature' ? $e->getAttribute('annotateRef'):'');
  my $type = ($e->getAttribute('type') ? &dashCamelCase($e->getAttribute('type')):$nodeName);
 
  if ($nodeName eq 'div') {
    my $kind = ($feature ? $feature:$type);
    # these commonly appearing kinds of div also get a title
    my $title;
    my $regex = (&conf('ARG_divTitleOsisID') ? &conf('ARG_divTitleOsisID'):'^(glossary|div)$');
    if ($kind =~ /$regex/) {
      $title = &encodeOsisRef(&getDivTitle($e));
    }
    return $kind.($title ? '_'.$title:'');
  }
  elsif ($nodeName eq 'milestone') {
    my $n = $e->getAttribute('n');
    $n =~ s/^(\[[^\]]+\])+//; # could be n="[level2]Сотворение мира" etc.
    return ($n ? &encodeOsisRef($n):$type);
  }
  elsif ($nodeName eq 'note') {
    my @ids = @{&atomizeContext(&getNodeContext($e))};
    my $base = @ids[0];
    $base =~ s/\![^\!]*$//;
    return $base;
  }
}

sub dashCamelCase {
  my $id = shift;

  my @p = split(/\-/, $id);
  for (my $x=1; $x<@p; $x++) {@p[$x] = ucfirst(@p[$x]);}
  return join('', @p);
}

1;
