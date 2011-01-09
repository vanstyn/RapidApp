package RapidApp::Error::CustomPrompt;

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

no Moose;
__PACKAGE__->meta->make_immutable;
1;