#!/usr/bin/perl

# usage: cbsfm2osis.pl ProjectDir [-l] File_path OsisConvertersDir [File_prefix]
#   Using -l means File_path is a file containing a list of SFM files to process in sequence
#   File_prefix is a prefix to be added to additional language specific picture file names 

use File::Spec;
$List = "";
$INPD = shift;
if ($INPD) {
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
}
else {
  print "Directory not specified. Exiting.\n";
  exit;
}

$INPF = shift;
if ($INPF eq "-l") {
  $List = "-l";
  $INPF = shift;
}

if ($INPF) {$INPF = File::Spec->rel2abs($INPF);}
else {
  print "File \"$INPF\" does not exist. Exiting.\n";
  exit;
}

$SCRD = shift;
if ($SCRD =~ /^\./) {$SCRD = File::Spec->rel2abs($SCRD);}

$CBD = File::Spec->rel2abs( __FILE__ );
# Remove file name
$CBD =~ s/[\\\/][^\\\/]+$//;

$PREFIX = shift;

require "$SCRD/scripts/common.pl";
&initPaths();

$CONFFILE = "$INPD/config.conf";
if (!-e $CONFFILE) {print "ERROR: Missing conf file: $CONFFILE. Exiting.\n"; exit;}
&getInfoFromConf($CONFFILE);

$OSISFILE = "$OUTDIR/".$MOD.".xml";
$LOGFILE = "$OUTDIR/OUT_sfm2osis.txt";

my $delete;
if (-e $OSISFILE) {$delete .= "$OSISFILE\n";}
if (-e $LOGFILE) {$delete .= "$LOGFILE\n";}
if ($delete) {
  print "\n\nARE YOU SURE YOU WANT TO DELETE:\n$delete? (Y/N):"; 
  $in = <>; 
  if ($in !~ /^\s*y\s*$/i) {exit;}
}
if (-e $OSISFILE) {unlink($OSISFILE);}
if (-e $LOGFILE) {unlink($LOGFILE);}

$TMPDIR = "$OUTDIR/tmp/src2osis";
if (-e $TMPDIR) {remove_tree($TMPDIR);}
make_path($TMPDIR);

if ($SWORDBIN && $SWORDBIN !~ /[\\\/]$/) {$SWORDBIN .= "/";}

&Log("\n-----------------------------------------------------\nSTARTING usfm2osis.pl\n\n");

# run preprocessor
&Log("\n--- PREPROCESSING USFM\n");
$OUTPUTFILE = "$TMPDIR/".$MOD."_1.sfm";
$AddFileOpt = ""; 
$ADDFILE = "$INPD/SFM_Add.txt";
if (-e $ADDFILE) {
  $AddFileOpt = "-a $ADDFILE" ;
}

$PPOUT = `$CBD/scripts/cbpreproc.py $AddFileOpt $List $INPF $OUTPUTFILE jpg $PREFIX`;

&Log($PPOUT);

# run main conversion script
&Log("\n--- CONVERTING PARATEXT TO OSIS\n");
$INPUTFILE = $OUTPUTFILE;
$OUTPUTFILE = "$TMPDIR/".$MOD."_1.xml";
$CONVOUT = `$SCRD/scripts/usfm2osis.py $MOD -o $OUTPUTFILE -r -g -x $INPUTFILE`;
&Log($CONVOUT);

# run postprocessor
&Log("\n--- POSTPROCESSING OSIS\n");
$INPUTFILE = $OUTPUTFILE;
$OUTPUTFILE = "$TMPDIR/".$MOD."_2.xml";

$PPOUT = `$CBD/scripts/cbpostproc.py $INPUTFILE $OUTPUTFILE`;

&Log($PPOUT);

# run addScripRefLinks.pl
$INPUTFILE = $OUTPUTFILE;
$OUTPUTFILE = $OSISFILE;
$COMMANDFILE = "$INPD/CF_addScripRefLinks.txt";
if (-e $COMMANDFILE) {
  &Log("\n--- ADDING SCRIPTURE REFERENCE LINKS\n");
  $NOCONSOLELOG = 1;
  require("$SCRD/scripts/addScripRefLinks.pl");
  $NOCONSOLELOG = 0;
}
else {
  &Log("Skipping Scripture reference parsing.\n");
  rename($INPUTFILE, $OSISFILE);
}

close(CONF);
1;
