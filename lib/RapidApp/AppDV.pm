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

sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		xtype				=> 'dataview',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		#tpl				=> $self->xtemplate
	);
	
	$self->add_listener( click => 'Ext.ux.RapidApp.AppDV.click_handler' );
	
	# FIXME: call this once instead of on every request:
	$self->add_ONREQUEST_calls('load_xtemplate');

}

sub load_xtemplate {
	my $self = shift;
	$self->apply_extconfig( tpl => $self->xtemplate );
	$self->apply_extconfig( FieldCmp_cnf => $self->FieldCmp );
}




sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
}


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
				'<div class="appdv-click-el edit:' . $Column->name . '" style="float: right;padding-top:4px;padding-left:4px;cursor:pointer;"><img src="/static/rapidapp/images/pencil_tiny.png"></div>' .
				'<div class="appdv-field-value ' . $Column->name . '"><div class="data">{' . $Column->name . '}</div></div>';
			#'</div>';
		});
		
		my $html_out = '';
		
		my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
		$Template->process($self->tt_file,$tpl_vars,\$html_out)
			or die usererr $Template->error;
		
		return $html_out;
		}
);






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;