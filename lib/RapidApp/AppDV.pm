package RapidApp::AppDV;
# Editable DataView class

use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use RapidApp::Include qw(sugar perlutil);

use Template;
use RapidApp::RecAutoload;

has 'tt_include_path' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
		return $self->app->config->{RapidApp}->{rapidapp_root};
	}
);

has 'tt_file' => ( is => 'ro', isa => 'Str', required => 1 );


has 'submodule_config_override' => (
	is        => 'ro',
	isa       => 'HashRef[HashRef]',
	default   => sub { {} }
);



sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		id					=> $self->instance_id,
		xtype				=> 'appdv',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		items => []
		#tpl				=> $self->xtemplate
	);
	
	
	#$self->add_listener( afterrender	=> 'Ext.ux.RapidApp.AppDV.afterrender_handler' );
	$self->add_listener(	click 		=> 'Ext.ux.RapidApp.AppDV.click_handler' );
	
	# FIXME: call this once instead of on every request:
	$self->add_ONREQUEST_calls('load_xtemplate');

}

sub load_xtemplate {
	my $self = shift;
	$self->apply_extconfig( tpl => $self->xtemplate );
	$self->apply_extconfig( FieldCmp_cnf => $self->FieldCmp );
	$self->apply_extconfig( items => [ values %{ $self->DVitems } ] );
}




sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
}


has 'DVitems' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
has 'FieldCmp' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has 'xtemplate_cnf' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
	
		my $tpl_vars = {};
		
		$tpl_vars->{field} = RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->columns->{$name} or return '';
			$self->FieldCmp->{$Column->name} = $Column->get_field_config;
			
			return '<div class="' . $Column->name . '">{' . $Column->name . '}</div>';
		});
		
		$tpl_vars->{edit_field} = RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			my $Column = $self->columns->{$name} or return '';
			
			$self->FieldCmp->{$Column->name} = $Column->get_field_config;


			
			return
			
			'<div class="appdv-click ' . $self->get_extconfig_param('id') . '">' .
			
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
		
		
		$tpl_vars->{submodule} = RapidApp::RecAutoload->new( process_coderef => sub {
			my $name = shift;
			
			my $Module = $self->Module($name) or return '';
			
			my $cnf = {
				%{ $Module->content },
				
				renderTarget => 'div.appdv-submodule.' . $name,
				applyValue => $self->record_pk
			};
			
			# Apply optional overrides:
			$cnf = { %$cnf, %{ $self->submodule_config_override->{$name} } } if ($self->submodule_config_override->{$name});
			
			# Store component configs as serialized JSON to make sure
			# they come out the same every time on the client side:
			$self->DVitems->{$name} = $self->json->encode($cnf);
			
			return '<div class="appdv-submodule ' . $name . '"></div>';
		});
		
		my $html_out = '';
		
		my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
		$Template->process($self->tt_file,$tpl_vars,\$html_out)
			or die $Template->error;
		
		return $html_out;
		}
);






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;