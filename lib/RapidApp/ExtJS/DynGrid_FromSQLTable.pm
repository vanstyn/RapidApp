package RapidApp::ExtJS::DynGrid_FromSQLTable;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Grid code object
#
#
# 2009-10-24:	Version 0.2 (HV)
#	Made "Strip Received Headers" actually work when enabled


use strict;
use RapidApp::ExtJS::DynGrid;
use Term::ANSIColor qw(:constants);


my $VERSION = '0.1';


sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->{Params} = shift;
	
	my %h = %{$self->{Params}};
	
	delete $h{dbh};
	$h{data_url} = $self->data_url;
	$h{field_list} = $self->fields;
	
	my $DynGrid = RapidApp::ExtJS::DynGrid->new(\%h);
	
	$DynGrid->grid_rows($self->table_rows);
	
	return $DynGrid;
}

sub dbh				{ return (shift)->{Params}->{dbh}; }
sub table				{ return (shift)->{Params}->{table}; }
sub data_url			{ return (shift)->{Params}->{data_url}; }



sub fields_old {
	my $self = shift;
	my $sql = 'show columns from ' . $self->table;
	
	$a = [];
	
	foreach my $field (@{ $self->dbh->selectcol_arrayref($sql) }) {
	
		push @{$a}, {
			name		=> $field,
			width		=> 60
		};
	}
	

	return $a;
}


sub fields_old_old {
	my $self = shift;
	
	my $sql = 'select * from ' . $self->table . ' limit 1';
	
	
	print STDERR  'fields(): ' . YELLOW . BOLD . $sql . CLEAR . "\n";
	
	my $a = [];
	
	my $row = $self->dbh->selectrow_hashref($sql);
	
	foreach my $field (keys %{$row} ) {
		push @{$a}, {
			name		=> $field,
			width		=> 60
		};
	}
	
	return $a;
}


sub fields {
	my $self = shift;
	
	delete $self->{pri_keys} if (defined $self->{pri_keys});
	
	my $sql = 'describe ' . $self->table;
	
	my $arr_ref = $self->dbh->selectall_arrayref($sql, { Slice => {} }) or return ();
	my $a = [];
	
	push @{$a}, {
		header			=> ' ',
		width				=> 22,
		name				=> 'edit',
		menuDisabled	=> 1,
		sortable			=> 0,
		id					=> 'editIcon'
	};
	
	
	foreach my $field (@{ $arr_ref }) {
	
		my $h = {
			name		=> $field->{Field},
			width		=> 10
		};
		
		if ($field->{Key} eq 'PRI') {
			$h->{id} = 'PRI_KEY';
			$self->{pri_keys}->{$h->{name}} = 1;
		}
		
		push @{$a}, $h;
	}
	
	#push @{$a}, {
	#	name				=> 'where_clause',
	#	hidden			=> 1,
	#};
	
	
	push @{$a}, {
		#width				=> 60,
		name				=> 'where_clause',
		menuDisabled	=> 1,
		#sortable			=> 1,
		hidden			=> 1
	};
	
	
	# If this table has no primary keys, we add ALL fields to the pri_keys hash:
	unless (defined $self->pri_keys) {
		foreach my $field (@{ $arr_ref }) {
			$self->pri_keys->{$field->{Field}} = 1;
		}
	}
	
	return $a;
}

sub pri_keys {
	my $self = shift;
	return $self->{pri_keys};
}


sub table_rows {
	my $self = shift;
	
	my $sql = 'select * from ' . $self->table . ' limit 200';
	
	print STDERR  'table_rows(): ' . YELLOW . BOLD . $sql . CLEAR . "\n";
	
	my $a = $self->dbh->selectall_arrayref($sql, { Slice => {} }) or return ();
	
	foreach my $row ( @{$a} ) {
		next unless (ref($row) eq 'HASH');
		
		my @w = ();
		foreach my $k (keys %{$row}) {
			next unless (defined $self->pri_keys and defined $self->pri_keys->{$k});
			push(@w, $self->dbh->quote_identifier($k) . ' = ' . $self->dbh->quote($row->{$k}));
		}
		
		$row->{where_clause} = 'where ' . join(' and ', @w);
	
	}
	
	
	
	return @{$a};
}


1;