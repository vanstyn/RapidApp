package RapidApp::DBIC::AuditAny::Collector;
use Moose;

use RapidApp::Include qw(sugar perlutil);

# ***** Generic Base Class *****

has 'AuditObj', is => 'ro', required => 1;
has 'collect_coderef', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;


# these are part of the base class because the AuditObj expects them in all
# Collectors to know if a particular tracked source is also a source used
# by the collector which would create a deep recursion situation
has 'writes_bound_schema_sources', is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {[]};


sub record_changes {
	my $self = shift;
	return $self->collect_coderef->(@_) if ($self->collect_coderef);
	
	die "No record_changes method implemented or no collector_coderef supplied!";

}

sub has_full_row_stored {
	my $self = shift;
	my $Row = shift;
	
	warn "has_full_row_stored() not implemented - returning false\n";
	
	return 0;
}

1;