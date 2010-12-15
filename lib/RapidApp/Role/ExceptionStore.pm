package RapidApp::Role::ExceptionStore;

use Moose::Role;
use Try::Tiny;
use RapidApp::ScopedGlobals;

=head2 $id= $obj->saveException( RapidApp::Error )

Save an exception and its details.  The exception must be a RapidApp::Error object.
If you wish to save a different type of exception, first wrap it in a RapidApp Error object
by
  RapidApp::Error->new(parse => $myException);
or
  RapidApp::Error->new(message => 'Semantic meaning of it all', cause => $myException);

Returns an ID used to look up the exception later.  On failure, logs the reason and returns undef.
Does not throw an exception.

(we could have the exception-saver throw an exception, but that might not be too helpful)

=cut
requires 'saveException';

around 'saveException' => sub {
	my ($orig, $self, $err)= @_;
	my $ret;
	try {
		defined $err && $err->isa('RapidApp::Error') or die "Second parameter must be a RapidApp::Error";
		$ret= $self->$orig($err);
	}
	catch {
		my $err= ''.$_;
		chomp $err;
		$err =~ s/ at /\n\tat /g;
		eval { RapidApp::ScopedGlobals->log->error("Failed to save exception: $err"); };
	};
	return $ret;
};

=head2 $err= $obj->loadException( $id )

Load an exception by the given id string.  If possible, a copy of the original
(or even the original) RapidApp exception will be returned.

If the error does not exist, or cannot be loaded, throws an exception.

=cut
requires 'loadException';

around 'loadException' => sub {
	my ($orig, $self, $id)= @_;
	defined $id && !ref $id or die "Invalid ID parameter";
	my $ret= $self->$orig($id);
	defined $ret && $ret->isa('RapidApp::Error') or die "API breakage- ".(ref $ret)." is not a RapidApp::Error";
	return $ret;
};

# =head2 \@list= $obj->listExceptions( \%args )

  # my $list= $obj->listExceptions();  # all
  # my $list= $obj->listExceptions({ offset => $ofs, limit => $count }); # count, starting from ofs

# =cut
# requires 'listExceptions';

# around 'listExceptions' => sub {
	# my ($orig, $self, $args)= @_;
	# defined $args or $args= {};
	# my $ret= $self->$orig($args);
	# defined $ret && ref $ret eq 'ARRAY' or die "API breakage- did not return list";
	# return $ret;
# }

1;