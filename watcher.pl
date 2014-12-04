#!/usr/bin/perl 

use strict;
use warnings; 

use App::FileWatcher;
use Cwd;
use feature qw(say);
use Getopt::Declare;
use Path::Class qw(dir);
use Proc::Daemon;
use Readonly;

Readonly my $cwd => getcwd();
Readonly my $logfile => dir($cwd, 'log-' . time . '.txt');
Readonly my $pidfile => dir($cwd, 'pidfile.pid');

my $daemon = Proc::Daemon->new(
    pid_file => $pidfile,
    work_dir => $cwd,
);

# pid of running daemon or 0 if not running
my $pid = $daemon->Status($pidfile);
my $daemonize = 0;
Readonly my $ARGS => Getopt::Declare->new(
   join( "\n",
         '[strict]',
         "-daemonize\t 
             { daemonize() }",
         "-start\t  
             { start() }",
         "-status\t    
             { status() }",
         "-stop\t
             { stop() }",
         # '[mutex: -daemon -start -status -stop]',
   )
) || exit(1);

sub daemonize { 
   say 'daemonize';
   $daemonize = 1;
}

sub start {
   say 'start';
   if ( !$pid ) {
      print "Starting...\n";
      if ($daemonize) {
         # when Init happens, everything under it runs in the child process.
         # this is important when dealing with file handles, due to the fact
         # Proc::Daemon shuts down all open file handles when Init happens.
         # Keep this in mind when laying out your program, particularly if
         # you use filehandles.
         $daemon->Init;
      }
      
      while ( 1 ) {
         open(my $log_fh, '>>', $logfile);
         # any code you want your daemon to run here.
         # this example writes to a filehandle every 5 seconds.
         print {$log_fh} "Logging at " . time() . "\n";
         close {$log_fh};
         sleep 5;
      }
   } 
   else {
      print "Already Running with pid $pid";
   }
}

sub stop {
   say 'stop';
   if ( $pid ) {
      print "Stopping pid $pid...\n";
      if ($daemon->Kill_Daemon($pidfile)) {
         print "Successfully stopped.\n";
      } 
      else {
         print "Could not find $pid.  Was it running?\n";
      }
   } 
   else {
      print "Not running, nothing to stop.\n";
   }
}

sub status {
   say 'status';
   if ( $pid ) {
      print "Running with pid $pid.\n";
   } 
   else {
      print "Not running.\n";
   }
}
