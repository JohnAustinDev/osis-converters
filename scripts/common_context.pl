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

# getContextAttributeHash() takes context/notContext attribute values from 
# DictionaryWords.xml and converts them into a hash containing all the 
# atomized context values (see checkAndNormalizeAtomicContext() function) 
# which compose the attribute value, and a list of entire included books. 
# NOTE: For a big speedup, entire books and 'all' are returned separately.
#
# context/notContext attribute values are space separated instances of 
# either atomized context values or, for brevity and convenience, one of 
# the following:
# - Bible osisRef (which is any combination of: OSISBK.CH.VS or OSISBK.CH.VS-OSISBK.CH.VS) 
#   plus it may begin with OSISBK = 'ALL' meadning all Bible books
# - Comma separated list of Paratext references, such as: GEN 1:2-4, EXO 5:6
# - Other special keywords:
#   ALL = Any context, can be used to cancel a higher level attribute
#   OT = Old Testament (including introductions)
#   NT = New Testament (including introductions)
#   BIBLE_INTRO or BIBLE_INTRO.0 = Bible introduction
#   TESTAMENT_INTRO.1 or TESTAMENT_INTRO.2 = OT or NT introduction, respectively
sub getContextAttributeHash($\$) {
  my $attrValue = shift;
  my $notesP = shift;
  
  my $osisRef = &paratextRefList2osisRef($attrValue);
  
  my %h;
  foreach my $ref (split(/\s+/, $osisRef)) {
    # Handle 'ALL'
    if ($ref eq 'ALL') {undef(%h); $h{'all'}++; return \%h;}
    
    # Handle whole book
    elsif ($OSISBOOKS{$ref}) {$h{'books'}{$ref}++;}
    
    # Handle keywords OT and NT
    elsif ($ref =~ /^(OT|NT)$/) {
      $h{'contexts'}{'TESTAMENT_INTRO.'.($ref eq 'OT' ? '1':'2').'.0'}++;
      foreach my $bk (split(/\s+/, ($ref eq 'OT' ? $OT_BOOKS:$NT_BOOKS))) {
        $h{'books'}{$bk}++;
      }
    }
    
    # Handle special case of BOOK1-BOOK2 for a major speedup
    elsif ($ref =~ /^($OSISBOOKSRE)-($OSISBOOKSRE)$/) {
      my $bookOrderP; &getCanon(&conf('Versification'), NULL, \$bookOrderP, NULL);
      my $aP = &scopeToBooks($ref, $bookOrderP);
      foreach my $bk (@{$aP}) {$h{'books'}{$bk}++;}
    }
    
    # Handle keyword ALL
    elsif ($ref =~ s/^ALL\b//) {
      foreach my $bk (split(/\s+/, "$OT_BOOKS $NT_BOOKS")) {
        if (!$ref) {$h{'books'}{$bk}++;}
        else {foreach my $k (&osisRef2Contexts("$bk$ref", $MOD, 'not-default')) {$h{'contexts'}{$k}++;}};
      }
    }
    
    else {foreach my $k (&osisRef2Contexts($ref, $MOD, 'not-default')) {$h{'contexts'}{$k}++;}}
  }
  
  if ($notesP && $attrValue && !$ALREADY_NOTED_RESULT{$attrValue}) {
    $ALREADY_NOTED_RESULT{$attrValue}++;
    $$notesP .= "NOTE: Converted context attribute value to contexts:\n";
    $$notesP .= "  Context  = $attrValue\n";
    $$notesP .= "  Contexts =".join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'books'}})).' '.join(' ', sort { &osisIDSort($a, $b) } keys(%{$h{'contexts'}}))."\n\n";
  }
  
  return \%h;
}

# Scoped attributes are hierarchical and cummulative. They occur in both
# positive and negative (not) forms. A positive attribute cancels any
# negative forms of that attribute occuring higher in the hierarchy.
sub getScopedAttribute($$) {
  my $a = shift;
  my $m = shift;
  
  my $ret = '';
  
  my $positive = ($a =~ /^not(.*?)\s*$/ ? lcfirst($1):$a);
  if ($positive =~ /^xpath$/i) {$positive = uc($positive);}
  my $negative = ($a =~ /^not/ ? $a:'not'.ucfirst($a));
    
  my @r = $XPC->findnodes("ancestor-or-self::*[\@$positive or \@$negative]", $m);
  if (@r[0]) {
    my @ps; my @ns;
    foreach my $re (@r) {
      my $p = $re->getAttribute($positive);
      if ($p) {
        if ($positive eq 'context') {$p = &paratextRefList2osisRef($p);}
        push(@ps, $p);
        @ns = ();
      }
      my $n = $re->getAttribute($negative);
      if ($n) {
        if ($positive eq 'context') {$n = &paratextRefList2osisRef($n);}
        push(@ns, $n);
      }
    }
    my $retP = ($a eq $positive ? \@ps:\@ns);
    if (@{$retP} && @{$retP}[0]) {
      $ret = join(($a =~ /XPATH/ ? '|':' '), @{$retP});
    }
  }
  
  if ($a eq 'context' && $ret =~ /\bALL\b/) {return '';}
  
  return $ret;
}

# Takes any valid osisRef and returns an equivalent array of atomized contexts.
sub osisRef2Contexts($$$) {
  my $osisRefLong = shift;
  my $osisRefWorkDefault = shift;
  my $workPrefixFlag = shift; # null=if present, 'always'=always include, 'not-default'=only if prefix is not osisRefWorkDefault
  
  # This call to osisRef2osisID includes introductions (even though intros do not have osisIDs, they have context values)
  my @cs = (split(/\s+/, &osisRef2osisID($osisRefLong, $osisRefWorkDefault, $workPrefixFlag, 1)));
  foreach my $c (@cs) {$c = &checkAndNormalizeAtomicContext($c)};
  
  return @cs;
}

# Takes any valid osisID and returns an array with itself and any
# containing DIVIDs. If includeIntro is set, any introduction atomic 
# context is also included.
sub osisID2Contexts($$) {
  my $osisID = shift;
  my $includeIntro = shift;

  my @ids = ();
  
  # Assume osisID is always in $MOD, since context arguments always(?) apply to the current module.
  my @ancdivs = $XPC->findnodes("descendant::*[\@osisID='$osisID']/ancestor::osis:div[\@osisID]", &getModXmlOSIS($MOD));

  # Include introduction?
  if ($includeIntro) {
    if (!@ancdivs) {push(@ids, 'BIBLE_INTRO.0.0.0');}
    else {
      foreach my $d (@ancdivs) {
        # NOTE: chapter intros are currently not returned, for a speedup
        if ($d->getAttribute('type') eq 'book') {
          if (@{$XPC->findnodes('following::osis:chapter[@sID="'.$d->getAttribute('osisID').'.1"]', $d)}[0]) {
            push(@ids, $d->getAttribute('osisID').'.0.0.0');
          }
          last;
        }
        elsif ($d->getAttribute('type') eq 'bookGroup') {
          my $n = 1 + @{$XPC->findnodes('preceding::osis:div[@type="bookGroup"]', $d)};
          push(@ids, "TESTAMENT_INTRO.$n.0.0");
          last;
        }
      }
    }
  }
  
  # Include ancestor DIVIDs
  foreach my $d (@ancdivs) {push(@ids, $d->getAttribute('osisID'));}
  
  push(@ids, $osisID);
  
  return @ids;
}

# Return a string representing the most specific context of a node in 
# any kind of document. For possible return values see bibleContext() 
# and otherModContext())
sub getNodeContext($) {
  my $node = shift;
  return (&isBible($node) ? &bibleContext($node):&otherModContext($node, 1));
}

# Return a 4 part Bible context for $node, which is not atomic (atomic 
# would be 3 parts for a Bible) so it may represent a range of verses.
# Possible forms:
# BIBLE_INTRO.0.0.0 = Bible intro
# TESTAMENT_INTRO.1.0.0 = Old Testament intro
# TESTAMENT_INTRO.2.0.0 = New Testament intro
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
      return "TESTAMENT_INTRO.".(1+@{$XPC->findnodes('preceding::osis:div[@type=\'bookGroup\']', $tst)}).".0.0";
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
    my $id = $e->getAttribute('osisID'); $id =~ s/^.*\s+//;
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

# Returns the osisID-based context for $node. If the node lies within 
# multiple containers having osisIDs, the return value will be a '+' 
# separated list of the ancestor osisIDs (most specific first). Thus the
# return value may contain multiple osisIDs and so is not necessarily 
# atomic (atomic is always a single part for 'other' modules).
# If the node is part of a glossary then the keyword's osisID is used, 
# even though a keyword is not a container itself. Or, if the node is 
# part of an introduction before a keyword, the keyword's osisID will be 
# prepended with 'BEFORE_'.
sub otherModContext($$) {
  my $node = shift;
  my $specificOsisID = shift; # return only the most specific container osisID
  
  my @c;
  
  # is node in a glossary?
  my $glossaryDiv = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"][last()]', $node)}[0];
  if ($glossaryDiv) {
    # get preceding keyword or self
    my $inKeyword = 0;
    my $prevkw = @{$XPC->findnodes('ancestor-or-self::osis:seg[@type="keyword"][1]', $node)}[0];
    if (!$prevkw) {$prevkw = @{$XPC->findnodes('preceding::osis:seg[@type="keyword"][1]', $node)}[0];}
    
    if ($prevkw) {
      foreach my $kw ($XPC->findnodes('.//osis:seg[@type="keyword"]', $glossaryDiv)) {
        if ($kw->isSameNode($prevkw)) {
          if (!$prevkw->getAttribute('osisID')) {
            &ErrorBug("otherModContext: Previous keyword has no osisID \"$prevkw\"");
          }
          push(@c, $prevkw->getAttribute('osisID'));
          $inKeyword++;
          last;
        }
      }
    }
    
    if (!$inKeyword) {
      # if not, then use BEFORE
      my $nextkw = @{$XPC->findnodes('following::osis:seg[@type="keyword"]', $node)}[0];
      if ($nextkw && $nextkw->hasAttribute('osisID')) {
        push(@c, 'BEFORE_'.$nextkw->getAttribute('osisID'));
      }
    }
  }
  
  # then return ancestor osisIDs
  my @ancestors = $XPC->findnodes('./ancestor::osis:*[@osisID]', $node);
  foreach $osisID (reverse @ancestors) {
    if ($osisID->getAttribute('osisID') =~ /^\s*$/) {next;}
    push(@c, $osisID->getAttribute('osisID'));
  }
  if (!@c) {&Error("otherModContext: There is no ancestor-or-self with an osisID for node $node");}
  
  if ($specificOsisID) {return @c[0];}
  else {return join('+', @c);}
}

# Returns an array of atomized context values from a '+' separated list 
# of getNodeContext(), bibleContext() or otherModContext() strings.
sub atomizeContext($) {
  my $context = shift;
  
  my @out;
  foreach my $seg (split(/\+/, $context)) {
    if ($seg =~ /^(BIBLE|TESTAMENT)_INTRO/) { # from bibleContext()
      push(@out, $seg);
    }
    elsif ($seg =~ /^(\w+\.\d+)\.(\d+)\.(\d+)$/) { # from bibleContext()
      my $bc = $1;
      my $v1 = (1*$2);
      my $v2 = (1*$3);
      if ($v2 < $v1) {$v2 = $v1;}
      for (my $i = $v1; $i <= $v2; $i++) {
        push(@out, "$bc.$i");
      }
    }
    else {push(@out, $seg);}
  }
  
  foreach my $a (@out) {$a = &checkAndNormalizeAtomicContext($a);}

  return @out;
}

# Return the most specific osisID associated with a node's context. The 
# osisID will be either that of a containing element or of a glossary 
# keyword.
sub getNodeContextOsisID($) {
  my $node = shift;

  my $context = &getNodeContext($node);
  
  # Introduction contexts don't have matching osisIDs.
  # The BEFORE_keyword does not correspond to a real osisID.
  # So use 'other' method for these.
  if ($context =~ /^(BIBLE_INTRO|TESTAMENT_INTRO|BEFORE_)/) {
    $context = &otherModContext($node, 1); # container osisIDs (requires atomizeContext)
  }
  elsif ($context =~ /^(($OSISBOOKSRE)(\.[1-9]\d*)*?)(\.0)+$/) {return $1;} # osisID for context Gen.1.0.0 is Gen.1 and for Gen.0.0.0 is Gen
  
  my @acs = &atomizeContext($context);
  if (!@acs[0]) {
    &Error("getNodeContextOsisID: Could not atomize context of node: $node\n(context=$context)");
    return '';
  }
  
  return @acs[0];
}

# Return context if there is intersection between a context string and 
# an attribute's contextsHashP, else return 0.
# $context is a string as from getNodeContext()
# $contextsHashP is a hash as from getContextAttributeHash() which may
# include the special keys 'books' or 'all' for a big speedup.
sub inContext($\%) {
  my $context = shift;
  my $contextsHashP = shift;
  
  if ($contextsHashP->{'all'}) {return $context;}
  
  foreach my $atom (&atomizeContext($context)) {
    if ($contextsHashP->{'contexts'}{$atom}) {return $context;}
    # check book separately for big speedup (see getContextAttributeHash)
    if ($atom =~ s/^([^\.]+).*?$/$1/ && $contextsHashP->{'books'}{$atom}) {
      return $context;
    }
  }
  
  return 0;
}

# Return a context string as the '+' separated list of osisID's which 
# comprise a scope attribute's value.
sub getScopeAttributeContext($$) {
  my $scopeAttrib = shift;
  my $bookOrderP = shift;
  
  my @ids;
  foreach my $s (split(/\s+/, $scopeAttrib)) {
    if ($s !~ /\-/) {push(@ids, $s);}
    elsif (!$bookOrderP) {&ErrorBug("getScopeAttributeContext must have bookOrderP to expand scope ranges.");}
    else {push(@ids, @{&scopeToBooks($s, $bookOrderP)});}
  }
  
  return join('+', @ids);
}

# Take a context and check its form. Returns nothing if it's invalid or
# if valid returns a normalized atomic context (like: 'a.b.c' for Bibles 
# or just 'a' for others).
#
# Atomized context values are defined as one of the following:
# BIBLE_INTRO.0.0 = Bible intro
# TESTAMENT_INTRO.1.0 = Old Testament intro
# TESTAMENT_INTRO.2.0 = New Testament intro
# (OSISBK).0.0 = book introduction of OSISBK
# (OSISBK).CH.0 = chapter 1 introduction OSISBK
# (OSISBK).CH.VS = verse OSISBK CH:VS
# BEFORE_osisID = glossary introduction before keyword with osisID
# osisID = any container element or keyword osisID
sub checkAndNormalizeAtomicContext($$) {
  my $context = shift;
  my $quiet = shift;
  
  $context =~ s/![^!]*$//; # remove any extension
  my $pre = ($context =~ /^(\w+\:)/ ? $1:'');
  my $work = ($context =~ s/^(\w+)\:// ? $1:$MOD);
  
  my $before = '';
  if ($context =~ /^(BIBLE_INTRO|TESTAMENT_INTRO|$OSISBOOKSRE)(\.(\d+)(\.(\d+)(\.(\d+))?)?)?$/) {
    my $bk = $1; my $ch = $3; my $vs = $5; my $vl = $7;
    if ($vl && $vs != $vl) {
      &ErrorBug("checkAndNormalizeAtomicContext: A multi-verse Bible context is not a valid atomized context: $context");
      return '';
    }
    if ($bk eq 'TESTAMENT_INTRO' && $ch != 1 && $ch != 2) {
      if (!$quiet) {&Error("checkAndNormalizeAtomicContext: TESTAMENT_INTRO is '$ch'.", 'It must be 1 or 2.');}
      return '';
    }
    if ($bk eq 'TESTAMENT_INTRO') {return "$pre$bk.$ch.0";}
    elsif ($bk eq 'BIBLE_INTRO') {return "$pre$bk.0.0";}
    else {
      if ($ch eq '0') {$vs = '0';}
      if ($ch eq '' && $vs eq '') {return "$pre$bk";} # This OSISBK is also an osisID
      if ($ch && $vs eq '') {
        &ErrorBug("checkAndNormalizeAtomicContext: A whole chapter is not a valid atomized context: $context");
        return '';
      }
      return "$pre$bk.$ch.$vs";
    }
  }
  
  # Then this is an osisID based context
  if ($context =~ s/^BEFORE_//) {$before = 'BEFORE_';}
  
  if ($context =~ /[^\p{gc=L}\p{gc=N}_\.]/) {
    if (!$quiet) {&Error("checkAndNormalizeAtomicContext: Illegal character in context: $before$context", "Only chars [\p{gc=L}\p{gc=N}_] are allowed.");}
    return '';
  }
  
  if ($CONTEXT_CHECK_XML && &getModNameOSIS($CONTEXT_CHECK_XML) eq $work && 
        !&existsElementID($context, $CONTEXT_CHECK_XML) && 
        !&existsScope($context, $CONTEXT_CHECK_XML)
      ) {
    &Error("There is no osisID or scope attribute having the value '$context' in ".$CONTEXT_CHECK_XML->URI." (checkAndNormalizeAtomicContext).", "This is likely caused by a reference to '$context' in ".($DWF ? $DWF->URI:$DICTIONARY_WORDS));
    $CONTEXT_CHECK_ERR++;
    return '';
  }
  
  return "$pre$before$context";
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
    &getContextAttributeHash($ec->getAttribute('context'));
  }
  foreach my $ec ($XPC->findnodes('//*[@notContext]', $dwf)) {
    $numatt++;
    &getContextAttributeHash($ec->getAttribute('notContext'));
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
      my $context = &getScopeAttributeContext($scope, $bookOrderP);
      foreach my $t (@test) {
        my $hashP = &getContextAttributeHash($t->getAttribute('scope'));
        if (&inContext($context, $hashP)) {
          $SCOPE_CACHE{$xml->URI}{$scope} = 'yes';
          $found++;
        }
      }
    }
  }

  return ($SCOPE_CACHE{$xml->URI}{$scope} eq 'yes');
}

1;
