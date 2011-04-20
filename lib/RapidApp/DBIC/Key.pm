package RapidApp::DBIC::Key;

use Params::Validate ':all';
use overload '""' => \&stringify, 'cmp' => \&compare; # to-string, eq operator overload

# These are used frequently enough, and simple enough, that I decided to leave out Moose
#   for performance reasons

sub new($@) {
	my $class= shift;
	my %p= validate(@_, { source => {type=>SCALAR}, columns => {type=>ARRAYREF|SCALAR} } );
	ref $p{columns} or $p{columns}= [ $p{columns} ];
	return bless \%p, $class;
}

sub new_from_array {
	my ($class, $srcN, @cols)= @_;
	return bless { source => $srcN, columns => \@cols }, $class;
}

sub source {
	return (shift)->{source};
}

sub columns {
	return @{(shift)->{columns}};
}

sub val_from_hash {
	my $self= shift;
	return RapidApp::DBIC::KeyVal->new_from_hash($self, @_);
}

sub val_from_row {
	my ($self, $row)= @_;
	return RapidApp::DBIC::KeyVal->new_from_row($self, $row);
}

sub val_from_hash_if_exists {
	my $self= shift;
	return RapidApp::DBIC::KeyVal->new_from_hash_if_exists($self, @_);
}

sub val_from_array {
	my $self= shift;
	return RapidApp::DBIC::KeyVal->new_from_array($self, @_);
}

sub stringify {
	my $self= shift;
	return $self->{_str} ||= $self->source.'.'.join('+', $self->columns);
}

sub _canonical {
	my $self= shift;
	return $self->{_canonical} ||= $self->source.'.'.join('+', sort $self->columns);
}

sub compare {
	my ($obj_a, $obj_b)= @_;
	#return 0 unless blessed $a && blessed $b && $a->isa('RapidApp:DBIC::Key') && $b->isa('RapidApp::DBIC::Key');
	return $obj_a->_canonical cmp $obj_b->_canonical;
}

1;