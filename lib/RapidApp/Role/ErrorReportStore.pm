package RapidApp::Role::ErrorReportStore;

use Moose::Role;
use Try::Tiny;
use RapidApp::ScopedGlobals;

=head2 $id= $obj->saveErrorReport( RapidApp::ErrorReport )

Save an exception and its details.

Returns an ID used to look up the exception later.  On failure, logs the reason and returns undef.
Does not throw an exception.

(we could have the exception-saver throw an exception, but that might not be too helpful)

=cut
requires 'saveErrorReport';

around 'saveErrorReport' => sub {
	my ($orig, $self, $err)= @_;
	my $ret;
	try {
		defined $err && $err->isa('RapidApp::ErrorReport') or die "Second parameter must be a RapidApp::ErrorReport";
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

=head2 $err= $obj->loadErrorReport( $id )

Load an exception by the given id string.  If possible, a copy of the original
(or even the original) RapidApp exception will be returned.

If the error does not exist, or cannot be loaded, throws an exception.

=cut
requires 'loadErrorReport';

around 'loadErrorReport' => sub {
	my ($orig, $self, $id)= @_;
	defined $id && !ref $id or die "Invalid ID parameter";
	my $ret= $self->$orig($id);
	defined $ret && $ret->isa('RapidApp::ErrorReport') or die "API breakage- ".(ref $ret)." is not a RapidApp::ErrorReport";
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