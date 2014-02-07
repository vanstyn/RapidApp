package RapidApp::DBIC::Component::AuditAny;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class::Schema');


### WARNING: THIS IS DEPRECATED, DO NOT USE
### See DBIx::Class::AuditAny  instead
###   (https://github.com/vanstyn/DBIx-Class-AuditAny)


use RapidApp::Include qw(sugar perlutil);
use Class::MOP::Class;

__PACKAGE__->mk_classdata( 'log_source_name' );
__PACKAGE__->mk_classdata( 'log_source_column_map' );
__PACKAGE__->mk_classdata( 'track_actions' );
__PACKAGE__->mk_classdata( 'track_immutable' );
__PACKAGE__->mk_classdata( 'no_compare_from_storage' );
#__PACKAGE__->mk_classdata( 'get_user_id_coderef' );

__PACKAGE__->mk_classdata( '_tracked_sources' );
__PACKAGE__->mk_classdata( '_initialized' );
__PACKAGE__->mk_classdata( '_active_data_points' );

# Provided as an optional hook to get arbitrary data points
sub get_log_data_points { {} }

# These are the default mappings of columns for the supplied log Source
# User-defined mappings are optionally specified in 'log_source_column_map'
# Any columns from the default list can be turned off (i.e. set to not store
# the given data point) by setting a value of undef
our %default_column_map = (
	change_ts		=> 'change_ts',
	#user_id			=> 'user_id', #<-- this will almost always be defined, but is app specific so not built-in
	action			=> 'action', 		# insert/update/delete
	schema			=> '', 			# store the name of the schema, off by default
	source			=> 'source',
	table			=> '', 			# store the table name
	pri_key_column	=> '',
	pri_key_value	=> 'row_key', 		# the value of the primary key of the changed row
	change_details	=> 'change_details'	# where to store the description of the change
);

our $ACTIVE_TXN = undef;

our @_action_names = qw(insert update delete);

sub _init {
	my $class = shift;
	return if ($class->_initialized);
	
	$class->_tracked_sources( {} ) unless ($class->_tracked_sources);
	$class->track_actions( \@_action_names ) unless ($class->track_actions);
	
	die 'track_actions must be an ArrayRef!' 
		unless (ref($class->track_actions) eq 'ARRAY');
	$_ ~~ @_action_names or die "Invalid action '$_' - only allowed actions: " . join(',',@_action_names) 
		for (@{$class->track_actions});
	
	die "No 'log_source_name' declared!" unless ($class->log_source_name);
	my $LogSource = $class->source($class->log_source_name) 
		or die "Invalid log_source_name '" . $class->log_source_name . "'";
	
	$class->log_source_column_map({
		%default_column_map,
		%{ $class->log_source_column_map || {} }
	});
	my $col_map = $class->log_source_column_map;
	
	# data points are disabled if they map to a false/undef/empty value:
	! $col_map->{$_} || $col_map->{$_} eq '' and delete $col_map->{$_} for (keys %$col_map);
	
	# Check to make sure the selected Log Source actually has columns for each
	# of the active/enabled data points:
	my %has_cols = map {$_=>1} $LogSource->columns;
	my @missing_cols = grep { !$has_cols{$_} } values %$col_map;
	die ref($LogSource) . ' cannot be used as the Log Source because it is missing ' .
	 'the following required columns: ' . join(', ',map {"'$_'"} @missing_cols) 
		if (scalar @missing_cols > 0);
	
	# Normalize the recorded source name for good measure:
	$class->log_source_name( $LogSource->source_name );
	
	return $class->_initialized(1);
}

sub track_all_sources {
	my ($class,@exclude) = @_;
	$class->_init;
	
	push @exclude, $class->log_source_name;
	
	# temp - auto exclude sources without exactly one primary key
	foreach my $source_name ($class->sources) {
		my $Source = $class->source($source_name);
		push @exclude, $source_name unless (scalar($Source->primary_columns) == 1);
	}
	
	
	my %excl = map {$_=>1} @exclude;
	return $class->track_sources(grep { !$excl{$_} } $class->sources);
}

sub track_sources {
	my ($class,@sources) = @_;
	$class->_init;
	
	foreach my $name (@sources) {
		my $Source = $class->source($name) or die "Bad Result Source name '$name'";
		my $source_name = $Source->source_name;
		
		die "The Log Source (" . $class->log_source_name . ") cannot track itself!!"
			if ($source_name eq $class->log_source_name);
		
		# Skip sources we've already setup:
		return if ($class->_tracked_sources->{$source_name});
		
		$class->_add_change_tracker($source_name,$_) for (@{$class->track_actions});
		$class->_tracked_sources->{$source_name} = 1;
	}
}



sub _add_change_tracker {
	my $class = shift;
	my $source_name = shift;
	my $action = shift;
	die "Bad action '$action'" unless ($action ~~ @_action_names);
	
	my $Source = $class->source($source_name);
	my $result_class = $class->class($source_name);
	my $meta = Class::MOP::Class->initialize($result_class);
	my $immutable = $meta->is_immutable;
	
	die "Won't add tracker/modifier method to immutable Result Class '$result_class' " .
	 '(hint: did you forget to remove __PACKAGE__->meta->make_immutable ??)' .
	 ' - to force/override, set schema class attr "track_immutable" to true.'
		if ($immutable && !$class->track_immutable);
	
	# Tempory turn mutable back on, saving any immutable_options, first:
	my %immut_opts = ();
	if($immutable) {
		%immut_opts = $meta->immutable_options;
		$meta->make_mutable;
	}
	
	my $applied_attr = '_' . $action . '_tracker_applied';
	$result_class->can($applied_attr) or $result_class->mk_classdata($applied_attr);
		
	die "Attempted to add duplicate update tracker!" 
		if ($result_class->$applied_attr);
		
	my @pri_keys = $Source->primary_columns;
	die "Source '$source_name' has " . scalar(@pri_keys) . " primary keys. " .
	 "Only sources with exactly 1 are currently supported." unless (scalar(@pri_keys) == 1);
	
	my %base_data = (
		action 				=> $action,
		source 				=> $Source->source_name,
		table 				=> $Source->from,
		pri_key_column		=> $pri_keys[0]
	);
	
	$meta->add_around_method_modifier( $action => sub {
		my $orig = shift;
		my $Row = shift;
		
		# Future...
		#if($ACTIVE_TXN) {
		#	my $origRow = $Row;
		#	my %old = ();
		#	if($Row->in_storage) {
		#		$origRow = $Row->get_from_storage || $Row;
		#		%old = $origRow->get_columns;
		#	}
		#	
		#	push @{$ACTIVE_TXN->{change_rows}}, {
		#		Row => $Row,
		#		old => \%old,
		#		origRow => $origRow
		#	};
		#}
		
		###
		my ($changes,@ret) = wantarray ?
			$class->proxy_method_get_changed($Row,$orig,@_) :
				@{$class->proxy_method_get_changed($Row,$orig,@_)};
		###
		
		$class->record_change($Row,$changes,%base_data);
		
		return wantarray ? @ret : $ret[0];
	}) and $result_class->$applied_attr(1);
	
	# Restore immutability to the way to was:
	$meta->make_immutable(%immut_opts) if ($immutable);
}



sub record_change {
	my $class = shift;
	my ($Row,$changes,%base_data) = @_;
	
	my $data_points = $class->get_log_data_points(@_);
	die "'get_log_data_points()' did not return expected HashRef"
		unless (ref($data_points) eq 'HASH');
		
	%$data_points = (%base_data, %$data_points);
	
	my $col_map = $class->log_source_column_map;
	my %activ = map {$_=>1} keys %$col_map;
	
	# Assuming it hasn't already been obtained above (and hasn't been turned off)
	# get the actual string description of the change:
	$data_points->{change_details} = $class->get_change_details(@_) if (
		! exists $data_points->{change_details} and
		$activ{change_details}
	);
	
	# Get the pri_key value:
	$data_points->{pri_key_value} = $class->get_pri_key_value(@_) if (
		! exists $data_points->{pri_key_value} and
		$activ{pri_key_value}
	);
	
	my $dt = DateTime->now( time_zone => 'local' );
	$data_points->{change_ts} = $dt if (
		! exists $data_points->{change_ts} and
		$activ{change_ts}
	);
	
	my %create = map { $col_map->{$_} => ($data_points->{$_} || undef) } keys %$col_map;
	return $class->create_log_entry(\%create);
}

sub create_log_entry {
	my $class = shift;
	return $class->resultset($class->log_source_name)->create(@_);
}

sub get_pri_key_value {
	my $class = shift;
	my $Row = shift;
	my ($col) = $Row->primary_columns;
	return $Row->get_column($col);
}

sub get_change_details {
	my $class = shift;
	
	# TODO: add a choice among multiple different formats:
	
	return $class->get_change_format_json_table(@_);
}

# simple tabular as array of arrays in JSON:
sub get_change_format_json_table {
	my $class = shift;
	my ($Row,$changes,%base_data) = @_;
	
	my $action = $base_data{action} or die "Unexpected error; action attr missing";
	
	#my $table = $action eq 'update' ? [[$action,'old','new']] : [[$action,'']];
	my $table = [[$action,'old','new']];
	push @$table, [$changes->{$_}->{header},$changes->{$_}->{old},$changes->{$_}->{new}]
		for (sort {$a cmp $b} keys %$changes);
	
	return undef unless (scalar @$table > 1);
	return encode_json($table);
}


## Future... 
#sub txn_do :Debug {
#	my $class = shift;
#	return $class->next::method(@_) if ($ACTIVE_TXN);
#	
#	# If we're here, this is the topmost txn_do call.
#	require String::Random;
#	local $ACTIVE_TXN = {
#		txn_id => String::Random->new->randregex('[a-z0-9A-Z]{5}'),
#		change_rows => []
#	};
#	
#	scream('txn_Id: ' . $ACTIVE_TXN->{txn_id});
#	
#	my $ret = $class->next::method(@_);
#	
#	foreach my $ch (@{$ACTIVE_TXN->{change_rows}}) {
#		my $diff = $class->row_compare_data_diff($ch->{Row},$ch->{old},$ch->{origRow});
#		scream_color(GREEN.BOLD,$diff);
#	}
#	
#	
#	
#	return $ret;
#}


## copied from RapidApp::DBIC::Component::TableSpec:
#
# Works like an around method modifier, but $self is expected as first arg and
# $orig (method) is expected as second arg (reversed from a normal around modifier).
# Calls the supplied method and returns what changed in the record from before to 
# after the call. e.g.:
#
# my ($changes) = $self->proxy_method_get_changed('update',{ foo => 'sdfds'});
#
# This is typically used for update, but could be any other method, too.
#
# Detects/propogates wantarray context. Call like this to chain from another modifier:
#my ($changes,@ret) = wantarray ?
# $self->proxy_method_get_changed($orig,@_) :
#  @{$self->proxy_method_get_changed($orig,@_)};
#
our $TRY_USE_TABLESPEC = 1;
our $TABLESPEC_EXCLUDE_ORIG_FK_VAL = 0;
sub proxy_method_get_changed {
	my $class = shift;
	my $self = shift;
	my $method = shift;
	
	my $origRow = $self;
	my %old = ();
	if($self->in_storage) {
		$origRow = $self->get_from_storage || $self;
		%old = $origRow->get_columns;
	}
	
	my @ret = ();
	wantarray ? 
		@ret = $self->$method(@_) : 
			$ret[0] = $self->$method(@_);
	
	my $diff = $class->row_compare_data_diff($self,\%old,$origRow);
	
	return wantarray ? ($diff,@ret) : [$diff,@ret];
}


sub row_compare_data_diff {
	my $class = shift;
	my $self = shift;
	my $data = shift;
	my $origRow = shift;
	
	my %old = %$data;
	
	my %new = ();
	if($self->in_storage) {
		%new = $class->no_compare_from_storage ? 
			$self->get_columns : $self->get_from_storage->get_columns;
	}
	
	# This logic is duplicated in DbicLink2. Not sure how to avoid it, though,
	# and keep a clean API
	@changed = ();
	foreach my $col (uniq(keys %new,keys %old)) {
		next if (! defined $new{$col} and ! defined $old{$col});
		next if ($new{$col} eq $old{$col});
		push @changed, $col;
	}
	
	my @new_changed = ();
	
	# Designed to work with proprietary RapidApp/TableSpec, if configured:
	my $use_ts = 1 if ($TRY_USE_TABLESPEC && $self->can('TableSpec_get_conf'));
	my $fk_map = $use_ts ? $self->TableSpec_get_conf('relationship_column_fks_map') : {};
		
	foreach my $col (@changed) {
		unless($use_ts && $fk_map->{$col}) {
			push @new_changed, $col;
			next;
		}
		
		# ------
		# Only applies to proprietary RapidApp/TableSpec, if present:
		#
		push @new_changed, $col unless ($TABLESPEC_EXCLUDE_ORIG_FK_VAL);
		
		my $rel = $fk_map->{$col};
		my $display_col = $self->TableSpec_related_get_set_conf($rel,'display_column');
		
		my $relOld = $origRow->$rel;
		my $relNew = $self->$rel;
		
		unless($display_col and ($relOld or $relNew)) {
			push @new_changed, $col if ($TABLESPEC_EXCLUDE_ORIG_FK_VAL);
			next;
		}
		
		push @new_changed, $rel;
		
		$old{$rel} = $relOld->get_column($display_col) if (exists $old{$col} and $relOld);
		$new{$rel} = $relNew->get_column($display_col) if (exists $new{$col} and $relNew);
		#
		# ------
	}
	
	@changed = @new_changed;
	
	my $col_props = $use_ts ? { $self->TableSpec_get_conf('columns') } : {};
	
	my %diff = map {
		$_ => { 
			old => $old{$_}, 
			new => $new{$_},
			header => ($col_props->{$_} && $col_props->{$_}->{header}) ? 
				$col_props->{$_}->{header} : $_
		} 
	} @changed;
	
	return \%diff;
}


1;__END__
