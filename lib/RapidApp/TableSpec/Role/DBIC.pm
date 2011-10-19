package RapidApp::TableSpec::Role::DBIC;
use strict;
use Moose::Role;
use Moose::Util::TypeConstraints;

use RapidApp::Include qw(sugar perlutil);

use Text::Glob qw( match_glob );
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
	$relspec =~ /([\*\?\[\]])/ 
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

# accepts a list of column names and returns the names that match the base colspec
# colspecs are tested in order, with later matches overriding earlier ones
sub filter_columns {
	my $self = shift;
	my @columns = @_;

	my %match = map { $_ => 0 } @columns;
	for my $spec (@{$self->base_colspec}) {
		for my $col (@columns) {
			my $result = $self->colspec_test($spec,$col);
			$match{$col} = $result if (defined $result);
		}
	}

	return grep { $match{$_} } keys %match;
}

sub colspec_test {
	my $self = shift;
	my $colspec = shift;
	my $col = shift;
	
	$colspec =~ /\./ and 
		die "colspec_test(): invalid colspec '$colspec' - relspecs not allowed, only base_colspecs can be testeded.";
	
	my $match_ret = 1;
	if ($colspec =~ /^\!/) {
		$colspec =~ s/^\!//;
		$match_ret = 0;
	}
	return $match_ret if (match_glob($colspec,$col));
	return undef;
}

sub BUILD {}
after BUILD => sub {
	my $self = shift;

	foreach my $col ($self->filter_columns($self->ResultClass->columns)) {
		my $info = $self->ResultClass->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $self->data_type_profiles->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile; 
		
		$self->add_columns( { name => $self->column_prefix . $col, profiles => \@profiles } );
		$self->dbic_col_names->{$self->column_prefix . $col} = $col;
	}
};
# Tracks original dbic column names:
has 'dbic_col_names' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

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



# Recursively flattens/merges in columns from related TableSpecs (matching include_colspec)
# into a new TableSpec object and returns it:
sub flattened_TableSpec_old {
	my $self = shift;
	
	my $Flattened = $self->new_TableSpec(
		name => $self->name,
		ResultClass => $self->ResultClass,
		relation_sep => $self->relation_sep,
		include_colspec => $self->base_colspec,
		relspec_prefix => $self->relspec_prefix
	);
	
	foreach my $rel (@{$self->relation_order}) {
		next if ($rel eq '');
		$Flattened->add_columns_from_TableSpec( $self->related_TableSpec( $rel, {
			include_colspec => $self->relation_colspecs->{$rel}
		})->flattened_TableSpec);
	}

	return $Flattened;
}






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


sub add_all_related_TableSpecs_recursive {
	my $self = shift;
	
	foreach my $rel (@{$self->relation_order}) {
		next if ($rel eq '');
		my $TableSpec = $self->add_related_TableSpec( $rel, {
			include_colspec => $self->relation_colspecs->{$rel}
		});
		
		$TableSpec->add_all_related_TableSpecs_recursive;
		
		for my $name ($TableSpec->column_names) {
			die "Column name conflict: " . $name . " is already defined" if ($self->has_column($name));
			$self->column_name_relationship_map->{$name} = $rel;
		}
	}
	return $self;
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

around 'column_names' => sub {
	my $orig = shift;
	my $self = shift;

	my @names = $self->$orig(@_);
	push @names, $self->related_TableSpec->{$_}->column_names for (@{$self->related_TableSpec_order});
	return @names;
};






sub resolve_dbic_colname {
	my $self = shift;
	my $name = shift;
	
	my ($rel,$col,$join) = $self->resolve_dbic_rel_alias_by_column_name($name);
	$join = {} unless (defined $join);
	
	my $dbic_name = $rel . '.' . $col;
	
	scream_color(RED,$dbic_name,$join);
	
	return $dbic_name;
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






1;