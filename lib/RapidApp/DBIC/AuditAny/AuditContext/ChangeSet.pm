package RapidApp::DBIC::AuditAny::AuditContext::ChangeSet;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'changes', is => 'ro', isa => 'ArrayRef', default => sub {[]};

sub add_changes { push @{(shift)->changes}, @_ }
sub all_changes { @{(shift)->changes} }
sub count_changes { scalar(@{(shift)->changes}) }

sub dump_changes {
	my $self = shift;
	
	my @Changes = $self->all_changes;
	
	scream([ map {
		[ $_->all_datapoint_values,$_->column_datapoint_values ]
	} @Changes ], scalar(@Changes));
}

sub finish {
	my $self = shift;
	die "Not active changeset" unless ($self == $self->AuditObj->active_changeset);
	$self->AuditObj->finish_changeset;
}

1;