package RapidApp::DbicErrorStore;

use Moose;
with 'RapidApp::Role::ErrorReportStore';

use RapidApp::Include 'perlutil';

use Storable ('freeze', 'thaw');

=head1 NAME

RapidApp::DbicExceptionStore;

=cut

has 'resultSource'      => ( is => 'rw', isa => 'DBIx::Class::ResultSource' );
has 'maxSerializedSize' => ( is => 'rw', default => 4*1024*1024 );
has 'maxCloneDepth'     => ( is => 'rw', default => 6 );

=head1 ATTRIBUTES

=over

=item resultSource

The DBIC ResultSource matching the required schema (below)

=item maxSerializedSize

The maximum size in bytes allowed for a serialized report.  Reports will be repeatedly trimmed
until they are below this size.

=item maxCloneDepth

When trimmed, this setting determines how deeply to clone a given node of the report.  The report
is repeatedly cloned with shallower and shallower depths until it fits within the maxSerializedSize.
The trimming attempts start with this depth, and step smaller if needed.

=back

=head1 DESCRIPTION

This module provides the ExceptionStore role which reads/writes rows to the exceptions table,
and then serializes relevant bits of data into a blob field to be deserialized and inspected later.

The required schema is (subject to change):

=over

=item who

Stored in database column.  The UserID from the user object in the catalyst object, as found in
the RapidApp::Error object.

=item what

Stored in database column.  The summary text of the exception, limited to 64 characters,
useful for quick identification in grid lists.  This is the RapidApp::Error->message text.

=item when

Stored in database column.  The DateTime of when the exception occured.  This columns should be
configured to inflate and deflate from DateTime objects.

=item where

The source location where the exception occured.  This is extracted from the Error object and
duplicated here for SQL searchability.

=item why

Serialized into the blob.  The exception object itself, which is a RapidApp::Error object.

=back

In SQL DDL:
  CREATE TABLE error_report (
    id int not null AUTO_INCREMENT,
    when DATETIME not null default NOW(),
    summary VARCHAR(200) not null,
    report MEDIUMBLOB not null,
    PRIMARY KEY (id)
  )

=head1 METHODS

=head2 $id= $store->saveException( $err )

Writes out a new record in the table, saving this exception object.

=cut
sub saveErrorReport {
	my ($self, $errReport)= @_;
	my $log= RapidApp::ScopedGlobals->log;
	my $c= RapidApp::ScopedGlobals->get("catalystInstance");
	
	my @summaryParts= ();
	
	# do creative things to build the summary, but absolutely do not let that stop us from saving the report
	try {
		if ($c) {
			my $uid= defined $c->user? $c->user->id : 'no user';
			my $uname= defined $c->user? $c->user->username : '??';
			my $isSys= $c->session->{isSystemAccount};
			push @summaryParts, ($isSys? $uname.'('.$uid.')' : 'system ('.$uid.')');
			
			push @summaryParts, $c->request->path;
		}
		
		my $err= $errReport->exception;
		push @summaryParts, '['.(ref $err).']' if ref $err;
		
		my $msg= ''.$errReport->exception;
		length($msg) < 164 or $msg= substr($msg,0,160).'...';
		push @summaryParts, $msg;
	}
	catch {
		push @summaryParts, '(error building summary: '.$_.')';
	};
	
	my $summary= substr(join(' ', @summaryParts), 0, 200);
	undef @summaryParts;
	
	my $refId;
	try {
		local $Storable::forgive_me= 1; # ignore non-storable things
		
		my ($serialized, $serializedSize);
		
		if ($ENV{DEBUG_ERROR_STORE}) {
			open my $file, ">", "/tmp/Dump_$errReport";
			$file->print(Dumper($errReport));
			$file->close;
		}
		
		for (my $maxDepth=$self->maxCloneDepth; $maxDepth > 0; $maxDepth--) {
			my $trimErr= $errReport->getTrimmedClone($maxDepth);
			$trimErr->apply_debugInfo(freezeInfo => "Exception object trimmed to depth $maxDepth");
			$serialized= freeze( $trimErr );
			$serializedSize= defined $serialized? length($serialized) : -1;
			
			last if (defined $serialized && $serializedSize < $self->maxSerializedSize);
			$log->warn("Error serialization was $serializedSize bytes, attempting to trim further...");
		}
		
		# last ditch attempt at saving something
		if (!defined $serialized || $serializedSize >= $self->maxSerializedSize) {
			my $trimErr= RapidApp::ErrorReport->new(
				dateTime => $errReport->dateTime,
				exception => undef,
				traces => [],
				debugInfo => {
					freezeInfo => "Exception object could not be trimmed small enough",
					smallestTrimmedErrorSize => $serializedSize,
					maxSize => $self->maxSerializedSize,
					numTraces => scalar(@{$errReport->traces}),
				},
			);
			$serialized= freeze( $trimErr );
		}
		
		my $rs= $self->resultSource;
		defined $rs or die "Missing ResultSource";
		
		my $row= $rs->resultset->create({
			when    => $errReport->dateTime,
			summary => $summary,
			report  => $serialized,
		});
		$refId= $row->id;
		$log->info("Exception saved as refId ".$refId);
	}
	catch {
		$log->error("Failed to save exception to database: ".$_);
		$refId= undef;
	};
	return $refId;
}

=head2 $err= $store->loadException( $id )

=cut
sub loadErrorReport {
	my ($self, $id)= @_;
	
	my $rs= $self->resultSource;
	defined $rs or die "Missing ResultSource";
	
	my $row= $rs->resultset->find($id);
	defined $row or die "No excption exists for id $id";
	
	my $serialized= $row->report;
	RapidApp::ScopedGlobals->log->debug('Read '.length($serialized).' bytes of serialized error');
	my $errReport= thaw($serialized);
	defined $errReport or die "Failed to deserialize exception";
	return $errReport;
}



1;
