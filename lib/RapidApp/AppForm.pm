package RapidApp::AppForm;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use Clone;
use Try::Tiny;

use RapidApp::ExtJS::MsgBox;

use RapidApp::JSONFunc;

use Term::ANSIColor qw(:constants);

has 'store_fields' => ( is => 'ro', lazy => 1, default => undef );
has 'formpanel_config'		=> ( is => 'ro', required => 1, isa => 'HashRef' );
has 'formpanel_items'		=> ( is => 'ro', required => 1, isa => 'ArrayRef' );

has 'load_data_coderef'		=> ( is => 'ro', default => undef );
has 'save_data_coderef'		=> ( is => 'ro', default => undef );

has 'reload_on_save' 		=> ( is => 'ro', default => 0 );



#has 'default_action' => ( is => 'ro', default => 'main' );
has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $actions = {};
	
	$actions->{save}				= sub { $self->save } if (defined $self->save_data_coderef);
	$actions->{load}				= sub { $self->load } if (defined $self->load_data_coderef);
	
	$actions->{store_read}	= sub { $self->store_read } if (defined $self->load_data_coderef);
	$actions->{store_write}	= sub { $self->store_write } if (defined $self->save_data_coderef);
	
	return $actions;
});

has 'item_key' => ( is => 'ro',	lazy_build => 1, isa => 'Str'			);
sub _build_item_key {
	my $self = shift;
	return $self->parent_module->item_key;
}

has 'fields' => ( is => 'ro',	lazy_build => 1, isa => 'ArrayRef'			);
sub _build_fields {
	my $self = shift;
	return $self->parent_module->fields;
}


#has 'store_fields' => ( is => 'ro',	lazy_build => 1, isa => 'ArrayRef'			);
#sub _build_store_fields {
#	my $self = shift;
#	
#	my @f = ();
#	
#	foreach my $f (@{$self->store_fields}) {
#		my $n = {};
#		$n->{name} = $f->{name} if (defined $f->{name});
#		$n->{name} = $f->{name} if (defined $f->{name});
#		$n->{name} = $f->{name} if (defined $f->{name});
#		$n->{name} = $f->{name} if (defined $f->{name});
#	
#	}
#	
#	return $self->parent_module->fields;
#}


sub content {
	my $self = shift;
	
	my $params = $self->c->req->params;
	delete $params->{_dc};
	
	my $config = Clone::clone($self->formpanel_config);
	
	$config->{id}				= 'appform';
	$config->{xtype} 			= 'submitform';
	$config->{do_action} 	= 'jsonsubmit';
	$config->{store_orig_params} = \1;
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


sub fetch_item {
	my $self = shift;
	
	my $params = $self->c->req->params;
	$params = $self->json->decode($self->c->req->params->{orig_params}) if (defined $self->c->req->params->{orig_params});
	
	my $new = shift;
	$params = $new if ($new);
	
	return $self->load_data_coderef->($params);
	 
}




sub load {
	my $self = shift;
	
	return {
		success	=> 1,
		data		=> $self->fetch_item
	};
}



sub save {
	my $self = shift;

	my $h = {};
	
	try {
	
		my $orig_json = $self->c->req->params->{orig_params};
		my $orig_params = JSON::decode_json($orig_json);
	
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


sub store_read {
	my $self = shift;
	
	return {
		results => 1,
		rows => [ $self->fetch_item($self->c->req->params) ]
	};
}



sub JsonStore {
	my $self = shift;
	
	my $params =  {
		$self->item_key => $self->c->req->params->{$self->item_key}
	};
	
	my $orig_json = $self->c->req->params->{orig_params};
	my $orig_params = JSON::from_json($orig_json) if (defined $orig_json);
	
	$params = {	$self->item_key => $orig_params->{$self->item_key} } if (
		defined $orig_params ->{$self->item_key}
	);
	
	
	use Data::Dumper;
	 print STDERR Dumper($self->store_fields) . CLEAR;
	
	my $store = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => {
			#storeId => 'appform-store-' . $orig_params->{$self->item_key},
			autoLoad => \1,
			idProperty => 'id',
			root => 'rows',
			totalProperty => 'results',
			
			url => $self->suburl('/store_read'),
			#api => {
			#	load => { url => $self->suburl('/store_read') },
			#	save => { url => $self->suburl('/store_write') },
			#},
			baseParams 	=> $params,
			fields		=> $self->store_fields,
			#root			=> 'data'
		}
	);
	
	use Data::Dumper;
	print STDERR BOLD . Dumper($store) . CLEAR;
	
	return $store;
}






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;