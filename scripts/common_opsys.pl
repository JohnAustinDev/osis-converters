#!/usr/bin/perl
#
# This script might be loaded on any operating system. So code here
# should be as operating system agnostic as possible and should not 
# rely on non-standard Perl modules. The functions in this file are
# required for bootstrapping osis-converters.

use Encode;
use File::Copy;
use File::Spec;

$VAGRANT_HOME = '/home/vagrant';

# Initializes more global path variables, checks operating system and 
# dependencies, and restarts with Vagrant if necessary. If checking and
# initialization is successful 1 is returned so the script can commence.
sub init_opsys() {
  chdir($INPD);
  
  if (!-e "$SCRD/paths.pl") {copy(&getDefaultFile('paths.pl'), $SCRD);}
  
  &readPaths();
  if ($NO_OUTPUT_DELETE) {$DEBUG = 1;}
  &Debug("osis-converters ".(&runningInVagrant() ? "on virtual machine":"on host").":\n\tSCRD=$SCRD\n\tSCRIPT=$SCRIPT\n\tINPD=$INPD\n");
  
  my $isCompatibleLinux = ($^O =~ /linux/i ? &shell("lsb_release -a", 3):''); # Mint is like Ubuntu but with totally different release info! $isCompatibleLinux = ($isCompatibleLinux =~ /Release\:\s*(14|16|18)\./ms);
  my $haveAllDependencies = ($isCompatibleLinux && &haveDependencies($SCRIPT, $SCRD, $INPD) ? 1:0);
  
  # Start the script if we're already running on a VM and/or have dependencies met.
  if (&runningInVagrant() || ($haveAllDependencies && !$VAGRANT)) {
    if ($haveAllDependencies) {
      require "$SCRD/scripts/common.pl";
      &init_linux_script();
      return 1;
    }
    elsif (&runningInVagrant()) {
      &ErrorBug("The Vagrant virtual machine does not have the necessary dependancies installed.");
      return 0;
    }
  }
  
  my $vagrantInstallMessage = "
    Install Vagrant and VirtualBox and then re-run osis-converters:
    Vagrant (from https://www.vagrantup.com/downloads.html)
    Virtualbox (from https://www.virtualbox.org/wiki/Downloads)";
  
  # If the user is forcing the use of Vagrant, then start Vagrant
  if ($VAGRANT) {
    if (&vagrantInstalled()) {
      &Note("\nVagrant will be used because \$VAGRANT is set.\n");
      &restart_with_vagrant();
    }
    else {
      &Error("You have \$VAGRANT=1; in osis-converters/paths.pl but Vagrant is not installed.", $vagrantInstallMessage);
    }
    return 0;
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
    return 0;
  }
  
  # Then we must use Vagrant, if it's installed
  if (&vagrantInstalled()) {
    &restart_with_vagrant();
    return 0;
  }
  
  &Error("You are not running osis-converters on compatible Linux and do not have vagrant/VirtualBox installed.", $vagrantInstallMessage);
  return 0;
}

# Read the osis-converters/paths.pl file which contains customized paths
# to things like fonts and executables (it also contains some settings
# like $DEBUG).
sub readPaths() {
  # The following host paths in paths.pl are converted to absolute paths
  # which are later updated to work on the VM if running in Vagrant.
  my @pathvars = ('MODULETOOLS_BIN', 'GO_BIBLE_CREATOR', 'SWORD_BIN', 'OUTDIR', 'FONTS', 'COVERS');
  
  if (-e "$SCRD/paths.pl") {
    require "$SCRD/paths.pl";
    
    if (!&runningInVagrant()) {
      # If host, then just make paths absolute (and save .hostinfo for Vagrant when needed)
      foreach my $v (@pathvars) {
        if (!$$v || $$v =~ /^(https?|ftp)\:/) {next;}
        if ($^O =~ /linux/i) {$$v = &expandLinuxPath($$v);}
        if ($$v =~ /^\./) {$$v = File::Spec->rel2abs($$v, $SCRD);}
      }
      if (open(SHL, ">$SCRD/.hostinfo")) {
        foreach my $v (@pathvars) {
          if (!$$v || $$v =~ /^(https?|ftp)\:/) {next;}
          my $rel2vhs = File::Spec->abs2rel($$v, &vagrantHostShare());
          $rel2vhs =~ s/\\/\//g; # this relative path is for the Linux VM
          print SHL "\$$v = '$rel2vhs';\n";
        }
        print SHL "1;\n";
        close(SHL);
      }
      else {&ErrorBug("Could not open $SCRD/.hostinfo. Vagrant will not work.", "Check that you have write permission in directory $SCRD.");}
    }
    else {
      # if Vagrant, then read .hostinfo and prepend path to INDIR_ROOT Vagrant share
      require("$SCRD/.hostinfo");
      foreach my $v (@pathvars) {
        if (!$$v || $$v =~ /^(https?|ftp)\:/) {next;}
        $$v = "$VAGRANT_HOME/INDIR_ROOT/$$v";
      }
    }
  }
  
  # Finally set default values when paths.pl doesn't exist or doesn't specify exedirs
  my %exedirs = (
    'MODULETOOLS_BIN' => "~/.osis-converters/src/Module-tools/bin", 
    'GO_BIBLE_CREATOR' => "~/.osis-converters/GoBibleCreator.245", 
    'SWORD_BIN' => "~/.osis-converters/src/sword/build/utilities"
  );
    
  # The following are installed to certain locations by provision.sh
  if ($^O =~ /linux/i) {
    foreach my $v (keys %exedirs) {
      if ($$v) {next;}
      $$v = &expandLinuxPath($exedirs{$v});
    }
  }
  
  # All executable directory paths should end in / or else be empty.
  foreach my $v (keys %exedirs) {
    if (!$$v) {next;}
    $$v =~ s/([^\/])$/$1\//;
  }
  
  my $dbgmsg = "paths.pl ".(&runningInVagrant() ? "on virtual machine":"on host").":\n";
  foreach my $v (@pathvars) {$dbgmsg .= "\t$v = $$v\n";}
  $dbgmsg .= "\tvagantHostShare=".&vagrantHostShare()."\n";
  $dbgmsg .= "\tVAGRANT=$VAGRANT\n\tNO_OUTPUT_DELETE=$NO_OUTPUT_DELETE\n";
  &Debug($dbgmsg, 1);
}

# Look for an osis-converters default file or directory in the following 
# places, in order. If a default file is not found, return either '' or 
# throw a stop error if priority was 0 (or null etc.). The file may  
# include a path that (presently) begins with either 'bible/' for Bible  
# module default files or 'dict/' for dictionary module default files. 
# If priority 1, 2 or 3 is specified, only the location with that 
# priority will be checked:
# priority  location
#    1      Project directory (if bible|dict subdir matches the project type)
#    2      main-project-parent/defaults directory
#    3      osis-converters/defaults directory
#
# NOTE: priority -1 will check all locations but will not throw an error 
# upon failure.
#
# NOTE: Soft links in the file path are followed, but soft links that 
# are valid on the host will NOT be valid on a VM. To work for the VM, 
# soft links must be valid from the VM's perspective (so they will begin 
# with /vagrant and be broken on the host, although they work on the VM).
sub getDefaultFile($$) {
  my $file = shift;
  my $priority = shift;
  
  my $moduleFile = $file;
  my $fileType = ($moduleFile =~ s/^(bible|dict)\/// ? $1:'');
  my $modType = ($MOD eq $DICTMOD ? 'dict':'bible');
  
  my $defaultFile;
  my $checkAll = ($priority != 1 && $priority != 2 && $priority != 3);
  
  my $projectDefaultFile = ($fileType eq 'dict' ? $DICTINPD:$MAININPD).'/'.$moduleFile;
  my $mainParent = "$MAININPD/..";
  if (($checkAll || $priority == 1) && -e $projectDefaultFile) {
    $defaultFile = $projectDefaultFile;
    &Note("getDefaultFile: (1) Found $file at $defaultFile");
  }
  if (($checkAll || $priority == 2) && -e "$mainParent/defaults/$file") {
    if (!$defaultFile) {
      $defaultFile = "$mainParent/defaults/$file";
      &Note("getDefaultFile: (2) Found $file at $defaultFile");
    }
    elsif ($^O =~ /linux/i && !&shell("diff '$mainParent/defaults/$file' '$defaultFile'", 3)) {
      &Note("(2) Default file $defaultFile is not needed because it is identical to the more general default file at $mainParent/defaults/$file");
    }
  }
  if (($checkAll || $priority == 3) && -e "$SCRD/defaults/$file") {
    if (!$defaultFile) {
      $defaultFile = "$SCRD/defaults/$file";
      &Note("getDefaultFile: (3) Found $file at $defaultFile");
    }
    elsif ($^O =~ /linux/i && !&shell("diff '$SCRD/defaults/$file' '$defaultFile'", 3)) {
      &Note("(3) Default file $defaultFile is not needed because it is identical to the more general default file at $SCRD/defaults/$file");
    }
  }
  if (!$priority && !$defaultFile) {
    &ErrorBug("Default file $file could not be found in any default path.", 'Add this file to the osis-converters/defaults directory.', 1);
  }
  return $defaultFile;
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
  $test{'JAVA'}             = [ 'java -version', "openjdk version \"10.", 1 ]; # NOT openjdk 10.
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
  
  return 1;
}


########################################################################
# Vagrant related functions
########################################################################

# The host share directory cannot be just a Windows drive letter (native 
# or emulated) because Vagrant cannot create a share to the root of a 
# window's drive.
sub vagrantHostShare() {
  if ($INPD !~ /^((?:\w\:|\/\w)?\/[^\/]+)/) {
    die "Error: Cannot parse project path \"$INPD\"\n";
  }
  return $1;
}

sub vagrantInstalled() {
  print "\n";
  my $pass;
  system("vagrant -v >tmp.txt 2>&1");
  if (!open(TEST, "<tmp.txt")) {die;}
  $pass = 0; while (<TEST>) {if ($_ =~ /\Qvagrant\E/i) {$pass = 1; last;}}
  unlink("tmp.txt");

  return $pass;
}

sub restart_with_vagrant() {
  if (!-e "$SCRD/Vagrantcustom" && open(VAGC, ">$SCRD/Vagrantcustom")) {
    print VAGC "# NOTE: You must halt your VM for changes to take effect\n
  config.vm.provider \"virtualbox\" do |vb|
    # Set the RAM for your Vagrant VM
    vb.memory = 2560
  end\n";
    close(VAGC);
  }
  
  chdir $SCRD; # Required for the following vagrant commands to work

  # Make sure Vagrant is up, and with the right share(s)
  my @shares;
  push(@shares, &vagrantShare(&vagrantHostShare(), "$VAGRANT_HOME/INDIR_ROOT"));
  $status = (-e "./.vagrant" ? &shell("vagrant status", 3):'');
  if ($status !~ /\Qrunning (virtualbox)\E/i) {
    &vagrantUp(\@shares);
  }
  elsif (!&matchingShares(\@shares)) {
    &shell("vagrant halt", 3);
    &vagrantUp(\@shares);
  }

  my $scriptRel = "/vagrant/".File::Spec->abs2rel($SCRIPT, $SCRD); $scriptRel =~ s/\\/\//g;
  my $inpdRel = File::Spec->abs2rel($INPD, &vagrantHostShare()); $inpdRel =~ s/\\/\//g;
  my $cmd = "vagrant ssh -c \"'$scriptRel' '$VAGRANT_HOME/INDIR_ROOT/$inpdRel'\"";
  print "\nStarting Vagrant with...\n$cmd\n";
  
  # Continue printing to console while Vagrant ssh remains open
  open(VUP, "$cmd |");
  while(<VUP>) {print $_;}
  close(VUP);
}

sub runningInVagrant() {
  return (-e "/vagrant/Vagrantfile" ? 1:0);
}

sub vagrantShare($$) {
  my $host = shift;
  my $client = shift;
  # If the host is Windows, $host must be a native path!
  $host =~ s/^((\w)\:|\/(\w))\//uc($+).":\/"/e;
  $host =~ s/\\/\\\\/g; $client =~ s/\\/\\\\/g; # escape "\"s for use as Vagrantfile quoted strings
  return "config.vm.synced_folder \"$host\", \"$client\"";
}

sub vagrantUp(\@) {
  my $sharesP = shift;
  
  if (!-e "./.vagrant") {mkdir("./.vagrant");}
  
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
  if ($solmsg) {&Log("SOLUTION: $solmsg\n", 1);}
  
  if ($doDie) {&Log("Exiting...\n", 1); exit;}
}

# Report errors that are unexpected or need to be seen by osis-converters maintainer
sub ErrorBug($$) {
  my $errmsg = shift;
  my $solmsg = shift;
  my $doDie = shift;
  
  &Log("\nERROR (UNEXPECTED): $errmsg\n", 1);
  if ($solmsg) {&Log("SOLUTION: $solmsg\n", 1);}
  
  use Carp qw(longmess);
  &Log(&longmess());
  
  &Log("Report the above unexpected error to osis-converters maintainer.\n\n");
  
  if ($doDie) {&Log("Exiting...\n", 1); exit;}
}

sub Warn($$) {
  my $warnmsg = shift;
  my $checkmsg = shift;
  my $flag = shift;
  
  # Terms beginning with <- will not have a leading line-break
  my $n1 = ($warnmsg =~ s/^<\-// ? '':"\n");
  my $n2 = ($checkmsg =~ s/^<\-// ? '':"\n");
  
  # If either term begins with -> there will be no ending line-break
  my $endbreak = ($warnmsg =~ s/^\->// ? '':"\n");
  $endbreak = ($checkmsg =~ s/^\->// || !$endbreak ? '':"\n");
  
  # Messages beginning with <> will only be output once
  if ($warnmsg  =~ s/^<>//) {if ($WARN_MSG{$warnmsg})    {$warnmsg='';}  else {$WARN_MSG{$warnmsg}++;}}
  if ($checkmsg =~ s/^<>//) {if ($WARN_CHECK{$checkmsg}) {$checkmsg='';} else {$WARN_CHECK{$checkmsg}++;}}

  if ($warnmsg) {
    &Log($n1."WARNING: $warnmsg", $flag);
  }
  if ($checkmsg) {
    &Log($n2."CHECK: $checkmsg", $flag);
  }
  if ($endbreak && ($warnmsg || $checkmsg)) {&Log("\n");}
}

sub Note($$) {
  my $notemsg = shift;
  my $flag = shift;
  
  # If message begins with -> there will be no ending line-break
  my $endbreak = ($notemsg =~ s/^\->// ? '':"\n");
  
  # Messages beginning with <> will only be output once
  if ($notemsg  =~ s/^<>//) {if ($NOTE_MSG{$notemsg}) {$notemsg='';} else {$NOTE_MSG{$notemsg}++;}}
  if (!$notemsg) {return;}
  
  &Log("NOTE: $notemsg$endbreak", $flag);
}

sub Debug($$) {
  my $dbgmsg = shift;
  my $flag = shift;
  
  if ($DEBUG) {&Log("DEBUG: $dbgmsg", ($flag ? $flag:1));}
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
  
  if ((!$NOCONSOLELOG && $flag != -1) || $flag >= 1 || $p =~ /ERROR/ || $LOGFILE eq 'none') {
    print encode("utf8", $p);
  }
  
  if ($flag == 2 || $LOGFILE eq 'none') {return;}
  
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
  push(@paths, ($INPD eq MAININPD ? 'DICTINPD':'MAININPD'));
  
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

sub expandLinuxPath($) {
  my $path = shift;
  if ($^O !~ /linux/i) {&ErrorBug("expandLinuxPath() should only be run on Linux, but opsys is: $^O", '', 1);}
  my $r = &shell("echo $path", 3);
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
