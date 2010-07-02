package RapidApp::DbicAppGrid;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS custom app object
#
#
# 2010-05-24:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::AppGrid';


our $VERSION = '0.1';

use RapidApp::DbicExtQuery;

use DateTime::Format::Flexible;
use JSON;

use Term::ANSIColor qw(:constants);

use Switch;

#### --------------------- ####

has 'db_name'						=> ( is => 'ro',	required => 0,		isa => 'Str'														);
has 'ResultSource'				=> ( is => 'ro',	required => 1, 	isa => 'DBIx::Class::ResultSource'							);
has 'ResultSet'					=> ( is => 'ro',	lazy_build => 1,	init_arg => undef, isa => 'DBIx::Class::ResultSet'		);
has 'source_name'					=> ( is => 'ro',	lazy_build => 1,	init_arg => undef, isa => 'Str'								);
has 'dsn'							=> ( is => 'ro',	lazy_build => 1,	init_arg => undef													);

has 'DbicExtQuery'				=> ( is => 'ro',	lazy_build => 1,	init_arg => undef, isa => 'RapidApp::DbicExtQuery'		);

has 'pri_keys'						=> ( is => 'ro',	lazy_build => 1,	init_arg => undef, isa => 'ArrayRef'							);
has 'first_key'					=> ( is => 'ro',	lazy_build => 1,	init_arg => undef, isa => 'Str'								);

has 'row_icon'						=> ( is => 'ro',	lazy_build => 1																			);
has 'fields'						=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'ArrayRef'					);
has 'init_fields_hash'			=> ( is => 'rw',	default => sub {{}}, init_arg => undef,		isa => 'HashRef'					);
has 'datafetch_coderef'			=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'CodeRef'					);
has 'itemfetch_coderef'			=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'CodeRef'					);
has 'edit_item_coderef'			=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'CodeRef'					);
has 'delete_item_coderef'		=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'CodeRef'					);
has 'add_item_coderef'			=> ( is => 'ro',	lazy_build => 1,	init_arg => undef,			isa => 'CodeRef'					);

has 'labelAlign'					=> ( is => 'ro',	required => 0,		default => 'top'													);
has 'edit_form_ajax_load'		=> ( is => 'ro',	required => 0,		default => 1														);
has 'custom_edit_form_items'	=> ( is => 'ro',	lazy_build => 1																			);
has 'custom_add_form_items'	=> ( is => 'ro',	lazy_build => 1																			);

has 'no_rowactions'				=> ( is => 'ro',	required => 0,		default => 1														);

has 'edit_window_height' 		=> ( is => 'ro',	default => 500																				);
has 'edit_window_width' 		=> ( is => 'ro',	default => 580																				);


sub BUILD {}
after 'BUILD' => sub {
	my $self = shift;
	my $params;
	if (ref($_[0]) eq 'HASH') {
		$params = $_[0];
	}
	else {
		$params = \%_;
	}
	
	if (defined $params->{fields} and ref($params->{fields}) eq 'ARRAY') {
		my $h = {};
		foreach my $field (@{$params->{fields}}) {
			$h->{$field->{name}} = $field;
		}
		$self->init_fields_hash($h);
	}

	if ($self->dsn and $self->dsn =~ /dbi\:mysql/i) {
		$self->ResultSource->storage->sql_maker->quote_char(q{`});
		$self->ResultSource->storage->sql_maker->name_sep(q{.});
	}
};


sub _build_ResultSet {
	my $self = shift;
	return $self->ResultSource->resultset;
}

sub _build_source_name {
	my $self = shift;
	return $self->ResultSource->source_name;
}


sub _build_dsn {
	my $self = shift;
	my $connect_info = $self->ResultSource->storage->connect_info;
	
	my $d = shift @$connect_info;
	return $d->{dsn} if (ref($d) eq 'HASH' and defined $d->{dsn});
	return $d;
}


sub _build_DbicExtQuery {
	my $self = shift;
	return RapidApp::DbicExtQuery->new( ResultSource => $self->ResultSource );
}


sub _build_pri_keys {
	my $self = shift;
	
	my $pri_keys = [ $self->ResultSource->primary_columns ];
	$pri_keys = [ $self->ResultSource->columns ] unless (scalar @$pri_keys > 0);
	
	return $pri_keys;
}

sub _build_first_key {
	my $self = shift;
	return $self->pri_keys->[0];
}
	

sub _build_fields { 
	my $self = shift;

	my @list = ();

	foreach my $column ($self->ResultSource->columns) {
		my $field = { name => $column,	header => $column, width => 20 };
		$field = $self->init_fields_hash->{$column} if (defined $self->init_fields_hash->{$column});
		
		my $col_info = $self->ResultSource->column_info($column);
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
		
		$field->{edit_allow} = 1 unless (defined $field->{edit_allow});
		
		push @list, $field;
	}
	return \@list;
}


sub _build_custom_add_form_items {
	my $self = shift;
	return $self->custom_edit_form_items;
}

sub _build_custom_edit_form_items {
	my $self = shift;

	my $form_fields = [];
			
	foreach my $column ($self->ResultSource->columns) {
		my $col_info = $self->ResultSource->column_info($column);
		my $field = {
			name			=> $column,
			fieldLabel	=> $column,
			#anchor		=> '85%',
			width			=> 380,
			xtype			=> 'textfield'
		};
		
		switch($col_info->{data_type}) {
		
			case 'text' {
				$field->{xtype} = 'textarea';
				$field->{height} = 180;
			}
			case 'enum' {
				$field->{enum_list} = $col_info->{extra}->{list};
				$self->set_field_combo($field);
				$field->{width} = int($field->{width}*0.6);
			}
			case ['timestamp','datetime'] {
				delete $field->{width};
				$field->{xtype}			= 'xdatetime';
				#$field->{width}	= 150;
				$field->{timeFormat}		= 'H:i:s';
				$field->{timeConfig}	= {
					altFormats	=> 'H:i:s',
					allowBlank	=> \1,
				};
				$field->{dateFormat} 	= 'Y-m-d';
				$field->{dateConfig} = {
					altFormats => 'm/d/Y|Y-n-d',
					allowBlank => \1,
				};
			}
			else {
			
			
			}
		}

		push @$form_fields, $field;
	}

	return $form_fields;
}




sub _build_datafetch_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
		
		my $data = $self->DbicExtQuery->data_fetch($params);
		
		my $rows = [];
		foreach my $row (@{$data->{rows}}) {
			push @$rows, $self->row_to_hash($row);
		}
		
		return {
			totalCount	=> $data->{totalCount},
			rows			=> $rows
		};
	};
}



sub _build_itemfetch_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
		
		my $h = {};
		foreach my $col (@{$self->pri_keys}) {
			defined $params->{$col} || die "primary key '$col' not in params, cannot fetch record";
			$h->{$col} = $params->{$col};
		}
		
		my $row = $self->Row_from_hashref($h) or return {};
		
		my %get_columns = $row->get_columns;
		return \%get_columns;
	};
}


sub _build_edit_item_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
		my $orig = shift;
	
		my $row = $self->Row_from_hashref($orig->{grid_row_params});
		
		#$row->set_columns($params);
		$row->update($params) or return {
			success	=> 0,
			msg		=> 'Update failed.'
		};

		return {
			success	=> 1,
			msg		=> 'Success'
		};
	};
}



sub _build_delete_item_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
	
		my $row = $self->Row_from_hashref($params);
		
		$row->delete or return {
			success	=> 0,
			msg		=> 'Delete failed.'
		};

		return {
			success	=> 1,
			msg		=> 'Success'
		};
	};
}


sub _build_add_item_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
		
		my $row = $self->ResultSet->new($params);
	
		$row->insert or return {
			success	=> 0,
			msg		=> 'Insert failed.'
		};

		return {
			success	=> 1,
			msg		=> 'Success'
		};
	};
}


###########################################################################################


sub Row_from_hashref {
	my $self = shift;
	my $params = shift;
	
	my @search = ();
	
	foreach my $k (keys %$params) {
		#push @search, { '`' . $k . '`' => $params->{$k} }; # <-- The fact these backtics are required means there is a bug in DBIC
		push @search, { $k => $params->{$k} };
	}
	
	my $search_spec = { -and => \@search };
		
	my $row = $self->ResultSet->single($search_spec);
	return $row;
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



sub row_to_hash {
	my $self = shift;
	my $row = shift;
	
	my $h = {};
	
	foreach my $field (@{$self->fields}) {
		my $f = $field->{name};
		$h->{$f} = $row->get_column($f);
	}
	return $h;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;