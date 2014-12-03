#!/usr/bin/perl

use strict; 
use warnings; 

use App::FileWatcher; 
use feature qw(say);

my $watcher = App::FileWatcher->new(
   pattern   => 'test\.txt',
   directory => '~/tmp',
   action    => sub { say 'FIRED'; }, 
);
$watcher->watch;

