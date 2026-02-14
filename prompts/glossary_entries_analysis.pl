#!/usr/bin/perl

use strict;

my $languageName = shift;
my $DIR_LOG_sfm2osis = shift || '.';

if (!$languageName || !$DIR_LOG_sfm2osis) {
  die "Usage glossary_entries_analysis.pl languageName /path/to/oc-log-directory\n";
}

my $LOG_sfm2osis = "$DIR_LOG_sfm2osis/LOG_sfm2osis.txt";

if (open(INF, "<:encoding(UTF-8)", "$LOG_sfm2osis")) {
  my @entries;
  while (<INF>) {
    if (/^\s+(\d+)\s+links to \w+DICT:(.*?)\s+as\s+/) {
      push(@entries, "$2 ($1)");
    }
  }
  my $n = 1;
  while (@entries) {
    my @batch = splice(@entries, 0, 50);
    my $filename = "ge_prompt_$n-" . ($n + @batch - 1) . ".txt";
    writePrompt($languageName, \@batch, $filename);
    $n += @batch;
  }
} else {
  die "Could not open $LOG_sfm2osis.\n";
}

sub writePrompt {
  my $langName = shift;
  my $entryAP = shift;
  my $outfile = shift;
  
  my $result = "I am working with a $langName Bible glossary.

Please classify the following glossary entries by parser collision risk using these classes:

A - deterministic phrase (safe auto-link)
B - proper name (high confidence)
C - domain/technical term (moderate validation)
D - generic lexical term (high ambiguity)

For each entry:

remove the link count that is in parenthesis following each entry,

determine the best concise English gloss (1-5 words) and never gloss a compound until each morpheme is understood.

assign exactly one class (A-D),

output this as Excel-safe CSV with exactly four columns:
\"Tuvan entry\",\"English gloss\",\"Class\",\"Link count\"

provide a copy button so I can copy the output as raw text


Rules:

one entry per row,

no extra commentary,

no headings,

Here are the entries:

" . join("\n", @{$entryAP}) . "

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
