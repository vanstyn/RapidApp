package RapidApp::DBIC::AuditAny::AuditContext::Source;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;
has 'ResultSource', is => 'ro', required => 1;
has 'source', is => 'ro', lazy => 1, default => sub { (shift)->ResultSource->source_name };
has 'class', is => 'ro', lazy => 1, default => sub { $_[0]->SchemaObj->class($_[0]->source) };
has 'from', is => 'ro', lazy => 1, default => sub { (shift)->ResultSource->source_name };
has 'table', is => 'ro', lazy => 1, default => sub { (shift)->class->table };

sub primary_columns { return (shift)->ResultSource->primary_columns }

has 'pri_key_column', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub { 
	my $self = shift;
	my @cols = $self->primary_columns;
	return undef unless (scalar(@cols) > 0);
	my $sep = $self->primary_key_separator;
	return join($sep,@cols);
};

has 'pri_key_count', is => 'ro', isa => 'Int', lazy => 1, default => sub { 
	my $self = shift;
	return scalar($self->primary_columns);
};

has 'datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('source') };
};

has 'all_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {
		%{ $self->AuditObj->base_datapoint_values },
		%{ $self->datapoint_values }
	};
};

1;