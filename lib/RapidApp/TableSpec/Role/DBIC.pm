package RapidApp::TableSpec::Role::DBIC;
use strict;
use Moose::Role;
use Moose::Util::TypeConstraints;

use RapidApp::Include qw(sugar perlutil);

use Text::Glob qw( match_glob );
use Text::WagnerFischer qw(distance);
use Clone qw( clone );

has 'ResultClass' => ( is => 'ro', isa => 'Str' );

has 'data_type_profiles' => ( is => 'ro', isa => 'HashRef', default => sub {{
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
}});


around BUILDARGS => sub {
	my $orig = shift;
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# Exclude colspecs that start with #
	@{$opt{include_colspec}} = grep { !/^#/ } @{$opt{include_colspec}} 
		if (ref($opt{include_colspec}) eq 'ARRAY');
	
	return $self->$orig(%opt);
};

sub BUILD {}
after BUILD => sub {
	my $self = shift;
	
	my $class = $self->ResultClass;

	my $cols = $self->init_config_column_properties;
	my %inc_cols = map { $_ => $cols->{$_} || {} } $self->filter_base_columns($class->columns);

	foreach my $col (keys %inc_cols) {
		my $info = $class->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $self->data_type_profiles->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile; 
		
		$inc_cols{$col} = merge($inc_cols{$col},{ 
			name => $self->column_prefix . $col,
			profiles => \@profiles 
		});
	}
	
	my %seen = ();
	my @order = grep { !$seen{$_}++ && exists $inc_cols{$_} } @{$self->init_config_column_order},keys %inc_cols;
	$self->add_columns($inc_cols{$_}) for (@order);
};

has 'init_config_column_properties' => ( 
	is => 'ro', 
	isa => 'HashRef',
	lazy => 1,
	default => sub {
		my $self = shift;
		
		my $class = $self->ResultClass;
		return {} unless ($class->can('TableSpec_cnf'));
		
		my $cols = {};
		
		# lower precidence:
		$cols = merge($cols,$class->TableSpec_cnf->{'column_properties_ordered'}->{data})
			if ($class->TableSpec_has_conf('column_properties_ordered'));
		
		# higher precidence:
		$cols = merge($cols,$class->TableSpec_cnf->{'column_properties'}->{data})
			if ($class->TableSpec_has_conf('column_properties'));
		
		return $cols;
	}
);
has 'init_config_column_order' => ( 
	is => 'ro', 
	isa => 'ArrayRef',
	lazy => 1,
	default => sub {
		my $self = shift;
		
		my @order = ();
		
		my $class = $self->ResultClass;
		return [$class->columns] unless ($class->can('TableSpec_cnf')); 
			
		push @order, @{$class->TableSpec_cnf->{'column_properties_ordered'}->{order}}
			if ($class->TableSpec_has_conf('column_properties_ordered'));
			
		push @order, $class->columns; # <-- native dbic column order has precidence over the column_properties order
			
		push @order, @{$class->TableSpec_cnf->{'column_properties'}->{order}}
			if ($class->TableSpec_has_conf('column_properties'));
		
		# fold together removing duplicates:
		my %seen = ();
		@order = grep { !$seen{$_}++ } @order;
		
		my $ovrs = $class->TableSpec_cnf->{column_order_overrides} or return \@order;
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

		%seen = ();
		return [ grep { !$seen{$_}++ } @order ];
	}
);




=head1 ColSpec format 'include_colspec'

The include_colspec attribute defines joins and columns to include. It consists 
of a list of "ColSpecs"

The ColSpec format is a string format consisting of consists of 2 parts: an 
optional 'relspec' followed by a 'colspec'. The last dot "." in the string separates
the relspec on the left from the colspec on the right. A string without periods
has no (or an empty '') relspec.

The relspec is a chain of relationship names delimited by dots. These must be exact
relnames in the correct order. These are used to create the base DBIC join attr. For
example, this relspec (to the left of .*):

 object.owner.contact.*
 
Would become this join:

 { object => { owner => 'contact' } }
 
Multple overlapping rels are collapsed in an inteligent manner. For example, this:

 object.owner.contact.*
 object.owner.notes.*
 
Gets collapsed into this join:

 { object => { owner => [ 'contact', 'notes' ] } }
 
The colspec to the right of the last dot "." is a glob pattern match string to identify
which columns of that last relationship to include. Standard simple glob wildcards * ? [ ]
are supported (this is powered by the Text::Glob module. ColSpecs with no relspec apply to
the base table/class. If no base colspecs are defined, '*' is assumed, which will include
all columns of the base table (but not of any related tables). 

Note that this ColSpec:

 object.owner.contact
 
Would join { object => 'owner' } and include one column named 'contact' within the owner table.

This ColSpec, on the other hand:

 object.owner.contact.*
 
Would join { object => { owner => 'contact' } } and include all columns within the contact table.

The ! chacter can exclude instead of include. It can only be at the start of the line, and it will
cause the colspec to exclude columns that match the pattern. For the purposes of joining, ! ColSpecs
are ignored.

=head1 EXAMPLE ColSpecs:

	'name',
	'!id',
	'*',
	'!*',
	'project.*', 
	'user.*',
	'contact.notes.owner.foo*',
	'contact.notes.owner.foo.sd',
	'project.dist1.rsm.object.*_ts',
	'relation.column',
	'owner.*',
	'!owner.*_*',

=cut


subtype 'ColSpec', as 'Str', where {
	/\s+/ and warn "ColSpec '$_' is invalid because it contains whitespace" and return 0;
	/[A-Z]+/ and warn "ColSpec '$_' is invalid because it contains upper case characters" and return 0;
	/([^a-z0-9\-\_\.\!\*\?\[\]])/ and warn "ColSpec '$_' contains invalid characters ('$1')." and return 0;
	/^\./ and warn "ColSpec '$_' is invalid: \".\" cannot be the first character" and return 0;
	/\.$/ and warn "ColSpec '$_' is invalid: \".\" cannot be the last character (did you mean '$_*' ?)" and return 0;
	
	$_ =~ s/^\!//;
	/\!/ and warn "ColSpec '$_' is invalid: ! (not) character may only be supplied at the begining of the string." and return 0;
	
	my @parts = split(/\./,$_); pop @parts;
	my $relspec = join('.',@parts);
	$relspec =~ /([\*\?\[\]])/ and $relspec ne '*'
		and warn "ColSpec '$_' is invalid: glob wildcards are only allowed in the column section, not in the relation section." and return 0;
	
	return 1;
};

has 'include_colspec' => ( 
	is => 'ro', isa => 'ArrayRef[ColSpec]',
	required => 1,
	trigger => sub {
		my ($self,$spec) = @_;
		my $sep = $self->relation_sep;
		/${sep}/ and die "Fatal: ColSpec '$_' is invalid because it contains the relation separater string '$sep'" for (@$spec);

		#init base/relation colspecs:
		$self->base_colspec;
	}
);


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

has 'base_colspec' => ( is => 'ro', isa => 'ArrayRef', lazy => 1,default => sub {
	my $self = shift;
	#init relation_colspecs:
	$self->relation_order;
	return $self->relation_colspecs->{''};
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
	
	return $self->colspec_select_columns({
		colspecs => $self->base_colspec,
		columns => \@columns,
	});
}


# TODO:
# abstract this logic (much of which is redundant) into its own proper class 
# (merge with Mike's class)
# Tests whether or not the supplied column name matches the supplied colspec.
# Returns 1 for positive match, 0 for negative match (! prefix) and undef for no match
sub colspec_test {
	my $self = shift;
	my $full_colspec = shift;
	my $col = shift;
	
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
	$full_colspec =~ s/^(\!)//;
	my $x = $1 ? -1 : 1;
	my $match_return = $1 ? 0 : 1;
	
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
		my $distance = distance($colspec,$test_col);
		
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

# returns a list of loaded column names that match the supplied colspec set
sub get_colspec_column_names {
	my $self = shift;
	my @colspecs = @_;
	@colspecs = @{$_[0]} if (ref($_[0]) eq 'ARRAY');
	
	return $self->colspec_select_columns({
		colspecs => \@colspecs,
		columns => [ $self->updated_column_order ]
	});
}

# Returns a sublist of the supplied columns that match the supplied colspec set.
# The colspec set is considered as a whole, with each column name tested against
# the entire compiled set, which can contain both positive and negative (!) colspecs,
# with the most recent match taking precidence.
sub colspec_select_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $colspecs = $opt{colspecs} or die "colspec_select_columns(): expected 'colspecs'";
	my $columns = $opt{columns} or die "colspec_select_columns(): expected 'columns'";
	
	# if best_match_look_ahead is true, the current remaining colspecs will be passed
	# to each invocation of colspec_test which will cause it to only return a match
	# when testing the *closest* (according to WagnerFischer edit distance) colspec
	# of the set to the column. This prevents 
	my $best_match = $opt{best_match_look_ahead};
	
	$colspecs = [ $colspecs ] unless (ref $colspecs);
	$columns = [ $columns ] unless (ref $columns);
	
	my %match = map { $_ => 0 } @$columns;
	my @order = ();
	my $i = 0;
	for my $spec (@$colspecs) {
		my @remaining = @$colspecs[++$i .. $#$colspecs];
		for my $col (@$columns) {
			my @arg = ($spec,$col);
			push @arg, @remaining if ($best_match); # <-- push the rest of the colspecs after the current for index
			
			my $result = $self->colspec_test(@arg) or next;;
			push @order, $col if ($result > 0);
			$match{$col} = $result;
		}
	}
	
	return grep { $match{$_} > 0 } @order;
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



has 'relation_colspecs' => ( is => 'ro', isa => 'HashRef', default => sub {{ '' => [] }} );
has 'relation_order' => ( is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
	my $self = shift;
	
	my @order = ('');
	my %end_rels = ( '' => 1 );
	foreach my $spec (@{ clone($self->include_colspec) }) {
		my $not = 0;
		$not = 1 if ($spec =~ /\!/);
		$spec =~ s/\!//;
		my @parts = split(/\./,$spec);
		my $rel = shift @parts;
		my $subspec = join('.',@parts);
		unless(@parts > 0) { # <-- if its the base rel
			$subspec = $rel;
			$rel = '';
		}
		
		# end rels that link to colspecs and not just to relspecs 
		# (intermediate rels with no direct columns)
		$end_rels{$rel}++ if (
			not $subspec =~ /\./ and 
			not $not
		 );
		
		$subspec = '!' . $subspec if ($not);
		
		unless(defined $self->relation_colspecs->{$rel}) {
			$self->relation_colspecs->{$rel} = [];
			push @order, $rel;
		}
		
		push @{$self->relation_colspecs->{$rel}}, $subspec;
	}
	
	# Set the base colspec to '*' if its empty:
	push @{$self->relation_colspecs->{''}}, '*' unless (@{$self->relation_colspecs->{''}} > 0);
	foreach my $rel (@order) {
		push @{$self->relation_colspecs->{$rel}}, '!*' unless ($end_rels{$rel});
	}
	return \@order;
});


sub new_TableSpec {
	my $self = shift;
	return RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(@_);
}


=pod
sub related_TableSpec {
	my $self = shift;
	my $rel = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $info = $self->ResultClass->relationship_info($rel) or die "Relationship '$rel' not found.";
	my $class = $info->{class};
	
	# Manually load and initialize the TableSpec component if it's missing from the
	# related result class:
	#unless($class->can('TableSpec')) {
	#	$class->load_components('+RapidApp::DBIC::Component::TableSpec');
	#	$class->apply_TableSpec(%opt);
	#}
	
	my $relspec_prefix = $self->relspec_prefix;
	$relspec_prefix .= '.' if ($relspec_prefix and $relspec_prefix ne '');
	$relspec_prefix .= $rel;
	
	my $TableSpec = $self->new_TableSpec(
		name => $class->table,
		ResultClass => $class,
		relation_sep => $self->relation_sep,
		relspec_prefix => $relspec_prefix,
		%opt
	);
	
	return $TableSpec;
}
=cut

=pod
# Recursively flattens/merges in columns from related TableSpecs (matching include_colspec)
# into a new TableSpec object and returns it:
sub flattened_TableSpec {
	my $self = shift;
	
	#return $self;
	
	my $Flattened = $self->new_TableSpec(
		name => $self->name,
		ResultClass => $self->ResultClass,
		relation_sep => $self->relation_sep,
		include_colspec => $self->include_colspec,
		relspec_prefix => $self->relspec_prefix
	);
	
	$Flattened->add_all_related_TableSpecs_recursive;
	
	#scream_color(CYAN,$Flattened->column_name_relationship_map);
	
	return $Flattened;
}
=cut

sub add_all_related_TableSpecs_recursive {
	my $self = shift;
	
	foreach my $rel (@{$self->relation_order}) {
		next if ($rel eq '');
		my $TableSpec = $self->add_related_TableSpec( $rel, {
			include_colspec => $self->relation_colspecs->{$rel}
		});
		
		$TableSpec->add_all_related_TableSpecs_recursive;
	}
	
	foreach my $rel (@{$self->related_TableSpec_order}) {
		my $TableSpec = $self->related_TableSpec->{$rel};
		for my $name ($TableSpec->column_names_ordered) {
			die "Column name conflict: $name is already defined (rel: $rel)" if ($self->has_column($name));
			$self->column_name_relationship_map->{$name} = $rel;
		}
	}
	
	return $self;
}

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
	
	die "There is already a related TableSpec associated with the '$rel' relationship" if (
		defined $self->related_TableSpec->{$rel}
	);
	
	my $info = $self->ResultClass->relationship_info($rel) or die "Relationship '$rel' not found.";
	my $class = $info->{class};

	my $relspec_prefix = $self->relspec_prefix;
	$relspec_prefix .= '.' if ($relspec_prefix and $relspec_prefix ne '');
	$relspec_prefix .= $rel;
	
	my $TableSpec = $self->new_TableSpec(
		name => $class->table,
		ResultClass => $class,
		relation_sep => $self->relation_sep,
		relspec_prefix => $relspec_prefix,
		%opt
	) or die "Failed to create related TableSpec";
	
	#for my $name ($TableSpec->column_names) {
	#	die "Column name conflict: " . $name . " is already defined" if ($self->has_column($name));
	#	$self->column_name_relationship_map->{$name} = $rel;
	#}
	
	$self->related_TableSpec->{$rel} = $TableSpec;
	push @{$self->related_TableSpec_order}, $rel;
	
	#for my $name ($TableSpec->local_column_names) {
	#	die "Column name conflict: $name is already defined (rel: $rel)" if ($self->has_column($name));
	#	$self->column_name_relationship_map->{$name} = $rel;
	#}
	
	#scream($self->column_name_relationship_map);
	
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

#around 'column_names' => sub {
#	my $orig = shift;
#	my $self = shift;
#
#	my @names = $self->$orig(@_);
#	push @names, $self->related_TableSpec->{$_}->column_names for (@{$self->related_TableSpec_order});
#	return @names;
#};

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

sub resolve_dbic_colname {
	my $self = shift;
	my $name = shift;
	my $merge_join = shift;
	
	my ($rel,$col,$join) = $self->resolve_dbic_rel_alias_by_column_name($name);
	$join = {} unless (defined $join);
	%$merge_join = %{ merge($merge_join,$join) } if ($merge_join);
	
	return $rel . '.' . $col;
}


sub resolve_dbic_rel_alias_by_column_name {
	my $self = shift;
	my $name = shift;
	
	my $rel = $self->column_name_relationship_map->{$name};
	unless ($rel) {
		my $pre = $self->column_prefix;
		$name =~ s/^${pre}//;
		return ('me',$name,$self->needed_join);
	}

	my $TableSpec = $self->related_TableSpec->{$rel};
	my ($alias,$dbname,$join) = $TableSpec->resolve_dbic_rel_alias_by_column_name($name);
	$alias = $rel if ($alias eq 'me');
	return ($alias,$dbname,$join);
}

sub chain_to_hash {
	my $self = shift;
	my @chain = @_;
	
	my $hash = {};

	my @evals = ();
	foreach my $item (@chain) {
		unshift @evals, '$hash->{\'' . join('\'}->{\'',@chain) . '\'} = {}';
		pop @chain;
	}
	eval $_ for (@evals);
	
	return $hash;
}




sub add_relationship_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->default_column_properties }, %$conf } if ( $self->default_column_properties );
		
		die "displayField is required" unless (defined $conf->{displayField});
		
		$conf->{render_col} = $rel . '_' . $conf->{displayField} unless ($conf->{render_col});
		
		my $info = $self->ResultClass->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		$conf->{foreign_col} = $self->get_foreign_column_from_cond($info->{cond});
		$conf->{valueField} = $conf->{foreign_col} unless (defined $conf->{valueField});
		$conf->{key_col} = $rel . '_' . $conf->{valueField};
		
		#Temporary/initial column setup:
		my $colname = $self->column_prefix . $rel;
		$self->add_columns({ name => $colname, %$conf });
		my $Column = $self->get_column($colname);
		
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


=pod


# returns a DBIC join attr based on the colspec
has 'join' => ( is => 'ro', lazy_build => 1 );
sub _build_join {
	my $self = shift;
	
	my $join = {};
	my @list = ();
	
	foreach my $item (@{ $self->include_colspec }) {
		my @parts = split(/\./,$item);
		my $colspec = pop @parts; # <-- the last field describes columns, not rels
		my $relspec = join('.',@parts) || '';
		
		push @{$self->relspec_order}, $relspec unless ($self->relspec_colspec_map->{$relspec} or $relspec eq '');
		push @{$self->relspec_colspec_map->{$relspec}}, $colspec;
		
		next unless (@parts > 0);
		# Ignore exclude specs:
		next if ($item =~ /^\!/);
		
		$join = merge($join,$self->chain_to_hash(@parts));
	}
	
	# Add '*' to the base relspec if it is empty:
	push @{$self->relspec_colspec_map->{''}}, '*' unless (defined $self->relspec_colspec_map->{''});
	unshift @{$self->relspec_order}, ''; # <-- base relspec first
	
	return $self->hash_with_undef_values_to_array_deep($join);
}
has 'relspec_colspec_map' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
has 'relspec_order' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );




sub hash_with_undef_values_to_array_deep {
	my ($self,$hash) = @_;
	return @_ unless (ref($hash) eq 'HASH');

	my @list = ();
	
	foreach my $key (keys %$hash) {
		if(defined $hash->{$key}) {
			
			if(ref($hash->{$key}) eq 'HASH') {
				# recursive:
				$hash->{$key} = $self->hash_with_undef_values_to_array_deep($hash->{$key});
			}
			
			push @list, $self->leaf_hash_to_string({ $key => $hash->{$key} });
			next;
		}
		push @list, $key;
	}
	
	return $hash unless (@list > 0); #<-- there were no undef values
	return $list[0] if (@list == 1);
	return \@list;
}

sub leaf_hash_to_string {
	my ($self,$hash) = @_;
	return @_ unless (ref($hash) eq 'HASH');
	
	my @keys = keys %$hash;
	my $key = shift @keys or return undef; # <-- empty hash
	return $hash if (@keys > 0); # <-- not a leaf, more than 1 key
	return $hash if (defined $self->leaf_hash_to_string($hash->{$key})); # <-- not a leaf, single value is not an empty hash
	return $key;
}



=cut


1;