package RapidApp::Error;

use Moose;

use overload '""' => \&_stringify_object; # to-string operator overload
use Data::Dumper;
use DateTime;
use Devel::StackTrace::WithLexicals;
use RapidApp::Data::DeepMap;
use Scalar::Util 'blessed', 'reftype';

sub dieConverter {
	die ref $_[0]? $_[0] : &capture(join(' ', @_), { lateTrace => 0 });
}

=head2 $err= capture( $someError, \%constructorArgs )

This function attempts to capture the details of some other exception object (or just a string)
and pull them into the fields of a RapidApp::Error::WrappedError.  This allows all code in
RapidApp to convert anything that happens to get caught into a Error object so that the handy
methods like "trace" and "isUserError" can be used.

The second (optional) parameter specifies additional arguments to RapidApp::Error::WrappedError->new.
If the object is already a RapidApp::Error derivative, the arguments are ignored.

=cut
sub capture {
	# allow leniency if we're called as a package method
	shift if !ref $_[0] && $_[0] eq __PACKAGE__;
	my ($errObj, $ctorArgs)= @_;
	$ctorArgs ||= {};
	exists $ctorArgs->{lateTrace} or $ctorArgs->{lateTrace}= 1;
	
	blessed($errObj) && $errObj->isa('RapidApp::Error')
		and return $errObj;
	
	return RapidApp::Error::WrappedError->new(captured => $errObj, %$ctorArgs);
}

has 'message_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'message' => ( is => 'rw', isa => 'Str', lazy_build => 1 );
sub _build_message {
	my $self= shift;
	return $self->message_fn->($self);
}

has 'userMessage_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'userMessage' => ( is => 'rw', lazy_build => 1 );
sub _build_userMessage {
	my $self= shift;
	return defined $self->userMessage_fn? $self->userMessage_fn->($self) : undef;
}

sub isUserError {
	my $self= shift;
	return defined $self->userMessage || defined $self->userMessage_fn;
}

has 'timestamp' => ( is => 'rw', isa => 'Int', default => sub { time } );
has 'dateTime' => ( is => 'rw', isa => 'DateTime', lazy_build => 1 );
sub _build_dateTime {
	my $self= shift;
	my $d= DateTime->from_epoch(epoch => $self->timestamp, time_zone => 'UTC');
	return $d;
}

has 'srcLoc' => ( is => 'rw', lazy_build => 1 );
sub _build_srcLoc {
	my $self= shift;
	# -- vv -- Added by HV to get UserErrors working again: (Mike: fixme)
	return undef unless ($self->trace);
	# -- ^^ --
	my $frame= $self->trace->frame(0);
	return defined $frame? $frame->filename . ' line ' . $frame->line : undef;
}

has 'data' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}} );
has 'cause' => ( is => 'rw' );

has 'traceArgs' => ( is => 'ro', lazy => 1, default => sub {{ frame_filter => \&ignoreSelfFrameFilter }} );
sub collectTraceArgs {
	my $self= shift;
	return $self->traceArgs;
}
has 'trace' => ( is => 'rw', lazy => 1, builder => '_build_trace' );
sub _build_trace {
	my $self= shift;
	my $args= $self->collectTraceArgs;
	my $class= 'Devel::StackTrace';
	if (exists $args->{TRACE_CLASS}) {
		$class= $args->{TRACE_CLASS};
		delete $args->{TRACE_CLASS};
	}
	my $result= $class->new(%$args);
	return $result;
}
sub ignoreSelfFrameFilter {
	my $params= shift;
	my ($from, $subName)= (''.$params->{caller}->[0], ''.$params->{caller}->[3]);
	return 0 if $from =~ /^RapidApp::Error(:.+)?$/;
	return 0 if $subName =~ /^RapidApp::Error:.*?:(_build_trace|BUILD)$/;
	return 1;
}

around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $params= ref $args[0] eq 'HASH'? $args[0]
		: (scalar(@args) == 1? { message => $args[0] } : { @args } );
	
	return $class->$orig($params);
};

sub BUILD {
	my $self= shift;
	$self->trace; # activate the trace
	defined($self->message_fn) || $self->has_message or die "Require one of message or message_fn";
}

sub dump {
	my $self= shift;
	
	# start with the readable messages
	my $result= $self->message."\n  at ".$self->srcLoc;
	
	$self->has_userMessage || $self->userMessage_fn
		and $result.= "User Message: ".$self->userMessage."\n";
	
	$result.= ' on '.$self->dateTime->ymd.' '.$self->dateTime->hms."\n";
	
	keys (%{$self->data})
		and $result.= Data::Dumper->Dump([$self->data], ["Data"])."\n";
	
	defined $self->trace
		and $result.= 'Stack: '.$self->trace."\n";
	
	defined $self->cause
		and $result.= 'Caused by: '.(blessed $self->cause && $self->cause->can('dump')? $self->cause->dump : ''.$self->cause);
	
	return $result;
}

sub as_string {
	my $self= shift;
	return $self->message.' at '.$self->srcLoc;
}

# called by Perl, on this package only (not a method lookup)
sub _stringify_object {
	return (shift)->as_string;
}

our $trimmer= RapidApp::Data::DeepMap->new(
	defaultMapper => \&fn_trimUnwantedCrap,
	mapperByRef => {
		'HASH'  => \&fn_trimUnwantedCrap,
		'ARRAY' => \&fn_trimUnwantedCrap,
		'REF'   => \&fn_trimUnwantedCrap,
	},
	mapperByISA => {
		'Catalyst' => sub { '$c'; },
		'RapidApp::Module' => \&fn_snubBlessed,
		'Catalyst::Component' => \&fn_snubBlessed,
		'IO::Handle' => \&fn_snubBlessed,
		'RapidApp::Error' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
		'Devel::StackTrace' => \&fn_trimStackTrace,
		'Devel::StackTrace::Frame' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
	}
);

our $MAX_DEPTH= 3;

sub getTrimmedClone {
	my ($self, $maxDepth)= @_;
	$trimmer->reset();
	local $MAX_DEPTH= $maxDepth;
	my $ret= $trimmer->translate($self);
	$trimmer->reset();
	return $ret;
}

sub fn_trimStackTrace {
	my ($trace, $mapper, $type)= @_;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth(0);
	my $result= &RapidApp::Data::DeepMap::fn_translateBlessedContents($trace, $mapper);
	$mapper->currentDepth($depth);
	return $result;
}

sub fn_trimUnwantedCrap {
	my ($obj, $mapper, $type)= @_;
	$type or return $obj;
	$mapper->currentDepth < $MAX_DEPTH or return "[$obj]";
	$type= reftype($obj) if blessed($obj);
	$type eq 'HASH' and return RapidApp::Data::DeepMap::fn_translateHashContents(@_);
	$type eq 'ARRAY' and return RapidApp::Data::DeepMap::fn_translateArrayContents(@_);
	$type eq 'REF' and return RapidApp::Data::DeepMap::fn_translateRefContents(@_);
	return "[$obj]";
}

sub fn_snubBlessed {
	my ($obj, $mapper, $type)= @_;
	return "[$type]";
}

no Moose;
__PACKAGE__->meta->make_immutable;

require RapidApp::Error::WrappedError;

1;