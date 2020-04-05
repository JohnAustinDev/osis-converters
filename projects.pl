#!/usr/bin/perl

# Run specified conversions for every project, as quickly as possible

use strict;
use warnings;
use threads;
use threads::shared;
use DateTime;
use Encode;
use File::Copy;

# Config values may be set here to be applied to the config.conf of 
# every project run by this script.

my %CONFIG; # $CONFIG{(MOD|DICT|section)}{config-entry} = value
#$CONFIG{'osis2html'}{'CreateSeparatePubs'} = 'false';
#$CONFIG{'osis2html'}{'CreateSeparateBooks'} = 'false';
#$CONFIG{'osis2ebooks'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2GoBible'}{'ARG_sfm2all_skip'} = 'true';
#$CONFIG{'osis2sword'}{'ARG_sfm2all_skip'} = 'true';

if ($0 ne "./projects.pl") {
  print "\nRun this script from the osis-converters directory.\n";
  exit;
}

my $SKIP = "none";
my %PRINTED;

my $PRJDIR = shift;     # path to directory containing osis-converters projects
my $SCRIPT = shift;     # script to run on all projects
my $MAXTHREADS = shift; # optional max number of threads to use (default is number of CPUs)

if (!$SCRIPT) {$SCRIPT = 'osis';}
if ($SCRIPT !~ /^(osis|osis2sword|osis2html|osis2ebooks|osis2GoBible|osis2all|sfm2all)$/) {
  print "Unrecognzed script argument: $SCRIPT\n";
  $SCRIPT = '';
}

if (!$MAXTHREADS) {
  $MAXTHREADS = `lscpu | egrep "^CPU\\(s\\)\\:"`;
  $MAXTHREADS =~ s/^.*?\s+(\d+)\s*$/$1/;
}
   
if (!$PRJDIR || !-e "$PRJDIR" || !$SCRIPT || !$MAXTHREADS || $MAXTHREADS != (1*$MAXTHREADS)) {
  print "
usage: projects.pl projects_directory [script] [max_threads]

projects_directory: The relative path from this script's directory to 
                    a directory containing osis-converters projects.
script            : The conversion(s) to run on each project. Default 
                    is osis (which will run sfm2osis or osis2osis 
                    depending on the project). The other options are 
                    osis2sword, osis2html, osis2ebooks, osis2GoBible, 
                    osis2all and sfm2all.
max_threads       : The number of threads to use. Default is the number 
                    of CPUs.
";
  exit;
}
$PRJDIR =~ s/\/$//;

my $LOGFILE = "$PRJDIR/OUT_projects.txt";
if (-e $LOGFILE) {unlink($LOGFILE);}

my $STARTTIME;
&timer('start'); &Log("\n");

my $INFO = &getProjectInfo($PRJDIR);

my @MODULES; my @MODULE_IGNORES; my @MAINS; my @MAIN_IGNORES;
foreach my $m (sort keys %{$INFO}) {
  if ($INFO->{$m}{'updated'}) {
    push(@MODULES, $m);
    if (&projHasDICT($m) && $INFO->{$m}{'type'} eq 'dict') {
      next;
    }
    push(@MAINS, $m);
  }
  else {
    push(@MODULE_IGNORES, $m);
    if (&projHasDICT($m) && $INFO->{$m}{'type'} eq 'dict') {
      next;
    }
    push(@MAIN_IGNORES, $m);
  }
}

# Update config files with any global changes
&updateConfigFiles(\@MODULES, \%CONFIG, $INFO);
$INFO = &getProjectInfo($PRJDIR);

my @RUN = &getScriptsToRun(\@MODULES, $SCRIPT, $INFO);

my %DEPENDENCY; &setDependencies(\%DEPENDENCY, \@RUN, $SCRIPT, $INFO);

&Log("Running ".@RUN." jobs on ".@MAINS." projects (".@MODULES." modules):\n");
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

&Log("Found ".@MAIN_IGNORES." projects needing upgrade (".@MODULE_IGNORES." modules):\n");
foreach my $m (@MODULE_IGNORES) {&Log(sprintf("%12s\n", $m));}
&Log("\n");

# Now run all jobs until there is nothing left to do.
my $NUM_THREADS :shared = 0;
my %DONE :shared;
my @STARTED :shared;
my $WAIT = 3; 
while (&working(\@STARTED, \%DONE) || @RUN) {
  while ($NUM_THREADS < $MAXTHREADS && @RUN) {
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
        print "NOTE: Dependencies of ".$RUN[$x]." are not done:\n".
        join(', ', @{$DEPENDENCY{$RUN[$x]}})."\n";
        last;
      }
      print "NOTE: Dependencies of ".$RUN[$x]." are done:\n".
      join(', ', @{$DEPENDENCY{$RUN[$x]}})."\n";
    }
    
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
  }

  sleep(2);
}
print "No more projects to start and none are running!\n";
foreach my $th (threads->list()) {$th->join();}

&updateConfigFiles(\@MODULES, \%CONFIG, $INFO, 'restore');

&timer('stop');

########################################################################
########################################################################

# Fills a hash with config.conf or CF_osis2osis.txt information for all 
# projects in pdir
sub getProjectInfo($) {
  my $pdir = shift;
  
  opendir(DIR, $pdir) || die;
  my @subs = readdir(DIR);
  closedir(DIR);
  
  my %info;
  foreach my $proj (@subs) {
    if ($proj =~ /^($SKIP)$/) {next;}
    if ($proj =~ /^(defaults|utils|CB_Common|Cross_References)$/) {next;}
    if ($proj =~ /^\./ || !-d "$pdir/$proj") {next;}
 
    $info{$proj}{'osis_deps'} = [];
    
    # sourceProject is osis2osis source project, or empty 
    # if there is none.
    # configProject the the MAIN module of a project or the 
    # MAIN module of the sourceProject if there is one.
      
    # Projects with a CF_osis2osis.txt file normally do not have their  
    # own config.conf file. So some of their info will later be taken
    # from the parentProject config.conf.
    if (-e "$pdir/$proj/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$proj/CF_osis2osis.txt") || die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $sourceProject = $1;
          # If CF_osis2osis.txt has SET_sourceProject, its modules are
          # considered updated and runnable.
          $info{$proj}{'updated'}++;
          $info{$proj}{'sourceProject'} = $sourceProject;
          $info{$proj}{'configProject'} = $sourceProject;
          push(@{$info{$proj}{'osis_deps'}}, $sourceProject);
        }
        if ($_ =~ /^CCOSIS\:\s*(\S+)\s*$/) {
          $info{$proj}{'CCOSIS'}{$1}++;
        }
      }
      close(CF);
      $info{$proj}{'osis_script'} = ($info{$proj}{'CCOSIS'}{$proj} ? 'osis2osis':'sfm2osis');
      next;
    }
    elsif (!-e "$pdir/$proj/config.conf") {next;}
    # Most projects have config.conf
    else {
      open(CONF, "<:encoding(UTF-8)", "$pdir/$proj/config.conf") || die;
      $info{$proj}{'osis_script'} = 'sfm2osis';
      $info{$proj}{'configProject'} = $proj;
      my $section = $proj;
      while(<CONF>) {
        if ($_ =~ /^\[(.*?)\]\s*$/) {
          $section = $1;
          # If config.conf has a [system] section, its modules are 
          # considered updated and runnable.
          if ($section eq 'system' && !$info{$proj}{'updated'}) {
            $info{$proj}{'updated'}++;
          }
        }
        elsif ($_ =~ /^(\S+)\s*=\s*(.*?)\s*$/) {
          $info{$proj}{"$section+$1"} = $2;
        }
      }
      close(CONF);
    }
  }
  
  # Create info for any sub modules
  foreach my $proj (keys %info) {
    # Only updated projects are considered
    if (!$info{$proj}{'updated'}) {next;}
    
    # If this project has a sourceProject, we must the use sourceProject conf
    my $sproj = ($info{$proj}{'sourceProject'} ? $info{$proj}{'sourceProject'}:$proj);
    
    # If it doesnt have a sub-module which follows all the rules, ignore it.
    if ($info{$sproj}{$sproj."DICT+ModDrv"} !~ /LD/) {next;}
    
    $info{$proj}{'hasDICT'}++;
    $info{$proj.'DICT'}{'hasDICT'}++;
    
    $info{$proj.'DICT'}{'updated'}++;
    $info{$proj.'DICT'}{'configProject'} = $proj;
    
    if ($info{$proj}{'sourceProject'}) {
      $info{$proj.'DICT'}{'sourceProject'} = $info{$proj}{'sourceProject'};
    }
    
    $info{$proj.'DICT'}{'osis_script'} = 'sfm2osis';
    if ($info{$proj}{'CCOSIS'}{$proj.'DICT'}) {
      $info{$proj.'DICT'}{'osis_script'} = 'osis2osis';
    }
    
    push(@{$info{$proj.'DICT'}{'osis_deps'}}, $proj);
    
    if ($proj ne $sproj) {
      # If dependent on a project with a DICT, add that DICT as depen-
      # dencies for proj and companion, plus add the source project as
      # dependency for companion (it already is a dependency for proj).
      push(@{$info{$proj}{'osis_deps'}}, $sproj.'DICT');
      push(@{$info{$proj.'DICT'}{'osis_deps'}}, $sproj.'DICT');
      push(@{$info{$proj.'DICT'}{'osis_deps'}}, $sproj);
    }
  }
  
  # Add module type
  foreach my $proj (keys %info) {
    if (!$info{$proj}{'updated'}) {next;}
    my $c2proj = $info{$proj}{'configProject'};
    if ($proj =~ /DICT$/) {$c2proj .= 'DICT';}
    
    my $moddrv = $info{$info{$proj}{'configProject'}}{"$c2proj+ModDrv"};
    
    my $type = 'bible';
    if ($moddrv =~ /LD/i) {$type = 'dict';}
    if ($moddrv =~ /GenBook/i) {$type = 'childrensBible';}
    if ($moddrv =~ /Com/i) {$type = 'commentary';}
    
    $info{$proj}{'type'} = $type;
  }
  
  return \%info;
}

sub getScriptsToRun(\@\@$\%) {
  my $projectsAP = shift;
  my $script = shift;
  my $infoP = shift;
  
  my @run;
  
  # Certain module types have a limited set of scripts that can be run on them.
  my @bible = ('osis', 'osis2sword', 'osis2html', 'osis2ebooks', 'osis2GoBible');
  my @dict = ('osis', 'osis2sword');
  my @childrensBible = ('osis', 'osis2sword', 'osis2html', 'osis2ebooks');
  my @commentary = ('osis', 'osis2sword'); # never tried!: 'osis2html', 'osis2ebooks';
  
  my @sfm2all = @bible; 
  my @osis2all = @bible; splice(@osis2all, 1, 1);
  
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
          my $s = ($scr eq 'osis' ? $infoP->{$m}{'osis_script'}:$scr);
          if ($script eq 'sfm2all' && 
              $infoP->{$infoP->{$m}{'configProject'}}{"$s+ARG_sfm2all_skip"} =~ /true/i) {
            &Log("WARNING: Skipping '$s $m' because config.conf ARG_sfm2all_skip = true\n");
            next;
          }
          push(@run, "$s $m");
        }
      }
    }
    else {
      foreach my $ok (@{$typeAP}) {
        if ($script ne $ok) {next;}
        my $s = ($script eq 'osis' ? $infoP->{$m}{'osis_script'}:$script);
        push(@run, "$s $m");
      }
    }
  }
  
  return @run;
}
  
sub setDependencies(\%\@$\%) {
  my $depsHP = shift;
  my $runAP = shift;
  my $script = shift;
  my $infoP = shift;
    
  foreach my $r (@{$runAP}) {
    $r =~ /^(\S+)\s+(\S+)$/;
    my $s = $1; my $m = $2;
    
    $depsHP->{$r} = [];
    
    # Only osis and sfm2all involve dependencies
    if ($script !~ /^(osis|sfm2all)$/) {next;}
    
    # Add dependencies for OSIS file creation
    my @deps = @{$infoP->{$m}{'osis_deps'}};
    if (@deps) {
      push(@{$depsHP->{$r}}, map( $infoP->{$_}{'osis_script'}." $_", @deps ));
    }
    if ($s =~ /^(sfm2osis|osis2osis)$/) {next;}
    
    # Add dependencies for other scripts
    if ($s =~ /^osis2/) {
      # Each of these runs has a dependence on its own OSIS file.
      push(@{$depsHP->{$r}}, $infoP->{$m}{'osis_script'}." $m");
      
      # If there is a DICT companion, both main and dict are 
      # dependencies.
      my $companion = $infoP->{$infoP->{$m}{'configProject'}}{"$m+Companion"};
      if ($companion && &projHasDICT($m)) {
        push(@{$depsHP->{$r}}, $infoP->{$companion}{'osis_script'}." $companion");
      }
    }
  }
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
  
  my $errors = 0; my $c = $result; while ($c =~ s/error//i) {$errors++;}

  if ($errors) {
    &Log(sprintf("FAILED %s: FINISHED WITH %i ERROR(S)\n", $run, $errors));
    my $inerr = 0;
    foreach my $line (split(/\n+/, $result)) {
      if ($line =~ /ERROR/) {&Log("$mod $line\n");}
    }
    &Log("\n");
    return;
  }
  
  &Log(sprintf("SUCCESS %s: FINISHED!\n", $run));
}

sub updateConfigFiles(\@\%\%$) {
  my $projAP = shift;
  my $configHP = shift;
  my $infoP = shift;
  my $restore = shift;
  
  if (!$restore) {
    foreach my $proj (@{$projAP}) {
      if (!-e "$PRJDIR/$proj/config.conf") {next;}
      
      &move("$PRJDIR/$proj/config.conf", "$PRJDIR/$proj/config.conf.bak") or die "Move failed: $!";
      open(INC, "<:encoding(UTF-8)", "$PRJDIR/$proj/config.conf.bak") or die "Could not read: $!";
      open(OUTC, ">:encoding(UTF-8)", "$PRJDIR/$proj/config.conf") or die "Could not write: $!";
      
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
              &Log("Commenting $proj config.conf: $_");
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
          &Log("Appending to $proj config.conf: $l1 $l2\n");
          print OUTC "$l1\n$l2\n";
        }
      }
      close(OUTC);
      
    }
  }
  else {
    foreach my $proj (@{$projAP}) {
      if (!-e "$PRJDIR/$proj/config.conf") {next;}
      unlink("$PRJDIR/$proj/config.conf");
      &move("$PRJDIR/$proj/config.conf.bak", "$PRJDIR/$proj/config.conf") or &Log("Move failed: $!\n");
    }
  }
  &Log("\n");
  
}

# Returns true if the module is or has a DICT companion
sub projHasDICT($) {
  my $m = shift;
  
  return $INFO->{$INFO->{$m}{'configProject'}}{'hasDICT'};
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
  
  $outdir = ($outdir ? $outdir:"$PRJDIR/$p/".($m =~ /DICT$/ ? "$m/":'')."outdir");
  
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
      &Log("elapsed time: ".($e->hours ? $e->hours." hours ":'').($e->minutes ? $e->minutes." minutes ":'').$e->seconds." seconds\n");
    }
    $STARTTIME = '';
  }
  else {&Log("\ncurrent time: ".localtime()."\n");}
}

# Return the number of projects currently running, and print a message
# every so often.
sub working(\@\%$) {
  my $startedAP = shift;
  my $doneHP = shift;
  my $now = shift;

  my @working;
  foreach my $r (@{$startedAP}) {
    if (!$doneHP->{$r}) {push(@working, $r);}
  }
  
  if ($now || !$WAIT) {
    print "Working on: \n\t".join("\n\t", @working)."\n";
    $WAIT = 15; # 30 seconds at 2 second sleeps
  }
  
  $WAIT--;
  
  return scalar @working;
}

sub Log($$) {
  my $p = shift;

  print encode("utf8", $p);
  
  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die;
  print LOGF $p;
  close(LOGF);
}
