package RapidApp::Role::ExceptionSaver;

use Moose::Role;

use DateTime;
use Try::Tiny;
use Storable ('freeze', 'thaw');

use RapidApp::ScopedGlobals;

=head1 NAME

RapidApp::Role::ExceptionSaver;

=cut

has 'exceptionModel' => ( is => 'rw', isa => 'Str', default => 'DB::exception' );

=head1 ATTRIBUTES

=over

=item exceptionModel

The name of the DBIC Catalyst Model to use for storing exception objects.

=back

=head1 DESCRIPTION

This module provides a function "saveException" which writes a row to the exceptions table,
and then serializes relevant bits of data into a blob field to be deserialized and inspected later.

These fields are (subject to change):

=over

=item when

Stored in database column.  The DateTime of when the exception occured

=item who

Stored in database column.  The userID from the user object in the catalyst object.

=item summary

Stored in database column.  The summary text of the exception, limited to 64 characters, useful for quick identification in grid lists.

=item err

Serialized into the blob.  The exception object itself, which is possibly a string of text.

=item req

Serialized into the blob.  The Request hash.

=item user

Serialized into the blob.  The User object from $c->user.

=back

The schema required for the table is currently
  CREATE TABLE exception (
    id int not null AUTO_INCREMENT,
    DateTime when not null,
    who int not null,  # or whatever type we will find in $c->user->id
    summary varchar(64) not null,
    serialized BLOB,
    PRIMARY KEY (id)
  )

=head1 METHODS

=head2 saveException( { err => $exceptionObject, msg => $shortMessage } )

This method writes the exception into whatever targets have been configured for saving exceptions
into.  At the moment, only DBIC tables are supported.  We might extend this in the future.

=cut
sub saveException {
	my $self= shift;
	my $params= ref $_[0]? $_[0] : { @_ };
	my $msg= $params->{msg};
	my $err= $params->{err};
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	
	my ($what, $where);
	if ($msg =~ /^(.*?) at ([^ ]+.p[ml](?: line [0-9]+)?).*/) {
		$what= $1;
		$where= $2;
		$where =~ s|.*?/lib/||;
	}
	else {
		$what= $msg;
	}
	# truncate strings which actually go into varchar columns
	defined $where && length($where) < 64 or $where= substr($where,0,64);
	length($what) < 64 or $what= substr($what,0,60).'...';
	
	my $now= DateTime->now;
	$now->set_time_zone('UTC');
	
	local $Storable::forgive_me= 1; # ignore non-storable things
	my $serialized= freeze( { err => $err, req => $c->request, user => $c->user } );
	
	if ($self->exceptionModel) {
		try {
			my $rs= $c->model($self->exceptionModel);
			defined $rs or die "Unknown model ".$self->exceptionModel;
			
			my $row= $rs->create({
				who   => defined $c->user? $c->user->id : undef,
				what  => $what,
				when  => $now,
				where => $where,
				why   => $serialized,
			});
			$c->stash->{exceptionLogId}= $row->id;
		}
		catch {
			$c->log->error("Failed to save exception to database: ".$_);
			$c->stash->{exceptionLogId}= '';
		};
	}
}

1;
