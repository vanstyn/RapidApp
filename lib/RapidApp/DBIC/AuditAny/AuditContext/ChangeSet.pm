package RapidApp::DBIC::AuditAny::AuditContext::ChangeSet;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

use Time::HiRes qw(gettimeofday tv_interval);
sub get_dt { DateTime->now( time_zone => 'local' ) }

# ***** PRIVATE Object Class *****

sub _build_tiedContexts { [] }
sub _build_local_datapoint_data { 
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('set') };
}

has 'changes', is => 'ro', isa => 'ArrayRef', default => sub {[]};
has 'finished', is => 'rw', isa => 'Bool', default => 0, init_arg => undef;

has 'changeset_ts', is => 'ro', isa => 'DateTime', default => sub { &get_dt };
has 'start_timeofday', is => 'ro', default => sub { [gettimeofday] };

has 'changeset_finish_ts', is => 'rw', isa => 'Maybe[DateTime]', default => undef;
has 'changeset_elapsed', is => 'rw', default => undef;

sub add_changes { push @{(shift)->changes}, @_ }
sub all_changes { @{(shift)->changes} }
sub count_changes { scalar(@{(shift)->changes}) }

sub finish {
	my $self = shift;
	die "Not active changeset" unless ($self == $self->AuditObj->active_changeset);
	$self->AuditObj->finish_changeset;
	return $self->mark_finished;
}

sub mark_finished {
	my $self = shift;
	return if ($self->finished);
	
	$self->changeset_finish_ts(&get_dt);
	$self->changeset_elapsed(tv_interval($self->start_timeofday));
	
	return $self->finished(1);
}

1;