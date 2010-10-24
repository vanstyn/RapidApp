package RapidApp::Role::SessionVarAutoload;

use strict;
use warnings;
use Data::Dumper;
use Moose::Role;
use Moose::Util;

before 'prepare_controller' => sub {
	my $self= shift;
	
	#$self->c->log->debug(Dumper($self->c->session));
	$self->_loadVarsFromSession;
};

after 'Controller' => sub {
	my $self= shift;
	
	$self->_storeVarsToSession;
	#$self->c->log->debug(Dumper($self->c->session));
};

sub moduleSession {
	my $self= shift;
	my $sess= $self->c->session->{$self->base_url};
	if (!defined $sess) {
		$self->c->session->{$self->base_url}= {};
		$sess= $self->c->session->{$self->base_url};
	}
	return $sess;
}

sub _loadVarsFromSession {
	my $self= shift;
	my $loaded= '';
	my $sessHash= $self->moduleSession;
	#$self->c->log->debug(Dumper($sessHash));
	for my $attr (grep { Moose::Util::does_role($_, 'RapidApp::Role::SessionVar') } $self->meta->get_all_attributes) {
		$loaded.= $attr->name . ' ';
		if (defined $sessHash->{$attr->name}) {
			$attr->set_value($self, $sessHash->{$attr->name});
		} else {
			$loaded .= '(skipped) ';
			$attr->clear_value($self);
		}
	}
	$self->c->log->info("loading session vars: $loaded");
}

sub _storeVarsToSession {
	my $self= shift;
	my $saved= '';
	my $sessHash= $self->moduleSession;
	for my $attr (grep { Moose::Util::does_role($_, 'RapidApp::Role::SessionVar') } $self->meta->get_all_attributes) {
		$saved.= $attr->name . ' ';
		if ($attr->has_value($self)) {
			$sessHash->{$attr->name}= $attr->get_value($self);
		} else {
			$saved .= '(skipped) ';
			delete $sessHash->{$attr->name};
		}
	}
	$self->c->log->info("saving session vars: $saved");
}

1;