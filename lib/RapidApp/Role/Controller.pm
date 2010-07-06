package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON;
use Moose::Role;
with 'RapidApp::Role::Module';

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';


has 'c'							=> ( is => 'rw' );
has 'base_url'					=> ( is => 'rw',	default => '' );
has 'actions'					=> ( is => 'ro', 	default => sub {{}} );
has 'default_action'			=> ( is => 'ro',	default => undef );
has 'content'					=> ( is => 'ro',	default => '' );
has 'render_as_json'			=> ( is => 'rw',	default => 1 );
has 'no_persist'				=> ( is => 'rw',	default => 0 );

has 'create_module_params' => ( is => 'ro', lazy => 1,	default => sub {
	my $self = shift;
	return {
		c => $self->c
	};
});



sub Controller {
	my $self = shift;
	$self->c(shift);
	my ( $opt, @args ) = @_;
	

	print STDERR GREEN . '-->' . ref($self) . '  ' . join(' . ',@_) . "\n\n" . CLEAR;
	
	
	if ($self->no_persist) {
		for my $attr ($self->meta->get_all_attributes) {
			$attr->clear_value($self) if ($attr->is_lazy or $attr->has_clearer);
		}
	};
		
	$self->base_url($self->c->namespace);
	$self->base_url($self->parent_module->base_url . '/' . $self->module_name) if (
		defined $self->parent_module
	);
	
	return $self->process_action($opt,@args)							if (defined $opt and defined $self->actions->{$opt});
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
	
	print STDERR RED . "PROCESS ACTION: " . $opt . "\n" . CLEAR;
	
	my $data = '';
	my $coderef;
	$coderef = $self->actions->{$opt} if (defined $opt);
	$data = $coderef->() if (defined $coderef and ref($coderef) eq 'CODE');
	
	return $self->render_data($data);
}


sub render_data {
	my $self = shift;
	my $data = shift;
	
	my $rendered_data = $data;
	$rendered_data = $self->JSON_encode($data) if (
		$self->render_as_json and
		ref($data) eq 'HASH'
	);
	
	#use Data::Dumper;
	#print STDERR YELLOW . Dumper($rendered_data) . CLEAR;

	#for my $i (1..5) {
	#	print STDERR RED .BOLD . Dumper(caller($i)) . "---\n" . CLEAR;
	#}
	
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	return $self->c->response->body( $rendered_data );
}




sub JSON_encode {
	my $self = shift;
	return JSON::to_json(shift);
}


1;