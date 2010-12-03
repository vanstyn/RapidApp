package RapidApp::Handler;
use Moose;

has 'scope'		=> ( is => 'ro', required => 1, isa => 'Object' );
has 'method'	=> ( is => 'ro', required => 1, isa => 'Str' );

sub BUILD {
	my $self = shift;
	
	$self->scope->can($self->method) or die ref($self->scope) . ' does not have a method named "' . $self->method . '"';

}

sub call {
	my $self = shift;
	my $method = $self->method;
	return $self->scope->$method(@_);
}

1;