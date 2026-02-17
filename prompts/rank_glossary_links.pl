#! /usr/bin/perl

# To update CF_addDictLinks.xml so it may produce AI validated links,  
# follow these steps:
# 1) Run rank_glossary_terms.pl to generate prompts_terms which must be
#    one-by-one fed to AI to produce the terms.csv file.
# 2) Run rank_glossary_links.pl to generate prompts_links which must be
#    one-by-one fed to AI to produce the links.csv file.
# 3) Run update_addDictLinks.pl which reads these two csv files and
#    updates CF_addDictLinks.xml so it will produce valid links.

# Term Classes
# A - deterministic phrase (safe auto-link)
# B - proper name (high confidence)
# C - domain/technical term (moderate validation required)
# D - generic lexical term (high ambiguity, full validation required)

# Link Classes (link quality)
# A: Excellent
# B: Good
# C: Fair
# D: Poor

my %config = (
  'default' => {'term classes requiring validation' => '(C|D)'},
);

use strict;
use Encode;
use Text::CSV_XS;
use File::Spec;
use FindBin qw($Bin);
use XML::LibXML;
use Data::Dumper;

my $AI_PROMPT_LEN = 75;
my $PROMPDIR = './prompts_links';

my $languageName = shift;
my $DIR_LOG_sfm2osis = shift || '.';
my $csvFile = shift || './terms.csv';

$DIR_LOG_sfm2osis =~ s/\/$//;
if (!$languageName || !$DIR_LOG_sfm2osis || !$csvFile) {
  die "Usage rank_glossary_links.pl languageName /path/to/oc-log-directory /path/to/terms.csv\n";
}

my $OSIS_NAMESPACE = 'http://www.bibletechnologies.net/2003/OSIS/namespace';
my $TEI_NAMESPACE = 'http://www.crosswire.org/2013/TEIOSIS/namespace';
my $ADDDICTLINKS_NAMESPACE= "http://github.com/JohnAustinDev/osis-converters";
my $XPC = XML::LibXML::XPathContext->new;
$XPC->registerNs('osis', $OSIS_NAMESPACE);
$XPC->registerNs('tei', $TEI_NAMESPACE);
$XPC->registerNs('dw', $ADDDICTLINKS_NAMESPACE);
my $XML_PARSER = XML::LibXML->new();

# Read the CSV file into a hash of hashes
my %rows;
my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });
open(my $fh, "<:encoding(utf8)", "$csvFile") or die "$csvFile: $!\n";
while (my $row = $csv->getline($fh)) {
  my $ent = @$row[0];
  my $gloss = @$row[1];
  my $class = @$row[2];
  my $count = @$row[3];
  $rows{$ent} = { 'gloss' => $gloss, 'class' => $class, 'count' => $count };
}
close $fh;

# Determine which terms are high risk, selected them as error prone
my %riskyRows; # term => priority
my $re = $config{'default'}{'term classes requiring validation'};
foreach my $e (keys %rows) {
  if ($rows{$e}{'class'} =~ /$re/) {
    $riskyRows{$e} = sprintf("%s %03d", $rows{$e}{'class'}, $rows{$e}{'count'});
  }
}

# Find MOD & DICTMOD
my $m = File::Spec->rel2abs("$DIR_LOG_sfm2osis");
$m =~ s/^.*\///;
my $mod     = $m =~ /^(.*?)DICT$/ ? $1 : $m;
my $dictmod = $m =~ /DICT$/ ? $m : $m . 'DICT';
my $moddir  = $m =~ /DICT$/ ? $DIR_LOG_sfm2osis . "/../$mod/" : $DIR_LOG_sfm2osis;
my $dictdir = $m =~ /DICT$/ ? $DIR_LOG_sfm2osis : $DIR_LOG_sfm2osis . "/../$dictmod" ;
my $modosis = "$moddir/$mod.xml";
my $dictosis = "$dictdir/$dictmod.xml";
if (! -e $modosis) {die "'$modosis' does not exist near: $DIR_LOG_sfm2osis\n";}
if (! -e $dictosis) {die "'$dictosis' does not exist near: $DIR_LOG_sfm2osis\n";}

# Create verse container OSIS file IF it does not exist (this runs SLOW)
my $verseContainerOsis = "$moddir/${mod}_vc.xml";
if (! -e $verseContainerOsis || -M $verseContainerOsis > -M $modosis) {
  &shell("saxonb-xslt -l -ext:on -xsl:'$Bin/../lib/bible/containers.xsl' -s:'$modosis' -o:'$verseContainerOsis'");
}
if (! -e $verseContainerOsis || -M $verseContainerOsis > -M $modosis) {
  die "Error container OSIS file: $verseContainerOsis\n";
}

# Create AI prompts to scrutinize the link contexts of selected terms
if (-e glob("$PROMPDIR/*.txt")) {`rm '$PROMPDIR'/*.txt`;}
if (! -e "$PROMPDIR") {`mkdir '$PROMPDIR'`;}
foreach my $term (
  sort {$riskyRows{$a} <=> $riskyRows{$b}}
  keys %riskyRows
) {
  my $hP = &readTerm($term, $dictosis);
  my $entryText = $hP->{'text'};
  my $termID = $hP->{'osisID'};
  
  my $refsAP = &readRefs($termID, $verseContainerOsis);
  
  my $n = 1;
  my $single = @$refsAP <= $AI_PROMPT_LEN;
  while (@$refsAP) {
    my @batch = splice(@$refsAP, 0, $AI_PROMPT_LEN);
    my $path = sprintf("%s/%s prompt %s%s.txt",
      $PROMPDIR,
      $riskyRows{$term},
      $term,
      $single ? '' : '_' . $n . '-' . ($n + @batch - 1)
    );
    if (-e $path) {die "Prompt file exists: $path\n";}
    writePrompt($languageName, $entryText, \@batch, $path);
    $n += @batch;
  }
}

########################################################################
########################################################################

sub readTerm {
  my $term = shift;
  my $osisdict = shift;
  
  my $osis = $XML_PARSER->parse_file($osisdict);
  
  my @kws = $XPC->findnodes(".//osis:div[\@type='x-keyword'][descendant::osis:seg[\@type='keyword'][normalize-space()='$term']]", $osis);
  if (@kws == 1) {
    my $kw = @kws[0];
    $kw = &deleteXpath('.//osis:*[@resp="x-oc"]', $kw);
    
    my @osisText = $XPC->findnodes('.//osis:osisText', $osis);
    my $m = @osisText[0]->getAttribute('osisRefWork');
    my @entnodes = $XPC->findnodes(
      "descendant::osis:seg[\@type='keyword'][normalize-space()='$term']",
      $kw
    );
    my $entnode = @entnodes[0];
    my $osisID = $m . ':' . $entnode->getAttribute('osisID');
    
    # Mark our term
    my $termtext = $entnode->textContent();
    $termtext .= ':';
    my $new_node = $osis->ownerDocument->createTextNode($termtext);
    $entnode->replaceNode($new_node);
    
    my %result;
    $result{'text'} = $kw->textContent();
    $result{'text'} =~ s/^\s+|\s+$//g;
    $result{'text'} =~ s/\s+/ /g;
    $result{'osisID'} = $osisID;
    return \%result;
  } if (@kws > 1) {
    die "Too many keywords: $term\n";
  } else {
    die "Failed to find keyword: $term\n";
  }
}

sub readRefs {
  my $termID = encode('utf8', shift);
  my $osisvc = shift;
  
  my $osis = $XML_PARSER->parse_file($osisvc);
  
  my $refxpath = "osis:reference[contains(concat(' ', normalize-space(\@osisRef), ' '), ' $termID ')]";
  
  my @refNodes = $XPC->findnodes(".//$refxpath", $osis);
  
  my @refs;
  foreach my $refNode (@refNodes) {
    my @elems = $XPC->findnodes('ancestor::osis:*[@osisID][1]', $refNode);
    if (!@elems) {die "No osisID ancestor for reference to $termID\n";}
    my $elem = @elems[0];
    
    # Mark our reference
    my $reftext = $refNode->textContent();
    $reftext =~ s/^(.*?)(\W*)$/*$1*$2/g;
    my $new_node = $elem->ownerDocument->createTextNode($reftext);
    $refNode->replaceNode($new_node);
    
    $elem = &deleteXpath('.//osis:chapter | .//osis:verse | .//osis:note | .//osis:*[@resp="x-oc"]', $elem);

    # Normalized text
    my $text = $elem->textContent();
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/\s+/ /g;
    
    # Shorten text to one sentence, if too long
    if (length($text) > 256) {
      $text =~ s/^.*?\.\s+([^\.]*\*[^\*]+\*)/$1/;
      $text =~ s/(\*[^\*]+\*[^\.]*\.).*?$/$1/;
    }
    
    # Remove note initial reference text
    if ($elem->getAttribute('osisID') =~ /!note/) {
      $text =~ s/^[\s\d\-:]+//;
    }
    
    # Use only first segment of osisID
    my $osisID = $elem->getAttribute('osisID');
    $osisID =~ s/\s+.*$//;
    
    push(@refs, $osisID . ": " . $text);
  }
  if (!@refs) {
    die "Failed to find references: $termID\n";
  }
  
  return \@refs;
}

sub deleteXpath {
  my $xpath = shift;
  my $top = shift;
  
  my $clone = $top->cloneNode(1);
  foreach my $d ($XPC->findnodes($xpath, $clone)) {$d->unbindNode();}
  return $clone;
}

sub writePrompt {
  my $langName = shift;
  my $entryText = shift;
  my $refsAP = shift;
  my $outfile = shift;
  
  my $result = "We are analyzing a $langName OSIS Bible glossary term.
You are performing glossary term relevance tiering using a locked universal rubric.

This rubric MUST NOT be reinterpreted, optimized, or reconsidered during this run or future runs.
You MUST apply it mechanically and consistently.

Tier A: Excellent. Assign ONLY if ALL are true:
  Exact match between the term's contextual usage and the term's glossary description.
  The term's contextual usage matches the glossary term's part of speech (e.g., noun-to-noun).
  
Tier B: Good. Assign ONLY if ALL are true:
  The term's contextual usage meaning is largely the same as the glossary term's description, but the glossary covers a broader or narrower scope.
  The term's contextual usage either matches, or there is only a minor grammatical mismatch (e.g., plural vs. singular) compared to the glossary term's part of speech.
  
Tier C: Fair. Assign ONLY if no other tier's criteria are met.
  
Tier D: Poor. Assign ONLY if ANY are true:
  Meaning of the term's contextual usage is unrelated to the term's glossary description (e.g., \"bank\" of a river vs. financial bank).
  There is a part of speech mismatch between the term's contexual usage and the glossary term. (e.g., verb-to-noun).
  
Example of tier A:
  glossary: Time - The Jews considered 6am to be the first hour of the day.
  text: The *time* of the earthquake was the fourth hour.
  
Example of tier D:
  glossary: Time - The Jews considered 6am to be the first hour of the day.
  text: Let both grow together until the harvest time.
  
Here is the glossary term, always followed by a colon, then its description:

$entryText

Here is a list of OSIS references where this term (or its forms) occurs:

" . join("\n", @{$refsAP}) . "

Please:

1. Read the glossary description carefully and identify its core semantic domains.
2. Analyze the reference term, which is surrounded by '*' symbols, within its context.
3. Group the references into tiers A through D based on the provided rubric (A=Excellent, B=Good, C=Fair, D=Poor).
4. Explain your reasoning step-by-step before providing the final tier assigments.
5. Format your output as escaped CSV having no heading row and exactly these four columns:
\"Tuvan glossary term\",\"Tuvan reference term\",\"osisID\",\"Tier\"
6. The \"Tuvan glossary term\" value MUST be the exact term from the glossary entry (so it MUST be the same for ALL rows).
7. Use the complete OSIS reference format only (e.g., Gen.7.2!note.n1), not human-readable references.
8. Cross-Check Requirement: Before final output, you must cross-reference your step-by-step reasoning with the final CSV data. If the reasoning identifies a mismatch or a specific tier (e.g., Tier D), the CSV MUST reflect that exact tier. Discrepancies between reasoning and the CSV are a failure of the mechanical application.
9. Provide a copy button so I can copy the output as raw text.
10. Do NOT include commentary.

Goal:
To assemble a CSV spreadsheet that will help me determine which term usages should be linked to the glossary, and which should not.
";

  if ($outfile) {
    if (open(OUTF, ">:encoding(UTF-8)", "$outfile")) {
      print OUTF $result;
      close(OUTF);
    } else {
      die "Could not open output file $outfile.\n";
    }
  } else {
    print $result;
  }
}

sub shell {
  my $cmd = shift;
  my $allowNonZeroExit = shift;
  
  # Run and save result of stdout+stderr
  my $result;
  open(my $fh, "-|", "$cmd 2>&1") or die "Couldn't run command: $!";
  while (my $line = <$fh>) {print "$line"; $result .= $line;}
  close($fh);
  
  # Check for errors. If $allowNonZeroExit, there are no errors.
  my $error = $?; $error = ($allowNonZeroExit ? 0:$error);
  $result = decode('utf8', $result);

  if ($error != 0) {die "ERROR: $cmd: $error\n";}

  return $result;
}
