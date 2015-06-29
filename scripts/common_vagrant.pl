#!/usr/bin/perl
#
# Code here may be run on the host machine (rather than the Vagrant VM) and
# so should not use any non-standard Perl modules.

sub init_vagrant($) {
  $SCRIPT = shift;
  $SCRIPT =~ s/^.*[\\\/]([^\\\/]+)\.pl$/$1/;
  
  if (!$INPD) {$INPD = "."};
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  $INPD =~ s/[\\\/](sfm|GoBible|eBook)$//; # allow using a subdir as project dir
  if (!-e $INPD) {
    print "Project directory \"$INPD\" does not exist. Exiting.\n";
    exit;
  }
  
  if (-e "$SCRD/paths.pl") {require "$SCRD/paths.pl";}
  
  # run in Vagrant if $VAGRANT is set, or if opsys is not Linux
  if (($VAGRANT || "$^O" !~ /linux/i) && !-e "/home/vagrant") {
    if (!&vagrantInstalled()) {exit;}
    startVagrant($SCRD, $SCRIPT, $INPD);
    exit;
  }
}

sub vagrantInstalled() {
  print "\n";
  my $pass;
  system("vagrant -v >".&escfile_xplatform("tmp.txt"). " 2>&1");
  if (!open(TEST, "<tmp.txt")) {die;}
  $pass = 0; while (<TEST>) {if ($_ =~ /\QVagrant 1\E/i) {$pass = 1; last;}}
  if (!$pass) {
    print "Install Vagrant from https://www.vagrantup.com/downloads.html and install\n";
    print "Virtualbox from https://www.virtualbox.org/wiki/Downloads and try again.\n";
  }
  print "\n";
  unlink("tmp.txt");

  return $pass;
}

sub startVagrant($$$) {
  my $scrd = shift;
  my $script = shift;
  my $inpd = shift;
  my $cmd = &escfile_xplatform("$scrd/vagrant.pl")." $script.pl ".&escfile_xplatform($inpd);
  print "$cmd\n";
  exec($cmd);
  exit;
}

sub escfile_xplatform($) {
  my $n = shift;
  if ("$^O" =~ /MSWin32/i) {$n = "\"".$n."\"";}
  else {$n =~ s/([ \(\)])/\\$1/g;}
  return $n;
}

1;
