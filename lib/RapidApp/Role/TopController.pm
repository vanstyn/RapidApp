package RapidApp::Role::TopController;
#
# -------------------------------------------------------------- #
#


use strict;
use warnings;
use Moose::Role;
with 'RapidApp::Role::Controller';

use RapidApp::ScopedGlobals;

our $VERSION = '0.1';

#### --------------------- ####


has 'app_title' 						=> ( is => 'ro',	default => 'RapidApp Application'		);


around 'Controller' => sub {
	my $orig = shift;
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	# mask the globals with the values for this request
	local $RapidApp::ScopedGlobals::CatalystInstance= $c;
	local $RapidApp::ScopedGlobals::Log= $c->log;
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	$opt = undef if (defined $opt and $opt eq '');
	return $self->viewpanel unless (defined $opt);
	
	my $result= $self->$orig(@_);
	
	# clear out any temporarily cached attributes generated by this request
	$self->recursive_clear_per_request_vars;
	
	return $result;
};


sub viewpanel {
	my $self = shift;
	
	$self->c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
	$self->c->stash->{config_url} = $self->base_url . '/' . $self->default_module;

	$self->c->stash->{title} = $self->app_title;

	$self->c->response->header('Cache-Control' => 'no-cache');
}


1;
