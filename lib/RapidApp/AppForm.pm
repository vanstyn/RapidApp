package RapidApp::AppForm;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use Clone;
use Try::Tiny;

use RapidApp::ExtJS::MsgBox;




has 'formpanel_config'		=> ( is => 'ro', required => 1, isa => 'HashRef' );
has 'formpanel_items'		=> ( is => 'ro', required => 1, isa => 'ArrayRef' );

has 'load_data_coderef'		=> ( is => 'ro', default => undef );
has 'save_data_coderef'		=> ( is => 'ro', default => undef );

has 'reload_on_save' 		=> ( is => 'ro', default => 0 );



#has 'default_action' => ( is => 'ro', default => 'main' );
has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $actions = {};
	
	$actions->{save}	= sub { $self->save } if (defined $self->save_data_coderef);
	$actions->{load}	= sub { $self->load } if (defined $self->load_data_coderef);
	
	return $actions;
});



sub content {
	my $self = shift;
	
	my $config = Clone::clone($self->formpanel_config);
	
	my $orig_data = $self->c->req->params->{orig_form_data};
	
	my $params = {};
	$params = JSON::decode_json($orig_data) if (defined $orig_data);
	my $orig_params = $self->c->req->params;
	$orig_params->{orig_form_data} = $params;
	
	$config->{base_params} = { orig_params => JSON::to_json($orig_params) };
	
	$config->{id}				= 'appform';
	$config->{xtype} 			= 'submitform';
	$config->{do_action} 	= 'jsonsubmit';
	$config->{store_orig_form_data} = \1;
	$config->{url}				=  $self->suburl('/save');
	
	$config->{action_load} = {
		url		=> $self->suburl('/load'),
		params	=> $params,
		nocache	=> \1
	} if (defined $self->load_data_coderef);
	
	
	$config->{onSuccess_eval} = 'form.load(form.action_load);' if ($self->reload_on_save);
	
	
	$config->{items}			= $self->formpanel_items;
	
	return RapidApp::ExtJS::SubmitForm->new($config)->Config;
}


sub load {
	my $self = shift;
	
	my $params = $self->c->req->params;
	
	my $data = {};
	$data = $self->load_data_coderef->($params);
	
	return {
		success	=> 1,
		data		=> $data
	};
}



sub save {
	my $self = shift;

	my $h = {};
	
	try {
	
		my $orig_json = $self->c->req->params->{orig_params};
		my $orig_params = JSON::from_json($orig_json);
	
		my $json_params = $self->c->req->params->{json_params};
		my $params = JSON::decode_json($json_params);
	
		my $hash = $self->save_data_coderef->($params,$orig_params);
		$h = $hash if (ref($hash) eq 'HASH');
	}
	catch {
		$h->{success} = 0;
		$h->{msg} = "$_";
		chomp $h->{msg};
	};
	
	$h->{success} = 0 unless (defined $h->{success});
	$h->{msg} = 'Update failed - unknown error' unless (defined $h->{msg});

	return $h;
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;