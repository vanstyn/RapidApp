package RapidApp::DBIC::PortableItem;

use Moose::Role;

has 'engine' => ( is => 'ro', required => 1 );

=head1 NAME

RapidApp::DBIC::ImportEngine::PortableItem

=head1 DESCRIPTION

This class is a simple interface for Portable Items used by the Import and Export engine.

It doesn't have much functionality, but defines the interface for subclasses to adhere to.

=head1 METHODS

=head2 $class->createFromHash( engine => $engine, hash => \%hash )

This factory method creates a PortableItem from a serialized hash.

=cut

requires 'createFromHash';

=head2 $class->createFromRow( engine => $engine, row => $DBIx::Class::Row )

This factory method creates a PortableItem that constructs itself from a DBIC row object.

=cut

requires 'createFromRow';

=head2 $self->toHash()

This returns a hash suitable for serialization.

=cut

requires 'toHash';

=head2 $self->getUpdateTarget

This method returns a DBIx::Class::Row object that represents this item, iff this item's data
has one.  For import, this method must perform a lookup to find an appropriate update target.
After insertion during import, this method should return the updated rows.
For export, this method just returns the row object we were constructed with.

If this item is not represented by a distinct "root row", this method can return a hash or
array of Row objects.  The hash/array should not be nested, to aid generic code to iterate
through the rows objects.

If this item has not been inserted and no appropriate update target exists, this method returns
undef.

=cut

requires 'getUpdateTarget';

=head2 $self->insert( clone => 0, user_option => $identifier )

This method adds the logical item to storage, failing if the item already exists in storage.
However, if the 'clone' parameter is true, it will try to make a new object with the same values
as the old, with a different primary key.  If this operation requires user interaction
(for example, to alter the key in a sensible way) it will return these details.
Whether the logical item exists in storage can be determined by getUpdateTarget.

Returns true if the insert suceeded, or false if it failed permanently.  For temporary failures,
it returns a hash describing the situation.  See B<merge>.

=cut

requires 'insert';

=head2 $self->merge( mode => ('passive' | 'update' | 'overwrite'), user_option => $identifier )

This method adds any parts of the logical item which do not exist in storage to the rows in
storage, possibly creating them if needed.  Thus, it is much like "insert_or_update".

The default mode is 'update'.  Specifying a mode of 'passive' will only update fields or insert
rows which are missing in storage.  Specifying a mode of 'overwrite' will wipe out the matching
rows and replace them with the contents of this item.

Returns a hash describing the situation, of the form
	{
		status => 'complete' | 'progress' | 'fail',
		require_pk => $RapidApp::DBIC::KeyVal,
		user_intervention => { problem => $identifier, prompt => $text, options => [ text => identifier, ... ] },
		post_process => $CODE,
	}

=over

=item status

This indicates the outcome of the operation.  Complete means that the logical item has been added,
however it might still need post-processing done on it.  Progress means that forward progress was
made on getting the data merged, but that the operation still couldn't be completed.  In order to
continue the merge, the value of 'resume' should be passed as a named parameter.  Fail means that
the operation cannot complete, though if user_intervention is specified, it might be possible to
resume the merge anyway.

=item require_pk

This specifies a primary key on which this merge depends.  The import engine uses this as a hint
to optimize the order items are merged.

=item user_intervention

This specifies options which can be presented to the user to resume a otherwise failed merge.
Problem is a machine-readable string describing the problem.  Prompt is a human-readable string
to show to the user.  Options are an array of user-facing options to choose from, each followed by
a machine-readable identifier which will be passed back to merge().

=item post_process

This specifies a coderef which should be executed after all items have been successfully imported
/merged/whatever.  Basically, it allows you to do last minute updates to the data after all
insertions are performed.  The processing by these methods is not limited to rows directly part
of this logical item.

=back

=cut

requires 'merge';

1;