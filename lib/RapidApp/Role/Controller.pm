package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON::PP;
use Moose::Role;
with 'RapidApp::Role::Module';

use RapidApp::JSONFunc;
use Try::Tiny;
use Scalar::Util 'blessed';

use Term::ANSIColor qw(:constants);


our $VERSION = '0.1';


has 'base_url' => ( 
	is => 'rw', lazy => 1, default => sub { 
		my $self = shift;
		
		my $url = $self->c->namespace;
		$url = $self->parent_module->base_url . '/' . $self->{module_name} if (defined  $self->parent_module); 
		return $url;
	},
	traits => [ 'RapidApp::Role::PerRequestVar' ] 
);
has 'actions'					=> ( is => 'ro', 	default => sub {{}} );
has 'extra_actions'			=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'content'					=> ( is => 'ro',	default => '' );
has 'render_as_json'			=> ( is => 'rw',	default => 1 );
has 'auto_viewport'			=> ( is => 'rw',	default => 1 );

sub c {
	return $RapidApp::ScopedGlobals::CatalystInstance;
}



has 'no_persist' => ( is => 'rw', lazy => 1, default => sub {
	my $self = shift;
	# inherit the parent's no_persist setting if its set:
	return $self->parent_module->no_persist if (
		defined $self->parent_module and 
		defined $self->parent_module->no_persist
	);
	return undef;
});

has 'render_append'			=> ( is => 'rw', default => '', isa => 'Str' );

sub add_render_append {
	my $self = shift;
	my $add or return;
	die 'ref encountered, string expected' if ref($add);
	
	my $cur = $self->render_append;
	return $self->render_append( $cur . $add );
}


has 'no_json_ref_types' => ( is => 'ro', default => sub {
	return {
		'IO::File'	=> 1
	}
});

has 'create_module_params' => ( is => 'ro', lazy => 1,	default => sub {
	my $self = shift;
	return {
		c => $self->c
	};
});

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
	my $self = shift;
	return JSON::PP->new->allow_blessed->convert_blessed;
}

sub JSON_encode {
	my $self = shift;
	return $self->json->encode(shift);
}

# Initializes variables of the controller based on the details of the current request being handled.
# This is a stub for 'after's and 'before's and overrides.
sub prepare_controller {
}

sub Controller {
	my ($self, $c, @args) = @_;
	
	# base_url has been set by the Module function in the process of getting this module, or it will default to c->namespace
	# 'c' is now a function that pulls from ScopedGlobals
	# no_persist attributes are cleared at the end of TopController, rather than
	#   before each module's controller at the next request. (frees up memory sooner, reduces bugs)
	# mangling the request path can now be performed by prepare_controller
	
	# run user-defined or mix-in code to get ready to process the action
	# the prepare function can modify the argument list if it so chooses
	
	$self->prepare_controller(\@args);
	
	# dispatch the request to the appropriate handler
	
	$self->c->log->info('--> ' . GREEN . BOLD . ref($self) . CLEAR . '  ' . join(' . ',@args));
	
	$self->controller_dispatch(@args);
}


sub clear_attributes {
	my $self = shift;
	for my $attr ($self->meta->get_all_attributes) {
		next if ($attr->name eq 'actions');
		$attr->clear_value($self) if ($attr->is_lazy or $attr->has_clearer);
	}
}



# This is moved into a separate function so that overridden controllers can re-use this functionality
sub controller_dispatch {
	my ($self, $opt, @subargs)= @_;
	
	if (defined $opt and (defined $self->actions->{$opt} or defined $self->extra_actions->{$opt}) ) {
		return $self->process_action($opt,@subargs);
	}
	elsif (defined $opt and $self->_load_module($opt)) {
		return $self->Module($opt)->Controller($self->c,@subargs);
	}
	elsif (defined $self->default_action) {
		return $self->process_action($self->default_action,@_);
	}
	else {
		# if there were unprocessed arguments which were not an action, and there was no default action, generate a 404
		if (defined $opt) {
			$self->c->log->info("--> " . RED . BOLD . "unknown action: $opt" . CLEAR);
			$self->c->stash->{current_view} = 'HTTP404';  # default to an error page
			return undef;
		}
		elsif ($self->c->stash->{reqContentType} ne 'JSON' && $self->auto_viewport) {
			$self->c->log->info("--> " . GREEN . BOLD . "[viewport]" . CLEAR . ". (no action)");
			return $self->viewport;
		}
		else {
			$self->c->log->info("--> " . GREEN . BOLD . "[content]" . CLEAR . ". (no action)");
			return $self->render_data($self->content);
		}
	}
}

=pod
around 'Module' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $Module = $self->$orig(@_) or return undef;
	
	$Module->base_url($self->base_url . '/' . $Module->module_name) if (
		$Module->does('RapidApp::Role::Controller')
	);
	
	return $Module;
};
=cut

sub process_action {
	my $self = shift;
	my ( $opt, @args ) = @_;
	
	$self->c->log->info("--> " . GREEN . BOLD . "action{ " . $opt . " }");
	
	defined $opt or die "No action specified";
	
	my $coderef = $self->actions->{$opt} || $self->extra_actions->{$opt};
	defined $coderef or die "No action named $opt";
	
	# New: if $coderef is not actually a coderef, we assume its a string representing an 
	# object method and we call it directly:
	return $self->render_data( ref($coderef) eq 'CODE'? $coderef->() : $self->$coderef );
}


sub render_data {
	my ($self, $data)= @_;
	
	# do nothing if the body has been set
	return undef if defined $self->c->response->body;
	
	# do nothing if the view has been configured
	return $data if defined $self->c->stash->{current_view};
	
	# if we want auto-json rendering, use the JSON view
	if ($self->render_as_json && ref($data) && !defined $self->no_json_ref_types->{ref($data)}) {
		$self->c->stash->{current_view} = 'RapidApp::JSON';
		return $data;
	}
	# else set the body directly and use no view
	else {
		$self->c->response->header('Cache-Control' => 'no-cache');
		return $self->c->response->body( $data );
	}
}

sub viewport {
	my $self= shift;
	$self->c->stash->{current_view} = 'RapidApp::TT';
	$self->c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
	$self->c->stash->{title} = $self->module_name;
	$self->c->stash->{config_url} = $self->base_url;
	my %params= %{$self->c->req->params};
	use Data::Dumper;
	$self->c->log->debug(Dumper(\%params));
	if (scalar keys %params) {
		$self->c->stash->{config_params} = RapidApp::JSON::MixedEncoder::encode_json(\%params);
	}
}

# add or replace actions (i.e. as passed to the action param of the constructor):
sub apply_actions {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	#my $new_actions = {
	#	%{ $self->actions },
	#	%new
	#};
	
	#my $attr = $self->meta->find_attribute_by_name('actions');
	#$attr->set_value($self,$new_actions);
	
	%{ $self->actions } = (
		%{ $self->actions },
		%new
	);
}


sub set_response_warning {
	my $self = shift;
	my $warn = shift;
	
	$warn = {
		title	=> 'Warning',
		msg	=> $warn
	} unless (ref($warn));
	
	die "Invalid argument passed to set_response_warning" unless (ref($warn) eq 'HASH' and defined $warn->{msg});
	
	return $self->c->response->header('X-RapidApp-Warning' => $self->json->encode($warn));
}


1;