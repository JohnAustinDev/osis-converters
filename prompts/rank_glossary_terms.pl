#!/usr/bin/perl

# To update CF_addDictLinks.xml so it may produce AI validated links,  
# follow these steps:
# 1) Run rank_glossary_terms.pl to generate prompts_terms which must be
#    one-by-one fed to AI to produce the terms.csv file.
# 2) Run rank_glossary_links.pl to generate prompts_links which must be
#    one-by-one fed to AI to produce the links.csv file.
# 3) Run update_addDictLinks.pl which reads these two csv files and
#    updates CF_addDictLinks.xml so it will produce valid links.

use strict;

my $AI_PROMPT_LEN = 50;
my $PROMPDIR = './prompts_terms';

my $languageName = shift;
my $DIR_LOG_sfm2osis = shift || '.';

if (!$languageName || !$DIR_LOG_sfm2osis) {
  die "Usage rank_glossary_terms.pl languageName /path/to/oc-log-directory\n";
}

my $LOG_sfm2osis = "$DIR_LOG_sfm2osis/LOG_sfm2osis.txt";

if (open(INF, "<:encoding(UTF-8)", "$LOG_sfm2osis")) {
  my @terms;
  while (<INF>) {
    if (/^\s+(\d+)\s+links to (.*?)\s+as\s+/) {
      push(@terms, "$2 ($1)");
    }
  }
  my $n = 1;
  if (-e glob("$PROMPDIR/*.txt")) {`rm '$PROMPDIR'/*.txt`;}
  if (! -e "$PROMPDIR") {`mkdir '$PROMPDIR'`;}
  while (@terms) {
    my @batch = splice(@terms, 0, $AI_PROMPT_LEN);
    my $path = $PROMPDIR . '/prompt_' . $n . '-' . ($n + @batch - 1) . ".txt";
    writePrompt($languageName, \@batch, $path);
    $n += @batch;
  }
} else {
  die "Could not open $LOG_sfm2osis.\n";
}

########################################################################
########################################################################

sub writePrompt {
  my $langName = shift;
  my $termAP = shift;
  my $outfile = shift;
  
  my $result = "I am working with a $langName Bible glossary.

Please classify the following glossary terms by parser collision risk
using these classes:

A - deterministic phrase (safe auto-link)
B - proper name (high confidence)
C - domain/technical term (moderate validation required)
D - generic lexical term (high ambiguity, full validation required)

For each term:

remove the link count that is in parenthesis following each term,

determine the best concise English gloss (1-5 words) never glossing a
compound until each morpheme is understood and always verifying against
the $langName language lexeme.

assign exactly one class (A-D),

output this as Excel-safe CSV with exactly four columns:
\"Tuvan term\",\"English gloss\",\"Class\",\"Link count\"

provide a copy button so I can copy the output as raw text


Rules:

one term per row,

no extra commentary,

no headings,

Here are the glossary terms:

" . join("\n", @{$termAP}) . "

End prompt.
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
