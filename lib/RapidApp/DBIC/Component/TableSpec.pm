package RapidApp::DBIC::Component::TableSpec;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class');

use Sub::Name qw/subname/;

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

#__PACKAGE__->load_components(qw/IntrospectableM2M/);

__PACKAGE__->load_components('+RapidApp::DBIC::Component::VirtualColumnsExt');

__PACKAGE__->mk_classdata( 'TableSpec' );
__PACKAGE__->mk_classdata( 'TableSpec_rel_columns' );

__PACKAGE__->mk_classdata( 'TableSpec_cnf' );
__PACKAGE__->mk_classdata( 'TableSpec_built_cnf' );

# See default profile definitions in RapidApp::TableSpec::Column
my $default_data_type_profiles = {
	text 		=> [ 'bigtext' ],
	blob 		=> [ 'bigtext' ],
	varchar 	=> [ 'text' ],
	char 		=> [ 'text' ],
	float		=> [ 'number' ],
	integer		=> [ 'number', 'int' ],
	tinyint		=> [ 'number', 'int' ],
	mediumint	=> [ 'number', 'int' ],
	bigint		=> [ 'number', 'int' ],
	decimal		=> [ 'number', 'int' ],
	datetime	=> [ 'datetime' ],
	timestamp	=> [ 'datetime' ],
	date		=> [ 'date' ],
};
__PACKAGE__->mk_classdata( 'TableSpec_data_type_profiles' );
__PACKAGE__->TableSpec_data_type_profiles({ %$default_data_type_profiles }); 


## Sets up many_to_many along with TableSpec m2m multi-relationship column
sub TableSpec_m2m {
	my $self = shift;
	my ($m2m,$local_rel,$remote_rel) = @_;
	
	$self->is_TableSpec_applied and 
		die "TableSpec_m2m must be called before apply_TableSpec!";
		
	$self->has_column($m2m) and die "'$m2m' is already defined as a column.";
	$self->has_relationship($m2m) and die "'$m2m' is already defined as a relationship.";

	my $rinfo = $self->relationship_info($local_rel) or die "'$local_rel' relationship not found";
	eval('require ' . $rinfo->{class});
	
	die "m2m bridge relationship '$local_rel' is not a multi relationship"
		unless ($rinfo->{attrs}->{accessor} eq 'multi');
		
	my $rrinfo = $rinfo->{class}->relationship_info($remote_rel);
	eval('require ' . $rrinfo->{class});
	
	$rinfo->{table} = $rinfo->{class}->table;
	$rrinfo->{table} = $rrinfo->{class}->table;
	
	$rinfo->{cond_info} = $self->parse_relationship_cond($rinfo->{cond});
	$rrinfo->{cond_info} = $self->parse_relationship_cond($rrinfo->{cond});
	
	# 
	#my $sql = '(' .
	#	# SQLite Specific:
	#	#'SELECT(GROUP_CONCAT(flags.flag,", "))' .
	#	
	#	# MySQL Sepcific:
	#	#'SELECT(GROUP_CONCAT(flags.flag SEPARATOR ", "))' .
	#	
	#	# Generic (MySQL & SQLite):
	#	'SELECT(GROUP_CONCAT(`' . $rrinfo->{table} . '`.`' . $rrinfo->{cond_info}->{foreign} . '`))' .
	#	
	#	' FROM `' . $rinfo->{table} . '`' . 
	#	' JOIN `' . $rrinfo->{table} . '` `' . $rrinfo->{table} . '`' .
	#	'  ON `' . $rinfo->{table} . '`.`' . $rrinfo->{cond_info}->{self} . '`' .
	#	'   = `' . $rrinfo->{table} . '`.`' . $rrinfo->{cond_info}->{foreign} . '`' .
	#	#' ON customers_to_flags.flag = flags.flag' .
	#	' WHERE `' . $rinfo->{cond_info}->{foreign} . '` = ' . $rel . '.' . $cond_data->{self} . 
	#')';

	# Create a relationship exactly like the the local bridge relationship, adding
	# the 'm2m_attrs' attribute which will be used later on to setup the special, 
	# m2m-specific multi-relationship column properties (renderer, editor, and to 
	# trigger proxy m2m updates in DbicLink2):
	$self->add_relationship(
		$m2m,
		$rinfo->{class},
		$rinfo->{cond},
		{%{$rinfo->{attrs}}, m2m_attrs => {
			remote_rel => $remote_rel,
			rinfo => $rinfo,
			rrinfo => $rrinfo
		}}
	);
	
	# -- Add a normal many_to_many bridge so we have the many_to_many sugar later on:
	# (we use 'set_$rel' in update_records in DbicLink2)
	local $ENV{DBIC_OVERWRITE_HELPER_METHODS_OK} = 1 
		unless (exists $ENV{DBIC_OVERWRITE_HELPER_METHODS_OK});
	$self->many_to_many(@_);
	#$self->apply_m2m_sugar(@_);
	# --
}

## sugar copied from many_to_many (DBIx::Class::Relationship::ManyToMany), 
## but only sets up add_$rel and set_$rel and won't overwrite existing subs (safer)
#sub apply_m2m_sugar {
#	my ($class, $meth, $rel, $f_rel, $rel_attrs) = @_;
#
#	my $set_meth = "set_${meth}";
#	my $add_meth = "add_${meth}";
#	
#	$class->can($set_meth) and 
#		die "m2m: set method '$set_meth' is already defined in (" . ref($class) . ")";
#		
#	$class->can($add_meth) and 
#		die "m2m: add method '$add_meth' is already defined in (" . ref($class) . ")";
#	
#    my $add_meth_name = join '::', $class, $add_meth;
#    *$add_meth_name = subname $add_meth_name, sub {
#      my $self = shift;
#      @_ > 0 or $self->throw_exception(
#        "${add_meth} needs an object or hashref"
#      );
#      my $source = $self->result_source;
#      my $schema = $source->schema;
#      my $rel_source_name = $source->relationship_info($rel)->{source};
#      my $rel_source = $schema->resultset($rel_source_name)->result_source;
#      my $f_rel_source_name = $rel_source->relationship_info($f_rel)->{source};
#      my $f_rel_rs = $schema->resultset($f_rel_source_name)->search({}, $rel_attrs||{});
#
#      my $obj;
#      if (ref $_[0]) {
#        if (ref $_[0] eq 'HASH') {
#          $obj = $f_rel_rs->find_or_create($_[0]);
#        } else {
#          $obj = $_[0];
#        }
#      } else {
#        $obj = $f_rel_rs->find_or_create({@_});
#      }
#
#      my $link_vals = @_ > 1 && ref $_[$#_] eq 'HASH' ? pop(@_) : {};
#      my $link = $self->search_related($rel)->new_result($link_vals);
#      $link->set_from_related($f_rel, $obj);
#      $link->insert();
#      return $obj;
#    };
#	
#	my $set_meth_name = join '::', $class, $set_meth;
#    *$set_meth_name = subname $set_meth_name, sub {
#		my $self = shift;
#		@_ > 0 or $self->throw_exception(
#			"{$set_meth} needs a list of objects or hashrefs"
#		);
#		my @to_set = (ref($_[0]) eq 'ARRAY' ? @{ $_[0] } : @_);
#		# if there is a where clause in the attributes, ensure we only delete
#		# rows that are within the where restriction
#		if ($rel_attrs && $rel_attrs->{where}) {
#			$self->search_related( $rel, $rel_attrs->{where},{join => $f_rel})->delete;
#		} else {
#			$self->search_related( $rel, {} )->delete;
#		}
#		# add in the set rel objects
#		$self->$add_meth($_, ref($_[1]) ? $_[1] : {}) for (@to_set);
#	};
#}
## --

sub is_TableSpec_applied {
	my $self = shift;
	return (
		defined $self->TableSpec_cnf and
		defined $self->TableSpec_cnf->{data} and
		defined $self->TableSpec_cnf->{data}->{apply_TableSpec_timestamp}
	);
}

sub apply_TableSpec {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# ignore/return if apply_TableSpec has already been called:
	return if $self->is_TableSpec_applied;
	
	# make sure _virtual_columns and _virtual_columns_order get initialized
	$self->add_virtual_columns();

	
	$self->TableSpec_data_type_profiles(
		%{ $self->TableSpec_data_type_profiles || {} },
		%{ delete $opt{TableSpec_data_type_profiles} }
	) if ($opt{TableSpec_data_type_profiles});
	
	$self->TableSpec($self->create_result_TableSpec($self,%opt));
	
	$self->TableSpec_rel_columns({});
	$self->TableSpec_cnf({});
	$self->TableSpec_built_cnf(undef);
	
	$self->apply_row_methods();
	
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
	
	## WARNING! This logic overlaps with logic further down (in default_TableSpec_cnf_columns)
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
	$defaults{iconCls} = $defaults{iconCls} || $data->{iconCls} || 'icon-pg';
	$defaults{multiIconCls} = $data->{multiIconCls} || 'icon-pg-multi';
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
	
	# lowest precidence:
	$cols = merge($cols,$set->{data}->{column_properties_defaults} || {});

	$cols = merge($cols,$set->{data}->{column_properties_ordered} || {});
		
	# higher precidence:
	$cols = merge($cols,$set->{data}->{column_properties} || {});

	my $data_types = $self->TableSpec_data_type_profiles;
	#scream(keys %$cols);
	
	foreach my $col (keys %$cols) {
		
		my $is_local = $self->has_column($col) ? 1 : 0;
		
		# If this is both a local column and a relationship, allow the rel to take over
		# if 'priority_rel_columns' is true:
		$is_local = 0 if (
			$is_local and
			$self->has_relationship($col) and
			$set->{data}->{'priority_rel_columns'}
		);
		
		# -- If priority_rel_columns is on but we need to exclude a specific column:
		$is_local = 1 if (
			! $is_local and
			$set->{data}->{no_priority_rel_column} and
			$set->{data}->{no_priority_rel_column}->{$col} and
			$self->has_column($col)
		);
		# --
		
		# Never allow a rel col to take over a primary key:
		my %pri_cols = map {$_=>1} $self->primary_columns;
		$is_local = 1 if ($pri_cols{$col});
		
		unless ($is_local) {
			# is it a rel col ?
			if($self->has_relationship($col)) {
				my $info = $self->relationship_info($col);
				
				$cols->{$col}->{relationship_info} = $info;
				my $cond_data = $self->parse_relationship_cond($info->{cond});
				$cols->{$col}->{relationship_cond_data} = { %$cond_data, %$info };
				
				if ($info->{attrs}->{accessor} eq 'single' || $info->{attrs}->{accessor} eq 'filter') {
					
					# Use TableSpec_related_get_set_conf instead of TableSpec_related_get_conf
					# to prevent possible deep recursion:
					
					my $display_column = $self->TableSpec_related_get_set_conf($col,'display_column');
					my $display_columns = $self->TableSpec_related_get_set_conf($col,'display_columns');
					
					# -- auto_editor_params/auto_editor_type can be defined in either the local column 
					# properties, or the remote TableSpec conf
					my $auto_editor_type = $self->TableSpec_related_get_set_conf($col,'auto_editor_type') || 'combo';
					my $auto_editor_params = $self->TableSpec_related_get_set_conf($col,'auto_editor_params') || {};
					my $auto_editor_win_params = $self->TableSpec_related_get_set_conf($col,'auto_editor_win_params') || {};
					$cols->{$col}->{auto_editor_type} = $cols->{$col}->{auto_editor_type} || $auto_editor_type;
					$cols->{$col}->{auto_editor_params} = $cols->{$col}->{auto_editor_params} || {};
					$cols->{$col}->{auto_editor_params} = { 
						%$auto_editor_params, 
						%{$cols->{$col}->{auto_editor_params}} 
					};
					# --
					
					$display_column = $display_columns->[0] if (
						! defined $display_column and
						ref($display_columns) eq 'ARRAY' and
						@$display_columns > 0
					);
					
					## fall-back set the display_column to the first key
					($display_column) = $self->primary_columns unless ($display_column);
					
					$display_columns = [ $display_column ] if (
						! defined $display_columns and
						defined $display_column
					);
					
					die "$col doesn't have display_column or display_columns set!" unless ($display_column);
					
					$cols->{$col}->{displayField} = $display_column;
					$cols->{$col}->{display_columns} = $display_columns; #<-- in progress - used for grid instead of combo
					
					#TODO: needs to be more generalized/abstracted
					#open_url, if defined, will add an autoLoad link to the renderer to
					#open/navigate to the related item
					$cols->{$col}->{open_url} = $self->TableSpec_related_get_set_conf($col,'open_url');
						
					$cols->{$col}->{valueField} = $cond_data->{foreign} 
						or die "couldn't get foreign col condition data for $col relationship!";
					
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
		
		## WARNING! This logic overlaps with logic further up (in create_result_TableSpec)
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
		
		$cols->{$col}->{profiles} = \@profiles;
		
		## --
		my $editor = {};
	
		## Set the 'default' field value to match the default from the db (if exists) for this column:
		$editor->{value} = $info->{default_value} if (exists $info->{default_value});
		
		## This sets additional properties of the editor for numeric type columns according
		## to the DBIC schema (max-length, signed/unsigned, float vs int). The API with "profiles" 
		## didn't anticipate this fine-grained need, so 'extra_properties' was added specifically 
		## to accomidate this (see special logic in TableSpec::Column):
		## note: these properties only apply if the editor xtype is 'numberfield' which we assume,
		## and is already set from the profiles of 'decimal', 'float', etc
		my $unsigned = ($info->{extra} && $info->{extra}->{unsigned}) ? 1 : 0;
		$editor->{allowNegative} = \0 if ($unsigned);
		
		if($info->{size}) {
			my $size = $info->{size};
			
			# Special case for 'float'/'decimal' with a specified precision (where 0 is the same as int):
			if(ref $size eq 'ARRAY' ) {
				my ($s,$p) = @$size;
				$size = $s;
				$editor->{maxValue} = ('9' x $s);
				$size += 1 unless ($unsigned); #<-- room for a '-'
				if ($p && $p > 0) {
					$editor->{maxValue} .= '.' . ('9' x $p);
					$size += $p + 1 ; #<-- precision plus a spot for '.' in the max field length	
					$editor->{decimalPrecision} = $p;
				}
				else {
					$editor->{allowDecimals} = \0;
				}
				$edit
			}
			$editor->{maxLength} = $size;
		}
		
		if(keys %$editor > 0) {
			$cols->{$col}->{extra_properties} = $cols->{$col}->{extra_properties} || {};
			$cols->{$col}->{extra_properties} = merge($cols->{$col}->{extra_properties},{
				editor => $editor
			});
		}
		## -- 
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
	my %pri_cols = map {$_=>1} $self->primary_columns;
	
	foreach my $rel ($self->relationships) {
		my $info = $self->relationship_info($rel);
		
		my $accessor = $info->{attrs}->{accessor};
		
		# 'filter' means single, but the name is also a local column
		$accessor = 'single' if (
			$accessor eq 'filter' and
			$self->TableSpec_cnf->{data}->{'priority_rel_columns'} and
			!(
				$self->TableSpec_cnf->{data}->{'no_priority_rel_column'} and
				$self->TableSpec_cnf->{data}->{'no_priority_rel_column'}->{$rel}
			) and
			! $pri_cols{$rel} #<-- exclude primary column names. TODO: this check is performed later, fix
		);
		
		if($accessor eq 'single') {
			push @single_rels, $rel;
			
			my ($fk) = keys %{$info->{attrs}->{fk_columns}};
			$fk_cols{$fk} = $rel if($fk);
		}
		elsif($accessor eq 'multi') {
			push @multi_rels, $rel;
		}
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
column_properties_defaults
relationship_columns
related_column_property_transforms
column_order_overrides
);

sub TableSpec_set_conf {
	my $self = shift;
	my $param = shift || return undef;
	my $value = shift;# || die "TableSpec_set_conf(): missing value for param '$param'";
	
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

	#return $relclass->TableSpec_get_conf($param,$relclass->TableSpec_cnf);
	return $relclass->TableSpec_get_set_conf($param);
}

# The "set conf" is different from the "built conf" in that it is passive, and only
# returns the values which have been expressly "set" on the Result class with a 
# "TableSpec_set_conf" call. The built conf reaches out to code to build a configuration,
# which causes recursive limitations in that code that reaches out to other TableSpec
# classes.
sub TableSpec_get_set_conf {
	my $self = shift;
	my $param = shift || return undef;
	return $self->TableSpec_get_conf($param,$self->TableSpec_cnf);
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


sub getOpenUrl {
	my $self = shift;
	return $self->TableSpec_get_conf('open_url');
}

### Util functions: to be called in Row-object context
sub apply_row_methods {
	my $class = shift;
	
	my %RowMethods = (
	
		getOpenUrl => sub { $class->TableSpec_get_conf('open_url') },
	
		getRecordPkValue => sub {
			my $self = shift;
			my @pk_vals = map { $self->get_column($_) } $self->primary_columns;
			return join('~$~',@pk_vals);
		},
		
		getRestKeyVal => sub {
			my $self = shift;
			my $rest_key_col = $class->TableSpec_get_conf('rest_key_column');
			return $self->get_column($rest_key_col) if ($self->has_column($rest_key_col));
			return $self->getRecordPkValue;
		},
		
		getRestPath => sub {
			my $self = shift;
			my $url = $class->getOpenUrl or return undef;
			my $val = $self->getRestKeyVal or return undef;
			return "$url/$val";
		},
	
		getDisplayValue => sub {
			my $self = shift;
			my $display_column = $class->TableSpec_get_conf('display_column');
			return $self->get_column($display_column) if ($self->has_column($display_column));
			return $self->getRecordPkValue;
		},
		
		inlineNavLink => sub {
			my $self = shift;
			my $text = shift || '<span>open</span>';
			my %attrs = ( class => "magnify-link-tiny", @_ );

			my $title = $self->getDisplayValue or return undef;
			my $url = $self->getRestPath or return undef;
			
			%attrs = (
				href => '#!' . $url,
				title => $title,
				%attrs
			);
			
			my $attr_str = join(' ',map { $_ . '="' . $attrs{$_} . '"' } keys %attrs);
			return '<a ' . $attr_str . '>' . $text . '</a>';
		},

		displayWithLink => sub {
			my $self = shift;
			return $self->getDisplayValue . ' ' . $self->inlineNavLink;
		}
	);
	
	# --- Actualize/load methods into the Row object namespace:
	foreach my $meth (keys %RowMethods) {
		my $meth_name = join '::', $class, $meth;
		*$meth_name = subname $meth_name => $RowMethods{$meth};
	}
	# ---
}






### -- old, pre-rest inlineNavLink:
## This function creates links just like the JavaScript function Ext.ux.RapidApp.inlineLink
#use URI::Escape;
#sub inlineNavLink {
#	my $self = shift;
#	my $text = shift || '<span>open</span>';
#	my %attrs = ( class => "magnify-link-tiny", @_ );
#	my $loadCfg = delete $attrs{loadCfg} || {};
#	
#	my $title = $self->getDisplayValue || return undef;
#	my $url = $self->getOpenUrl || return undef;
#	my $pk_val = $self->getRecordPkValue || return undef;
#	
#	$loadCfg = merge({
#		title => $title,
#		autoLoad => {
#			url => $url,
#			params => { '___record_pk' => $pk_val }
#		}
#	},$loadCfg);
#	
#	my $href = '#loadcfg:data=' . uri_escape(encode_json($loadCfg));
#	my $onclick = 'return Ext.ux.RapidApp.InlineLinkHandler.apply(this,arguments);';
#	
#	%attrs = (
#		href => $href,
#		onclick => $onclick,
#		ondblclick => $onclick,
#		title => $title,
#		%attrs
#	);
#	
#	my $attr_str = join(' ',map { $_ . '="' . $attrs{$_} . '"' } keys %attrs);
#	
#	return '<a ' . $attr_str . '>' . $text . '</a>';
#
#}
#


1;
