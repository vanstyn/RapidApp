package RapidApp::DBIC::AuditAny::DataPoint;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use Switch qw(switch);

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;
has 'name', is => 'ro', isa => 'Str', required => 1;
has 'context', is => 'ro', isa => 'Str', required => 1;
has 'passthrough', is => 'ro', isa => 'Bool', default => 0;
has 'method', is => 'ro', isa => 'CodeRef', lazy => 1, default => sub {
	my $self = shift;
	return undef unless ($self->passthrough);
	return sub {
		my $s = shift;
		my $Context = shift;
		my $name = $s->name;
		return $Context->$name(@_);
	};
};

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
	return $self->method->($self,$Context,@_);
}

1;