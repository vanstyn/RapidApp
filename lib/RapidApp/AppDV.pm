package RapidApp::AppDV;
# Editable DataView class


use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';


use Template;

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
	
	# FIXME: call this once instead of on every request:
	$self->add_ONREQUEST_calls('load_xtemplate');

}

sub load_xtemplate {
	my $self = shift;
	$self->apply_extconfig( tpl	=> $self->xtemplate );
}




sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
}

has 'xtemplate_cnf' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
	
		my $tpl_vars = {};
		
		foreach my $column (keys %{$self->DataStore->columns}) {
			$tpl_vars->{field}->{$column} = '<div class="' . $column . '">{' . $column . '}</div>';
			$tpl_vars->{edit_field}->{$column} = 
			'<div class="' . $column . '">' . 
				'<div class="edit_field_lnk" style="float: right;padding-top:4px;padding-left:4px;cursor:pointer;"><img src="/static/rapidapp/images/pencil_tiny.png"></div>' .
				'{' . $column . '}' .
			'</div>';
		}
		
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