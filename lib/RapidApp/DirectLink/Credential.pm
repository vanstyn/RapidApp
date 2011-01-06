package RapidApp::DirectLink::Credential;
use Moose;
use Scalar::Util 'blessed';

around 'BUILDARGS' => sub {
	my ($orig, $class, $config, $app, $realm)= @_;
	return $class->$orig($config);
};

=head2 authenticate($c, $realm, $authinfo)

Authenticate returns a user object if it likes the authinfo.  This implementation likes the
authinfo simply if it contains a DirectLink::Link under the key 'directLink'.

It will then go to the store to try and find the user object, first using the 'auth' attribute of
the link, and if that fails, using the passed $authinfo parameter.

=cut
my $hashToStr= sub {
	my $hash= shift;
	return '{ '.(join ', ', map { $_.'="'.$hash->{$_}.'"' } sort keys %$hash).' }';
};
sub authenticate {
	my ($self, $c, $realm, $authinfo)= @_;
	$c->log->debug("authenticate: ".$hashToStr->($authinfo));
	my $link= $authinfo->{directLink};
	ref $link && blessed($link) && $link->isa('RapidApp::DirectLink::Link') or return 0;
	
	return $realm->find_user( $link->auth, $c ) || $realm->find_user( $authinfo, $c );
}

1;