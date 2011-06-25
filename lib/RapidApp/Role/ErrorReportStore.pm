package RapidApp::Role::ErrorReportStore;

use Moose::Role;
use Try::Tiny;
use RapidApp::ScopedGlobals;
use RapidApp::ErrorReport;
use IO::File;
use Storable ('freeze', 'thaw');

has 'updateEnabled' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'listEnabled'   => ( is => 'ro', isa => 'Bool', default => 0 );
has 'maxSerializedSize' => ( is => 'rw', default => 4*1024*1024 );
has 'maxCloneDepth'     => ( is => 'rw', default => 6 );

=head1 ATTRIBUTES

=over

=item updateEnabled

Whether it is permitted (and supported) to call $self->updateErrorReport

Defaults to false.  Set to true if you implemented this functionality and want to enable it.

=item listEnabled

Whether it is permitted (and supported) to call $self->listReports

Defaults to false.  Set to true if you implemented this functionality and want to enable it.

=item maxSerializedSize

The maximum size in bytes allowed for a serialized report.  Reports will be repeatedly trimmed
until they are below this size.

=item maxCloneDepth

When trimmed, this setting determines how deeply to clone a given node of the report.  The report
is repeatedly cloned with shallower and shallower depths until it fits within the maxSerializedSize.
The trimming attempts start with this depth, and step smaller if needed.

=back

=head1 METHODS

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


=head2 \@list= $obj->updateErrorReport( $errId, $report )

Overwrite report ID with the new report object

=cut
sub updateErrorReport { die "unsupported" };

around 'updateErrorReport' => sub {
	my ($orig, $self, $id, $report)= @_;
	$self->updateEnabled or die "Error-report updates are not enabled";
	return $self->$orig($id, $report);
};


=head2 \@list= $obj->listReports( \%args )
  my $list= $obj->listExceptions();  # all
  my $list= $obj->listExceptions({ offset => $ofs, limit => $count }); # count, starting from ofs

=cut
sub listReports { die "unsupported" };

around 'listReports' => sub {
	my ($orig, $self, $args)= @_;
	$self->listEnabled or die "Error-report updates are not enabled";
	defined $args or $args= {};
	my $ret= $self->$orig($args);
	defined $ret && (ref $ret eq 'ARRAY') or die "API breakage- did not return list";
	return $ret;
};

sub serializeErrorReport {
	my ($self, $errReport)= @_;
	my $log= RapidApp::ScopedGlobals->log;
	my $c= RapidApp::ScopedGlobals->get("catalystInstance");
	
	local $Storable::forgive_me= 1; # ignore non-storable things
	
	my ($serialized, $serializedSize)= (undef, 0x7FFFFFFF);
	
	if ($ENV{DEBUG_ERROR_STORE}) {
		IO::File->new("> /tmp/Dump_$errReport")->print(Dumper($errReport));
	}
	
	for (my $maxDepth= $self->maxCloneDepth; $maxDepth > 2; $maxDepth--) {
		try {
			my $trimErr= $errReport->getTrimmedClone($maxDepth);
			$trimErr->apply_debugInfo(freezeInfo => "Exception object trimmed to depth $maxDepth");
			$serialized= freeze( $trimErr );
			$serializedSize= defined $serialized? length($serialized) : -1;
		}
		catch {
			$log->warn("Error serialization failed, attempting to trim further...");
		};
		return $serialized if (defined $serialized && $serializedSize < $self->maxSerializedSize);
		$log->warn("Error serialization was $serializedSize bytes, attempting to trim further...");
	}
	
	# last ditch attempt at saving something
	my $errMsg= 'Exception could not be stringified!';
	try {
		$errMsg= ''.$errReport->exception;
		$errMsg= substr($errMsg, 0, $self->maxSerializedSize - 600); # I actually measured the frozen size of the hash below with no message to be 405 bytes
	}
	catch { };
	
	my $trimErr= RapidApp::ErrorReport->new(
		dateTime => $errReport->dateTime,
		exception => $errMsg,
		traces => [],
		debugInfo => {
			freezeInfo => "Error report could not be serialized",
			smallestTrimmedErrorSize => $serializedSize,
			maxSize => $self->maxSerializedSize,
			numTraces => scalar(@{$errReport->traces}),
		},
	);
	return freeze( $trimErr );
}

sub deserializeErrorReport {
	my ($self, $frozen)= @_;
	my $errReport= thaw($frozen);
	defined $errReport or die "Failed to deserialize error report";
	return $errReport;
}

1;