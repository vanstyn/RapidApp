package RapidApp::AppDV;
# Editable DataView class

use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use RapidApp::Include qw(sugar perlutil);

use Template;
use RapidApp::AppDV::TTController;

use HTML::TokeParser::Simple;

has 'apply_css_restrict' => ( is => 'ro', default => 0 );

has 'extra_tt_vars' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {{}}
);


has 'TTController'  => (
	is => 'ro',
	isa => 'RapidApp::AppDV::TTController',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::AppDV::TTController->new( AppDV => $self );
	}
);

has 'tt_include_path' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
		#return $self->app->config->{RapidApp}->{rapidapp_root};
		return $self->app->config->{root}->stringify . '/templates';
	}
);

has 'tt_file' => ( is => 'ro', isa => 'Str', required => 1 );
has 'tt_file_web1' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );


has 'submodule_config_override' => (
	is        => 'ro',
	isa       => 'HashRef[HashRef]',
	default   => sub { {} }
);

has '+DataStore_build_params' => ( default => sub {{
	store_autoLoad => \1
}});

# persist_on_add is AppDV specific, and causes a store save to happen *after* a
# new record has been added via filling out fields. when persist_immediately.create
# is set empty records are instantly created without giving the user the chance
# set the initial values
has 'persist_on_add' => ( is => 'ro', isa => 'Bool', default => 1 );
has '+persist_immediately' => ( default => sub {{
	create	=> \0,
	update	=> \1,
	destroy	=> \1
}});

sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		xtype				=> 'appdv',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		overClass		=> 'record-over',
		persist_on_add	=> \scalar($self->persist_on_add),
		items => []
	);
	
	
	#$self->add_listener( afterrender	=> 'Ext.ux.RapidApp.AppDV.afterrender_handler' );
	#$self->add_listener(	click 		=> 'Ext.ux.RapidApp.AppDV.click_handler' );
	
	# FIXME: call this once instead of on every request:
	$self->add_ONREQUEST_calls('load_xtemplate');

}

sub load_xtemplate {
	my $self = shift;
	$self->apply_extconfig( id => $self->instance_id );
	$self->apply_extconfig( tpl => $self->xtemplate );
	$self->apply_extconfig( FieldCmp_cnf => $self->FieldCmp );
	$self->apply_extconfig( items => [ values %{ $self->DVitems } ] );
	
	my $params = $self->c->req->params;
	my @qry = ();
	foreach my $p (keys %$params) {
		push @qry, $p . '=' . $params->{$p};
	}
	
	my $qry_str = join('&',@qry);
	
	$self->apply_extconfig( printview_url => $self->suburl('printview') . '?' . $qry_str );
}

sub xtemplate_cnf {
	my $self = shift;
	
	my $html_out = '';
	
	my $tt_vars = {
		r	=> $self->TTController,
		%{ $self->extra_tt_vars }
	};
	
	my $tt_file = $self->tt_file;
	$tt_file = $self->tt_file_web1 if ($self->tt_file_web1 and $self->is_web1_request);
	
	my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
	$Template->process($tt_file,$tt_vars,\$html_out)
		or die $Template->error . "  Template file: $tt_file";
	
	return $html_out unless ($self->apply_css_restrict);
	
	#TODO: make this more robust/better:	
	my @classes = ();
	#push @classes, 'no_create' unless ($self->can('create_records'));
	#push @classes, 'no_update' unless ($self->can('update_records'));
	#push @classes, 'no_destroy' unless ($self->can('destroy_records'));
	push @classes, 'no_create' unless ($self->DataStore->create_handler);
	push @classes, 'no_update' unless ($self->DataStore->update_handler);
	push @classes, 'no_destroy' unless ($self->DataStore->destroy_handler);
	
	
	return '<div class="' . join(' ',@classes) . '">' . $html_out . '</div>';
}



sub xtemplate {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		#func => 'new Ext.XTemplate',
		func => 'Ext.ux.RapidApp.newXTemplate',
		parm => [ $self->xtemplate_cnf, $self->xtemplate_funcs ]
	);
}


# The 'renderField' function defined here is called by 'autofield' in TTController
# This is needed because complex logic can't be called directly within {[ ... ]} in
# XTemplates; only function calls. This function accepts a function as an argument 
# (which is allowed) and then calls it in the format and with the arguments expected
# from a Column renderer:
sub xtemplate_funcs {
	my $self = shift;
	return {
		compiled => \1,
		disableFormats => \1,
		renderField => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(name,values,renderer) {' .
				'var record = { data: values };' .
				'return renderer(values[name],{},record);' .
			'}'
		)
	};
}




has 'DVitems' => ( 
	is => 'ro', 
	traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ], 
	isa => 'HashRef', 
	default => sub {{}} 
);

has 'FieldCmp' => ( 
	is => 'ro', 
	traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ], 
	isa => 'HashRef', 
	default => sub {{}} 
);





# Dummy read_records:
sub read_records {
	my $self = shift;
	
	return {
		results => 1,
		rows => [{ $self->record_pk => 1 }]
	};
}


sub web1_render {
	my ($self, $renderCxt)= @_;
	
	$self->c->stash->{template} = 'templates/rapidapp/ext_page.tt';
	
	my $html_out = $self->web1_string_content;
	
	my @classes = ();
	push @classes, 'no_create';
	push @classes, 'no_update';
	push @classes, 'no_destroy';

	$html_out = '<div class="' . join(' ',@classes) . '">' . $html_out . '</div>';
	
	$renderCxt->write($html_out);
}

sub web1_string_content {
	my $self = shift;
	my $xtemplate = $self->xtemplate_cnf;
	return $self->render_xtemplate_with_tt($xtemplate);
}

# This code is not yet fully working. It attemps to process an Ext.XTemplate with TT
sub render_xtemplate_with_tt {
	my $self = shift;
	my $xtemplate = shift;
	
	#return $xtemplate;
	
	my $parser = HTML::TokeParser::Simple->new(\$xtemplate);
	
	my $start = '';
	my $inner = '';
	my $end = '';
	
	while (my $token = $parser->get_token) {
		unless ($token->is_start_tag('tpl')) {
			$start .= $token->as_is;
			next;
		}
		while (my $inToken = $parser->get_token) {
			last if $inToken->is_end_tag('tpl');
			
			$inner .= $inToken->as_is;
			

			if ($inToken->is_start_tag('div')) {
				my $class = $inToken->get_attr('class');
				my ($junk,$submod) = split(/appdv-submodule\s+/,$class);
				if ($submod) {
					my $Module = $self->Module($submod);
					$inner .= $Module->web1_string_content if ($Module and $Module->can('web1_string_content'));
				}
				
			}
		}
		while (my $enToken = $parser->get_token) {
			$end .= $enToken->as_is;
		}
		last;
	}
	
	#$self->c->scream([$start,$inner,$end]);
	
	my $tpl = '{ FOREACH rows }' . $inner . '{ END }';
	
	my $html_out = '';
	my $Template = Template->new({
		START_TAG	=> /\{/,
		END_TAG		=> /\}/
	});
	
	my $data = $self->DataStore->read;
	
	#$self->c->scream($data,$tpl);
	
	$Template->process(\$tpl,$data,\$html_out) 
		or die "Template error (" . $Template->error . ')' .
		"\n\n" .
		"  Template vars:\n" . Dumper($data) . "\n\n" .
		"  Template contents:\n" . Dumper($tpl);
	
	return $start . $html_out . $end;
}

sub is_printview {
	my $self = shift;
	return 1 if ($self->c->req->header('X-RapidApp-View') eq 'print');
	return 0;
}

# Available to derived classes. Can be added to toolbar buttons, etc
sub print_view_button {
	my $self = shift;
	
	my $params = $self->c->req->params;
	delete $params->{_dc};
	
	my $cnf = {
		url => $self->suburl('printview'),
		params => $params
	};
	
	my $json = $self->json->encode($cnf);
	
	return {
		xtype	=> 'button',
		text => 'Print View',
		iconCls => 'icon-printer',
		handler => jsfunc 'Ext.ux.RapidApp.winLoadUrlGET.createCallback(' . $json . ')'
	};
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;