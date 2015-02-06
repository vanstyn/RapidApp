package RapidApp::Responder::CustomPrompt;

use Moose;
extends 'RapidApp::Responder';

use RapidApp::Util qw(:all);
use HTML::Entities;

has 'title' 		=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'param_name'	=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'height'		=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );
has 'width'			=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );
has 'buttons'		=> ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );
has 'buttonIcons'	=> ( is => 'ro', isa => 'Maybe[HashRef[Str]]', default => undef );
has 'items'			=> ( is => 'ro', isa => 'Maybe[ArrayRef|HashRef]', default => undef );
has 'formpanel_cnf'	=> ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );
has 'noCancel'			=> ( is => 'ro', default => undef );
has 'validate'			=> ( is => 'ro', default => undef );
has 'EnterButton' 	=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'EscButton' 		=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'focusField' 		=> ( is => 'ro', isa => 'Maybe[Str]', default => undef );

sub customprompt_data {
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
	$data->{noCancel}			= $self->noCancel if (defined $self->noCancel);
	$data->{validate}			= $self->validate if (defined $self->validate);
	$data->{EnterButton}		= $self->EnterButton if (defined $self->EnterButton);
	$data->{EscButton}		= $self->EscButton if (defined $self->EscButton);
	$data->{focusField}		= $self->focusField if (defined $self->focusField);

	return $data;
}

sub customprompt_json {
	my $self = shift;
	return RapidApp::JSON::MixedEncoder::encode_json($self->customprompt_data);
}

sub writeResponse {
	my ($self, $c)= @_;
	
	$c->response->header('X-RapidApp-CustomPrompt' => $self->customprompt_json);
	#$c->response->status(500);
	
	my $rct= $c->stash->{requestContentType};
	if ($rct eq 'text/x-rapidapp-form-response' || $rct eq 'JSON') {
		$c->stash->{json}= { success => \0 };
		$c->view('RapidApp::JSON')->process($c);
	}
	else {
		unless (length($c->response->body) > 0) {
			$c->response->content_type('text/plain; charset=utf-8');
			$c->response->body("More user input was needed to complete your request, but we can only send prompts through dynamic javascript requests");
		}
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;