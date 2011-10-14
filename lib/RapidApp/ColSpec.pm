package RapidApp::ColSpec;
use strict;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::Data::Dmap;

around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	return $opt{spec} if (ref($opt{spec}) eq __PACKAGE__);
	$opt{spec} = [ $opt{spec} ] unless (ref($opt{spec}));
	
	return $class->$orig(%opt);
};


has 'spec' => (
	is => 'ro',
	isa => 'ArrayRef[Str]',
	required => 1,
);

has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );
 
sub BUILD {
	my $self = shift;
	
	my $sep = $self->relation_sep;
	for (@{ $self->spec }) {
		/${sep}/ and die "Fatal: colspec '$_' is invalid because it contains the relation separater string '$sep'";
		/\s+/ and die "Fatal: colspec '$_' is invalid because it contains whitespace";
		/([^a-zA-Z0-9\-\_\.\*\?\[\]])/ and die "Fatal: colspec '$_' contains invalid characters ('$1').";
	}

}

# returns a DBIC join attr based on the colspec
has 'join' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $join = {};
	my @list = ();
	
	foreach my $item (@{ $self->spec }) {
		my @parts = split(/\./,$item);
		next unless (@parts > 1);
		pop @parts; # <-- the last field describes columns, not rels
		
		/([\*\?\[\]])/ and die "Fatal: colspec '$item' is invalid: glob wildcards are only allowed in the column section, not in the relation section." for (@parts);
		
		push @list,$self->chain_to_hash(@parts);
	}
	
	foreach my $item (@list) {
		$join = merge($join,$item);
	}
	
	dmap { return $self->leaf_hash_to_string($_) } $join;
	return $self->hash_with_undef_values_to_array_deep($join);
});



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

sub leaf_hash_to_string {
	my ($self,$hash) = @_;
	return @_ unless (ref($hash) eq 'HASH');
	
	my @keys = keys %$hash;
	my $key = shift @keys or return undef; # <-- empty hash
	return $hash if (@keys > 0); # <-- not a leaf, more than 1 key
	return $hash if (defined $self->leaf_hash_to_string($hash->{$key})); # <-- not a leaf, single value is not an empty hash
	return $key;
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
			
			push @list, { $key => $hash->{$key} };
			next;
		}
		push @list, $key;
	}
	
	return $hash unless (@list > 0); #<-- there were no undef values
	return $list[0] if (@list == 1);
	return \@list;
}







1;