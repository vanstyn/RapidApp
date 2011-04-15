package RapidApp::DBIC::KeyVal;

use Params::Validate ':all';
use overload '""' => \&stringify; # to-string operator overload

# These are used frequently enough, and simple enough, that I decided to leave out Moose
#   for performance reasons

sub new {
	my $class= shift;
	my %p= validate(@_, { key => 1, values => 1 });
	if (ref $p{values} eq 'HASH') {
		$p{values}= [ map { $p{values}->{$_} } $p{key}->columns ];
	}
	return bless \%p, $class;
}

# a less expensive way to create them....
sub new_from_array {
	my ($class, $key, @vals)= @_;
	die "First argument must be a Key" unless (ref $key)->isa('RapidApp::DBIC::Key');
	return bless { key => $key, values => \@vals }, $class;
}

sub new_from_hash {
	my ($class, $key, @args)= @_;
	die "First argument must be a Key" unless (ref $key)->isa('RapidApp::DBIC::Key');
	my $hash= ref $args[0] eq 'HASH'? $args[0] : { @args };
	my @vals;
	for my $colN ($key->columns) {
		exists $hash->{$colN} or die "Key $key has no value in hash: {".join(', ', map { "$_ => ".$hash->{$_} } keys %$hash)."}";
		push @vals, $hash->{$colN};
	}
	return bless { key => $key, values => \@vals }, $class;
}

sub source {
	return (shift)->key->source;
}

sub key {
	return (shift)->{key};
}

sub columns {
	return (shift)->key->columns;
}

sub values {
	return @{(shift)->{values}};
}

sub asHash {
	my $self= shift;
	my @v= $self->values;
	my @c= $self->columns;
	return { map { $_, shift(@v) } @c };
}

# This method stringifies a value for a key.
# For all single-column keys, we just use the value.
# For multiple-column keys, we join the values with the length of that value
# i.e.   LEN "~" VALUE LEN "~" VALUE ...
# (which is a quick and easy way to ensure that unique values get unique
#   strings without having to escape anything.  This trick is borrowed
#   from C++ name mangling)
sub stringify {
	my $self= shift;
	my @vals= $self->values;
	scalar(@vals) eq 1 && return ''.$vals[0];
	return join '+', map { length($_).'_'.$_ } @vals;
}

1;