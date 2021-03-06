#!/usr/bin/perl

# Run specified conversions for every project, as quickly as possible

# Bootstrap osis-converters so project config files can be read.
use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl";

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
my %CONFIG; # $CONFIG{(MAINMOD|DICTMOD|section)}{config-entry} = value
#$CONFIG{'osis2ebooks'}{'CreateFullBible'} = 'false';
#$CONFIG{'osis2ebooks'}{'CreateSeparatePubs'} = 'false';
#$CONFIG{'osis2ebooks'}{'CreateSeparateBooks'} = 'first';
#$CONFIG{'osis2ebooks'}{'CreateTypes'} = 'epub';
#$CONFIG{'osis2html'}{'CreateFullBible'} = 'false';
#$CONFIG{'osis2html'}{'CreateSeparatePubs'} = 'false';
#$CONFIG{'osis2html'}{'CreateSeparateBooks'} = 'first';
#$CONFIG{'osis2sword'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2GoBible'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2html'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2ebooks'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'MAINMOD'}{'AddScripRefLinks'} = 'false';
#$CONFIG{'MAINMOD'}{'AddDictLinks'} = 'false';
#$CONFIG{'MAINMOD'}{'AddCrossRefs'} = 'false';
#$CONFIG{'DICTMOD'}{'AddSeeAlsoLinks'} = 'false';
#$CONFIG{'system'}{'DEBUG'} = '1';

# This takes 45 minutes so skip it...
$CONFIG{'GRG:osis2GoBible'}{'ARG_sfm2all_skip'} = 'true';

my $SKIP = '^(none)$'; # skip particular modules or sub-modules

if ($0 ne "./projects.pl") {
  print "\nRun this script from the osis-converters directory.\n";
  exit;
}

# path to directory containing osis-converters projects
my $PRJDIR = shift;

# regex matching modules to run
my $MODRE = shift;

# conversions to run on matched modules
my $CONVERSIONS = shift;

# optional max number of threads to use (default is number of CPUs)
my $MAXTHREADS = shift; 

if (!$MODRE) {$MODRE = 'all';}
if (!$CONVERSIONS) {$CONVERSIONS = 'osis';}
if ($CONVERSIONS !~ /^(osis|sfm2osis|osis2osis|osis2sword|osis2html|osis2ebooks|osis2GoBible|osis2all|sfm2sword|sfm2html|sfm2ebooks|sfm2GoBible|sfm2all)$/) {
  print "Unrecognzed script argument: $CONVERSIONS\n";
  $CONVERSIONS = '';
}

if (!$MAXTHREADS) {
  $MAXTHREADS = `lscpu | egrep "^CPU\\(s\\)\\:"`;
  $MAXTHREADS =~ s/^.*?\s+(\d+)\s*$/$1/;
}
   
if ( !$PRJDIR || !-e $PRJDIR || 
     !$CONVERSIONS || 
     !$MAXTHREADS || $MAXTHREADS != (1*$MAXTHREADS) 
   ) {
  print "
usage: projects.pl projects_directory [module_regex] [script] [max_threads]

projects_directory: The relative path from this script's directory to 
                    a directory containing osis-converters projects.
module_regex      : A regex matching modules to run, or 'all'. Default 
                    is 'all'.
script            : The conversion(s) to run on each project. Default 
                    is osis (which will run sfm2osis or osis2osis 
                    depending on the project). The other options are 
                    sfm2osis, osis2osis, osis2sword, osis2html, 
                    osis2ebooks, osis2GoBible, osis2all sfm2sword, 
                    sfm2html, sfm2ebooks, sfm2GoBible and sfm2all.
max_threads       : The number of threads to use. Default is the number 
                    of CPUs.
";
  exit;
}
$PRJDIR =~ s/\/$//;

my %PRINTED;
my $MYLOG = "$PRJDIR/OUT_projects.txt";
if (-e $MYLOG) {unlink($MYLOG);}

my $STARTTIME;
&timer('start'); &pLog("\n");

my $INFO = &getProjectInfo($PRJDIR);

my @MODULES; my @MODULE_IGNORES;
my %MAINS;   my %MAIN_IGNORES;
foreach my $m (sort keys %{$INFO}) {
  if ($MODRE && $MODRE !~ /^all$/i && $m !~ /^$MODRE$/) {next;}
  if ($SKIP && $m =~ /$SKIP/) {next;}
  
  if ($INFO->{$m}{'runable'}) {
    push(@MODULES, $m);
    
    my $dict = &hasDICT($m);
    $MAINS{($dict && $dict =~ /^(.*?)DICT$/ ? $1:$m)}++;
  }
  else {
    push(@MODULE_IGNORES, $m);
    
    my $dict = &hasDICT($m);
    $MAIN_IGNORES{($dict && $dict =~ /^(.*?)DICT$/ ? $1:$m)}++;
  }
}

&pLog("Ignoring ".(scalar keys %MAIN_IGNORES)." projects which need upgrading (".@MODULE_IGNORES." modules):\n");
foreach my $m (@MODULE_IGNORES) {
  &pLog(sprintf("%12s\n", $m));
}
&pLog("\n");

# Update config files with any global changes, and then re-read info.
&updateConfigFiles(\@MODULES, \%CONFIG, $INFO);
$SIG{'INT'} = sub {&finish()};
$INFO = &getProjectInfo($PRJDIR);

my @RUN = &getScriptsToRun(\@MODULES, $CONVERSIONS, $INFO);

my %DEPENDENCY; &setDependencies(\%DEPENDENCY, \@RUN, $CONVERSIONS, $INFO, \@MODULES);

&pLog("Scheduling ".@RUN." jobs on ".(scalar keys %MAINS)." projects (".@MODULES." modules):\n");
foreach my $m (@MODULES) {
  foreach my $run (@RUN) {
    if ($run !~ /^(\S+)\s+$m$/) {next;}
    my $script = $1;
    my $deps = join(', ', @{$DEPENDENCY{$run}});
    my $depsmsg = ($deps ? "(after $deps)":'');
    $depsmsg =~ s/ (osis2osis|sfm2osis)//g;
    &pLog(sprintf("%12s:%12s %-35s %s\n", 
                  $m, 
                  $script,
                  $depsmsg, 
                  &outdir($INFO, $m)
    ));
  }
}
&pLog("\n");

ReadMode 4;

# Now run all jobs until there is nothing left to do, or the ESC key is 
# pressed.
&pLog("Running ".@RUN." jobs on ".(scalar keys %MAINS)." projects (".@MODULES." modules):\n");
my $NUM_THREADS :shared = 0;
my %DONE :shared;
my @STARTED :shared;
my $WAIT = 3;
my $KEY = 0;
my $PAUSED = 0;
my $KILLED = 0;
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
    
    sleep(2); # so jobs don't start at the same time, causing problems
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

if ($KEY == 27) {
  &pLog("\n");
  &pLog("
No more conversions will be scheduled...
Press ctrl-c to kill remaining threads and exit.
Or wait for the current threads to finish:\n");
&working(\@STARTED, \%DONE, 'log');
}
else {
  print "No more projects to start and none are running!\n";
}

&finish();

########################################################################
########################################################################

# Fill a hash with config.conf and CF_osis2osis.txt information for all
# projects in $pdir
sub getProjectInfo {
  my $pdir = shift;
  
  opendir(DIR, $pdir) or die;
  my @projects = readdir(DIR);
  closedir(DIR);
  
  my %info;
  foreach my $proj (@projects) {
    if ($proj =~ /^(defaults|utils|CB_Common|Cross_References)$/) {
      next;
    }
    if ($proj =~ /^\./ || !-d "$pdir/$proj") {
      next;
    }
    
    # - sourceProject is osis2osis source project, or else undef 
    # if OSIS will be created by sfm2osis (the usual case).
    # - configProject is the the MAIN module of a project if it has a
    # config.conf or else the MAIN module of the sourceProject if there 
    # is a sourceProject with a config.conf (projects with a 
    # CF_osis2osis.txt file might not have their own config.conf file 
    # until after osis2osis is run, so this script may reference the 
    # sourceProject's config.conf in such a case).
    
    if (-e "$pdir/$proj/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$proj/CF_osis2osis.txt") 
        or die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $sourceProject = $1;
          # If CF_osis2osis.txt has SET_sourceProject, its modules are
          # considered runnable.
          $info{$proj}{'runable'}++;
          $info{$proj}{'sourceProject'} = $sourceProject;
          $info{$proj}{'configProject'} = $sourceProject;
        }
        if ($_ =~ /^CCOSIS\:\s*(\S+)\s*$/) {
          $info{$proj}{'CCOSIS'}{$1}++;
        }
      }
      close(CF);
    }
    
    if (!-e "$pdir/$proj/config.conf") {next;}
    $info{$proj}{'configProject'} = $proj;
    
    # Projects where config.conf contains [system] are considered runnable
    my $cp = $info{$proj}{'configProject'};
    if (&shell("grep '\\[system\\]' \"$pdir/$cp/config.conf\"", 3, 1)) {
      $info{$proj}{'runable'}++;
      if (!defined($info{$cp}{'MainmodName'})) {
        our $CONF; &set_configuration_globals("$pdir/$cp", 'none');
        foreach my $k (keys %{$CONF}) {$info{$cp}{$k} = $CONF->{$k};}
      }
    }
  }
  
  # Create info for dict modules now
  foreach my $proj (keys %info) {
    if (!&hasDICT($proj, \%info)) {next;}
    # Only runnable DICT modules are returned by hasDICT()
    $info{$proj.'DICT'}{'runable'}++;
    $info{$proj.'DICT'}{'configProject'} = $info{$proj}{'configProject'};
    if ($info{$proj}{'sourceProject'}) {
      $info{$proj.'DICT'}{'sourceProject'} = $info{$proj}{'sourceProject'};
    }
  }
  
  # Add module types
  foreach my $m (keys %info) {
    if (!$info{$m}{'runable'}) {next;}
    
    my $cproj = $info{$m}{'configProject'};
    my $c2proj = ($m =~ /DICT$/ ? $cproj.'DICT':$cproj);
    
    my $moddrv = $info{$cproj}{"$c2proj+ModDrv"};
    
    my $type = 'bible';
    if ($moddrv =~ /LD/i) {$type = 'dict';}
    if ($moddrv =~ /GenBook/i) {$type = 'childrensBible';}
    if ($moddrv =~ /Com/i) {$type = 'commentary';}
    
    $info{$m}{'type'} = $type;
  }
  
  if ($DEBUG) {&pLog("info = ".Dumper(\%info)."\n");}

  return \%info;
}

sub getScriptsToRun {
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
    
    if ($script =~ /^(osis2all|sfm2all)$/) {
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
    elsif ($script =~ /^sfm2(sword|html|ebooks|GoBible)$/) {
      my $to = $1;
      push(@run, &osisScript($m)." $m");
      foreach my $ok (@{$typeAP}) {
        if ("osis2$to" ne $ok) {next;}
        push(@run, "osis2$to $m");
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
# script and module, like: "$s $m", such that the given script must be 
# run on the given module before that dependency is considered met. Each
# conversion has an array of these dependencies, all of which need to be
# met before the conversion should be run.
sub setDependencies {
  my $depsHP = shift;
  my $runAP = shift;
  my $script = shift;
  my $infoP = shift;
  my $modulesAP = shift;
    
  foreach my $r (@{$runAP}) {
    $depsHP->{$r} = [];
    
    if ($r !~ /^(\S+)\s+(\S+)$/) {print "\n$r\n"; die;}
    my $s = $1; my $m = $2;
    my %deps;
    
    # run's requiring the OSIS files to be rebuilt...
    if ($script =~ /^(osis|osis2osis)$/ || $script =~ /^sfm2/) {
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
    
    # include only those dependencies which are part of the current run
    my %modules; map($modules{$_}++, @{$modulesAP});
    foreach my $d (keys %deps) {
      if ($d !~ /^(\S+)\s+(\S+)$/) {next;}
      my $s = $1; my $m = $2;
      if (!exists($modules{$m})) {
        print "WARNING: Skipping dependence '$d' because $m is not being run.\n";
        next;
      }
      
      push(@{$depsHP->{$r}}, $d);
    }
  }
  
  if ($DEBUG) {&pLog("DEPENDENCIES = ".Dumper($depsHP)."\n");}
}

# Run osis-converters on a module, and report.
sub runScript {
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
    &pLog(sprintf("\nFAILED:  %12s %9s FINISHED WITH %i ERROR(s).\n", 
          $script, 
          $mod, 
          scalar @errors
    ));
    foreach my $e (@errors) {&pLog("$e\n");}
    &pLog("\n");
    return;
  }
  
  &pLog(sprintf("SUCCESS! %12s %9s is FINISHED.\n", 
        $script, 
        $mod
  ));
}

sub updateConfigFiles {
  my $projAP = shift;
  my $configHP = shift;
  my $infoP = shift;
  my $restore = shift;
  
  if (!(scalar keys %{$configHP})) {
    &pLog("No config.conf changes to be made.\n\n");
    return;
  }
  
  if (!$restore) {
    &pLog("Config changes which are being applied to config.conf files: ".
      Dumper($configHP)."\n");
      
    # Gather a list of unique config files to update
    my %update;
    foreach my $m (@{$projAP}) {
      $update{$infoP->{$m}{'configProject'}}++;
      if ($infoP->{$m}{'sourceProject'}) {
        $update{$infoP->{$m}{'sourceProject'}}++;
      }
    }
    
    # Update each config file in turn
    foreach my $m (keys %update) {
      &copy("$PRJDIR/$m/config.conf", "$PRJDIR/$m/.config.conf.bak") 
        or die "Move failed: $!";
      open(INC, "<:encoding(UTF-8)", "$PRJDIR/$m/.config.conf.bak") 
        or die "Could not read: $!";
      open(OUTC, ">:encoding(UTF-8)", "$PRJDIR/$m/config.conf") 
        or die "Could not write: $!";
      
      my $section = $m;
      while(<INC>) {
        if ($_ =~ /^\[([^\]]+)\]\s*$/) {
          $section = $1;
        }
        elsif ($_ =~ /^([^#]\S*)\s*=\s*(.*?)\s*$/) {
          my $e = $1; my $v = $2;
          foreach my $sc (keys %{$configHP}) {
            my $sec = $sc;
            my $mod = ($sec =~ s/^([^:]+):// ? $1:'');
            foreach my $ec (keys %{$configHP->{$sc}}) {
              if ( $sec eq $section && $ec eq $e &&
                    (!$mod || $mod eq $m) ) {
                $_ = '#'.$_;
                print "Commenting $m config.conf: $_";
              }
            }
          }
        }
        print OUTC $_;
      }
      close(INC);
      
      print OUTC "\n";
      foreach my $sc (keys %{$configHP}) {
        my $sec = $sc;
        my $mod = ($sec =~ s/^([^:]+):// ? $1:'');
        if ($sc eq 'MAINMOD') {$sec = $m;}
        elsif ($sc eq 'DICTMOD') {$sec = $m.'DICT';}
        foreach my $ec (keys %{$configHP->{$sc}}) {
          if ($mod && $mod ne $m) {next;}
          my $l1 = "[$sec]"; my $l2 = "$ec = ".$configHP->{$sc}{$ec};
          print "Appending to $m config.conf: $l1 $l2\n";
          print OUTC "$l1\n$l2\n\n";
        }
      }
      close(OUTC);
      
    }
    &pLog("Changed ".(scalar keys %update)." config.conf files.\n");
  }
  else {
    my @fs = split(/\n+/, &shell("find \"$PRJDIR\" -name .config.conf.bak"));
    foreach my $f (@fs) {
      my $t = $f; $t =~ s/\.(config\.conf)\.bak$/$1/;
      &move("$PRJDIR/$f", "$PRJDIR/$t");
    }
    &pLog("Restored ".@fs." config.conf files.\n");
  }
  &pLog("\n");
  
}

# Returns the DICT sub-module name if the module is or has a DICT 
# sub-module.
sub hasDICT {
  my $m = shift;
  my $infoP = shift;
  
  $infoP = ($infoP ? $infoP:$INFO);
  
  # Only runable projects can have dictionaries
  my $dict;
  if ($infoP->{$m}{'runable'}) {
  
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
sub osisScript {
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
sub outdir {
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

sub timer {
  my $do = shift;
 
  if ($do =~ /start/i) {
    &pLog("start time: ".localtime()."\n");
    $STARTTIME = DateTime->now();
  }
  elsif ($do =~ /stop/i) {
    &pLog("\nend time: ".localtime()."\n");
    if ($STARTTIME) {
      my $now = DateTime->now();
      my $e = $now->subtract_datetime($STARTTIME);
      &pLog("elapsed time: ".
            ($e->hours ? $e->hours." hours ":'').
            ($e->minutes ? $e->minutes." minutes ":'').
            $e->seconds." seconds\n");
    }
    $STARTTIME = '';
  }
  else {&pLog("\ncurrent time: ".localtime()."\n");}
}

# Return the number of projects currently running, and print or log a 
# message about the currently running projects.
my $LASTMSG;
sub working {
  my $startedAP = shift;
  my $doneHP = shift;
  my $logOrPrint = shift; # 'log' means log msg. Otherwise print msg. 

  my @working;
  foreach my $r (@{$startedAP}) {
    if (!$doneHP->{$r}) {push(@working, $r);}
  }
  
  if ($logOrPrint || !$WAIT) {
    my $msg = "Working on: \n\t".join("\n\t", @working)."\n";
    if (!$PAUSED) {$msg .= "Press p to pause the scheduler. ";}
    else {$msg .= "Press p again to continue scheduling. ";}
    if (!$KILLED) {$msg .= "Press ESC to kill the scheduler.\n";}
    
    if ($logOrPrint && $logOrPrint =~ /log/i) {&pLog($msg);}
    elsif ($msg ne $LASTMSG) {
      print $msg;
      $LASTMSG = $msg;
    }
    
    $WAIT = 15; # 30 seconds at 2 second sleeps
  }
  
  $WAIT--;
  
  return scalar @working;
}

sub readKey {
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
    $KILLED++;
    print "ESC was pressed...\n";
  }
}

sub finish {

  ReadMode 0;
  
  foreach my $th (threads->list()) {$th->join();}

  &updateConfigFiles(\@MODULES, \%CONFIG, $INFO, 'restore');

  &timer('stop');
  
  exit;
}

sub pLog {
  my $p = shift;

  print encode("utf8", $p);
  
  open(LOGF, ">>:encoding(UTF-8)", $MYLOG) || die;
  print LOGF $p;
  close(LOGF);
}
