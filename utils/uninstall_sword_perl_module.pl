#!/usr/bin/perl

# uninstall_sword_perl_module.pl

use 5.14.2;
use ExtUtils::Installed;
use ExtUtils::Packlist;

my $module = 'Sword';

my $installed_modules = ExtUtils::Installed->new;

# iterate through and try to delete every file associated with the module
foreach my $file ($installed_modules->files($module)) {
    print "removing $file\n";
    print `sudo rm "$file"`."\n";
}

# delete the module packfile
my $packfile = $installed_modules->packlist($module)->packlist_file;
print "removing packfile $packfile\n";
print `sudo rm "$packfile"`."\n";

# delete the module directories if they are empty
foreach my $dir (reverse sort($installed_modules->directory_tree($module))) {
  if ($dir) {
    print("removing module directory $dir\n");
    print `sudo rmdir "$dir"`."\n";
  }
}
