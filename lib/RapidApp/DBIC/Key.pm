package RapidApp::DBIC::Key;

use Params::Validate ':all';
use overload '""' => \&stringify; # to-string operator overload

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

sub val_from_array {
	my $self= shift;
	return RapidApp::DBIC::KeyVal->new_from_array($self, @_);
}

sub stringify {
	my $self= shift;
	return $self->{_str} ||= $self->source.'.'.join('+', $self->columns);
}

1;