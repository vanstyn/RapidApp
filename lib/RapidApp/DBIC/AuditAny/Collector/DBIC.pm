package RapidApp::DBIC::AuditAny::Collector::DBIC;
use Moose;
extends 'RapidApp::DBIC::AuditAny::Collector';

use RapidApp::Include qw(sugar perlutil);

has 'AuditObj', is => 'ro', required => 1;
has 'log_schema', is => 'ro', isa => lazy => 1, default => sub { (shift)->AuditObj->schema };

has 'record_source', is => 'ro', isa => 'Str', required => 1;
has 'change_data_rel', is => 'ro', isa => 'Maybe[Str]';
has 'column_data_rel', is => 'ro', isa => 'Maybe[Str]';



# the top level source; could be either change or changeset
has 'record_Source', is => 'ro', isa => 'Object', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	my $Source = $self->log_schema->source($self->record_source) 
		or die "Bad record_source name '" . $self->record_source . "'";
	return $Source;
};

has 'changeset_Source', is => 'ro', isa => 'Maybe[Object]', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return $self->change_data_rel ? $self->record_Source : undef;
};

has 'change_Source', is => 'ro', isa => 'Object', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	my $SetSource = $self->changeset_Source or return $self->record_Source;
	my $Source = $SetSource->related_source($self->change_data_rel)
		or die "Bad change_data_rel name '" . $self->change_data_rel . "'";
	return $Source;
};

has 'column_Source', is => 'ro', isa => 'Maybe[Object]', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return undef unless ($self->column_data_rel);
	my $Source = $self->change_Source->related_source($self->column_data_rel)
		or die "Bad column_data_rel name '" . $self->column_data_rel . "'";
	return $Source;
};

has 'changeset_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	return [] unless ($self->changeset_Source);
	my @DataPoints = $self->AuditObj->get_context_datapoints(qw(base set));
	return [ map { $_->name } @DataPoints ];
};

has 'change_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	my @contexts = qw(source change);
	push @contexts,(qw(base set)) unless ($self->changeset_Source);
	my @DataPoints = $self->AuditObj->get_context_datapoints(@contexts);
	return [ map { $_->name } @DataPoints ];
};

has 'column_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	return [] unless ($self->column_Source);
	my @DataPoints = $self->AuditObj->get_context_datapoints(qw(column));
	return [ map { $_->name } @DataPoints ];
};

has 'write_sources', is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
	my $self = shift;
	my @sources = ();
	push @sources, $self->changeset_Source->source_name if ($self->changeset_Source);
	push @sources, $self->change_Source->source_name if ($self->change_Source);
	push @sources, $self->column_Source->source_name if ($self->column_Source);
	return \@sources;
};

has '+writes_bound_schema_sources', default => sub {
	my $self = shift;
	return $self->log_schema == $self->AuditObj->schema ? 
		$self->write_sources : [];
};

sub BUILD {
	my $self = shift;
	
	$self->validate_log_schema;

}

sub validate_log_schema {
	my $self = shift;

}



sub record_changes {
	my $self = shift;
	my $ChangeSet = shift;
	
	scream_color(MAGENTA,'record changes');
	
	my @Changes = $ChangeSet->all_changes;
	
	scream([ map {
		[ $_->all_datapoint_values,$_->column_datapoint_values ]
	} @Changes ], scalar(@Changes));
	
}




1;