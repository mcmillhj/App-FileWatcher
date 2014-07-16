#!/usr/bin/perl

use strict; 
use warnings; 

use feature qw(say);
use App::FileWatcher; 

my $watcher = App::FileWatcher->new(
   pattern   => '.*txt',
   directory => '/tmp',
   action    => sub { say 'FIRING ACTION'; }, 
);


