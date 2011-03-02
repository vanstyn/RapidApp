package RapidApp::Sugar;

use strict;
use warnings;
use Exporter qw( import );
use Data::Dumper;
use RapidApp::JSON::MixedEncoder;
use RapidApp::JSON::RawJavascript;
use RapidApp::Error::UserError;
use RapidApp::Handler;
use RapidApp::DefaultOverride qw(override_defaults merge_defaults);
use RapidApp::Debug;

our @EXPORT = qw(sessvar perreq asjson rawjs mixedjs ra_die usererr override_defaults merge_defaults DEBUG);

# Module shortcuts
#

# a per-session variable, dynamically loaded form the session object on each request
sub sessvar {
	my ($name, %attrs)= @_;
	push @{$attrs{traits}}, 'RapidApp::Role::SessionVar';
	return ( $name, %attrs );
}

# a per-request variable, reset to default or cleared at the end of each request execution
sub perreq {
	my ($name, %attrs)= @_;
	push @{$attrs{traits}}, 'RapidApp::Role::PerRequestVar';
	return ( $name, %attrs );
}

# JSON shortcuts
#

sub asjson {
	scalar(@_) == 1 or die "Expected single argument";
	return RapidApp::JSON::MixedEncoder::encode_json($_[0]);
}

sub rawjs {
	scalar(@_) == 1 && ref $_[0] eq '' or die "Expected single string argument";
	return RapidApp::JSON::RawJavascript->new(js=>$_[0]);
}

sub mixedjs {
	return RapidApp::JSON::ScriptWithData->new(@_);
}

# Exception constructors

sub ra_die {
	my $msg= shift;
	my $data= { %_ };
	die RapidApp::Error->new(message => $msg, data => $data);
}

sub usererr {
	return RapidApp::Responder::UserError->new(@_);
}

# debug stuff to the log
sub DEBUG {
	unshift @_, 'RapidApp::Debug';
	goto &RapidApp::Debug::global_write; # we don't want to mess up 'caller'
}

1;