package RapidApp::Role::DbicLink2;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::ColSpec;

#sub BUILDARGS {}
around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# Attributes ending in '_colspec' have a special meaning:
	grep { $opt{$_} = RapidApp::ColSpec->new( spec => $opt{$_}) if ($_ =~ /_colspec$/) } keys %opt;
	
	return $class->$orig(%opt);
};

has 'ResultSource' => (
	is => 'ro',
	isa => 'DBIx::Class::ResultSource',
	required => 1
);


has 'include_colspec' => (
	is => 'ro',
	isa => 'RapidApp::ColSpec',
);



1;