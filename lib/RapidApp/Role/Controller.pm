package RapidApp::Role::Controller;
#
# -------------------------------------------------------------- #
#


use strict;
use JSON;
use Moose::Role;

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';

has 'parent_ref'						=> ( is => 'ro', default => undef );
has 'c'									=> ( is => 'rw' );
has 'base_url'							=> ( is => 'rw' );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module'	);
has 'actions'							=> ( is => 'ro', 	default => sub {{}} );


sub Controller {
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
#	print STDERR BLUE . " --> : " . ref($self) . "\n" . CLEAR;
#	print STDERR CYAN . "base_url: " . $self->base_url . "\n" . CLEAR;
#	print STDERR RED . "path: " . $self->c->req->path . "\n" . CLEAR;
#	print STDERR YELLOW . "namesp: " . $self->c->namespace . "\n" . CLEAR;
#	print STDERR GREEN . "opt: " . $opt . "\n" . CLEAR;
	
	
	$self->c($c);
	$self->base_url($self->c->namespace) unless (defined $self->parent_ref);
	
	#$self->base_url('/' . $self->c->req->path);
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	
	return $self->process_action($opt,@args)									if (defined $self->actions->{$opt});
	return $self->modules_obj->{$opt}->Controller($self->c,@args)		if ($self->_load_module($opt));
	return $self->default_action($opt,@args);
}

# placeholder:
sub default_action {}



sub _load_module {
	my $self = shift;
	my $mod = shift;
	
	my $class_name = $self->modules->{$mod} or return 0;

	return 1 if (
		defined $self->modules_obj->{$mod} and
		ref($self->modules_obj->{$mod}) eq $class_name
	);
	
	
	my $Object = $class_name->new(
		parent_ref	=> $self,
		c 				=> $self->c,
		#base_url		=> $self->c->namespace . '/' . $opt
		base_url		=> $self->base_url . '/' . $mod
	) or die "Failed to create new $class_name object";

	$self->modules_obj->{$mod} = $Object;

	return 1;
}



sub process_action {
	my $self = shift;
	my ( $opt, @args ) = @_;
	
	print STDERR RED . "PROCESS ACTION: " . $opt . "\n" . CLEAR;
	
	my $data = '';
	$data = $self->actions->{$opt}->();
	
	$self->c->response->header('Cache-Control' => 'no-cache');
	return $self->c->response->body( $data );
}


sub JSON_encode {
	my $self = shift;
	return JSON::to_json(shift);
}



# backward compat: (didn't work)
#sub subapps {
#	my $self = shift;
#	
#	$self->_load_all_modules;
#	
#	my $h = {};
#	
#	foreach my $mod (keys %{$self->modules_obj}) {
#		my $Object = $self->modules_obj->{$mod};
#		$h->{$mod} = sub {
#			#my $c = shift;
#			#$Object->c($c) if (defined $c);
#			return $Object;
#		};
#	}
#	
#	return $h;
#}

#sub _load_all_modules {
#	my $self = shift;
#	
#	foreach my $mod (keys %{$self->modules}) {
#		$self->_load_module($mod);
#	}
#}



1;