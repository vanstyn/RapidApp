package FakeSource;
use strict;
use Carp;

sub source_name {
	$_[0]->{name};
}
sub schema {
	$_[0]->{schema}
}
sub columns {
	@{ $_[0]->{cols} }
}
sub primary_columns {
	$_[0]->{pk} ||= [ $_[0]->columns ];
}
sub relationships {
	keys %{$_[0]{rels}};
}
sub has_column {
	scalar grep { $_ eq $_[1] } $_[0]->columns;
}
sub column_info {
	{ data_type => 'varchar', size => 32 };
}
sub has_relationship {
	$_[0]->{rels}->{$_[1]}
}
sub related_source {
	my $srcN= $_[0]->{rels}->{$_[1]} or carp "No such relationship: ".$_[0]->name.".$_[1]";
	$_[0]->schema->source($srcN)
}

package FakeSchema;
use strict;
use Scalar::Util 'weaken';
use Carp;

sub new {
	my ($class, $sources)= @_;
	my $self= bless { sources => $sources }, $class;
	for my $srcN (keys %$sources) {
		$sources->{$srcN}{name}= $srcN;
		$sources->{$srcN}{columns} and $sources->{$srcN}{cols}= delete $sources->{$srcN}{columns};
		weaken( $sources->{$srcN}{schema}= $self );
		bless $sources->{$srcN}, 'FakeSource';
	}
	$self;
}
sub source {
	$_[0]->{sources}{$_[1]} or croak "No such source: $_[1]";
}

1;