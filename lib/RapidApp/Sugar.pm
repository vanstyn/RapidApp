package RapidApp::Sugar;

use strict;
use warnings;
use Exporter qw( import );
use Data::Dumper;
use RapidApp::JSON::MixedEncoder;
use RapidApp::JSON::RawJavascript;
use RapidApp::HTML::RawHtml;
use RapidApp::Error::UserError;
use RapidApp::Handler;
use RapidApp::DefaultOverride qw(override_defaults merge_defaults);
use RapidApp::Debug;
use HTML::Entities;

our @EXPORT = qw(sessvar perreq asjson rawjs mixedjs ashtml rawhtml usererr userexception override_defaults merge_defaults DEBUG);

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

sub ashtml {
	my $text= shift;
	return "$text" if ref($text) && ref($text)->isa('RapidApp::HTML::RawHtml');
	return undef unless defined $text;
	return join('<br />', map { encode_entities($_) } split("\n", "$text"));
}

sub rawhtml {
	my $html= shift;
	# any other arguments we were given, we pass back in hopes that we're part of a function call that needed them.
	return RapidApp::HTML::RawHtml->new($html), @_;
}

# Exception constructors

=head1 Exceptions

To throw data that gets captured in an error report, with a generic user-facing message:
  die $data;

To throw data that gets captured in an error report, with a custom user-facing message:
  die userexception "Description of what shouldn't have happened", $data;

To throw a message to the user with no data and no error report:
  die usererr "Hey you moron, don't do that";

To specify that your message is html already:
  die usererr rawhtml "<h2>Hell Yeah</h2>";

=cut

my %keyAliases = (
	msg => 'message',
	umsg => 'userMessage',
	title => 'userMessageTitle',
);

sub usererr {
	my $log= RapidApp::ScopedGlobals->get('log');
	my %args= ();
	
	# First arg is always the message.  We stringify it, so it doesn't matter if it was an object.
	my $msg= shift;
	defined $msg or die "userexception requires at least a first message argument";
	
	# If the passed arg is already a UserError object, return it as-is:
	return $msg if ref($msg) && ref($msg)->isa('RapidApp::Responder::UserError');
	
	$args{userMessage}= ref($msg) && ref($msg)->isa('RapidApp::HTML::RawHtml')? $msg : "$msg";
	
	# pull in any other args
	while (scalar(@_) > 1) {
		my ($key, $val)= (shift, shift);
		$key = $keyAliases{$key} || $key;
		RapidApp::Responder::UserError->can($key)
			or $log && $log->error("Invalid attribute for UserError: $key");
		$args{$key}= $val;
	}
	
	# userexception is allowed to have a payload at the end, but this would be meaningless for usererr,
	#  since usererr is not saved.
	if (scalar(@_)) {
		my ($pkg, $file, $line)= caller;
		$log && $log->error("Odd number of arguments to usererr at $file:$line");
	}
	
	return RapidApp::Responder::UserError->new(\%args);
}

sub userexception {
	my $log= RapidApp::ScopedGlobals->get('log');
	my %args= ();
	
	# First arg is always the message.  We stringify it, so it doesn't matter if it was an object.
	my $msg= shift;
	defined $msg or die "userexception requires at least a first message argument";
	$args{userMessage}= ref($msg) && ref($msg)->isa('RapidApp::HTML::RawHtml')? $msg : "$msg";
	$args{message}= $args{userMessage};
	
	# pull in any other args
	while (scalar(@_) > 1) {
		my ($key, $val)= (shift, shift);
		$key = $keyAliases{$key} || $key;
		RapidApp::Error->can($key)
			or $log && $log->error("Invalid attribute for RapidApp::Error: $key");
		$args{$key}= $val;
	}
	
	# userexception is allowed to have a payload as the last argument
	if (scalar(@_)) {
		$args{data}= shift;
	}
	
	return RapidApp::Error->new(\%args);
}

# debug stuff to the log
sub DEBUG {
	unshift @_, 'RapidApp::Debug';
	goto &RapidApp::Debug::global_write; # we don't want to mess up 'caller'
}

1;