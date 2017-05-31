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

sub _linkedRow_set_columns {
  my ($pushRow, $pullRow) = @_;
  if($pullRow->can('_linkedRow_pull_set_columns')) {
    $pullRow->_linkedRow_pull_set_columns($pushRow);
  }
  else {
    die "remote LinkedResult not configured";
  }
  $_[0]->maybe::next::method($_[1])
}

sub _linkedRow_pull_set_columns {
  my ($pullRow, $pushRow) = @_;
  my $shared_cols = $pushRow->_get_linked_shared_columns or die "failed _get_linked_shared_columns";  
  $pullRow->$_( $pushRow->$_ ) for (@$shared_cols);
  $_[0]->maybe::next::method($_[1])
}

sub _create_linkedRow {
  my $self = shift;
  my $Rs = $self->_get_linkedRs or return undef;
  my $key = $self->_get_linked_key_column or return undef;
  my $shared_cols = $self->_get_linked_shared_columns or return undef;

  my $Row = $Rs->new_result({});
  $self->_linkedRow_set_columns($Row);
  local $Row->{_pulling_linkedRow} = $self;

  $Row->insert
}

sub _push_linkedRow {
  my ($self, $Row) = @_;
  my $shared_cols = $self->_get_linked_shared_columns or return undef;
  $Row ||= $self->_find_linkedRow or return $self->_create_linkedRow;
  
  local $Row->{_pulling_linkedRow} = $self;
  $self->_linkedRow_set_columns($Row);
  $Row->update
}

sub _delete_linkedRow {
  my $self = shift;
  my $Row = $self->_find_linkedRow or return undef;
  
  local $Row->{_pulling_linkedRow} = $self;
  $Row->delete
}

sub update {
  my $self = shift;
  my $columns = shift;
  
  my $Row;
  $Row = $self->_find_linkedRow unless ($self->{_pulling_linkedRow});
  
  $self->set_inflated_columns($columns) if $columns;
  
  $self->_push_linkedRow($Row) unless ($self->{_pulling_linkedRow});
  
  $self->next::method;
}

sub insert {
  my $self = shift;
  my $columns = shift;
  $self->set_inflated_columns($columns) if $columns;
  
  $self->next::method;
  
  $self->_push_linkedRow unless ($self->{_pulling_linkedRow});
  
  $self
}

sub delete {
  my $self = shift;

  $self->_delete_linkedRow unless ($self->{_pulling_linkedRow});
  
  $self->next::method;
}

1;
