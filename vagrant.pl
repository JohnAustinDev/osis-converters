#!/usr/bin/perl
# usage: vagrant.pl script input_directory
#
# The purpose of this script is to set the required file shares between
# host and vagrant client, and to call osis-converters on the client.

use File::Spec;
use Encode;

$Script = File::Spec->rel2abs(shift); $Script =~ s/\\/\//g;
$ProjectDir = File::Spec->rel2abs(shift); $ProjectDir =~ s/\\/\//g;
$VAGRANT_HOME = '/home/ubuntu';

# ProjectDir must be relative to INDIR_ROOT
# INDIR_ROOT cannot be just a Windows drive letter (native|emulated).
# Vagrant cannot create a share to the root of a window's drive.
if ($ProjectDir !~ s/^((?:\w\:|\/\w)?\/[^\/]+)(.*?)$/$2/) {
  die "\nERROR: Cannot parse project path \"$ProjectDir\"\n";
}
$INDIR_ROOT = $1;

$SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/\\/\//g; $SCRD =~ s/(\/[^\/]+){1}$//;
chdir $SCRD;
if (-e "./paths.pl") {require "./paths.pl";}

push(@Shares, &vagrantShare($INDIR_ROOT, "INDIR_ROOT"));
if ($OUTDIR) {push(@Shares, &vagrantShare($OUTDIR, "OUTDIR"));}
if ($MODULETOOLS_BIN) {push(@Shares, &vagrantShare($MODULETOOLS_BIN, ".osis-converters/src/Module-tools/bin"));}

$Status = (-e "./.vagrant" ? &shell("vagrant status", 1):'');
if ($Status !~ /\Qrunning (virtualbox)\E/i) {&vagrantUp(\@Shares);}
elsif (&rebuildNeeded(\@Shares)) {&shell("vagrant destroy -f"); &vagrantUp(\@Shares);}
elsif (!&matchingShares(\@Shares)) {&shell("vagrant halt"); &vagrantUp(\@Shares);}

my $script_rel = File::Spec->abs2rel($Script, $SCRD);
$cmd = "vagrant ssh -c \"cd /vagrant && ./$script_rel $VAGRANT_HOME/INDIR_ROOT$ProjectDir\"";
print "\nStarting Vagrant...\n$cmd\n";
open(VUP, "$cmd |");
while(<VUP>) {print $_;}
close(VUP);

########################################################################

sub vagrantShare($$) {
  my $host = shift;
  my $client = shift;
  # If the host is Windows, $host must be a native path!
  $host =~ s/^((\w)\:|\/(\w))\//uc($+).":\/"/e;
  $host =~ s/\\/\\\\/g; $client =~ s/\\/\\\\/g; # escape "\"s for use as Vagrantfile quoted strings
  return "config.vm.synced_folder \"$host\", \"$VAGRANT_HOME/$client\"";
}

sub vagrantUp(\@) {
  my $sharesP = shift;
  
  # Create input/output filesystem shares
  open(TPL, "<./Vagrantfile_tpl") || die "\nERROR: Cannot open \"./Vagrantfile_tpl\"\n";
  open(VAG, ">./Vagrantfile") || die "\nERROR: Cannot open \"./Vagrantfile\"\n";
  if (!-e "./.vagrant") {&shell("mkdir ./.vagrant");}
  while (<TPL>) {
    print VAG $_;
    if ($_ =~ /\Q"VagrantProvision.sh"\E/) {foreach my $share (@$sharesP) {print VAG "$share\n";}}
  }
  close(VAG);
  close(TPL);
  print "
Starting Vagrant...
The first use of Vagrant will automatically download and build a virtual
machine having osis-converters fully installed. This build will take some
time. Subsequent use of Vagrant will run much faster.\n\n";
  open(VUP, "vagrant up |");
  while(<VUP>) {print $_;}
  close(VUP);
}

# returns 1 if all shares match, 0 otherwise
sub matchingShares(\@) {
  my $sharesP = shift;
  
  my %shares; foreach my $sh (@$sharesP) {$shares{$sh}++;}
  open(CSH, "<./Vagrantfile") || return 0;
  while(<CSH>) {
    if ($_ =~ /^(\Qconfig.vm.synced_folder\E\s.*)$/) {$shares{$1}++;}
    foreach my $share (@$sharesP) {if ($_ =~ /^\Q$share\E$/) {delete($shares{$share});}}
  }
  return (keys(%shares) == 0 ? 1:0);
}

sub rebuildNeeded() {
  my $is  = &shell("grep \"config.vm.box \" ./Vagrantfile_tpl", 1);
  my $was = &shell("grep \"config.vm.box \" ./Vagrantfile", 1);
  
  return ($is ne $was);
}

sub shell($$) {
  my $cmd = shift;
  my $quiet = shift;
  
  if (!$quiet) {print "$cmd\n";}
  my $result = decode('utf8', `$cmd 2>&1`);
  if (!$quiet) {print "$result\n";}
  
  return $result;
}
