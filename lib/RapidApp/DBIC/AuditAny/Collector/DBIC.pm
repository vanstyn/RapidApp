package RapidApp::DBIC::AuditAny::Collector::DBIC;
use Moose;
extends 'RapidApp::DBIC::AuditAny::Collector';

use RapidApp::Include qw(sugar perlutil);

has 'AuditObj', is => 'ro', required => 1;
has 'target_schema', is => 'ro', isa => 'Object', lazy => 1, default => sub { (shift)->AuditObj->schema };

has 'target_source', is => 'ro', isa => 'Str', required => 1;
has 'change_data_rel', is => 'ro', isa => 'Maybe[Str]';
has 'column_data_rel', is => 'ro', isa => 'Maybe[Str]';



# the top level source; could be either change or changeset
has 'targetSource', is => 'ro', isa => 'Object', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	my $Source = $self->target_schema->source($self->target_source) 
		or die "Bad target_source name '" . $self->target_source . "'";
	return $Source;
};

has 'changesetSource', is => 'ro', isa => 'Maybe[Object]', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return $self->change_data_rel ? $self->targetSource : undef;
};

has 'changeSource', is => 'ro', isa => 'Object', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	my $SetSource = $self->changesetSource or return $self->targetSource;
	my $Source = $SetSource->related_source($self->change_data_rel)
		or die "Bad change_data_rel name '" . $self->change_data_rel . "'";
	return $Source;
};

has 'columnSource', is => 'ro', isa => 'Maybe[Object]', 
 lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return undef unless ($self->column_data_rel);
	my $Source = $self->changeSource->related_source($self->column_data_rel)
		or die "Bad column_data_rel name '" . $self->column_data_rel . "'";
	return $Source;
};

has 'changeset_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	return [] unless ($self->changesetSource);
	my @DataPoints = $self->AuditObj->get_context_datapoints(qw(base set));
	my @names = map { $_->name } @DataPoints;
	$self->enforce_source_has_columns($self->changesetSource,@names);
	return \@names;
};

has 'change_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	my @contexts = qw(source change);
	push @contexts,(qw(base set)) unless ($self->changesetSource);
	my @DataPoints = $self->AuditObj->get_context_datapoints(@contexts);
	my @names = map { $_->name } @DataPoints;
	$self->enforce_source_has_columns($self->changeSource,@names);
	return \@names;
};

has 'column_datapoints', is => 'ro', isa => 'ArrayRef[Str]',
 lazy => 1, default => sub {
	my $self = shift;
	return [] unless ($self->columnSource);
	my @DataPoints = $self->AuditObj->get_context_datapoints(qw(column));
	my @names = map { $_->name } @DataPoints;
	$self->enforce_source_has_columns($self->columnSource,@names);
	return \@names;
};

has 'write_sources', is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
	my $self = shift;
	my @sources = ();
	push @sources, $self->changesetSource->source_name if ($self->changesetSource);
	push @sources, $self->changeSource->source_name if ($self->changeSource);
	push @sources, $self->columnSource->source_name if ($self->columnSource);
	return \@sources;
};

has '+writes_bound_schema_sources', default => sub {
	my $self = shift;
	return $self->target_schema == $self->AuditObj->schema ? 
		$self->write_sources : [];
};

sub BUILD {
	my $self = shift;
	
	$self->validate_target_schema;

}

sub validate_target_schema {
	my $self = shift;
	
	$self->changeset_datapoints;
	$self->change_datapoints;
	$self->column_datapoints;
	
	

}


sub enforce_source_has_columns {
	my $self = shift;
	my $Source = shift;
	my @columns = @_;
	
	my @missing = ();
	$Source->has_column($_) or push @missing, $_ for (@columns);
	
	return 1 unless (scalar(@missing) > 0);
	
	die "Source '" . $Source->source_name . "' missing required columns: " . 
		join(',',map { "'$_'" } @missing);
}


sub record_changes {
	my $self = shift;
	my $ChangeSet = shift;
	
	return $self->add_changeset_row($ChangeSet) if ($self->changesetSource);
	$self->add_change_row($_) for ($ChangeSet->all_changes);
	
	return 1;
	
	
	#scream_color(MAGENTA.BOLD,' --- record changes ---');
	#
	#my @Changes = $ChangeSet->all_changes;
	#
	#scream([ map {
	#	[ $_->all_datapoint_values,$_->column_datapoint_values ]
	#} @Changes ], scalar(@Changes));
	
}


sub add_change_row {
	my $self = shift;
	my $ChangeContext = shift;
	
	my %create = $ChangeContext->get_named_datapoint_values($self->change_datapoints);
	
	scream(\%create);
	
	return $self->changeSource->resultset->create(\%create);
	
}


sub add_changeset_row {
	my $self = shift;
	my $ChangeSetContext = shift;
	
	die "not implemented";

}





1;