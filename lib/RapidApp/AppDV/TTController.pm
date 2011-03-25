package RapidApp::AppDV::TTController;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::RecAutoload;

has 'AppDV' => (
	is => 'ro',
	isa => 'RapidApp::AppDV',
	required => 1
);


sub dataview_id {
	my $self = shift;
	return $self->AppDV->get_extconfig_param('id');
}




sub div_wrapper {
	my $self = shift;
	return '<div class="appdv-tt-generated ' . $self->dataview_id . '">' . 
		(shift) . 
	'</div>';
}




sub div_clickable {
	my $self = shift;
	return $self->div_wrapper(
		'<div class="clickable">' . 
			(shift) . 
		'</div>'
	);
}



sub delete_record {
	my $self = shift;
	return $self->div_clickable('<div class="delete-record">Delete</div>');
}




sub div_editable_value{
	my $self = shift;
	my $name = shift;
	return $self->div_clickable(
		'<div class="editable-value">' .
			'<div class="field-name" style="display:none;">' . $name . '</div>' .
			(shift) .
		'</div>'
	);
}

sub data_wrapper_div {
	my $self = shift;
	my $name = shift;
	return '<div class="data-wrapper">' .
		'<div class="data-holder">{' . $name . '}</div>' .
		'<div class="field-holder"></div>' .
	'</div>' ;
}



sub div_edit_field {
	my $self = shift;
	my $name = shift;
	return $self->div_editable_value($name,
		'<div class="appdv-edit-field">' .	
			'<table><tr>' .
				'<td>' . $self->data_wrapper_div($name) . '</td>' .
								
				'<td class="icons">' .
					'<div class="edit">&nbsp;</div>' .
					'<div class="save" title="save">&nbsp;</div>' .
					'<div class="cancel" title="cancel">&nbsp;</div>' .
				'</td>' .
			'</tr></table>' .
		'</div>'
	);
}




sub div_bigfield {
	my $self = shift;
	my $name = shift;
	return $self->div_editable_value($name,
		'<div class="appdv-edit-bigfield">' .
			$self->data_wrapper_div($name)  . 
			'<div class="icons">' .
				'<div class="edit">edit</div>' .
				'<div class="cancel">cancel</div>' .
				'<div class="save">save</div>' .
			'</div>' .
		'</div>'
	);
}



has 'field' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->AppDV->columns->{$name} or return '';
			$self->FieldCmp->{$Column->name} = $Column->get_field_config;
			
			return '<div class="' . $Column->name . '">{' . $Column->name . '}</div>';
		});
	
	}
);



has 'edit_field' => (
	is => 'ro',
	lazy => 1,
	isa => 'RapidApp::RecAutoload',
	default => sub {
		my $self = shift;
		return RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->AppDV->columns->{$name} or return '';
			
			$self->AppDV->FieldCmp->{$Column->name} = $Column->get_field_config;

			return $self->div_edit_field($Column->name);
		});
	}
);


has 'edit_bigfield' => (
	is => 'ro',
	lazy => 1,
	isa => 'RapidApp::RecAutoload',
	default => sub {
		my $self = shift;
		return RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->AppDV->columns->{$name} or return '';
			
			$self->AppDV->FieldCmp->{$Column->name} = $Column->get_field_config;

			return $self->div_bigfield($Column->name);
			
			'<div class="appdv-click ' . $self->AppDV->get_extconfig_param('id') . '">' .
			
				#'<div class="appdv-click-el edit:' . $Column->name . '" style="float: right;padding-top:4px;padding-left:4px;cursor:pointer;"><img src="/static/rapidapp/images/pencil_tiny.png"></div>' .
				'<div class="appdv-field-value ' . $Column->name . '" style="position:relative;">' .
				#'<div style="overflow:auto;">' .
					'<div class="data">{' . $Column->name . '}</div>' .
					'<div class="fieldholder"></div>' .
					'<div class="appdv-click-el edit:' . $Column->name . ' appdv-edit-box">edit</div>' .
					'<div class="appdv-click-el edit:' . $Column->name . ' appdv-edit-box save">save</div>' .
					'<div class="appdv-click-el edit:' . $Column->name . ' appdv-edit-box cancel"><img class="cancel" src="/static/rapidapp/images/cross_tiny.png"></div>' .
				'</div>' .
			'</div>';

		});
	}
);
		
		
has 'edit_click_field' => (
	is => 'ro',
	lazy => 1,
	isa => 'RapidApp::RecAutoload',
	default => sub {
		my $self = shift;
		return RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->AppDV->columns->{$name} or return '';
			
			$self->AppDV->FieldCmp->{$Column->name} = $Column->get_field_config;


			
			return
			
			'<div class="appdv-click ' . $self->AppDV->get_extconfig_param('id') . '">' .
			

					'<div class="data appdv-editable-value"><span>{' . $Column->name . '}</span></div>' .
					
			'</div>';

		});
	}
);
		
		
has 'submodule' => (
	is => 'ro',
	lazy => 1,
	isa => 'RapidApp::RecAutoload',
	default => sub {
		my $self = shift;
		return RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			
			my $Module = $self->AppDV->Module($name) or return '';
			
			return $self->div_module_content($name,$Module);
			
		});
	}
);


sub get_Module {
	my $self = shift;
	my $path = shift;
	
	my $Module = $self->AppDV->get_Module($path) or return '';
	
	$path =~ s/\//\_/g;
			
	return $self->div_module_content($path,$Module);
}

# Example tt usage:
# [% r.ajaxcmp('projects2','/main/explorer/projects2','{"p1":"p1val","p2":"p2val"}') %]
sub ajaxcmp {
	my $self = shift;
	my $name = shift;
	my $url = shift;
	my $params_enc = shift;
	
	my $params = {};
	$params = $self->AppDV->json->decode($params_enc) if (defined $params_enc);
	
	
	my $cnf = {
		xtype 	=> 'ajaxcmp',
		applyCnf => {
			plugins => [ 'autowidthtoolbars' ],
			autoHeight => \1
		},
		renderTarget => 'div.appdv-submodule.' . $name,
		applyValue => $self->AppDV->record_pk,
		autoLoad	=> {
			url		=> $url,
			params	=> $params
		},
	};
	
	return $self->div_module($name,$cnf);
}


sub div_module_content {
	my $self = shift;
	my $name = shift;
	my $Module = shift;
	
	my $cnf = {
		%{ $Module->content },
		plugins => [ 'autowidthtoolbars' ],
		autoHeight => \1,
		renderTarget => 'div.appdv-submodule.' . $name,
		applyValue => $self->AppDV->record_pk
	};
	
	return $self->div_module($name,$cnf);
}


sub div_module {
	my $self = shift;
	my $name = shift;
	my $cnf = shift;
	
	# Apply optional overrides:
	$cnf = { %$cnf, %{ $self->AppDV->submodule_config_override->{$name} } } if ($self->AppDV->submodule_config_override->{$name});
	
	# Store component configs as serialized JSON to make sure
	# they come out the same every time on the client side:
	$self->AppDV->DVitems->{$name} = $self->AppDV->json->encode($cnf);
	
	return '<div class="appdv-submodule ' . $name . '"></div>';
}





has 'toggle' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return {
			edit => $self->div_clickable(
				'<div class="edit-record-toggle">' .
					'<div class="edit">Edit</div>' .
					'<div class="save">Save</div>' .
					'<div class="cancel">Cancel</div>' .
				'</div>'
			),
							
			select	=> '<div class="appdv-toggle select"></div>'
		};
	}
);




1;
