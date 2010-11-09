package RapidApp::DbicAppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppGrid2';



use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);

use RapidApp::MooseX::ClassAttrSugar;
setup_add_methods_for('config');
setup_add_methods_for('listeners');




add_default_config(
	remote_columns		=> \1,
	loadMask				=> \1

);

has 'include_columns' => ( is => 'ro', default => sub {[]} );
has 'exclude_columns' => ( is => 'ro', default => sub {[]} );


has 'include_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->include_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});

has 'exclude_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->exclude_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});



has 'join_map' => ( is => 'rw', lazy => 1, builder => '_build_join_map', isa => 'HashRef' );
sub _build_join_map {
	my $self = shift;
	
	my $map = {};
	my $recurse;
	$recurse = sub {
		my $Source = shift;
		my $join = shift;
		
		if (ref($join)) {
			if (ref($join) eq 'ARRAY') {
				foreach my $sub (@$join) {
					$recurse->($Source,$sub);
				}
			}
			
			if (ref($join) eq 'HASH') {
				foreach my $rel (keys %$join) {
					my $info = $Source->relationship_info($rel);
					my $subSource = $Source->schema->source($info->{class});
					$recurse->($subSource,$join->{$rel});
				}
			}
		
		}
		else {
			$map->{$Source->source_name}->{$join} = 1;
		
		}
	};
	
	$recurse->($self->ResultSource,$self->joins);
	
	return $map;
}





sub BUILD {
	my $self = shift;
	
	$self->add_store_config(
		remoteSort => \1
	);





	#$self->add_column(
	#	'status.status' => {
	#		name	=> 'status.status',
	#		header	=> 'status_status',
	#		dataIndex	=> 'status_status',
	#		width	=> 100
	#	
	#	}
	#);

	
	#$self->add_column(
	#	'status' => {
	#		name	=> 'status',
	#		header	=> 'status',
	#		width	=> 100,
	#		dataIndex => 'status'
	#	
	#	}
	#);
	
	my $fieldSub = sub {
		my ($Source, $column, $colname) = @_;
		my $field = { 
			name 			=> $colname,	
			header 		=> $colname, 
			dataIndex	=> $colname, 
			sortable		=> \1,
			width 		=> 70 
		};
		
		my $col_info = $Source->column_info($column);
		my $type = $col_info->{data_type};
		
		if ($self->numeric_type($type)) {
			$field->{data_type} = 'numeric';
		}
		elsif($self->date_type($type)) {
			$field->{data_type} = 'date';
		}
		elsif ($type eq 'enum') {
			$field->{data_type} = 'list';
			$field->{filter} = { 
				type		=> 'list', 
				options	=> $col_info->{extra}->{list}
			};
		}
		
		return $field;
	};
	
	my $addColRecurse;
	$addColRecurse = sub {
		my $Source = shift;
		my $rel_name = shift;
		my $prefix = shift;
		
		foreach my $column ($Source->columns) {
			
			my $colname = $column;
			$colname = $prefix . '_' . $column if ($prefix);
			
			next unless ($self->valid_colname($colname));
			
			$self->fieldname_transforms->{$colname} = $rel_name . '.' . $column unless ($colname eq $column);
			
			my $field = $fieldSub->($Source,$column,$colname);
			
			$self->add_column(
				$colname => $field
			);
		}

		foreach my $rel ($Source->relationships) {
			next unless (defined $self->join_map->{$Source->source_name}->{$rel});
		
			my $info = $Source->relationship_info($rel);
			#next unless ($info->{attrs}->{accessor} eq 'single');

			my $subSource = $Source->schema->source($info->{class});
			my $new_prefix = $rel;
			$new_prefix = $prefix . '_' . $rel if ($prefix);
			$addColRecurse->($subSource,$rel,$new_prefix);
			
		}
	};
	
	$addColRecurse->($self->ResultSource);
	
=pod
	foreach my $column ($self->ResultSource->columns) {
		my $field = $fieldSub->($self->ResultSource,$column,$column);
		
		$self->add_column(
			$column => $field
		);
	}

	foreach my $rel ($self->ResultSource->relationships) {
		my $info = $self->ResultSource->relationship_info($rel);
		next unless ($info->{attrs}->{accessor} eq 'single');

		my $Source = $self->ResultSource->schema->source($info->{class});
		
		foreach my $column ($Source->columns) {
			my $colname = $rel . '_' . $column;
			
			$self->fieldname_transforms->{$colname} = $rel . '.' . $column;
			
			my $field = $fieldSub->($Source,$column,$colname);
			
			$self->add_column(
				$colname => $field
			);
		}
	}
=cut
	
	use Data::Dumper;
	#print STDERR BLUE . Dumper($self->fieldname_transforms) . CLEAR;
	#print STDERR RED . Dumper($self->join_map) . CLEAR;
	#print STDERR BLUE . Dumper($self->columns) . CLEAR;
	
	#print STDERR RED . Dumper($self->store_config) . CLEAR;
	#
	
	
}


sub valid_colname {
	my $self = shift;
	my $name = shift;
	
	if (scalar @{$self->exclude_columns} > 0) {
		return 0 if (defined $self->exclude_columns_hash->{$name});
	}
	
	if (scalar @{$self->include_columns} > 0) {
		return 0 unless (defined $self->include_columns_hash->{$name});
	}
	
	return 1;
}





sub numeric_type {
	my $self = shift;
	my $type = shift;
	
	$type = lc($type);
	
	return 1 if (
		$type =~ /int/ or
		$type =~ /float/
	);
	return 0;
}

sub date_type {
	my $self = shift;
	my $type = shift;
	
	$type = lc($type);
	
	return 1 if (
		$type eq 'datetime' or
		$type eq 'timestamp'
	);
	return 0;
}




has 'fieldname_transforms' => ( is => 'ro', default => sub {{}});

=pod
#has 'fieldname_transforms' => ( is => 'ro', default => sub {{}} );
has 'fieldname_transforms' => ( is => 'ro', default => sub { return {};
	{
		'status'						=> 'status.status',
		'submitted_username'			=> 'submitted_user.username',
		'submitted_fullname'			=> 'submitted_user.full_name',
		'update_username'				=> 'update_user.username',
		'update_fullname'				=> 'update_user.full_name',
		'engineer_username'				=> 'engineer_user.username',
		'engineer_fullname'				=> 'engineer_user.full_name',
		'pricing_updated_username'		=> 'pricing_updated_user.username',
		'pricing_updated_fullname'		=> 'pricing_updated_user.full_name',
		'dist1_name'					=> 'dist1.name',
		'dist1_salesperson'				=> 'dist1_salesperson.name',
		'dist2_name'					=> 'dist2.name',
		'dist2_salesperson'				=> 'dist2_salesperson.name',
		
		'rsm_user_fullname'				=> 'rsm_user.full_name',
		'rsm_user_id'					=> 'rsm_user.id',
		'product_category'				=> 'product_category.category',
		'discount'						=> 'discount.discount'
		
		#'attachments_count' => { count => 'attachments.id' },
		
		#'rsm_user_fullname'				=> 'dist1.rsm_user.full_name',
	};
});
=cut




has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	
	my $cnf = {
		ResultSource			=> $self->ResultSource,
		ExtNamesToDbFields 		=> $self->fieldname_transforms,
		joins 					=> $self->joins,
		#implied_joins			=> 1
		#group_by				=> [ 'me.id' ],
	};
	
	#$cnf->{columns} = $self->json->decode($self->c->req->params->{columns}) if (
	#	defined $self->c->req->params->{columns}
	#);
	
	return RapidApp::DbicExtQuery->new($cnf);
}




sub read_records {
	my $self = shift;

	my $params = $self->c->req->params;
	
	#delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	if(defined $params->{columns} and not ref($params->{columns})) {
		my $decoded = $self->json->decode($params->{columns});
		$params->{columns} = $decoded;
		
		# If custom columns have been provided, we have to make sure that "id" is among them.
		# This is required to properly support the "Project" page which is opened by double-clicking
		# a grid row. The id field must be loaded in the Ext Record because this is used by the
		# Project page to query the database for the given project:
		#push @{$params->{columns}}, 'id';
		
		# We can't limit the fields if there is a query (because it needs to be able to search 
		# in all fields and all relationships:
		#delete $params->{columns} if (defined $params->{query});
	};
	
	
	#$params->{columns} = [] unless ($params->{columns});
	#push @{$params->{columns}}, 'status';
	

=pod
	# --- Exclude `deleted`:
	push @{$params->{columns}}, 'deleted' if (defined $params->{columns});
	my $filters = [];
	$filters = $self->json->decode($params->{filter}) if (defined $params->{filter} and $params->{filter} ne '');
	push @$filters, {
		field		=> 'deleted',
		type		=> 'numeric',
		comparison	=> 'eq',
		value		=> 0
	};
	$params->{filter} = $filters;
	# ---
=cut


	my $data = $self->DbicExtQuery->data_fetch($params);

	my $rows = [];
	foreach my $row (@{$data->{rows}}) {
		my $hash = { $row->get_columns };
		#$hash->{'status_status'} = $row->status->status;
		#$hash->{'status_status'} = 'Foo';
		#$hash->{icon} = '<img src="/static/rapidapp/images/form_green.png">';
		push @$rows, $hash;
	}
	
	my $result = {
		results		=> $data->{totalCount},
		rows		=> $rows
	};
	
	use Data::Dumper;
	#print STDERR YELLOW . Dumper($result) . CLEAR;
	
	return $result;

}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;