package RapidApp::AppCustom;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS custom app object
#
#
# 2010-03-07:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::AppBase';


our $VERSION = '0.1';



use Term::ANSIColor qw(:constants);

#### --------------------- ####


has 'Content'							=> ( is => 'ro',	required => 1											);
has 'Subpaths'							=> ( is => 'ro',	lazy_build => 1										);
has 'json_encode'						=> ( is => 'ro',	default => 1											);



sub _build_default_action { 
	my $self = shift;
	my $params = $self->c->req->params;
	return $self->Content_Encode($self->Content,$params);
}

sub _build_controller_actions {
	my $self = shift;
	
	return {} unless ($self->has_Subpaths and ref($self->Subpaths) eq 'HASH');
	
	my $params = $self->c->req->params;
	
	my $actions = {};
	
	foreach my $Path (keys %{$self->Subpaths}) {
		$actions->{$Path} = $self->Content_Encode($self->Subpaths->{$Path},$params);
	}
	
	return $actions;
}

###########################################################################################



sub Content_Encode {
	my $self = shift;
	my $Content = shift or die '$Content is undef!!';
	my $params = shift;

	return sub { $self->encode_if($Content->($params)); } if (ref($Content) eq 'CODE');
	return sub { $self->encode_if($Content); };
}


sub encode_if {
	my $self = shift;
	my $data = shift;
	
	return $data unless ($self->json_encode);
	return $self->JSON_encode($data);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;