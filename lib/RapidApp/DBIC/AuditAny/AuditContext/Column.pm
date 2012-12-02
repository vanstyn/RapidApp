package RapidApp::DBIC::AuditAny::AuditContext::Column;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'ChangeContext', is => 'ro', required => 1;
has 'column_name', is => 'ro', isa => 'Str', required => 1;
has 'old_value', is => 'ro', isa => 'Str', required => 1;
has 'new_value', is => 'ro', isa => 'Str', required => 1;

has 'col_props', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'column_header', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
	my $self = shift;
	my $header = $self->col_props->{header} || $self->column_name;
	return $header;
};


has 'datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('column') };
};


has 'all_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {
		%{ $self->ChangeContext->all_datapoint_values },
		%{ $self->datapoint_values }
	};
};



1;