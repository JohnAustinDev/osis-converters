#!/usr/bin/perl

# Create a new OSIS file for every project, as quickly as possible

use strict;
use warnings;
use threads;
use threads::shared;
use DateTime;
use Encode;

if ($0 ne "./projects2osis.pl") {
  print "\nRun this script from the osis-converters directory.\n";
  exit;
}

my $SKIP = "none";

my $PRJDIR = shift;     # path to directory containing osis-converters projects
my $maxthreads = shift; # optional max number of threads to use (default is number of CPUs)

if (!$maxthreads) {
  $maxthreads = `lscpu | egrep "^CPU\\(s\\)\\:"`;
  $maxthreads =~ s/^.*?\s+(\d+)\s*$/$1/;
}
   
if (!$PRJDIR || !-e "$PRJDIR" || !$maxthreads || $maxthreads != (1*$maxthreads)) {
  print "\nusage: projects2osis.pl projects_directory [max_threads]\n\n";
  exit;
}
$PRJDIR =~ s/\/$//;

my $LOGFILE = "$PRJDIR/OUT_projects2osis.txt";
if (-e $LOGFILE) {unlink($LOGFILE);}

my $STARTTIME;
&timer('start'); &Log("\n");

my $INFO = &getProjectInfo($PRJDIR);

my @projects; my @ignore;
foreach my $k (sort keys %{$INFO}) {
  if ($INFO->{$k}{'updated'}) {push(@projects, $k);}
  else {push(@ignore, $k);}
}

&Log("Creating ".@projects." OSIS files:\n");
foreach my $m (@projects) {
  my $deps = join(', ', @{$INFO->{$m}{'dependencies'}});
  &Log(sprintf("%12s:%-16s %s\n", $m, $deps, &outdir($m)));
}
&Log("\n");

&Log("Ignoring ".@ignore." project directories:\n");
foreach my $m (@ignore) {&Log(sprintf("%12s\n", $m));}
&Log("\n");

my $NUM_THREADS :shared = 0;
my %DONE :shared;
my @started :shared;
my $wait = 3; 
while (&working(\@started, \%DONE) || @projects) {

  while ($NUM_THREADS < $maxthreads && @projects) {
    # Start another OSIS conversion, skipping over any 
    # project whose dependency OSIS file(s) are not done.
    my $x = -1;
    my $ok;
    do {
      $x++;
      $ok = 1;
      foreach my $d (@{$INFO->{$projects[$x]}{'dependencies'}}) {
        if (!$DONE{$d}) {$ok = 0;}
      }
    } while ($x < $#projects && !$ok);
    
    if (@{$INFO->{$projects[$x]}{'dependencies'}}) {
      if (!$ok) {last;}
      &Log("NOTE: Dependencies of ".$projects[$x]." are done: ".
      join(', ', @{$INFO->{$projects[$x]}{'dependencies'}})."\n");
    }
    
    threads->create(sub {
      &createOSIS($PRJDIR, $projects[$x]);
      $NUM_THREADS--;
      $DONE{$projects[$x]}++; 
    });
    
    $NUM_THREADS++;
    push(@started, splice(@projects, $x, 1));
    if (@projects) {print("There are ".@projects." projects left...\n");}
  }

  sleep(2);
}
print "No more projects to start and none are running!\n";
foreach my $th (threads->list()) {$th->join();}

&timer('stop');

########################################################################
########################################################################

# Fills a hash with information about all projects in pdir
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
 
    $info{$proj}{'dependencies'} = [];
      
    if (-e "$pdir/$proj/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$proj/CF_osis2osis.txt") || die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $sourceProject = $1;
          $info{$proj}{'updated'}++;
          $info{$proj}{'osis2osis'} = $sourceProject;
          push(@{$info{$proj}{'dependencies'}}, $sourceProject);
        }
      }
      close(CF);
      next;
    }
    elsif (!-e "$pdir/$proj/config.conf") {next;}
    else {
      open(CONF, "<:encoding(UTF-8)", "$pdir/$proj/config.conf") || die;
      my $section = $proj;
      while(<CONF>) {
        if ($_ =~ /^\[(.*?)\]\s*$/) {
          $section = $1;
          # If config.conf has a [system] section, its modules are 
          # considered updated.
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
  
  # Now add any Companion modules
  foreach my $proj (keys %info) {
    my $sourceProject = $info{$proj}{'osis2osis'};
    my $sourceCompanion;
    my $companion; 
    if ($sourceProject) {
      $sourceCompanion = $info{$sourceProject}{"$sourceProject+Companion"};
      if ($sourceCompanion) {
        $companion = $sourceCompanion; 
        $companion =~ s/^$sourceProject/$proj/;
      }
    }
    else {
      $companion = $info{$proj}{"$proj+Companion"};
    }
    
    if ($companion) {
      $info{$companion}{'dependencies'} = [];
      push(@{$info{$companion}{'dependencies'}}, $proj);
      
      # If dependant on a project with a DICT, add that DICT as depen-
      # dencies to proj and companion, plus add the source project as
      # dependency to companion.
      if ($sourceCompanion) {
        push(@{$info{$proj}{'dependencies'}}, $sourceCompanion);
        push(@{$info{$companion}{'dependencies'}}, $sourceCompanion);
        push(@{$info{$companion}{'dependencies'}}, $sourceProject);
      }
      
      $info{$companion}{'updated'} = $info{$proj}{'updated'};
    }
  }
  
  return \%info;
}

# Run osis-converters on a module to create its OSIS file, and report.
sub createOSIS($$) {
  my $pdir = shift;
  my $mod = shift;
  
  my $p = $mod;
  my $dict = ($p =~ s/DICT$// ? $p.'DICT':'');
  my $path = $pdir.'/'.$p.($dict ? '/'.$dict:'');
  
  my $cmd;
  if (-e "$path/CF_osis2osis.txt") {
    $cmd = "./osis2osis.pl \"$path\"";
  }
  else {
    $cmd = "./sfm2osis.pl \"$path\"";
  }
  
  &Log(sprintf("%13s started: %s \n", $mod, $cmd));
  my $result = decode('utf8', `$cmd  2>&1`);
  
  my $errors = 0; my $c = $result; while ($c =~ s/error//i) {$errors++;}

  if ($errors) {
    &Log(sprintf("%13s FAILED: FINISHED WITH %i ERROR(S) OUTDIR=%s\n", $mod, $errors, &outdir($mod)));
    my $inerr = 0;
    foreach my $line (split(/\n+/, $result)) {
      if ($line =~ /ERROR/) {&Log("$mod $line\n");}
    }
    &Log("\n");
    return;
  }
  
  &Log(sprintf("%13s SUCCESS: FINISHED!\n", $mod));
}

# Return the output directory where the OSIS file will go. This may 
# return the wrong directory for osis2osis.pl projects which use a 
# bootstrap.pl script which creates a config.conf at run time.
sub outdir($) {
  my $m = shift;
  
  my $p = $m; $p =~ s/DICT$//;
  my $outdir = $INFO->{$p}{'system+OUTDIR'};
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
  my $doneP = shift;
  my $now = shift;

  my @working;
  foreach my $m (@{$startedAP}) {if (!$doneP->{$m}) {push(@working, $m);}}
  
  if ($now || !$wait) {
    print "Working on project(s): ".join(', ', @working)."\n";
    $wait = 15; # 30 seconds at 2 second sleeps
  }
  
  $wait--;
  
  return scalar @working;
}

sub Log($$) {
  my $p = shift;

  print encode("utf8", $p);
  
  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die;
  print LOGF $p;
  close(LOGF);
}
