package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON;
use Moose::Role;
with 'RapidApp::Role::Module';

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';


has 'c'									=> ( is => 'rw' );
has 'base_url'							=> ( is => 'rw',	default => '' );
has 'actions'							=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'					=> ( is => 'ro',	default => 'default_action' );


has 'create_module_params' => ( is => 'ro', lazy => 1,	default => sub {
	my $self = shift;
	return {
		c => $self->c
	};
});



sub Controller {
	my $self = shift;
	$self->c(shift);
	my ( $opt, @args ) = @_;
	
#	print STDERR BLUE . " --> : " . ref($self) . "\n" . CLEAR;
#	print STDERR CYAN . "base_url: " . $self->base_url . "\n" . CLEAR;
#	print STDERR RED . "path: " . $self->c->req->path . "\n" . CLEAR;
#	print STDERR YELLOW . "namesp: " . $self->c->namespace . "\n" . CLEAR;
#	print STDERR GREEN . "opt: " . $opt . "\n" . CLEAR;
	
	
	#$self->c($c);
	#$self->base_url($self->c->namespace) unless (defined $self->parent_module);
	
	$self->base_url($self->c->namespace);
	
	$self->base_url($self->parent_module->base_url . '/' . $self->module_name) if (
		defined $self->parent_module
	);
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	
	return $self->process_action($opt,@args)									if (defined $opt and defined $self->actions->{$opt});
	return $self->modules_obj->{$opt}->Controller($self->c,@args)		if (defined $opt and $self->_load_module($opt));
	return $self->process_action($self->default_action,@_);
}



sub process_action {
	my $self = shift;
	my ( $opt, @args ) = @_;
	
	print STDERR RED . "PROCESS ACTION: " . $opt . "\n" . CLEAR;
	
	my $data = '';
	$data = $self->actions->{$opt}->();
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	return $self->c->response->body( $data );
}


sub JSON_encode {
	my $self = shift;
	return JSON::to_json(shift);
}


1;