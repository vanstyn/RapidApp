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

use Term::ANSIColor qw(:constants);


our $VERSION = '0.1';


has 'c'							=> ( is => 'rw' );
has 'base_url'					=> ( is => 'rw',	default => '' );
has 'actions'					=> ( is => 'ro', 	default => sub {{}} );
has 'extra_actions'			=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'content'					=> ( is => 'ro',	default => '' );
has 'render_as_json'			=> ( is => 'rw',	default => 1 );
has 'multi_instance'       => ( is => 'rw',  default => 0 );
has 'instance_num'         => ( is => 'rw',  default => undef );

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
	
	# clear all lazy attributes, if the user asked for it
	$self->clear_attributes if ($self->no_persist);

	
	# set up some critical per-request variables needed for the rest of RapidApp's functionality
	
	$self->c($c);
	
	my $url= defined $self->parent_module? $self->parent_module->base_url . '/' . $self->module_name
		: $self->c->namespace;
	
	if ($self->multi_instance) {
		if (defined $args[0] && ref $args[0] eq '' && $args[0] =~ /^[0-9]+$/) {
			$self->instance_num(shift @args);
		} else {
			my $sess= $self->c->session;
			defined $sess->{$url} or $sess->{$url}= { nextInstNum => 0 };
			$self->instance_num($sess->{$url}->{nextInstNum}++);
		}
		$url .= '/' . $self->instance_num;
	}
	$self->base_url($url);
	
	# run user-defined or mix-in code to get ready to process the action
	
	$self->prepare_controller;
	
	# dispatch the request to the appropriate handler
	
	$self->c->log->info('-->' . ref($self) . '  ' . join(' . ',@args));
	
	$self->controller_dispatch(@args);
}


sub clear_attributes {
	my $self = shift;
	for my $attr ($self->meta->get_all_attributes) {
		$attr->clear_value($self) if ($attr->is_lazy or $attr->has_clearer);
	}
}



# This is moved into a separate function so that overridden controllers can re-use this functionality
sub controller_dispatch {
	my ($self, $opt, @subargs)= @_;
	
	my $data;
	
	try {
	
		if (defined $opt and (defined $self->actions->{$opt} or defined $self->extra_actions->{$opt}) ) {
			$data = $self->process_action($opt,@subargs);
		
		}
		elsif (defined $opt and $self->_load_module($opt)) {
			$data = $self->Module($opt)->Controller($self->c,@subargs);
		
		}
		elsif (defined $self->default_action) {
			$data = $self->process_action($self->default_action,@_);
		}
		else {
			$data = $self->render_data($self->content);
		
		}
	}
	catch {
		chomp($_);
		
		$self->c->log->info(' ---->>> RAPIDAPP EXCEPTION: ' . $_);
		$self->c->res->header('X-RapidApp-Exception' => 1);
		$self->c->res->status(542);
		
		$data = $self->render_data({
			exception	=> \1,
			success		=> \0,
			msg			=> $_
		});
	};
	
	return $data;
}

around 'Module' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $Module = $self->$orig(@_) or return undef;
	
	$Module->base_url($self->base_url . '/' . $Module->module_name) if (
		$Module->does('RapidApp::Role::Controller')
	);
	
	return $Module;
};


sub process_action {
	my $self = shift;
	my ( $opt, @args ) = @_;
	
	$self->c->log->info("PROCESS ACTION: " . $opt);
	
	my $data = '';
	my $coderef;
	if (defined $opt) {
		$coderef = $self->actions->{$opt};
		$coderef = $self->extra_actions->{$opt} unless (defined $coderef);
	}
	$data = $coderef->() if (defined $coderef and ref($coderef) eq 'CODE');
	
	return $self->render_data($data);
}


sub render_data {
	my $self = shift;
	my $data = shift;
	
	my $rendered_data = $data;
	$rendered_data = $self->JSON_encode($data) if (
		$self->render_as_json and
		ref($data) and
		not defined $self->no_json_ref_types->{ref($data)}
	);
	
	
	#use Data::Dumper;
	#print STDERR YELLOW . Dumper($data) . CLEAR;
	#print STDERR GREEN . "\n" . $self->render_as_json . "\n" . CLEAR;
	
	
	#$rendered_data .= $self->render_append;
	
	#use Data::Dumper;
	#print STDERR YELLOW . "\n" . $rendered_data . "\n\n" . CLEAR;

	#for my $i (1..5) {
	#	print STDERR RED .BOLD . Dumper(caller($i)) . "---\n" . CLEAR;
	#}
	
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	return $self->c->response->body( $rendered_data );
}







1;