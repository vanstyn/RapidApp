package RapidApp::AppBase;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Grid object
#
#
# 2010-01-18:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;
with 'RapidApp::Role::Controller';

use Clone;
#use JSON;

use Try::Tiny;
use RapidApp::ExtJS::MsgBox;
use String::Random;

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';




#### --------------------- ####


has 'base_params' 				=> ( is => 'ro',	lazy => 1, default => sub {{}}	);
has 'params' 						=> ( is => 'ro',	required 	=> 0,		isa => 'ArrayRef'	);
has 'base_query_string'			=> ( is => 'ro',	default => ''		);
has 'exception_style' 			=> ( is => 'ro',	required => 0,		default => "color: red; font-weight: bolder;"			);
has 'auto_viewport'				=> ( is => 'rw',	default => 0 );

has 'auto_init_modules', is => 'ro', isa => 'Maybe[HashRef]', default => sub{undef};
# ----------



has 'instance_id' => ( 
	is => 'ro', lazy => 1, 
	traits => ['RapidApp::Role::PerRequestBuildDefReset'], 
	default => sub {
		my $self = shift;
		return 'instance-' . String::Random->new->randregex('[a-z0-9A-Z]{5}');
});


###########################################################################################

sub BUILD {
	my $self= shift;
	$self->apply_actions(viewport => 'viewport');
	$self->apply_actions('web1.0' => 'web1');
	$self->apply_actions(printview => 'printview');
  
  $self->apply_init_modules(%{$self->auto_init_modules})
    if ($self->auto_init_modules);
}

sub suburl {
	my $self = shift;
	my $url = shift;
	
	my $new_url = $self->base_url;
	$new_url =~ s/\/$//;
	$url =~ s/^\/?/\//;
	
	$new_url .= $url;
	
	if (defined $self->base_query_string and $self->base_query_string ne '') {
		$new_url .= '?' unless ($self->base_query_string =~ /^\?/);
		$new_url .= $self->base_query_string;
	}
	
	return $new_url;
}


sub urlparams {
	my $self = shift;
	my $params = shift;
	
	my $new = Clone($self->base_params);
	
	if (defined $params and ref($params) eq 'HASH') {
		foreach my $k (keys %{ $params }) {
			$new->{$k} = $params->{$k};
		}
	}
	return $new;
}

sub content {
	die "Unimplemented";
}

sub web1_content {
	my $self= shift;
	return $self->auto_viewport? $self->viewport : $self->web1;
}

sub web1 { # public action
	my $self= shift;
	$self->c->view('RapidApp::Web1Render')->render({module => $self});
	return 1;
}

sub web1_render {
	my ($self, $renderCxt)= @_;
	$self->c->error("No web1_render defined for ".(ref $self));
}

sub viewport {
	my $self= shift;
	$self->c->stash->{current_view} ||= 'RapidApp::Viewport';
	$self->c->stash->{title} ||= $self->module_name;
	$self->c->stash->{config_url} ||= $self->base_url;
	if (scalar keys %{$self->c->req->params}) {
		$self->c->stash->{config_params} ||= { %{$self->c->req->params} };
	}
}

sub printview {
	my $self= shift;
	$self->c->stash->{current_view} ||= 'RapidApp::Printview';
	$self->c->stash->{title} ||= $self->module_name;
	$self->c->stash->{config_url} ||= $self->base_url;
	if (scalar keys %{$self->c->req->params}) {
		$self->c->stash->{config_params} ||= { %{$self->c->req->params} };
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;