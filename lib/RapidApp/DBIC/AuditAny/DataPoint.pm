package RapidApp::DBIC::AuditAny::DataPoint;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use Switch qw(switch);

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;
has 'name', is => 'ro', isa => 'Str', required => 1;
has 'context', is => 'ro', isa => 'Str', required => 1;
has 'method', is => 'ro', isa => 'Str|CodeRef', required => 1;
has 'user_defined', is => 'ro', isa => 'Bool', default => 0;


sub BUILD {
	my $self = shift;
	
	my @contexts = qw(base source set change column);
	die "Bad data point context '" . $self->context . "' - allowed values: " . join(',',@contexts)
		unless ($self->context ~~ @contexts);
		
	die "Bad datapoint name '" . $self->name . "' - only lowercase letters, numbers, underscore(_) and dash(-) allowed" 
		unless ($self->name =~ /^[a-z0-9\_\-]+$/);
}

sub get_value {
	my $self = shift;
	my $Context = shift;
	my $method = $self->method;
	return ref($method) ? $method->($self,$Context,@_) : $Context->$method(@_);
}

1;