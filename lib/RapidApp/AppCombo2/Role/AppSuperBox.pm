package RapidApp::AppCombo2::Role::AppSuperBox;

use strict;
use warnings;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

has 'default_cls' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

sub BUILD {}
after 'BUILD' => sub {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype => 'superboxselect',
		default_cls => $self->default_cls
	);
	
	$self->add_plugin('appsuperbox');
};

1;
