package RapidApp::Error;

use Moose;

use overload '""' => \&as_string; # to-string operator overload
use Data::Dumper;
use DateTime;
use Devel::StackTrace::WithLexicals;

sub dieConverter {
	die ref $_[0]? $_[0] : &capture(join ' ', @_);
}

=head2 $err= capture( $something )

This function attempts to capture the details of some other exception object (or just a string)
and pull them into the fields of a RapidApp::Error.  This allows all code in RapidApp to convert
anything that happens to get caught into a Error object so that the handy methods like "trace"
and "isUserError" can be used.

=cut
sub capture {
	# allow leniency if we're called as a package method
	shift if !ref $_[0] && $_[0] eq __PACKAGE__;
	die "Too many arguments to capture (it is a plain function, not a package emthod)" if scalar(@_) != 1;
	my $errObj= shift;
	
	if (blessed($errObj)) {
		return $errObj if $errObj->isa('RapidApp::Error');
		
		# TODO: come up with more comprehensive data collection from unknown classes
		my $hash= {};
		$hash->{message} ||= $errObj->message if $errObj->can('message');
		$hash->{trace}   ||= $errObj->trace   if $errObj->can('trace');
		return RapidApp::Error->new($hash);
	}
	elsif (ref $errObj eq 'HASH') {
		# TODO: more processing here...  but not sure when we'd make use of this anyway
		return RapidApp::Error->new($errObj);
	}
	else {
		my $args= { message => ''.$errObj };
		my @lines= split /[\n\r]/, $args->{message};
		
		if ($lines[0] =~ /^(.*?) at (.+?) line ([0-9]+).*/) {
			if (scalar(@lines) > 1) {
				# for multi-line messages where the first line ends with "at FILE line ###" we leave the message untouched
			}
			else {
				# else we strip off the line number, and call it part of our stack trace
				$args->{message}= $1;
				$args->{firstStackFrame}= [ '', $2, $3, '', 0, undef, undef, undef, 0, '', undef ];
			}
		}
		return RapidApp::Error->new($args);
	}
}

has 'message_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'message' => ( is => 'rw', isa => 'Str', lazy_build => 1 );
sub _build_message {
	my $self= shift;
	return $self->message_fn;
}

has 'userMessage_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'userMessage' => ( is => 'rw', lazy_build => 1 );
sub _build_userMessage {
	my $self= shift;
	return defined $self->userMessage_fn? $self->userMessage_fn->() : undef;
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
	my $frame= $self->trace->frame(0);
	return defined $frame? $frame->filename . ' line ' . $frame->line : undef;
}

has 'data' => ( is => 'rw', isa => 'HashRef' );
has 'cause' => ( is => 'rw' );

has 'firstStackFrame' => ( is => 'ro', isa => 'ArrayRef' );

has 'traceFilter' => ( is => 'rw' );
has 'trace' => ( is => 'rw', builder => '_build_trace' );
sub _build_trace {
	my $self= shift;
	# if catalyst is in debug mode, we capture a FULL stack trace
	#my $c= RapidApp::ScopedGlobals->catalystInstance;
	#if (defined $c && $c->debug) {
	#	$self->{trace}= Devel::StackTrace::WithLexicals->new(ignore_class => [ __PACKAGE__ ]);
	#}
	my $filter= $self->traceFilter || \&ignoreSelfFrameFilter;
	my $args= { frame_filter => $filter };
	defined $self->firstStackFrame
		and $args->{raw}= [ { caller => $self->firstStackFrame, args => [] } ];
	
	my $result= Devel::StackTrace->new(%$args);
	return $result;
}
sub ignoreSelfFrameFilter {
	my $params= shift;
	my ($from, $calledPkg)= (''.$params->{caller}->[0], ''.$params->{caller}->[3]);
	return 0 if substr($from, 0, 15) eq 'RapidApp::Error';
	return 0 if substr($from, 0, 10) eq 'Class::MOP' && substr($calledPkg, 0, 15) eq 'RapidApp::Error';
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
	defined $self->message_fn || $self->has_message or die "Require one of message or message_fn";
}

sub dump {
	my $self= shift;
	
	# start with the readable messages
	my $result= $self->message."\n";
	$self->has_userMessage
		and $result.= "User Message: ".$self->userMessage."\n";
	
	$result.= ' on '.$self->dateTime->ymd.' '.$self->dateTime->hms."\n";
	
	defined $self->data
		and $result.= Dumper([$self->data], ["Data"])."\n";
	
	defined $self->trace
		and $result.= 'Stack: '.$self->trace."\n";
	
	defined $self->cause
		and $result.= 'Caused by: '.(blessed $self->cause && $self->cause->can('dump')? $self->cause->dump : ''.$self->cause);
	
	return $result;
}

sub as_string {
	return (shift)->message;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;