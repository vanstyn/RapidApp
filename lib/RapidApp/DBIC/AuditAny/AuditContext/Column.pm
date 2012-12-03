package RapidApp::DBIC::AuditAny::AuditContext::Column;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'ChangeContext', is => 'ro', required => 1;
has 'column_name', is => 'ro', isa => 'Str', required => 1;
has 'old_value', is => 'ro', isa => 'Maybe[Str]', required => 1;
has 'new_value', is => 'ro', isa => 'Maybe[Str]', required => 1;

sub class { (shift)->ChangeContext->class }

sub _build_tiedContexts { 
	my $self = shift;
	my @Contexts = ( $self->ChangeContext, @{$self->ChangeContext->tiedContexts} );
	return \@Contexts;
}
sub _build_local_datapoint_data { 
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('column') };
}

#has 'datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
#	my $self = shift;
#	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('column') };
#};
#
#
#has 'all_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
#	my $self = shift;
#	return {
#		%{ $self->ChangeContext->all_datapoint_values },
#		%{ $self->datapoint_values }
#	};
#};

### Special TableSpec-specific datapoints:

sub fk_map { (shift)->ChangeContext->fk_map }
sub column_properties { (shift)->ChangeContext->column_properties }

has 'col_props', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return $self->column_properties->{$self->column_name} || {};
};

has 'column_header', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
	my $self = shift;
	my $header = $self->col_props->{header} || $self->column_name;
	return $header;
};

has 'rel', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub {
	my $self = shift;
	return $self->fk_map->{$self->column_name};
};

has 'old_display_value', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub {
	my $self = shift;
	return undef unless (defined $self->old_value);
	return $self->get_display_value($self->ChangeContext->origRow);
};

has 'new_display_value', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub {
	my $self = shift;
	return undef unless (defined $self->new_value);
	return $self->get_display_value($self->ChangeContext->Row);
};

sub get_display_value {
	my $self = shift;
	my $Row = shift;
	my $rel = $self->rel or return undef;
	
	my $display_col = $self->class->TableSpec_related_get_set_conf($rel,'display_column')
		or return undef;
		
	my $relRow = $Row->$rel or return undef;
	
	return $relRow->get_column($display_col);
}



1;