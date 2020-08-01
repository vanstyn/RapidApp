package RapidApp::Module::Grid::SearchBox;

use strict;
use warnings;

use Moo;
use Types::Standard ':all';

use RapidApp::Util qw(:all);

has 'grid_module', 
  is => 'ro', 
  isa => ConsumerOf['RapidApp::Module::StorCmp::Role::DbicLnk'], 
  required => 1;


has 'mode_name', 
  is => 'ro', 
  isa => Str,  
  required => 1;
  
has 'label',
  is => 'ro',
  isa => Str,
  required => 1;  
  
has 'choose_colummns',
  is => 'ro', 
  isa => Bool, 
  required => 1;


## Idea feature for future; arbirarary type-ahead functionality
#has 'type_ahead',
#  is => 'ro', 
#  isa => Bool, 
#  default => sub { 0 };


# Every subclass must implement this method:
sub chain_query_search_rs {
  my ($self, $Rs, $opt) = @_;
  
  ... 
}



sub searchbox_ext_config {
  my $self = shift;

  return {
    mode_name       => $self->mode_name,
    label           => $self->label,
    choose_colummns => $self->choose_colummns ? \1 : \0
  }
}



1;