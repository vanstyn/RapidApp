package RapidApp::Module::StorCmp::Role::DbicLnk::RowPg;

use strict;
use warnings;

# ABSTRACT: for DbicLnk modules to display a single Row instead of multiple

use Moose::Role;

# From RapidApp::Module::StorCmp::Role::DbicLnk, which must be loaded first
requires 'allow_restful_queries';


use RapidApp::Util qw(:all);

has 'getTabTitle', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;
has 'getTabIconCls', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;

sub supplied_id {
  my $self = shift;
  
  
  
  
  my $id = $self->c->req->params->{$self->record_pk};
  if (not defined $id and $self->c->req->params->{orig_params}) {
    my $orig_params = $self->json->decode($self->c->req->params->{orig_params});
    $id = $orig_params->{$self->record_pk};
  }
  
  scream($self->c->req->params,$self->record_pk,$self->_rst_qry_param,$id);
  
  return $id;
}

sub ResultSet {
  my $self = shift;
  my $Rs = shift;

  my $value = $self->supplied_id or return $Rs;
  return $Rs->search_rs($self->record_pk_cond($value));
}

has 'req_Row', is => 'ro', lazy => 1, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ], default => sub {
#sub req_Row {
  my $self = shift;
  my $Rs = $self->_ResultSet;
  
  my $supId = $self->supplied_id;
  die usererr "Record Id not supplied in request", title => 'Id not supplied'
    unless (defined $supId || defined $self->c->req->params->{$self->_rst_qry_param});
  
  my $count = $Rs->count;
  
  unless ($count == 1) {
    my $idErr = defined $supId ? "id: '$supId'" : "'" . $self->c->req->params->{$self->_rst_qry_param} . "'";

    die usererr 'Record was not found by ' . $idErr, title => 'Record not found'
      unless ($count);
    
    die usererr $count . ' records match ' . $idErr , title => 'Multiple records match';
  }
  
  my $Row = $Rs->first or return undef;
  
  if (my $relchain = $self->c->req->params->{relchain}) {
    $Row = eval join('->','$Row',@$relchain);
  }
  
  if ($self->getTabTitle) {
    my $title = $self->getTabTitle->($self,$Row);
    $self->apply_extconfig( tabTitle => $title ) if ($title);
  }
  
  if ($self->getTabIconCls) {
    my $iconCls = $self->getTabIconCls->($self,$Row);
    $self->apply_extconfig( tabIconCls => $iconCls ) if ($iconCls);
  }
  
  # New: honor/apply again the apply_extconfig (this was added as a quick fix
  # for the case when we're redispatched from a rel rest path)
  # TODO/FIXME: do this properly...
  my $ovr = $self->c->stash->{apply_extconfig};
  $self->apply_extconfig( %$ovr ) if ($ovr);
    
  return $Row;
};



1;