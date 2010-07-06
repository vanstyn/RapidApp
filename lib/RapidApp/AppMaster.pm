package RapidApp::AppMaster;
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
BEGIN { extends 'Catalyst::Controller'; }

use JSON;
use Data::Dumper;

our $VERSION = '0.1';


#### --------------------- ####


has 'app_title' 						=> ( is => 'ro',	default => 'RapidApp Application'		);
has 'app_class'						=> ( is => 'ro',	default => undef		);
has 'app_model'						=> ( is => 'ro',	default => undef		);




sub index :Path {
    my $self = shift;
	 my ( $c, $opt, @args ) = @_;

	$c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
	$c->stash->{config_url} = $c->namespace . '/json_config';

	$c->stash->{title} = $self->app_title;

	$c->response->header('Cache-Control' => 'no-cache');
}


sub json_config :Local {
	my ( $self, $c, $opt, @args ) = @_;

	my $data = {};

	$data = $c->model($self->viewpanel_model)->main_viewpanel($c) if (defined $self->viewpanel_model);

	$c->response->body( JSON::to_json($data) );
	$c->response->header('Cache-Control' => 'no-cache');
}



sub explorer2 :Local {
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	#sub { $self->app_class->new(
	#	c		=> $c
	#
	#)->Controller(@_); }
	
	
	my $App = $self->app_class->new(
		c		=> $c
	
	);
	
	$App->Controller(@_);
}



sub explorer :Local {
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
		
	$c->model($self->content_model)->Controller(@_) if (defined $self->content_model);
}



###########################################################################################




no Moose;
__PACKAGE__->meta->make_immutable;
1;