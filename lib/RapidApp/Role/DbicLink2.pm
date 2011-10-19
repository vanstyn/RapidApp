package RapidApp::Role::DbicLink2;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::Role::DBIC;

# Colspec attrs can be specified as simple arrayrefs
has 'include_colspec' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );

has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );

has 'ResultSource' => (
	is => 'ro',
	isa => 'DBIx::Class::ResultSource',
	required => 1
);

has 'ResultClass' => ( is => 'ro', lazy_build => 1 );
sub _build_ResultClass {
	my $self = shift;
	my $source_name = $self->ResultSource->source_name;
	return $self->ResultSource->schema->class($source_name);
}

has 'TableSpec' => ( is => 'ro', isa => 'RapidApp::TableSpec', lazy_build => 1 );
sub _build_TableSpec {
	my $self = shift;
	my $TableSpec = RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(
		name => $self->ResultClass->table,
		relation_sep => $self->relation_sep,
		ResultClass => $self->ResultClass,
		include_colspec => $self->include_colspec
	);
	
	$TableSpec->add_all_related_TableSpecs_recursive;
	return $TableSpec;
}



sub read_records {
	my $self = shift;
	my $params = shift;
	
	scream($params);

}





# This is the meat of serving data requests.
#   * calculate a list of columns which should be selected,
#   * call DbicExtQuery to get the ResultSet,
#   * build hashes form the result
sub read_records1 {
	my ($self, $params)= @_;
	
	# only touch request if params were not supplied
	$params ||= $self->c->req->params;
	
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	
	if (defined $params->{columns}) {
		if (!ref $params->{columns}) {
			my $decoded = $self->json->decode($params->{columns});
			$params->{columns} = $decoded;
		}
		
		$self->prepare_req_columns($params->{columns});
		

	}
	
	my @arg = ( $params );
	push @arg, $self->read_extra_search_set if ($self->can('read_extra_search_set'));

	# Build the query
	my $Rs = $self->DbicExtQuery->build_data_fetch_resultset(@arg);
	
	# don't use Row objects
	$Rs= $Rs->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' });
	
	return {
		rows    => [ $Rs->all ],
		results => $Rs->pager->total_entries,
	};
}



sub get_request_Rs_attr {
	my $self = shift;
	my $params = shift;
	
	$params = {
		start => 0,
		limit => 100000,
		dir => 'asc',
		%$params
	};
	
	my $attr = {
		select => [],
		as => [],
		join => {},
		page => int($params->{start}/$params->{limit}) + 1,
		rows => $params->{limit}
	};
	
	$attr->{order_by} = {
		'-' . $params->{dir} => lc($self->TableSpec->resolve_dbic_colname($params->{sort},$attr->{join}))
	} if (defined $params->{sort} and defined $params->{dir});
	
	$params->{columns} = [] unless (defined $params->{columns});
	$params->{columns} = $self->json->decode($params->{columns}) unless (ref $params->{columns});
	
	# Remove duplicates:
	my %Seen = ();
	$params->{columns} = [ grep { ! $Seen{$_}++ } @{$params->{columns}} ];
	
	for my $col (@{$params->{columns}}) {
		my $dbic_name = $self->TableSpec->resolve_dbic_colname($col,$attr->{join});
		push @{$attr->{select}}, $dbic_name;
		push @{$attr->{as}}, $col;
	}
	
	# This makes it look prettier, but is probably not needed:
	#$attr->{join} = $self->TableSpec->hash_with_undef_values_to_array_deep($attr->{join});
	
	return $attr;
}





1;