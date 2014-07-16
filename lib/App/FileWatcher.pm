package App::FileWatcher; 

use Moo; 
use namespace::clean;

use Data::Dumper; 

use Carp qw(croak);
use File::Find::Rule; 
use File::stat qw(stat); 
use File::Touch; 
use Path::Tiny qw(path);
use Readonly; 
use Types::Standard qw(InstanceOf CodeRef);

Readonly my $SECONDS_IN_MINUTE => 60;
Readonly my $TRIGGER_NAME      => '.trigger';

has 'directory' => (
   is       => 'ro', 
   required => 1,
   coerce   => sub { path($_[0])->stringify }, 
);

has 'pattern' => (
   is       => 'ro', 
   required => 1,
   coerce   => sub { qr/$_[0]/ },
);

has 'action' => (
   is       => 'ro',
   isa      => InstanceOf[CodeRef],
   required => 1,
);

has 'polltime' => (
   is      => 'ro',
   default =>  sub { $SECONDS_IN_MINUTE * 10 },
);

has 'hostname' => (
   is      => 'ro',
   default => sub { 'localhost' },
);

has 'protocol' => (
   is      => 'ro',
   default => sub { 'ssh' },
);

sub BUILD {
   my ($self) = @_; 

   if ( ! -d $self->directory ) {
      croak "specified directory '" . $self->directory . "' does not exist";
   } 

   if ( !$self->install_trigger ) {
      croak 'Unable to install trigger in directory ' . $self->directory; 
   }
   $self->poll; 
}

=item install_trigger 

Creates a hidden file named .trigger in the directory specified by 
$self->directory

preconditions: 
   1. trigger file does not exist
   2. userid executing this program has permissions to write files 
      $self->directory

postconditions: 
   1. trigger file exists in $self->directory

on success: returns true
on failure: returns false

=cut

sub install_trigger {
   my ($self) = @_; 

   my $trigger = path($self->directory,$TRIGGER_NAME)->stringify;
   if ( ! -e $trigger && !touch($trigger) ) {
      return 0; 
   }

   return 1;
}

=item poll

loops forever, polling the trigger file to determine if the trigger can be
fired

=cut

sub poll {
   my ($self) = @_;

   while ( 1 ) {
      if ($self->can_fire) {
         $self->fire;
         die; 
      }

      sleep($self->polltime); 
   }
}

=item can_fire

tests whether this trigger can fire, given the modify timestamp of the 
.trigger file

=cut

sub can_fire {
   my ($self) = @_; 

   my $trigger_filename = path($self->directory, $TRIGGER_NAME)->stringify;
   my $trigger_mtime = stat($trigger_filename)->mtime;
   my $pat = $self->pattern; 
  
   # update the trigger filename
   touch($trigger_filename);

   return 1 
      if grep { 
            stat($_)->mtime >= $trigger_mtime && m/$pat/i 
         } File::Find::Rule->file->in($self->directory);

   return 0;
}

sub fire {
   my ($self) = @_; 

   $self->action->();
}

1; 
