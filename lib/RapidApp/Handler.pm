package RapidApp::Handler;
use Moose;

has 'scope'		=> ( is => 'ro', default => undef, isa => 'Maybe[Object]' );
has 'method'	=> ( is => 'ro', default => undef, isa => 'Maybe[Str]' );
has 'code'		=> ( is => 'ro', default => undef, isa => 'Maybe[CodeRef]' );

sub BUILD {
	my $self = shift;
	
	die 'neither code nor method supplied.' unless (defined $self->method or defined $self->code);
	die 'method and code cannot be used together' if (defined $self->method and defined $self->code);
	
	if (defined $self->method) {
		die 'scope is required with method' unless (defined $self->scope);
		$self->scope->can($self->method) or die ref($self->scope) . ' does not have a method named "' . $self->method . '"';
	}
}

sub call {
	my $self = shift;
	return $self->_call_coderef(@_) if (defined $self->code);
	my $method = $self->method;
	return $self->scope->$method(@_);
}

sub _call_coderef {
	my $self = shift;
	my @arg = ();
	push @arg, $self->scope if (defined $self->scope);
	push @arg, @_;
	return $self->code->(@arg);
}


1;