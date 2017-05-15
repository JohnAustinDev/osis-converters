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
# It creates an epub or fb2 ebook from an osis.xml input file and config file convert.txt located in the specified directory.
# The css file, if present, must be in the same directory and named ebible.css when processing a Bible.
# The output file is created in the same directory and has the same name as the input file with the appropriate extension (.epub, .fb2)


$INPD = shift; $LOGFILE = shift;
use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){2}$//;
require "$SCRD/scripts/common_vagrant.pl"; &init_vagrant();
require "$SCRD/scripts/common.pl"; &init(1);

use File::Spec;
$RUNDIR = shift;
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

$INPF = shift;
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

# Get directory of perl file
$CBD = File::Spec->rel2abs( __FILE__ );
$CBD =~ s/[\\\/][^\\\/]+$//;

$OPTYPE = shift;
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

$IPTYPE = shift;

if ($IPTYPE){
  $typetmp = ucfirst($IPTYPE);
  $tletter = substr($typetmp, 0, 1);
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

$COVER = shift;
if ($COVER) {
  if (-e $COVER) {
    $COVER = File::Spec->rel2abs($COVER);
  }
  else {
   print "Cover image file $COVER does not exist - ignoring\n";
   $COVER = ""
  }
}

# Check that config file exists
if (-e "convert.txt") {
  $CONFILE = File::Spec->rel2abs("convert.txt");
}
else {
 print "Config file convert.txt missing\n";
 exit;
}

# Note: EPUB only: --preserve-cover-aspect-ratio
$COMMAND = "ebook-convert ".&escfile($INPF)." ".&escfile($OPF)." --config-file ".&escfile($CONFILE)." --output-fmt $OPTYPE --preserve-cover-aspect-ratio --max-toc-links 0 --chapter \"/\" --chapter-mark none --page-breaks-before \"/\" ";
# Start forming the command string

# Check if the CSS file exists
$CSSFILE = "e$IPTYPE.css";
if (! -e $CSSFILE) {$CSSFILE = "./css/e$IPTYPE.css";}
if (-e $CSSFILE) {
  $CSSFILE = File::Spec->rel2abs($CSSFILE);
  $COMMAND .= " --css-file ".&escfile($CSSFILE)." ";
}
else {
  print "WARNING: Proceding without CSS file as no file found\n"
}

$COMMAND .= '--level1-toc "//*[@toclevel=\'1\']" --level2-toc "//*[@toclevel=\'2\']" --level3-toc "//*[@toclevel=\'3\']"';

# Add cover image if required
if ($COVER and $COVER ne "") {
  $COMMAND .= " --cover ".&escfile($COVER);
}

# Add options for FB2 output
if (lc $OPTYPE eq "fb2")
{
  $COMMAND .= ' --fb2 religion --sectionize toc';
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

# Perform post-processing for FB2
if (lc $OPTYPE eq "fb2")
{
  # Create temporary file name
  $TEMPF = $OPF;
  $TEMPF =~ s/\.[^\.]*$/1./;
  
  # Rename output file to temp file and pre-process to give new output file
  rename $OPF, $TEMPF;
  $COMMAND = "$CBD/scripts/fb2postproc.py ".&escfile($TEMPF)." ".&escfile($OPF)." ".&escfile($CSSFILE);
  print "$COMMAND\n";
  &Log("$COMMAND\n");
  system $COMMAND;
  unlink $TEMPF;
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
