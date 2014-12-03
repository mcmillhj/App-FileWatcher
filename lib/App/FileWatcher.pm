package App::FileWatcher; 

use Moo; 
use namespace::clean;

use Carp qw(croak);
use English qw(-no_match_vars);
use File::Find::Rule; 
use File::stat qw(stat); 
use File::Touch; 
use Path::Tiny qw(path);
use Readonly; 
use Types::Standard qw(InstanceOf CodeRef);

Readonly my $SECONDS_IN_MINUTE => 60;
Readonly my $TRIGGER_NAME => '.trigger-' . time;

=item directory

directory to watch

=cut

has 'directory' => (
   is       => 'ro', 
   required => 1,
   coerce   => sub { path($_[0])->stringify }, 
);

=item pattern 

regular expression to match against files in the watch directory

=cut 

has 'pattern' => (
   is       => 'ro', 
   required => 1,
   coerce   => sub { qr/$_[0]/ },
);

=item action 

coderef to execute when _can_fire returns true 

=cut

has 'action' => (
   is       => 'ro',
   isa      => InstanceOf[CodeRef],
   required => 1,
);

=item polltime

time, in seconds, to sleep between polling the watch directory

=cut

has 'polltime' => (
   is      => 'ro',
   default =>  sub { $SECONDS_IN_MINUTE * 10 },
);

=item BUILD

construct a new instance of FileWatcher and validate conditions
required for watching files:
   - verifies that the directory to be watched exists
   - writes the hidden trigger file to the watch directory

=cut

sub BUILD {
   my ($self) = @_; 
   
   die "specified directory '" . $self->directory . "' does not exist"
       unless -d $self->directory;

   die 'Unable to install trigger in directory ' . $self->directory
       unless $self->_install_trigger;
}

sub watch {
   my ($self) = @_;
   
   $self->_poll;
}

=item _install_trigger 

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

sub _install_trigger {
   my ($self) = @_; 

   my $trigger = path($self->directory, $TRIGGER_NAME)->stringify;
   if ( ! -e $trigger && ! touch($trigger) ) {
      return 0; 
   }

   return 1;
}

=item _poll

loops forever, polling the trigger file to determine if the trigger can be
fired

=cut

sub _poll {
   my ($self) = @_;

   while ( 1 ) {
      if ($self->_can_fire) {
         $self->_fire;
      }
      sleep($self->polltime); 
   }
}

=item _can_fire

tests whether this trigger can fire, given the modify timestamp of the 
.trigger-[unixtimestamp] file

=cut

sub _can_fire {
   my ($self) = @_; 

   my $trigger_filename = path($self->directory, $TRIGGER_NAME)->stringify;
   my $trigger_mtime = stat($trigger_filename)->mtime;
  
   my ($found) = grep { 
      stat($_)->mtime >= $trigger_mtime
   } File::Find::Rule->file
                     ->name($self->pattern)
                     ->in($self->directory);
   
   # update the trigger filename
   touch($trigger_filename);

   return 1 if $found;
   return 0;
}

=item _fire

apply the action specified for this trigger

on success: action is supplied 
on failure: dies with $EVAL_ERROR

=cut

sub _fire {
   my ($self) = @_; 

   eval {
      $self->action->();
   };
   if ( my $err = $EVAL_ERROR ) {
      die "Encountered an error while firing: $err";
   }
}

=item _clean_trigger

clean the hidden trigger file from the watch directory
(Note: currently not used)

on success: the hidden trigger file is deleted
on failure: dies with $OS_ERROR

=cut

sub _clean_trigger {
   my ($self) = @_;
   
   my $trigger_filename = $self->_build_trigger_filename;
   unlink($trigger_filename)
       or die "Error cleaning trigger file $trigger_filename: $OS_ERROR";
}

=item _build_trigger_filename

construct the trigger filename from the watch directory
and the $TRIGGER_NAME constant

=cut

sub _build_trigger_filename {
   my ($self) = @_;

   return path(
      $self->directory,
      $TRIGGER_NAME
   );
}

1; 
