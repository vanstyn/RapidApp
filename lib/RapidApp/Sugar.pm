package RapidApp::Sugar;

use strict;
use warnings;
use Exporter qw( import );
use Data::Dumper;

our @EXPORT = ( 'sessvar' );

sub sessvar {
	my ($name, %attrs)= @_;
	push @{$attrs{traits}}, 'RapidApp::Role::SessionVar';
	return ( $name, %attrs );
}

1;