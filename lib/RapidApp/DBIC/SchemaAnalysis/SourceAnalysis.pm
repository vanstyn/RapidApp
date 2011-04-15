package RapidApp::DBIC::SchemaAnalysis::SourceAnalysis;

use Moose;

use overload '""' => \&stringify; # to-string operator overload

has 'source' => ( is => 'ro', isa => 'DBIx::Class::ResultSource', required => 1 );
has 'name'   => ( is => 'ro', default => sub { (shift)->source->source_name }, lazy => 1, required => 1 );
has 'pk'     => ( is => 'ro', isa => 'RapidApp::DBIC::Key', lazy_build => 1, required => 1 );

# list of columns which receive an auto-generated value.
# right now we only look for auto_increment.
has 'autogen_cols' => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1, lazy_build => 1, required => 1 );

# information about records which are "part of the schema"
has 'schema_defined_rows' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1, required => 1 );

sub _build_pk {
	my $self= shift;
	return RapidApp::DBIC::Key->new(
		source => $self->source->source_name,
		columns => [ $self->source->primary_columns
	]);
}

sub _build_autogen_cols {
	my $self= shift;
	my $rsrc= $self->source;
	return [ grep { $rsrc->column_info($_)->{is_auto_increment} } $rsrc->columns ];
}

sub _convert_populate_data_to_hashes {
	my ($self, $data)= @_;
	return [] unless defined $data;
	return $data unless scalar(@$data);
	return $data unless ref $data->[0] eq 'ARRAY';
	my @rows= @$data;
	my @header= @{shift @rows};
	my @result;
	for my $rowAry (@rows) {
		my %rowHash= map { $_, shift(@$rowAry) } @header;
		push @result, \%rowHash;
	}
	return \@result;
}

sub _build_schema_defined_rows {
	my $self= shift;
	my $rowCls= $self->source->resultset->result_class;
	my $code;
	my $const_recs= $self->_convert_populate_data_to_hashes( ($code= $rowCls->can('CONSTANT_VALUES')) && $code->() );
	my $init_recs=  $self->_convert_populate_data_to_hashes( ($code= $rowCls->can('INITIAL_VALUES'))  && $code->() );
	my @rows;
	push @rows, map {+ { is_const => 1, data => $_, pkVal => $self->pk->val_from_hash($_) } } @$const_recs;
	push @rows, map {+ { is_const => 0, data => $_, pkVal => $self->pk->val_from_hash($_) } } @$init_recs;
	
	return \@rows;
}

sub stringify {
	my $self= shift;
	my $ret= 'SourceAnalysis: [ '.$self->name." ]\n"
		."   primary key: ".$self->pk."\n";
	my @autogen= $self->autogen_cols;
	if (scalar(@autogen)) {
		$ret .= "   auto-gen cols: [ ".join(', ', @autogen)." ]\n";
	}
	if (scalar(@{$self->schema_defined_rows})) {
		$ret .= "   schema-defined rows:\n".join('',
			map { "      { pkVal=>".$_->{pkVal}.", is_const=>".$_->{is_const}.", data=>[HASH] }\n" } @{$self->schema_defined_rows},
		);
	}
	$ret;
}

__PACKAGE__->meta->make_immutable;
1;