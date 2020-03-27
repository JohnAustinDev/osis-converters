#!/usr/bin/perl

# Create a new OSIS file for every project, as quickly as possible

use strict;
use warnings;
use threads;
use threads::shared;

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

&timer('start');

my $projectInfoP = &getProjectInfo($PRJDIR);

my @projects;
foreach my $k (sort keys %{$projectInfoP}) {
  if ($projectInfoP->{$k}{'updated'}) {push(@projects, $k);}
}

print "Creating new OSIS files for these projects:\n";
foreach my $p (@projects) {print "$p\n";}
print "\n";

my $NUM_THREADS :shared = 0;
my %DONE :shared;
while (@projects) {

  while ($NUM_THREADS < $maxthreads && @projects) {
    # Start another OSIS conversion, skipping over any osis2osis 
    # project whose source OSIS is not done.
    my $x = -1;
    my $sourceProject;
    do {
      if ($x > -1) {
        print "NOTE: Skipping ".$projects[$x]." until $sourceProject is done.";
      }
      $x++;
      $sourceProject = $projectInfoP->{$projects[$x]}{'sourceProject'};
    } while ($x < $#projects && $sourceProject && !$DONE{$sourceProject});
    if ($sourceProject && !$DONE{$sourceProject}) {last;}
    if ($sourceProject && $DONE{$sourceProject}) {
      print "NOTE: Source project $sourceProject of ".$projects[$x]." is done."
    }
    
    threads->create(sub {
      &createOSIS($PRJDIR, $projects[$x]);
      $NUM_THREADS--;
      $DONE{$projects[$x]}++; 
    });
    
    $NUM_THREADS++;
    splice(@projects, $x, 1);
    if (@projects) {print "NOTE: ".@projects." waiting...\n";}
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
    if (-e "$pdir/$sub/CF_osis2osis.txt") {
      $info{$sub}{'updated'}++;
      open(CF, "<:encoding(UTF-8)", "$pdir/$sub/CF_osis2osis.txt") || die;
      while(<CF>) {
        if ($_ =~ /^SET_sourceProject:(.*?)\s*$/) {
          $info{$sub}{'sourceProject'} = $1;
        }
      }
      close(CF);
      if (!$info{$sub}{'sourceProject'}) {die;}
      next;
    }
    elsif (!-e "$pdir/$sub/config.conf") {next;}
    
    open(CONF, "<:encoding(UTF-8)", "$pdir/$sub/config.conf") || die;
    
    my $section = $sub;
    while(<CONF>) {
      if ($_ =~ /^\[(.*?)\]\s*$/) {
        $section = $1;
        
        # if config.conf has a [system] section, modules are considered updated
        if ($section eq 'system') {
          $info{$sub}{'updated'}++;
          if (-e "$pdir/$sub/$sub".'DICT') {
            $info{$sub.'DICT'}{'updated'}++;
          }
        }
      }
      elsif ($_ =~ /^\S+\s*=\s*(.*?)\s*$/) {
        $info{$sub}{"$section+$1"} = $2;
      }
    }
    close(CONF);
  }
  
  return \%info;
}

# Run osis-converters on a module to create its OSIS file, and report.
sub createOSIS($) {
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
  
  printf("%8s started: %s \n", $mod, $cmd);
  my $result = `$cmd`;
  
  my $errors = 0; my $c = $result; while ($c =~ s/error//i) {$errors++;}

  if ($errors) {
    printf("%8s FAILED: FINISHED WITH %i ERROR(S)\n", $mod, $errors);
    return;
  }
  
  printf("%8s SUCCESS: FINISHED with no errors!!!!!\n", $mod);
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
      &Log("elapsed time: ".($e->hours ? $e->hours." hours ":'').($e->minutes ? $e->minutes." minutes ":'').$e->seconds." seconds\n", 1);
    }
    $STARTTIME = '';
  }
  else {&Log("\ncurrent time: ".localtime()."\n");}
}
