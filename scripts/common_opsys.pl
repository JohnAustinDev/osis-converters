#!/usr/bin/perl
#
# This script might be loaded on any operating system. So code here
# should be as operating system agnostic as possible and should not 
# rely on non-standard Perl modules. The functions in this file are
# required for bootstrapping osis-converters.

use Encode;
use File::Copy;
use File::Spec;

# Initializes more global path variables, checks operating system and 
# dependencies. This function may start the script, re-start the script 
# using Vagrant, or bail.
sub start_script() {
  chdir($INPD);
  
  if (!-e "$SCRD/paths.pl") {
    my $paths = &getDefaultFile('paths.pl');
    if ($paths) {copy($paths, $SCRD);}
  }
  
  &readPaths();
  &Debug((&runningInVagrant() ? "On virtual machine":"On host")."\n\tINPD=$INPD\n\tLOGFILE=$LOGFILE\n\tSCRIPT=$SCRIPT\n\tSCRD=$SCRD\n\tVAGRANT=$VAGRANT\n\tNO_OUTPUT_DELETE=$NO_OUTPUT_DELETE\n");
  
  my $isCompatibleLinux = `lsb_release -a 2>&1`; $isCompatibleLinux = ($isCompatibleLinux =~ /Release\:\s*(14|16|18)\./ms);
  my $haveAllDependencies = ($isCompatibleLinux && &haveDependencies($SCRIPT, $SCRD, $INPD) ? 1:0);
  
  # Start script if we're already running on a VM or have dependencies met.
  if (&runningInVagrant() || ($haveAllDependencies && !$VAGRANT)) {
    if ($haveAllDependencies) {
      require "$SCRD/scripts/common.pl";
      &start_linux_script();
    }
    elsif (&runningInVagrant()) {
      &ErrorBug("The Vagrant virtual machine does not have the necessary dependancies installed.");
    }
    return;
  }
  
  my $vagrantInstallMessage = "
    Install Vagrant and VirtualBox and then re-run osis-converters:
    Vagrant (from https://www.vagrantup.com/downloads.html)
    Virtualbox (from https://www.virtualbox.org/wiki/Downloads)";
  
  # If the user is forcing the use of Vagrant, then start Vagrant
  if ($VAGRANT) {
    if (&vagrantInstalled()) {
      &Note("\nVagrant will be used because \$VAGRANT is set.\n");
      &startVagrant($SCRD, $SCRIPT, $INPD);
    }
    else {
      &Error("You have \$VAGRANT=1; in osis-converters/paths.pl but Vagrant is not installed.", $vagrantInstallMessage);
    }
    return;
  }
  
  # OKAY then, to meet dependancies check if we may use Vagrant and report
  if ($isCompatibleLinux) {
    &Error("Dependancies are not met.", "
You are running a compatible version of Linux, so you have two options:
1) Install the necessary dependancies by running: 
osis-converters\$ sudo provision.sh
2) Run with Vagrant by adding '\$VAGRANT=1;' to this file: 
osis-converters/paths.pl
NOTE: Option #2 requires that Vagrant and VirtualBox be installed and 
will run slower and use more memory.");
    return;
  }
  
  # Then we must use Vagrant
  if (&vagrantInstalled()) {
    &startVagrant($SCRD, $SCRIPT, $INPD);
    return;
  }
  
  &Error("You are not running osis-converters on Linux Ubuntu 14 to 18.", $vagrantInstallMessage);
}

# Read the osis-converters/paths.pl file which contains customized paths
# to things like fonts and executables (it also contains some settings
# like $DEBUG).
sub readPaths() {
  # The following host paths in paths.pl are converted to absolute paths
  # which are then updated to work on the VM if running in Vagrant.
  my @pathvars = ('MODULETOOLS_BIN', 'GO_BIBLE_CREATOR', 'SWORD_BIN', 'OUTDIR', 'FONTS', 'COVERS');
  
  # If we have paths.pl, read it, but always with its paths as 
  # interpereted on the host (the purpose of hostinfo). This is 
  # necessary because to create VM paths we must always start with a
  # host path.
  if (-e "$SCRD/paths.pl") {
    require "$SCRD/paths.pl";
    
    if (!&runningInVagrant()) {
      if (open(SHL, ">$SCRD/.hostinfo")) {
        print SHL "\$HOSTHOME = \"".&expand('$HOME')."\";\n";
        foreach my $v (@pathvars) {
          if (!$$v || $$v =~ /^(https?|ftp)\:/) {next;} 
          $$v = &expand($$v);
          $$v = File::Spec->rel2abs($$v, $SCRD);
          print SHL "\$$v = \"$$v\";\n";
        }
        print SHL "1;\n";
        close(SHL);
      }
      else {&ErrorBug("Could not open $SCRD/.hostinfo", "Check that you have write permission in directory $SCRD.");}
    }
    
    require("$SCRD/.hostinfo");
  }

  # Now if we're running in Vagrant, we convert the host paths to VM paths
  if (&runningInVagrant() && open(CSH, "<$SCRD/Vagrantshares")) {
    while(<CSH>) {
      if ($_ =~ /config\.vm\.synced_folder\s+"([^"]*)"\s*,\s*"([^"]*INDIR_ROOT[^"]*)"/) {
        $SHARE_HOST = $1;
        $SHARE_VIRT = $2;
      }
    }
    close(CSH);
    if ($SHARE_HOST && $SHARE_VIRT) {
      foreach my $v (@pathvars) {
        if (!$$v || $$v =~ /^(https?|ftp)\:/) {next;} 
        $$v = File::Spec->abs2rel($$v, $SHARE_HOST);
        $$v = File::Spec->rel2abs($$v, $SHARE_VIRT);
      }
    }
  }
  
  # The following are installed to certain locations by provision.sh
  my %exedirs = (
    'MODULETOOLS_BIN' => "~/.osis-converters/src/Module-tools/bin", 
    'GO_BIBLE_CREATOR' => "~/.osis-converters/GoBibleCreator.245", 
    'SWORD_BIN' => "~/.osis-converters/src/sword/build/utilities"
  );
  
  # Finally set default values when paths.pl doesn't exist or doesn't specify exedirs
  foreach my $v (keys %exedirs) {$$v = &expand($exedirs{$v});}
  
  # All executable directory paths should end in / or else be empty.
  foreach my $v (keys %exedirs) {
    if (!$$v) {next;}
    $$v =~ s/([^\/])$/$1\//;
  }
  &Debug((&runningInVagrant() ? "On virtual machine":"On host")."\n".eval { my $r; foreach my $v (@pathvars) {$r .= "\t$v = $$v\n";} $r .= "\n"; $r; }, 1);
}

# Look for an osis-converters default file or directory in the following 
# places, in order. Return '' if file is not found. The file must include 
# a path that (presently) begins with either 'bible/' for Bible module 
# files or 'dict/' for dictionary module files. If priority is specified, 
# only the location with that priority will be checked (1 is highest and
# 3 is lowest priority).
# priority-1) Project directory (if bible|dict subdir matches the project type)
# priority-2) Project-parent/defaults directory
# priority-3) osis-converters/defaults directory
#
# NOTE: Soft links in the file path are followed, but soft links that 
# are valid on the host will NOT be valid on a VM. To work for the VM, 
# soft links must be valid from the VM's perspective (so they will begin 
# with /vagrant and be broken on the host, although they work on the VM).
sub getDefaultFile($$) {
  my $file = shift;
  my $priority = shift;
  
  my $fileType = ($file =~ /^(bible|dict)\// ? $1:'');
  my $projType = ($INPD =~ /DICT\/?\s*$/ ? 'dict':'bible');
  my $projParent = $INPD.($projType eq 'dict' ? '/../..':'/..');
  my $pfile = $file; $pfile =~ s/^(bible|dict)\///;
   
  my $f;
  if ((!$priority || $priority == 1) && $fileType eq $projType && -e "$INPD/$pfile") {
    $f = "$INPD/$pfile";
    &Note("getDefaultFile: (1) Found $file at $f");
  }
  if ((!$priority || $priority == 2) && -e "$projParent/defaults/$file") {
    if (!$f) {
      $f = "$projParent/defaults/$file";
      &Note("getDefaultFile: (2) Found $file at $f");
    }
    elsif (!&shell("diff '$projParent/defaults/$file' '$f'", 3)) {
      &Note("(2) Default file $f is not needed because it is identical to the more general default file at $projParent/defaults/$file");
    }
  }
  if ((!$priority || $priority == 3) && -e "$SCRD/defaults/$file") {
    if (!$f) {
      $f = "$SCRD/defaults/$file";
      &Note("getDefaultFile: (3) Found $file at $f");
    }
    elsif (!&shell("diff '$SCRD/defaults/$file' '$f'", 3)) {
      &Note("(3) Default file $f is not needed because it is identical to the more general default file at $SCRD/defaults/$file");
    }
  }
  return $f;
}

# Return 1 if dependencies are met for $script and 0 if not
sub haveDependencies($$$$) {
  my $script = shift;
  my $scrd = shift;
  my $inpd = shift;
  my $quiet = shift;
  
  my $logflag = ($quiet ? ($DEBUG ? 2:3):1);

  my @deps;
  if ($script =~ /(sfm2all)/) {
    @deps = ('SWORD_PERL', 'SWORD_BIN', 'XMLLINT', 'GO_BIBLE_CREATOR', 'MODULETOOLS_BIN', 'XSLT2', 'CALIBRE');
  }
  elsif ($script =~ /(sfm2osis|osis2osis)/) {
    @deps = ('SWORD_PERL', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2sword/) {
    @deps = ('SWORD_PERL', 'SWORD_BIN', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2ebooks/) {
    @deps = ('SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2', 'CALIBRE');
  }
  elsif ($script =~ /osis2html/) {
    @deps = ('SWORD_PERL', 'MODULETOOLS_BIN', 'XSLT2');
  }
  elsif ($script =~ /osis2GoBible/) {
    @deps = ('SWORD_PERL', 'GO_BIBLE_CREATOR', 'MODULETOOLS_BIN', 'XSLT2');
  }
  
  # XSLT2 also requires that openjdk 10.0.1 is NOT being used 
  # because its Unicode character classes fail with saxonb-xslt.
  my %depsh = map { $_ => 1 } @deps;
  if ($depsh{'XSLT2'}) {push(@deps, 'JAVA');}
  
  my %test;
  $test{'SWORD_BIN'}        = [ &escfile($SWORD_BIN."osis2mod"), "You are running osis2mod: \$Rev: 3431 \$" ]; # want specific version
  $test{'XMLLINT'}          = [ "xmllint --version", "xmllint: using libxml" ]; # who cares what version
  $test{'GO_BIBLE_CREATOR'} = [ "java -jar ".&escfile($GO_BIBLE_CREATOR."GoBibleCreator.jar"), "Usage" ];
  $test{'MODULETOOLS_BIN'}  = [ &escfile($MODULETOOLS_BIN."usfm2osis.py"), "Revision: 491" ]; # check version
  $test{'XSLT2'}            = [ 'saxonb-xslt', "Saxon 9" ]; # check major version
  $test{'JAVA'}             = [ 'java -version', "openjdk version \"10.0.1\"", 1 ]; # NOT openjdk 10.0.1
  $test{'CALIBRE'}          = [ "ebook-convert --version", "calibre 3" ]; # check major version
  $test{'SWORD_PERL'}       = [ "perl -le 'use Sword; print \$Sword::SWORD_VERSION_STR'", "1.8.900" ]; # check version
  
  my $failMes = '';
  foreach my $p (@deps) {
    if (!exists($test{$p})) {
      &ErrorBug("No test for \"$p\".");
      return 0;
    }
    system($test{$p}[0]." >".&escfile("tmp.txt"). " 2>&1");
    if (!open(TEST, "<tmp.txt")) {
      &ErrorBug("Could not read test output file \"$SCRD/tmp.txt\".");
      return 0;
    }
    my $result; {local $/; $result = <TEST>;} close(TEST); unlink("tmp.txt");
    my $need = $test{$p}[1];
    if (!$test{$p}[2] && $result !~ /\Q$need\E/im) {
      $failMes .= "\nDependency $p failed:\n\tRan: \"".$test{$p}[0]."\"\n\tLooking for: \"$need\"\n\tGot:\n$result\n";
    }
    elsif ($test{$p}[2] && $result =~ /\Q$need\E/im) {
      $failMes .= "\nDependency $p failed:\n\tRan: \"".$test{$p}[0]."\"\n\tCannot have: \"$need\"\n\tGot:\n$result\n";
    }
    #&Note("Dependency $p:\n\tRan: \"".$test{$p}[0]."\"\n\tGot:\n$result");
  }
  
  if ($failMes) {
    &Error("\n$failMes\n", $logflag);
    if (!&runningInVagrant()) {
      &Log("
      SOLUTION: On Linux systems you can try installing dependencies by running:
      $scrd/provision.sh\n\n", 1);
    }
    return 0;
  }
  
  $MODULETOOLS_GITHEAD = `cd "$MODULETOOLS_BIN" && git rev-parse HEAD 2>tmp.txt`; unlink("tmp.txt");
  &Log("Module-tools git rev: $MODULETOOLS_GITHEAD", $logflag);
  
  &Log("Using ".`calibre --version`."\n", $logflag);
  
  return 1;
}


########################################################################
# Vagrant related functions
########################################################################

sub vagrantInstalled() {
  print "\n";
  my $pass;
  system("vagrant -v >tmp.txt 2>&1");
  if (!open(TEST, "<tmp.txt")) {die;}
  $pass = 0; while (<TEST>) {if ($_ =~ /\Qvagrant\E/i) {$pass = 1; last;}}
  unlink("tmp.txt");

  return $pass;
}

sub startVagrant($$$) {
  my $scrd = shift;
  my $script = shift;
  my $inpd = shift;
  my @args = ("$scrd/Vagrant.pl", $script, $inpd);
  print "@args\n";
  system(@args); # exec does not run with Windows cmd shell
  exit;
}

sub runningInVagrant() {
  return (-e "/vagrant/Vagrant.pl" ? 1:0);
}

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
  
  if (!-e "./.vagrant") {&shell("mkdir ./.vagrant", 3);}
  
  # Create input/output filesystem shares
  open(VAG, ">./Vagrantshares") || die "\nError: Cannot open \"./Vagrantshares\"\n";
  foreach my $share (@$sharesP) {print VAG "$share\n";}
  close(VAG);
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
  open(CSH, "<./Vagrantshares") || return 0;
  while(<CSH>) {
    if ($_ =~ /^(\Qconfig.vm.synced_folder\E\s.*)$/) {$shares{$1}++;}
    foreach my $share (@$sharesP) {if ($_ =~ /^\Q$share\E$/) {delete($shares{$share});}}
  }
  return (keys(%shares) == 0 ? 1:0);
}


########################################################################
# Logging functions
########################################################################

# Report errors that users need to fix
sub Error($$$) {
  my $errmsg = shift;
  my $solmsg = shift;
  my $doDie = shift;

  &Log("\nERROR: $errmsg\n", 1);
  if ($solmsg) {&Log("SOLUTION: $solmsg\n");}
  
  if ($doDie) {&Log("Exiting...\n", 1); exit;}
}

# Report errors that are unexpected or need to be seen by osis-converters maintainer
sub ErrorBug($$) {
  my $errmsg = shift;
  my $solmsg = shift;
  my $doDie = shift;
  
  &Log("\nERROR (UNEXPECTED): $errmsg\n", 1);
  if ($solmsg) {&Log("SOLUTION: $solmsg\n");}
  
  use Carp qw(longmess);
  &Log(&longmess());
  
  &Log("Report the above unexpected error to osis-converters maintainer.\n\n");
  
  if ($doDie) {&Log("Exiting...\n", 1); exit;}
}

sub Warn($$) {
  my $warnmsg = shift;
  my $checkmsg = shift;
  my $flag = shift;
  
  # Messages beginning with <- will not have a leading line-break
  my $n = ($warnmsg =~ s/^\<\-// ? '':"\n");

  &Log($n."WARNING: $warnmsg\n".($checkmsg ? "CHECK: $checkmsg\n":''), $flag);
}

sub Note($$) {
  my $notemsg = shift;
  my $flag = shift;
  
  &Log("NOTE: $notemsg\n", $flag);
}

sub Debug($$) {
  my $dbgmsg = shift;
  my $flag = shift;
  
  if ($DEBUG) {&Log("DEBUG: $dbgmsg", $flag);}
}

sub Report($$) {
  my $rptmsg = shift;
  my $flag = shift;
  
  &Log("$MOD REPORT: $rptmsg\n", $flag);
}

# Log to console and logfile. $flag can have these values:
# -1 = only log file
#  0 = log file (+ console unless $NOCONSOLELOG is set)
#  1 = log file + console (ignoring $NOCONSOLELOG)
#  2 = only console
#  3 = don't log anything
sub Log($$) {
  my $p = shift; # log message
  my $flag = shift;
  
  if ($flag == 3) {return;}
  
  $p =~ s/&lt;/</g; $p =~ s/&gt;/>/g; $p =~ s/&amp;/&/g;
  $p =~ s/&#(\d+);/my $r = chr($1);/eg;
  
  if ((!$NOCONSOLELOG && $flag != -1) || $flag >= 1 || $p =~ /ERROR/) {
    print encode("utf8", $p);
  }
  
  if ($flag == 2) {return;}
  
  if ($p !~ /ERROR/ && !$DEBUG) {$p = &encodePrintPaths($p);}
  
  if (!$LOGFILE) {$LogfileBuffer .= $p; return;}

  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die "Could not open log file \"$LOGFILE\"\n";
  if ($LogfileBuffer) {print LOGF $LogfileBuffer; $LogfileBuffer = '';}
  print LOGF $p;
  close(LOGF);
}

sub encodePrintPaths($) {
  my $t = shift;
  
  # encode these local file paths
  my @paths = ('INPD', 'OUTDIR', 'SWORD_BIN', 'XMLLINT', 'MODULETOOLS_BIN', 'XSLT2', 'GO_BIBLE_CREATOR', 'CALIBRE', 'SCRD');
  foreach my $path (@paths) {
    if (!$$path) {next;}
    my $rp = $$path;
    $rp =~ s/[\/\\]+$//;
    $t =~ s/\Q$rp\E/\$$path/g;
  }
  return $t;
}


########################################################################
# Utility functions
########################################################################

sub expand($) {
  my $path = shift;
  my $r = `echo $path`;
  chomp($r);
  return $r;
}

sub escfile($) {
  my $n = shift;
  
  $n =~ s/([ \(\)])/\\$1/g;
  return $n;
}

# Run a Linux shell script. $flag can have these values:
# -1 = only log file
#  0 = log file (+ console unless $NOCONSOLELOG is set)
#  1 = log file + console (ignoring $NOCONSOLELOG)
#  2 = only console
#  3 = don't log anything
sub shell($$) {
  my $cmd = shift;
  my $flag = shift; # same as Log flag
  
  &Log("\n$cmd\n", $flag);
  my $result = decode('utf8', `$cmd 2>&1`);
  &Log($result."\n", $flag);
  
  return $result;
}

1;
