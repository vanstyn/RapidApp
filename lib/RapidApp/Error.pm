package RapidApp::Error;

use Moose;

use overload '""' => \&_stringify_object; # to-string operator overload
use Data::Dumper;
use DateTime;
use Devel::StackTrace::WithLexicals;
use RapidApp::Data::DeepMap;
use Scalar::Util 'blessed', 'reftype';

=head1 NAME

RapidApp::Error

=head1 DESCRIPTION

This is a fancy error class which has some features like 'userMessage' that play a special
role in RapidApp handling.  RapidApp does not require this error to be used for anything,
but you might find it convenient.

See RapidApp::View::JSON for details about how errors are rendered.

=cut

sub BUILD {
	my $self= shift;
	defined $self->message_fn || $self->has_message or die "Must specify message for message_fn";
}

has 'message_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'message' => ( is => 'rw', lazy_build => 1 );
sub _build_message {
	my $self= shift;
	return $self->message_fn->($self);
}

# used by RapidApp::View::OnError
has 'userMessage_fn' => ( is => 'rw', isa => 'CodeRef' );
has 'userMessage' => ( is => 'rw', lazy_build => 1 );
sub _build_userMessage {
	my $self= shift;
	return defined $self->userMessage_fn? $self->userMessage_fn->($self) : undef;
}

# used by RapidApp::View::OnError
has 'userMessageTitle' => ( is => 'rw' );

has 'timestamp' => ( is => 'rw', isa => 'Int', default => sub { time } );
has 'dateTime' => ( is => 'rw', isa => 'DateTime', lazy_build => 1 );
sub _build_dateTime {
	my $self= shift;
	my $d= DateTime->from_epoch(epoch => $self->timestamp, time_zone => 'UTC');
	return $d;
}


#has 'srcLoc' => ( is => 'rw', lazy_build => 1 );
#sub _build_srcLoc {
#	my $self= shift;
#	# -- vv -- Added by HV to get UserErrors working again: (Mike: fixme)
#	return undef unless ($self->trace);
#	# -- ^^ --
#	my $frame= $self->trace->frame(0);
#	return defined $frame? $frame->filename . ' line ' . $frame->line : undef;
#}


has 'data' => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub {{}} );
has 'cause' => ( is => 'rw' );

sub dump {
	my $self= shift;
	
	# start with the readable messages
	my $result= $self->message;#."\n  at ".$self->srcLoc;
	
	$self->has_userMessage || $self->userMessage_fn
		and $result.= "User Message: ".$self->userMessage."\n";
	
	$result.= ' on '.$self->dateTime->ymd.' '.$self->dateTime->hms."\n";
	
	keys (%{$self->data})
		and $result.= Data::Dumper->Dump([$self->data], ["Data"])."\n";
	
	#defined $self->trace
	#	and $result.= 'Stack: '.$self->trace."\n";
	
	defined $self->cause
		and $result.= 'Caused by: '.(blessed $self->cause && $self->cause->can('dump')? $self->cause->dump : ''.$self->cause);
	
	return $result;
}

sub as_string {
	my $self= shift;
	return $self->message . ''; #.' at '.$self->srcLoc;
}

# called by Perl, on this package only (not a method lookup)
sub _stringify_object {
	return (shift)->as_string;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;