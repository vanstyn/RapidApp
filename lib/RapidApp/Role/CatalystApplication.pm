package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use Scalar::Util 'blessed';
use CatalystX::InjectComponent;
use Hash::Merge;
use RapidApp::Debug 'DEBUG';
use Text::SimpleTable::AutoWidth;
use Catalyst::Utils;
use Path::Class qw(file dir);
use Time::HiRes qw(tv_interval);
use Clone qw(clone);
require Data::Dumper::Concise;
use URI::Escape;

use RapidApp;
use Template;

use Catalyst::Controller::SimpleCAS 0.991;

sub rapidapp_version { $RapidApp::VERSION }

sub rapidApp { (shift)->model("RapidApp"); }

has 'request_id' => ( is => 'ro', default => sub { (shift)->rapidApp->requestCount; } );

# ---
# Override dump_these to limit the depth of data structures which will get
# dumped. This is needed because RapidApp has a relatively large footprint
# and the dump can get excessive. This gets called from finalize_error
# when in debug mode.
around 'dump_these' => sub {
  my ($orig,$c,@args) = @_;

  # strip and capture original 'Request' and 'Response'
  my ($req_arr,$res_arr);
  my $these = [ grep {
    ! ($_->[0] eq 'Request'  and $req_arr = $_) &&
    ! ($_->[0] eq 'Response' and $res_arr = $_)
  } $c->$orig(@args) ];

  my @new_these = ();
  {
    require Data::Dumper;
    local $Data::Dumper::Maxdepth = 4;
    my $VAR1; eval( Data::Dumper::Dumper($these) );
    @new_these = (
      # Put the original, non-depth-limited Request and Reponse data back in.
      # We need to do this because there are other places in native Catalyst
      # code (e.g. log_request_uploads) which rely on getting the the unaltered 
      # request/response objects out of 'dump_these'. Also, these objects aren't
      # the ones which need to be limited anyway, so we preserve them as-is.
      # Added for Github Issue #54, and to preserve the API as of Catalyst 5.90065.
      # Note: the functioning of this stuff in Catalyst is legacy and may be 
      # refactored in a later version of Catalyst...
      $req_arr,$res_arr,
      @{$VAR1 || []}
    );
  }

  return @new_these;
};
# ---


around 'setup_components' => sub {
	my ($orig, $app, @args)= @_;
  
  $app->_normalize_catalyst_config;
  
  # Set the Encoding to UTF-8 unless one is already set:
  $app->encoding('UTF-8') unless ($app->encoding);
  
  # Force this standard setting. When it is off, in certain cases, it
  # can lead to bizzare regex exceptions. This setting is already automatically
  # set for all new apps created by recent versions of catalyst.pl
  $app->config( disable_component_resolution_regex_fallback => 1 );
  
  $app->$orig(@args);  # standard catalyst setup_components
  $app->setupRapidApp; # our additional components needed for RapidApp
};

sub setupRapidApp {
  my $app = shift;
  
  my @inject = (
    ['RapidApp::RapidApp' => 'RapidApp']
  );
  
  # Views:
  push @inject, (
    ['Catalyst::View::TT'            => 'View::RapidApp::TT'         ],
    ['RapidApp::View::Viewport'      => 'View::RapidApp::Viewport'   ],
    ['RapidApp::View::Printview'     => 'View::RapidApp::Printview'  ],
    ['RapidApp::View::JSON'          => 'View::RapidApp::JSON'       ],
    ['RapidApp::View::HttpStatus'    => 'View::RapidApp::HttpStatus' ],
    ['RapidApp::View::OnError'       => 'View::RapidApp::OnError'    ],
    ['RapidApp::View::Template'      => 'View::RapidApp::Template'   ]
  );
  
  ## This code allowed for automatic detection of an alternate, locally-defined
  ## 'ModuleDispatcher' controller to act as the root module controller. This
  ## functionality is not used anyplace, has never been public, and is not worth
  ## the maintenance cost
  #my $log = $app->log;
  #my @names= keys %{ $app->components };
  #my @controllers= grep /[^:]+::Controller.*/, @names;
  #my $haveRoot= 0;
  #foreach my $ctlr (@controllers) {
  #  if ($ctlr->isa('RapidApp::ModuleDispatcher')) {
  #    $log->debug("RapidApp: Found $ctlr which implements ModuleDispatcher.");
  #    $haveRoot= 1;
  #  }
  #}
  #if (!$haveRoot) {
  #  #$log->debug("RapidApp: No Controller extending ModuleDispatcher found, using default")
  #  #  if($app->debug);
  #  push @inject,['RapidApp::Controller::DefaultRoot', 'Controller::RapidApp::Root'];
  #}
  
  # Controllers:
  push @inject, (
    ['RapidApp::Controller::DefaultRoot'             => 'Controller::RapidApp::Root'             ],
    ['RapidApp::Controller::DirectCmp'               => 'Controller::RapidApp::Module'           ],
    ['RapidApp::Template::Controller'                => 'Controller::RapidApp::Template'         ],
    ['RapidApp::Template::Controller::Dispatch'      => 'Controller::RapidApp::TemplateDispatch' ],
    ['Catalyst::Controller::SimpleCAS'               => 'Controller::SimpleCAS'                  ],
  );
  
  $app->injectUnlessExist( @{$_} ) for (@inject);
  
};

sub root_module_controller {
  my $c = shift;
  return $c->controller('RapidApp::Root');
}

sub injectUnlessExist {
  my ($app, $actual, $virtual)= @_;
  if (!$app->components->{$virtual}) {
    $app->debug && $app->log->debug("RapidApp - Injecting Catalyst Component: $virtual");
    CatalystX::InjectComponent->inject( into => $app, component => $actual, as => $virtual );
  }
}

after 'setup_finalize' => sub {
  my $app = shift;
  $app->rapidApp->_setup_finalize;
  $app->log->info(sprintf(
    " --- RapidApp (v$RapidApp::VERSION) Loaded in %0.3f seconds ---",
    tv_interval($RapidApp::START)
  ));
};

# called once per request, in class-context
before 'handle_request' => sub {
	my ($app, @arguments)= @_;
	$app->rapidApp->incRequestCount;
};

# called once per request, to dispatch the request on a newly constructed $c object
around 'dispatch' => \&_rapidapp_top_level_dispatch;

sub _rapidapp_top_level_dispatch {
	my ($orig, $c, @args)= @_;
  
  # New: simpler global to get $c in user code. can be accessed from
  # anywhere with: 'RapidApp->active_request_context()'
  local $RapidApp::ACTIVE_REQUEST_CONTEXT = $c;
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	# provide hints for our controllers on what contect type is expected
	$c->stash->{requestContentType}=
		$c->req->header('X-RapidApp-RequestContentType')
		|| $c->req->param('RequestContentType')
		|| '';
	
	$c->stash->{onrequest_time_elapsed}= 0;
  
  try {
    $orig->($c, @args);
    for my $err (@{ $c->error }) {
      if (blessed($err) && $err->isa('RapidApp::Responder')) {
        $c->clear_errors;
        $c->forward($err->action);
        last;
      }
    }
  }
  catch {
    # Fallback to handle uncaught exceptions during dispatch. This is
    # known to happen when the client sends a garbled request, such as
    # overly long Ajax requests that were truncated
    my $err = shift;
    warn $err;
    $c->response->content_type('text/plain');
    $c->response->body(" *** Uncaught Exception in Catalyst Engine ***\n\n\n$err");
    $c->response->status(500);
  };
	
	if (!defined $c->response->content_type) {
		$c->log->error("Body was set, but content-type was not!  This can lead to encoding errors!");
	}
};

sub module_root_namespace {
  my $c = shift;
  return $c->config->{'Model::RapidApp'}{module_root_namespace} || '';
}

# This is ugly, but seems to be the best way to re-resolve a *public* URL
# path and dispatch it. It essentially starts over in handle_request at
# the 'prepare_action' phase with a different request path set, leaving
# all other details of the request the same. This is meant to be called
# during an existing request (dispatch phase). This is used internally in 
# places like NavCore for saved searches:
sub redispatch_public_path {
  my ($c, @args) = @_;

  my $path = join('/',@args);
  $path =~ s/^\///; #<-- strip leading /
  $path =~ s/\/$//; #<-- strip trailing leading /
  $path =~ s/\/+/\//g; #<-- strip any double //
  $path ||= '';

  $c->log->debug("Redispatching as path: $path") if ($c->debug);

  # Overwrite the 'path' in the request object:
  $c->request->path($path);

  # Now call prepare_action again, now with the updated path:
  $c->prepare_action;

  # Now forward to the new action. If there is no action,
  # call $c->dispatch just for the sake of error handling
  return $c->action ? $c->forward( $c->action ) : $c->dispatch;
}


sub auto_hashnav_redirect_current {
  my ($c, @args) = @_;
  return $c->hashnav_redirect_current(@args) if (
    $c->req->method eq 'GET' && ! $c->is_ra_ajax_req
    && ! $c->req->params->{__no_hashnav_redirect} #<-- new: check for special exclude param
  );
}

sub hashnav_redirect_current {
  my ($c, @args) = @_;
  # Redirects the current request back to itself as a hashnav:
  return $c->hashnav_redirect($c->req->path,$c->req->params,@args);
}

sub hashnav_redirect {
  my ($c, $path, $params, $base) = @_;

  $path = [$path] unless (ref($path));

  unless(defined $base) {
    # Use the module_root_namespace as the base, if set:
    my $ns = $c->module_root_namespace;
    $base = $ns ne '' ? join('','/',$ns,'/') : '/';
  }

  my $url = join('/','',$base.'#!',@$path);
  $url =~ s/\/+/\//g; #<-- strip any double //

  if($params && keys %$params > 0) {
    my $qs = join('&',map { $_ . '=' . uri_escape($params->{$_}) } keys %$params);
    $url .= '?' . $qs;
  }

  $c->response->redirect($url);
  return $c->detach;
}


around 'finalize_error' => sub {
  my ($orig, $c, @args) = @_;
  if($c->is_ra_ajax_req) {
    # If this is an Ajax request, send it back as raw text instead of
    # the normal Catalyst::Engine's HTML error page
    $c->res->content_type('text/plain; charset=utf-8');
    my $error = join("\n", @{ $c->error }) || 'Unknown error';
    if($c->debug) {
      $error .= join("\n",
        "\n\n",
        "RapidApp v$RapidApp::VERSION\n",
        map { Data::Dumper::Concise::Dumper($_) } $c->dump_these
      );
    };
    $c->res->body($error);
    $c->res->status(500);
  }
  else {
    return $c->$orig(@args);
  }
};

# called after the response is sent to the client, in object-context
after 'log_response' => sub {
	my $c= shift;
	$c->rapidApp->cleanupAfterRequest($c);
};


# reset stats for each request:
before 'dispatch' => sub { %$RapidApp::Functions::debug_around_stats = (); };
after 'dispatch' => \&_report_debug_around_stats;

sub _report_debug_around_stats {
	my $c = shift;
	my $stats = $RapidApp::Functions::debug_around_stats || return;
	return unless (ref($stats) && keys %$stats > 0);
	
	my $total = $c->stats->elapsed;
	
	my $display = $c->_get_debug_around_stats_ascii($total,"Catalyst Request Elapsed");
	
	print STDERR "\n" . $display;
}


sub _get_debug_around_stats_ascii {
	my $c = shift;
	my $total = shift or die "missing total arg";
	my $total_heading = shift || 'Total Elapsed';
	
	my $stats = $RapidApp::Functions::debug_around_stats || return;
	return unless (ref($stats) && keys %$stats > 0);
	
	my $auto_width = 'calls';
	my @order = qw(class sub calls min/max/avg total pct);
	
	$_->{pct} = ($_->{total}/$total)*100 for (values %$stats);
	
	my $tsum = 0;
	my $csum = 0;
	my $count = 0;
	my @rows = ();
	foreach my $stat (sort {$b->{pct} <=> $a->{pct}} values %$stats) {
		$tsum += $stat->{total};
		$csum += $stat->{calls};
		$count++;
		
		$stat->{$_} = sprintf('%.3f',$stat->{$_}) for(qw(min max avg total));
		$stat->{'min/max/avg'} = $stat->{min} . '/' . $stat->{max} . '/' . $stat->{avg};
		$stat->{pct} = sprintf('%.1f',$stat->{pct}) . '%';

		push @rows, [ map {$stat->{$_}} @order ];
	}

	my $tpct = sprintf('%.1f',($tsum/$total)*100) . '%';
	$tsum = sprintf('%.3f',$tsum);
	
	my $t = Text::SimpleTable::AutoWidth->new(
		max_width => Catalyst::Utils::term_width(),
		captions => \@order
	);

	$t->row(@$_) for (@rows);
	$t->row(' ',' ',' ',' ',' ',' ');
	$t->row('(' . $count . ' Tracked Functions)','',$csum,'',$tsum,$tpct);
	
	my $table = $t->draw;
	
	my $display = BOLD . "Tracked Functions (debug_around) Stats (current request):\n" . CLEAR .
		BOLD.MAGENTA . $table . CLEAR .
		BOLD . "Catalyst Request Elapsed: " . YELLOW . sprintf('%.3f',$total) . CLEAR . "s\n\n";
	
	return $display;

}


## Moved from RapidApp::Catalyst:


sub app_version { eval '$' . (shift)->config->{name} . '::VERSION' }

before 'setup_plugins' => sub {
	my $c = shift;

	# -- override Static::Simple default config to ignore extensions like html.
	my $config
		= $c->config->{'Plugin::Static::Simple'}
		= $c->config->{'static'}
		= Catalyst::Utils::merge_hashes(
			$c->config->{'Plugin::Static::Simple'} || {},
			$c->config->{static} || {}
		);
	
	$config->{ignore_extensions} ||= [];
	$c->config->{'Plugin::Static::Simple'} = $config;
	# --
	
};
# --

# Handy method returns true for requests which came from The RapidApp ajax client
sub is_ra_ajax_req {
  my $c = shift;
  return 0 unless ($c->can('request') && $c->request);
  my $tp = $c->request->header('X-RapidApp-RequestContentType') or return 0;
  return $tp eq 'JSON' ? 1 : 0;
}

# Some some housework on the config for normalization/consistency:
sub _normalize_catalyst_config {
  my $c = shift;
  
  my $cnf = $c->config;
  $cnf->{'RapidApp'} ||= {};
  
  # New: allow root_template_prefix/root_template to be supplied
  # in the Template Controller config instead of Model::RapidApp
  # since it just makes better sense from the user standpoint:
  my $tc_cfg = $cnf->{'Controller::RapidApp::Template'} || {};
  $cnf->{'RapidApp'}{root_template_prefix} = $tc_cfg->{root_template_prefix}
    if(exists $tc_cfg->{root_template_prefix});
  $cnf->{'RapidApp'}{root_template} = $tc_cfg->{root_template}
    if(exists $tc_cfg->{root_template});
  
  # ---
  # We're going to transition away from the 'Model::RapidApp' config
  # key because it is confusing, and in the future the current "model"
  # class will probably go away (since it is not really a model).
  # We're going to start by merging/aliasing the config key so users
  # can use 'RapidApp' instead of 'Model::RapidApp';
  $cnf->{'Model::RapidApp'} = Catalyst::Utils::merge_hashes(
    $cnf->{'Model::RapidApp'} || {},
    $cnf->{'RapidApp'} || {}
  );
  $cnf->{'RapidApp'} = $cnf->{'Model::RapidApp'};
  # ---

}

# New: convenience method to get the main 'Template::Controller' which
# is being made into a core function of rapidapp:
sub template_controller { (shift)->controller('RapidApp::Template') }
sub template_dispatcher { (shift)->controller('RapidApp::TemplateDispatch') }

my $share_dir = dir( RapidApp->share_dir );
sub default_tt_include_path {
  my $c = shift;
  my $app = ref $c ? ref $c : $c;
  
  my @paths = ();
  my $home = dir( Catalyst::Utils::home($app) );
  
  if($home && -d $home) {
    my $root = $home->subdir('root');
    if($root && -d $root) {
      my $tpl = $root->subdir('templates');
      push @paths, "$tpl" if ($tpl && -d $tpl);
      push @paths, "$root";
    }
  }
  
  # This should be redundant if share_dir is setup properly
  if($share_dir && -d $share_dir) {
    my $tpl = $share_dir->subdir('templates');
    push @paths, "$tpl" if ($tpl && -d $tpl);
    push @paths, "$share_dir";
  }
  
  return join(':',@paths);
}

# convenience util function
## TODO: This is to be replaced with a call to template_render() within
## the new Template::Controller (see template_controller() above)
my $TT;
sub template_render {
	my $c = shift;
	my $template = shift;
	my $vars = shift || {};
  
	$TT ||= Template->new({ 
    INCLUDE_PATH => $c->default_tt_include_path,
    ABSOLUTE => 1
  });
	
	my $out;
	$TT->process($template,$vars,\$out) or die $TT->error;

	return $out;
}

# Temp hack to set the include path for our TT Views. These Views will be
# totally refactored in RapidApp 2. This will remain until then:
before 'setup_components' => sub {
  my $c = shift;
  my @views = qw(
    View::RapidApp::TT
    View::RapidApp::Viewport
    View::RapidApp::Printview
    View::RapidApp::HttpStatus
  );
  
  $c->config( $_ => { 
    INCLUDE_PATH => $c->default_tt_include_path,
    ABSOLUTE => 1
  }) for (@views);
};


our $ON_FINALIZE_SUCCESS = [];

## -- 'on_finalize_success' provides a mechanism to call code at the end of the request
## only if successful
sub add_on_finalize_success {
	my $c = shift;
	# make sure this is the CONTEXT object and not a class name
	$c = RapidApp->active_request_context unless (ref $c);
	my $code = shift or die "No CodeRef supplied";
	die "add_on_finalize_success(): argument not a CodeRef" 
		unless (ref $code eq 'CODE');
	
	if(try{$c->stash}) {
		$c->stash->{on_finalize_success} ||= [];
		push @{$c->stash->{on_finalize_success}},$code;
	}
	else {
		push @$ON_FINALIZE_SUCCESS,$code;
	}
	return 1;
}

before 'finalize' => sub {
	my $c = shift;
	my $coderefs = try{$c->stash->{on_finalize_success}} or return;
	return unless (scalar @$coderefs > 0);
	my $status = $c->res->code;
	return unless ($status =~ /^[23]\d{2}$/); # status code 2xx = success, also allow 3xx codes
	$c->log->info(
		"finalize_body(): calling " . (scalar @$coderefs) .
		" CodeRefs added by 'add_on_finalize_success'"
	);
	$c->run_on_finalize_success_codes($coderefs);
};
END { __PACKAGE__->run_on_finalize_success_codes($ON_FINALIZE_SUCCESS); }

sub run_on_finalize_success_codes {
	my $c = shift;
	my $coderefs = shift;
	my $num = 0;
	foreach my $ref (@$coderefs) {
		try {
			$ref->($c);
		}
		catch {
			# If we get here, we're screwed. Best we can do is log the error. (i.e. we can't tell the user)
			my $err = shift;
			my $errStr = RED.BOLD . "EXCEPTION IN CodeRefs added by 'add_on_finalize_success!! [coderef #" . 
				++$num . "]:\n " . CLEAR . RED . (ref $err ? Dumper($err) : $err) . CLEAR;
			
			try{$c->log->error($errStr)} or warn $errStr;
			
			# TODO: handle exceptions here like any other. This might require a bit
			# of work to achieve because by the time we get here we're already past the
			# code that handles RapidApp exceptions, and the below commented out code doesn't work
			#
			# This doesn't work (Whenever this *concept* is able to work, handle in a single
			# try/catch instead of a separate one as is currently done - which we're doing because
			# we're not able to let the user know something went wrong, so we try our best to
			# run each one):
			#delete $c->stash->{on_finalize_success};
			#my $view = $c->view('RapidApp::JSON') or die $err;
			#$c->stash->{exception} = $err;
			#$c->forward( $view );
		};
	}
};
##
## --



1;
