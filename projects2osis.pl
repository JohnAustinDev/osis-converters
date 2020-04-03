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
my $MAXTHREADS = shift; # optional max number of threads to use (default is number of CPUs)

if (!$MAXTHREADS) {
  $MAXTHREADS = `lscpu | egrep "^CPU\\(s\\)\\:"`;
  $MAXTHREADS =~ s/^.*?\s+(\d+)\s*$/$1/;
}
   
if (!$PRJDIR || !-e "$PRJDIR" || !$MAXTHREADS || $MAXTHREADS != (1*$MAXTHREADS)) {
  print "\nusage: projects2osis.pl projects_directory [max_threads]\n\n";
  exit;
}
$PRJDIR =~ s/\/$//;

my $LOGFILE = "$PRJDIR/OUT_projects2osis.txt";
if (-e $LOGFILE) {unlink($LOGFILE);}

my $STARTTIME;
&timer('start'); &Log("\n");

my $INFO = &getProjectInfo($PRJDIR);

my @PROJECTS; my @IGNORE;
foreach my $k (sort keys %{$INFO}) {
  if ($INFO->{$k}{'updated'}) {
    push(@PROJECTS, $k);
  }
  else {
    push(@IGNORE, $k);
  }
}

&Log("Updating ".@PROJECTS." OSIS files:\n");
foreach my $m (@PROJECTS) {
  my $deps = join(', ', @{$INFO->{$m}{'dependencies'}});
  &Log(sprintf("%12s:%-30s %14s %s\n", 
                $m, 
                ($deps ? " (after $deps)":''), 
                $INFO->{$m}{'script'}, 
                &outdir($INFO, $m)
  ));
}
&Log("\n");

&Log("Found ".@IGNORE." projects needing upgrade:\n");
foreach my $m (@IGNORE) {&Log(sprintf("%12s\n", $m));}
&Log("\n");

my $NUM_THREADS :shared = 0;
my %DONE :shared;
my @STARTED :shared;
my $WAIT = 3; 
while (&working(\@STARTED, \%DONE) || @PROJECTS) {

  while ($NUM_THREADS < $MAXTHREADS && @PROJECTS) {
    # Start another OSIS conversion, skipping over any 
    # project whose dependency OSIS file(s) are not done.
    my $x = -1;
    my $ok;
    do {
      $x++;
      $ok = 1;
      foreach my $d (@{$INFO->{$PROJECTS[$x]}{'dependencies'}}) {
        if (!$DONE{$d}) {$ok = 0;}
      }
    } while ($x < $#PROJECTS && !$ok);
    
    if (@{$INFO->{$PROJECTS[$x]}{'dependencies'}}) {
      if (!$ok) {last;}
      &Log("NOTE: Dependencies of ".$PROJECTS[$x]." are done: ".
      join(', ', @{$INFO->{$PROJECTS[$x]}{'dependencies'}})."\n");
    }
    
    threads->create(sub {
      &createOSIS($PRJDIR, $PROJECTS[$x], $INFO->{$PROJECTS[$x]}{'script'});
      $NUM_THREADS--;
      $DONE{$PROJECTS[$x]}++; 
    });
    
    $NUM_THREADS++;
    push(@STARTED, splice(@PROJECTS, $x, 1));
    if (@PROJECTS) {print("There are ".@PROJECTS." projects left...\n");}
  }

  sleep(2);
}
print "No more projects to start and none are running!\n";
foreach my $th (threads->list()) {$th->join();}

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
 
    $info{$proj}{'dependencies'} = [];
      
    # Projects with a CF_osis2osis.txt file normally do not have their  
    # own config.conf file.
    if (-e "$pdir/$proj/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$proj/CF_osis2osis.txt") || die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $sourceProject = $1;
          # If CF_osis2osis.txt has SET_sourceProject, its modules are
          # considered updated and runnable.
          $info{$proj}{'updated'}++;
          $info{$proj}{'sourceProject'} = $sourceProject;
          push(@{$info{$proj}{'dependencies'}}, $sourceProject);
        }
        if ($_ =~ /^CCOSIS\:\s*(\S+)\s*$/) {
          $info{$proj}{'CCOSIS'}{$1}++;
        }
      }
      close(CF);
      $info{$proj}{'script'} = ($info{$proj}{'CCOSIS'}{$proj} ? 'osis2osis.pl':'sfm2osis.pl');
      next;
    }
    elsif (!-e "$pdir/$proj/config.conf") {next;}
    # Most projects have config.conf
    else {
      open(CONF, "<:encoding(UTF-8)", "$pdir/$proj/config.conf") || die;
      $info{$proj}{'script'} = 'sfm2osis.pl';
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
  
  # Add any Companion modules
  foreach my $proj (keys %info) {
    my $sourceProject = $info{$proj}{'sourceProject'};
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
      
      $info{$companion}{'script'} = 'sfm2osis.pl';
      if ($info{$proj}{'CCOSIS'}{$companion}) {
        $info{$companion}{'script'} = 'osis2osis.pl';
      }
      
      # If dependent on a project with a DICT, add that DICT as depen-
      # dencies for proj and companion, plus add the source project as
      # dependency for companion (it already is a dependency for proj).
      if ($sourceCompanion) {
        push(@{$info{$proj}{'dependencies'}}, $sourceCompanion);
        push(@{$info{$companion}{'dependencies'}}, $sourceCompanion);
        push(@{$info{$companion}{'dependencies'}}, $sourceProject);
        $info{$companion}{'sourceProject'} = $sourceProject;
      }
      
      if ($companion eq $proj.'DICT') {
        $info{$proj.'DICT'}{'updated'} = $info{$proj}{'updated'};
      }
    }
  }
  
  return \%info;
}

# Run osis-converters on a module to create its OSIS file, and report.
sub createOSIS($$$) {
  my $pdir = shift;
  my $mod = shift;
  my $script = shift;
  
  my $p = $mod;
  my $dict = ($p =~ s/DICT$// ? $p.'DICT':'');
  my $path = $pdir.'/'.$p.($dict ? '/'.$dict:'');
  
  my $cmd = "./$script \"$path\"";
  
  &Log(sprintf("%13s started: %s \n", $mod, $cmd));
  my $result = decode('utf8', `$cmd  2>&1`);
  
  my $errors = 0; my $c = $result; while ($c =~ s/error//i) {$errors++;}

  if ($errors) {
    &Log(sprintf("%13s FAILED: FINISHED WITH %i ERROR(S)\n", $mod, $errors));
    my $inerr = 0;
    foreach my $line (split(/\n+/, $result)) {
      if ($line =~ /ERROR/) {&Log("$mod $line\n");}
    }
    &Log("\n");
    return;
  }
  
  &Log(sprintf("%13s SUCCESS: FINISHED!\n", $mod));
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
  my $doneP = shift;
  my $now = shift;

  my @working;
  foreach my $m (@{$startedAP}) {if (!$doneP->{$m}) {push(@working, $m);}}
  
  if ($now || !$WAIT) {
    print "Working on project(s): ".join(', ', @working)."\n";
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
