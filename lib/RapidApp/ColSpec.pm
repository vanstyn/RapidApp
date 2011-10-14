package RapidApp::ColSpec;
use strict;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use Text::Glob qw( match_glob );
use Clone qw(clone);

around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	return $opt{spec} if (ref($opt{spec}) eq __PACKAGE__);
	$opt{spec} = [ $opt{spec} ] unless (ref($opt{spec}));
	
	return $class->$orig(%opt);
};

has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );
has 'ResultSource' => ( is => 'ro', isa => 'DBIx::Class::ResultSource', required => 1 );

has 'spec' => (
	is => 'ro',
	isa => 'ArrayRef[Str]',
	required => 1,
	# Need to do this validation in a trigger so we have access to the value of 'relation_sep' :
	trigger => sub {
		my ($self,$spec) = @_;
		my $sep = $self->relation_sep;
		for (@$spec) {
			/${sep}/ and die "Fatal: colspec '$_' is invalid because it contains the relation separater string '$sep'";
			/\s+/ and die "Fatal: colspec '$_' is invalid because it contains whitespace";
			/([^a-zA-Z0-9\-\_\.\*\?\[\]])/ and die "Fatal: colspec '$_' contains invalid characters ('$1').";
			
			my @parts = split(/\./,$_); pop @parts;
			my $relspec = join('.',@parts);
			$relspec =~ /([\*\?\[\]])/ and die "Fatal: colspec '$_' is invalid: glob wildcards are only allowed in the column section, not in the relation section.";
			
			#init join and columns:
			$self->join;
			$self->columns;

		}
	}
);

has 'column_props' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
has 'columns' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
sub _build_columns {
	my $self = shift;
	
	# Make sure join is initialized:
	$self->join;
	
	my $columns = [];
	push @$columns, $self->relspec_to_column_list($_) for (@{$self->relspec_order});
	return $columns;
}

sub relspec_to_column_list {
	my $self = shift;
	my $relspec = shift;
	my $Source = shift || $self->ResultSource;
	my $prefix = shift || '';
	my @columns = @_;
	
	if ($relspec eq '') { 
		foreach my $col ($Source->columns) {
			my $colname = $prefix . $col;
			$self->column_props->{$colname} = $Source->source_name;
			push @columns, $colname;
		}
		return @columns;
	}
	
	my @parts = split(/\./,$relspec);
	$prefix .= join($self->relation_sep,@parts) . $self->relation_sep;
	my $relation = shift @parts;
	my $RelSource = $Source->related_source($relation) or croak "Failed to find ResultSource for '$relation'";
	return $self->relspec_to_column_list(join('.',@parts) || '',$RelSource,$prefix,@columns);
}


sub colspec_matching_columns {
	my $self = shift;
	my $relspec = shift;
	my @columns = @_;
	
	my $colspecs = clone($self->relspec_colspec_map->{$relspec}) or croak "relspec '$relspec' not found!";
	my $limits = [];
	my $excludes = [];
	
	foreach my $spec (@$colspecs) {
		if($spec =~ /^\-/) {
			$spec =~ s/^\-//;
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


# returns a DBIC join attr based on the colspec
has 'join' => ( is => 'ro', lazy_build => 1 );
sub _build_join {
	my $self = shift;
	
	my $join = {};
	my @list = ();
	
	foreach my $item (@{ $self->spec }) {
		my @parts = split(/\./,$item);
		my $colspec = pop @parts; # <-- the last field describes columns, not rels
		my $relspec = join('.',@parts) || '';
		
		push @{$self->relspec_order}, $relspec unless ($self->relspec_colspec_map->{$relspec} or $relspec eq '');
		push @{$self->relspec_colspec_map->{$relspec}}, $colspec;
		
		next unless (@parts > 0);
		# Ignore exclude specs:
		next if ($item =~ /^\-/);
		
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