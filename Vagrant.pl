#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2018 John Austin (gpl.programs.info@gmail.com)
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

# usage: Vagrant.pl script input_directory

# This script might be run on any operating system.

# This script starts osis-converters on a Vagrant VirtualBox virtual 
# machine. First, it sets the required file shares between the host and 
# vagrant client, and then it starts osis-converters on the client using 
# Vagrant.

use File::Spec;
$Script = File::Spec->rel2abs(shift); $Script =~ s/\\/\//g;
$INPD = File::Spec->rel2abs(shift); $INPD =~ s/\\/\//g;
$SCRIPT = File::Spec->rel2abs(__FILE__); $SCRIPT =~ s/\\/\//g;
$SCRD = $SCRIPT;
if ($SCRD !~ s/(\/osis\-converters)\/.*?$/$1/) {
  die "Error: Unexpected osis-converters installation directory name\n";
}

$VAGRANT_HOME = '/home/vagrant';

require "$SCRD/scripts/common_opsys.pl";

# INPD must be made relative to an INDIR_ROOT Vagrant share.
# INDIR_ROOT cannot be just a Windows drive letter (native or emulated) 
# because Vagrant cannot create a share to the root of a window's drive.
if ($INPD !~ s/^((?:\w\:|\/\w)?\/[^\/]+)//) {
  die "Error: Cannot parse project path \"$INPD\"\n";
}
$INDIR_ROOT = $1;

chdir $SCRD;

if (!-e "$SCRD/Vagrantcustom" && open(VAGC, ">$SCRD/Vagrantcustom")) {
  print VAGC "# NOTE: You must halt your VM for changes to take effect\n
config.vm.provider \"virtualbox\" do |vb|
  # Set the RAM for your Vagrant VM
  vb.memory = 2560
end\n";
  close(VAGC);
}

&readPaths();

push(@Shares, &vagrantShare($INDIR_ROOT, "INDIR_ROOT"));
# The following shares are no longer needed since INDIR_ROOT is used to reach all paths instead
#if ($OUTDIR) {push(@Shares, &vagrantShare($OUTDIR, "OUTDIR"));}
#if ($MODULETOOLS_BIN) {push(@Shares, &vagrantShare($MODULETOOLS_BIN, ".osis-converters/src/Module-tools/bin"));}

$Status = (-e "./.vagrant" ? &shell("vagrant status", 3):'');
if ($Status !~ /\Qrunning (virtualbox)\E/i) {&vagrantUp(\@Shares);}
elsif (!&matchingShares(\@Shares)) {&shell("vagrant halt", 3); &vagrantUp(\@Shares);}

my $script_rel = File::Spec->abs2rel($Script, $SCRD);
$cmd = "vagrant ssh -c \"cd /vagrant && ./$script_rel $VAGRANT_HOME/INDIR_ROOT$INPD\"";
print "\nStarting Vagrant...\n$cmd\n";
open(VUP, "$cmd |");
while(<VUP>) {print $_;}
close(VUP);
