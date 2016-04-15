#!/usr/bin/perl
#
# Code here may be run on the host machine (rather than the Vagrant VM) and
# so should not use any non-standard Perl modules.

$VAGRANT = 1; # Vagrant is on by default. To run natively, add "$Vagrant=0;" to paths.pl

sub init_vagrant() {
  if (!$INPD) {$INPD = "."};
  $INPD =~ s/[\\\/]\s*$//;
  if ($INPD =~ /^\./) {$INPD = File::Spec->rel2abs($INPD);}
  $INPD =~ s/[\\\/](sfm|GoBible|eBook)$//; # allow using a subdir as project dir
  if (!-e $INPD) {
    print "Project directory \"$INPD\" does not exist. Exiting.\n";
    exit;
  }
  chdir($INPD);
  
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
  system("vagrant -v >tmp.txt 2>&1");
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
  my @args = ("$scrd/vagrant.pl", $script, $inpd);
  print "@args\n";
  system(@args); # exec does not run with Windows cmd shell
  exit;
}

1;
