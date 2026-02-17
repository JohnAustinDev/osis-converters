#! /usr/bin/perl

# To update CF_addDictLinks.xml so it may produce AI validated links,  
# follow these steps:
# 1) Run rank_glossary_terms.pl to generate prompts_terms which must be
#    one-by-one fed to AI to produce the terms.csv file.
# 2) Run rank_glossary_links.pl to generate prompts_links which must be
#    one-by-one fed to AI to produce the links.csv file.
# 3) Run update_addDictLinks.pl which reads these two csv files and
#    updates CF_addDictLinks.xml so it will produce valid links.

my %config = (
  'only link capitalized proper nouns' => 1,
  'link exact term if term length less than' => 4,
  'link exact term if link count greater than' => 400,
  'default' => {'keep link classes' => '(A|B)'},
);

use strict;
use Encode;
use Text::CSV_XS;
use File::Spec;
use FindBin qw($Bin);
use XML::LibXML;
use Data::Dumper;

my $termsCSV = shift;
my $linksCSV = shift;
my $addDictLinksXML = shift;

if (
  !$termsCSV || !$linksCSV || !$addDictLinksXML ||
  ! -e $termsCSV | ! -e $linksCSV | ! -e $addDictLinksXML
) {
  die "Usage update_addDictLinks.pl /path/to/terms.csv /path/to/links.csv /path/to/CF_addDictLinks.xml\n";
}

my $OSIS_NAMESPACE = 'http://www.bibletechnologies.net/2003/OSIS/namespace';
my $TEI_NAMESPACE = 'http://www.crosswire.org/2013/TEIOSIS/namespace';
my $ADDDICTLINKS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
my $XPC = XML::LibXML::XPathContext->new;
$XPC->registerNs('osis', $OSIS_NAMESPACE);
$XPC->registerNs('tei', $TEI_NAMESPACE);
$XPC->registerNs('dw', $ADDDICTLINKS_NAMESPACE);
my $XML_PARSER = XML::LibXML->new();

# Read the CF_addDictLinks.xml into LibXUL document
my $dwf = $XML_PARSER->parse_file($addDictLinksXML);

# Read the two CSV files into hash of hashes
my %terms;
my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });
open(my $fh, "<:encoding(utf8)", "$termsCSV") or die "$termsCSV: $!\n";
while (my $row = $csv->getline($fh)) {
  my $ent = @$row[0];
  my $gloss = @$row[1];
  my $class = @$row[2];
  my $count = @$row[3];
  $terms{$ent} = { 'gloss' => $gloss, 'class' => $class, 'count' => $count };
}
close $fh;
my %links;
my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });
open(my $fh, "<:encoding(utf8)", "$linksCSV") or die "$linksCSV: $!\n";
while (my $row = $csv->getline($fh)) {
  my $ent = @$row[0];
  my $link = @$row[1];
  my $osisID = @$row[2];
  my $class = @$row[3];
  my @osisIDs;
  if (!defined($links{$ent}{$class}{'osisIDs'})) {
    $links{$ent}{$class}{'osisIDs'} = \@osisIDs;
  }
  push(@{$links{$ent}{$class}{'osisIDs'}}, $osisID);
  my @links;
  if (!defined($links{$ent}{$class}{'links'})) {
    $links{$ent}{$class}{'links'} = \@links;
  }
  push(@{$links{$ent}{$class}{'links'}}, $link);
}
close $fh;
#print Dumper(\%links); exit 0;

# Update each entry
foreach my $nameNode ($XPC->findnodes(".//dw:entry/dw:name", $dwf)) {
  my $entry = $nameNode->textContent();
  my $entryNode = $nameNode->parentNode();
  my @matchNodes = $XPC->findnodes(".//dw:match", $entryNode);
  
  # Add context or notContext attribute if appropriate
  if ($links{$entry}) {
    my (@context, @notContext);
    foreach my $class (keys %{$links{$entry}}) {
      my $re = $config{'default'}{'keep link classes'};
      if ($class =~ /$re/) {
        push(@context, @{$links{$entry}{$class}{'osisIDs'}});
      } else {
        push(@notContext, @{$links{$entry}{$class}{'osisIDs'}});
      }
    }
    if (@notContext) {
      if (@context < @notContext) {
        my $val = join(' ', sort @context);
        if ($entryNode->getAttribute('context') ne $val) {
          $entryNode->setAttribute('context', $val);
          &Log("Added context to $entry: $val");
        }
      } else {
        my $val = join(' ', sort @notContext);
        if ($entryNode->getAttribute('notContext') ne $val) {
          $entryNode->setAttribute('notContext', $val);
          &Log("Added notContext to $entry: $val");
        }
      }
    }
  }
  
  # Enforce capitalization if appropriate (class B is Proper Noun)
  if (
    $terms{$entry}{'class'} eq 'B' &&
    $config{'only link capitalized proper nouns'}
  ) {
    foreach my $matchNode (@matchNodes) {
      my $t = $matchNode->textContent();
      if ($t =~ s/^(.*?\/[^i\/]*)i([^i\/]*)$/$1$2/) {
        &setTextContent($matchNode, $t);
        &Log("Enforced capitalization on $entry: $t");
      }
    }
  }
  
  # Enforce exact term if appropriate
  my $lenlt = $config{'link exact term if term length less than'};
  my $cntgt = $config{'link exact term if link count greater than'};
  if (length($entry) < $lenlt || $cntgt < $terms{$entry}{'count'}) {
    foreach my $matchNode (@matchNodes) {
      my $t = $matchNode->textContent();
      if ($t =~ s/(?<=\\E)\\S\*(\)?)/$1\\b/g) {
        &setTextContent($matchNode, $t);
        &Log("Enforced exact term on $entry: $t");
      }
    }
  }
}

# Overwrite CF_addDictLinks.xml with an updated version
if (open(XML, ">$addDictLinksXML")) {
  print XML $dwf->toString();
  close(XML);
}

########################################################################
########################################################################

sub setTextContent {
  my $element = shift;
  my $text = shift;
 
  foreach my $c ($element->childNodes()) {$c->unbindNode();}
  my $newNode = $element->ownerDocument->createTextNode($text);
  $element->appendChild($newNode);
}

sub Log {
  my $t = shift;
  
  print encode('utf8', $t . "\n");
}
