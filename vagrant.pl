#!/usr/bin/perl
# usage: vagrant.pl script input_directory
#
# The purpose of this script is to set the required file shares between
# host and vagrant client, and to call osis-converters on the client.

$Script = shift;
$Indir = shift;

$Indir =~ s/^([\\\/]?[^\\\/]+)[\\\/]?(.*?)[\\\/]?$/$2/;
$INPARENT = $1;
if ($INPARENT =~ /^\./) {$INPARENT = File::Spec->rel2abs($INPARENT);}

use File::Spec; $SCRD = File::Spec->rel2abs(__FILE__); $SCRD =~ s/([\\\/][^\\\/]+){1}$//;
chdir $SCRD;
require "./paths.pl";

push(@Shares, &vagrantShare($INPARENT, "INDIR"));
if ($OUTDIR) {push(@Shares, &vagrantShare($OUTDIR, "OUTDIR"));}
if ($REPOTEMPLATE_BIN) {push(@Shares, &vagrantShare($REPOTEMPLATE_BIN, "REPOTEMPLATE_BIN"));}

$Status = `vagrant status`;
if ($Status !~ /\Qrunning (virtualbox)\E/i) {&vagrantUp(\@Shares);}
elsif (!&matchingShares(\@Shares)) {print `vagrant halt`; &vagrantUp(\@Shares);}

$cmd = "vagrant ssh -c \"/vagrant/$Script /home/vagrant/INDIR/$Indir\"";
print "\nStarting Vagrant...\n$cmd\n";
open(VUP, "$cmd |");
while(<VUP>) {print $_;}
close(VUP);

########################################################################

sub vagrantShare($$) {
  my $host = shift;
  my $client = shift;
  $host =~ s/^\/(\w)(?=(\/Users\/|$))/$1:/;
  return "config.vm.synced_folder \"$host\", \"/home/vagrant/$client\"";
}

sub vagrantUp(\@) {
  my $sharesP = shift;
  
  # Create input/output filesystem shares
  open(TPL, "<./Vagrantfile_tpl") || die;
  open(VAG, ">./Vagrantfile") || die;
  if (!-e "./.vagrant") {`mkdir ./.vagrant`;}
  while (<TPL>) {
    print VAG $_;
    if ($_ =~ /\Q"VagrantProvision.sh"\E/) {foreach my $share (@$sharesP) {print VAG "$share\n";}}
  }
  close(VAG);
  close(TPL);
  print "Starting Vagrant...\n";
  print "The first use of Vagrant will automatically download and build a virtual\n";
  print "machine having osis-converters fully installed. This build will take some\n";
  print "time. Subsequent use of Vagrant will run much faster.\n\n";
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
