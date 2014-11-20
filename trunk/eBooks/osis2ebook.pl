#!/usr/bin/perl


# usage: osis2ebook.pl Directory Input_file Output_file_format [Book_type] [Cover_image]
#   Directory is the directory containing the input file and associated configuration and css files
#   Input_file is the name of the input file (this should include the .xml file extension)
#   Output_file_format is 'epub', 'fb2' etc.
#   Book_type should be 'B[ible]', 'C[ommentary] or G[enbook] - Bible is default and currently the only supported type
#   Cover_image is file path for cover image (relative to Directory)


# This script requires Calibre to be installed, with the osis-input plugin.
# It creates an epub or fb2 ebook from an osis.xml input file and config file convert.txt located in the specified directory.
# The css file, if present, must be in the same directory and named ebible.css when processing a Bible.
# The output file is created in the same directory and has the same name as the input file with the appropriate extension (.epub, .fb2)

use File::Spec;
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  if (-d $INPD) {
	chdir ($INPD);
  }
  else {
	print "Directory $INPD does not exist\n";
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

$OPTYPE = shift;
if ($OPTYPE) {
  # Form output file name by replacing file extension
  $OPF = $INPF;
  $OPF =~ s/\..*?$/\.$OPTYPE/;
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

# Start forming the command string
$COMMAND = "ebook-convert $INPF $OPF --config-file $CONFILE";

# Check if the CSS file exists
$CSSFILE = "e$IPTYPE.css";
if (-e $CSSFILE) {
  $CSSFILE = File::Spec->rel2abs($CSSFILE);
  $COMMAND .= " --css-file $CSSFILE";
}
else {
  print "WARNING: Proceding without CSS file as no file found\n"
}

# Check table of contents requirements
# Note - this currently only caters for Bibles
open(COMF, "<:encoding(UTF-8)", $CONFILE);
$foundgroup = 0;

foreach $line (<COMF>) {
  $line = lc $line;
  if ($line =~ /^group\d=/) {
    #Testament headings used
	$COMMAND .= " --level1-toc //h:h1 --level2-toc //h:h2 --level3-toc //*[\@chapter]/\@chapter";
	$foundgroup = 1;
	last;
  }
}
close(COMF);
if (!$foundgroup) {
  $COMMAND .= ' --level1-toc //h:h2 --level2-toc //*[@chapter]/@chapter';
}

# Add cover image if required
if ($COVER and $COVER ne "") {
  $COMMAND .= " --cover $COVER";
}

# Add options for FB2 output
if (lc $OPTYPE eq "fb2")
{
  $COMMAND .= ' --fb2 religion --sectionize toc --output-fmt fb2';
}

# Run conversion commmand
system $COMMAND;
1;


sub printUsage {
print "\nusage: osis2ebook.pl Directory Input_file Output_file_format [Book_type] [Cover image]\n";
print "   Directory is the directory containing the input file and associated configuration and css files\n";
print "   Input_file is the name of the input file (this should include the .xml file extension)\n";
print "   Output_file_format is 'epub', 'fb2' etc.\n";
print "   Book_type should be 'B[ible]', 'C[ommentary] or G[enbook] - Bible is default and currently the only supported type\n";
print "   Cover_image is file path for cover image (relative to Directory)\n";
}
