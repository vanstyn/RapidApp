package RapidApp::DBIC::Component::TableSpec;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class');

use strict;
use warnings;

use Sub::Name qw/subname/;

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Util qw(:all);

use RapidApp::TableSpec;
use RapidApp::Module::DbicCombo;

#__PACKAGE__->load_components(qw/IntrospectableM2M/);

__PACKAGE__->load_components('+RapidApp::DBIC::Component::VirtualColumnsExt');

__PACKAGE__->mk_classdata( 'TableSpec' );
__PACKAGE__->mk_classdata( 'TableSpec_rel_columns' );

__PACKAGE__->mk_classdata( 'TableSpec_cnf' );
__PACKAGE__->mk_classdata( 'TableSpec_built_cnf' );

# See default profile definitions in RapidApp::TableSpec::Column
my $default_data_type_profiles = {
  text        => [ 'bigtext' ],
  mediumtext  => [ 'bigtext' ],
  longtext    => [ 'bigtext' ],
  tinytext    => [ 'text' ],
  smalltext   => [ 'text' ],
  varchar     => [ 'text' ],
  char        => [ 'text' ],
  nvarchar    => [ 'text' ],
  nchar       => [ 'text' ],
  float       => [ 'number' ],
  integer     => [ 'number', 'int' ],
  tinyint     => [ 'number', 'int' ],
  smallint    => [ 'number', 'int' ],
  mediumint   => [ 'number', 'int' ],
  bigint      => [ 'number', 'int' ],
  decimal     => [ 'number' ],
  numeric     => [ 'number' ],
  double      => [ 'number' ],
  'double precision' => [ 'number' ],
  datetime    => [ 'datetime' ],
  timestamp   => [ 'datetime' ],
  date        => [ 'date' ],
  blob        => [ 'blob' ],
  longblob    => [ 'blob' ],
  mediumblob  => [ 'blob' ],
  tinyblob    => [ 'blob' ],
  smallblob   => [ 'blob' ],
  binary      => [ 'blob' ],
  varbinary   => [ 'blob' ],
  year        => [ 'otherdate' ],
  tsvector    => [ 'bigtext','unsearchable','virtual_source' ], #<-- postgres-specific
  boolean     => ['bool'],
  ipaddr      => ['unsearchable'] #<-- postgres-specific
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
		defined $self->TableSpec_cnf->{apply_TableSpec_timestamp}
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
	
	# --- Set some base defaults here:
	my $table = $self->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
	my ($pri) = ($self->primary_columns,$self->columns); #<-- first primary col, or first col
	$self->TableSpec_set_conf(
		display_column => $pri,
		title => $table,
    
    # --
    # New: initialize the columns cnf key early. It doesn't even need all
    # the columns (just at least one -- we're just doing the base columns
    # and not bothering with relationships + virtual columns). This is
    # just about getting the Hash defined so that later calls will update
    # this hash rather than create a new one, which can get lost in certain
    # situations (such as a Result Class that loads the TableSpec component
    # in-line but does not apply any column configs). 
    # This was needed added after the recent prelim TableSpec_cnf refactor (in v0.99030)
    # which is a temp/in-between change that consolidates storage of column
    # configs internally while still preserving the original API for now. 
    # Yes, this is ugly/hackish but will go away as soon as the full-blown, 
    # long-planned TableSpec refactor is undertaken...
    columns => { map { $_ => {} } $self->columns }
    # --
	);
	# ---
	
	return $self;
}

sub create_result_TableSpec {
	my $self = shift;
	my $ResultClass = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $table = $ResultClass->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format

	my $TableSpec = RapidApp::TableSpec->new( 
		name => $table,
		%opt
	);

	my $data_types = $self->TableSpec_data_type_profiles;
	
	## WARNING! This logic overlaps with logic further down (in default_TableSpec_cnf_columns)
	foreach my $col ($ResultClass->columns) {
		my $info = $ResultClass->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
    push @profiles, 'autoinc' if ($info->{is_auto_increment});
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
    
    # -- PostgreSQL override until array columns are supported (Github Issue #55):
    $type_profile = ['unsearchable','virtual_source'] if (
      $info->{data_type} =~ /\[/ #<-- if the data_type contains a square backect, i.e. 'text[]'
    );
    # --
    
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

  my $data = $set;
	
	
	my $table = $self->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
  
  my $is_virtual = $self->_is_virtual_source;
  my $defs_i = $is_virtual ? 'ra-icon-pg-red' : 'ra-icon-pg';
  my $defm_i = $is_virtual ? 'ra-icon-pg-multi-red' : 'ra-icon-pg-multi';
	
	# FIXME: These defaults cannot be seen via call from related tablespec, because of
	# a circular logic situation. For base-defaults, see apply_TableSpec above
	# This is one of the reasons the whole TableSpec design needs to be refactored
	my %defaults = ();
	$defaults{iconCls} = $data->{singleIconCls} if ($data->{singleIconCls} and ! $data->{iconCls});
	$defaults{iconCls} = $defaults{iconCls} || $data->{iconCls} || $defs_i;
	$defaults{multiIconCls} = $data->{multiIconCls} || $defm_i;
	$defaults{singleIconCls} = $data->{singleIconCls} || $defaults{iconCls};
	$defaults{title} = $data->{title} || $table;
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
  
  
  #my $defs = \%defaults;
  #my $col_cnf = $self->default_TableSpec_cnf_columns($set);
  #$defs = merge($defs,$col_cnf);
  #return merge($defs, $set);  

  %defaults = ( %defaults, %$set );
  my $defs = \%defaults;
  my $col_cnf = $self->default_TableSpec_cnf_columns($defs);
  $defs->{columns} = $col_cnf->{columns};
  
  return $defs;
}

sub _is_virtual_source {
  my $self = shift;
  return (
    $self->result_source_instance->can('is_virtual') &&
    $self->result_source_instance->is_virtual
  );
}

sub default_TableSpec_cnf_columns {
	my $self = shift;
	my $set = shift || {};

  my $data = $set;
	
	my @col_order = $self->default_TableSpec_cnf_column_order($set);
	
	my $cols = { map { $_ => {} } @col_order };
  
  # lowest precidence:
  #$cols = merge($cols,$set->{column_properties_defaults} || {});
  %$cols = ( %$cols, %{ $set->{column_properties_defaults} || {}} );

  #$cols = merge($cols,$set->{column_properties_ordered} || {});
  %$cols = ( %$cols, %{ $set->{column_properties_ordered} || {}} );
		
	# higher precidence:
	#$cols = merge($cols,$set->{column_properties} || {});
  %$cols = ( %$cols, %{ $set->{column_properties} || {}} );
  
	my $data_types = $self->TableSpec_data_type_profiles;
	#scream(keys %$cols);
  
  my $is_virtual = $self->_is_virtual_source;
	
	foreach my $col (keys %$cols) {
		
		my $is_phy = $self->has_column($col) ? 1 : 0;
    $cols->{$col}{is_phy_colname} = $is_phy; #<-- track if this is also a physical column name

    my $is_local = $is_phy;
		
		# If this is both a local column and a relationship, allow the rel to take over
		# if 'priority_rel_columns' is true:
		$is_local = 0 if (
			$is_local and
			$self->has_relationship($col) and
			$set->{'priority_rel_columns'}
		);
		
		# -- If priority_rel_columns is on but we need to exclude a specific column:
		$is_local = 1 if (
			! $is_local and
			$set->{no_priority_rel_column} and
			$set->{no_priority_rel_column}->{$col} and
			$is_phy
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
					
          # -- NEW: Virtual Single Relationship - will be read-only
          unless($cond_data->{foreign} && $cond_data->{self}) {
            $cols->{$col}{virtualized_single_rel} = 1;
            $cols->{$col}{allow_add} = 0;
            $cols->{$col}{allow_edit} = 0;
            next;
          }
          # --
          
          # New: pass the is_nullable flag in from the local FK column:
          if($self->has_column($cond_data->{self})) {
            $cols->{$col}{is_nullable} = $self->column_info($cond_data->{self})
              ->{is_nullable} ? 1 : 0;
          }
          
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
        
        # New: add the 'relcol' profile to relationship columns:
        $cols->{$col}->{profiles} ||= [];
        push @{$cols->{$col}->{profiles}}, 'relcol';
        push @{$cols->{$col}->{profiles}}, 'virtual_source' if ($is_virtual);
        push @{$cols->{$col}->{profiles}}, 'multirel' if ($info->{attrs}->{accessor} eq 'multi');
			}
			next;
		}
		
		## WARNING! This logic overlaps with logic further up (in create_result_TableSpec) FIXME!
		my $info = $self->column_info($col);
		my @profiles = ();
			
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
    push @profiles, 'autoinc' if ($info->{is_auto_increment});
		
		my $type_profile = $data_types->{$info->{data_type}} || ['text'];
    
    # -- PostgreSQL override until array columns are supported (Github Issue #55):
    $type_profile = ['unsearchable','virtual_source'] if (
      $info->{data_type} =~ /\[/ #<-- if the data_type contains a square backect, i.e. 'text[]'
    );
    # --
    
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile;
		
		$cols->{$col}->{profiles} = [ $cols->{$col}->{profiles} ] if (
			defined $cols->{$col}->{profiles} and 
			not ref $cols->{$col}->{profiles}
		);
		push @profiles, @{$cols->{$col}->{profiles}} if ($cols->{$col}->{profiles});
    
    push @profiles, 'virtual_source' if ($is_virtual);
		
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
    
    # --vv-- NEW: handling for 'enum' columns (Github Issue #30):
    if($info->{data_type} eq 'enum' && $info->{extra} && $info->{extra}{list}) {
      my $list = $info->{extra}{list};
      
      my $selections = [];
      # Null choice:
      push @$selections, {
        # #A9A9A9 = light grey
        text => '<span style="color:#A9A9A9;">(None)</span>', value => undef
      } if ($info->{is_nullable});
      
      push @$selections, map {
        { text => $_, value => $_ }
      } @$list;
    
      $cols->{$col}{menu_select_editor} = {
        #mode: 'combo', 'menu' or 'cycle':
        mode        => 'menu',
        selections  => $selections
      };

      # New: also save the list of possible values in a hashref...
      #      This is being done so that they can be pre-validated in
      #      quick search, needed for Postfix (Github Issue #56)
      #      TODO: not happy about having to do this - revisit later
      $cols->{$col}{enum_value_hash} = { map {$_=>1} @$list }
    }
    # --^^--
    
  }

  return { columns => $cols };
}

sub TableSpec_valid_db_columns {
  my $self = shift;

  my @single_rels = ();
  my @multi_rels = ();
  my @virtual_single_rels = ();

  my %fk_cols = ();
  my %pri_cols = map {$_=>1} $self->primary_columns;

  foreach my $rel ($self->relationships) {
    my $info = $self->relationship_info($rel);
    
    my $accessor = $info->{attrs}->{accessor};
    
    # 'filter' means single, but the name is also a local column
    $accessor = 'single' if (
      $accessor eq 'filter' and
      $self->TableSpec_cnf->{'priority_rel_columns'} and
      !(
        $self->TableSpec_cnf->{'no_priority_rel_column'} and
        $self->TableSpec_cnf->{'no_priority_rel_column'}->{$rel}
      ) and
      ! $pri_cols{$rel} #<-- exclude primary column names. TODO: this check is performed later, fix
    );
    
    if($accessor eq 'single') {
      my $cond_info = $self->parse_relationship_cond($info->{cond});
      if($cond_info->{self} && $cond_info->{foreign}) {
        push @single_rels, $rel;
        my ($fk) = keys %{$info->{attrs}->{fk_columns}};
        $fk_cols{$fk} = $rel if($fk);
      }
      else {
        # (Github Issue #40)
        # New: "virtual" single rels are relationships for which we
        # cannot introspect in both directions (i.e. not physical
        # foreign keys). These are still "single" in that they map to
        # one related row, but will not be editable and not have a
        # open link (yet) 
        push @virtual_single_rels, $rel;
      }
    }
    elsif($accessor eq 'multi') {
      push @multi_rels, $rel;
    }
  }

  $self->TableSpec_set_conf('relationship_column_names',\@single_rels);
  $self->TableSpec_set_conf('multi_relationship_column_names',\@multi_rels);
  $self->TableSpec_set_conf('relationship_column_fks_map',\%fk_cols);

  # New: move single rels up to immediately follow their FK column:
  my @cols = map { $_, ( $fk_cols{$_} ? $fk_cols{$_} : () ) } $self->columns;

  return uniq(@cols,@single_rels,@multi_rels,@virtual_single_rels);
}

# There is no longer extra logic at this stage because we're
# backing off of the entire original "ordering" design:
sub default_TableSpec_cnf_column_order { (shift)->TableSpec_valid_db_columns }

# Tmp code: these are all key names that may be used to set column
# properties (column TableSpecs). We are keeping track of them to
# use to for remapping while the TableSpec_cnf refactor/consolidation
# is underway...
my @col_prop_names = qw(
columns
column_properties
column_properties_ordered
column_properties_defaults
);
my %col_prop_names = map {$_=>1} @col_prop_names;

# The TableSpec_set_conf method is overly complex to allow
# flexible arguments as either hash or hashref, and because of
# the special case of setting the nested 'column_properties'
# param, if specified as the first argument, and then be able to
# accept its sub params as either a hash or a hashref. In hindsight, 
# allowing this was probably not worth the extra maintenace/code and
# was too fancy for its own good (since this case may or may not  
# shift the key/value positions in the arg list) but it is a part
# of the API for now...
sub TableSpec_set_conf {
  my $self = shift;
  die "TableSpec_set_conf(): bad arguments" unless (scalar(@_) > 0);
  
  # First arg can be a hashref - deref and call again:
  if(ref($_[0])) {
    die "TableSpec_set_conf(): bad arguments" unless (
      ref($_[0]) eq 'HASH' and
      scalar(@_) == 1
    );
    return $self->TableSpec_set_conf(%{$_[0]})
  }
  
  $self->TableSpec_built_cnf(undef); #<-- FIXME!!
  
  # Special handling for setting 'column_properties':
  if ($col_prop_names{$_[0]}) {
    shift @_; #<-- pull out the 'column_properties' first arg
    return $self->_TableSpec_set_column_properties(@_);
  };
  
  # Enforce even number of args for good measure:
  die join(' ', 
    'TableSpec_set_conf( %cnf ):',
    "odd number of args in key/value list:", Dumper(\@_)
  ) if (scalar(@_) & 1);
  
  my %cnf = @_;
  
  for my $param (keys %cnf) {
    # Also make sure all the keys (even positions) are simple scalars:
    die join(' ',
      'TableSpec_set_conf( %cnf ):',
      'found ref in key position:', Dumper($_)
    ) if (ref($param));
  
    if($col_prop_names{$param}) {
      # Also handle column_properties specified with other params:
      die join(' ',
        'TableSpec_set_conf( %cnf ): Expected',
        "HashRef value for config key '$param':", Dumper($cnf{$param})
      ) unless (ref($cnf{$param}) eq 'HASH');
      $self->_TableSpec_set_column_properties($cnf{$param});
    }
    else {
      $self->TableSpec_cnf->{$param} = $cnf{$param} 
    }
  }
}

# Special new internal method for setting column properties and
# properly handle backward compatability. Simultaneously sets/updates
# the cnf key names for all the 'column_properties' names that are
# currently supported by the API (as references pointing to the same
# single config HashRef). This is only temporary and is a throwback
# caused by the older/original API design for the TableSpec_cnf and
# will be removed later on once the other config names can be depricated
# along with other planned refactored. This is just a stop-gap to 
# allow this refactor to be done in stages...
sub _TableSpec_set_column_properties {
  my $self = shift;
  die "TableSpec_set_conf( column_properties => %cnf ): bad args" 
    unless (scalar(@_) > 0);
  
  # First arg can be a hashref - deref and call again:
  if(ref($_[0])) {
    die "TableSpec_set_conf( column_properties => %cnf ): bad args"  unless (
      ref($_[0]) eq 'HASH' and
      scalar(@_) == 1
    );
    return $self->_TableSpec_set_column_properties(%{$_[0]})
  }
  
  # Enforce even number of args for good measure:
  die join(' ', 
    'TableSpec_set_conf( column_properties => %cnf ):',
    "odd number of args in key/value list:", Dumper(\@_)
  ) if (scalar(@_) & 1);
  
  my %cnf = @_;
  
  # Also make sure all the keys (even positions) are simple scalars:
  ref($_) and die join(' ',
    'TableSpec_set_conf( column_properties => %cnf ):',
    'found ref in key position:', Dumper($_)
  ) for (keys %cnf);
  
  my %valid_colnames = map {$_=>1} ($self->TableSpec_valid_db_columns);
  
  my $col_props;
  $col_props ||= $self->TableSpec_cnf->{$_} for (@col_prop_names);
  $col_props ||= {};
  
  for my $col (keys %cnf) {
    warn join(' ',
      "Ignoring config for unknown column name '$col'",
      "in $self TableSpec config\n"
    ) and next unless ($valid_colnames{$col});
    $col_props->{$col} = $cnf{$col};
  }
  
  $self->TableSpec_cnf->{$_} = $col_props for (@col_prop_names);
}


# New function for updating/merging in column configs. This allows
# setting certain column configs without overwriting existing config 
# keys that are not being specified:
sub TableSpec_merge_columns_conf {
  my $self = shift;
  my $conf = shift;
  
  die "TableSpec_merge_columns_conf( \%columns ): bad args"
    unless (ref($conf) eq 'HASH');
  
  my $existing = $self->TableSpec_get_conf('columns') || {};
  
  my @cols = uniq( keys %$conf, keys %$existing );
  
  my %new = ( map {
    $_ => {
      %{ $existing->{$_} || {} },
      %{ $conf->{$_} || {} },
    }
  } @cols );
  
  return $self->TableSpec_set_conf( columns => \%new );
}



sub TableSpec_get_conf {
  my $self = shift;
  my $param = shift || return undef;
  my $storage = shift || $self->get_built_Cnf;
  
  # Special: map all column prop names into 'column_properties'
  $param = 'column_properties' if ($col_prop_names{$param});
  
  my $value = $storage->{$param};
  
  # --- FIXME FIXME FIXME
  # In the original design of the TableSpec_cnf internals, which
  # was too fancy for its own good, meta/type information was
  # transparently stored to be able to do things like remember
  # the order of keys in hashes, auto dereference, etc. This has
  # been unfactored and converted to simple key/values since, however,
  # places that might still call TableSpec_get_conf still expect
  # to get back lists instead of ArrayRefs/HashRefs in certain
  # places. These places should be very limited (part of the reason
  # it was decided this whole thing wasn't worth it, because it just
  # wasn't used enough), but for now, to honor the original API (mostly)
  # we're dereferencing according to wantarray, since all the places
  # that expect to get lists back obviously call TableSpec_get_conf
  # in LIST context. This should not be kept this way for too long,
  # however! It is just temporary until those outside places
  # can be confirmed and eliminated, or a proper deprecation plan
  # can be made, should that even be needed...
  
  if(wantarray && ref($value)) {
    cluck join("\n",'',
      "  WARNING: calling TableSpec_get_conf() in LIST context",
      "  is deprecated, please update your code.",
      "   --> Auto-dereferencing param '$param' $value",'',
    '') if (ref($value) eq 'ARRAY' || ref($value) eq 'HASH');
    return @$value if (ref($value) eq 'ARRAY');
    return %$value if (ref($value) eq 'HASH');
  }
  
  # When trying to get a param that does not exist, return an
  # empty list if called in LIST context, otherwise undef
  return wantarray ? () : undef unless (exists $storage->{$param});
  # ---
  
  return $value;
}


sub TableSpec_has_conf {
	my $self = shift;
	my $param = shift;
	my $storage = shift || $self->get_built_Cnf;
	return 1 if (exists $storage->{$param});
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

# This function parses 'foreign' and 'self' column names from the
# 'cond' of a defined in a DBIC relationship into a hashref. It is
# only able to do this for simple, single-key foreign key rels
# of the form:    { "foreign.id_col" => "self.fk_col" }
# All other forms, such as multi-keys and CodeRefs, will return
# and empty HashRef. The only reason we really need this information
# outside of DBIC is for editable single rels (FKs) to be able
# to present selection dialogs (i.e. dropdowns) and currently
# the "open" magnify links, but the open links are planned to be
# changed to reference URLs based on the relationship name, which
# will remove this dependency and allow open links for any relationship
# column, including even those with CodeRef conditions...
sub parse_relationship_cond {
  my ($self,$cond,$info) = @_;
  
  return {} unless (
    ref($cond) eq 'HASH' and
    scalar keys %$cond == 1
  );
  
  my $data = {};
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
	
  no warnings 'uninitialized'; # because we might compare undef values
  
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
	my @changed = ();
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
	
	my $col_props = $self->TableSpec_get_conf('columns');
	
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

sub getRestKey {
	my $self = shift;
	my $rest_key_col = $self->TableSpec_get_conf('rest_key_column');
	return $rest_key_col if ($rest_key_col && $rest_key_col ne '');
	my @pri = $self->primary_columns;
	return $pri[0] if ($pri[0] && scalar @pri == 1);
	return undef;
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
			my $col = $class->getRestKey or return $self->getRecordPkValue;
			return try{$self->get_column($col)};
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
			my %attrs = ( class => "ra-nav-link ra-icon-magnify-tiny", @_ );

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
		no strict 'refs';
    my $meth_name = join '::', $class, $meth;
		*$meth_name = subname $meth_name => $RowMethods{$meth};
	}
	# ---
}


sub _table_name_safe {
  my $class = shift;

  my $table = $class->table;
  $table = $$table if ((ref($table)||'') eq 'SCALAR'); # Handle ScalarRef values
  $table = (reverse split(/\./,$table))[0]; # Handle 'db.table' and 'schema.db.table' formats

  $table =~ s/[\'\"]//g; # Strip quotes
  $table =~ s/\W/_/g;    # Convert any non-word characters to underscore

  $table
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
