package RapidApp::Model;
#
# -------------------------------------------------------------- #
#

use Term::ANSIColor qw(:constants);

use strict;
use warnings;
use Moose;
extends 'Catalyst::Model';
with 'RapidApp::Role::Controller';

use JSON;
use Switch;


our $VERSION = '0.1';


#### --------------------- ####


has 'app_title' 						=> ( is => 'ro',	default => 'RapidApp Application'		);


around 'Controller' => sub {
	my $orig = shift;
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	$self->c($c);
	
	$opt = undef if (defined $opt and $opt eq '');
	return $self->viewpanel unless (defined $opt);
	
	return $self->$orig(@_);
};


sub viewpanel {
	my $self = shift;
	
	$self->c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
	$self->c->stash->{config_url} = $self->base_url . '/' . $self->default_module;

	$self->c->stash->{title} = $self->app_title;

	$self->c->response->header('Cache-Control' => 'no-cache');
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;
