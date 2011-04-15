package RapidApp::DBIC::ImportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use Try::Tiny;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'decode_json', 'encode_json';
use Storable 'fd_retrieve';
use RapidApp::DBIC::ImportEngine::Item;
use RapidApp::DBIC::ImportEngine::ItemReader;
use RapidApp::DBIC::SchemaAnalysis::Dependency;

=head1 DESCRIPTION

This engine facilitates the inserting of hashes which describe a row of a table.

Its main feature is to remap fields in a record which refer to auto-increment columns in
another table.  For instance, it will correctly handle
  { action => 'insert', source => 'Foo', data => { id => 'x', value => 'aaaaa' } }
  { action => 'insert', source => 'Foo', data => { id => 'y', parent_id => 'x', value => 'bbbbb' } }
  { action => 'insert', source => 'Foo', data => { parent_id => 'y', value => 'ccccc' } }
by translating from 'x' to the number generated for the auto_increment column <Foo.id> when
inserting record 'x'.  All other records which refer to <Foo.id = 'x'> will get remapped to
<Foo.id = ###>.  While I used strings in the example, it is just as valid to use the numbers from
a previous incarnation of the database.  ImportEngine will not allow any values for auto-id fields
to pass through without being translated.

Another feature is that inserts will be re-ordered if necessary, such that a record which refers to
an unknown key will be placed in a waiting list until that key is seen and inserted.

=head1 BUGS

Currently, there are situations where a record will get inserted before the required foreign
constraint is met.  For instance, if <C.id> has a FK of <B.id> which has a FK of <A.id>, then
an insert for table C will be tried as soon as the corresponding key is added to table A.
Some additional logic could prevent this situation, but sometimes circular dependencies show up
which would prevent any records form getting inserted at all.  Some fancy logic will be needed
to solve this the "right way" (which may involve inserting partial records and updating them later,
and in other cases might just be better handled by disabling constraints temporarily).
In the meantime, we just try inserting things repeatedly until
they all succeed or until no progress is made.

While DBIC supports fancy nested inserts and selects, we currently only translate keys for flat
records.  I would love to support the full DBIC semantics, but it will require much more time
to implement.

  # Will not work yet!
  # record A will get mapped to the correct Foo, but A.category will not get translated.
  { action => 'insert', source => 'Category', data => { id => 'n', data => 'category of blah' } }
  { action => 'insert', source => 'Foo', data => { id => 1, a => { category => 'n', data => 'blah' } } }

Key translations do not happen for searches.  Implementing this would require a full-blown search
logic processor.  Until this is implemented, do not write searches that depend on a generated key.
However, the whole point of a search is to find generated IDs of existing records based on
non-generated fields, so not being able to search on a generated field shouldn't be that big of
a problem.

  # Will not work yet!
  # 'x' will not get translated to a Foo.id
  { action => 'find', source => 'Foo', search => { parent_id => 'x' }, data => { id => 'y' } }

And finally, I don't have support for multi-column keys.  However, I left room in the design for
this.  We just don't happen to have any in our projects so far, so I didn't waste time implementing
it.

=cut

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

has 'reader' => ( is => 'rw', isa => 'RapidApp::DBIC::ImportEngine::ItemReader',
	coerce => 1, trigger => \&setup_reader_itemClassForResultSource );

has 'on_progress' => ( is => 'rw', isa => 'Maybe[CodeRef]' );
has 'progress_period' => ( is => 'rw', isa => 'Int', default => -1, trigger => \&_on_progress_period_change );
has 'next_progress' => ( is => 'rw', isa => 'Int', default => -1 );

has 'records_read' => ( is => 'rw', isa => 'Int', default => 0 );
has 'records_imported' => ( is => 'rw', isa => 'Int', default => 0 );

has 'commit_partial_import' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'data_is_dirty' => ( is => 'rw', isa => 'Bool', default => 0 );

with 'RapidApp::DBIC::SchemaAnalysis';

# map of {ColKey}{read_id} => $saved_id
# used by 'translate_key' and 'set_translation'
has 'auto_id_map' => ( is => 'ro', isa => 'HashRef[HashRef[Str]]', default => sub {{}} );

# map of {colKey}{missing_id} => [ [ $srcN, $rec, \@deps, $errMsg ], ... ]
has 'records_missing_keys' => ( is => 'ro', isa => 'HashRef[HashRef[ArrayRef]]', default => sub {{}} );
sub records_missing_keys_count {
	my $self= shift;
	my $cnt= 0;
	map { map { $cnt+= scalar(@$_) } values %$_ } values %{$self->records_missing_keys};
	return $cnt;
}

has 'pending_items' => ( is => 'ro', isa => 'ArrayRef[RapidApp::DBIC::ImportEngine::Item]', default => sub {[]} );

# array of [ [ $srcN, $rec, \@deps, $errMsg ], ... ]
has 'records_failed_insert' => ( is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub {[]} );

# map of {srcN}{primary_key} => 1
#has 'processed' => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );

#has '_calc_dep_fn_per_source' => ( is => 'rw', isa => 'HashRef[CodeRef]', lazy_build => 1 );
#has '_proc_dep_fn_per_source' => ( is => 'rw', isa => 'HashRef[CodeRef]', lazy_build => 1 );

sub BUILD {
	my $self= shift;
	$self->setup_reader_itemClassForResultSource($self->reader) if ($self->reader);
}

# Return a new-db-key as a function of an old-db-key.
# Returns undef if the translation isn't known yet.
sub translate_key {
	my ($self, $colkey, $val)= @_;
	my $mapByCol= $self->auto_id_map->{$colkey};
	return $mapByCol? $mapByCol->{$val} : undef;
}

# Define a mapping from an old-db-key to a new-db-key for a given colKey
# (a colKey defines a key within a table, which is usually just "Table.Col")
# This method has a side-effect of queueing all records which were waiting for this translation to be defined.
sub set_translation {
	my ($self, $colKey, $oldVal, $newVal)= @_;
	my $mapByCol= $self->auto_id_map->{$colKey} ||= {};
	$mapByCol->{$oldVal}= $newVal;
	my @resolved= $self->_pop_delayed_inserts($colKey, $oldVal);
	if (scalar @resolved) {
		DEBUG('import', "\t[resolved dep: $colKey  $oldVal => $newVal, ".(scalar @resolved)." items queued ]");
		push @{$self->pending_items}, @resolved;
	}
}

# Tell the engine to delay processing of this item until a translation is known for the given colKey and value
sub push_delayed_insert {
	my ($self, $colKey, $val, $importItem)= @_;
	my $pendingByCol= ($self->records_missing_keys->{$colKey} ||= {}); 
	my $pendingByVal= ($pendingByCol->{$val} ||= []);
	push @$pendingByVal, $importItem;
	$self->_send_feedback_event if (!--$self->{next_progress});
}

sub _pop_delayed_inserts {
	my ($self, $colKey, $val)= @_;
	my $pendingByCol= $self->records_missing_keys->{$colKey} or return;
	my $pendingByKey= delete $pendingByCol->{$val} or return;
	scalar keys %$pendingByCol or delete $self->records_missing_keys->{$colKey};
	return @$pendingByKey;
}

=pod
sub _build__calc_dep_fn_per_source {
	my $self= shift;
	my $default= $self->can('calculate_dependencies'); # do it this way to pick up methods from subclasses
	my %result= map {
		$_ => $self->schema->resultset($_)->result_class->can('import_calculate_dependencies')
				|| $default
		} keys %{$self->valid_sources};
	return \%result;
}

sub _build__proc_dep_fn_per_source {
	my $self= shift;
	my $default= $self->can('process_dependencies'); # do it this way to pick up methods from subclasses
	my %result= map {
		$_ => $self->schema->resultset($_)->result_class->can('import_process_dependencies')
				|| $default
		} keys %{$self->valid_sources};
	return \%result;
}
=cut

sub _on_progress_period_change {
	my $self= shift;
	$self->next_progress($self->progress_period) if ($self->progress_period > 0);
}

sub _send_feedback_event {
	my $self= shift;
	my $code= $self->on_progress();
	$code->() if $code;
	$self->next_progress($self->progress_period);
}

# Process all items in the input stream, and handle failures.
sub import_records {
	my ($self, $src)= @_;
	
	# optionally set up a new reader
	if (defined $src) {
		(ref $src)->isa('IO::Handle')
			and $src= { source => $src };
		ref $src eq 'HASH'
			and $src= RapidApp::DBIC::ImportEngine::ItemReader->factory_create($src);
		$self->reader($src);
	}
	
	my ($data, $cnt, $worklist);
	$self->schema->txn_do( sub {
		my $acn;
		while (($data= $self->next_item)) {
			$self->process_item($data);
		}
		
		# Inserts might fail if a constraint is not met.  Ideally our dependency system catches that, but this is a fall-back mechanism.
		# Keep trying to insert them until either no records get inserted, or until they all succeed
		my $prev_imported_count= -1;
		while (scalar @{$self->records_failed_insert} && $self->records_imported > $prev_imported_count) {
			$prev_imported_count= $self->records_imported;
			push @{$self->pending_items}, map { $_->[0] } @{$self->records_failed_insert};
			$self->records_failed_insert([]);
			
			while (($data= $self->next_item($src))) {
				$self->process_item($data);
			}
		}
		
		if ($cnt= scalar @{$self->records_failed_insert}) {
			$self->report_insert_errors;
			my $msg= "$cnt records could not be added due to errors\nSee /tmp/rapidapp_import_errors.txt for details\n";
			$self->commit_partial_import? warn $msg : die $msg;
			$self->data_is_dirty(1);
		}
		
		if ($cnt= $self->records_missing_keys_count) {
			$self->report_missing_keys;
			my $msg= "$cnt records could not be added due to missing dependencies\nSee /tmp/rapidapp_import_errors.txt for details\n";
			$self->commit_partial_import? warn $msg : die $msg;
			$self->data_is_dirty(1);
		}
		$self->data_is_dirty and warn "WARNING: Committing anyway via 'commit_partial_import'!!!";
	});
}

has '_debug_fd' => ( is => 'rw', isa => 'IO::File', lazy_build => 1 );
sub _build__debug_fd {
	my $debug_fd= IO::File->new;
	$debug_fd->open('/tmp/rapidapp_import_errors.txt', '>:utf8') or die $!;
	return $debug_fd;
}

sub report_missing_keys {
	my $self= shift;
	
	my $debug_fd= $self->_debug_fd;
	for my $colKey (keys %{$self->records_missing_keys}) {
		while (my ($colVal, $recs)= each %{$self->records_missing_keys->{$colKey}}) {
			$debug_fd->print("Required $colKey = '$colVal' :\n");
			$debug_fd->print("\t".encode_json({ %$_ })."\n") for (@$recs);
		}
	}
	$debug_fd->flush();
}

sub report_insert_errors {
	my $self= shift;
	
	my $debug_fd= $self->_debug_fd;
	$debug_fd->print("Insertion Errors:\n");
	for my $attempt (@{$self->{records_failed_insert}}) {
		my ($importItem, $errMsg)= @$attempt;
		$debug_fd->print(
			"insert ".$importItem->source
			."\n\tRecord   : ".encode_json($importItem->data)
			."\n\tRemapped : ".encode_json($importItem->remapped_data)."\n\tError    : $errMsg\n");
	}
	$debug_fd->flush();
}

# Get the next item to be processed, either from a waiting list or from the input stream.
sub next_item {
	my ($self)= @_;
	
	# if any previoud items are now ready to be processed, process them first
	my $delayedItem= shift @{$self->pending_items};
	return $delayedItem if $delayedItem;

	# else read the next one form the stream
	my $ret= $self->reader->next;
	if ($ret) {
		$self->{records_read}++;
		$self->_send_feedback_event if (!--$self->{next_progress});
	}
	return $ret;
}

# Process an items dependencies, or queue it for later.
# If deps are met, we call an action on the Item, and consider the item completed.
# Note: the item might not actually be complete after the action is run, but if not, it
#   is the responsibility of the item to re-queue itself in whatever manner needed.
sub process_item {
	my ($self, $importItem)= @_;
	
	$importItem->engine($self);
	
	if ($importItem->resolve_dependencies) {
		my $code= $importItem->can($importItem->action) or die (ref $importItem)." cannot perform action \"".$importItem->action."\"";
		$importItem->$code;
	} else {
		my $depList= $importItem->dependencies;
		defined $depList && scalar(@$depList) or die "resolve_dependencies must either return true, or build a list of dependencies";
		
		my $dep= $depList->[0];
		my $colKey= $dep->colKey;
		my $val= $importItem->data->{$dep->col};
		DEBUG('import', "\t[delayed due to dependency: $colKey = $val  => ".$dep->origin_colKey." = ?? ]");
		$self->push_delayed_insert($dep->origin_colKey, $val, $importItem);
		return;
	}
}

sub perform_find {
	my ($self, $srcN, $search, $bindData)= @_;
}

sub perform_insert {
	my ($self, $srcN, $rec, $remappedRec)= @_;
	
	DEBUG('import', 'perform_insert', $srcN, $rec, '=>', $remappedRec);
	
	defined $self->valid_sources->{$srcN} or die "Cannot import records into source $srcN";
	
	my $rs= $self->schema->resultset($srcN);
	my $resultClass= $rs->result_class;
	my ($code, $row);
	
	# perform the insert, possibly calling the Result class to do the work
	if ($code= $resultClass->can('import_create')) {
		$row= $resultClass->$code($rs, $remappedRec, $rec);
	} else {
		$row= $rs->create($remappedRec);
	}
	$self->{records_imported}++;
	$self->_send_feedback_event if (!--$self->{next_progress});
	
	# record any auto-id values that got generated
	for my $colN ($self->source_analysis->{$srcN}->autogen_cols) {
		my $origVal= $rec->{$colN};
		next unless defined $origVal;
		
		my $newVal= $row->get_column($colN);
		my $colKey= $srcN.'.'.$colN;
		$self->set_translation($colKey, $origVal, $newVal);
	}
}

# TODO: we want to do away with this logic at some point, and just fail on DB insert errors.
# But, first we need to have logic that will make sure the records get added in the correct sequence.
sub try_again_later {
	my ($self, $importItem, $errText)= @_;
	
	DEBUG('import', "\t[failed, deferred...]");
	push @{$self->records_failed_insert}, [ $importItem, $errText ];
	$self->_send_feedback_event if (!--$self->{next_progress});
	return;
}

# This procedure is used by importItem to build the remapped record.
# I put it here because I wanted to keep most of the engine logic in this file.
sub default_build_remapped_data {
	my ($self, $importItem)= @_;
	
	my $remappedData= { %{$importItem->data} };
	
	# Delete values for auto-generated keys
	# there should just be zero or one for auto_increment, but we might extend this to auto-datetimes too
	delete $remappedData->{$_} for ($self->source_analysis->{$importItem->source}->autogen_cols);
	
	return $remappedData;
}

# This procedure is used by importItem to process its dependencies.
# I put it here because I wanted to keep most of the engine logic in this file.
sub default_process_dependencies {
	my ($self, $importItem)= @_;
	my $srcN= $importItem->source;
	my $deps= $importItem->dependencies;
	
	# nothing to do if all deps are resolved
	scalar(@$deps) or return 1;
	
	# swap values of any fields that need remapped, and keep track of which we can't
	my @newDeps= grep { !$_->resolve($self, $importItem) } @$deps;
	
	$importItem->dependencies(\@newDeps);
	return scalar(@newDeps) == 0;
}

# ResultSources can have special import item classes, such that any record for a particular source
#   creates a subclass of RA::DBIC::IE::Item.  We expect them to be named [App::DB]::ImportItem::[Source]
#   where [App::DB] is the package name of the schema, and [Source] is the name of the DBIC ResultSource.
# This method builds a list of those classes, and then sets them in the reader, so that the reader can
#   manufacture the correct Item object.
sub setup_reader_itemClassForResultSource {
	my ($self, $reader)= @_;
	my $clsMap= $reader->itemClassForResultSource;
	defined $clsMap or $reader->itemClassForResultSource(($clsMap= {}));
	
	my $schemaCls= ref $self->schema or die "No schema selected";
	my $default= ($schemaCls.'::ImportItem')->can('new')? $schemaCls.'::ImportItem' : undef;
	
	for my $srcN (keys %{$self->valid_sources}) {
		my $customItemCls= $schemaCls.'::ImportItem::'.$srcN;
		$customItemCls= undef unless $customItemCls->can('new');
		$clsMap->{$srcN} ||= $customItemCls || $default;
	}
	
	# we've been modifying a ref to the one held by the reader, so nothing to do here
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
