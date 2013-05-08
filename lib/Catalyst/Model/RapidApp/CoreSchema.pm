package Catalyst::Model::RapidApp::CoreSchema;
use Moose;

use strict;
use warnings;

extends 'Catalyst::Model::DBIC::Schema';

use Catalyst::Model::DBIC::Schema::Types
    qw/ConnectInfo LoadedClass SchemaClass Schema/;
 
use MooseX::Types::Moose qw/ArrayRef Str ClassName Undef/;

use Module::Runtime;

has schema_class => (
    is => 'ro',
    isa => SchemaClass,
    coerce => 1,
    default => 'RapidApp::CoreSchema'
);

has connect_info => (
  is => 'rw', 
  isa => ConnectInfo, 
  coerce => 1,
  lazy => 1,
  default => sub {
    my $self = shift;
    $self->_prepare_db_file;
    return {
      dsn => 'dbi:SQLite:dbname=' . $self->db_file,
      quote_names => 1,
    };
  }
);

has 'db_file', is => 'ro', isa => 'Str', required => 1;


sub _prepare_db_file {
  my $self = shift;
  return 1 if (-f $self->db_file);
  my $class = $self->schema_class;
  Module::Runtime::require_module($class);
  my $schema = $class->connect('dbi:SQLite:dbname=' . $self->db_file);
  $schema->deploy;
  
  $schema->resultset('NavtreeNode')->create({
    id => 0,
    pid => undef,
    text => 'DUMMY ROOT NODE',
    ordering => 0
  });
  
}



1;
