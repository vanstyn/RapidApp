package RapidApp::Model;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS master app object
#
#
# 2010-02-18:	Version 0.1 (HV)
#	Initial development

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



###########################################################################################




no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

has 'base_url'							=> ( is => 'rw' );
has 'c'									=> ( is => 'rw' );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module'	);



sub Controller {
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	$self->c($c);
	$self->base_url($self->c->namespace);
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	
	$opt = undef if (defined $opt and $opt eq '');
	return $self->viewpanel unless (defined $opt);

	if (defined $self->modules->{$opt}) {
		unless (defined $self->modules_obj->{$opt}) {
			my $class = $self->modules->{$opt};
			$self->modules_obj->{$opt} = $class->new(
				c 				=> $self->c,
				base_url		=> $self->c->namespace . '/' . $opt
			); # ;
		}
			return $self->modules_obj->{$opt}->Controller($self->c,@args);
	}
}

