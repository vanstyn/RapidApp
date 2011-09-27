package RapidApp::DBIC::ColPath;
use strict;
use warnings;
use overload '""' => sub { $_[0]->toString }; # to-string operator overload

sub coerce {
	my $class= shift;
	return (scalar(@_) && defined $_[0] && $_[0]->isa($class))? $_[0] : $class->new(@_);
}

sub new {
	my $class= shift;
	die "Cannot create ColPath with 0 elements" unless scalar(@_);
	bless [ @_ ], $class;
}

sub colName {
	$_[0][-1] # the last element of @$self
}

sub colPathList {
	# this line noise is actually perl code that returns the first N-1 elements of @$self
	@{$_[0]}[0..($#{$_[0]}-1)]
}

sub colPath {
	[ colPathList(@_) ]
}

sub toString {
	return join('.', @{ $_[0] } );
}

=head2 $col->key

Key is like toString, but guaranteed not to collide with any other possible column path
regardless of whether the path contains embedded "." characters.

=cut
sub key {
	join '', map { length($_).$_ } @{$_[0]}
}

=head2 $col->assignToHashTree( $hash, $value );

Assign a value to a HashTree at the location described by this path.

=cut
sub assignToHashTree {
	my ($self, $hash, $value)= @_;
	for ($self->colPathList) {
		$hash= ($hash->{$_} ||= {})
	}
	$hash->{$self->colName}= $value;
}

1;