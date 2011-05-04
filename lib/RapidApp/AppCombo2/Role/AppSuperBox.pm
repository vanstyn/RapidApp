package RapidApp::AppCombo2::Role::AppSuperBox;

use strict;
use warnings;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

sub BUILD {}
after 'BUILD' => sub {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype => 'superboxselect',
	);
	
	$self->add_plugin('appsuperbox');
};

1;
