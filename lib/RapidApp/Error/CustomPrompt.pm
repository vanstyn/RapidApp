package RapidApp::Error::CustomPrompt;

sub new {
	my $class= shift;
	RapidApp::ScopedGlobals->log->warn("Use RapidApp::Responder::CustomPrompt instead of RapidApp::Error::CustomPrompt");
	return RapidApp::Responder::CustomPrompt->new(@_);
}
=pod
use Moose;
#extends 'RapidApp::Error';

use JSON::PP;

has 'title' 		=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'param_name'	=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'height'		=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );
has 'width'			=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );
has 'buttons'		=> ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );
has 'buttonIcons'	=> ( is => 'ro', isa => 'Maybe[HashRef[Str]]', default => undef );
has 'items'			=> ( is => 'ro', isa => 'Maybe[ArrayRef|HashRef]', default => undef );
has 'formpanel_cnf'	=> ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

sub header_data {
	my $self = shift;
	
	my $data = {};
	$data->{title} 			= $self->title if (defined $self->title);
	$data->{param_name}		= $self->param_name if (defined $self->param_name);
	$data->{height} 		= $self->height if (defined $self->height);
	$data->{width} 			= $self->width if (defined $self->width);
	$data->{buttons} 		= $self->buttons if (defined $self->buttons);
	$data->{buttonIcons} 	= $self->buttonIcons if (defined $self->buttonIcons);
	$data->{items} 			= $self->items if (defined $self->items);
	$data->{formpanel_cnf} 	= $self->formpanel_cnf if (defined $self->formpanel_cnf);

	return $data;
}

# TODO: do this properly in a View:
sub header_json {
	my $self = shift;
	return JSON::PP::encode_json($self->header_data);
}

sub customHttpResponse {
	my ($self, $c)= @_;
	
	$c->response->header('X-RapidApp-CustomPrompt' => $err->header_json);
	unless (length($c->response->body) > 0) {
		$c->response->content_type('text/plain; charset=utf-8');
		$c->response->body("More user input was needed to complete your request, but we can only send prompts through dynamic javascript requests");
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
=cut
1;
