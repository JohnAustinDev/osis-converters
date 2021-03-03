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

our ($INOSIS, $MOD, $SCRIPT_NAME, $XML_PARSER, $XPC, %DOCUMENT_CACHE);

# Some of the following routines take either nodes or module names as inputs.
# Note: Whereas //osis:osisText[1] is TRULY, UNBELIEVABLY SLOW, /osis:osis/osis:osisText[1] is fast
sub getOsisModName {
  my $node = shift; # might already be string mod name- in that case just return it

  if (!ref($node)) {
    my $modname = $node; # node is not a ref() so it's a modname
    if (!$DOCUMENT_CACHE{$modname}) {
      our $OSIS;
      my $osis = ($SCRIPT_NAME =~ /^(osis2sword|osis2gobible|osis2ebooks|osis2html)$/ ? $INOSIS:$OSIS);
      if (! -e $osis) {&ErrorBug("getOsisModName: No current osis file to read for $modname.", 1);}
      &initDocumentCache($XML_PARSER->parse_file($osis));
      if (!$DOCUMENT_CACHE{$modname}) {&ErrorBug("getOsisModName: header of osis $osis does not include modname $modname.", 1);}
    }
    return $modname;
  }
  
  # Generate doc data if the root document has not been seen before
  my $headerDoc = $node->ownerDocument->URI;

  if (!$DOCUMENT_CACHE{$headerDoc}) {
    # When splitOSIS() is used, the document containing the header may be different than the current node's document.
    my $splitOSISdoc = $headerDoc;
    if ($splitOSISdoc =~ s/[^\/]+$/other.osis/ && -e $splitOSISdoc) {
      if (!$DOCUMENT_CACHE{$splitOSISdoc}) {&initDocumentCache($XML_PARSER->parse_file($splitOSISdoc));}
      $DOCUMENT_CACHE{$headerDoc} = $DOCUMENT_CACHE{$splitOSISdoc};
    }
    else {&initDocumentCache($node->ownerDocument);}
  }
  
  if (!$DOCUMENT_CACHE{$headerDoc}) {
    &ErrorBug("initDocumentCache failed to init \"$headerDoc\"!", 1);
    return '';
  }
  
  return $DOCUMENT_CACHE{$headerDoc}{'getOsisModName'};
}
# Associated functions use this cached header data for a big speedup. 
# The cache is cleared and reloaded the first time a node is referenced 
# from an OSIS file URI.
sub initDocumentCache {
  my $xml = shift; # must be a document node
  
  my $dbg = "initDocumentCache: ";
  
  my $headerDoc = $xml->URI;
  undef($DOCUMENT_CACHE{$headerDoc});
  $DOCUMENT_CACHE{$headerDoc}{'xml'} = $xml;
  my $shd = $headerDoc; $shd =~ s/^.*\///; $dbg .= "document=$shd ";
  my $osisIDWork = @{$XPC->findnodes('/osis:osis/osis:osisText[1]', $xml)}[0];
  if (!$osisIDWork) {
    &ErrorBug("Document is not an osis document:".$headerDoc, 1);
  }
  $osisIDWork = $osisIDWork->getAttribute('osisIDWork');
  $DOCUMENT_CACHE{$headerDoc}{'getOsisModName'} = $osisIDWork;
  
  # Save data by MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  undef($DOCUMENT_CACHE{$osisIDWork});
  $DOCUMENT_CACHE{$osisIDWork}{'xml'}                = $xml;
  $dbg .= "selfmod=$osisIDWork ";
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisModName'}     = $osisIDWork;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisRefSystem'}   = @{$XPC->findnodes('//osis:header/osis:work[@osisWork="'.$osisIDWork.'"]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'} = @{$XPC->findnodes('//osis:header/osis:work[child::osis:type[@type!="x-glossary"]]/osis:refSystem', $xml)}[0]->textContent;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'} =~ s/^Bible.//i;
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisBibleModName'}    = @{$XPC->findnodes('//osis:header/osis:work[child::osis:type[@type!="x-glossary"]]', $xml)}[0]->getAttribute('osisWork');
  my $dict = @{$XPC->findnodes('//osis:header/osis:work[child::osis:type[@type="x-glossary"]]', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisDictModName'}     = ($dict ? $dict->getAttribute('osisWork'):'');
  my %books; foreach my $bk (map($_->getAttribute('osisID'), $XPC->findnodes('//osis:div[@type="book"]', $xml))) {$books{$bk}++;}
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisBooks'} = \%books;
  my $scope = @{$XPC->findnodes('//osis:header/osis:work[1]/osis:scope', $xml)}[0];
  $DOCUMENT_CACHE{$osisIDWork}{'getOsisScope'} = ($scope ? $scope->textContent():'');
  
  # Save companion data by its MODNAME (gets overwritten anytime initDocumentCache is called, since the header includes all works)
  my @works = $XPC->findnodes('/osis:osis/osis:osisText/osis:header/osis:work', $xml);
  foreach my $work (@works) {
    my $w = $work->getAttribute('osisWork');
    if ($w eq $osisIDWork) {next;}
    undef($DOCUMENT_CACHE{$w});
    $DOCUMENT_CACHE{$w}{'getOsisRefSystem'} = @{$XPC->findnodes('./osis:refSystem', $work)}[0]->textContent;
    $dbg .= "compmod=$w ";
    $DOCUMENT_CACHE{$w}{'getOsisVersification'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisVersification'};
    $DOCUMENT_CACHE{$w}{'getOsisBibleModName'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisBibleModName'};
    $DOCUMENT_CACHE{$w}{'getOsisDictModName'} = $DOCUMENT_CACHE{$osisIDWork}{'getOsisDictModName'};
    $DOCUMENT_CACHE{$w}{'xml'} = ''; # force a re-read when again needed (by existsElementID)
  }
  &Debug("$dbg\n");
  
  return $DOCUMENT_CACHE{$osisIDWork}{'getOsisModName'};
}

# IMPORTANT: the osisCache lookup can ONLY be called on $modname after 
# a call to getOsisModName($modname), since getOsisModName($modname) 
# is where the cache is written.
sub osisCache {
  my $func = shift;
  my $modname = shift;

  if (exists($DOCUMENT_CACHE{$modname}{$func})) {return $DOCUMENT_CACHE{$modname}{$func};}
  &Error("DOCUMENT_CACHE failure: $modname $func\n");
  return '';
}

sub getOsisXML {
  my $mod = shift;

  my $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  if (!$xml) {
    undef($DOCUMENT_CACHE{$mod});
    &getOsisModName($mod);
    $xml = $DOCUMENT_CACHE{$mod}{'xml'};
  }
  return $xml;
}

sub getOsisRefSystem {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisRefSystem', $mod);
  if (!$return) {
    &ErrorBug("getOsisRefSystem: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}

sub getOsisVersification {
  my $mod = &getOsisModName(shift);

  if ($mod eq 'KJV') {return 'KJV';}
  if ($mod eq $MOD) {return &conf('Versification');}
  my $return = &osisCache('getOsisVersification', $mod);
  if (!$return) {
    &ErrorBug("getOsisVersification: No document node for \"$mod\"!");
    return &conf('Versification');
  }
  return $return;
}

sub getOsisBibleModName {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisBibleModName', $mod);
  if (!$return) {
    &ErrorBug("getOsisBibleModName: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}

sub getOsisDictModName {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisDictModName', $mod);
  if (!$return) {
    &ErrorBug("getOsisDictModName: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}

sub getOsisRefWork {return &getOsisModName(shift);}

sub getOsisIDWork {return &getOsisModName(shift);}

sub getOsisBooks {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisBooks', $mod);
  if (!$return) {
    &ErrorBug("getOsisBooks: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}

sub getOsisScope {
  my $mod = &getOsisModName(shift);

  my $return = &osisCache('getOsisScope', $mod);
  if (!$return) {
    &ErrorBug("getOsisScope: No document node for \"$mod\"!");
    return '';
  }
  return $return;
}

sub isChildrensBible {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Book\.\w+CB$/ ? 1:0);
}

sub isBible {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Bible/ ? 1:0);
}

sub isDict {
  my $mod = &getOsisModName(shift);

  return (&osisCache('getOsisRefSystem', $mod) =~ /^Dict/ ? 1:0);
}

1;
