package RapidApp::Error::WrappedError;

use Moose;
extends 'RapidApp::Error';

has 'captured'  => ( is => 'ro', required => 1 );
has 'lateTrace' => ( is => 'rw', isa => 'Bool', required => 1 );

around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $params= ref $args[0] eq 'HASH'? $args[0] : { @args };
	
	my $errObj= $params->{captured};
	if (blessed($errObj)) {
		# TODO: come up with more comprehensive data collection from unknown classes
		$params->{message} ||= $errObj->message if $errObj->can('message');
		$params->{message} ||= ''.$errObj;
		$params->{trace}   ||= $errObj->trace   if $errObj->can('trace');
		$params->{cause}   ||= $errObj;
	}
	elsif (ref $errObj eq 'HASH') {
		$params->{message}= '('.join(' ',%$errObj).')';
	}
	else {
		# if we've got a bunch of lines that look like a stack trace, try to use it instead
		my $msg;
		my @lines= split /[\n\r]/, ''.$errObj;
		my @stackSim= ();
		for my $line (@lines) {
			if ($line =~ /^(.*?) at (.+?) line ([0-9]+)\.?(.*)/) {
				defined $msg or $msg= $1 . $4;
				push @stackSim, [ '', $2, $3, '', 0, undef, undef, undef, 0, '', undef ];
			}
		}
		$params->{message}= defined $msg? $msg : ''.$errObj;
		# if we're late, we don't bother with a real stack trace
		if ($params->{lateTrace}) {
			if (scalar @stackSim) {
				$params->{traceArgs}= { raw => [ map { caller => $_, args => [] }, @stackSim ] };
			}
			else {
				$params->{trace}= bless { raw => [ { caller => [caller], args => [] } ] }, 'Devel::StackTrace';
			}
		}
	}
	return $class->$orig($params);
};

sub as_string {
	return (shift)->captured;
}
#use overload '""' => \&as_string; # to-string operator overload

no Moose;
__PACKAGE__->meta->make_immutable;
1;