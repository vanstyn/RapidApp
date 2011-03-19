package RapidApp::AppDV;
# Editable DataView class


use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';


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
		xtype				=> 'rcompdataview',
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
	$self->apply_extconfig( tpl => $self->xtemplate );
	$self->apply_extconfig( items => $self->cmpdv_items );
}




sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
}


has 'cmpdv_items' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );

has 'xtemplate_cnf' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
	
		my $tpl_vars = {};
		my $cmpdv_items = [];
		
		my $cmpdv_items_add = sub {
			my $column = shift;
			push @$cmpdv_items, {
				xtype => 'appdv-clickbox',
				cls => 'hops-note-edit',
				#qtip => 'Edit',
				height => 10,
				width => 10,
				#xtype => 'hops-editnotetoolbtn',
				handler => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppDV.edit_field_handler' ),
				renderTarget => 'div.' . $column . '_edit_field_lnk',
				applyValue => $self->record_pk,
			};
		};
		
		$tpl_vars->{field} = RapidApp::RecAutoload->new( process_coderef => sub {
			my $column = shift;
			return '' unless ($self->columns->{$column});
			$cmpdv_items_add->($column);
			
			return '<div class="' . $column . '">{' . $column . '}</div>';
		});
		
		$tpl_vars->{edit_field} = RapidApp::RecAutoload->new( process_coderef => sub {
			
			my $column = shift;
			return '' unless ($self->columns->{$column});
			$cmpdv_items_add->($column);
			
			return '<div class="' . $column . '">' . 
				'<div class="' . $column . '_edit_field_lnk" style="float: right;padding-top:4px;padding-left:4px;"></div>' .
				#'<div class="' . $column . '_edit_field_lnk" style="float: right;padding-top:4px;padding-left:4px;cursor:pointer;"><img src="/static/rapidapp/images/pencil_tiny.png"></div>' .
				'{' . $column . '}' .
			'</div>';
		});
		
		my $html_out = '';
		
		my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
		$Template->process($self->tt_file,$tpl_vars,\$html_out)
			or die usererr $Template->error;
		
		$self->cmpdv_items($cmpdv_items);
		
		return $html_out;
		}
);






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;