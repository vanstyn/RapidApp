package RapidApp::DbicErrorStore;

use Moose;
with 'RapidApp::Role::ErrorReportStore';

use RapidApp::Include 'perlutil';
use RapidApp::Debug 'DEBUG';

=head1 NAME

RapidApp::DbicExceptionStore;

=cut

has 'resultSource'      => ( is => 'rw', isa => 'DBIx::Class::ResultSource' );

=head1 ATTRIBUTES

=over

=item resultSource

The DBIC ResultSource matching the required schema (below)

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
	my $rs= $self->resultSource;
	try {
		defined $rs or die "Missing ResultSource";
		
		my $serialized= $self->serializeErrorReport($errReport);
		my $when= $errReport->dateTime->clone();
		#$when->set_time_zone('local'); # use local timezone for the appgrid display
		
		$self->_suppressDbicTrace(sub {
			$refId= $self->_createRecord({
				when    => $when,
				summary => $summary,
				report  => $serialized,
			});
		});
		
		$log->info("Exception saved as refId ".$refId);
	}
	catch {
		$log->error("Failed to save exception to database: ".$_);
		$refId= undef;
	};
	return $refId;
}

# Having this as a separate method allows for subclasses to fill in extra fields
sub _createRecord {
	my ($self, $argHash)= @_;
	my $row= $self->resultSource->resultset->create($argHash);
	return $row->id;
}

=head2 $err= $store->loadErrorReport( $id )

=cut
sub loadErrorReport {
	my ($self, $id)= @_;
	
	my $rs= $self->resultSource;
	defined $rs or die "Missing ResultSource";
	
	my $row= $rs->resultset->single({ id => $id });
	defined $row or die "No such error report $id";
	
	my $serialized= $row->report;
	RapidApp::ScopedGlobals->log->debug('Read '.length($serialized).' bytes of serialized error');
	my $errReport= $self->deserializeErrorReport($serialized);
	
	return $errReport;
}

=head2 $err= $store->updateErrorReport( $id, $report )

=cut
sub updateErrorReport {
	my ($self, $id, $report)= @_;
	my $row= $self->resultSource->resultset->single({ id => $id });
	defined $row or die "No such error report $id";
	my $serialized= $self->serializeErrorReport( $report );
	$self->_suppressDbicTrace(sub {
		$row->update({ report => $serialized });
	});
}

sub _suppressDbicTrace {
	my ($self, $code)= @_;
	my ($db_debug, $err, $ret);
	my $rs= $self->resultSource;
	try {
		$db_debug= $rs->schema->storage->debug();
		$rs->schema->storage->debug(0); # prevent spamming the console with binary data
		$ret= $code->();
	}
	catch {
		$err= @_;
	};
	# turn traces back on if we turned them off
	if ($db_debug && $rs && $rs->schema && $rs->schema->storage) {
		$rs->schema->storage->debug($db_debug);
	}
	defined $err and die $err;
	return $ret;
}


1;
