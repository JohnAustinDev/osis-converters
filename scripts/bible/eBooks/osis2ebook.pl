#!/usr/bin/perl

# usage: osis2ebook.pl ProjectDirectory LogFile Directory Input_file Output_file_format [Book_type] [Cover_image]
#   ProjectDirectory is the path to the osis-converters project directory
#   LogFile is the path to the osis-converters log file
#   Directory is the directory containing the input file and associated configuration and css files
#   Input_file is the name of the input file (this should include the .xml file extension)
#   Output_file_format is 'epub', 'fb2' etc.
#   Book_type should be 'B[ible]', 'C[ommentary] or G[enbook] - Bible is default and currently the only supported type
#   Cover_image is file path for cover image (relative to Directory)

# This script requires Calibre to be installed, with the osis-input plugin.
# It creates an epub or fb2 ebook from an osis.xml input file.
# The css file, if present, must be in the same directory and named ebible.css when processing a Bible.
# The output file is created in the same directory and has the same name as the input file with the appropriate extension (.epub, .fb2)

my $RUNDIR  = @ARGV[2];
my $INPF    = @ARGV[3];
my $OPTYPE  = @ARGV[4];
my $IPTYPE  = @ARGV[5];
my $COVER   = @ARGV[6];

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){4}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();

our ($WRITELAYER, $APPENDLAYER, $READLAYER);
our ($SCRD, $MOD, $INPD, $MAINMOD, $MAININPD, $DICTMOD, $DICTINPD, 
    $TMPDIR, $DEBUG, $XML_PARSER, $XPC);

my ($OPF);

if ($RUNDIR) {
  $RUNDIR =~ s/[\\\/]\s*$//;
  if ($RUNDIR =~ /^\./) {$RUNDIR = File::Spec->rel2abs($INPD);}
  if (-d $RUNDIR) {
	chdir ($RUNDIR);
  }
  else {
	print "Directory $RUNDIR does not exist\n";
	exit;
  }
}
else {
  print "Directory not specified\n";
  &printUsage();
  exit;
}

if ($INPF) {
  if (-e $INPF) {
	chdir($INPF);
  }
  else {
	print "Input file $INPF does not exist\n";
	exit;
  }
}
else {
  print "Input file not specified\n";
  &printUsage();
  exit;
}
print "Input file is $INPF\n";

if ($OPTYPE) {
  # Form output file name by replacing file extension
  $OPF = $INPF;
  $OPF =~ s/\.[^\.]+$/\.$OPTYPE/;
  print "Output file is $OPF\n";
}
else {
  print "Ouput file format not specified\n";
  &printUsage();
  exit;
}

if ($IPTYPE){
  my $typetmp = ucfirst($IPTYPE);
  my $tletter = substr($typetmp, 0, 1);
  if ($tletter eq "B") {
    $IPTYPE = "bible"
  }
  elsif ($tletter eq "C") {
    print "Commentry conversion is not currently supported\n";
	exit;
  }
  elsif ($tletter eq "G") {
    print "Genbook conversion is not currently supported\n";
	exit;
  }
  else {
    print "Unrecognised book type\n";
	&printUsage();
	exit;
  }
} else {
  $IPTYPE = "bible"
}

if ($COVER) {
  if (-e $COVER) {
    $COVER = File::Spec->rel2abs($COVER);
  }
  else {
   print "Cover image file $COVER does not exist - ignoring\n";
   $COVER = ""
  }
}

my $xml = $XML_PARSER->parse_file($INPF);

# Start forming the command string
my $COMMAND = "ebook-convert".
  ' '. &escfile($INPF).
  ' '. &escfile($OPF).
  ' --max-toc-links 0'.
  ' --chapter "/"'.
  ' --chapter-mark none'.
  ' --page-breaks-before "/"'.
  ' --keep-ligatures'.
  ' --disable-font-rescaling'.
  ' --minimum-line-height 0'.
  ' --subset-embedded-fonts'.
  ' --level1-toc "//*[@title=\'toclevel-1\']"'.
  ' --level2-toc "//*[@title=\'toclevel-2\']"'.
  ' --level3-toc "//*[@title=\'toclevel-3\']"'.
  ' --publisher "'.@{$XPC->findnodes('//osis:publisher[@type="x-CopyrightHolder"][not(@xml:lang)][1]', $xml)}[0]->textContent.'"';

# Add cover image if required
if ($COVER and $COVER ne "") {
  $COMMAND .= " --cover ".&escfile($COVER);
}

# Add options for specific output formats
if (lc $OPTYPE eq "fb2")
{
  $COMMAND .= ' --fb2 religion --sectionize files';
}
elsif (lc $OPTYPE eq "epub") {
  $COMMAND .= " --output-profile tablet --preserve-cover-aspect-ratio --dont-split-on-page-breaks"; #--flow-size 0
}

# Debug keeps eBook intermediate files
if ($DEBUG)
{
  $COMMAND .= ' --debug-pipeline='.&escfile("$RUNDIR/debug");
}

# Run conversion command
print "$COMMAND\n";
&Log("$COMMAND\n");
system $COMMAND;

if (lc $OPTYPE eq "fb2") {
  my $cmd = "zip ".&escfile("$OPF.zip")." ".&escfile($OPF);
  print "$cmd\n";
  &Log("$cmd\n");
  system $cmd; 
}

1;


sub printUsage {
print "\nusage: osis2ebook.pl Directory Input_file Output_file_format [Book_type] [Cover image]\n";
print "   Directory is the directory containing the input file and associated configuration and css files\n";
print "   Input_file is the name of the input file (this should include the .xml file extension)\n";
print "   Output_file_format is 'epub', 'fb2' etc.\n";
print "   Book_type should be 'B[ible]', 'C[ommentary] or G[enbook] - Bible is default and currently the only supported type\n";
print "   Cover_image is file path for cover image (relative to Directory)\n";
}
