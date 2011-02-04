package RapidApp::FileErrorStore;

use Moose;
with 'RapidApp::Role::ErrorReportStore';

use RapidApp::Include 'perlutil';

use Storable ('freeze', 'thaw');

=head1 NAME

RapidApp::DbicExceptionStore;

=cut

has 'maxSerializedSize' => ( is => 'rw', default => 4*1024*1024 );
has 'maxCloneDepth'     => ( is => 'rw', default => 6 );
has 'reportPath'        => ( is => 'rw', required => 1, lazy_build => 1 );

sub _build_reportPath {
	my $self= shift;
	my $path= '/tmp/'.RapidApp::ScopedGlobals->catalystClass;
	-e $path || mkdir $path || die "Cannot create directory $path";
}

=head1 ATTRIBUTES

=over

=item maxSerializedSize

The maximum size in bytes allowed for a serialized report.  Reports will be repeatedly trimmed
until they are below this size.

=item maxCloneDepth

When trimmed, this setting determines how deeply to clone a given node of the report.  The report
is repeatedly cloned with shallower and shallower depths until it fits within the maxSerializedSize.
The trimming attempts start with this depth, and step smaller if needed.

=back

=head1 DESCRIPTION

This ErrorReportStore writes the error reports to serialized files in the /tmp/ directory.

Use DbicErrorStore for a more elegant solution.

=head1 METHODS

=head2 $id= $store->saveErrorReport( $errReport )

Writes out a new record in the table, saving this exception object.

=cut
our $LAST_FREE_FNAME_ID= 0;
sub saveErrorReport {
	my ($self, $errReport)= @_;
	my $log= RapidApp::ScopedGlobals->log;
	
	my $refId;
	try {
		local $Storable::forgive_me= 1; # ignore non-storable things
		# find next available filename
		my $fname;
		for ($refId= $LAST_FREE_FNAME_ID; -e ($fname= $self->_refIdToFname($refId)); $refId++) {}
		
		store $errReport, $fname or die "Failed to write $fname";
		$LAST_FREE_FNAME_ID= $refId;
		$log->info("Exception saved as refId $refId ($fname)");
	}
	catch {
		$log->error("Failed to save exception to database: ".$_);
		$refId= undef;
	};
	return $refId;
}

=head2 $err= $store->loadErrorReport( $id )

=cut
sub loadErrorReport {
	my ($self, $refId)= @_;
	my $log= RapidApp::ScopedGlobals->log;
	
	my $fname= $self->_refIdToFname($refId);
	-e $fname or die "No excption exists for id $refId";
	$log->debug('Deserializing '.(-s $fname).' bytes of serialized error report');
	my $errReport= retrieve($fname);
	defined $errReport or die "Failed to deserialize error report";
	return $errReport;
}

sub _refIdToFname {
	my ($self, $refId)= @_;
	return $self->reportPath.'/'.$refId.'.sto';
}

1;
