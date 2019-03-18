# This file is part of "osis-converters".
# 
# Copyright 2019 John Austin (gpl.programs.info@gmail.com)
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

# getAtomizedAttributeContexts() takes context/notContext attribute values from 
# DictionaryWords.xml and converts them into a hash containing all the 
# atomized context values (see checkAtomicContext() function) which 
# compose the attribute value, and a list of entire included books. 
# NOTE: For a big speedup, entire books are returned separately.
#
# context/notContext attribute values are space separated instances of 
# either atomized context values or, for brevity, any of the following 
# shortened forms:
# - Bible osisRef (which is any combination of: OSISBK.CH.VS or OSISBK.CH.VS-OSISBK.CH.VS) 
#   plus may begin with OSISBK = 'ALL' meadning all Bible books
# - Other special keywords:
#   OT = Old Testament (including introductions)
#   NT = New Testament (including introductions)
#   BIBLE_INTRO or BIBLE_INTRO.0 = Bible introduction
#   TESTAMENT_INTRO.0 or TESTAMENT_INTRO.1 = OT or NT introduction, respectively
sub getAtomizedAttributeContexts($\$) {
  my $attrValue = shift;
  my $notesP = shift;
  
  my %h;
  foreach my $ref (split(/\s+/, $attrValue)) {
    # Handle whole book
    if ($OSISBOOKS{$ref}) {$h{'books'}{$ref}++; next;}
    
    # Handle keywords OT and NT
    if ($ref =~ /^(OT|NT)$/) {
      $h{'contexts'}{'TESTAMENT_INTRO.'.($ref eq 'OT' ? '0':'1').'.0'}++;
      foreach my $bk (split(/\s+/, ($ref eq 'OT' ? $OT_BOOKS:$NT_BOOKS))) {
        $h{'books'}{$bk}++;
      }
      next;
    }
    
    # Handle special case of BOOK1-BOOK2 for a major speedup
    if ($ref =~ /^($OSISBOOKSRE)-($OSISBOOKSRE)$/) {
      my $bookOrderP; &getCanon(&conf('Versification'), NULL, \$bookOrderP, NULL);
      my $aP = &scopeToBooks($ref, $bookOrderP);
      foreach my $bk (@{$aP}) {$h{'books'}{$bk}++;}
      next;
    }
    
    # Handle keyword ALL
    if ($ref =~ s/^ALL\b//) {
      foreach my $bk (split(/\s+/, "$OT_BOOKS $NT_BOOKS")) {
        if (!$ref) {$h{'books'}{$bk}++;}
        else {foreach my $k (&osisRef2Contexts("$bk$ref")) {$h{'contexts'}{$k}++;}};
      }
    }
    else {foreach my $k (&osisRef2Contexts($ref)) {$h{'contexts'}{$k}++;}}
  }
  
  if ($notesP && $attrValue && !$ALREADY_NOTED_RESULT{$attrValue}) {
    $ALREADY_NOTED_RESULT{$attrValue}++;
    $$notesP .= "NOTE: Converted context attribute value to contexts:\n";
    $$notesP .= "  Context  = $attrValue\n";
    $$notesP .= "  Contexts =".join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'books'}})).' '.join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'contexts'}}))."\n\n";
  }
  
  return \%h;
}

# Takes any valid osisRef and returns an equivalent array of atomized contexts.
sub osisRef2Contexts($$$) {
  my $osisRefLong = shift;
  my $osisRefWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisRefWorkDefault
  
  # This call to osisRef2osisID includes introductions (even though intros do not have osisIDs, they have context values)
  my @cs = (split(/\s+/, &osisRef2osisID($osisRefLong, $osisRefWorkDefault, $workPrefixFlag, 1)));
  foreach my $c (@cs) {$c = &checkAtomicContext($c)};
  
  return @cs;
}

# Return a single string representing the context of any node
sub getNodeContext($) {
  my $node = shift;
  
  return (&isBible($node) ? &bibleContext($node):&otherModContext($node));
}

# Returns an array of atomized context values from a getNodeContext(),
# bibleContext() or otherModContext() string.
sub atomizeContext($) {
  my $context = shift;
  
  my @out;
  if ($context =~ /^(BIBLE|TESTAMENT)_INTRO/) { # from bibleContext()
    push(@out, $context);
  }
  elsif ($context =~ /^(\w+\.\d+)\.(\d+)(\.(\d+|PART))?$/) { # from bibleContext()
    my $bc = $1;
    my $v1 = $2;
    my $v2 = $4;
    if ($v2 eq 'PART') {push(@out, "$bc.$v1!PART");} # special case from fitToVerseSystem
    elsif ($v2) {
      for (my $i = $v1; $i <= $v2; $i++) {
        push(@out, "$bc.$i");
      }
    }
    else {push(@out, $context);}
  }
  elsif ($context =~ /\./) {foreach my $c (split('.', $context)) {push(@out, $c);}}
  else {push(@out, $context);}
  
  foreach my $a (@out) {$a = &checkAtomicContext($a)};

  return @out;
}

# Return the most specific osisID associated with a node's context 
# within its document.
sub getNodeOsisID($) {
  my $node = shift;

  my $context = &getNodeContext($node);
  
  # Bible introduction contexts don't have matching osisIDs.
  # The BEFORE_keyword does not correspond to a real osisID.
  # So use 'other' method for these
  if (&isBible($node) && $context =~ /\.0$/ || &isDict($node) && $context =~ /^BEFORE_/) {
    $context = &otherModContext($node);
  }
  
  my @acs = &atomizeContext($context);
  if (!@acs[0]) {
    &Error("getNodeOsisID: Could not atomize context of node: $node\n(context=$context)");
    return '';
  }
  
  return @acs[0];
}

# Return a 4 part Bible context for $node, which is not atomic (atomic 
# would be 3 parts for a Bible) so it may represent a range of verses.
# Possible forms:
# BIBLE_INTRO.0.0.0 = Bible intro
# TESTAMENT_INTRO.0.0.0 = Old Testament intro
# TESTAMENT_INTRO.1.0.0 = New Testament intro
# Gen.0.0.0 = Gen book intro
# Gen.1.0.0 = Gen chapter 1 intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext($) {
  my $node = shift;
  
  my $context = '';
  
  # get book
  my $bkdiv = @{$XPC->findnodes('ancestor-or-self::osis:div[@type="book"][@osisID][1]', $node)}[0];
  my $bk = ($bkdiv ? $bkdiv->getAttribute('osisID'):'');
  
  # no book means we might be a Bible or testament introduction (or else an entirely different type of OSIS file)
  if (!$bk) {
    my $refSystem = &getRefSystemOSIS($node);
    if ($refSystem !~ /^Bible/) {
      &ErrorBug("bibleContext: OSIS file is not a Bible \"$refSystem\" for node \"$node\"");
      return '';
    }
    my $tst = @{$XPC->findnodes('ancestor-or-self::osis:div[@type=\'bookGroup\'][1]', $node)}[0];
    if ($tst) {
      return "TESTAMENT_INTRO.".(0+@{$XPC->findnodes('preceding::osis:div[@type=\'bookGroup\']', $tst)}).".0.0";
    }
    return "BIBLE_INTRO.0.0.0";
  }

  # find most specific osisID associated with elem (assumes milestone verse/chapter tags and end tags which have no osisID attribute)
  my $c = @{$XPC->findnodes('preceding::osis:chapter[@osisID][1]', $node)}[0];
  if (!($c && $c->getAttribute('osisID') =~ /^\Q$bk.\E(\d+)$/)) {$c = '';}
  my $cn = ($c ? $1:0);
  
  my $v = @{$XPC->findnodes('preceding::osis:verse[@osisID][1]', $node)}[0];
  if (!($v && $v->getAttribute('osisID') =~ /(^|\s)\Q$bk.$cn.\E(\d+)$/)) {$v = '';}
  
  my $e = ($v ? $v:($c ? $c:$bkdiv));

  # get context from most specific osisID
  if ($e) {
    my $id = $e->getAttribute('osisID');
    $context = ($id ? $id:"unk.0.0.0");
    if ($id =~ /^\w+$/) {$context .= ".0.0.0";}
    elsif ($id =~ /^\w+\.\d+$/) {$context .= ".0.0";}
    elsif ($id =~ /^\w+\.\d+\.(\d+)$/) {$context .= ".$1";}
    elsif ($id =~ /^(\w+\.\d+\.\d+) .*\w+\.\d+\.(\d+)$/) {$context = "$1.$2";}
  }
  else {
    &ErrorBug("bibleContext could not determine context of \"$node\"");
    return 0;
  }
  
  return $context;
}

# Return a multi-part, osisID based, context for $node, which is not 
# atomic (atomic would always be 1 part for 'other') so it may represent 
# a series of '.' separated ancestor osisIDs (most specific first). If 
# the node is part of a glossary then the keyword's osisID is returned 
# (even though a keyword is not a container itself) or if the node is 
# part of an introduction before a keyword, its context will be 
# prepended with 'BEFORE_'.
sub otherModContext($) {
  my $node = shift;
  
  # is node in a glossary?
  my $glossaryDiv = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"][last()]', $node)}[0];
  if ($glossaryDiv) {
    # get preceding keyword or self
    my $prevkw = @{$XPC->findnodes('ancestor-or-self::osis:seg[@type="keyword"][1]', $node)}[0];
    if (!$prevkw) {$prevkw = @{$XPC->findnodes('preceding::osis:seg[@type="keyword"][1]', $node)}[0];}
    
    if ($prevkw) {
      foreach my $kw ($XPC->findnodes('.//osis:seg[@type="keyword"]', $glossaryDiv)) {
        if ($kw->isSameNode($prevkw)) {
          if (!$prevkw->getAttribute('osisID')) {
            &ErrorBug("otherModContext: Previous keyword has no osisID \"$prevkw\"");
          }
          return $prevkw->getAttribute('osisID');
        }
      }
    }
    
    # if not, then use BEFORE
    my $nextkw = @{$XPC->findnodes('following::osis:seg[@type="keyword"]', $node)}[0];
    if (!$nextkw) {
      &ErrorBug("otherModContext: There are no entries in the glossary which contains node $node");
      return '';
    }
    if (!$nextkw->getAttribute('osisID')) {
      &ErrorBug("otherModContext: Next keyword has no osisID \"$nextkw\"");
    }
    return 'BEFORE_'.$nextkw->getAttribute('osisID');
  }
  
  # then return ancestor osisIDs
  my @c;
  foreach $osisID ($XPC->findnodes('./ancestor-or-self::osis:*[@osisID]', $node)) {
    if ($osisID->getAttribute('osisID') =~ /^\s*$/) {next;}
    push(@c, $osisID->getAttribute('osisID'));
  }
  my $context = join('.', reverse @c);
  if (!$context) {&Error("otherModContext: There is no ancestor-or-self with an osisID for node $node");}
  
  return $context;
}

# Return context if there is intersection between a node's context and 
# and an attribute's contextsHashP, else return 0.
# $context is a string from getNodeContext()
# $contextsHashP is a hash from getAtomizedAttributeContexts()
sub inContext($\%) {
  my $context = shift;
  my $contextsHashP = shift;
  
  foreach my $atom (&atomizeContext($context)) {
    if ($contextsHashP->{'contexts'}{$atom}) {return $context;}
    # check book separately for big speedup (see getAtomizedAttributeContexts)
    if ($atom =~ s/^([^\.]+).*?$/$1/ && $contextsHashP->{'books'}{$atom}) {
      return $context;
    }
  }
  
  return 0;
}

# Return first book of $bookArrayP which is within context $contextsHashP
# Or else return 0.
sub inGlossaryContext(\@\%) {
  my $bookArrayP = shift;
  my $contextsHashP = shift;
 
  foreach my $bk (@{$bookArrayP}) {
    if (&inContext($bk, $contextsHashP)) {return $bk;}
  }
  
  return 0;
}

# Take a context and check its form. Returns nothing if it's invalid or
# if valid returns a normalized atomic context (like: 'a.b.c' for Bibles 
# or just 'a' for others).
#
# Atomized context values are defined as one of the following:
# BIBLE_INTRO.0.0 = Bible intro
# TESTAMENT_INTRO.0.0 = Old Testament intro
# TESTAMENT_INTRO.1.0 = New Testament intro
# (OSISBK).0.0 = book introduction of OSISBK
# (OSISBK).CH.0 = chapter 1 introduction OSISBK
# (OSISBK).CH.VS = verse OSISBK CH:VS
# BEFORE_osisID = glossary introduction before keyword with osisID
# osisID = any container element or keyword osisID
sub checkAtomicContext($$) {
  my $context = shift;
  my $quiet = shift;
  
  my $work = ($context =~ s/^(\w+)\:// ? $1:$MOD);
  
  my $before = '';
  if ($context =~ /^(BIBLE_INTRO|TESTAMENT_INTRO|$OSISBOOKSRE)(\.(\d+)(\.(\d+))?)?$/) {
    my $bk = $1; my $ch = $3; my $vs = $5;
    if ($bk eq 'TESTAMENT_INTRO' && $ch != 1 && $ch != 2) {
      if (!$quiet) {&Error("checkAtomicContext: TESTAMENT_INTRO is '$ch'.", 'It must be 1 or 2.');}
      return '';
    }
    if ($bk eq 'TESTAMENT_INTRO') {return "$bk.$ch.0";}
    elsif ($bk eq 'BIBLE_INTRO') {return "$bk.0.0";}
    else {
      if ($ch eq '0') {$vs = '0';}
      if ($ch eq '' && $vs eq '') {return $bk;} # This OSISBK is also an osisID
      if ($ch && $vs eq '') {
        &ErrorBug("checkAtomicContext: A whole chapter is not a valid atomized context: $context");
        return '';
      }
      return "$bk.$ch.$vs";
    }
  }
  
  # Then this is an osisID based context
  if ($context =~ s/^BEFORE_//) {$before = 'BEFORE_';}
  
  if ($context =~ /[^\p{L}\p{N}_\.]/) {
    if (!$quiet) {&Error("checkAtomicContext: Illegal character in context: $before$context", "Only chars [\p{L}\p{N}_] are allowed.");}
    return '';
  }
  
  if ($CONTEXT_CHECK_XML && &getModNameOSIS($CONTEXT_CHECK_XML) eq $work && 
        !&existsElementID($context, $CONTEXT_CHECK_XML) && 
        !&existsScope($context, $CONTEXT_CHECK_XML)
      ) {
    &Error("checkAtomicContext: osisID/scope '$context' was not found.");
    $CONTEXT_CHECK_ERR++;
    return '';
  }
  
  return "$before$context";
}

sub checkDictionaryWordsContexts($$) {
  my $osis = shift;
  my $dwf = shift;
  
  &Log("\nCHECKING CONTEXT ATTRIBUTES IN DWF...\n");
  
  if (!ref($osis)) {$osis = $XML_PARSER->parse_file($osis);}
  if (!ref($dwf)) {$dwf = $XML_PARSER->parse_file($dwf);}
  
  $CONTEXT_CHECK_XML = $osis; # This turns on osisID existence checking
  $CONTEXT_CHECK_ERR = 0;
  my $numatt = 0;
  foreach my $ec ($XPC->findnodes('//*[@context]', $dwf)) {
    $numatt++;
    &getAtomizedAttributeContexts($ec->getAttribute('context'));
  }
  foreach my $ec ($XPC->findnodes('//*[@notContext]', $dwf)) {
    $numatt++;
    &getAtomizedAttributeContexts($ec->getAttribute('notContext'));
  }
  
  $CONTEXT_CHECK_XML = ''; # This turns off osisID existence checking
  
  &Report("Checked '$numatt' context and notContext attributes. ($CONTEXT_CHECK_ERR problem(s))");
}

sub existsElementID($$) {
  my $osisID = shift;
  my $xml = shift;
  
  $osisID =~ s/^([^\:]*\:)//;
  
  if (!$ID_CACHE{$xml->URI}{$osisID}) {
    $ID_CACHE{$xml->URI}{$osisID} = 'no';
    # xpath 1.0 does not have "matches" so we need to do some extra work
    my $xpath = ('false' eq 'DWF' ? 
      "//*[name()='entry'][contains(\@osisRef, '$osisID')]/\@osisRef" :
      "//*[contains(\@osisID, '$osisID')]/\@osisID"
    );
    my @test = $XPC->findnodes($xpath, $xml);
    my $found = 0;
    foreach my $t (@test) {
      if ($t->value =~ /(^|\s)(\w+\:)?\Q$osisID\E(\s|$)/) {
        $ID_CACHE{$xml->URI}{$osisID} = 'yes';
        $found++;
      }
    }
    if ($found > 1) {
      &Error("existsElementID: osisID \"$work:$osisID\" appears $found times in $search.", "All osisID values in $work must be unique values.");
    }
  }
  return ($ID_CACHE{$xml->URI}{$osisID} eq 'yes');
}

# Does a particular scope attribute value valid for this OSIS xml file?
sub existsScope($$) {
  my $scope = shift;
  my $xml = shift;
  if (!$SCOPE_CACHE{$xml->URI}{$scope}) {
    $SCOPE_CACHE{$xml->URI}{$scope} = 'no';
  
    # xpath 1.0 does not have "matches" so we need to do some extra work
    my @test = $XPC->findnodes('//osis:div[@type="glossary"][@scope]', $xml);
    my $found = 0;
    foreach my $t (@test) {
      if ($t->getAttribute('scope') eq $scope) {
        $SCOPE_CACHE{$xml->URI}{$scope} = 'yes';
        $found++;
      }
    }
    if (!$found) {
      my $bookOrderP; &getCanon(&conf("Versification"), NULL, \$bookOrderP, NULL);
      my $aP = &scopeToBooks($scope, $bookOrderP);
      foreach my $t (@test) {
        my $hashP = &getAtomizedAttributeContexts($t->getAttribute('scope'));
        if (&inGlossaryContext($aP, $hashP)) {
          $SCOPE_CACHE{$xml->URI}{$scope} = 'yes';
          $found++;
        }
      }
    }
  }

  return ($SCOPE_CACHE{$xml->URI}{$scope} eq 'yes');
}

1;
