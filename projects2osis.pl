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

my @projects;
foreach my $k (sort keys %{$INFO}) {
  if ($INFO->{$k}{'updated'}) {push(@projects, $k);}
}

&Log("Creating OSIS files:\n");
foreach my $m (@projects) {
  my $deps = join(', ', @{$INFO->{$m}{'dependencies'}});
  &Log(sprintf("%12s:%-16s %s\n", $m, $deps, &outdir($m)));
}
&Log("\n");

my $NUM_THREADS :shared = 0;
my %DONE :shared;
while (@projects) {

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
    splice(@projects, $x, 1);
    if (@projects) {&Log("NOTE: ".@projects." waiting...\n");}
  }

  sleep(2);
}
foreach my $thr (threads->list()) {$thr->join();}

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
  foreach my $sub (@subs) {
    if ($sub =~ /^($SKIP)$/) {next;}
    if ($sub =~ /^\./ || !-d "$pdir/$sub") {next;}
   
    $info{$sub}{'dependencies'} = [];
      
    if (-e "$pdir/$sub/CF_osis2osis.txt") {
      open(CF, "<:encoding(UTF-8)", "$pdir/$sub/CF_osis2osis.txt") || die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          my $d = $1;
          push(@{$info{$sub}{'dependencies'}}, (split(/\s*,\s*/, $d)));
        }
      }
      close(CF);
      if (@{$info{$sub}{'dependencies'}}) {$info{$sub}{'updated'}++;}
      next;
    }
    elsif (!-e "$pdir/$sub/config.conf") {next;}
    
    open(CONF, "<:encoding(UTF-8)", "$pdir/$sub/config.conf") || die;
    
    my $section = $sub;
    while(<CONF>) {
      if ($_ =~ /^\[(.*?)\]\s*$/) {
        $section = $1;
        
        # if config.conf has a [system] section, modules are considered updated
        if ($section eq 'system' && !$info{$sub}{'updated'}) {
          $info{$sub}{'updated'}++;
          if (-e "$pdir/$sub/$sub".'DICT') {
            # initialize the DICT module
            $info{$sub.'DICT'}{'updated'}++;
            $info{$sub.'DICT'}{'dependencies'} = [];
            push(@{$info{$sub.'DICT'}{'dependencies'}}, $sub);
          }
        }
      }
      elsif ($_ =~ /^(\S+)\s*=\s*(.*?)\s*$/) {
        $info{$sub}{"$section+$1"} = $2;
      }
    }
    close(CONF);
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
  
  &Log(sprintf("%13s SUCCESS: FINISHED with no errors.\n", $mod));
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

sub Log($$) {
  my $p = shift;

  print encode("utf8", $p);
  
  open(LOGF, ">>:encoding(UTF-8)", $LOGFILE) || die;
  print LOGF $p;
  close(LOGF);
}
