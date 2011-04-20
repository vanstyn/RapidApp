package RapidApp::DBIC::SchemaAnalysis::SourceAnalysis;

use Moose;
use RapidApp::DBIC::SchemaAnalysis::Constraint;
use RapidApp::Debug 'DEBUG';

use overload '""' => \&stringify; # to-string operator overload

has 'source' => ( is => 'ro', isa => 'DBIx::Class::ResultSource', required => 1 );
has 'name'   => ( is => 'ro', default => sub { (shift)->source->source_name }, lazy => 1, required => 1 );
has 'pk'     => ( is => 'ro', isa => 'RapidApp::DBIC::Key', lazy_build => 1, required => 1 );

# list of columns which receive an auto-generated value.
# right now we only look for auto_increment.
has 'autogen_cols' => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1, lazy_build => 1, required => 1 );

# information about records which are "part of the schema"
has 'schema_defined_rows' => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1, lazy_build => 1, required => 1 );

# List of foreign keys this source might depend on
# Each item is a pair of local-key, foreign-key, with matching column order.
# This is much easier to work with than DBIC's native { self.col1 => foreign.col6, self.col2 => foreign.col7 }
has 'fk_constraints' => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1, lazy_build => 1, required => 1 );

sub _build_pk {
	my $self= shift;
	return RapidApp::DBIC::Key->new_from_array($self->source->source_name, $self->source->primary_columns);
}

sub _build_autogen_cols {
	my $self= shift;
	my $rsrc= $self->source;
	return [ grep { $rsrc->column_info($_)->{is_auto_increment} } $rsrc->columns ];
}

sub _build_fk_constraints {
	my $self= shift;
	# TODO: implement this after figuring out how to interpret the relations to figure out
	#   which are constraints and which are simple relations.
	my @ret;
	for my $relN ($self->source->relationships) {
		my $relHash= $self->source->relationship_info($relN);
		next unless $relHash->{attrs}->{is_foreign_key_constraint};
		
		my $relObjs= $self->_get_relation_objects($self->source, $relN, $relHash);
		my $ok= $self->_find_origin_key($relObjs->{foreignSrc}, $relObjs->{foreignKey}, $relObjs->{localKey});
		push @ret, RapidApp::DBIC::SchemaAnalysis::Constraint->new(
			local_key   => $relObjs->{localKey},
			foreign_key => $relObjs->{foreignKey},
			origin_key  => $ok
		);
	}
	return \@ret;
}

sub _get_relation_objects {
	my ($self, $rsrc, $relN, $relHash)= @_;
	
	$relHash ||= $rsrc->relationship_info($relN);
	my (@lk_cols, @fk_cols);
	for my $fkn (keys %{$relHash->{cond}}) {
		my $lkn= $relHash->{cond}->{$fkn};
		push @fk_cols, ($fkn =~ /foreign.(.*)/)? $1 : $fkn;
		push @lk_cols, ($lkn =~ /self.(.*)/)? $1 : $lkn;
	}
	my $f_rsrc= $rsrc->related_source($relN);
	return {
		foreignSrc => $f_rsrc,
		foreignKey => RapidApp::DBIC::Key->new_from_array($f_rsrc->source_name, sort @fk_cols),
		localKey   => RapidApp::DBIC::Key->new_from_array($rsrc->source_name, sort @lk_cols),
	}
}

sub _find_origin_key {
	my ($self, $rsrc, $key, $prevKey)= @_;
	# iterate all relations of related resultsource
	# if find a relation that does not map back to this resultset, and is_foreign_key_constraint, recurse
	for my $relN ($rsrc->relationships) {
		my $relHash= $rsrc->relationship_info($relN);
		next unless $relHash->{attrs}->{is_foreign_key_constraint};
		
		my $relObjs= $self->_get_relation_objects($rsrc, $relN, $relHash);
		DEBUG('foo', $rsrc->source_name, key => "$key", prevKey => "$prevKey", fk => ''.$relObjs->{foreignKey}, flk => ''.$relObjs->{localKey}) if $rsrc->source_name =~ /template.*/i;
		DEBUG('foo', rel_loc_key => ''.$relObjs->{localKey}, key => ''.$key, cmp => ($relObjs->{localKey} eq $key) ) if $rsrc->source_name =~ /template.*/i;
		if (($relObjs->{localKey} eq $key) && ($relObjs->{foreignKey} ne $prevKey)) {
			return $self->_find_origin_key($relObjs->{foreignSrc}, $relObjs->{foreignKey}, $key);
		}
	}
	# else, this key is the origin.
	DEBUG('foo', 'returning ' => $key.'') if $rsrc->source_name =~ /template.*/i;
	return $key;
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
	if (scalar($self->schema_defined_rows)) {
		$ret .= "   schema-defined rows:\n".join('',
			map { "      { pkVal=>".$_->{pkVal}.",\tis_const=>".$_->{is_const}.",\tdata=>[HASH] }\n" } $self->schema_defined_rows,
		);
	}
	if (scalar($self->fk_constraints)) {
		$ret .= "   foreign-key constraints:\n".join('',
			map { "      { local_key=>".$_->local_key.",\tforeign_key=>".$_->foreign_key.",\torigin_key=>".$_->origin_key." }\n" } $self->fk_constraints,
		);
	}
	$ret;
}

__PACKAGE__->meta->make_immutable;
1;