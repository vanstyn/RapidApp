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
use Clone;
use JSON;

use Try::Tiny;
use RapidApp::ExtJS::MsgBox;

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';




#### --------------------- ####



has 'c' 								=> ( is => 'rw',	required 	=> 1								);
has 'base_url' 					=> ( is => 'ro',	required 	=> 1,		isa => 'Str'		);
has 'base_params' 				=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'HashRef'	);
has 'params' 						=> ( is => 'ro',	required 	=> 0,		isa => 'ArrayRef'	);
has 'base_query_string'			=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'Str'		);
has 'controller_actions'		=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'HashRef'	);
has 'default_action'				=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'CodeRef'	);
has 'exception_style' 			=> ( is => 'ro',	required => 0,		default => "color: red; font-weight: bolder;"			);
# ----------


sub _build_base_params {	return {};	}
sub _build_base_query_string { '' }


###########################################################################################




sub Controller {
	my ( $self, $c, $opt, @args ) = @_;

	my $data = '';
	
	if (defined $opt and ref($self->controller_actions->{$opt}) eq 'CODE') {
		$data = $self->controller_actions->{$opt}->(@args);
	}
	elsif (ref($self->default_action) eq 'CODE') {
		$data = $self->default_action->(@args);
	}
		
	$c->response->header('Cache-Control' => 'no-cache');
	return $c->response->body( $data );
}





sub suburl {
	my $self = shift;
	my $url = shift;
	
	my $new_url = $self->base_url;
	$new_url =~ s/\/$//;
	$url =~ s/^\/?/\//;
	
	$new_url .= $url;
	
	if ($self->has_base_query_string) {
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


sub JSON_encode {
	my $self = shift;
	return JSON::to_json(shift);
}


=pod
sub Controller {
	my ( $self, $c, $opt, @args ) = @_;

	my $data = '';
	
	switch($opt) {
		case 'action_icon-edit'		{ $data = $self->action_icon_edit;							}
		case 'action_icon-delete'	{ $data = $self->action_icon_delete;						}
		case 'action_delete'			{ $data = $self->action_delete;								}
		case 'add_window' 			{ $data = $self->add_window;									}
		case 'edit_window' 			{ $data = $self->edit_window;									}
		case 'add_submit' 			{ $data = JSON::to_json($self->add_submit);				}
		case 'edit_submit' 			{ $data = JSON::to_json($self->edit_submit);				}
		case 'data' 					{ $data = JSON::to_json($self->grid_rows); 				}
		else								{ $data = JSON::to_json($self->DynGrid->Params);		}
	}
	
	$c->response->header('Cache-Control' => 'no-cache');
	return $c->response->body( $data );
}


=cut


no Moose;
__PACKAGE__->meta->make_immutable;
1;