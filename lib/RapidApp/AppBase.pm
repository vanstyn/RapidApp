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
use JSON;

use Try::Tiny;
use RapidApp::ExtJS::MsgBox;

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';




#### --------------------- ####


has 'base_params' 				=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'HashRef'	);
has 'params' 						=> ( is => 'ro',	required 	=> 0,		isa => 'ArrayRef'	);
has 'base_query_string'			=> ( is => 'ro',	lazy_build 	=> 1,		isa => 'Str'		);
has 'exception_style' 			=> ( is => 'ro',	required => 0,		default => "color: red; font-weight: bolder;"			);
# ----------

has 'render_as_json'			=> ( is => 'rw',	default => 1 );

sub _build_base_params {	return {};	}
sub _build_base_query_string { '' }


###########################################################################################




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


no Moose;
__PACKAGE__->meta->make_immutable;
1;