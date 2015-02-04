package RapidApp::Sugar;

use strict;
use warnings;
use Exporter qw( import );
use Data::Dumper;
use RapidApp::JSON::MixedEncoder;
use RapidApp::JSON::RawJavascript;
use RapidApp::HTML::RawHtml;
use RapidApp::Responder::UserError;
use RapidApp::Handler;
use HTML::Entities;
use Scalar::Util qw(blessed);
use Hash::Merge qw( merge );
Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );
use Clone qw(clone);

use Types::Standard qw(:all);

our @EXPORT = qw(
  asjson rawjs mixedjs ashtml rawhtml usererr userexception 
  jsfunc blessed merge hashash infostatus clone
);

# Module shortcuts
#


# JSON shortcuts
#

# encode the object into JSON text, with automatic handling for RawJavascript
sub asjson {
	scalar(@_) == 1 or die "Expected single argument";
	return RapidApp::JSON::MixedEncoder::encode_json($_[0]);
}

# Bless a string as RawJavascript so that it doesn't get encoded as JSON data during asjson
sub rawjs {
	scalar(@_) == 1 && ref $_[0] eq '' or die "Expected single string argument";
	return RapidApp::JSON::RawJavascript->new(js=>$_[0]);
}

# Works like rawjs but accepts a list of arguments. Each argument should be a function defintion,
# and will be stacked together, passing each function in the chain through the first argument
sub jsfunc {
	my $js = shift or die "jsfunc(): At least one argument is required";
	
	return jsfunc(@$js) if (ref($js) eq 'ARRAY');
	
	blessed $js and not $js->can('TO_JSON_RAW') and 
		die "jsfunc: arguments must be JavaScript function definition strings or objects with TO_JSON_RAW methods";
	
	$js = $js->TO_JSON_RAW if (blessed $js);
	
	# Remove undef arguments:
	@_ = grep { defined $_ } @_;
	
	$js = 'function(){ ' .
		'var args = arguments; ' .
		'args[0] = (' . $js . ').apply(this,arguments); ' .
		'return (' . jsfunc(@_) . ').apply(this,args); ' .
	'}' if (scalar @_ > 0);
	
	return RapidApp::JSON::RawJavascript->new(js=>$js)
}

# Encode a mix of javascript and data into appropriate objects that will get converted
#  to JSON properly during "asjson".
#
# Example:  mixedjs "function() { var data=", { a => $foo, b => $bar }, "; Ext.msg.alert(data); }";
# See ScriptWithData for more details.
#
sub mixedjs {
	return RapidApp::JSON::ScriptWithData->new(@_);
}

# Take a string of text/plain and convert it to text/html.  This handles "RawHtml" objects.
sub ashtml {
	my $text= shift;
	return "$text" if ref($text) && ref($text)->isa('RapidApp::HTML::RawHtml');
	return undef unless defined $text;
	return join('<br />', map { encode_entities($_) } split("\n", "$text"));
}

# Bless a scalar to indicate the scalar is already html, and doesn't need converted.
sub rawhtml {
	my $html= shift;
	# any other arguments we were given, we pass back in hopes that we're part of a function call that needed them.
	return RapidApp::HTML::RawHtml->new($html), @_;
}

=head2 usererr $message, key => $value, key => $value

Shorthand notation to create a UserError, to inform the user they did something wrong.
First argument is a scalar of text (or a RawHtml scalar of html)
Second through N arguments are hash keys to apply to the UserError constructor.

Examples:
  # To throw a message to the user with no data and no error report:
  die usererr "Hey you moron, don't do that";

  # To specify that your message is html already:
  die usererr rawhtml "<h2>Hell Yeah</h2>";

=cut

my %keyAliases = (
	msg => 'message',
	umsg => 'userMessage',
	title => 'userMessageTitle',
);
sub usererr {
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
			or warn "Invalid attribute for UserError: $key";
		$args{$key}= $val;
	}
	
	# userexception is allowed to have a payload at the end, but this would be meaningless for usererr,
	#  since usererr is not saved.
	if (scalar(@_)) {
		my ($pkg, $file, $line)= caller;
		warn "Odd number of arguments to usererr at $file:$line";
	}
	
	return RapidApp::Responder::UserError->new(\%args);
}

=head2 userexception $message, key => $value, key => $value, \%data

Shorthand notation for creating a RapidApp::Error which also informs the user about why the error occured.
First argument is the message displayed to the user (can be a RawHtml object).
Last argument is a hash of data that should be saved for the error report.
( the last argument is equivalent to a value for an implied hash key of "data" )

Examples:

  # Die with a custom user-facing message (in plain text), and a title made of html.
  die userexception "Description of what shouldn't have happened", title => rawhtml "<h1>ERROR</h1>";
  
  # Capture some data for the error report, as we show this message to the user.
  die userexception "Description of what shouldn't have happened", $some_debug_info;

=cut

sub userexception {
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
			or warn "Invalid attribute for RapidApp::Error: $key";
		$args{$key}= $val;
	}
	
	# userexception is allowed to have a payload as the last argument
	if (scalar(@_)) {
		$args{data}= shift;
	}
	
	return RapidApp::Error->new(\%args);
}



# Suger function sets up a Native Trait ArrayRef attribute with useful
# default accessor methods
#sub hasarray {
#	my $name = shift;
#	my %opt = @_;
#	
#	my %defaults = (
#		is => 'ro',
#		isa => 'ArrayRef',
#		traits => [ 'Array' ],
#		default => sub {[]},
#		handles => {
#			'all_' . $name => 'uniq',
#			'add_' . $name => 'push',
#			'insert_' . $name => 'unshift',
#			'has_no_' . $name => 'is_empty',
#			'count_' . $name		=> 'count'
#		}
#	);
#	
#	my $conf = merge(\%defaults,\%opt);
#	return caller->can('has')->($name,%$conf);
#}

# Suger function sets up a Native Trait HashRef attribute with useful
# default accessor methods
sub hashash {
	my $name = shift;
	my %opt = @_;
	
	my %defaults = (
		is => 'ro',
		isa => 'HashRef',
		traits => [ 'Hash' ],
		default => sub {{}},
		handles => {
			'apply_' . $name		=> 'set',
			'get_' . $name			=> 'get',
			'has_' . $name			=> 'exists',
			'all_' . $name			=> 'values',
			$name . '_names'		=> 'keys',
		}
	);
	
	my $conf = merge(\%defaults,\%opt);
	return caller->can('has')->($name,%$conf);
}


sub infostatus {
	my %opt = @_;
	%opt = ( msg => $_[0] ) if (@_ == 1);
	return RapidApp::Responder::InfoStatus->new(%opt);
}


1;