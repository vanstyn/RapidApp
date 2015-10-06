package RapidApp::TableSpec::Role::DBIC;
use strict;
use Moose::Role;
use Moose::Util::TypeConstraints;

use RapidApp::TableSpec::DbicTableSpec;
use RapidApp::TableSpec::ColSpec;
use RapidApp::TableSpec::Column::Profile;

use RapidApp::Util qw(:all);

use RapidApp::DBIC::Component::TableSpec;

require Text::Glob;
use Text::WagnerFischer qw(distance);
use Clone qw( clone );
use Digest::MD5 qw(md5_hex);
use curry;

# hackish performance tweak:
my %match_glob_cache = ();
sub match_glob {
  my ($l,$r) = @_;
  $match_glob_cache{$l}{$r} = Text::Glob::match_glob($l,$r)
    unless (exists $match_glob_cache{$l}{$r});
  return $match_glob_cache{$l}{$r};
}

# ---
# Attributes 'ResultSource', 'ResultClass' and 'schema' are interdependent. If ResultSource
# is not supplied to the constructor, both ResultClass and schema must be.
has 'ResultSource', is => 'ro', isa => 'DBIx::Class::ResultSource', lazy => 1,
default => sub {
	my $self = shift;
	
	my $schema_attr = $self->meta->get_attribute('schema');
	$self->meta->throw_error("'schema' not supplied; cannot get ResultSource automatically!")
		unless ($schema_attr->has_value($self));
	
	#return $self->schema->source($self->ResultClass);
	return try{$self->schema->source($self->ResultClass)} || 
		$self->schema->source((reverse split(/\:\:/,$self->ResultClass))[0]);
};

has 'ResultClass', is => 'ro', isa => 'Str', lazy => 1, 
default => sub {
	my $self = shift;
	my $source_name = $self->ResultSource->source_name;
	return $self->ResultSource->schema->class($source_name);
};

has 'schema', is => 'ro', lazy => 1, default => sub { (shift)->ResultSource->schema; };
# ---

use List::Util;

sub _coerce_ColSpec {
  my $v = $_[0];
  ( # quick/dirty simulate from 'ArrayRef[Str]'
    ref $v && ref($v) eq 'ARRAY' &&
    !( List::Util::first { ref($_) || ! defined $_ } @$v )
  ) ? RapidApp::TableSpec::ColSpec->new(colspecs => $v) : $v
}

subtype 'ColSpec', as 'Object';
coerce 'ColSpec', from 'ArrayRef[Str]',	via { &_coerce_ColSpec($_) };

has 'include_colspec', is => 'ro', isa => 'ColSpec', 
	required => 1, coerce => \&_coerce_ColSpec, trigger =>  sub { (shift)->_colspec_attr_init_trigger(@_) };
	
has 'updatable_colspec', is => 'ro', isa => 'ColSpec', 
	default => sub {[]}, coerce => \&_coerce_ColSpec, trigger =>  sub { (shift)->_colspec_attr_init_trigger(@_) };
	
has 'creatable_colspec', is => 'ro', isa => 'ColSpec', 
	default => sub {[]}, coerce => \&_coerce_ColSpec, trigger => sub { (shift)->_colspec_attr_init_trigger(@_) };
	
has 'always_fetch_colspec', is => 'ro', isa => 'ColSpec', 
	default => sub {[]}, coerce => \&_coerce_ColSpec, trigger => sub { (shift)->_colspec_attr_init_trigger(@_) };

# See attr in RapidApp::Module::StorCmp::Role::DbicLnk
has 'no_header_transform', is => 'ro', isa => 'Bool', default => 0;

sub _colspec_attr_init_trigger {
	my ($self,$ColSpec) = @_;
	my $sep = $self->relation_sep;
	/${sep}/ and die "Fatal: ColSpec '$_' is invalid because it contains the relation separater string '$sep'" for ($ColSpec->all_colspecs);
	
	$ColSpec->expand_colspecs(sub {
		$self->expand_relspec_wildcards(\@_)
	});
}

sub BUILD {}
after BUILD => sub {
	my $self = shift;
	
	$self->init_relspecs;
	
};

sub init_relspecs {
	my $self = shift;
	
	$self->multi_rel_columns_indx;
	
	$self->include_colspec->expand_colspecs(sub {
		$self->expand_relationship_columns(@_)
	});
	
	$self->include_colspec->expand_colspecs(sub {
		$self->expand_related_required_fetch_colspecs(@_)
	});
	
	
	foreach my $col ($self->no_column_colspec->base_colspec->all_colspecs) {
		$self->Cnf_columns->{$col} = {} unless ($self->Cnf_columns->{$col});
		%{$self->Cnf_columns->{$col}} = (
			%{$self->Cnf_columns->{$col}},
			no_column => \1, 
			no_multifilter => \1, 
			no_quick_search => \1
		);
		push @{$self->Cnf_columns_order},$col;
	}
	uniq($self->Cnf_columns_order);
	
	my @rels = $self->include_colspec->all_rel_order;
	
	$self->add_related_TableSpec($_) for (grep { $_ ne '' } @rels);
	
	$self->init_local_columns;
	
	foreach my $rel (@{$self->related_TableSpec_order}) {
		my $TableSpec = $self->related_TableSpec->{$rel};
		for my $name ($TableSpec->updated_column_order) {
			die "Column name conflict: $name is already defined (rel: $rel)" if ($self->has_column($name));
			$self->column_name_relationship_map->{$name} = $rel;
		}
	}
	
}


has 'column_data_alias', is => 'ro', isa => 'HashRef', default => sub {{}};
sub apply_column_data_alias { my $h = (shift)->column_data_alias; %$h = ( %$h, @_ ) }

has 'no_column_colspec', is => 'ro', isa => 'ColSpec', coerce => 1, default => sub {[]};
sub expand_relationship_columns {
	my $self = shift;
	my @columns = @_;
	my @expanded = ();
	
	my $rel_cols = $self->get_Cnf('relationship_column_names') || return;
	
	my @no_cols = ();
	foreach my $col (@columns) {
		push @expanded, $col;
		
		foreach my $relcol (@$rel_cols) {
			next unless (match_glob($col,$relcol));
		
			my @add = (
				$self->Cnf_columns->{$relcol}->{keyField},
				$relcol . '.' . $self->Cnf_columns->{$relcol}->{displayField},
				$relcol . '.' . $self->Cnf_columns->{$relcol}->{valueField}
			);
			push @expanded, @add;
			$self->apply_column_data_alias( $relcol => $self->Cnf_columns->{$relcol}->{keyField} );
			push @no_cols, grep { !$self->colspecs_to_colspec_test(\@columns,$_) } @add;
		}
	}
	$self->no_column_colspec->add_colspecs(@no_cols);
	
	return @expanded;
}

sub expand_related_required_fetch_colspecs {
	my $self = shift;
	my @columns = @_;
	my @expanded = ();
	
	my $local_cols = $self->get_Cnf_order('columns');

	my @no_cols = ();
	foreach my $spec (@columns) {
		push @expanded, $spec;
		
		foreach my $col (@$local_cols) {
			next unless (match_glob($spec,$col));
		
			my $req = $self->Cnf_columns->{$col}->{required_fetch_colspecs} or next;
			$req = [ $req ] unless (ref $req);
			
			my @req_columns = ();
			foreach my $spec (@$req) {
				my $colname = $spec;
				my $sep = $self->relation_sep;
				$colname =~ s/\./${sep}/g;
				push @req_columns, $self->column_prefix . $colname;
				#push @req_columns, $colname;
			}
			# This is then used later during the store read request in DbicLink2
			$self->Cnf_columns->{$col}->{required_fetch_columns} = [] 
				unless (defined $self->Cnf_columns->{$col}->{required_fetch_columns});
				
			push @{$self->Cnf_columns->{$col}->{required_fetch_columns}}, @req_columns;

			push @expanded, @$req;
			push @no_cols, grep { !$self->colspecs_to_colspec_test(\@columns,$_) } @$req;
		}
	}
	$self->no_column_colspec->add_colspecs(@no_cols);

	return @expanded;
}


sub base_colspec {
	my $self = shift;
	return $self->include_colspec->base_colspec->colspecs;
}

has 'Cnf_columns', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return clone($self->get_Cnf('columns'));
};
has 'Cnf_columns_order', is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub {
	my $self = shift;
	return clone($self->get_Cnf_order('columns'));
};

sub init_local_columns  {
	my $self = shift;
	
	my $class = $self->ResultClass;
	$class->set_primary_key( $class->columns ) unless ( $class->primary_columns > 0 );
	
	my @order = @{$self->Cnf_columns_order};
	@order = $self->filter_base_columns(@order);
	
	$self->add_db_column($_,$self->Cnf_columns->{$_}) for (@order);
};


sub add_db_column($@) {
	my $self = shift;
	my $name = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%opt = $self->get_relationship_column_cnf($name,\%opt) if($opt{relationship_info});
	
	$opt{name} = $self->column_prefix . $name;
	
	my $editable = $self->filter_updatable_columns($name,$opt{name});
	my $creatable = $self->filter_creatable_columns($name,$opt{name});
	
	# --  NEW: VIRTUAL COLUMNS SUPPORT:
	if($self->ResultClass->has_virtual_column($name)) {
		# Only editable if a custom 'set_function' has been defined for the virtual column:
		unless(try{$self->ResultClass->column_info($name)->{set_function}}) {
			$editable = 0;
			$creatable = 0;
		}
		# Hard-code exclude virtual columns from quick search. May add this support in
		# the future, but it will require a bit of effort (see the complex/custom code
		# in multifilters with the conversion into a 'HAVING' clause
		$opt{no_quick_search} = \1;
	}
	# --
	
	$opt{allow_edit} = \0 unless ($editable);
	$opt{allow_add} = \0 unless ($creatable);

	unless ($editable or $creatable) {
		$opt{rel_combo_field_cnf} = $opt{editor} if($opt{editor});
		$opt{editor} = '' ;
	}
	
	return $self->add_columns(\%opt);
}



# Load and process config params from TableSpec_cnf in the ResultClass plus
# additional defaults:
has 'Cnf_order', is => 'ro', isa => 'HashRef', default => sub {{}};
sub get_Cnf_order { (shift)->Cnf_order->{$_[0]} }


has 'Cnf', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $class = $self->ResultClass;
	
	# Load the TableSpec Component on the Result Class if it isn't already:
	# (should this be done like this? this is a global change and could be an overreach)
	unless($class->can('TableSpec_cnf')) {
		$class->load_components('+RapidApp::DBIC::Component::TableSpec');
		$class->apply_TableSpec;
	}
	
	my $cf = $class->get_built_Cnf;
  
	#%{$self->Cnf_order} = %{ $cf->{order} || {} };
	#return $cf->{data} || {};
  
  # Legacy/backcompat: simulate the olf TableSpec_cnf format:
  my $sim_order = { columns => [ keys %{$cf->{columns}} ] };
  
  %{$self->Cnf_order} = %{ $sim_order || {} };
  return $cf || {};
}, isa => 'HashRef';
sub get_Cnf { (shift)->Cnf->{$_[0]} }

has 'relationship_column_configs', is => 'ro', isa => 'HashRef', lazy_build => 1; 
sub _build_relationship_column_configs {
	my $self = shift;
	
	my $class = $self->ResultClass;
	return {} unless ($class->can('TableSpec_cnf'));
	
	my %rel_cols_indx = map {$_=>1} @{$self->get_Cnf('relationship_column_names')};
	my %columns = $class->TableSpec_get_conf('columns');
	return { map { $_ => $columns{$_} } grep { $rel_cols_indx{$_} } keys %columns };
};


# colspecs that were added solely for the relationship columns
# get stored in 'added_relationship_column_relspecs' and are then
# hidden in DbicLink2.
# TODO: come up with a better way to handle this. It's ugly.
has 'added_relationship_column_relspecs' => ( 
	is => 'rw', isa => 'ArrayRef', default => sub {[]},
	#trigger => sub { my ($self,$val) = @_; uniq($val) }
);


sub expand_relspec_wildcards {
	my $self = shift;
	my $colspec = shift;
	
	if(ref($colspec) eq 'ARRAY') {
		my @exp = ();
		push @exp, $self->expand_relspec_wildcards($_,@_) for (@$colspec);
		return @exp;
	}
	
	my $Source = shift || $self->ResultSource;
	my @ovr_macro_keywords = @_;
	
	# Exclude colspecs that start with #
	return () if ($colspec =~ /^\#/);
	
	my @parts = split(/\./,$colspec); 
	return ($colspec) unless (@parts > 1);
	
	my $clspec = pop @parts;
	my $relspec = join('.',@parts);
	
	# There is nothing to expand if the relspec doesn't contain wildcards:
	return ($colspec) unless ($relspec =~ /[\*\?\[\]\{]/);
	
	push @parts,$clspec;
	
	my $rel = shift @parts;
	my $pre; { my ($match) = ($rel =~ /^(\!)/); $rel =~ s/^(\!)//; $pre = $match ? $match : ''; }
	
	my @rel_list = $Source->relationships;
	#scream($_) for (map { $Source->relationship_info($_) } @rel_list);
	
	my @macro_keywords = @ovr_macro_keywords;
	my $macro; { 
    my ($match) = ($rel =~ /^\{([\?\:a-zA-Z0-9]+)\}/);
    $rel =~ s/^\{([\?\:a-zA-Z0-9]+)\}//;
    $macro = $match; 
  }
	push @macro_keywords, split(/\:/,$macro) if ($macro);
	my %macros = map { $_ => 1 } @macro_keywords;
	
	my @accessors = grep { $_ eq 'single' or $_ eq 'multi' or $_ eq 'filter'} @macro_keywords;
	if (@accessors > 0) {
		my %ac = map { $_ => 1 } @accessors;
		@rel_list = grep { $ac{ $Source->relationship_info($_)->{attrs}->{accessor} } } @rel_list;
	}

	my @matching_rels = grep { match_glob($rel,$_) } @rel_list;
	die 'Invalid ColSpec: "' . $rel . '" doesn\'t match any relationships of ' . 
		$Source->schema->class($Source->source_name) 
      unless ($macros{'?'} or @matching_rels > 0 or scalar(@rel_list) == 0);
	
	my @expanded = ();
	foreach my $rel_name (@matching_rels) {
		my @suffix = $self->expand_relspec_wildcards(join('.',@parts),$Source->related_source($rel_name),@ovr_macro_keywords);
		push @expanded, $pre . $rel_name . '.' . $_ for (@suffix);
	}

	return (@expanded);
}


has 'relation_sep' => ( is => 'ro', isa => 'Str', required => 1 );
has 'relspec_prefix' => ( is => 'ro', isa => 'Str', default => '' );
# needed_join is the relspec_prefix in DBIC 'join' attr format
has 'needed_join' => ( is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {} if ($self->relspec_prefix eq '');
	return $self->chain_to_hash(split(/\./,$self->relspec_prefix));
});
has 'column_prefix' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub {
	my $self = shift;
	return '' if ($self->relspec_prefix eq '');
	my $col_pre = $self->relspec_prefix;
	my $sep = $self->relation_sep;
	$col_pre =~ s/\./${sep}/g;
	return $col_pre . $self->relation_sep;
});




around 'get_column' => sub {
	my $orig = shift;
	my $self = shift;
	my $name = shift;
	
	my $rel = $self->column_name_relationship_map->{$name};
	if ($rel) {
		my $TableSpec = $self->related_TableSpec->{$rel};
		return $TableSpec->get_column($name) if ($TableSpec);
	}
	
	return $self->$orig($name);
};


# accepts a list of column names and returns the names that match the base colspec
sub filter_base_columns {
	my $self = shift;
	my @columns = @_;
	
	# Why has this come up?
	# filter out columns with invalid characters (*):
	@columns = grep { /^[A-Za-z0-9\-\_\.]+$/ } @columns;
	
	return $self->colspec_select_columns({
		colspecs => $self->base_colspec,
		columns => \@columns,
	});
}

sub filter_include_columns {
	my $self = shift;
	my @columns = @_;
	
	my @inc_cols = $self->colspec_select_columns({
		colspecs => $self->include_colspec->colspecs,
		columns => \@columns,
	});
	
	my @rel_cols = $self->colspec_select_columns({
		colspecs => $self->added_relationship_column_relspecs,
		columns => \@columns,
	});
	
	my %allowed = map {$_=>1} @inc_cols,@rel_cols;
	return grep { $allowed{$_} } @columns;
}

# accepts a list of column names and returns the names that match updatable_colspec
sub filter_updatable_columns {
	my $self = shift;
	my @columns = @_;
	
	#exclude all multi relationship columns (except new m2m multi rel columns)
	@columns = grep {
		$self->m2m_rel_columns_indx->{$self->column_prefix . $_} ||
		!$self->multi_rel_columns_indx->{$self->column_prefix . $_}
	} @columns;
	
	return $self->colspec_select_columns({
		colspecs => $self->updatable_colspec->colspecs,
		columns => \@columns,
	});
}



# accepts a list of column names and returns the names that match creatable_colspec
sub filter_creatable_columns {
	my $self = shift;
	my @columns = @_;
	
	#exclude all multi relationship columns
	#@columns = grep {!$self->multi_rel_columns_indx->{$_}} @columns;
	
	#exclude all multi relationship columns (except new m2m multi rel columns)
	@columns = grep {
		$self->m2m_rel_columns_indx->{$self->column_prefix . $_} ||
		!$self->multi_rel_columns_indx->{$self->column_prefix . $_}
	} @columns;

	# First filter by include_colspec:
	@columns = $self->filter_include_columns(@columns);
	
	return $self->colspec_select_columns({
		colspecs => $self->creatable_colspec->colspecs,
		columns => \@columns,
	});
}



# Tests whether or not the colspec in the second arg matches the colspec of the first arg
# The second arg colspec does NOT expand wildcards, it has to be a specific rel/col string
sub colspec_to_colspec_test {
	my $self = shift;
	my $colspec = shift;
	my $test_spec = shift;
	
	my ($match) = ($colspec =~ /^(\!)/); $colspec =~ s/^(\!)//;
	my $x = $match ? -1 : 1;
	
	my @parts = split(/\./,$colspec);
	my @test_parts = split(/\./,$test_spec);
	return undef unless(scalar @parts == scalar @test_parts);
	
	foreach my $part (@parts) {
		my $test = shift @test_parts or return undef;
		return undef unless (match_glob($part,$test));
	}
	
	return $x;
}

sub colspecs_to_colspec_test {
	my $self = shift;
	my $colspecs = shift;
	my $test_spec = shift;
	
	$colspecs = [ $colspecs ] unless (ref($colspecs) eq 'ARRAY');
	
	my $match = 0;
	foreach my $colspec (@$colspecs) {
		my $result = $self->colspec_to_colspec_test($colspec,$test_spec) || next;
		return 0 if ($result < 0);
		$match = 1 if ($result > 0);
	}
	
	return $match;
}



my %dist_cache = ();
sub get_distance {
  my ($l,$r) = @_;
  $dist_cache{$l}{$r} = distance($l,$r) unless (exists $dist_cache{$l}{$r});
  return $dist_cache{$l}{$r};
}


#around colspec_test => &func_debug_around();

# TODO:
# abstract this logic (much of which is redundant) into its own proper class 
# (merge with Mike's class)
# Tests whether or not the supplied column name matches the supplied colspec.
# Returns 1 for positive match, 0 for negative match (! prefix) and undef for no match
sub _colspec_test($$){
	my $self = shift;
	my $full_colspec = shift || die "full_colspec is required";
	my $col = shift || die "col is required";
	
	# @other_colspecs - optional.
	# If supplied, the column will also be tested against the colspecs in @other_colspecs,
	# and no match will be returned unless this colspec matches *and* has the lowest
	# edit distance of any other matches. This logic is designed so that remaining
	# colspecs to be tested can be considered, and only the best match will win. This
	# is meaningful when determining things like order based on a list of colspecs. This 
	# doesn't serve any purpose when doing a straight bool up/down test
	# tested with 
	my @other_colspecs = @_;
	
  
  my $full_colspec_orig = $full_colspec;
  my ($neg_flag) = ($full_colspec =~ /^(\!)/); $full_colspec =~ s/^(\!)//;
  my $x = $neg_flag ? -1 : 1;
  my $match_return = $neg_flag ? 0 : 1;
	
	my @parts = split(/\./,$full_colspec); 
	my $colspec = pop @parts;
	my $relspec = join('.',@parts);

	my $sep = $self->relation_sep;
	my $prefix = $relspec;
	$prefix =~ s/\./${sep}/g;
	
	@parts = split(/${sep}/,$col); 
	my $test_col = pop @parts;
	my $test_prefix = join($sep,@parts);
	
	# no match:
	return undef unless ($prefix eq $test_prefix);
	
	# match (return 1 or 0):
	if (match_glob($colspec,$test_col)) {
		# Calculate WagnerFischer edit distance
		my $distance = get_distance($colspec,$test_col);
		
		# multiply my $x to set the sign, then flip so bigger numbers 
		# mean better match instead of the reverse
		my $value = $x * (1000 - $distance); # <-- flip 
		
		foreach my $spec (@other_colspecs) {
			my $other_val = $self->colspec_test($spec,$col) or next;

			# A colspec in @other_colspecs is a better match than us, so we defer:
			return undef if (abs $other_val > abs $value);
		}
		return $value;
	};
	
	# no match:
	return undef;
}

#
# colspec_test_key is used to see if _colspec_test changed, this is
# the only relevant indicator to refetch the result for the given
# colspec_test
#
use B::Deparse;
our $colspec_test_source;
{
	my $deparse = B::Deparse->new;
	$colspec_test_source = $deparse->coderef2text(\&_colspec_test);
}

# New: caching wrapper for performance:
sub colspec_test($$){
  my ( $self, @args ) = @_;
  my $colspec_key = join('|',@args);
	return $self->{_colspec_test_cache}{$colspec_key} //= $self->_colspec_test(@args);
}

# returns a list of loaded column names that match the supplied colspec set
sub get_colspec_column_names {
	my $self = shift;
	my @colspecs = @_;
	@colspecs = @{$_[0]} if (ref($_[0]) eq 'ARRAY');
	
	# support for passing colspecs with relspec wildcards:
	@colspecs = $self->expand_relspec_wildcards(\@colspecs,undef,'?');
	
	return $self->colspec_select_columns({
		colspecs => \@colspecs,
		columns => [ $self->updated_column_order ]
	});
}

# returns a list of all loaded column names except those that match the supplied colspec set
sub get_except_colspec_column_names {
	my $self = shift;
	
	my %colmap = map { $_ => 1} $self->get_colspec_column_names(@_);
	return grep { ! $colmap{$_} } $self->updated_column_order;
}

# Tests if the supplied colspec set matches all of the supplied columns
sub colspec_matches_columns {
	my $self = shift;
	my $colspecs = shift;
	my @columns = @_;
	my @matches = $self->colspec_select_columns({
		colspecs => $colspecs,
		columns => \@columns
	});
	return 1 if (@columns == @matches);
	return 0;
}

our $colspec_select_columns_source;

# Returns a sublist of the supplied columns that match the supplied colspec set.
# The colspec set is considered as a whole, with each column name tested against
# the entire compiled set, which can contain both positive and negative (!) colspecs,
# with the most recent match taking precidence.
sub colspec_select_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

	$self->{_colspec_select_columns_cache} = {}
		unless defined $self->{_colspec_select_columns_cache};

	my $colspecs = $opt{colspecs} or die "colspec_select_columns(): expected 'colspecs'";
	my $columns = $opt{columns} or die "colspec_select_columns(): expected 'columns'";
	$columns = [ sort { $a cmp $b } @{$columns} ];

	my $colspec_select_columns_key = join('_',
		md5_hex(join('_',@{$colspecs})),
		md5_hex(join('_',@{$columns})),
	);

	return @{$self->{_colspec_select_columns_cache}{$colspec_select_columns_key}}
		if defined $self->{_colspec_select_columns_cache}{$colspec_select_columns_key};

	my $cache_key;
	if ($self->has_cache) {
		$cache_key = join('_','colspec_select_columns_cache',
			md5_hex($colspec_test_source.$colspec_select_columns_source),
			md5_hex($self->ResultClass),
			$colspec_select_columns_key,
		);
		my $cache_content = $self->cache->get($cache_key);
		return @{$self->{_colspec_select_columns_cache}{$colspec_select_columns_key} = $cache_content}
			if $cache_content;
	}

	# if best_match_look_ahead is true, the current remaining colspecs will be passed
	# to each invocation of colspec_test which will cause it to only return a match
	# when testing the *closest* (according to WagnerFischer edit distance) colspec
	# of the set to the column. This prevents 
	my $best_match = $opt{best_match_look_ahead};
	
	$colspecs = [ $colspecs ] unless (ref $colspecs);
	$columns = [ $columns ] unless (ref $columns);
	
	$opt{match_data} = {} unless ($opt{match_data});

	my %match = map { $_ => 0 } @$columns;
	my @order = ();
	my $i = 0;
	for my $spec (@$colspecs) {
		my @remaining = @$colspecs[++$i .. $#$colspecs];
		for my $col (@$columns) {

			my @arg = ($spec,$col);
			push @arg, @remaining if ($best_match); # <-- push the rest of the colspecs after the current for index
			
			my $result = $self->colspec_test(@arg) or next;
			push @order, $col if ($result > 0);
			$match{$col} = $result;
			$opt{match_data}->{$col} = {
				index => $i - 1,
				colspec => $spec
			} unless ($opt{match_data}->{$col});
		}
	}
	
	my $colspec_select_columns = [ uniq(grep { $match{$_} > 0 } @order) ];
	if ($cache_key) {
		$self->cache->set($cache_key,$colspec_select_columns);
	}
	return @{$self->{_colspec_select_columns_cache}{$colspec_select_columns_key} = $colspec_select_columns};
}

{
	my $deparse = B::Deparse->new;
	$colspec_select_columns_source = $deparse->coderef2text(\&colspec_select_columns);
}

# Applies the original column order defined in the table Schema:
sub apply_natural_column_order {
	my $self = shift;
	my $class = $self->ResultClass;

  # New: need to consult the TableSpec method now that we move single-rels up into the column
  # list at the location of their FK column -- its no longer as simple as columns then rels
  my @local = $class->can('default_TableSpec_cnf_column_order')
    ? ( $class->default_TableSpec_cnf_column_order )
    : ( $class->columns, $class->relationships     ); # fall-back for good measure

	$self->reorder_by_colspec_list(
    @local, @{ $self->include_colspec->colspecs || [] }
	);
}

# reorders the entire column list according to a list of colspecs. This is called
# by DbicLink2 to use the same include_colspec to also define the column order
sub reorder_by_colspec_list {
	my $self = shift;
	my @colspecs = @_;
	@colspecs = @{$_[0]} if (ref($_[0]) eq 'ARRAY');
	
	# Check the supplied colspecs for any that don't contain '.'
	# if there are none, and all of them contain a '.', then we
	# need to add the base colspec '*'
	my $need_base = 1;
	! /\./ and $need_base = 0 for (@colspecs);
	unshift @colspecs, '*' if ($need_base);
	
	my @new_order = $self->colspec_select_columns({
		colspecs => \@colspecs,
		columns => [ $self->updated_column_order ],
		best_match_look_ahead => 1
	});
	
	# Add all the current columns to the end of the new list in case any
	# got missed. (this prevents the chance of this operation dropping any 
	# of the existing columns, dupes are filtered out below):
	push @new_order, $self->updated_column_order;
	
	my %seen = ();
	@{$self->column_order} = grep { !$seen{$_}++ } @new_order;
	return $self->updated_column_order; #<-- for good measure
}

sub relation_colspecs {
	my $self = shift;
	return $self->include_colspec->subspec;
}

sub relation_order {
	my $self = shift;
	return $self->include_colspec->rel_order;
}


sub new_TableSpec {
	my $self = shift;
	return RapidApp::TableSpec::DbicTableSpec->new(@_);
	#return RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(@_);
}



# Returns the TableSpec associated with the supplied column name
sub column_TableSpec {
	my $self = shift;
	my $column = shift;

	my $rel = $self->column_name_relationship_map->{$column};
	unless ($rel) {
		my %ndx = map {$_=>1} 
			keys %{$self->columns}, 
			@{$self->added_relationship_column_relspecs};
			
		#scream($column,\%ndx);
			
		return $self if ($ndx{$column});
		return undef;
	}
	
	return $self->related_TableSpec->{$rel}->column_TableSpec($column);
}

# Accepts a list of columns and divides them into a hash of arrays
# with keys of the relspec to which each set of columns belongs, with
# both the localized and original column names in a hashref.
# This logic is used in update in DbicLink2
sub columns_to_relspec_map {
	my $self = shift;
	my @columns = @_;
	my $map = {};
	
	foreach my $col (@columns) {
		my $TableSpec = $self->column_TableSpec($col) or next;
		my $pre = $TableSpec->column_prefix;
		my $local_name = $col;
		$local_name =~ s/^${pre}//;
		push @{$map->{$TableSpec->relspec_prefix}}, {
			local_colname => $local_name,
			orig_colname => $col
		};
	}
	
	return $map;
}


sub columns_to_reltree {
	my $self = shift;
	my @columns = @_;
	my %map = (''=>[]);
	foreach my $col (@columns) {
		my $rel = $self->column_name_relationship_map->{$col} || '';
		push @{$map{$rel}}, $col;
	}
	
	my %tree = map {$_=>1} @{delete $map{''}};
	#$tree{'@' . $_} = $self->columns_to_reltree(@{$map{$_}}) for (keys %map);
	
	foreach my $rel (keys %map) {
		my $TableSpec = $self->related_TableSpec->{$rel} or die "Failed to find related TableSpec $rel";
		$tree{'@' . $rel} = $TableSpec->columns_to_reltree(@{$map{$rel}});
	}

	return \%tree;
}


sub walk_columns_deep {
	my $self = shift;
	my $code = shift;
	my @columns = @_;
	
	my $recurse = 0;
	$recurse = 1 if((caller(1))[3] eq __PACKAGE__ . '::walk_columns_deep');
	local $_{return} = undef unless ($recurse);
	local $_{rel} = undef unless ($recurse);
	local $_{depth} = 0 unless ($recurse);

	
	my %map = (''=>[]);
	foreach my $col (@columns) {
		my $rel = $self->column_name_relationship_map->{$col} || '';
		push @{$map{$rel}}, $col;
	}
	
	
	my @local_cols = @{delete $map{''}};
	
	my $pre = $self->column_prefix;
	my %name_map = map { my $name = $_; $name =~ s/^${pre}//; $name => $_ } @local_cols;
	local $_{name_map} = \%name_map;
	local $_{return} = $code->($self,@local_cols);
	local $_{depth} = $_{depth}; $_{depth}++;
	foreach my $rel (keys %map) {
		my $TableSpec = $self->related_TableSpec->{$rel} or die "Failed to find related TableSpec $rel";
		local $_{last_rel} = $_{rel};
		local $_{rel} = $rel;
		$TableSpec->walk_columns_deep($code,@{$map{$rel}});
	}
}




# Accepts a DBIC Row object and a relspec, and returns the related DBIC
# Row object associated with that relspec
sub related_Row_from_relspec {
	my $self = shift;
	my $Row = shift || return undef;
	my $relspec = shift || '';
	
	my @parts = split(/\./,$relspec);
	my $rel = shift @parts || return $Row;
	return $Row if ($rel eq '');
	
	my $info = $Row->result_source->relationship_info($rel) or die "Relationship $rel not found";
	
	# Skip unless its a single (not multi) relationship:
	return undef unless ($info->{attrs}->{accessor} eq 'single' || $info->{attrs}->{accessor} eq 'filter');
	
	my $Related = $Row->$rel;
	return $self->related_Row_from_relspec($Related,join('.',@parts));
}


# Is this func still used??
# Like column_order but only considers columns in the local TableSpec object
# (i.e. not in related TableSpecs)
sub local_column_names {
	my $self = shift;
	my %seen = ();
	return grep { !$seen{$_}++ && exists $self->columns->{$_} } @{$self->column_order}, keys %{$self->columns};
}


has 'column_name_relationship_map' => ( is => 'ro', isa => 'HashRef[Str]', default => sub {{}} );
has 'related_TableSpec' => ( is => 'ro', isa => 'HashRef[RapidApp::TableSpec]', default => sub {{}} );
has 'related_TableSpec_order' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );
sub add_related_TableSpec {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	die "There is already a related TableSpec associated with the '$rel' relationship - " . Dumper(caller_data_brief(20,'^RapidApp')) if (
		defined $self->related_TableSpec->{$rel}
	);
	
	my $info = $self->ResultClass->relationship_info($rel) or die "Relationship '$rel' not found.";
	my $relclass = $info->{class};

	my $relspec_prefix = $self->relspec_prefix;
	$relspec_prefix .= '.' if ($relspec_prefix and $relspec_prefix ne '');
	$relspec_prefix .= $rel;
	
	my $table = $relclass->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
	my %params = (
		name => $table,
		ResultClass => $relclass,
		schema => $self->schema, #<-- need both ResultClass and schema to identify ResultSource
		relation_sep => $self->relation_sep,
		relspec_prefix => $relspec_prefix,
		include_colspec => $self->include_colspec->get_subspec($rel),
    no_header_transform => $self->no_header_transform
	);

	$params{updatable_colspec} = $self->updatable_colspec->get_subspec($rel) || []; 
	$params{creatable_colspec} = $self->creatable_colspec->get_subspec($rel) || [];
	$params{no_column_colspec} = $self->no_column_colspec->get_subspec($rel) || [];

	%params = ( %params, %opt );
	
	my $class = $self->ResultClass;
	if($class->can('TableSpec_get_conf') and $class->TableSpec_has_conf('related_column_property_transforms')) {
    my $rel_transforms = $class->TableSpec_get_conf('related_column_property_transforms');
		$params{column_property_transforms} = $rel_transforms->{$rel} if ($rel_transforms->{$rel});
		
		# -- Hard coded default 'header' transform (2011-12-25 by HV)
		# If there isn't already a configured column_property_transform for 'header'
		# add one that appends the relspec prefix. This is currently built-in because
		# it is such a ubiquotous need and it is just more intuitive than creating yet
		# other param that will always be 'on'. I am sure there are cases where this is
		# not desired, but until I run across them it will just be hard coded:
    #  * Update: Yes, we do want an option to turn this off, and now there is (2015-09-29 by HV)
		unless($self->no_header_transform) {
			$params{column_property_transforms}->{header} ||= sub { $_ ? "$_ ($relspec_prefix)" : $_ };
		}
		# --
		
	}
	
	my $TableSpec = $self->new_TableSpec(%params) or die "Failed to create related TableSpec";
	
	$self->related_TableSpec->{$rel} = $TableSpec;
	push @{$self->related_TableSpec_order}, $rel;
	
	return $TableSpec;
}

sub addIf_related_TableSpec {
	my $self = shift;
	my ($rel) = @_;
	
	my $TableSpec = $self->related_TableSpec->{$rel} || $self->add_related_TableSpec(@_);
	return $TableSpec;
}

around 'get_column' => \&_has_get_column_modifier;
around 'has_column' => \&_has_get_column_modifier;
sub _has_get_column_modifier {
	my $orig = shift;
	my $self = shift;
	my $name = $_[0];
	
	my $rel = $self->column_name_relationship_map->{$name};
	my $obj = $self;
	$obj = $self->related_TableSpec->{$rel} if (defined $rel);
	
	return $obj->$orig(@_);
}


around 'updated_column_order' => sub {
	my $orig = shift;
	my $self = shift;
	
	my %seen = ();
	# Start with and preserve the column order in this object:
	my @order = grep { !$seen{$_}++ } @{$self->column_order};
	
	# Pull in any unseen columns from the superclass (should normally be none, except when initializing)
	push @order, grep { !$seen{$_}++ } $self->$orig(@_);
	
	my @rels = ();
	push @rels, $self->related_TableSpec->{$_}->updated_column_order for (@{$self->related_TableSpec_order});
	
	# Preserve the existing order, adding only new/unseen related columns:
	push @order, grep { !$seen{$_}++ } @rels;
	
	@{$self->column_order} = @order;
	return @{$self->column_order};
};




has 'multi_rel_columns_indx', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $list = $self->get_Cnf('multi_relationship_column_names') || [];
	
	my %indx = ();
	foreach my $rel (@$list) {
		unless($self->ResultSource->has_relationship($rel)) {
			warn RED.BOLD . "\n\nMulti-rel column error: '$rel' is not a valid " .
				"relationship of ResultSource '" . $self->ResultSource->source_name . 
				"'\n\n" . CLEAR;
			next;
		}
		my $info = $self->ResultSource->relationship_info($rel) || {};
		my $cond = $info->{cond};
		my $h = $cond ? $self->ResultClass->parse_relationship_cond($cond) : {};
		my ($rev_relname) = (keys %{$self->ResultSource->reverse_relationship_info($rel)});
    $indx{$rel} = { %$h, 
			info => $info,
			rev_relname => $rev_relname,
			relname => $rel,
			parent_source => $self->ResultSource->source_name
		};
	}
	
	# -- finally refactored this into simpler code above (with error handling). 
	# Got too carried away with map!!!
	#my %indx = map { $_ => 
	#	{ %{$self->ResultClass->parse_relationship_cond(
	#			$self->ResultSource->relationship_info($_)->{cond}
	#		)}, 
	#		info => $self->ResultSource->relationship_info($_),
	#		rev_relname => (keys %{$self->ResultSource->reverse_relationship_info($_)})[0],
	#		relname => $_
	#	} 
	#} @$list;
	# --
	
	# Add in any defined functions (this all needs to be cleaned up/refactored):
	$self->Cnf_columns->{$_}->{function} and $indx{$_}->{function} = $self->Cnf_columns->{$_}->{function} 
		for (keys %indx);
		
	#scream_color(GREEN,'loading');
	#scream_color(GREEN.BOLD,$_,$self->Cnf_columns->{$_}) for (keys %indx);
	
	#scream(\%indx);

	return \%indx;
}, isa => 'HashRef';



=head2 resolve_dbic_colname

=over 4

=item Arguments: $fieldName, \%merge_join, $get_render_col (bool)

=item Return Value: Valid DBIC 'select'

=back

Returns a value which can be added to DBIC's ->{attr}{select} in order to select the column.

$fieldName is the ExtJS column name to resolve. This contains the full path to the column which
may span multiple joins, for example:

  rel1__rel2__foo

In this case, 'rel1' is a relationship of the local (top-level) source, and rel2 is a relationship
of the 'rel1' source. The \%merge_join argument is passed by reference and modified to contain the 
join needed for the select. In the case, assuming 'foo' is an ordinary column of the 'rel2' source, 
the select/as/join might be the following:

  select  : 'rel2.foo'
  as      : 'rel1__rel2__foo'   # already implied by the $fieldName
  join    : { rel1 => 'rel2' }  # merged into %merge_join

However, 'foo' might not be a column in the relationship of the 'rel2' source - it might be a 
relationship or a virtual column. In these cases, a sub-select/query is generated for the select,
which is dependent on what foo actually is. For multi-rels it is a count of the related rows while
for single rels it is a select of the remote display_column. For virtual columns, it is a 
sub-select of whatever the 'sql' attr is set to for the given virtual_column config.

=cut
sub resolve_dbic_colname {
  my ($self, $fieldName, $merge_join, $get_render_col)= @_;
  $get_render_col ||= 0;

  # $rel is the alias of the last relationship name in the chain --
  #  if $fieldName is 'rel1__rel2__rel3__blah', $rel is 'rel3'
  #
  # $col is the column name in the remote source --
  #  if $fieldName is 'rel1__rel2__rel3__blah', $col is 'blah'
  #
  # $join is the join attr needed to get to $rel/$col
  #  if $fieldName is 'rel1__rel2__rel3__blah', $join is { rel1 => { rel2 => 'rel3' } }
  #  the join needs to be merged into the common %merge_join hash
  #
  # $cond_data contains details about $col when $col is a relationship (otherwise it is undef)
  #  if $fieldName is 'rel1__rel2__rel3__blah', $cond_data contains info about 
  #  the relationship 'blah', which is a relationship of the rel3 source
  my ($rel,$col,$join,$cond_data) = $self->resolve_dbic_rel_alias_by_column_name($fieldName,$get_render_col);

  %$merge_join = %{ merge($merge_join,$join) }
    if ($merge_join and $join);


  if (!defined $cond_data) {
    # $col is a simple column, not a relationship, we're done:
    return "$rel.$col";
  } else {

    # If cond_data is defined, the relation is a multi-relation, and we need to either
    #  join and group-by, or run a sub-query.  If join-and-group-by happens twice, it
    #  breaks COUNT() (because the number of joined rows gets multiplied) so by default
    #  we only use sub-queries.  In fact, join and group-by has a lot of problems on
    #  MySQL and we should probably never use it.
    $cond_data->{function} = $cond_data->{function} || $self->multi_rel_columns_indx->{$fieldName};
    
    # Support for a custom aggregate function
    if (ref($cond_data->{function}) eq 'CODE') {
      # TODO: we should use hash-style parameters
      return $cond_data->{function}->($self,$rel,$col,$join,$cond_data,$fieldName);
    }
    else {
      my $m2m_attrs = $cond_data->{info}->{attrs}->{m2m_attrs};
      if($m2m_attrs) {
        # -- m2m relationship column --
        #
        # Setup the special GROUP_CONCAT render/function
        #
        # This is a partial implementation supporting "m2m" (many_to_many)
        # relationship columns as added by the special result class function:
        #  __PACKAGE__->TableSpec_m2m( 'rel' => 'linkrel', 'foreignrel' );
        # Which needs to be used instead of the built-in __PACKAGE__->many_to_many
        # function. (side note: this is needed for the same reason that 
        # DBIx::Class::IntrospectableM2M was created).
        #
        # This function renders the values as a CSV list, so it is only suitable
        # for many_to_many cases with a limited number of rows (e.g. roles table)
        # which is probably the most common scenario, but certainly not the only
        # one. Also, this CSV list is tied into the functioning of the m2m column
        # editor. It is also db-specific, and only tested is MySQL and SQLite.
        # All these reasons are why I say this implementation is "partial" in
        # its current form.

        my $rel_info = $m2m_attrs->{rinfo};
        my $rev_rel_info = $m2m_attrs->{rrinfo};
      
        # initial hard-coded example the dynamic logic was based on:
        #my $sql = '(' .
        #	# SQLite Specific:
        #	#'SELECT(GROUP_CONCAT(flags.flag,", "))' .
        #	
        #	# MySQL Sepcific:
        #	#'SELECT(GROUP_CONCAT(flags.flag SEPARATOR ", "))' .
        #	
        #	# Generic (MySQL & SQLite):
        #	'SELECT(GROUP_CONCAT(flags.flag))' .
        #	
        #	' FROM ' . $source->from . 
        #	' JOIN `flags` `flags` ON customers_to_flags.flag = flags.flag' .
        #	' WHERE ' . $cond_data->{foreign} . ' = ' . $rel . '.' . $cond_data->{self} . 
        #')';
        
        
        ### TODO: build this using DBIC (subselect_rs as_query? resultset_column ?)
        ### This is unfortunately database specific. It works in MySQL and SQLite, and
        ### should work in any database with the GROUP_CONCAT function. It doesn't work
        ### in PostgrSQL because it doesn't have GROUP_CONCAT. This will have to be implemented
        ### separately first each db. TODO: ask the storage engine for the db type and apply
        ### a correct version of the function:
        ###   UPDATE: Now works with PostgreSQL - PR #150, mst++, TBSliver++
        
        # TODO: support cross-db relations
        
        local *_ = $self->schema->storage->sql_maker->curry::_quote;

        my $rel_table_raw = $self->schema->source($rel_info->{source})->name;
        my $rev_rel_table_raw = $self->schema->source($rev_rel_info->{source})->name;

        my $rel_table = _($rel_table_raw);
        my $rev_rel_table = _($rev_rel_table_raw);
        
        my $rel_alias = (reverse split(/\./,$rel_table_raw))[0];
        my $rev_rel_alias = (reverse split(/\./,$rev_rel_table_raw))[0];
        
        my $rel_join_col = _(join '.', $rel_alias, $rev_rel_info->{cond_info}{self});
        my $rev_rel_join_col = _(join '.', $rev_rel_alias, $rev_rel_info->{cond_info}{foreign});
        
        my $rev_rel_col = _(join '.', $rel_alias, $rel_info->{cond_info}{foreign});
        my $rel_col = _(join '.', $rel, $cond_data->{self});

        my $sql = do {

          my $sqlt_type = $self->schema->storage->sqlt_type;
          my $concat = do {
            if ($sqlt_type eq 'PostgreSQL') {
              "STRING_AGG($rev_rel_join_col, ',')"
            } else {
              "GROUP_CONCAT($rev_rel_join_col)";
            }
          };
          join(' ', '(',
            "SELECT($concat)",
            " FROM $rel_table",
            " JOIN $rev_rel_table",
            "  ON $rel_join_col = $rev_rel_join_col",
            " WHERE $rev_rel_col = $rel_col",
          ')');

        };

        return { '' => \$sql, -as => $fieldName };		
      }
      else {

        die '"parent_source" missing from $cond_data -- cannot correlate sub-select for "$col"'
          unless ($cond_data->{parent_source});
        
        my $p_source = $self->schema->source($cond_data->{parent_source});
        my $rel_attrs = $p_source->relationship_info($col)->{attrs};
        
        my $rel_rs;
        
        # Github Issue #95
        if(!$rel_attrs->{where}) {
          # The new correlate logic does not work with relationships with a 'where'
          $rel_rs = $self->_correlate_rs_rel(
            $p_source->resultset->search_rs(undef,{ alias => $rel }), 
            $col
          );
        }
        else {
          ##########################################################################################
          # If there is a 'where' we have to fall back to the old logic -- FIXME!!!
          ##########################################################################################
          my $source = $self->schema->source($cond_data->{info}{source});

          # $rel_rs is a resultset object for $col when $col is the name of a relationship (which
          # it is because we're here). We are using $rel_rs to create a sub-query for a count.
          # We are suppling a custom alias that is not likely to conflict with the rest of the
          # query.
          $rel_rs = $source->resultset_class
            ->new($source, { alias => "${col}_alias" })
            ->search_rs(undef,{
              %{$source->resultset_attributes || {}},
              %{$cond_data->{info}{attrs} || {}}
            });

          # --- Github Issue #40 ---
          # This was the original, manual condition generation which only supported
          # single-key relationship conditions (and not multi-key or CodeRef):
          #my $cond = { "${rel}_alias.$cond_data->{foreign}" => \[" = $rel.$cond_data->{self}"] };

          # This is the new way which uses DBIC's internal machinery in the proper way
          # and works for any multi-rel cond type, including CodeRef:
          # UPDATE (#68): Starting in DBIC 0.08280 this invocation is producing a
          # warning because it doesn't know what "${col}_alias" is
          # (we're declaring it as the alias in $rel_rs above). It thinks
          # it should be a relationship, but it is just the local ('me')
          # alias (from the perspective of $rel_rs)
          my $cond = do {
            # TEMP/FIXME - This is not the way _resolve_condition is supposed to be called
            # and this will stop working in the next major DBIC release. _resolve_condition
            # needs to be called with a valid relname which we do not have in this case. In
            # order to fix this, we need to call _resolve_condition from one rel higher so
            # we can pass $col as the rel. For now we are just ignoring the warning which
            # we know is being produced. See Github Issue #68
            local $SIG{__WARN__} = sub {};
            $source->_resolve_condition(
              $cond_data->{info}{cond},
              $rel_rs->current_source_alias, #<-- the self alias ("${col}_alias" as set above)
              $rel, #<-- the foreign alias
            )
          };
          # ---

          $rel_rs = $rel_rs->search_rs($cond);
          ##########################################################################################
        }

        if($cond_data->{info}{attrs}{accessor} eq 'multi') {
          # -- standard multi relationship column --
          # This is where the count sub-query is generated that provides
          # the numeric count of related items for display in multi rel columns.
          return { '' => $rel_rs->count_rs->as_query, -as => $fieldName };
        }
        else {
          # -- NEW: virtualized single relationship column --
          # Returns the related display_column value as a subquery using the same
          # technique as the count for multi-relationship columns
          my $source = $self->schema->source($cond_data->{info}{source});
          my $display_column = $source->result_class->TableSpec_get_conf('display_column')
            or die "Failed to get display_column";
          return { '' => $rel_rs->get_column($display_column)->as_query, -as => $fieldName };
        }
      }
    }
  }
}

# Copied directly from DBIx::Class::Helper::ResultSet::CorrelateRelationship::correlate
sub _correlate_rs_rel {
   my ($self, $Rs, $rel) = @_;
 
   my $source = $Rs->result_source;
   my $rel_info = $source->relationship_info($rel);
 
   return $source->related_source($rel)->resultset
      ->search(scalar $source->_resolve_condition(
         $rel_info->{cond},
         "${rel}_alias",
         $Rs->current_source_alias,
         $rel
      ), {
         alias => "${rel}_alias",
      })
}

sub resolve_dbic_rel_alias_by_column_name  {
	my $self = shift;
	my $fieldName = shift;
	my $get_render_col = shift || 0; 
	
	# -- applies only to relationship columns and currently only used for sort:
	#  UPDATE: now also used for column_summaries
	if($get_render_col) {
		my $render_col = $self->relationship_column_render_column_map->{$fieldName};
		$fieldName = $render_col if ($render_col);
	}
	# --
	
	my $rel = $self->column_name_relationship_map->{$fieldName};
	unless ($rel) {
		
		my $join = $self->needed_join;
		my $pre = $self->column_prefix;
		$fieldName =~ s/^${pre}//;
		
		# Special case for "multi" relationships... they return the related row count
		my $cond_data = $self->multi_rel_columns_indx->{$fieldName};
		if ($cond_data) {
			# Need to manually build the join to include the rel column:
			# Update: we no longer add this to the join, because we use a sub-select
			#   to query the multi-relation, and don't want a product-style join in
			#   the top-level query.
			#my $rel_pre = $self->relspec_prefix;
			#$rel_pre .= '.' unless ($rel_pre eq '');
			#$rel_pre .= $name;
			#$join = $self->chain_to_hash(split(/\./,$rel_pre));
			
			# ---
			# What was the purpose of this? The above was commented out and this was added 
			# in its place (Mike?) it doesn't seem to do anything but break multi-rel columns
			# when joined via several intermediate single rels. Removed 2012-07-07 by HV.
			#$join = $self->chain_to_hash($self->relspec_prefix)
			#	if length $self->relspec_prefix;
			# ---
			
			return ('me',$fieldName,$join,$cond_data);
		}
		
		
		## ----
		## NEW: VIRTUAL COLUMNS SUPPORT (added 2012-07-06 by HV)
		## Check if this column has been setup via 'add_virtual_columns' in the 
		## Result class and look for special attributes 'function' (higher priority) 
		## or 'sql' (lower priority) for virtualizing the column in the
		## query. This is similar to a multi rel column, but is still a column
		## and not a relationship (TODO: combine this logic with the older multi
		## rel column logic)
		if ($self->ResultClass->has_virtual_column($fieldName)) {
			my $info = $self->ResultClass->column_info($fieldName) || {};
			my $function = $info->{function} || sub {
				my ($self,$rel,$col,$join,$cond_data2,$name2) = @_;
				my $sql = $info->{sql} || 'SELECT(NULL)';
				# also see RapidApp::DBIC::Component::VirtualColumnsExt
				$sql = $info->{sql}->($self->ResultClass, $col) if ref $sql eq 'CODE';
				
				# ** translate 'self.' into the relname of the current context. This
				# should either be 'me.' or the join name. This logic is important
				# to be able to have an sql snippet defined in a Result class that will
				# work across different join/perspectives.
				$sql =~ s/self\./${rel}\./g;
				$sql =~ s/\`self\`\./\`${rel}\`\./g; #<-- also support backtic quoted form (quote_sep)
				# **
				
				return { '' => \"($sql)", -as => $col };
			};
			$cond_data = { function => $function };
			
			if ($info->{join}) {
				my @prefix = split(/\./,$self->relspec_prefix);
				push @prefix, $info->{join};
				$join = $self->chain_to_hash(@prefix);
			}
			
			return ('me',$fieldName,$join,$cond_data);
		}
		## ----
    ## --- NEW: Virtual Single Relationship Column (Github Issue #40)
    elsif($self->ResultClass->has_relationship($fieldName)){
      my $cnf = $self->Cnf_columns->{$fieldName};
      if ($cnf && $cnf->{virtualized_single_rel}) {
        # This is emulating the existing format being passed around and
        # used for relationship columns (see multi_rel_columns_indx). This
        # is going to be totally refactored and simplified later (also,
        # note that 'me' has no actual meaning and is a throwback)
        return ('me',$fieldName,$join,{ 
          relname => $fieldName,
          info => $self->ResultClass->relationship_info($fieldName),
          parent_source => $self->ResultSource->source_name
        });
      }
    }
    # ---
		
		return ('me',$fieldName,$join);
	}
	
	my $TableSpec = $self->related_TableSpec->{$rel};
	my ($alias,$dbname,$join,$cond_data) = $TableSpec->resolve_dbic_rel_alias_by_column_name($fieldName,$get_render_col);
	$alias = $rel if ($alias eq 'me');
	return ($alias,$dbname,$join,$cond_data);
}


# This exists specifically to handle relationship columns:
has 'custom_dbic_rel_aliases' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

# Updated: the last item may now be a ref in which case it will be set 
# as the last value instead of {}
sub chain_to_hash {
	my $self = shift;
	my @chain = @_;
	
	my $hash = {};
	my $last;

	my @evals = ();
	my $i = 0;
	foreach my $item (@chain) {
		my $right = '{}';
		my $set_end = 0;
		if($i++ == 0) {
			$last = pop @chain;
			if(ref $last) {
				$right = '$last';
				$set_end = 1;
			}
			else {
				# Put it back if its not a ref:
				push @chain, $last;
			}
		}
		my $left = '$hash->{\'' . join('\'}->{\'',@chain) . '\'}';		
		unshift @evals, $left . ' = ' . $right;
		pop @chain unless ($set_end);
	}
	eval $_ for (@evals);
	
	return $hash;
}


has 'relationship_column_render_column_map', is => 'ro', isa => 'HashRef', default => sub {{}};
sub get_relationship_column_cnf {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  # New: apply profiles early so any profiles which set rel column options
  # are available (e.g. 'soft_rel' which sets 'auto_editor_params' -- added for #77)
  if ($opt{profiles}) {
    my $o = RapidApp::TableSpec::Column::Profile->_apply_profiles_soft(\%opt);
    %opt = %$o;
  }

  return $self->get_virtual_relationship_column_cnf($rel,\%opt) if ($opt{virtualized_single_rel});
	return $self->get_multi_relationship_column_cnf($rel,\%opt) if ($self->multi_rel_columns_indx->{$rel});
	
	my $conf = \%opt;
	my $info = $conf->{relationship_info} or die "relationship_info is required";
	
  my $table = $self->ResultClass->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
	my $err_info = "rel col: " . $table . ".$rel - " . Dumper($conf);
	
	die "displayField is required ($err_info)" unless (defined $conf->{displayField});
	die "valueField is required ($err_info)" unless (defined $conf->{valueField});
	die "keyField is required ($err_info)" unless (defined $conf->{keyField});
	
	my $Source = try{$self->ResultSource->related_source($rel)} catch {
		warn RED.BOLD . $_ . CLEAR;
		return undef;
	} or return undef; 

	
	# --- Disable quick searching on rel cols with virtual display_column
	# If the display column of the remote result class is virtual we turn
	# off quick searching. This *could* be supported in the future; it would require
	# some special coding. It is probably not something that should be on per
	# default anyway, because searching on a virtual column could be slow 
	# (see the complex HAVING stuff for multifilters)**
	$conf = { %$conf,
    # TODO: this can probably be enabled much easier now, just like column summaries (#93)
    #   the complex 'HAVING' stuff mentioned above has since been unfactored (#51)
		no_quick_search => \1,
	} if (try{$self->ResultSource->related_class($rel)->has_virtual_column($conf->{displayField})});
	#
	# ---

	my $render_col = $self->column_prefix . $rel . $self->relation_sep . $conf->{displayField};
	my $key_col = $self->column_prefix . $rel . $self->relation_sep . $conf->{valueField};
	my $upd_key_col = $self->column_prefix . $conf->{keyField};
	
	# -- Assume the the column profiles of the display column:
	my $relTS = $self->related_TableSpec->{$rel};
	if($relTS) {
		my $relconf = $relTS->Cnf_columns->{$conf->{displayField}};
		$conf->{profiles} = $relconf->{profiles} || $conf->{profiles};
    
    # New: special exception - do not assume the 'autoinc' profile which
    # disables add/edit for the purposes of the *local* table. This does
    # not apply to the relationship column context, and we need to remove
    # it to prevent relationship columns with auto_increment display_column
    # from being forced read-only. This is a bit hackish - TODO/FIXME
    @{$conf->{profiles}} = grep { $_ ne 'autoinc' } @{$conf->{profiles}}
      if($conf->{profiles});
	}
	# --
  
	my $colname = $self->column_prefix . $rel;
	
	# -- 
	# Store the render column that is associated with this relationship column
	# Currently we use this for sorting on relationship columns:
	$self->relationship_column_render_column_map->{$colname} = $render_col;
	# Also store in the column itself - added for excel export - is this redundant to above? probably. FIXME
	$conf->{render_column} = $render_col; 
	# --

	my $rows;
	my $read_raw_munger = sub {
		$rows = (shift)->{rows};
		$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
		foreach my $row (@$rows) {
			$row->{$colname} = $row->{$upd_key_col} if (exists $row->{$upd_key_col});
		}
	};
	
	my $required_fetch_columns = [ 
		$render_col,
		$key_col,
		$upd_key_col
	];
	
	$conf->{renderer} = 'Ext.ux.showNull' unless ($conf->{renderer});
	
	# ---
	# We need to set 'no_fetch' to prevent DbicLink2 trying to fetch the rel name
	# as a column -- EXCEPT if the rel name is ALSO a column name:
	my $is_also_local_col = $self->ResultSource->has_column($rel) ? 1 : 0;
	$conf->{no_fetch} = 1 unless ($is_also_local_col);
	# ---
	
	
	$conf = { %$conf, 
		
		#no_quick_search => \1,
		#no_multifilter => \1,
		
		query_id_use_column => $upd_key_col,
		query_search_use_column => $render_col,
		
		#required_fetch_colspecs => [],
		
		required_fetch_columns => $required_fetch_columns,
		
		read_raw_munger => RapidApp::Handler->new( code => $read_raw_munger ),
		#update_munger => RapidApp::Handler->new( code => $update_munger ),
	};
	
	my $cur_renderer = $conf->{renderer};
  
  my $is_phy = $conf->{is_phy_colname};
	
	# NEW: use simpler DbicRelRestRender to generate a REST link. Check to make sure
	# the relationship references the *single* primary column of the related row
	my $use_rest = 1; #<-- simple toggle var
	my $cond_data = try{$self->ResultClass->parse_relationship_cond($info->{cond})};
	my $rel_rest_key = try{$self->ResultSource->related_class($rel)->getRestKey};
	if($use_rest && $cond_data && $rel_rest_key && $conf->{open_url}) {
		# Toggle setting the 'key' arg in the link (something/1234 vs something/key/1234)
		my $rest_key = $rel_rest_key eq $cond_data->{foreign} ? undef : $cond_data->{foreign};
		$conf->{renderer} = jsfunc(
			'function(value, metaData, record) { return Ext.ux.RapidApp.DbicRelRestRender({' .
				'value:value,record:record,' .
				'key_col: "' . $key_col . '",' .
				'render_col: "' . $render_col . '",' .
				'open_url: "' . $conf->{open_url} . '"' .
				( $rest_key ? ',rest_key:"' . $rest_key . '"' : '') .
        ( $is_phy ? ',is_phy_colname: true' : '') .
			'})}',$cur_renderer
		);
	}
	# Fall back to the older loadCnf inlineLink:
	else {
		$conf->{renderer} = jsfunc(
			'function(value, metaData, record, rowIndex, colIndex, store) {' .
				'return Ext.ux.RapidApp.DbicSingleRelationshipColumnRender({' .
					'value:value,metaData:metaData,record:record,rowIndex:rowIndex,colIndex:colIndex,store:store,' .
					'render_col: "' . $render_col . '",' .
					'key_col: "' . $key_col . '",' .
					'upd_key_col: "' . $upd_key_col . '"' .
					( $conf->{open_url} ? ",open_url: '" . $conf->{open_url} . "'" : '' ) .
				'});' .
			'}', $cur_renderer
		);
	}
	
	
  ############# ---
  $conf->{editor} = $conf->{editor} || {};
  $conf->{auto_editor_params} = $conf->{auto_editor_params} || {};
  
  # ----
  #  Set allowBlank according to the db schema of the key column. This is handled
  #  automatically in normal columns in the profile stuff, but has to be done special
  #  for relationship columns:
  my $cinfo = exists $conf->{keyField} ? $self->ResultSource->column_info($conf->{keyField}) : undef;
  if($cinfo and defined $cinfo->{is_nullable} and ! exists $conf->{editor}->{allowBlank}) {
    # This logic is specific instead of being a blanket boolean choice. If there is some other,
    # different, unexpected value for 'is_nullable', don't set allowBlank one way or the other
    $conf->{editor}->{allowBlank} = \0 if($cinfo->{is_nullable} == 0);
    if($cinfo->{is_nullable} == 1) {
      $conf->{editor}->{allowBlank} = \1;
      # This setting will only have an effect if the editor is AppCombo2 based:
      $conf->{editor}->{allowSelectNone} = \1;
    }
  }
  #  same for 'default_value', if defined (again, this logic already happens for normal columns):
  $conf->{editor}->{value} = $cinfo->{default_value} if ($cinfo && exists $cinfo->{default_value});
  #  TODO: refactor so the 'normal' column logic from 'profiles' etc gets applied here so this
  #  duplicate logic isn't needed
  # ----

  $conf->{auto_editor_params} = $conf->{auto_editor_params} || {};


  my $aet = $conf->{auto_editor_type};
  if($aet eq 'combo' || $aet eq 'dropdown') {
  
    my $params = {
      valueField		=> $conf->{valueField},
      displayField	=> $conf->{displayField},
      name				=> $colname,
      ResultSet		=> $Source->resultset,
      record_pk		=> $conf->{valueField},
      # Optional custom ResultSet params applied to the dropdown query
      RS_condition	=> $conf->{RS_condition} ? $conf->{RS_condition} : {},
      RS_attr			=> $conf->{RS_attr} ? $conf->{RS_attr} : {},
    };
    
    $params->{type_filter} = 1 if ($aet eq 'combo');
  
    my $table = $self->ResultClass->table;
    $table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
    my $module_name = 'combo_' . $table . '_' . $colname;
    my $Module = $self->get_or_create_rapidapp_module( $module_name,
      class	  => 'RapidApp::Module::DbicCombo',
      params  => { %$params, %{ $conf->{auto_editor_params} } }
    );
    
    if($conf->{editor}) {
      if($conf->{editor}->{listeners}) {
        my $listeners = delete $conf->{editor}->{listeners};
        $Module->add_listener( $_ => $listeners->{$_} ) for (keys %$listeners);
      }
      $Module->apply_extconfig(%{$conf->{editor}}) if (keys %{$conf->{editor}} > 0);
    }
    
    $conf->{editor} =  $Module->content;
  }
  
  elsif($aet eq 'grid') {
    
    die "display_columns is required with 'grid' auto_editor_type" 
      unless (defined $conf->{display_columns});
    
    my $custOnBUILD = $conf->{auto_editor_params}->{onBUILD} || sub{};
    my $onBUILD = sub {
      my $self = shift;		
      $self->apply_to_all_columns( hidden => \1 );
      $self->apply_columns_list($conf->{display_columns},{ hidden => \0 });
      return $custOnBUILD->($self);
    };
    $conf->{auto_editor_params}->{onBUILD} = $onBUILD;
    
    my $table = $self->ResultClass->table;
    $table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
    my $grid_module_name = 'grid_' . $table . '_' . $colname;
    my $GridModule = $self->get_or_create_rapidapp_module( $grid_module_name,
      class	=> 'RapidApp::Module::DbicGrid',
      params	=> {
        ResultSource => $Source,
        include_colspec => [ '*', '{?:single}*.*' ],
        #include_colspec => [ ($conf->{valueField},$conf->{displayField},@{$conf->{display_columns}}) ],
        title => '',
        %{ $conf->{auto_editor_params} }
      }
    );
    
    my $title = $conf->{header} ? 'Select ' . $conf->{header} : 'Select Record';
    $conf->{editor} = { 

      # These can be overridden
      header			=> $conf->{header},
      win_title		=> $title,
      win_height		=> 450,
      win_width		=> 650,
      
      %{$conf->{editor}},
      
      # These can't be overridden
      name		=> $colname,
      xtype => 'datastore-app-field',
      valueField		=> $conf->{valueField},
      displayField	=> $conf->{displayField},
      load_url	=> $GridModule->base_url,
      
    };
  }
  
  elsif($aet eq 'custom') {
    
    # Use whatever is already in 'editor' plus some sane defaults
    my $title = $conf->{header} ? 'Select ' . $conf->{header} : 'Select Record';
    $conf->{editor} = { 

      # These can be overridden
      header			=> $conf->{header},
      win_title		=> $title,
      win_height		=> 450,
      win_width		=> 650,
      valueField		=> $conf->{valueField},
      displayField	=> $conf->{displayField},
      name			=> $colname,
      
      %{$conf->{auto_editor_params}},
      %{$conf->{editor}},
    };
  }
  ############# ---

  return (name => $colname, %$conf);
}


sub get_multi_relationship_column_cnf {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	return $self->get_m2m_multi_relationship_column_cnf($rel,\%opt) 
		if ($opt{relationship_cond_data}->{attrs}->{m2m_attrs});
	
	my $conf = \%opt;
	
	my $rel_data = clone($conf->{relationship_cond_data});
	
	## -- allow override of the associated TabsleSpec cnfs from the relationship attrs:
	$conf->{title_multi} = delete $rel_data->{attrs}->{title_multi} if ($rel_data->{attrs}->{title_multi});
	$conf->{multiIconCls} = delete $rel_data->{attrs}->{multiIconCls} if ($rel_data->{attrs}->{multiIconCls});
	$conf->{open_url_multi} = delete $rel_data->{attrs}->{open_url_multi} if ($rel_data->{attrs}->{open_url_multi});
	$conf->{open_url_multi_rs_join_name} = delete $rel_data->{attrs}->{open_url_multi_rs_join_name} if ($rel_data->{attrs}->{open_url_multi_rs_join_name});
	delete $rel_data->{attrs}->{cascade_copy};
	delete $rel_data->{attrs}->{cascade_delete};
	delete $rel_data->{attrs}->{join_type};
	delete $rel_data->{attrs}->{accessor};
	
	$rel_data->{attrs}->{join} = [ $rel_data->{attrs}->{join} ] if (
		defined $rel_data->{attrs}->{join} and
		ref($rel_data->{attrs}->{join}) ne 'ARRAY'
	);
	
	if($rel_data->{attrs}->{join}) {
		@{$rel_data->{attrs}->{join}} = grep { $_ ne $conf->{open_url_multi_rs_join_name} } @{$rel_data->{attrs}->{join}};
		delete $rel_data->{attrs}->{join} unless (scalar @{$rel_data->{attrs}->{join}} > 0);
	}
	
	
	my $title = $conf->{title_multi} ? $conf->{title_multi} : 'Related "' . $rel . '" Rows';
	
	my $loadCfg = {
		title => $title,
		iconCls => $conf->{multiIconCls} ,
		autoLoad => {
			url => $conf->{open_url_multi},
			params => {}
		}
	};
	
	my $div_open = 
		'<div' . 
		( $conf->{multiIconCls} ? ' class="with-inline-icon ' . $conf->{multiIconCls} . '"' : '' ) . '><span>' .
		$title .
		'&nbsp;<span class="superscript-navy">';
	
	my $cur_renderer = $conf->{renderer};
  
  my $open_url = $self->ResultClass->TableSpec_get_conf('open_url');
  my $rel_rest_key = try{$self->ResultClass->getRestKey};
  my $orgnCol = $rel_rest_key ? join('',$self->column_prefix,$rel_rest_key) : undef;
	
  $conf->{required_fetch_columns} ||= [];
  push @{$conf->{required_fetch_columns}}, $orgnCol if ($orgnCol);
  
  my $rSelfCol = $rel_data->{self} ? join('',$self->column_prefix,$rel_data->{self}) : undef;
  push @{$conf->{required_fetch_columns}}, $rSelfCol if ($rSelfCol && $rSelfCol ne ($orgnCol || ''));

  # Allow old apps to turn off using this source as a rest origin and force fallback to
  # the fugly, original loadCnf inlineLink
	my $use_rest = 
    $rel_data->{attrs}{allow_rel_rest_origin}
    // try{$rel_data->{class}->TableSpec_get_conf('allow_rel_rest_origin')};
    
  $use_rest = 1 unless (defined $use_rest);
	if($use_rest && $orgnCol && $open_url) {
		$conf->{renderer} = jsfunc(
			'function(value, metaData, record) { return Ext.ux.RapidApp.DbicRelRestRender({' .
				'value:value,record:record,' .
				"disp: '" . $div_open . "' + value + '</span>'," .
				'key_col: "' . $orgnCol . '",' .
				'open_url: "' . $open_url . '",' .
				'multi_rel: true,' .
				'rs: "' . $rel . '"' . 
			'})}',$cur_renderer
		);
	}
	else {

		# Fall back to the old thick, ugly loadCnf inlineLink:
    #  This code path should never happen with RapidDbic, but will still happen for
    #  manual setups where there is no 'open_url' or other missing TableSpec data:
		$conf->{renderer} = $rel_data->{self} ? jsfunc(
			'function(value, metaData, record, rowIndex, colIndex, store) {' .
				"var div_open = '$div_open';" .
				"var disp = div_open + value + '</span>';" .
				
				#'var key_key = ' .
				'var key_val = record.data["' . $rSelfCol . '"];' .
				
				'var attr = ' . RapidApp::JSON::MixedEncoder::encode_json($rel_data->{attrs}) . ';' .
				
				( # TODO: needs to be generalized better
					$conf->{open_url_multi} ?
						'if(key_val && value && value > 0 && !Ext.ux.RapidApp.NO_DBIC_REL_LINKS) {' .
							'var loadCfg = ' . RapidApp::JSON::MixedEncoder::encode_json($loadCfg) . ';' .
							
							'var join_name = "' . $conf->{open_url_multi_rs_join_name} . '";' .
							
							'var cond = {};' .
							'cond[join_name + ".' . $rel_data->{foreign} . '"] = key_val;' .
							
							#'var attr = {};' .
							'if(join_name != "me"){ if(!attr.join) { attr.join = []; } attr.join.push(join_name); }' .
							
							# Fix!!!
							'if(join_name == "me" && Ext.isArray(attr.join) && attr.join.length > 0) { join_name = attr.join[0]; }' .
							
							#Fix!!
							'loadCfg.autoLoad.params.personality = join_name;' .
							
							#'loadCfg.autoLoad.params.base_params = Ext.encode({' .
							#	'resultset_condition: Ext.encode(cond),' .
							#	'resultset_attr: Ext.encode(attr)' .
							#'});' .
							
							'loadCfg.autoLoad.params.base_params_base64 = base64.encode(Ext.encode({' .
								'resultset_condition: Ext.encode(cond),' .
								'resultset_attr: Ext.encode(attr)' .
							'}));' .
							
							'var href = "#loadcfg:" + Ext.urlEncode({data: Ext.encode(loadCfg)});' .
							'disp += "&nbsp;" + Ext.ux.RapidApp.inlineLink(' .
								'href,"<span>open</span>","ra-nav-link ra-icon-magnify-tiny",null,"Open/view: " + loadCfg.title' .
							');' .
						'}'
					:
						''
				) .
				"disp += '</span></div>';" .
				'return disp;' .
			'}', $cur_renderer
		) : jsfunc( 
      # New: skip all the above open link logic in advance if we don't have
      # self/foreign rel data. Added for Github Issue #40 now that it is 
      # possible for it to be missing (just means there will be no open link):
      join("\n", 
        'function(value, metaData, record, rowIndex, colIndex, store) {',
          "var div_open = '$div_open';",
          "return div_open + value + '</span></span></div>';",
        '}'
      )
   );
	}
	

	$conf->{name} = join('',$self->column_prefix,$rel);
	
	return %$conf;
}

has 'm2m_rel_columns_indx', is => 'ro', isa => 'HashRef', default => sub {{}};

sub get_m2m_multi_relationship_column_cnf {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $conf = \%opt;
	
	$conf->{no_quick_search} = \1;
	$conf->{no_summary} = \1;
	
	$conf->{renderer} = jsfunc 'Ext.ux.RapidApp.prettyCsvRenderer';
	
	my $m2m_attrs = $conf->{relationship_cond_data}->{attrs}->{m2m_attrs};
	my $rinfo = $m2m_attrs->{rinfo};
	my $rrinfo = $m2m_attrs->{rrinfo};
	
	my $colname = $self->column_prefix . $rel;
	$conf->{name} = $colname;
	
	$self->m2m_rel_columns_indx->{$colname} = 1;
	
	### This is the initial editor type 'multi-check-combo' which is only suitable if
	### there are a relatively limited number of remote linkable rows (such as roles)
	### TODO: add more types (like combo vs grid in single relationship combos) such
	### as one that is paged and can support lots of rows to select from
	
	### Also, TODO: add support for different diplayField and valueField. This will
	### require setting up a whole additional relationship for rendering. Also, need
	### to add the ability to customize the render mode. Currently it is hard coded to
	### csv list of key/link values. It will always have to be something like this, but
	### it could render differently. If there are many values, there might be a better way
	### to render/display, such as a count like the default regular multi rel column
	
	my $schema = $self->ResultSource->schema;
	my $Source = $schema->source($rrinfo->{source});
	
	my $table = $self->ResultClass->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
	my $module_name = 'm2mcombo_' . $table . '_' . $colname;
	my $Module = $self->get_or_create_rapidapp_module( $module_name,
		class	=> 'RapidApp::Module::DbicCombo',
		params	=> {
			valueField		=> $rrinfo->{cond_info}->{foreign},
			displayField	=> $rrinfo->{cond_info}->{foreign},
			name			=> $colname,
			ResultSet		=> $Source->resultset,
			record_pk		=> $rrinfo->{cond_info}->{foreign},
			# Optional custom ResultSet params applied to the dropdown query
			RS_condition	=> $conf->{RS_condition} ? $conf->{RS_condition} : {},
			RS_attr			=> $conf->{RS_attr} ? $conf->{RS_attr} : {},
			#%{ $conf->{auto_editor_params} },
		}
	);
	$Module->apply_extconfig( xtype => 'multi-check-combo' );
	
	$conf->{editor} = $conf->{editor} || {};
	
	# allowBlank per-default. There are no database-level rules for "nullable" since the
	# column is virtual and has no schema/properties
	$conf->{editor}->{allowBlank} = \1 unless (exists $conf->{editor}->{allowBlank});
	
	if($conf->{editor}->{listeners}) {
		my $listeners = delete $conf->{editor}->{listeners};
		$Module->add_listener( $_ => $listeners->{$_} ) for (keys %$listeners);
	}
	$Module->apply_extconfig(%{$conf->{editor}}) if (keys %{$conf->{editor}} > 0);
	
	$conf->{editor} =  $Module->content;
	
	return %$conf;
}


# TODO: consolidate/simplify all "virtual" relationship columns here. Multi-relationship
# columns are themselves a virtual column...
sub get_virtual_relationship_column_cnf {
  my $self = shift;
  my $rel = shift;
  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  my $conf = { 
    %opt, 
    name => join('',$self->column_prefix,$rel)
  };
  
  my $cur_renderer = $conf->{renderer};
  
  my $rel_rest_key = try{$self->ResultClass->getRestKey};
  my $orgnCol = $rel_rest_key ? join('',$self->column_prefix,$rel_rest_key) : undef;
  
  $conf->{required_fetch_columns} ||= [];
  push @{$conf->{required_fetch_columns}}, $orgnCol if ($orgnCol);

  my $use_rest = 1;
  if($use_rest && $orgnCol) {
    my $open_url = $self->ResultClass->TableSpec_get_conf('open_url');
    $conf->{renderer} = jsfunc( join('',
      'function(value, metaData, record) { return Ext.ux.RapidApp.DbicRelRestRender({',
        'value:value,',
        'record:record,',
        'key_col: "',$orgnCol,'",',
        'open_url: "',$open_url,'",',
        'rs: "',$rel,'"',
      '})}'
    ),$cur_renderer);
  }
    
  return %$conf;
}


sub get_or_create_rapidapp_module {
	my $self = shift;
	my $name = shift or die "get_or_create_rapidapp_module(): Missing module name";
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

	my $rootModule = RapidApp->_rootModule or die "Failed to find RapidApp Root Module!!";
	
	$rootModule->apply_init_modules( tablespec => 'RapidApp::Module' ) 
		unless ( $rootModule->has_module('tablespec') );
	
	my $TMod = $rootModule->Module('tablespec');
	
	$TMod->apply_init_modules( $name => \%opt ) unless ( $TMod->has_module($name) );
	
	my $Module = $TMod->Module($name);
	$Module->call_ONREQUEST_handlers;
	$Module->DataStore->call_ONREQUEST_handlers;
	
	return $Module;
}

1;
