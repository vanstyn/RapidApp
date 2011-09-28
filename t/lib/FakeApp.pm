package FakeApp;
use strict;
use warnings;
use Catalyst::Request;
use Catalyst::Response;

sub new {
	my %params= (ref($_[0]) eq 'HASH')? %{$_[0]} : @_;
	$params{request} ||= Catalyst::Request->new();
	$params{response} ||= Catalyst::Response->new();
}

sub debug { 1 }
sub config { { home => '.', } }

sub request { $_[0]->{request} }
sub response { $_[0]->{response} }

1;