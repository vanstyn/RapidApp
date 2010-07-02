package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON;
use Moose::Role;

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';

has 'parent_ref'						=> ( is => 'ro', default => undef );
has 'c'									=> ( is => 'rw' );
has 'base_url'							=> ( is => 'rw' );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module'	);
has 'actions'							=> ( is => 'ro', 	default => sub {{}} );


sub Controller {
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	print STDERR BLUE . " --> : " . ref($self) . "\n" . CLEAR;
	print STDERR CYAN . "base_url: " . $self->base_url . "\n" . CLEAR;
	print STDERR RED . "path: " . $self->c->req->path . "\n" . CLEAR;
	print STDERR YELLOW . "namesp: " . $self->c->namespace . "\n" . CLEAR;
	print STDERR GREEN . "opt: " . $opt . "\n" . CLEAR;
	
	
	$self->c($c);
	$self->base_url($self->c->namespace) unless (defined $self->parent_ref);
	
	#$self->base_url('/' . $self->c->req->path);
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	
	return $self->process_action($opt,@args) if (defined $self->actions->{$opt});
	
	
	
	if (defined $self->modules->{$opt}) {
		#unless (defined $self->modules_obj->{$opt}) {
			my $class = $self->modules->{$opt};
			
			print STDERR BOLD . GREEN . "class: " . $class . "\n" . CLEAR;
			
			$self->modules_obj->{$opt} = $class->new(
				parent_ref	=> $self,
				c 				=> $self->c,
				#base_url		=> $self->c->namespace . '/' . $opt
				base_url		=> $self->base_url . '/' . $opt
			);
		#}
		return $self->modules_obj->{$opt}->Controller($self->c,@args);
	}
	
	return $self->default_action($opt,@args);
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


# placeholder:
sub default_action {
	my $self = shift;
	my ( $opt, @args ) = @_;

}

sub JSON_encode {
	my $self = shift;
	return JSON::to_json(shift);
}


1;