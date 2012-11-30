package RapidApp::DBIC::Component::SimpleChangeLog;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class::Schema');

use RapidApp::Include qw(sugar perlutil);
use Class::MOP::Class;

__PACKAGE__->mk_classdata( 'log_source_name' );
__PACKAGE__->mk_classdata( 'log_source_column_map' );
__PACKAGE__->mk_classdata( 'track_actions' );
__PACKAGE__->mk_classdata( 'track_immutable' );

__PACKAGE__->mk_classdata( '_tracked_sources' );
__PACKAGE__->mk_classdata( '_initialized' );

# These are the default mappings of columns for the supplied log Source
# User-defined mappings are optionally specified in 'log_source_column_map'
# Any columns from the default list can be turned off (i.e. set to not store
# the given data point) by setting a value of undef
our %default_column_map = (
	change_ts	=> 'change_ts',
	user_id		=> 'user_id',
	action		=> 'action', 		# insert/update/delete
	schema		=> undef, 			# store the name of the schema, off by default
	source		=> 'source',
	table		=> undef, 			# store the table name
	pri_key		=> 'pri_key', 		# the value of the primary key of the changed row
	diff_change	=> 'diff_change'	# where to store the description of the change
);


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
	
	my @required_cols = grep { defined $_ } values %{$class->log_source_column_map};
	my %has_cols = map {$_=>1} $LogSource->columns;
	my @missing_cols = grep { !$has_cols{$_} } @required_cols;
	
	die ref($LogSource) . ' cannot be used as the Log Source because it is missing ' .
	 'the following required columns: ' . join(', ',map {"'$_'"} @missing_cols) 
		if (scalar @missing_cols > 0);
	
	# Normalize:
	$class->log_source_name( $LogSource->source_name );
	
	return $class->_initialized(1);
}

sub track_all_sources {
	my ($class,@exclude) = @_;
	$class->_init;
	
	push @exclude, $class->log_source_name;
	return $class->track_sources(grep { ! $_ ~~ @exclude } $class->sources);
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
		
		
		## Setup tracking code.....
		
		$class->_add_change_tracker($source_name,'insert');
		$class->_add_change_tracker($source_name,'update');
		$class->_add_change_tracker($source_name,'delete');
	
	
		$class->_tracked_sources->{$source_name} = 1;
	}

}



sub _add_change_tracker {
	my $class = shift;
	my $source_name = shift;
	my $action = shift;
	die "Bad action '$action'" unless ($action ~~ @_action_names);
	
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
	
	
	$meta->add_around_method_modifier( $action => sub {
		my $orig = shift;
		my $self = shift;
		
		###
		my ($changes,@ret) = wantarray ?
			proxy_method_get_changed($self,$orig,@_) :
				@{proxy_method_get_changed($self,$orig,@_)};
		###
		
		scream($action,$changes);
		
		
		
		return wantarray ? @ret : $ret[0];
	}) and $result_class->$applied_attr(1);
	
	# Restore immutability to the way to was:
	$meta->make_immutable(%immut_opts) if ($immutable);
}





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
	
	my %new = ();
	if($self->in_storage) {
		%new = $self->get_columns;
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
	
	return wantarray ? (\%diff,@ret) : [\%diff,@ret];
}




1;__END__
