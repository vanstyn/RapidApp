package RapidApp::DBIC::Component::TableSpec;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class');


# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

__PACKAGE__->mk_classdata( 'TableSpec' );
__PACKAGE__->mk_classdata( 'TableSpec_rel_columns' );

__PACKAGE__->mk_classdata( 'TableSpec_cnf' );
__PACKAGE__->mk_classdata( 'TableSpec_built_cnf' );

# See default profile definitions in RapidApp::TableSpec::Column
my $default_data_type_profiles = {
	text 			=> [ 'bigtext' ],
	blob 			=> [ 'bigtext' ],
	varchar 		=> [ 'text' ],
	char 			=> [ 'text' ],
	float			=> [ 'number' ],
	integer		=> [ 'number', 'int' ],
	tinyint		=> [ 'number', 'int' ],
	mediumint	=> [ 'number', 'int' ],
	bigint		=> [ 'number', 'int' ],
	datetime		=> [ 'datetime' ],
	timestamp	=> [ 'datetime' ],
	date			=> [ 'date' ],
};
__PACKAGE__->mk_classdata( 'TableSpec_data_type_profiles' );
__PACKAGE__->TableSpec_data_type_profiles({ %$default_data_type_profiles }); 



sub apply_TableSpec {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# ignore/return if apply_TableSpec has already been called:
	return if (
		defined $self->TableSpec_cnf and
		defined $self->TableSpec_cnf->{data} and
		defined $self->TableSpec_cnf->{data}->{apply_TableSpec_timestamp}
	);
	
	$self->TableSpec_data_type_profiles(
		%{ $self->TableSpec_data_type_profiles || {} },
		%{ delete $opt{TableSpec_data_type_profiles} }
	) if ($opt{TableSpec_data_type_profiles});
	
	$self->TableSpec($self->create_result_TableSpec($self,%opt));
	
	$self->TableSpec_rel_columns({});
	$self->TableSpec_cnf({});
	$self->TableSpec_built_cnf(undef);
	
	# Just doing this to ensure we're initialized:
	$self->TableSpec_set_conf( apply_TableSpec_timestamp => time );
	
	return $self;
}

sub create_result_TableSpec {
	my $self = shift;
	my $ResultClass = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $TableSpec = RapidApp::TableSpec->new( 
		name => $ResultClass->table,
		%opt
	);
	
	my $data_types = $self->TableSpec_data_type_profiles;
	
	foreach my $col ($ResultClass->columns) {
		my $info = $ResultClass->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile; 
		
		$TableSpec->add_columns( { name => $col, profiles => \@profiles } ); 
	}
	
	return $TableSpec;
}


sub get_built_Cnf {
	my $self = shift;
	
	$self->TableSpec_build_cnf unless ($self->TableSpec_built_cnf);
	return $self->TableSpec_built_cnf;
}

sub TableSpec_build_cnf {
	my $self = shift;
	my %set_cnf = %{ $self->TableSpec_cnf || {} };
	$self->TableSpec_built_cnf($self->default_TableSpec_cnf(\%set_cnf));
}

sub default_TableSpec_cnf  {
	my $self = shift;
	my $set = shift || {};

	my $data = $set->{data} || {};
	my $order = $set->{order} || {};
	my $deref = $set->{deref} || {};

	my %defaults = ();
	$defaults{iconCls} = $data->{singleIconCls} if ($data->{singleIconCls} and ! $data->{iconCls});
	$defaults{iconCls} = $defaults{iconCls} || $data->{iconCls} || 'icon-application-view-detail';
	$defaults{multiIconCls} = $data->{multiIconCls} || 'icon-database_table';
	$defaults{singleIconCls} = $data->{singleIconCls} || $defaults{iconCls};
	$defaults{title} = $data->{title} || $self->table;
	$defaults{title_multi} = $data->{title_multi} || $defaults{title};
	($defaults{display_column}) = $self->primary_columns;
	
	my @display_columns = $data->{display_column} ? ( $data->{display_column} ) : $self->primary_columns;

	# row_display coderef overrides display_column to provide finer grained display control
	my $orig_row_display = $data->{row_display} || sub {
		my $record = $_;
		my $title = join('/',map { $record->{$_} || '' } @display_columns);
		$title = sprintf('%.13s',$title) . '...' if (length $title > 13);
		return $title;
	};
	
	$defaults{row_display} = sub {
		my $display = $orig_row_display->(@_);
		return $display if (ref $display);
		return {
			title => $display,
			iconCls => $defaults{singleIconCls}
		};
	};
	
	my $rel_trans = {};
	
	#foreach my $rel ( $class->storage->schema->source($class)->relationships ) {
	#	my $info = $class->relationship_info($rel);
	#	$rel_trans->{$rel}->{editor} = sub {''} unless ($info->{attr}->{accessor} eq 'single');
	#}
	$defaults{related_column_property_transforms} = $rel_trans;
	
	my $defs = { data => \%defaults };
	
	my $col_cnf = $self->default_TableSpec_cnf_columns($set);
	$defs = merge($defs,$col_cnf);

	return merge($defs, $set);
}

sub default_TableSpec_cnf_columns {
	my $self = shift;
	my $set = shift || {};

	my $data = $set->{data} || {};
	my $order = $set->{order} || {};
	my $deref = $set->{deref} || {};
	
	my @col_order = $self->default_TableSpec_cnf_column_order($set);
	
	my $cols = { map { $_ => {} } @col_order };

	$cols = merge($cols,$set->{data}->{column_properties_ordered} || {});
		
	# higher precidence:
	$cols = merge($cols,$set->{data}->{column_properties} || {});

	my $data_types = $self->TableSpec_data_type_profiles;
	#scream(keys %$cols);
	
	foreach my $col (keys %$cols) {
		
		unless ($self->has_column($col)) {
			# is it a rel col ?
			if($self->has_relationship($col)) {
				my $info = $self->relationship_info($col);
				
				$cols->{$col}->{relationship_info} = $info;
				my $cond_data = $self->parse_relationship_cond($info->{cond});
				$cols->{$col}->{relationship_cond_data} = { %$cond_data, %$info };
				
				if ($info->{attrs}->{accessor} eq 'single') {
					
					# Use TableSpec_related_get_set_conf instead of TableSpec_related_get_conf
					# to prevent possible deep recursion:
					$cols->{$col}->{displayField} = $self->TableSpec_related_get_set_conf($col,'display_column')
						or die "$col doesn't have display_column set!";
					
					#TODO: needs to be more generalized/abstracted
					#open_url, if defined, will add an autoLoad link to the renderer to
					#open/navigate to the related item
					$cols->{$col}->{open_url} = $self->TableSpec_related_get_set_conf($col,'open_url');
						
					
					$cols->{$col}->{valueField} = $cond_data->{foreign} 
						or die "couldn't get foreign col condition data for $col relationship!";
					
					$cols->{$col}->{auto_editor_type} = 'combo';
					$cols->{$col}->{keyField} = $cond_data->{self}
						or die "couldn't get self col condition data for $col relationship!";
					
					next;
				}
				elsif($info->{attrs}->{accessor} eq 'multi') {
					$cols->{$col}->{title_multi} = $self->TableSpec_related_get_set_conf($col,'title_multi');
					$cols->{$col}->{multiIconCls} = $self->TableSpec_related_get_set_conf($col,'multiIconCls');
					$cols->{$col}->{open_url_multi} = $self->TableSpec_related_get_set_conf($col,'open_url_multi');
					
					$cols->{$col}->{open_url_multi_rs_join_name} = 
						$self->TableSpec_related_get_set_conf($col,'open_url_multi_rs_join_name') || 'me';
				}
			}
			next;
		}
		
		
		my $info = $self->column_info($col);
		my @profiles = ();
			
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile;
		
		$cols->{$col}->{profiles} = [ $cols->{$col}->{profiles} ] if (
			defined $cols->{$col}->{profiles} and 
			not ref $cols->{$col}->{profiles}
		);
		push @profiles, @{$cols->{$col}->{profiles}} if ($cols->{$col}->{profiles});
		
		$cols->{$col}->{profiles} = \@profiles
	}
	
	return {
		data => { columns => $cols },
		order => { columns => \@col_order }
	};
}

sub TableSpec_valid_db_columns {
	my $self = shift;
	
	my @single_rels = ();
	my @multi_rels = ();
	
	my %fk_cols = ();
	
	foreach my $rel ($self->relationships) {
		my $info = $self->relationship_info($rel);
		if($info->{attrs}->{accessor} eq 'single') {
			push @single_rels, $rel;
			
			my ($fk) = keys %{$info->{attrs}->{fk_columns}};
			$fk_cols{$fk} = $rel;
		}
		elsif($info->{attrs}->{accessor} eq 'multi') {
			push @multi_rels, $rel;
		
		}
		# TODO: what about other types? 'filter' ?
	
	}
	
	$self->TableSpec_set_conf('relationship_column_names',\@single_rels);
	$self->TableSpec_set_conf('multi_relationship_column_names',\@multi_rels);
	$self->TableSpec_set_conf('relationship_column_fks_map',\%fk_cols);
	
	return uniq($self->columns,@single_rels,@multi_rels);
}

sub default_TableSpec_cnf_column_order {
	my $self = shift;
	my $set = shift || {};
	
	my @order = ();
	push @order, @{ $self->TableSpec_get_conf('column_properties_ordered',$set) || [] };
	#push @order, $self->columns;
	push @order, $self->TableSpec_valid_db_columns; # <-- native dbic column order has precidence over the column_properties order
	push @order, @{ $self->TableSpec_get_conf('column_properties',$set) || [] };
		
	# fold together removing duplicates:
	@order = uniq @order;
	
	my $ovrs = $self->TableSpec_get_conf('column_order_overrides',$set) or return @order;
	foreach my $ord (@$ovrs) {
		my ($offset,$cols) = @$ord;
		my %colmap = map { $_ => 1 } @$cols;
		# remove colnames to be ordered differently:
		@order = grep { !$colmap{$_} } @order;
		
		# If the offset is a column name prefixed with + (after) or - (before)
		$offset =~ s/^([\+\-])//;
		if($1) {
			my $i = 0;
			my $ndx = 0; # <-- default before (will become 0 below)
			$ndx = scalar @order if ($1 eq '+'); # <-- default after
			for my $col (@order) {
				$ndx = $i and last if ($col eq $offset);
				$i++;
			}
			$ndx++ if ($1 eq '+' and $ndx > 0);
			$offset = $ndx;
		}

		$offset = scalar @order if ($offset > scalar @order);
		splice(@order,$offset,0,@$cols);
	}
	
	return uniq @order;
}


# List of specific param names that we know should be hash confs:
my %hash_conf_params = map {$_=>1} qw(
column_properties
column_properties_ordered
relationship_columns
related_column_property_transforms
column_order_overrides
);

sub TableSpec_set_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $value = shift || die "TableSpec_set_conf(): missing value for param '$param'";
	
	$self->TableSpec_built_cnf(undef);
	
	return $self->TableSpec_set_hash_conf($param,$value,@_) 
		if($hash_conf_params{$param} and @_ > 0);
		
	$self->TableSpec_cnf->{data}->{$param} = $value;
	delete $self->TableSpec_cnf->{order}->{$param};
	
	return $self->TableSpec_set_conf(@_) if (@_ > 0);
	return 1;
}

# Stores arbitrary hashes, preserving their order
sub TableSpec_set_hash_conf {
	my $self = shift;
	my $param = shift;
	
	return $self->TableSpec_set_conf($param,@_) if (@_ == 1); 
	
	$self->TableSpec_built_cnf(undef);
	
	my %opt = get_mixed_hash_args_ordered(@_);
	
	my $i = 0;
	my $order = [ grep { ++$i & 1 } @_ ]; #<--get odd elements (keys)
	
	my $data = \%opt;
	
	$self->TableSpec_cnf->{data}->{$param} = $data;
	$self->TableSpec_cnf->{order}->{$param} = $order;
}

# Sets a reference value with flag to dereference on TableSpec_get_conf
sub TableSpec_set_deref_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $value = shift || die "TableSpec_set_deref_conf(): missing value for param '$param'";
	die "TableSpec_set_deref_conf(): value must be a SCALAR, HASH, or ARRAY ref" unless (
		ref($value) eq 'HASH' or
		ref($value) eq 'ARRAY' or
		ref($value) eq 'SCALAR'
	);
	
	$self->TableSpec_cnf->{deref}->{$param} = 1;
	my $ret = $self->TableSpec_set_conf($param,$value);

	return $self->TableSpec_set_deref_conf(@_) if (@_ > 0);
	return $ret;
}

sub TableSpec_get_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $storage = shift || $self->get_built_Cnf;
	
	return $self->TableSpec_get_hash_conf($param,$storage) if ($storage->{order}->{$param});
	
	my $data = $storage->{data}->{$param};
	return deref($data) if ($storage->{deref}->{$param});
	return $data;
}

sub TableSpec_get_hash_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $storage = shift || $self->get_built_Cnf;
	
	my $data = $storage->{data}->{$param};
	my $order = $storage->{order}->{$param};
	
	ref($data) eq 'HASH' or
		die "FATAL: Unexpected data! '$param' has a stored order, but it's data is not a HashRef!";
		
	ref($order) eq 'ARRAY' or
		die "FATAL: Unexpected data! '$param' order is not an ArrayRef!";
		
	my %order_indx = map {$_=>1} @$order;
	
	!$order_indx{$_} and
		die "FATAL: Unexpected data! param '$param' - found key '$_' missing from stored order!"
			for (keys %$data);
			
	!$data->{$_} and
		die "FATAL: Unexpected data! param '$param' - missing declared ordered key '$_' from data!"
			for (@$order);
	
	return map { $_ => $data->{$_} } @$order;
}

sub TableSpec_has_conf {
	my $self = shift;
	my $param = shift;
	my $storage = shift || $self->get_built_Cnf;
	return 1 if (exists $storage->{data}->{$param});
	return 0;
}


sub TableSpec_related_class {
	my $self = shift;
	my $rel = shift || return undef;
	my $info = $self->relationship_info($rel) || return undef;
	my $relclass = $info->{class};
	
	eval "require $relclass;";
	
	#my $relclass = $self->related_class($rel) || return undef;
	$relclass->can('TableSpec_get_conf') || return undef;
	return $relclass;
}

# Gets a TableSpec conf param, if exists, from a related Result Class
sub TableSpec_related_get_conf {
	my $self = shift;
	my $rel = shift || return undef;
	my $param = shift || return undef;
	
	my $relclass = $self->TableSpec_related_class($rel) || return undef;

	return $relclass->TableSpec_get_conf($param);
}

# Gets a TableSpec conf param, if exists, from a related Result Class,
# but uses the already 'set' params in TableSpec_cnf as storage, so that
# get_built_cnf doesn't get called.
sub TableSpec_related_get_set_conf {
	my $self = shift;
	my $rel = shift || return undef;
	my $param = shift || return undef;
	
	my $relclass = $self->TableSpec_related_class($rel) || return undef;

	return $relclass->TableSpec_get_conf($param,$relclass->TableSpec_cnf);
}

# TODO: Find a better way to handle this. Is there a real API
# in DBIC to find this information?
sub get_foreign_column_from_cond {
	my $self = shift;
	my $cond = shift;
	
	die "currently only single-key hashref conditions are supported" unless (
		ref($cond) eq 'HASH' and
		scalar keys %$cond == 1
	);
	
	foreach my $i (%$cond) {
		my ($side,$col) = split(/\./,$i);
		return $col if (defined $col and $side eq 'foreign');
	}
	
	die "Failed to find forein column from condition: " . Dumper($cond);
}

# TODO: Find a better way to handle this. Is there a real API
# in DBIC to find this information?
sub parse_relationship_cond {
	my $self = shift;
	my $cond = shift;
	
	my $data = {};
	
	die "currently only single-key hashref conditions are supported" unless (
		ref($cond) eq 'HASH' and
		scalar keys %$cond == 1
	);
	
	foreach my $i (%$cond) {
		my ($side,$col) = split(/\./,$i);
		$data->{$side} = $col;
	}
	
	return $data;
}

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
	my $fk_map = $self->TableSpec_get_conf('relationship_column_fks_map');
	foreach my $col (@changed) {
		unless($fk_map->{$col}) {
			push @new_changed, $col;
			next;
		}
		
		my $rel = $fk_map->{$col};
		my $display_col = $self->TableSpec_related_get_set_conf($rel,'display_column');
		
		my $relOld = $origRow->$rel;
		my $relNew = $self->$rel;
		
		unless($display_col and ($relOld or $relNew)) {
			push @new_changed, $col;
			next;
		}
		
		push @new_changed, $rel;
		
		$old{$rel} = $relOld->get_column($display_col) if (exists $old{$col} and $relOld);
		$new{$rel} = $relNew->get_column($display_col) if (exists $new{$col} and $relNew);
	}
	
	@changed = @new_changed;
	
	my $col_props = { $self->TableSpec_get_conf('columns') };
	
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


=pod
sub TableSpec_set_conf_column_order {
	my $self = shift;
	my $offset = $_[0];
	die "TableSpec_set_column_order(): expected offset/index number in first arg (got '$offset')" unless (
		defined $offset and
		$offset =~ /^\d+$/
	);
	return $self->TableSpec_set_conf_column_order_base(@_);
}

# Like TableSpec_set_conf_column_order but the offset is the name of another column
sub TableSpec_set_conf_column_order_after {
	my $self = shift;
	my $colname = shift;
	return $self->TableSpec_set_conf_column_order_base('+' . $colname,@_);
}

# Like TableSpec_set_conf_column_order but the offset is the name of another column
sub TableSpec_set_conf_column_order_before {
	my $self = shift;
	my $colname = shift;
	return $self->TableSpec_set_conf_column_order_base('-' . $colname,@_);
}

# Can be called over and over again to apply and re-apply
sub TableSpec_set_conf_column_order_base {
	my $self = shift;
	my $offset = shift;
	my @cols = @_;
	@cols = $_[0] if (ref($_[0]));
	die "TableSpec_set_column_order(): no column names supplied" unless (@cols > 0);
	
	$self->TableSpec_cnf->{column_order_overrides}->{data} = [] 
		unless ($self->TableSpec_cnf->{column_order_overrides}->{data});
		
	push @{$self->TableSpec_cnf->{column_order_overrides}->{data}}, [$offset,\@cols];
}
=cut



sub related_TableSpec {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
	my $class = $info->{class};
	
	# Manually load and initialize the TableSpec component if it's missing from the
	# related result class:
	unless($class->can('TableSpec')) {
		$class->load_components('+RapidApp::DBIC::Component::TableSpec');
		$class->apply_TableSpec(%opt);
	}
	
	return $class->TableSpec;
}




sub TableSpec_add_columns_from_related {
	my $self = shift;
	my $rels = get_mixed_hash_args(@_);
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		$conf->{column_property_transforms}->{name} = sub { $rel . '_' . $_ };
		
		# If its a relationship column that will setup a combo:
		$conf->{column_property_transforms} = { %{$conf->{column_property_transforms}},
			key_col => sub { $rel . '_' . $_ },
			render_col => sub { $rel . '_' . $_ },
		};
		
		my $info = $self->relationship_info($rel) or next;
		
		# Make sure the related class is already loaded:
		eval 'use ' . $info->{class};
		die $@ if ($@);
		
		my $TableSpec = $info->{class}->TableSpec->copy($conf) or next;
		
		my @added = $self->TableSpec->add_columns_from_TableSpec($TableSpec);
		foreach my $Column (@added) {
			$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
			push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
			
			# Add a new global_init_coderef entry if this column has one:
			rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } ) 
				if ($Column->rapidapp_init_coderef);
		}
	}
}




sub TableSpec_add_relationship_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	
	# Moved to TableSpec::Role::DBIC
	#return;
	
	
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		die "displayField is required" unless (defined $conf->{displayField});
		
		$conf->{render_col} = $rel . '_' . $conf->{displayField} unless ($conf->{render_col});
		
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		$conf->{foreign_col} = $self->get_foreign_column_from_cond($info->{cond});
		$conf->{valueField} = $conf->{foreign_col} unless (defined $conf->{valueField});
		$conf->{key_col} = $rel . '_' . $conf->{valueField};
		
		#Temporary/initial column setup:
		$self->TableSpec->add_columns({ name => $rel, %$conf });
		my $Column = $self->TableSpec->get_column($rel);
		
		#$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
		#push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
		
		# Temp placeholder:
		$Column->set_properties({ editor => 'relationship_column' });
		
		my $ResultClass = $self;
		
		$Column->rapidapp_init_coderef( sub {
			my $self = shift;
			
			my $rootModule = shift;
			$rootModule->apply_init_modules( tablespec => 'RapidApp::AppBase' ) 
				unless ( $rootModule->has_module('tablespec') );
			
			my $TableSpecModule = $rootModule->Module('tablespec');
			my $c = RapidApp::ScopedGlobals->get('catalystClass');
			my $Source = $c->model('DB')->source($info->{source});
			
			my $valueField = $self->get_property('valueField');
			my $displayField = $self->get_property('displayField');
			my $key_col = $self->get_property('key_col');
			my $render_col = $self->get_property('render_col');
			my $auto_editor_type = $self->get_property('auto_editor_type');
			my $rs_condition = $self->get_property('ResultSet_condition') || {};
			my $rs_attr = $self->get_property('ResultSet_attr') || {};
			
			my $editor = $self->get_property('editor') || {};
			
			my $column_params = {
				required_fetch_columns => [ 
					$key_col,
					$render_col
				],
				
				read_raw_munger => RapidApp::Handler->new( code => sub {
					my $rows = (shift)->{rows};
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						$row->{$self->name} = $row->{$key_col};
					}
				}),
				update_munger => RapidApp::Handler->new( code => sub {
					my $rows = shift;
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						if ($row->{$self->name}) {
							$row->{$key_col} = $row->{$self->name};
							delete $row->{$self->name};
						}
					}
				}),
				no_quick_search => \1,
				no_multifilter => \1
			};
			
			$column_params->{renderer} = jsfunc(
				'function(value, metaData, record, rowIndex, colIndex, store) {' .
					'return record.data["' . $render_col . '"];' .
				'}', $self->get_property('renderer')
			);
			
			# If editor is no longer set to the temp value 'relationship_column' previously set,
			# it means something else has set the editor, so we don't overwrite it:
			if ($editor eq 'relationship_column') {
				if ($auto_editor_type eq 'combo') {
				
					my $module_name = $ResultClass->table . '_' . $self->name;
					$TableSpecModule->apply_init_modules(
						$module_name => {
							class	=> 'RapidApp::DbicAppCombo2',
							params	=> {
								valueField		=> $valueField,
								displayField	=> $displayField,
								name				=> $self->name,
								ResultSet		=> $Source->resultset,
								RS_condition	=> $rs_condition,
								RS_attr			=> $rs_attr,
								record_pk		=> $valueField
							}
						}
					);
					my $Module = $TableSpecModule->Module($module_name);
					
					# -- vv -- This is required in order to get all of the params applied
					$Module->call_ONREQUEST_handlers;
					$Module->DataStore->call_ONREQUEST_handlers;
					# -- ^^ --
					
					$column_params->{editor} = { %{ $Module->content }, %$editor };
				}
			}
			
			$self->set_properties({ %$column_params });
		});
		
		# This coderef gets called later, after the RapidApp
		# Root Module has been loaded.
		rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } );
	}
}




1;__END__
