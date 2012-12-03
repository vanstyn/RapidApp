package RapidApp::DBIC::AuditAny::AuditContext::ChangeSet;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'changes', is => 'ro', isa => 'ArrayRef', default => sub {[]};

sub _build_tiedContexts { [] }
sub _build_local_datapoint_data { 
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('changeset') };
}


sub add_changes { push @{(shift)->changes}, @_ }
sub all_changes { @{(shift)->changes} }
sub count_changes { scalar(@{(shift)->changes}) }


sub finish {
	my $self = shift;
	die "Not active changeset" unless ($self == $self->AuditObj->active_changeset);
	$self->AuditObj->finish_changeset;
}

1;