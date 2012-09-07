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
		
		my $parentUrl= defined $self->parent_module? $self->parent_module->base_url.'/' : '';
		return $parentUrl . $self->{module_name};
	},
	traits => [ 'RapidApp::Role::PerRequestVar' ] 
);

#has 'extra_actions'			=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'render_as_json'			=> ( is => 'rw',	default => 1, traits => [ 'RapidApp::Role::PerRequestVar' ]  );
has 'auto_web1'				=> ( is => 'rw',	default => 0 );

# NEW: if true, sub-args (of url path) are passed in even if the sub path does
# not exist as a defined action or sub-module. TODO: refactor and use built-in Catalyst
# functionality for controller actions. ALL of Module/Controller should be refactored
# into proper sub-classes of Catalyst controllers
has 'accept_subargs', is => 'ro', isa => 'Bool', default => 0;

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

# In catalyst terminology, "c" is the catalyst instance, embodying a request.
sub c {
	return RapidApp::ScopedGlobals->get('catalystInstance');
}

# In catalyst terminology, "app" is the package name of the class that extends catalyst
# Many catalyst methods can be called from the package level
sub app {
	return RapidApp::ScopedGlobals->catalystClass;
}

# The current logger object, probably the same as ->c->log, but maybe not.
sub log {
	return RapidApp::ScopedGlobals->log;
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

has 'create_module_params' => ( is => 'ro', lazy => 1, default => sub {{}} );

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
	my $self = shift;
	#$self->log->warn((ref $self)."->json still being used");
	return RapidApp::JSON::MixedEncoder->new;
}

sub JSON_encode {
	my $self = shift;
	return $self->json->encode(shift);
}

# This method attempts to set up a catalyst request instance such that a new request can be executed
#   to a different module and with different parameters and HTTP headers than were used for the main
#  request.
sub simulateRequest {
	my ($self, $req)= @_;
	
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	
	my $tempResp= Catalyst::Response->new();
	
	my $origReq= $c->request;
	my $origResp= $c->response;
	my $origStash= $c->stash;
	
	try {
		$c->request($req);
		$c->response($tempResp);
		
		# This is dangerous both any way you do it.  We could make an empty stash, but then might lose important
		#   settings (like those set by ModuleDispatcher)
		$c->stash({ %$origStash });
		
		my $path= $req->uri->path;
		$path =~ s|^/||;
		my @args= split('/', $path);
		$self->c->log->debug("Simulate Request: \"".join('", "', @args));
		my $ctl_ret= $self->Controller($c, @args);
		
		$c->log->debug('controller return: '.(length($ctl_ret) > 20? (ref $ctl_ret).' length='.length($ctl_ret) : $ctl_ret));
		$c->log->debug('body: '.(length($tempResp->body) > 20? (ref $tempResp->body).' length='.length($tempResp->body) : $tempResp->body));
		
		# execute the specified view, if needed
		if (!defined $c->res->body) {
			my $view= $self->c->stash->{current_view_instance} || $c->view($c->stash->{current_view});
			$view->process($c);
		}
		
		$c->request($origReq);
		$c->response($origResp);
		$c->stash($origStash);
	}
	catch {
		$c->request($origReq);
		$c->response($origResp);
		$c->stash($origStash);
		die $_;
	};
	return $tempResp;
}

sub simulateRequestToSubUrl {
	my ($self, $uri, @params)= @_;
	blessed($uri) && $uri->isa('URI') or $uri= URI->new($uri);
	
	# if parameters were part of the URI, extract them first, then possibly override them with @params
	# Note that "array-style" URI params will be returned as duplicate key entries, so we have to do some work to
	#   assemble the values into lists to match the way you'd expect it to work.
	my @uriParams= $uri->query_form;
	my %paramHash;
	for (my $i=0; $i < $#uriParams; $i+= 2) {
		my ($key, $val)= ($uriParams[$i], $uriParams[$i+1]);
		$paramHash{$key}= (!defined $paramHash{$key})?
			$val
			: (ref $paramHash{$key} ne 'ARRAY')?
				[ $paramHash{$key}, $val ]
				: [ @{$paramHash{$key}}, $val ];
	}
	
	# add in the supplied parameters
	%paramHash= ( %paramHash, @params );
	
	my $req= Catalyst::Request->new( uri => $uri, parameters => \%paramHash );
		
	return $self->simulateRequest($req);
}

sub simulateRequestToSubUrl_asString {
	my $self= shift;
	my $resp= $self->simulateRequestToSubUrl(@_);
	$resp->status == 200
		or die "Simulated request to ".$_[0]." returned status ".$resp->status;
	my $ret= $resp->body;
	if (ref $ret) {
		my $fd= $ret;
		local $/= undef;
		$ret= <$fd>;
		$fd->close;
	}
	return $ret;
}

# Initializes variables of the controller based on the details of the current request being handled.
# This is a stub for 'after's and 'before's and overrides.
sub prepare_controller {
}

=head2 Controller( $catalyst, @pathArguments )

This method handles a request.

=cut

# new available API accessor:
our $LOCAL_ARGS = [];
sub local_args { @$LOCAL_ARGS }

sub Controller {
	my ($self, $c, @args) = @_;
	
	# track the current argument list in a localized global for easy access:
	local $LOCAL_ARGS = \@args;
	
	# base_url has been set by the Module function in the process of getting this module, or it will default to c->namespace
	# 'c' is now a function that pulls from ScopedGlobals
	# no_persist attributes are cleared at the end of TopController, rather than
	#   before each module's controller at the next request. (frees up memory sooner, reduces bugs)
	# mangling the request path can now be performed by prepare_controller
	
	# run user-defined or mix-in code to get ready to process the action
	# the prepare function can modify the argument list if it so chooses
	
	#$self->prepare_controller(\@args); # why was this passed as a ref?? - changed 2012-09-07 by HV
	$self->prepare_controller(@args);
	
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
		my $ct= $self->c->stash->{requestContentType};
		# if there were unprocessed arguments which were not an action, and there was no default action, generate a 404
		# UPDATE: unless new 'accept_subargs' attr is true (see attribute declaration above)
		if (defined $opt && !$self->accept_subargs) {
			$self->c->log->info("--> " . RED . BOLD . "unknown action: $opt" . CLEAR);
			if ($ct eq 'text/x-RapidApp-FormSubmitResponse'
				|| $ct eq 'JSON'
			) {
				die RapidApp::Role::Controller::UnknownAction->new(message => "Unknown module or action '$opt'", unknown_arg => $opt);
			}
			else {
				$self->c->stash->{current_view} = 'RapidApp::HttpStatus';
				$self->c->res->status(404);
				return 1;
			}
		}
		elsif ($ct ne 'JSON' && $ct ne 'text/x-rapidapp-form-response' && $self->auto_web1) {
			$self->c->log->info("--> " . GREEN . BOLD . "[web1_content]" . CLEAR . ". (no action)");
			return $self->web1_content;
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
	return $self->render_data( ref($coderef) eq 'CODE'? $coderef->($self,@args) : $self->$coderef(@args) );
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
		
		# check for the condition that will cause a "Wide character in syswrite" and give a better error message
		if (utf8::is_utf8($self->c->response->body)) {
			$self->c->response->content_type =~ /^text|xml$|javascript$|JSON$/
				or $self->c->log->warn("Controller ".(ref $self)." returned unicode text but isn't using a \"text\" content type!");
		}
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

requires 'content';
requires 'web1_content';

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

# if response_callback_scoped is true when set_response_callback is called, the
# function will be called with the scope (this reference) of the Ext.data.Connection
# object that initiated the Ajax request (Ext.Ajax.request) and this.response will
# also contain the response object; This is false by default because setting the 
# scope breaks many functions, and this is usually not needed (the only reason to
# turn this on would be if you need to examine the specific request/response)
has 'response_callback_scoped' => (
	is => 'rw',
	traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
	default => 0
);

=item
set_response_callback examples

$self->set_response_callback( 'Ext.ux.MyFunc' );

$self->set_response_callback( alert => 'foo!' );

$self->set_response_callback( 'Ext.Msg.alert' => ( 'A message!!', 'this is awesome!!' ) );

my $func = RapidApp::JSONFunc->new( raw => 1, func => 'function(){ console.log("anon!!"); console.dir(this.response); }');	
$self->response_callback_scoped(1);
$self->set_response_callback( $func => ( "arg1",{ key_in_arg2 => 'blah!!!' },'arg3',\1  ) );

=cut

# when calling set_response_callback the JS function specified will be
# called after the request is completed successfully
sub set_response_callback {
	my ($self, $func, @args) = @_;

	my $data = {};
	$data->{arguments} = [ @args ] if (scalar @args > 0);
	
	if(ref($func) eq 'RapidApp::JSONFunc') {
		die "only 'raw' RapidApp::JSONFunc objects are supported" unless ($func->raw);
		$data->{anonfunc} = $func;
	}
	else {
		$data->{func} = $func;
	}
	
	$data->{scoped} = \1 if ($self->response_callback_scoped);
	
	return $self->c->response->header( 'X-RapidApp-Callback' => $self->json->encode($data) );
}


has 'response_server_events' => (
	is => 'ro',
	isa => 'ArrayRef[Str]',
	traits => [ 'Array' ],
	default => sub {[]},
	handles => {
		add_response_server_events	=> 'push',
		all_response_server_events	=> 'uniq'
	}
);
after 'add_response_server_events' => sub {
	my $self = shift;
	$self->c->response->header( 
		'X-RapidApp-ServerEvents' => $self->json->encode([ $self->all_response_server_events ]) 
	);
};






1;