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
	return '<div class="clickable">' . 
		(shift) . 
	'</div>';
}


sub div_clickable_field {
	my $self = shift;
	my $name = shift;
	return $self->div_wrapper(
		$self->div_clickable(
			'<div class="editable-value">' .
				'<div class="field-name" style="display:none;">' . $name . '</div>' .
				'<table><tr>' .
					'<td class="data">' .
						'<div class="data-inner">{' . $name . '}</div>' .
					'</td>' .
									
					'<td class="icons">' .
						'<div class="edit">&nbsp;</div>' .
						'<div class="save">&nbsp;</div>' .
						'<div class="cancel">&nbsp;</div>' .
					'</td>' .
					
					
				'</tr></table>' .
			'</div>'
		)
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

			return $self->div_clickable_field($Column->name);
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

			return
			
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
			
			my $cnf = {
				%{ $Module->content },
				
				renderTarget => 'div.appdv-submodule.' . $name,
				applyValue => $self->AppDV->record_pk
			};
			
			# Apply optional overrides:
			$cnf = { %$cnf, %{ $self->AppDV->submodule_config_override->{$name} } } if ($self->AppDV->submodule_config_override->{$name});
			
			# Store component configs as serialized JSON to make sure
			# they come out the same every time on the client side:
			$self->AppDV->DVitems->{$name} = $self->AppDV->json->encode($cnf);
			
			return '<div class="appdv-submodule ' . $name . '"></div>';
		});
	}
);


has 'toggle' => (
	is => 'ro',
	lazy => 1,
	default => sub {{
		edit 		=> '<div class="appdv-toggle edit">Edit</div>',
		select	=> '<div class="appdv-toggle select"></div>'
	}}
);




1;
