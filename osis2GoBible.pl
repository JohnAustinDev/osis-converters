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

use File::Spec; $SCRIPT = File::Spec->rel2abs(__FILE__); $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";

$maxUnicode = 1103; # Default value: highest Russian Cyrillic Uncode code point
$averageBookSize = 28000;

$GOBIBLE = "$INPD/GoBible";

&runAnyUserScriptsAt("GoBible/preprocess", \$INOSIS);

$INXML = $XML_PARSER->parse_file($INOSIS);
foreach my $e (@{$XPC->findnodes('//osis:list[@subType="x-navmenu"]', $INXML)}) {$e->unbindNode();}
$output = $INOSIS; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1removeNavMenu$3/;
&writeXMLFile($INXML, $output, \$INOSIS);

&runScript($MODULETOOLS_BIN."osis2gobible.xsl", \$INOSIS);

&Log("\n--- Creating Go Bible osis.xml file...\n");
my $collectionsP = &getInitialCollection($MAINMOD, &getScopeOSIS($INXML), &conf('Versification'));

my %results;
my @types = ('normal', 'simple');
foreach my $type (@types) {
  if ($type eq 'simple') {
    my @a; push(@a, (keys %{$collectionsP}));
    foreach my $k (@a) {$collectionsP->{$k.'_s'} = delete $collectionsP->{$k};}
  }
#use Data::Dumper; &Log("type=$type\n".Dumper($collectionsP)."\n", 1);
  &makeGoBible($type, "$TMPDIR/$type", $collectionsP, ($type eq 'normal' ? 5:0), \%results);
}

# Log the results
my $bookOrderP; &getCanon(&conf("Versification"), NULL, \$bookOrderP, NULL);
my $scope = &getScopeOSIS($INXML);
my $scopeTotal = @{&scopeToBooks($scope, $bookOrderP)};
foreach my $type (sort keys %results) {
  my $numcols; my $total; my $collist;
  foreach my $col (sort keys %{$results{$type}}) {
    $numcols++;
    $total += scalar @{$results{$type}{$col}};
    $collist .= sprintf("%-10s = %s\n", $col, join(' ', @{$results{$type}{$col}}));
  }
  if ($total ne $scopeTotal) {
    &Error("GoBible did not output $scopeTotal books as excected from scope: $scope. ($total book(s) were output).", "See GoBible output logged above.");
  }
  &Report(
"Created $numcols $type GoBible jar files(s) containing 
a total of $total book(s). (Scope has $scopeTotal books):\n$collist", 1);
}

&timer('stop');

########################################################################
########################################################################

sub makeGoBible($$$$$) {
  my $type = shift;
  my $dir = shift;
  my $collectionsP = shift;
  my $resize = shift;
  my $resultsP = shift;
  
  if ($type !~ /^(normal|simple)$/ || $dir !~ /\/$type$/) {
    &ErrorBug("makeGoBible type must be 'normal' or 'simple': dir=$dir, type=$type");
    return;
  }
  
  &Log("\n--- Running Go Bible Creator, resize=$resize ($type)\n");
  if (-e $dir) {remove_tree($dir);}
  mkdir $dir;
  
  copy(&getDefaultFile('bible/GoBible/icon.png'), "$dir/icon.png");
  if (-e "$dir/../collections.txt") {unlink "$dir/../collections.txt";}
  &writeCollectionsFile("$dir/../collections.txt", $collectionsP);
  if (-e "$dir/../osis.xml") {unlink "$dir/../osis.xml";}
  &copy($INOSIS, "$dir/../osis.xml");
  @FILES = (&getDefaultFile("bible/GoBible/ui.properties"), "$dir/../collections.txt", "$dir/../osis.xml");
  &goBibleConvChars($type, \@FILES, $dir);
  if (-e $GO_BIBLE_CREATOR."GoBibleCore/ui.properties") {unlink $GO_BIBLE_CREATOR."GoBibleCore/ui.properties";}
  &copy("$dir/ui.properties", $GO_BIBLE_CREATOR."GoBibleCore/ui.properties");
  my $log = &shell("java -jar ".&escfile($GO_BIBLE_CREATOR."GoBibleCreator.jar")." ".&escfile("$dir/collections.txt"));

  chdir($dir);
  if (!opendir(DIR, "./")) {&ErrorBug("makeGoBible could not open $dir for reading"); return;}
  my @f = readdir(DIR);
  closedir(DIR);
  
  my %tooBig;
  for (my $i=0; $i < @f; $i++) {
    if ($f[$i] !~ /^(.*?).jar$/i) {next;}
    my $col = $1;
    my $size = (-s "$dir/".$f[$i]);
    if ($size > 512000) {
      if ($col =~ /(ot|nt)\d+(_s)?/) {&Note("The small jar file ".$f[$i]." is larger than 512kb ($size)");}
      $tooBig{$col} = $size;
    }
  }
  if (scalar keys %tooBig > 1) {
    if (exists($tooBig{lc($MAINMOD)})) {delete($tooBig{lc($MAINMOD)});}
    elsif (exists($tooBig{lc($MAINMOD)."_s"})) {delete($tooBig{lc($MAINMOD)."_s"});}
  }
  if (scalar keys %tooBig) {
    if ($resize--) {
      &adjustCollectionSizes($collectionsP, \%tooBig);
      &makeGoBible($type, $dir, $collectionsP, $resize, $resultsP);
      return;
    }
    &ErrorBug("At least one small JAR file is greater than 512kb.", "Small jar files should be smaller than 512kb, but osis-converters failed to acheive this.");
  }
  &Log("\n$log\n");
  
  &Log("\n--- Copying module to MKS directory $MOD".&conf("Version")."\n");
  for (my $i=0; $i < @f; $i++) {
    if ($f[$i] !~ /\.(jar|jad)$/i) {next;}
    copy("$dir/".$f[$i], "$GBOUT/".$f[$i]);
  }
  chdir($SCRD);
  
  &checkGoBibleLog($log, $resultsP);
  return;
}

sub getInitialCollection($$$) {
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
  
  # Get localized book names from OSIS file
  my %localbk;
  foreach my $tocm ($XPC->findnodes('//osis:div[@type="book"]/descendant::osis:milestone[@type="x-usfm-toc'.&conf('TOC').'"][1]', $INXML)) {
    my $bk = @{$XPC->findnodes('ancestor::osis:div[@type="book"][1]', $tocm)}[0]->getAttribute('osisID');
    $localbk{$bk} = $tocm->getAttribute('n');
  }
  
  my $coltxt = &getDefaultFile("bible/GoBible/collections.txt");
  if (!open(INC, "<:encoding(UTF-8)", $coltxt)) {
    &ErrorBug("writeCollectionsFile could not open $coltxt for reading.", '', 1);
  }
  if (!open (COLL, ">:encoding(UTF-8)", $fdest)) {
    &ErrorBug("writeCollectionsFile could not open $fdest for writing.", '', 1);
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
    print COLL $_;
  }
  foreach my $bk (keys %localbk) {if ($localbk{$bk}) {print COLL "Book-Name-Map: $bk, ".$localbk{$bk}."\n";}}
  
  print COLL "Info: (".&conf('Version').") ".&conf('Description')."\n";
  print COLL "Application-Name: ".&conf('Abbreviation')."\n";
  
  # Write collections according to collectionsP
  foreach my $col (sort keys (%{$collectionsP})) {
    print COLL "\nCollection: $col\n";
    foreach my $bk (@{$collectionsP->{$col}}) {
      print COLL "Book: $bk\n";
    }
  }
  close(COLL);
  close(INC);
  
#&Debug("writeCollectionsFile $fdest:\n".&shell("cat \"$fdest\"")."\n");
}

sub adjustCollectionSizes($$) {
  my $collectionsP = shift;
  my $tooBigP = shift;
  
  my $mod; my $simple;
  foreach my $k (keys %{$collectionsP}) {
    if ($k =~ /^(.*?)(nt|ot)?\d*(_s)?$/) {$mod = $1; $simple = $3;}
    last;
  }
  
  # One key means full Bible is too big, so split into ot and nt, first
  my %cols;
  if (scalar keys %{$collectionsP} == 1) {
    my $k; my $c;
    foreach $c (keys %{$collectionsP}) {
      foreach my $b (@{$collectionsP->{$c}}) {
        $k = $mod.(NT_BOOKS =~ /\b$b\b/ ? 'nt':'ot').'1'.$simple;
        $cols{$k}++;
        if (!exists($collectionsP->{$k})) {$collectionsP->{$k} = ();}
        push(@{$collectionsP->{$k}}, $b);
      }
      last; # yes, collectionsP started with 1 key, but may have more by now
    }
    if (scalar keys %cols == 2) {return;} # since books were split between testaments, maybe we're ok now
    $tooBigP->{$k} = delete($tooBigP->{$c}); # so that next steps will effect new collection rather than full one
  }
  
  # Push x books from each tooBig collection to the next collection
  foreach my $col (keys %{$tooBigP}) {
    my $bigsize = $tooBigP->{$col};
    my $nmove =  printf("%.0f", ($bigsize - 512000)/$averageBookSize);
    $col =~ /((ot\d+|nt\d+)?)((_s)?)/;
    my $n = $1; my $s = $3;
    $n =~ s/(ot|nt)//;
    if (!$n) {$n = 1;} else {$n++;}
    if ($s ne $simple) {&ErrorBug("adjustCollectionSizes type mismatch: '$s' != '$simple'");}
    my $lastX = $#{$collectionsP->{$col}};
    for (my $x=$lastX; $x>($lastX-$nmove); $x--) {
      my $bk = pop(@{$collectionsP->{$col}});
      my $k = $mod.(NT_BOOKS =~ /\b$bk\b/ ? 'nt':'ot').$n.$simple;
      if (!exists($collectionsP->{$k})) {$collectionsP->{$k} = ();}
      unshift(@{$collectionsP->{$k}}, $bk);
    }
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
  
  undef(%highUnicode);
  my @FROM,
  my @TO;
 
  if (open(INF, "<:encoding(UTF-8)", &getDefaultFile("bible/GoBible/".$type."Chars.txt"))) {
    while(<INF>) {
      if ($_ =~ /Replace-these-chars:\s*(.*?)\s*$/) {
        $CHARS = $1;
        for ($i=0; substr($CHARS, $i, 1); $i++) {
          push(@FROM, substr($CHARS, $i, 1));
        }
      }
      if ($_ =~ /With-these-chars:\s*(.*?)\s*$/) {
        $CHARS = $1;
        for ($i=0; substr($CHARS, $i, 1); $i++) {
          push(@TO, substr($CHARS, $i, 1));
        }
      }
      if ($_ =~ /Replace-this-group:\s*(.*?)\s*$/) {
        $CHARS = $1;
        push(@FROM, $CHARS);
      }
      if ($_ =~ /With-this-group:\s*(.*?)\s*$/) {
        $CHARS = $1;
        push(@TO, $CHARS);
      }
      if ($_ =~ /Max-Unicode-Code-Point:\s*(\d+)\s*$/) {$maxUnicode = ($1*1);}
    }
    close(INF);

    &Log("Converting the following chars:\n");
    for ($i=0; $i<@FROM; $i++) {&Log(@FROM[$i]."<>".@TO[$i]."\n");}
  }

  &Log("Converting chars in following files:\n");
  make_path($destdir);

  foreach my $file (@$aP) {
    open(INF, "<:encoding(UTF-8)", $file) || die "Could not open $file.\n";
    $leaf = $file;
    $leaf =~ s/^.*?([^\\\/]+)$/$1/;
    open(OUTF, ">:encoding(UTF-8)", "$destdir/$leaf") || die "Could not open $destdir/$leaf.\n";

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
      
      WriteGB($_, $file, $line);
    }
    close(OUTF);
    close(INF);
  }
  &Log("\n");

  # Log whether any high Unicode chars
  &Log("Listing $type unicode chars higher than $maxUnicode:\n");
  $error = "false";
  foreach $key (keys %highUnicode) {
    if ($type eq "simple") {$error = "true"; &Log(" ".$key." :".$highUnicode{$key}."\n");}
    else {&Log($key." ");}
  }
  if ($type eq "simple") {
    if ($error eq "false") {&Log("Good! No such chars were found.\n");}
    else {&Error("The high code point Unicode chars above were found.",
"You need to add these characters to the GoBible/simpleChars.txt
file, and map them to lower order Unicode characters (below $maxUnicode) 
which look as similar as possible to the original character. Then these 
characters will be replaced when building the 'simple' apps, and will 
not appear as boxes on feature phones.");}
  }
  else {&Log("\n");}
  &Log("\n");
  
  return join(' ', (sort keys %highUnicode));
}

sub WriteGB($$$) {
  my $print = shift;
  my $f = shift;
  my $l = shift;
  $f =~ s/^.*?([^\/]+)$/$1/;
  for ($i=0; substr($print, $i, 1); $i++) {
    my $c = substr($print, $i, 1);
    if (ord($c) > $maxUnicode) {$highUnicode{$c} = $highUnicode{$c}.$f.":".$l.":".$i." ";}
  }
  print OUTF $print;
}

1;
