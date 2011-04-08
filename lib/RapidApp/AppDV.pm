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


sub is_web1_request {
	my $self = shift;
	my @args = reverse @{$self->c->req->args};
	return 1 if ($args[0] =~ /web1\.0/);
	return 0;
}



has 'submodule_config_override' => (
	is        => 'ro',
	isa       => 'HashRef[HashRef]',
	default   => sub { {} }
);

has '+DataStore_build_params' => ( default => sub {{
	store_autoLoad => \1
}});

sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		xtype				=> 'appdv',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		overClass		=> 'record-over',
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
		or die $Template->error;
	
	return $html_out unless ($self->apply_css_restrict);
	
	#TODO: make this more robust/better:	
	my @classes = ();
	push @classes, 'no_create' unless ($self->can('create_records'));
	push @classes, 'no_update' unless ($self->can('update_records'));
	push @classes, 'no_destroy' unless ($self->can('destroy_records'));

	return '<div class="' . join(' ',@classes) . '">' . $html_out . '</div>';
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
	
	$renderCxt->write($self->web1_string_content);
}

sub web1_string_content {
	my $self = shift;
	my $xtemplate = $self->xtemplate_cnf;
	return $self->render_xtemplate_with_tt($xtemplate);
}




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
		START_TAG	=> '{',
		END_TAG		=> '}'
	});
	
	my $data = $self->DataStore->read;
	
	#$self->c->scream($data,$tpl);
	
	$Template->process(\$tpl,$data,\$html_out) or die usererr $Template->error;
	
	return $start . $html_out . $end;
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;