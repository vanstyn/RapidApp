package RapidApp::DbicAppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppGrid2';

use RapidApp::DbicAppCombo;

use Switch;

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);

use RapidApp::MooseX::ClassAttrSugar;
setup_apply_methods_for('config');
setup_apply_methods_for('listeners');


apply_default_config(
	remote_columns		=> \1,
	loadMask				=> \1

);


has 'base_search_set' => ( is => 'ro',	default => undef );
has 'fieldname_transforms' => ( is => 'ro', default => sub {{}});
has 'primary_columns' => ( is => 'rw', default => sub {[]}, isa => 'ArrayRef');

has 'always_fetch_columns' => ( is => 'ro', default => undef );

sub apply_primary_columns {
	my $self = shift;
	my @cols = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	
	my %cur = ();
	foreach my $col (@{$self->primary_columns},@cols) {
		$cur{$col}++;
	}
	
	return $self->primary_columns([ keys %cur ]);
}


sub remove_primary_columns {
	my $self = shift;
	my @cols = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	
	my %remove = ();
	foreach my $rem (@cols) {
		$remove{$rem}++;
	}
	
	my %cur = ();
	foreach my $col (@{$self->primary_columns}) {
		next if ($remove{$col});
		$cur{$col}++;
	}
	
	return $self->primary_columns([ keys %cur ]);
}



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
	
	$self->apply_primary_columns($self->record_pk); # <-- should be redundant
	$self->apply_primary_columns($self->ResultSource->primary_columns);
	
	$self->apply_config(primary_columns => $self->primary_columns);
	
	$self->apply_store_config(
		remoteSort => \1
	);
	
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
		my $type = $self->dbic_to_ext_type($col_info->{data_type});
		$field->{filter}->{type} = $type if ($type);
		
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
			
			$self->apply_columns(
				$colname => $field
			);
			
			# -- Build combos (dropdowns) for every related field (for use in multifilters currently):
			if ($prefix) {
				$self->c->log->debug(MAGENTA . BOLD . $colname . ' (' . $rel_name . ')' . CLEAR);
				
				my $module_name = 'combo_' . $colname;
				$self->apply_modules({ 
					$module_name => {
						class	=> 'RapidApp::DbicAppCombo',
						params	=> {
							name				=> $column,
							ResultSource	=> $Source
						}
					}
				});
				
				$self->apply_columns(
					$colname => { field_cnf => $self->Module($module_name)->content }
				);
			}
			# --
		}

		foreach my $rel ($Source->relationships) {
			
			next unless (defined $self->join_map->{$Source->source_name}->{$rel});
		
			my $info = $Source->relationship_info($rel);
			
			use Data::Dumper;
			$self->c->log->debug(YELLOW . BOLD . Dumper($info) . CLEAR);
			
			#next unless ($info->{attrs}->{accessor} eq 'single');

			my $subSource = $Source->schema->source($info->{class});
			my $new_prefix = $rel;
			$new_prefix = $prefix . '_' . $rel if ($prefix);
			$addColRecurse->($subSource,$rel,$new_prefix);
			
		}
	};
	
	$addColRecurse->($self->ResultSource);
}


before 'ONREQUEST' => sub {
	my $self = shift;
	$self->applyIf_module_options( delete_records => 1 ) if($self->can('delete_rows'));
};

sub action_delete_records {
	my $self = shift;
	
	die "delete_rows method does not exist" unless ($self->can('delete_rows'));
	
	my $recs = $self->json->decode($self->c->req->params->{rows});
	
	my @Rows = ();
	foreach my $rec (@$recs) {
		my $search = {};
		foreach my $col (@{$self->primary_columns}) {
			$search->{$col} = $rec->{$col} if (defined $rec->{$col});
		}
		push @Rows, $self->ResultSource->resultset->single($search);
	}
	
	my $result = $self->delete_rows(@Rows);
	
	return {
		success => \1,
		msg => 'success'
	};
}



sub dbic_to_ext_type {
	my $self = shift;
	my $type = shift;
	
	$type = lc($type);
	
	switch ($type) {
		case (/int/ or /float/) {
			return 'number';
		}
		case ('datetime' or 'timestamp') {
			return 'date';
		}
	}
	return undef;
}




has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	
	my $cnf = {
		ResultSource			=> $self->ResultSource,
		ExtNamesToDbFields 	=> $self->fieldname_transforms,
		joins 					=> $self->joins,
		#implied_joins			=> 1
		#group_by				=> [ 'me.id' ],
	};
	
	$cnf->{base_search_set} = $self->base_search_set if (defined $self->base_search_set);
	
	#$cnf->{columns} = $self->json->decode($self->c->req->params->{columns}) if (
	#	defined $self->c->req->params->{columns}
	#);
	
	return RapidApp::DbicExtQuery->new($cnf);
}




sub read_records {
	my $self = shift;

	my $params = $self->c->req->params;
	
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	if(defined $params->{columns} and not ref($params->{columns})) {
		my $decoded = $self->json->decode($params->{columns});
		$params->{columns} = $decoded;
		
		# If custom columns have been provided, we have to make sure that the record_pk is among them.
		# This is required to properly support the "item" page which is opened by double-clicking
		# a grid row. The id field must be loaded in the Ext Record because this is used by the
		# item page to query the database for the given id:
		push @{$params->{columns}}, $self->record_pk if (defined $self->record_pk);
		
		push @{$params->{columns}}, @{$self->always_fetch_columns} if (defined $self->always_fetch_columns);
		
		# We can't limit the fields if there is a query (because it needs to be able to search 
		# in all fields and all relationships:
		delete $params->{columns} if (defined $params->{query});
	};
	

	my $data = $self->DbicExtQuery->data_fetch($params);

	my $rows = [];
	foreach my $row (@{$data->{rows}}) {
		my $hash = { $row->get_columns };
		push @$rows, $hash;
	}
	
	my $result = {
		results		=> $data->{totalCount},
		rows		=> $rows
	};

	return $result;
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;