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
use Data::Dumper;

use Term::ANSIColor qw(:constants);

use RapidApp::Error;
use Exception::Class (
	'RapidApp::Role::Controller::UnknownAction' => {
		isa => 'RapidApp::Error',
		fields => [ 'unknown_arg' ]
	}
);

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

#has 'extra_actions'			=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'render_as_json'			=> ( is => 'rw',	default => 1, traits => [ 'RapidApp::Role::PerRequestVar' ]  );
has 'auto_viewport'			=> ( is => 'rw',	default => 0 );


has 'actions' => (
	traits	=> ['Hash'],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_actions	=> 'set',
		 get_action		=> 'get',
		 has_action		=> 'exists'
	}
);


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
	return RapidApp::JSON::MixedEncoder->new;
}

sub JSON_encode {
	my $self = shift;
	return $self->json->encode(shift);
}

# Initializes variables of the controller based on the details of the current request being handled.
# This is a stub for 'after's and 'before's and overrides.
sub prepare_controller {
}

=head2 Controller( $catalyst, @pathArguments )

This method handles a request.

=cut
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


=head2 controller_dispatch( @args )

controller_dispatch performs the standard RapidApp dispatch processing for a Module.

=over

=item *

If the first argument names an action, the action is executed.

=item *

If the first argument names a sub-module, the processing is passed to the sub-module.

=item *

If the first argument does not match anything, then the default action is called, if specified,
otherwise a 404 is returned to the user.

=item *

If there are no arguments, and the client was not requesting JSON, the viewport is executed.

=item *

Else, content is called, and its return value is passed to render_data.

=back

=cut
sub controller_dispatch {
	my ($self, $opt, @subargs)= @_;
	
	if ( defined $opt and $self->has_action($opt) ) {
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
			if ($self->c->stash->{requestContentType} ne 'JSON') {
				$self->c->stash->{current_view} = 'RapidApp::HttpStatus';
				$self->c->res->status(404);
				return undef;
			} else {
				die RapidApp::Role::Controller::UnknownAction->new(message => "Unknown module or action", unknown_arg => $opt);
			}
		}
		elsif ($self->c->stash->{requestContentType} ne 'JSON' && $self->auto_viewport) {
			$self->c->log->info("--> " . GREEN . BOLD . "[viewport]" . CLEAR . ". (no action)");
			return $self->viewport;
		}
		else {
			$self->c->log->info("--> " . GREEN . BOLD . "[content]" . CLEAR . ". (no action)");
			return $self->render_data($self->content);
		}
	}
}

=head2 process_action( $actionName, [optional @args] )

This routine handles the execution of a selected action.  The action must exist.
For actions that map to coderefs, the coderef is executed.
For actions that map to strings, a method of that name is called on $self.

=cut
sub process_action {
	my $self = shift;
	my ( $opt, @args ) = @_;
	
	$self->c->log->info("--> " . GREEN . BOLD . "action{ " . $opt . " }" . CLEAR);
	
	defined $opt or die "No action specified";
	
	my $coderef = $self->get_action($opt);
	defined $coderef or die "No action named $opt";
	
	# New: if $coderef is not actually a coderef, we assume its a string representing an 
	# object method and we call it directly:
	return $self->render_data( ref($coderef) eq 'CODE'? $coderef->() : $self->$coderef );
}

=head2 render_data( $data )

This is a very DWIM sort of routine that takes its parameter (likely the return value of
content or an action) and picks an appropriate view for it, possibly ignoring it altogether.

=over

=item *

If the action generated a body, no view is needed, and the parameter is ignored.

=item *

If the action chose its own view, no further processing is done, and the parameter is returned.

=item *

If the controller is configured to render json (the default) and the parameter isn't blacklisted
in no_json_ref_types, and the parameter isn't a plain string, the RapidApp::JSON view is chosen.
The parameter is returned (as-is) to get passed back to TopController who passes it to the view.

=item *

Else, the data is treated as an explicit string for the body.  The body is assigned, and returned.

=back

=cut
sub render_data {
	my ($self, $data)= @_;
	
	#$self->c->log->debug(Dumper($data));
	
	# do nothing if the body has been set
	if (defined $self->c->response->body && length $self->c->response->body) {
		$self->c->log->debug("(body set by user)");
		return undef;
	}
	
	# do nothing if the view has been configured
	if (defined $self->c->stash->{current_view} || defined $self->c->stash->{current_view_instance}) {
		$self->c->log->debug("(view set by user)");
		return $data;
	}
	
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
	$self->c->stash->{current_view} = 'RapidApp::Viewport';
	$self->c->stash->{title} = $self->module_name;
	$self->c->stash->{config_url} = $self->base_url;
	if (scalar keys %{$self->c->req->params}) {
		$self->c->stash->{config_params} = { %{$self->c->req->params} };
	}
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