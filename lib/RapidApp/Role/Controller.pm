package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON::PP;
use Moose::Role;
with 'RapidApp::Role::Module';

use RapidApp::JSONFunc;

use Term::ANSIColor qw(:constants);


our $VERSION = '0.1';


has 'c'							=> ( is => 'rw' );
has 'base_url'					=> ( is => 'rw',	default => '' );
has 'actions'					=> ( is => 'ro', 	default => sub {{}} );
has 'extra_actions'			=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'content'					=> ( is => 'ro',	default => '' );
has 'render_as_json'			=> ( is => 'rw',	default => 1 );

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

sub Controller {
	my $self = shift;
	$self->c(shift);
	my ( $opt, @args ) = @_;
	
	$self->c->log->info('-->' . ref($self) . '  ' . join(' . ',@_));
	
	if ($self->no_persist) {
		for my $attr ($self->meta->get_all_attributes) {
			$attr->clear_value($self) if ($attr->is_lazy or $attr->has_clearer);
		}
	};
		
	$self->base_url($self->c->namespace);
	$self->base_url($self->parent_module->base_url . '/' . $self->module_name) if (
		defined $self->parent_module
	);
	
	return $self->process_action($opt,@args)							if (defined $opt and (defined $self->actions->{$opt} or defined $self->extra_actions->{$opt}) );
	return $self->Module($opt)->Controller($self->c,@args)		if (defined $opt and $self->_load_module($opt));
	return $self->process_action($self->default_action,@_)		if (defined $self->default_action);
	return $self->render_data($self->content);
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