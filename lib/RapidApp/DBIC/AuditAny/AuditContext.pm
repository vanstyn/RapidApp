package RapidApp::DBIC::AuditAny::AuditContext;
use Moose;

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;

has 'tiedContexts', is => 'ro', isa => 'ArrayRef[Object]', lazy_build => 1;
has 'local_datapoint_data', is => 'ro', isa => 'HashRef', lazy_build => 1;

sub _build_tiedContexts { die "Virtual method" }
sub _build_local_datapoint_data { die "Virtual method" }

sub get_datapoint_value {
	my $self = shift;
	my $name = shift;
	my @Contexts = ($self,@{$self->tiedContexts},$self->AuditObj);
	foreach my $Context (@Contexts) {
		return $Context->local_datapoint_data->{$name} 
			if (exists $Context->local_datapoint_data->{$name});
	}
	die "Unknown datapoint '$name'";
}

sub get_datapoints_data {
	my $self = shift;
	my @names = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	return { map { $_ => $self->get_datapoint_value($_) } @names };
}


sub SchemaObj { (shift)->AuditObj->schema };
sub schema { ref (shift)->AuditObj->schema };
sub primary_key_separator { (shift)->AuditObj->primary_key_separator };
sub get_context_datapoints { (shift)->AuditObj->get_context_datapoints(@_) };
sub get_context_datapoint_names { (shift)->AuditObj->get_context_datapoint_names(@_) };

1;