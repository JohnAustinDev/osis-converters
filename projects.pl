#!/usr/bin/perl

# Run specified conversions for every project, as quickly as possible

use strict;
use warnings;
use threads;
use threads::shared;
use DateTime;
use Encode;
use File::Copy;
use Data::Dumper;
use Term::ReadKey;
my $DEBUG = 0;

# Config values may be set here to be applied to the config.conf of 
# every project converted by this script.
my %CONFIG; # $CONFIG{(MOD|DICT|section)}{config-entry} = value
#$CONFIG{'osis2html'}{'CreateSeparatePubs'} = 'false';
#$CONFIG{'osis2html'}{'CreateSeparateBooks'} = 'false';
#$CONFIG{'osis2ebooks'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2GoBible'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2sword'}{'ARG_sfm2all_skip'} = 'true';

my $SKIP = '^(none)$'; # skip particular modules or sub-modules
my $ONLY = '^(all)$';  # only run listed modules or sub-modules

if ($0 ne "./projects.pl") {
  print "\nRun this script from the osis-converters directory.\n";
  exit;
}

# path to directory containing osis-converters projects
my $PRJDIR = shift;

# script to run on all projects
my $SCRIPT = shift;

# optional max number of threads to use (default is number of CPUs)
my $MAXTHREADS = shift; 

if (!$SCRIPT) {$SCRIPT = 'osis';}
if ($SCRIPT !~ /^(osis|sfm2osis|osis2osis|osis2sword|osis2html|osis2ebooks|osis2GoBible|osis2all|sfm2all)$/) {
  print "Unrecognzed script argument: $SCRIPT\n";
  $SCRIPT = '';
}

if (!$MAXTHREADS) {
  $MAXTHREADS = `lscpu | egrep "^CPU\\(s\\)\\:"`;
  $MAXTHREADS =~ s/^.*?\s+(\d+)\s*$/$1/;
}
   
if ( !$PRJDIR || !-e $PRJDIR || 
     !$SCRIPT || 
     !$MAXTHREADS || $MAXTHREADS != (1*$MAXTHREADS) 
   ) {
  print "
usage: projects.pl projects_directory [script] [max_threads]

projects_directory: The relative path from this script's directory to 
                    a directory containing osis-converters projects.
script            : The conversion(s) to run on each project. Default 
                    is osis (which will run sfm2osis or osis2osis 
                    depending on the project). The other options are 
                    sfm2osis, osis2osis, osis2sword, osis2html, 
                    osis2ebooks, osis2GoBible, osis2all and sfm2all.
max_threads       : The number of threads to use. Default is the number 
                    of CPUs.
";
  exit;
}
$PRJDIR =~ s/\/$//;

my %PRINTED;
my $LOGFILE = "$PRJDIR/OUT_projects.txt";
if (-e $LOGFILE) {unlink($LOGFILE);}

my $STARTTIME;
&timer('start'); &Log("\n");

my $INFO = &getProjectInfo($PRJDIR);

my @MODULES; my @MODULE_IGNORES;
my @MAINS;   my @MAIN_IGNORES;
foreach my $m (sort keys %{$INFO}) {
  if ($ONLY && $ONLY !~ /all/ && $m !~ /$ONLY/) {next;}
  if ($SKIP && $m =~ /$SKIP/) {next;}
  
  if ($INFO->{$m}{'updated'}) {
    push(@MODULES, $m);
    if (&hasDICT($m) && $INFO->{$m}{'type'} eq 'dict') {
      next;
    }
    push(@MAINS, $m);
  }
  else {
    push(@MODULE_IGNORES, $m);
    if (&hasDICT($m) && $INFO->{$m}{'type'} eq 'dict') {
      next;
    }
    push(@MAIN_IGNORES, $m);
  }
}

&Log("Ignoring ".@MAIN_IGNORES." projects which need upgrading (".@MODULE_IGNORES." modules):\n");
foreach my $m (@MODULE_IGNORES) {
  &Log(sprintf("%12s\n", $m));
}
&Log("\n");

# Update config files with any global changes, and then re-read info.
&updateConfigFiles(\@MODULES, \%CONFIG, $INFO);
$INFO = &getProjectInfo($PRJDIR);

my @RUN = &getScriptsToRun(\@MODULES, $SCRIPT, $INFO);

my %DEPENDENCY; &setDependencies(\%DEPENDENCY, \@RUN, $SCRIPT, $INFO);

&Log("Scheduling ".@RUN." jobs on ".@MAINS." projects (".@MODULES." modules):\n");
foreach my $m (@MODULES) {
  foreach my $run (@RUN) {
    if ($run !~ /^(\S+)\s+$m$/) {next;}
    my $script = $1;
    my $deps = join(', ', @{$DEPENDENCY{$run}});
    my $depsmsg = ($deps ? " (after $deps)":'');
    $depsmsg =~ s/ (osis2osis|sfm2osis)//g;
    &Log(sprintf("%12s:%-30s %14s %s\n", 
                  $m, 
                  $depsmsg, 
                  $script, 
                  &outdir($INFO, $m)
    ));
  }
}
&Log("\n");

ReadMode 4;

# Now run all jobs until there is nothing left to do, or the ESC key is 
# pressed.
my $NUM_THREADS :shared = 0;
my %DONE :shared;
my @STARTED :shared;
my $WAIT = 3;
my $KEY = 0;
my $PAUSED = 0;
while ( ( &working(\@STARTED, \%DONE) || @RUN ) && 
          $KEY != 27 
      ) { # 27 is ESC key
      
  $KEY = 0; # clear if set by inner while loop
  while ( !$PAUSED && $KEY != 27 && $NUM_THREADS < $MAXTHREADS && @RUN ) {
    # Start another conversion, skipping over any conversion whose 
    # dependencies are not done.
    my $x = -1;
    my $ok;
    do {
      $x++;
      $ok = 1;
      foreach my $run (@{$DEPENDENCY{$RUN[$x]}}) {
        if (!$DONE{$run}) {$ok = 0;}
      }
    } while ($x < $#RUN && !$ok);
    
    if (@{$DEPENDENCY{$RUN[$x]}}) {
      if (!$ok) {
        print "Waiting for dependencies (".($MAXTHREADS - $NUM_THREADS)." free threads)...\n".
        last;
      }
      print "NOTE: Dependencies of ".$RUN[$x]." are done:\n\t".
      join("\n\t", @{$DEPENDENCY{$RUN[$x]}})."\n";
    }
    
    sleep(1); # so jobs don't starts at the same time, causing problems
    threads->create(sub {
      print "Starting: ".$RUN[$x]."\n";
      &runScript($PRJDIR, $RUN[$x]);
      $NUM_THREADS--;
      $DONE{$RUN[$x]}++;
      print "Exiting: ".$RUN[$x]."\n";
    });
    
    $NUM_THREADS++;
    push(@STARTED, splice(@RUN, $x, 1));
    if (@RUN) {print("There are ".@RUN." jobs left...\n");}
    
    &readKey();
  }

  if (!$KEY) {  # allow KEY already set by inner while loop to break outer loop
    &readKey();
  }
  sleep(2);
}

ReadMode 0;

&updateConfigFiles(\@MODULES, \%CONFIG, $INFO, 'restore');

if ($KEY == 27) {
  &Log("\n");
  &Log("
No more conversions will be scheduled...
Press ctrl-c to kill remaining threads and exit.
Or wait for the current threads to finish:\n");
&working(\@STARTED, \%DONE, 'log');
}
else {
  print "No more projects to start and none are running!\n";
}

foreach my $th (threads->list()) {$th->join();}

&timer('stop');

########################################################################
########################################################################

# Fills a hash with config.conf or CF_osis2osis.txt information for all 
# projects in pdir
sub getProjectInfo($) {
  my $pdir = shift;
  
  opendir(DIR, $pdir) or die;
  my @subs = readdir(DIR);
  closedir(DIR);
  
  my %info;
  foreach my $proj (@subs) {
    if ($proj =~ /^(defaults|utils|CB_Common|Cross_References)$/) {
      next;
    }
    if ($proj =~ /^\./ || !-d "$pdir/$proj") {
      next;
    }
    
    # sourceProject is osis2osis source project, or empty 
    # if OSIS will be created by sfm2osis.
    # configProject is the the MAIN module of a project or the 
    # MAIN module of the sourceProject if there is one.
      
    # Projects with a CF_osis2osis.txt file may not have their own 
    # config.conf file until after osis2osis is run, so this script
    # uses the sourceProject's config.conf when necessary.
    
    if (-e "$pdir/$proj/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$proj/CF_osis2osis.txt") 
        or die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $sourceProject = $1;
          # If CF_osis2osis.txt has SET_sourceProject, its modules are
          # considered updated and runnable.
          $info{$proj}{'updated'}++;
          $info{$proj}{'sourceProject'} = $sourceProject;
          $info{$proj}{'configProject'} = $sourceProject;
        }
        if ($_ =~ /^CCOSIS\:\s*(\S+)\s*$/) {
          $info{$proj}{'CCOSIS'}{$1}++;
        }
      }
      close(CF);
      next;
    }
    elsif (!-e "$pdir/$proj/config.conf") {next;}
    # Most projects have config.conf
    else {
      $info{$proj}{'configProject'} = $proj;
      open(CONF, "<:encoding(UTF-8)", "$pdir/$proj/config.conf") 
        or die;
      my $section = $proj;
      while(<CONF>) {
        if ($_ =~ /^\[(.*?)\]\s*$/) {
          $section = $1;
          # If config.conf has a [system] section, its modules are 
          # considered updated and runnable.
          if ($section eq 'system') {
            $info{$proj}{'updated'}++;
          }
        }
        elsif ($_ =~ /^([^#]\S+)\s*=\s*(.*?)\s*$/) {
          $info{$proj}{"$section+$1"} = $2;
        }
      }
      close(CONF);
    }
  }
  
  # Create info for any sub modules
  foreach my $proj (keys %info) {
    if (!&hasDICT($proj, \%info)) {next;}
    
    my $sproj = ($info{$proj}{'sourceProject'} ? 
                 $info{$proj}{'sourceProject'} : $proj);
    
    $info{$proj.'DICT'}{'updated'}++;
    $info{$proj.'DICT'}{'configProject'} = $sproj;
    
    if ($proj ne $sproj) {
      $info{$proj.'DICT'}{'sourceProject'} = $sproj;
    }
  }
  
  # Add all module and sub-module types
  foreach my $proj (keys %info) {
    if (!$info{$proj}{'updated'}) {next;}
    
    my $cproj = $info{$proj}{'configProject'};
    my $c2proj = ($proj =~ /DICT$/ ? $cproj.'DICT':$cproj);
    
    my $moddrv = $info{$cproj}{"$c2proj+ModDrv"};
    
    my $type = 'bible';
    if ($moddrv =~ /LD/i) {$type = 'dict';}
    if ($moddrv =~ /GenBook/i) {$type = 'childrensBible';}
    if ($moddrv =~ /Com/i) {$type = 'commentary';}
    
    $info{$proj}{'type'} = $type;
  }
  
  if ($DEBUG) {&Log("info = ".Dumper(\%info)."\n"); }
  
  return \%info;
}

sub getScriptsToRun(\@\@$\%) {
  my $projectsAP = shift;
  my $script = shift;
  my $infoP = shift;
  
  my @run;
  
  # Certain module types have a limited set of scripts that can be run on them.
  my @bible = ('sfm2osis', 'osis2osis', 'osis', 'osis2sword', 'osis2html', 'osis2ebooks', 'osis2GoBible');
  my @dict = ('sfm2osis', 'osis2osis', 'osis', 'osis2sword');
  my @childrensBible = ('sfm2osis', 'osis2osis', 'osis', 'osis2sword', 'osis2html', 'osis2ebooks');
  my @commentary = ('sfm2osis', 'osis2osis', 'osis', 'osis2sword'); # never tried!: 'osis2html', 'osis2ebooks';
  
  my @sfm2all = @bible; splice(@sfm2all, 0, 2);
  my @osis2all = @bible; splice(@osis2all, 0, 3);
  
  my $scriptAP = ($script eq 'sfm2all' ? \@sfm2all:\@osis2all);
  
  # Assign scripts to be run
  foreach my $m (@{$projectsAP}) {
    my $type = $infoP->{$m}{'type'};
    my $typeAP;
    if    ($type eq 'bible')          {$typeAP = \@bible;}
    elsif ($type eq 'dict')           {$typeAP = \@dict;}
    elsif ($type eq 'childrensBible') {$typeAP = \@childrensBible;}
    elsif ($type eq 'commentary')     {$typeAP = \@commentary;}
    else {next;}
    
    if ($script =~ /(osis2all|sfm2all)/) {
      foreach my $scr (@{$scriptAP}) {
        foreach my $ok (@{$typeAP}) {
          if ($scr ne $ok) {next;}
          my $s = ($scr eq 'osis' ? &osisScript($m):$scr);
          my $arg = $infoP->{$infoP->{$m}{'configProject'}}{"$s+ARG_sfm2all_skip"};
          if ($script eq 'sfm2all' && $arg && $arg =~ /true/i) {
            print "WARNING: Skipping '$s $m' because config.conf ARG_sfm2all_skip = true\n";
            next;
          }
          push(@run, "$s $m");
        }
      }
    }
    else {
      foreach my $ok (@{$typeAP}) {
        if ($script ne $ok) {next;}
        my $s = $script;
        if ($script eq 'osis') {$s = &osisScript($m);}
        elsif ($script =~ /^(sfm2osis|osis2osis)$/) {
          if ($s ne &osisScript($m)) {next;}
        }
        push(@run, "$s $m");
      }
    }
  }
  
  return @run;
}

# Set dependencies for each conversion. Each dependency is a string with 
# script and a module, like: "$s $m", such that the given script must be 
# run on the given module before the dependency is considered met.
sub setDependencies(\%\@$\%) {
  my $depsHP = shift;
  my $runAP = shift;
  my $script = shift;
  my $infoP = shift;
    
  foreach my $r (@{$runAP}) {
    $depsHP->{$r} = [];
    
    $r =~ /^(\S+)\s+(\S+)$/;
    my $s = $1; my $m = $2;
    my %deps;
    
    if ($script =~ /^(osis|sfm2all|sfm2osis|osis2osis)$/) {
      if ($s eq 'sfm2osis' || $script eq 'osis2osis') {
        # sfm2osis DICT sub-modules depend on main OSIS
        if ($m eq &hasDICT($m)) {
          my $main = $m; $main =~ s/DICT$//;
          $deps{&osisScript($main).' '.$main}++;
        }
      }
      elsif ($s eq 'osis2osis') {
        # osis2osis modules depend on their source main & dict OSIS and 
        # possibly their main OSIS (if a DICT)
        my $sproj = $infoP->{$m}{'sourceProject'};
        $deps{&osisScript($sproj).' '.$sproj}++;
        if (my $dict = &hasDICT($sproj)) {
          $deps{&osisScript($dict).' '.$dict}++;
        }
        if ($m eq &hasDICT($m)) {
          my $main = $m; $main =~ s/DICT$//;
          $deps{&osisScript($main).' '.$main}++;
        }
      }
      elsif ($s =~ /^(osis2GoBible)$/) {
        # these depend only on their OSIS file
        $deps{&osisScript($m).' '.$m}++;
      }
      elsif ($s =~ /^(osis2html|osis2ebooks|osis2sword)$/) {
        # these depend on both main and dict (if exists) OSIS files
        $deps{&osisScript($m).' '.$m}++;
        if (my $dict = &hasDICT($m)) {
          $deps{&osisScript($dict).' '.$dict}++;
        }
      }
    }
    
    if ($s =~ /^(osis2sword)$/) {
      # The main SWORD module must be created first, because its links 
      # to the dict SWORD module are checked when the dict is created.
      if ($m eq &hasDICT($m)) {
        my $main = $m; $main =~ s/DICT$//;
        $deps{"osis2sword $main"}++;
      }
    }
    
    push(@{$depsHP->{$r}}, (keys %deps));
  }
  
  if ($DEBUG) {&Log("DEPENDENCIES = ".Dumper($depsHP)."\n");}
}

# Run osis-converters on a module, and report.
sub runScript($$) {
  my $pdir = shift;
  my $run = shift;
  
  $run =~ /^(\S+)\s+(\S+)$/;
  my $script = $1; my $mod = $2;
  
  my $p = $mod;
  my $dict = ($p =~ s/DICT$// ? $p.'DICT':'');
  my $path = $pdir.'/'.$p.($dict ? '/'.$dict:'');
  
  my $cmd = "./$script.pl \"$path\"";
  print "Started: $cmd\n";
  my $result = decode('utf8', `$cmd  2>&1`);

  my @errors;
  foreach my $line (split(/\n+/, $result)) {
    if ($line !~ /ERROR/) {next;}
    push(@errors, "$mod $line");
  }
  
  if (@errors) {
    &Log(sprintf("\nFAILED:  %12s %9s FINISHED WITH %i ERROR(s).\n", 
          $script, 
          $mod, 
          scalar @errors
    ));
    foreach my $e (@errors) {&Log("$e\n");}
    &Log("\n");
    return;
  }
  
  &Log(sprintf("SUCCESS! %12s %9s is FINISHED.\n", 
        $script, 
        $mod
  ));
}

sub updateConfigFiles(\@\%\%$) {
  my $projAP = shift;
  my $configHP = shift;
  my $infoP = shift;
  my $restore = shift;
  
  if (!(scalar keys %{$configHP})) {
    &Log("No config.conf changes to be made.\n\n");
    return;
  }
  
  my @updated;
  if (!$restore) {
    &Log("Config changes which are being applied to config.conf files: ".
      Dumper($configHP)."\n"); 
    
    foreach my $proj (@{$projAP}) {
      if (!-e "$PRJDIR/$proj/config.conf") {next;}
      push(@updated, "$PRJDIR/$proj/config.conf");
      
      &move("$PRJDIR/$proj/config.conf", "$PRJDIR/$proj/config.conf.bak") 
        or die "Move failed: $!";
      open(INC, "<:encoding(UTF-8)", "$PRJDIR/$proj/config.conf.bak") 
        or die "Could not read: $!";
      open(OUTC, ">:encoding(UTF-8)", "$PRJDIR/$proj/config.conf") 
        or die "Could not write: $!";
      
      my $section = $proj;
      while(<INC>) {
        if ($_ =~ /^\[([^\]]+)\]\s*$/) {
          $section = $1;
        }
        elsif ($_ =~ /^([^#]\S*)\s*=\s*(.*?)\s*$/) {
          my $e = $1; my $v = $2;
          foreach my $sc (keys %{$configHP}) {
            foreach my $ec (keys %{$configHP->{$sc}}) {
              if (!($sc eq $section && $ec eq $e)) {next;}
              $_ = '#'.$_;
              print "Commenting $proj config.conf: $_";
            }
          }
        }
        print OUTC $_;
      }
      close(INC);
      
      print OUTC "\n";
      foreach my $sc (keys %{$configHP}) {
        foreach my $ec (keys %{$configHP->{$sc}}) {
          my $l1 = "[$sc]"; my $l2 = "$ec = ".$configHP->{$sc}{$ec};
          print "Appending to $proj config.conf: $l1 $l2\n";
          print OUTC "$l1\n$l2\n";
        }
      }
      close(OUTC);
      
    }
    &Log("Changed ".@updated." config.conf files.\n");
  }
  else {
    foreach my $proj (@{$projAP}) {
      if ( !-e "$PRJDIR/$proj/config.conf" || 
           !-e "$PRJDIR/$proj/config.conf.bak" ) {
        next;
      }
      push(@updated, "$PRJDIR/$proj/config.conf");
      unlink("$PRJDIR/$proj/config.conf");
      &move("$PRJDIR/$proj/config.conf.bak", "$PRJDIR/$proj/config.conf") 
        or &Log("Move failed: $!\n");
    }
    &Log("Restored ".@updated." config.conf files.\n");
  }
  &Log("\n");
  
}

# Returns the DICT sub-module name if the module is or has a DICT 
# sub-module.
sub hasDICT($\%) {
  my $m = shift;
  my $infoP = shift;
  
  $infoP = ($infoP ? $infoP:$INFO);
  
  # Only updated projects are considered
  my $dict;
  if ($infoP->{$m}{'updated'}) {
  
    # If this project has a sourceProject, we must look at 
    # sourceProject's conf.
    my $sproj = ( $infoP->{$m}{'sourceProject'} ? 
      $infoP->{$m}{'sourceProject'}:$infoP->{$m}{'configProject'} );
   
    # It must have a sub-module which follows all the rules.
    my $modDrv = $infoP->{$sproj}{$sproj."DICT+ModDrv"};
    if ($modDrv && $modDrv =~ /LD/) {
      $dict = ($m !~ /DICT$/ ? $m.'DICT':$m);
    }
  }

  return $dict;
}

# Returns the script used to create the module's OSIS file (sfm2osis or 
# osis2osis)
sub osisScript($) {
  my $m = shift;
  
  if (!$INFO->{$m}{'sourceProject'}) {
    return 'sfm2osis';
  }
  
  if (!&hasDICT($m)) {
    return 'osis2osis';
  }
  
  my $main = $m; $main =~ s/DICT$//;
  return ($INFO->{$main}{'CCOSIS'}{$m} ? 'osis2osis':'sfm2osis');
}

# Return the output directory where the OSIS file will go.
sub outdir(\%$) {
  my $infoP = shift;
  my $m = shift;
  
  my $p = $m; $p =~ s/DICT$//;
  
  my $outdir = $infoP->{$p}{'system+OUTDIR'};
  if ($infoP->{$p}{'sourceProject'}) {
    $outdir = $infoP->{$infoP->{$p}{'sourceProject'}}{'system+OUTDIR'};
  }
  
  $outdir = ( $outdir ? $outdir : 
              "$PRJDIR/$p/".($m =~ /DICT$/ ? "$m/":'')."outdir"
            );
  
  return $outdir;
}

sub timer($) {
  my $do = shift;
 
  if ($do =~ /start/i) {
    &Log("start time: ".localtime()."\n");
    $STARTTIME = DateTime->now();
  }
  elsif ($do =~ /stop/i) {
    &Log("\nend time: ".localtime()."\n");
    if ($STARTTIME) {
      my $now = DateTime->now();
      my $e = $now->subtract_datetime($STARTTIME);
      &Log("elapsed time: ".
            ($e->hours ? $e->hours." hours ":'').
            ($e->minutes ? $e->minutes." minutes ":'').
            $e->seconds." seconds\n");
    }
    $STARTTIME = '';
  }
  else {&Log("\ncurrent time: ".localtime()."\n");}
}

# Return the number of projects currently running, and print a message
# every so often, or anytime $now is set (and will also write this to 
# the log file if $now is set to 'log').
sub working(\@\%$) {
  my $startedAP = shift;
  my $doneHP = shift;
  my $now = shift;

  my @working;
  foreach my $r (@{$startedAP}) {
    if (!$doneHP->{$r}) {push(@working, $r);}
  }
  
  if ($now || !$WAIT) {
    my $msg = "Working on: \n\t".join("\n\t", @working)."\n";
    if ($PAUSED) {$msg .= "Press p again to continue scheduling.\n";}
    if ($now && $now =~ /log/i) {&Log($msg);}
    else {print $msg;}
    
    $WAIT = 15; # 30 seconds at 2 second sleeps
  }
  
  $WAIT--;
  
  return scalar @working;
}

sub readKey() {
  $KEY = ReadKey(-1);
  $KEY = ($KEY ? ord($KEY):0);
  if ($KEY == 112) {
    $PAUSED = ($PAUSED ? 0:1);
    if ($PAUSED) {
      print "\nThe scheduler is currently PAUSED.\n";
    }
    else {
      print "\nRestarting the scheduler...\n";
    }
  }
  elsif ($KEY == 27) {
    print "ESC was pressed...\n";
  }
}

sub Log($$) {
  my $p = shift;

  print encode("utf8", $p);
  
  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die;
  print LOGF $p;
  close(LOGF);
}
