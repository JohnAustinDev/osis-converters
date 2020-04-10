#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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

# usage: osis2GoBible.pl [Bible_Directory]

# Run this script to create GoBible mobile phone Bibles from an osis 
# file. The following input files need to be in a 
# "Bible_Directory/GoBible" sub-directory:
#    collections.txt            - build-control file
#    ui.properties              - user interface translation
#    icon.png                   - icon for the application
#    normalChars.txt (optional) - character replacement file
#    simpleChars.txt (optional) - simplified character replacement file

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# GoBible wiki: http://www.crosswire.org/wiki/Projects:Go_Bible

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();

%BookSizes;
$BookOverhead = 1000;
$JarOverhead = 40000;
$MaxTries = 10;

$GOBIBLE = "$INPD/GoBible";

&runAnyUserScriptsAt("GoBible/preprocess", \$INOSIS);

# Remove navigation menus
$INXML = $XML_PARSER->parse_file($INOSIS);
foreach my $e (@{$XPC->findnodes('//osis:list[@subType="x-navmenu"]', $INXML)}) {$e->unbindNode();}
&writeXMLFile($INXML, \$INOSIS);

&runScript($MODULETOOLS_BIN."osis2gobible.xsl", \$INOSIS);

&Log("\n--- Creating Go Bible osis.xml file...\n");
my $collectionsP = &getFullCollection($MAINMOD, &getScopeOSIS($INXML), &conf('Versification'));

my $bookOrderP; &getCanon(&conf("Versification"), NULL, \$bookOrderP, NULL);
my $scope = &getScopeOSIS($INXML);
$ScopeTotal = @{&scopeToBooks($scope, $bookOrderP)};

my %results;

# Make 'normal' character set
&makeGoBibles('normal', "$TMPDIR/normal", $collectionsP, $MaxTries, \%results);
&copyGoBibles("$TMPDIR/normal", $GBOUT);

my @a; push(@a, (sort keys %{$collectionsP}));
foreach my $k (@a) {$collectionsP->{$k.'_s'} = delete $collectionsP->{$k};}
#use Data::Dumper; &Log("type=$type\n".Dumper($collectionsP)."\n", 1);

# Make 'simple' character set, using the collections arrived at by 'normal'
&makeGoBibles('simple', "$TMPDIR/simple", $collectionsP, 0, \%results);
&copyGoBibles("$TMPDIR/simple", $GBOUT);

# Log results
my $colSizeP = &readJarFileSizes($GBOUT);
foreach my $type (sort keys %results) {
  my $numcols = 0; my $totalFull = 0; my $totalShort = 0; my @collist;
  foreach my $col (sort keys %{$results{$type}}) {
    $numcols++;
    if ($col !~ /(nt|ot)\d+/) {$totalFull += scalar @{$results{$type}{$col}};}
    else {$totalShort += scalar @{$results{$type}{$col}};}
    push(@collist, sprintf("%s (%i kb)", $col, $colSizeP->{$col}/1000));
  }
  if ($totalFull ne $ScopeTotal || ($totalShort && $totalShort ne $ScopeTotal)) {
    &Error("GoBible did not output $ScopeTotal books as excected from scope: $scope. ($totalFull book(s) in full JAR".($totalShort ? " and $totalShort in short JAR files":'').").", "See GoBible output logged above.");
  }
  &Report("Created $numcols $type GoBible jar files(s) containing a total of $totalFull book(s) in a full JAR file and $totalShort book(s) in short JAR files. (Scope also has $ScopeTotal books):\n".join(", ", @collist), 1);
}

&timer('stop');

########################################################################
########################################################################

sub makeGoBibles($$$$$) {
  my $type = shift;
  my $dir = shift;
  my $collectionsP = shift;
  my $resize = shift;
  my $resultsP = shift;
  
  my $colext = ($type eq 'simple' ? '_s':'');
  
  if ($type !~ /^(normal|simple)$/ || $dir !~ /\/$type$/) {
    &ErrorBug("makeGoBibles type must be 'normal' or 'simple': dir=$dir, type=$type");
    return;
  }
  
  &Log("\n--- Running Go Bible Creator, resize=$resize ($type)\n");
  if (-e $dir) {remove_tree($dir);}
  mkdir $dir;
  
  my $clt = &getDefaultFile('bible/GoBible/collections.txt', 1);
  if ($clt) {
    &Warn("A GoBible/collections.txt was found in input directory $MAININPD so it will now be deleted.",
"This file is now auto-generated internally by osis-converters.");
    unlink($clt);
  }
  
  # Gather and prepare GoBible input files
  copy(&getDefaultFile('bible/GoBible/icon.png'), "$dir/icon.png");
  if (-e "$dir/../collections.txt") {unlink "$dir/../collections.txt";}
  my $colfile = &writeCollectionsFile("$dir/../collections.txt", $collectionsP);
  if (-e "$dir/../osis.xml") {unlink "$dir/../osis.xml";}
  &copy($INOSIS, "$dir/../osis.xml");
  my @files = (&getDefaultFile("bible/GoBible/ui.properties"), "$dir/../collections.txt", "$dir/../osis.xml");
  &goBibleConvChars($type, \@files, $dir);
  if (-e $GO_BIBLE_CREATOR."GoBibleCore/ui.properties") {unlink $GO_BIBLE_CREATOR."GoBibleCore/ui.properties";}
  &copy("$dir/ui.properties", $GO_BIBLE_CREATOR."GoBibleCore/ui.properties");
  
  # Run GoBible Creator
  my $log = &shell("java -jar ".&escfile($GO_BIBLE_CREATOR."GoBibleCreator.jar")." ".&escfile("$dir/collections.txt"), 3);

  # Read, compare, and check size of resulting JAR files
  my $colSizeP = &readJarFileSizes($dir);
  my $colCalcP = (%BookSizes ? &calculateCollectionSizes($collectionsP, \%BookSizes):'');
  my $maxsize = 512000;
  my $needReRun = 0;
  foreach my $col (sort keys %{$colSizeP}) {
    if ($colSizeP->{$col} > $maxsize) {
      $needReRun++;
      if ($col =~ /(ot|nt)\d+$colext/) {
        &Note(sprintf("The small jar file $col is larger than 512kb (%i)", $colSizeP->{$col}/1000), 1);
      }
    }
    my $size = ($colSizeP->{$col}/1000);
    my $calc = ($colCalcP ? ($colCalcP->{$col}/1000):0);
    &Report(sprintf("$col actual-size=%i, calc-size=%i, err=%i\n", $size, $calc, (100*($calc/$size))));
  }

  # Check if another run is needed and prepare for it
  if ($needReRun) {
    if (scalar keys %{$collectionsP} == 1) { # on the first pass, there is always only 1 collection
      &calculateBookSizes("$dir/osis.xml", $colSizeP->{lc($MAINMOD).$colext}, \%BookSizes);
      &createCollectionsOTNT($collectionsP, $colext);
      $colSizeP = &calculateCollectionSizes($collectionsP, \%BookSizes);
    }
    elsif ($needReRun == 1) {$needReRun = 0;}
  }
   
  # Re-run GoBible if necessary/possible
  if ($needReRun) {
    if ($resize--) {
      &adjustCollectionSizes($collectionsP, $colSizeP, $colext, \%BookSizes, $maxsize);
      &Note("Re-running GoBible Creator (countdown=$resize)", 1);
      &makeGoBibles($type, $dir, $collectionsP, $resize, $resultsP);
      return;
    }
    &ErrorBug("At least one small JAR file is greater than 512kb; small jar files should be smaller than 512kb, but osis-converters failed to acheive this.");
  }
  
  &Log("\n$log\n$colfile\n");
  
  &checkGoBibleLog($log, $resultsP);
  return;
}

sub copyGoBibles($$) {
  my $dfrom = shift;
  my $dto = shift;
  
  &Log("\n--- Copying module to MKS directory $dto\n");
  if (!opendir(DIR, $dfrom)) {&ErrorBug("copyGoBibles could not open $dfrom for reading"); return;}
  my @f = readdir(DIR);
  closedir(DIR);
  for (my $i=0; $i < @f; $i++) {
    if ($f[$i] !~ /\.(jar|jad)$/i) {next;}
    copy("$dfrom/".$f[$i], "$dto/".$f[$i]);
  }
}

sub getFullCollection($$$) {
  my $modname = shift;
  my $scope = shift;
  my $v11n = shift;
  
  my %collections;
  
  my $bookOrderP; &getCanon($v11n, NULL, \$bookOrderP, NULL);
  $collections{lc($modname)} = &scopeToBooks($scope, $bookOrderP); 
  return \%collections;
}

sub writeCollectionsFile($$) {
  my $fdest = shift;
  my $collectionsP = shift;
  
  my $colfile;
  
  # Get localized book names from OSIS file
  my %localbk;
  foreach my $tocm ($XPC->findnodes('//osis:div[@type="book"]/descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $INXML)) {
    my $bk = @{$XPC->findnodes('ancestor::osis:div[@type="book"][1]', $tocm)}[0]->getAttribute('osisID');
    $localbk{$bk} = $tocm->getAttribute('n');
  }
  
  my $coltxt = &getDefaultFile("bible/GoBible/collections.txt");
  if (!open(INC, $READLAYER, $coltxt)) {
    &ErrorBug("writeCollectionsFile could not open $coltxt for reading.", 1);
  }
  
  # Write Book-Name-Map for all books in localbk and coltxt
  while (<INC>) {
    if ($_ =~ /^Book\-Name\-Map\:\s*(\S+)\s*,\s*(.*?)\s*$/) {
      my $bk = $1; my $name = $2;
      if ($localbk{$bk}) {
        $_ = "Book-Name-Map: $bk, ".$localbk{$bk}."\n";
        $localbk{$bk} = '';
      }
    }
    $colfile .= $_;
  }
  foreach my $bk (sort keys %localbk) {if ($localbk{$bk}) {$colfile .= "Book-Name-Map: $bk, ".$localbk{$bk}."\n";}}
  
  $colfile .= "Info: (".&conf('Version').") ".&conf('Description')."\n";
  $colfile .= "Application-Name: ".&conf('Abbreviation')."\n";
  
  # Write collections according to collectionsP
  foreach my $col (sort keys (%{$collectionsP})) {
    $colfile .= "\nCollection: $col\n";
    foreach my $bk (@{$collectionsP->{$col}}) {
      $colfile .= "Book: $bk\n";
    }
  }
  close(INC);
  
  if (!open (COLL, $WRITELAYER, $fdest)) {
    &ErrorBug("writeCollectionsFile could not open $fdest for writing.", 1);
  }
  print COLL $colfile;
  close(COLL);
  
#&Debug("writeCollectionsFile $fdest:\n".&shell("cat \"$fdest\"")."\n");
  return $colfile;
}

sub readJarFileSizes($) {
  my $dir = shift;
  
  if (!opendir(DIR, $dir)) {&ErrorBug("readJarFileSizes could not open $dir for reading"); return;}
  my @f = readdir(DIR);
  closedir(DIR);
  
  my %colSize;
  for (my $i=0; $i < @f; $i++) {
    if ($f[$i] !~ /^(.*?).jar$/i) {next;}
    my $col = $1;
    $colSize{$col} = (-s "$dir/".$f[$i]);
    #&Note("Actual size of $col is ".($colSize{$col}/1000)." kb\n");
  }
  
  return \%colSize;
}

sub calculateBookSizes($$$) {
  my $osis = shift;
  my $fullsize = shift;
  my $bookSizesP = shift;
  
  my $xml = $XML_PARSER->parse_file($osis);
  my %bookChars;
  my $totalChars = 0;
  my @books = $XPC->findnodes('//osis:div[@type="book"]', $xml);
  foreach my $bke (@books) {
    my $bk = $bke->getAttribute('osisID');
    $bookChars{$bk} = length($bke->textContent());
    $totalChars += $bookChars{$bk};
  }
  foreach my $bke (@books) {
    my $bk = $bke->getAttribute('osisID');
    $bookSizesP->{$bk} = int(($fullsize-$JarOverhead-($BookOverhead*@books)) * $bookChars{$bk}/$totalChars);
    &Note("Calculated size of $bk is ".$bookSizesP->{$bk}." kb\n");
  }
}

# Add to the full JAR file new OT and NT and JAR files
sub createCollectionsOTNT($$) {
  my $collectionsP = shift;
  my $colext = shift;
  
  my $ot1 = lc($MAINMOD).'ot1'.$colext;
  my $nt1 = lc($MAINMOD).'nt1'.$colext;
  
  if (exists($collectionsP->{$ot1})) {delete $collectionsP->{$ot1};}
  if (exists($collectionsP->{$nt1})) {delete $collectionsP->{$nt1};}
  
  my %cols;
  my $k;
  foreach my $b (@{$collectionsP->{lc($MAINMOD).$colext}}) {
    $k = ($NT_BOOKS =~ /\b$b\b/ ? $nt1:$ot1);
    $cols{$k}++;
    if (!exists($collectionsP->{$k})) {$collectionsP->{$k} = ();}
    push(@{$collectionsP->{$k}}, $b);
  }
}

# Read collectionsP and calculate the size of each collection based on 
# bookSizesP.
sub calculateCollectionSizes($$) {
  my $collectionsP = shift;
  my $bookSizesP = shift;
  
  my %colSize;
  foreach my $col (sort keys %{$collectionsP}) {
    $colSize{$col} = $JarOverhead;
    foreach my $bk (@{$collectionsP->{$col}}) {
      $colSize{$col} += $BookOverhead + $bookSizesP->{$bk};
    }
    #&Note("Calculated size of $col is ".($colSize{$col}/1000)." kb\n");
  }

  return \%colSize;
}

# Shift books in collectionsP collections so that no collection other 
# than the full-Bible collection, is larger than maxColSize.
sub adjustCollectionSizes($$$$) {
  my $collectionsP = shift;
  my $colSizeP = shift;
  my $colext = shift;
  my $bookSizesP = shift;
  my $maxColSize = shift;
  
  my $hasOversize;
  do {
    &shiftBookFromOversizedCollections($collectionsP, $colSizeP, $colext, $maxColSize);
    $colSizeP = &calculateCollectionSizes($collectionsP, $bookSizesP);
    $hasOversize = 0;
    foreach my $col (sort keys %{$colSizeP}) {
      if ($col eq lc($MAINMOD).$colext) {next;}
      if ($colSizeP->{$col} > $maxColSize) {$hasOversize++;}
    }
  } while ($hasOversize);
  my $note = "Adjusted collection sizes:\n";
  foreach my $col (sort keys %{$collectionsP}) {
    $note .= sprintf("%-10s (calc size:%4i kb) %s\n", $col, ($colSizeP->{$col}/1000), join(' ', @{$collectionsP->{$col}}));
  }
  &Note($note, 2);
}

# Move a book from each over-sized collection to the next collection
sub shiftBookFromOversizedCollections($$$$) {
  my $collectionsP = shift;
  my $colSizeP = shift;
  my $colext = shift;
  my $maxColSize = shift;

  foreach my $col (sort keys %{$collectionsP}) {
    if ($col eq lc($MAINMOD).$colext) {next;}
    if ($colSizeP->{$col} <= $maxColSize) {next;}
    if ($col !~ /(ot|nt)(\d+)$colext$/) {&ErrorBug("($col !~ /((ot\\d+|nt\\d+)?)$colext\$/)", 1);}
    my $n = $2;
    my $bk = pop(@{$collectionsP->{$col}});
    my $k = lc($MAINMOD).($NT_BOOKS =~ /\b$bk\b/ ? 'nt':'ot').($n+1).$colext;
    if (!exists($collectionsP->{$k})) {$collectionsP->{$k} = ();}
    unshift(@{$collectionsP->{$k}}, $bk);
  }
}

# Returns 0 on all-good, 1 on problem
sub checkGoBibleLog($$) {
  my $log = shift;
  my $resultsP = shift;
  
  while ($log =~ s/^Writing Collection (\S+)\s*\:\s*\n([^\n]*), \d+ book\(s\) written\.//m) {
    my $col = $1; my $bks = $2; my $sn = ($col =~ /_s$/ ? 'simple':'normal');
    my @a; push(@a, split(/\s*,\s*/, $bks));
    $resultsP->{$sn}{$col} = \@a;
  }
  
  return $resultsP; 
}

sub goBibleConvChars($$$) {
  my $type = shift;
  my $aP = shift;
  my $destdir = shift;
  
  &Log("\n--- Converting characters ($type)\n");
  
  my @FROM, my @TO;
  &readReplacementChars(&getDefaultFile("bible/GoBible/".$type."Chars.txt"), \@FROM, \@TO);
  
  &Log("Converting the following chars:\n");
  for ($i=0; $i<@{@FROM}; $i++) {&Log(@{$FROM}[$i]."<>".@{$TO}[$i]."\n");}

  &Log("Converting chars in following files:\n");
  make_path($destdir);

  my %highUnicode;
  foreach my $file (@$aP) {
    open(INF, $READLAYER, $file) || die "Could not open $file.\n";
    $leaf = $file;
    $leaf =~ s/^.*?([^\\\/]+)$/$1/;
    open(OUTF, $WRITELAYER, "$destdir/$leaf") || die "Could not open $destdir/$leaf.\n";

    &Log("$file\n");
    $line = 0;
    while(<INF>) {
      $line++;
      
      # Replace some Unicode chars which might cause problems on some phones
      $c = fromUTF8("…");
      $_ =~ s/$c/\.\.\./g;
      $c = fromUTF8("­"); # remove optional hyphens!
      $_ =~ s/$c//g;
      
      # Replace
      for ($i=0; $i<@FROM; $i++) {
        $r = @FROM[$i];
        $s = @TO[$i];
        $_ =~ s/\Q$r\E/$s/g; # simplify the character set      
      }
      
      WriteGB($_, $file, $line, \%highUnicode);
    }
    close(OUTF);
    close(INF);
  }
  &Log("\n");

  # Log whether any high Unicode chars
  &Log("Listing $type unicode chars higher than $MAX_UNICODE:\n");
  $error = "false";
  foreach $key (sort keys %highUnicode) {
    if ($type eq "simple") {$error = "true"; &Log(" ".$key."(".ord($key).") :".$highUnicode{$key}."\n");}
    else {&Log($key." ");}
  }
  if ($type eq "simple") {
    if ($error eq "false") {&Log("Good! No such chars were found.\n");}
    else {&Error("The high code point Unicode chars above were found.",
"You need to add these characters to the GoBible/simpleChars.txt
file, and map them to lower order Unicode characters (below $MAX_UNICODE) 
which look as similar as possible to the original character. Then these 
characters will be replaced when building the 'simple' apps, and will 
not appear as boxes on feature phones.");}
  }
  else {&Log("\n");}
  &Log("\n");
  
  return join(' ', (sort keys %highUnicode));
}

sub WriteGB($$$\%) {
  my $print = shift;
  my $f = shift;
  my $l = shift;
  my $highUnicodeP = shift;
  
  $f =~ s/^.*?([^\/]+)$/$1/;
  for ($i=0; substr($print, $i, 1); $i++) {
    my $c = substr($print, $i, 1);
    if (ord($c) > $MAX_UNICODE) {$highUnicodeP->{$c} = $highUnicodeP->{$c}.$f.":".$l.":".$i." ";}
  }
  print OUTF $print;
}

1;
