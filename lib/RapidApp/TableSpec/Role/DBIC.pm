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

has 'relation_sep' => ( is => 'ro', isa => 'Str', required => 1 );
has 'relspec_prefix' => ( is => 'ro', isa => 'Str', default => '' );
has 'column_prefix' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub {
	my $self = shift;
	return '' if ($self->relspec_prefix eq '');
	my $col_pre = $self->relspec_prefix;
	my $sep = $self->relation_sep;
	$col_pre =~ s/\./${sep}/g;
	return $col_pre . $self->relation_sep;
});

subtype 'ColSpec', as 'Str', where {
	/\s+/ and warn "ColSpec '$_' is invalid because it contains whitespace" and return 0;
	/[A-Z]+/ and warn "ColSpec '$_' is invalid because it contains upper case characters" and return 0;
	/([^a-z0-9\-\_\.\!\*\?\[\]])/ and warn "ColSpec '$_' contains invalid characters ('$1')." and return 0;
	
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

has 'base_colspec' => ( is => 'ro', isa => 'ArrayRef', lazy => 1,default => sub {
	my $self = shift;
	#init relation_colspecs:
	$self->relation_order;
	return $self->relation_colspecs->{''};
});

# accepts a list of column names and returns the names that match the base colspec
sub filter_columns {
	my $self = shift;
	my @columns = @_;
	
	my $limits = [];
	my $excludes = [];
	
	foreach my $spec (@{$self->base_colspec}) {
		if($spec =~ /^\!/) {
			$spec =~ s/^\!//;
			push @$excludes, $spec;
			next;
		}
		push @$limits, $spec;
	}
	
	my %match = ();
	COL: foreach my $col (@columns) {
		my $skip = 0;
		match_glob($_,$col) and next COL for (@$excludes);
		match_glob($_,$col) and $match{$col}++ for (@$limits);
	}
	return keys %match;
}

sub BUILD {}
after BUILD => sub {
	my $self = shift;
	
	if($self->column_prefix) {
		$self->meta->find_attribute_by_name('column_property_transforms')->set_value($self,{})
			unless (defined $self->column_property_transforms);
			
		$self->column_property_transforms->{name} = sub { $self->column_prefix . $_ };
	}
	
	foreach my $col ($self->filter_columns($self->ResultClass->columns)) {
		my $info = $self->ResultClass->column_info($col);
		my @profiles = ();
		
		push @profiles, $info->{is_nullable} ? 'nullable' : 'notnull';
		
		my $type_profile = $self->data_type_profiles->{$info->{data_type}} || ['text'];
		$type_profile = [ $type_profile ] unless (ref $type_profile);
		push @profiles, @$type_profile; 
		
		$self->add_columns( { name => $col, profiles => \@profiles } ); 
	}

};


has 'relation_colspecs' => ( is => 'ro', isa => 'HashRef', default => sub {{ '' => [] }} );
has 'relation_order' => ( is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
	my $self = shift;
	
	my @order = ('');
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
		
		
		
		
		$subspec = '!' . $subspec if ($not);
		
		scream([$spec,$rel,$subspec]) if ($not);
		
		unless(defined $self->relation_colspecs->{$rel}) {
			$self->relation_colspecs->{$rel} = [];
			push @order, $rel;
		}
		
		push @{$self->relation_colspecs->{$rel}}, $subspec;
	}
	
	# Set the base colspec to '*' if its empty:
	push @{$self->relation_colspecs->{''}}, '*' unless (@{$self->relation_colspecs->{''}} > 0);
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
	
	my $TableSpec = $self->new_TableSpec(
		name => $class->table,
		ResultClass => $class,
		relation_sep => $self->relation_sep,
		column_prefix => $self->column_prefix || '' . $rel . $self->relation_sep,
		%opt
	);
	
	return $TableSpec;
}


# Recursively flattens/merges in columns from related TableSpecs (matching include_colspec)
# into a new TableSpec object and returns it:
sub flattened_TableSpec {
	my $self = shift;
	
	my $Flattened = $self->new_TableSpec(
		name => $self->name,
		ResultClass => $self->ResultClass,
		relation_sep => $self->relation_sep,
		include_colspec => $self->base_colspec,
		column_prefix => $self->column_prefix
	);
	
	foreach my $rel (@{$self->relation_order}) {
		next if ($rel eq '');
		$Flattened->add_columns_from_TableSpec( $self->related_TableSpec( $rel, {
			include_colspec => $self->relation_colspecs->{$rel}
		})->flattened_TableSpec);
	}

	return $Flattened;
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