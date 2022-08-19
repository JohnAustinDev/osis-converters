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

use strict;

our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, $TMPDIR);
our ($XPC, $XML_PARSER, %OSIS_ABBR, $OSISBOOKSRE, %OSIS_GROUP);

my %ALREADY_NOTED_RESULT;

# Take a context/notContext attribute value from CF_addDictLinks.xml and
# convert it into a hash containing all the atomized context values (see
# checkAndNormalizeAtomicContext() function) composing that value, plus
# a list of entire included books. 
# NOTE: For a big speedup, entire books and 'all' are returned separately.
#
# context/notContext attribute values are space separated instances of 
# either atomized context values or, for brevity and convenience, one of 
# the following:
# - Bible osisRef (which is any combination of: OSISBK.CH.VS or OSISBK.CH.VS-OSISBK.CH.VS) 
#   plus it may begin with OSISBK = 'ALL' meadning all Bible books
# - Comma separated list of Paratext references, such as: GEN 1:2-4, EXO 5:6
# - These other special keywords:
#   ALL = Any context, can be used to cancel a higher level attribute
#   OT = Old Testament (including introductions)
#   NT = New Testament (including introductions)
#   BIBLE_INTRO or BIBLE_INTRO.0 = Bible introduction
#   BOOKGROUP_INTRO.1 or BOOKGROUP_INTRO.2 = OT or NT introduction, respectively
sub getContextAttributeHash {
  my $attrValue = shift;
  my $notesP = shift;
  
  my $osisRef = &paratextRefList2osisRef($attrValue);
  
  my %h;
  foreach my $ref (split(/\s+/, $osisRef)) {
    # Handle 'ALL'
    if ($ref eq 'ALL') {undef(%h); $h{'all'}++; return \%h;}
    
    # Handle whole book
    elsif (defined($OSIS_ABBR{$ref})) {$h{'books'}{$ref}++;}
    
    # Handle keywords OT and NT
    elsif ($ref =~ /^(OT|NT)$/) {
      $h{'contexts'}{'BOOKGROUP_INTRO.'.($ref eq 'OT' ? '1':'2').'.0'}++;
      foreach my $bk ($ref eq 'OT' ? @{$OSIS_GROUP{'OT'}} : @{$OSIS_GROUP{'NT'}}) {
        $h{'books'}{$bk}++;
      }
    }
    
    # Handle special case of BOOK1-BOOK2 for a major speedup
    elsif ($ref =~ /^($OSISBOOKSRE)-($OSISBOOKSRE)$/) {
      my $aP = &scopeToBooks($ref, &conf('Versification'));
      foreach my $bk (@{$aP}) {$h{'books'}{$bk}++;}
    }
    
    # Handle keyword ALL
    elsif ($ref =~ s/^ALL\b//) {
      foreach my $bk (sort keys %OSIS_ABBR) {
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
sub getScopedAttribute {
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
sub osisRef2Contexts {
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
sub osisID2Contexts {
  my $osisID = shift;
  my $includeIntro = shift;

  my @ids = ();
  
  # Assume osisID is always in $MOD, since context arguments always(?) apply to the current module.
  my @ancdivs = $XPC->findnodes("descendant::*[\@osisID='$osisID']/ancestor::osis:div[\@osisID]", &getOsisXML($MOD));

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
          push(@ids, "BOOKGROUP_INTRO.$n.0.0");
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

# Return a string representing the context of a node in any kind of 
# document. For possible return values see bibleContext() and 
# otherModContext())
sub getNodeContext {
  my $node = shift;

  return (&isBible($node) ? &bibleContext($node):&otherModContext($node));
}

# Return a 4 part Bible context for $node, which is not atomic (atomic 
# would be 3 parts for a Bible) so it may represent a range of verses.
# Possible forms:
# BIBLE_INTRO.0.0.0 = Bible intro
# BOOKGROUP_INTRO.1.0.0 = Old Testament intro
# BOOKGROUP_INTRO.2.0.0 = New Testament intro
# BOOKSUBGROUP_INTRO.1.1.0 = 1st OT sub-group intro
# BOOKSUBGROUP_INTRO.1.2.0 = 2nd OT sub-group intro
# Gen.0.0.0 = Gen book intro
# Gen.1.0.0 = Gen chapter 1 intro
# Gen.1.1.1 = Genesis 1:1
# Gen.1.1.3 = Genesis 1:1-3
sub bibleContext {
  my $node = shift;
  
  my $context = '';
  
  # get book
  my $bkdiv = @{$XPC->findnodes('ancestor-or-self::osis:div[@type="book"][@osisID][1]', $node)}[0];
  my $bk = ($bkdiv ? $bkdiv->getAttribute('osisID'):'');
  
  # no book means we might be a Bible, bookGroup or bookSubGroup introduction
  # (or else in a different type of OSIS file entirely)
  if (!$bk) {
    my $refSystem = &getOsisRefSystem($node);
    if ($refSystem !~ /^Bible/) {
      &ErrorBug("bibleContext: OSIS file is not a Bible \"$refSystem\" for node \"$node\"");
      return '';
    }
    my $tst = @{$XPC->findnodes('ancestor-or-self::osis:div[@type="bookGroup"]', $node)}[0];
    if ($tst) {
      # If we're in a bookGroup (but not in a book) then we are either in a
      # bookGroup intro or a bookSubGroup intro. We are in a bookSubGroup
      # intro if there exists a preceding book, or [bookSubGroup] TOC
      # milestone, in the bookGroup OR there exists material between books
      # AND we are in the div immediately preceding the first book of the
      # bookGroup. Otherwise we are in the bookGroup introduction.
      my $bgnum = (1+@{$XPC->findnodes('preceding::osis:div[@type="bookGroup"]', $tst)});
      my $bsgnum = 0;
      my $sureBSGChildren = @{$XPC->findnodes('child::node()
        [not(self::osis:div[@type="book"])]
        [preceding-sibling::osis:div[@type="book"]]', $tst)}[0];
      my $bgid = $tst->getAttribute('osisID');
      my $chbsgnum = 1;
      my $inbsg = 0;
      my $toc = &conf('TOC');
      foreach my $child ($XPC->findnodes('/node()', $tst)) {
        my $mybook = @{$XPC->findnodes('self::osis:div[@type="book"]', $child)}[0];
        if ($mybook) {
          if ($inbsg) {
            $chbsgnum++;
            $inbsg = 0;
          }
        }
        elsif (@{$XPC->findnodes('preceding-sibling::osis:div[@type="book"]', $child)}[0] ||
          @{$XPC->findnodes('preceding::osis:milestone[@type="x-usfm-toc'.$toc.'"][1]
            [contains(@n, "[bookSubGroup]")]', $child)}[0]) {
          $inbsg = 1;
        }
        elsif ($sureBSGChildren && @{$XPC->findnodes('following-sibling::node()[1]
          [self::osis:div[@type="book"]]', $child)}[0]) {
          $inbsg = 1;
        }
        if ($inbsg && $child->unique_key eq @{$XPC->findnodes('ancestor-or-self::node()
          [parent::osis:div[@type="bookGroup"]]', $node)}[0]->unique_key) {
          $bsgnum = $chbsgnum;
          last;
        }
      }
      if ($bsgnum) {
        return "BOOKSUBGROUP_INTRO.$bgnum.$bsgnum.0";
      }
      return "BOOKGROUP_INTRO.$bgnum.0.0";
    }
    # If we're not in a bookGroup we are Bible introduction.
    return "BIBLE_INTRO.0.0.0";
  }

  # find most specific osisID associated with elem (assumes milestone
  # verse/chapter tags and end tags which have no osisID attribute)
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
sub otherModContext {
  my $node = shift;
  
  my @c;
  
  my $aggregate = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="x-aggregate-subentry"]', $node)}[0];
  
  # is node in a glossary?
  my $glossaryDiv = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"][last()]', $node)}[0];
  if ($glossaryDiv && !$aggregate) {
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
  foreach my $osisID (reverse @ancestors) {
    if ($osisID->getAttribute('osisID') =~ /^\s*$/) {next;}
    push(@c, $osisID->getAttribute('osisID'));
  }
  if (!@c) {&Error("otherModContext: There is no ancestor-or-self with an osisID for node $node");}
  
  return join('+', @c);
}

# Returns an array of atomized context values from a '+' separated list 
# of getNodeContext(), bibleContext() or otherModContext() strings.
sub atomizeContext {
  my $context = shift;
  
  my @out;
  foreach my $seg (split(/\+/, $context)) {
    if ($seg =~ /^(BIBLE_INTRO|BOOKGROUP_INTRO|BOOKSUBGROUP_INTRO)/) { # from bibleContext()
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

  return \@out;
}

# Return context if there is intersection between a context string and 
# an attribute's contextsHashP, else return 0.
# $context is a string as from getNodeContext()
# $contextsHashP is a hash as from getContextAttributeHash() which may
# include the special keys 'books' or 'all' for a big speedup.
sub inContext {
  my $context = shift;
  my $contextsHashP = shift;
  
  if ($contextsHashP->{'all'}) {return $context;}
  
  foreach my $atom (@{&atomizeContext($context)}) {
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
sub getScopeAttributeContext {
  my $scopeAttrib = shift;
  my $vsys = shift;
  
  my @ids;
  foreach my $s (split(/\s+/, $scopeAttrib)) {
    if ($s !~ /\-/) {push(@ids, $s);}
    else {push(@ids, @{&scopeToBooks($s, $vsys)});}
  }
  
  return join('+', @ids);
}

# Take a context and check its form. Returns nothing if it's invalid or
# if valid returns a normalized atomic context (like: 'a.b.c' for Bibles 
# or just 'a' for others).
#
# Atomized context values are defined as one of the following:
# BIBLE_INTRO.0.0 = Bible intro
# BOOKGROUP_INTRO.1.0 = Old Testament intro
# BOOKGROUP_INTRO.2.0 = New Testament intro
# BOOKSUBGROUP_INTRO.1.1.0 = 1st OT book sub-group intro
# (OSISBK).0.0 = book introduction of OSISBK
# (OSISBK).CH.0 = chapter 1 introduction OSISBK
# (OSISBK).CH.VS = verse OSISBK CH:VS
# BEFORE_osisID = glossary introduction before keyword with osisID
# osisID = any container element or keyword osisID
my ($CONTEXT_CHECK_XML, $CONTEXT_CHECK_ERR);
sub checkAndNormalizeAtomicContext {
  my $context = shift;
  my $quiet = shift;
  
  my $pre = ($context =~ /^(\w+\:)/ ? $1:'');
  my $work = ($context =~ s/^(\w+)\:// ? $1:$MOD);
  
  my $before = '';
  my $ext = ($context =~ s/(![^!]*)$// ? $1:''); # remove any extension
  if ($context =~ /^(BIBLE_INTRO|BOOKGROUP_INTRO|BOOKSUBGROUP_INTRO|$OSISBOOKSRE)(\.(\d+)(\.(\d+)(\.(\d+))?)?)?$/) {
    my $bk = $1; my $ch = $3; my $vs = $5; my $vl = $7;
    if ($vl && $vs != $vl) {
      &ErrorBug("checkAndNormalizeAtomicContext: A multi-verse Bible context is not a valid atomized context: $context");
      return '';
    }
    if ($bk eq 'BOOKGROUP_INTRO') {return "$pre$bk.$ch.0";}
    elsif ($bk eq 'BOOKSUBGROUP_INTRO') {return "$pre$bk.$ch.$vs";}
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
  $context .= $ext; # so add extension back
  if ($context =~ s/^BEFORE_//) {$before = 'BEFORE_';}
  
  if ($context =~ /[^\p{gc=L}\p{gc=N}_\.\!]/) {
    if (!$quiet) {&Error("checkAndNormalizeAtomicContext: Illegal character in context: $before$context", "Only chars [\p{gc=L}\p{gc=N}_\.\!] are allowed.");}
    return '';
  }
  
  if ($CONTEXT_CHECK_XML && &getOsisModName($CONTEXT_CHECK_XML) eq $work && 
        !&existsElementID($context, $CONTEXT_CHECK_XML) && 
        !&existsScope($context, $CONTEXT_CHECK_XML)
      ) {
    &Error("There is no osisID or scope attribute having the value '$context' in ".$CONTEXT_CHECK_XML->URI." (checkAndNormalizeAtomicContext).", "This is likely caused by a reference to '$context' in CF_addDictLinks.xml");
    $CONTEXT_CHECK_ERR++;
    return '';
  }
  
  return "$pre$before$context";
}

sub checkAddDictLinksContexts {
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
  foreach my $ec ($XPC->findnodes('//*[@notExplicit]', $dwf)) {
    if ($ec->getAttribute('notExplicit') =~ /^(true|false)$/) {next;}
    $numatt++;
    &getContextAttributeHash($ec->getAttribute('notExplicit'));
  }
  foreach my $ec ($XPC->findnodes('//*[@onlyExplicit]', $dwf)) {
    if ($ec->getAttribute('onlyExplicit') =~ /^(true|false)$/) {next;}
    $numatt++;
    &getContextAttributeHash($ec->getAttribute('onlyExplicit'));
  }
  
  $CONTEXT_CHECK_XML = ''; # This turns off osisID existence checking
  
  &Report("Checked '$numatt' attributes with context values. ($CONTEXT_CHECK_ERR problem(s))");
}

my %ID_CACHE;
sub existsElementID {
  my $osisID = shift;
  my $xml = shift;
  
  $osisID =~ s/^([^\:]*\:)//;
  
  if (!$ID_CACHE{$xml->URI}{$osisID}) {
    $ID_CACHE{$xml->URI}{$osisID} = 'no';
    my @test = $XPC->findnodes("//*[contains(\@osisID, '$osisID')]/\@osisID", $xml);
    my $found = 0;
    foreach my $t (@test) {
      if ($t->value =~ /(^|\s)(\w+\:)?\Q$osisID\E(\s|$)/) {
        $ID_CACHE{$xml->URI}{$osisID} = 'yes';
        $found++;
      }
    }
    if ($found > 1) {
      &Error("existsElementID: osisID \"$osisID\" appears $found times.", "All osisID values in must be unique values.");
    }
  }
  return ($ID_CACHE{$xml->URI}{$osisID} eq 'yes');
}

# Does a particular scope attribute value valid for this OSIS xml file?
my %SCOPE_CACHE;
sub existsScope {
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
      my $context = &getScopeAttributeContext($scope, &conf("Versification"));
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

sub getGlossaryScopeAttribute {
  my $e = shift;
  
  my $eDiv = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="x-aggregate-subentry"]', $e)}[0];
  if ($eDiv && $eDiv->getAttribute('scope')) {return $eDiv->getAttribute('scope');}

  my $glossDiv = @{$XPC->findnodes('./ancestor-or-self::osis:div[@type="glossary"]', $e)}[0];
  if ($glossDiv) {return $glossDiv->getAttribute('scope');}

  return '';
}

1;
