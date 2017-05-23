package RapidApp::DBIC::Component::LinkedResult;
use parent 'DBIx::Class';

use strict;
use warnings;

use RapidApp::Util qw(:all);


sub _get_linkedRs {
  my $self = shift;
  my $Source = $self->result_source->{_linked_source} or return undef;
  $Source->resultset
}

sub _get_linked_key_column {
  my $self = shift;
  $self->result_source->{_linked_key_column}
}

sub _get_linked_shared_columns {
  my $self = shift;
  $self->result_source->{_linked_shared_columns}
}

sub _find_linkedRow {
  my $self = shift;
  my $Rs = $self->_get_linkedRs or return undef;
  my $key = $self->_get_linked_key_column or return undef;
  $Rs->search_rs({ $key => $self->$key })
    ->first
}

sub _create_linkedRow {
  my $self = shift;
  my $Rs = $self->_get_linkedRs or return undef;
  my $key = $self->_get_linked_key_column or return undef;
  my $shared_cols = $self->_get_linked_shared_columns or return undef;
  
  my $columns = { map { $_ => $self->$_ } @$shared_cols };
  
  $columns->{$key} = $self->$key;
  
  my $Row = $Rs->new($columns);
  
  local $Row->{_pushing_linkedRow} = 1;
  $Row->insert
}

sub _push_linkedRow {
  my $self = shift;
  my $shared_cols = $self->_get_linked_shared_columns or return undef;
  my $Row = $self->_find_linkedRow or return $self->_create_linkedRow;
  
  local $Row->{_pushing_linkedRow} = 1;
  $Row->$_( $self->$_ ) for (@$shared_cols);
  $Row->update
}

sub _delete_linkedRow {
  my $self = shift;
  my $Row = $self->_find_linkedRow or return undef;
  
  local $Row->{_pushing_linkedRow} = 1;
  $Row->delete
}

sub update {
  my $self = shift;
  my $columns = shift;
  $self->set_inflated_columns($columns) if $columns;
  
  $self->_push_linkedRow unless ($self->{_pushing_linkedRow});
  
  $self->next::method;
}

sub insert {
  my $self = shift;
  my $columns = shift;
  $self->set_inflated_columns($columns) if $columns;
  
  $self->_push_linkedRow unless ($self->{_pushing_linkedRow});
  
  $self->next::method;
}

sub delete {
  my $self = shift;

  $self->_delete_linkedRow unless ($self->{_pushing_linkedRow});
  
  $self->next::method;
}

1;
