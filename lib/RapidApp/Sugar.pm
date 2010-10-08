package RapidApp::Sugar;

use strict;
use warnings;
use Exporter qw( import );
use Data::Dumper;
use RapidApp::JSON::MixedEncoder;
use RapidApp::JSON::RawJavascript;

@RapidApp::Sugar::EXPORT = ( 'sessvar', 'asjson', 'rawjs' );

# Module shortcuts
#

sub sessvar {
	my ($name, %attrs)= @_;
	push @{$attrs{traits}}, 'RapidApp::Role::SessionVar';
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

1;