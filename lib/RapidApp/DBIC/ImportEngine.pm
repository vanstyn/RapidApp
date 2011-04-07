package RapidApp::DBIC::ImportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use Try::Tiny;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'decode_json', 'encode_json';
use Storable 'fd_retrieve';

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );
has 'input_format' => ( is => 'ro', isa => 'Str', required => 1, default => 'JSON' );

has 'on_progress' => ( is => 'rw', isa => 'Maybe[CodeRef]' );
has 'progress_period' => ( is => 'rw', isa => 'Int', default => -1, trigger => \&_on_progress_period_change );
has 'next_progress' => ( is => 'rw', isa => 'Int', default => -1 );

has 'records_read' => ( is => 'rw', isa => 'Int', default => 0 );
has 'records_imported' => ( is => 'rw', isa => 'Int', default => 0 );

has 'commit_partial_import' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'data_is_dirty' => ( is => 'rw', isa => 'Bool', default => 0 );

with 'RapidApp::DBIC::SchemaAnalysis';

# map of {ColKey}{read_id} => $saved_id
has 'auto_id_map' => ( is => 'ro', isa => 'HashRef[HashRef[Str]]', default => sub {{}} );

# map of {colKey}{missing_id} => [ [ $srcN, $rec, \@deps, $errMsg ], ... ]
has 'records_missing_keys' => ( is => 'ro', isa => 'HashRef[HashRef[ArrayRef]]', default => sub {{}} );
sub records_missing_keys_count {
	my $self= shift;
	my $cnt= 0;
	map { map { $cnt+= scalar(@$_) } values %$_ } values %{$self->records_missing_keys};
	return $cnt;
}

has 'pending_inserts' => ( is => 'ro', isa => 'ArrayRef[ArrayRef]', default => sub {[]} );

# array of [ [ $srcN, $rec, \@deps, $errMsg ], ... ]
has 'records_failed_insert' => ( is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub {[]} );

# map of {srcN}{primary_key} => 1
#has 'processed' => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );

has '_calc_dep_fn_per_source' => ( is => 'rw', isa => 'HashRef[CodeRef]', lazy_build => 1 );
has '_proc_dep_fn_per_source' => ( is => 'rw', isa => 'HashRef[CodeRef]', lazy_build => 1 );

sub translate_key {
	my ($self, $colkey, $val)= @_;
	my $mapByCol= $self->auto_id_map->{$colkey};
	return $mapByCol? $mapByCol->{$val} : undef;
}

sub set_translation {
	my ($self, $colKey, $oldVal, $newVal)= @_;
	my $mapByCol= $self->auto_id_map->{$colKey} ||= {};
	$mapByCol->{$oldVal}= $newVal;
	my @resolved= $self->_pop_delayed_inserts($colKey, $oldVal);
	if (scalar @resolved) {
		DEBUG('import', "\t[resolved dep: $colKey  $oldVal => $newVal ]");
		push @{$self->pending_inserts}, @resolved;
	}
}

sub push_delayed_insert {
	my ($self, $colKey, $val, $insertParamArray)= @_;
	my $pendingByCol= ($self->records_missing_keys->{$colKey} ||= {}); 
	my $pendingByVal= ($pendingByCol->{$val} ||= []);
	push @$pendingByVal, $insertParamArray;
	$self->_send_feedback_event if (!--$self->{next_progress});
}

sub _pop_delayed_inserts {
	my ($self, $colKey, $val)= @_;
	my $pendingByCol= $self->records_missing_keys->{$colKey} or return;
	my $pendingByKey= delete $pendingByCol->{$val} or return;
	scalar keys %$pendingByCol or delete $self->records_missing_keys->{$colKey};
	return @$pendingByKey;
}

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

sub import_records {
	my ($self, $src)= @_;
	my ($data, $cnt, $worklist);
	$self->schema->txn_do( sub {
		my $acn;
		while (($data= $self->read_record($src))) {
			$self->import_record($data);
			# now, insert any records that depended on this one (unless they have other un-met deps, in which case they get re-queued)
			while (my $delayedInsert= shift @{$self->pending_inserts}) {
				$self->_dep_resolve_and_insert(@$delayedInsert);
			}
		}
		
		# keep trying to insert them until either no records get inserted, or until they all succeed
		if (scalar @{$self->records_failed_insert}) {
			do {
				$worklist= $self->records_failed_insert;
				$self->records_failed_insert([]);
				
				$self->perform_insert(@$_) for (@$worklist);
				# now, insert any records that depended on this one (unless they have other un-met deps, in which case they get re-queued)
				while (my $delayedInsert= shift @{$self->pending_inserts}) {
					$self->_dep_resolve_and_insert(@$delayedInsert);
				}
			} while (scalar( @{$self->records_failed_insert} ) != scalar(@$worklist));
			
			if ($cnt= scalar @{$self->records_failed_insert}) {
				$self->report_insert_errors;
				my $msg= "$cnt records could not be added due to errors\nSee /tmp/rapidapp_import_errors.txt for details\n";
				$self->commit_partial_import? warn $msg : die $msg;
				$self->data_is_dirty(1);
			}
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
	$debug_fd->open('/tmp/rapidapp_import_errors.txt', 'w') or die $!;
	return $debug_fd;
}

sub report_missing_keys {
	my $self= shift;
	
	my $debug_fd= $self->_debug_fd;
	for my $colKey (keys %{$self->records_missing_keys}) {
		while (my ($colVal, $recs)= each %{$self->records_missing_keys->{$colKey}}) {
			$debug_fd->print("Required $colKey = '$colVal' :\n");
			$debug_fd->print("\t".encode_json($_)."\n") for (@$recs);
		}
	}
	$debug_fd->flush();
}

sub report_insert_errors {
	my $self= shift;
	
	my $debug_fd= $self->_debug_fd;
	$debug_fd->print("Insertion Errors:\n");
	for my $attempt (@{$self->{records_failed_insert}}) {
		my ($srcN, $rec, $deps, $remappedRec, $errMsg)= @$attempt;
		$debug_fd->print("insert $srcN\n\tRecord   : ".encode_json($rec)."\n\tRemapped : ".encode_json($remappedRec)."\n\tError    : $errMsg\n");
	}
	$debug_fd->flush();
}

sub read_record {
	my ($self, $src)= @_;
	my $ret;
	
	return undef if $src->eof;
	
	if ($self->input_format eq 'JSON') {
		my $line= $src->getline;
		defined($line) or return undef;
		chomp $line;
		$ret= decode_json($line);
	} elsif ($self->input_format eq 'STORABLE') {
		$ret= fd_retrieve($src);
		# we have the option to write an end-of-file record in the storable stream,
		#   so that multiple things could be stored in the same file
		return undef if ($ret eq 'EOF');
	} else {
		die "Unknown input format ".$self->input_format;
	}
	
	if ($ret) {
		$self->{records_read}++;
		$self->_send_feedback_event if (!--$self->{next_progress});
	}
	return $ret;
}

sub import_record {
	my $self= shift;
	my %p= validate(@_, { action => 0, source => {type=>SCALAR}, data => {type=>HASHREF}, search => 0 });
	my $srcN= $p{source};
	my $rec= $p{data};
	defined $self->valid_sources->{$srcN} or die "Cannot import records into source $srcN";
	my $code;
	
	$code= $self->_calc_dep_fn_per_source->{$srcN};
	my $deps= $code->($self, $srcN, $rec);
	
	$self->_dep_resolve_and_insert($srcN, $rec, $deps);
}

sub get_primary_key_string {
	my ($self, $rsrc, $rec)= @_;
	my @pkvals;
	for my $colN ($rsrc->primary_columns) {
		defined $rec->{$colN} or return '';  # primary key wasn't given.  Hopefully it gets autogenerated during insert.
		push @pkvals, $rec->{$colN};
	}
	return stringify_pk(@pkvals);
}

sub stringify_pk {
	join '', map { length($_).'|'.$_ } @_;
}

sub perform_insert {
	my $self= shift;
	my ($srcN, $rec, $deps, $remappedRec)= @_;
	
	DEBUG('import', 'perform_insert', $srcN, $rec, '=>', $remappedRec);
	
	my $rs= $self->schema->resultset($srcN);
	my $resultClass= $rs->result_class;
	my ($code, $row);
	
	# perform the insert, possibly calling the Result class to do the work
	my $err;
	try {
		if ($code= $resultClass->can('import_create')) {
			$row= $resultClass->$code($rs, $remappedRec, $rec);
		} else {
			die if exists $remappedRec->{id};
			$row= $rs->create($remappedRec);
		}
		$self->{records_imported}++;
		$self->_send_feedback_event if (!--$self->{next_progress});
	}
	catch {
		$err= $_;
		$err= "$err" if (ref $err);
	};
	if ($err) {
		# we'll try it again later
		DEBUG('import', "\t[failed, deferred...]");
		push @{$self->records_failed_insert}, [ @_, $err ];
		$self->_send_feedback_event if (!--$self->{next_progress});
		return;
	}
	
	# record any auto-id values that got generated
	my @autoCols= @{$self->auto_cols_per_source->{$srcN} || []};
	for my $colN (@autoCols) {
		my $origVal= $rec->{$colN};
		next unless defined $origVal;
		
		my $newVal= $row->get_column($colN);
		my $colKey= $srcN.'.'.$colN;
		$self->set_translation($colKey, $origVal, $newVal);
	}
}

sub _dep_resolve_and_insert {
	my ($self, $srcN, $rec, $deps)= @_;
	
	my $resolveDepFn= $self->_proc_dep_fn_per_source->{$srcN};
	
	my $delayedCnt= $self->records_missing_keys_count;
	my $remapped= $resolveDepFn->(@_);
	if ($remapped) {
		$self->perform_insert($srcN, $rec, $deps, $remapped);
	} else {
		$self->records_missing_keys_count > $delayedCnt
			or die "process_dependencies must call push_delayed_insert if it can't remap the record";
	}
}

sub calculate_dependencies {
	my ($self, $srcN, $rec)= @_;
	return $self->col_depend_per_source->{$srcN} || [];
}

sub process_dependencies {
	my $self= shift;
	my ($srcN, $rec, $deps)= @_;
	
	my $remappedRec= { %$rec };
	
	# Delete values for auto-generated keys
	# there should just be zero or one for auto_increment, but we might extend this to auto-datetimes too
	my @autoCols= @{$self->auto_cols_per_source->{$srcN} || []};
	delete $remappedRec->{$_} for (@autoCols);
	
	# swap values of any fields that need remapped
	for my $dep (@$deps) {
		my $colN= $dep->{col};
		my $oldVal= $rec->{$colN};
		# only swap the value if it was given as a scalar.  Hashes indicate fancy DBIC stuff
		if (defined $oldVal && !ref $oldVal) {
			# find the new value for the key
			my $newVal= $self->auto_id_map->{$dep->{origin_colKey}}->{$oldVal};
			
			# if we don't know it yet, we depend on this foreign column value.
			# queue this record for later insertion.
			if (!defined $newVal) {
				DEBUG('import', "\t[delayed due to dependency: $srcN.$colN=$oldVal => ".$dep->{origin_colKey}."=?? ]");
				$self->push_delayed_insert($dep->{origin_colKey}, $oldVal, [ $srcN, $rec, $deps ]);
				return undef;
			}
			# swap it
			$remappedRec->{$colN}= $newVal;
		}
	}
	
	# the record will now get inserted
	return $remappedRec;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
