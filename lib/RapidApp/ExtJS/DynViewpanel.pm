package RapidApp::ExtJS::DynGrid;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Grid code object
#
#
# 2009-10-24:	Version 0.2 (HV)
#	Made "Strip Received Headers" actually work when enabled


use strict;
use Clone;



my $VERSION = '0.1';


sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->Params(shift) or return undef;
	
	return $self;
}


sub Params {
	my $self = shift;
	unless (defined $self->{Params}) {
		my $p = shift;
		return undef unless (
			defined $p 						and
			ref($p) eq 'HASH' 				and
			defined $p->{data_url}		and
			defined $p->{field_list}	
		);
		
		$p->{xtype} 		= 'dyngrid'		unless (defined $p->{xtype});
		$p->{layout}		= 'fit' 			unless (defined $p->{layout});
		$p->{gridid}		= 'mygrid'		unless (defined $p->{gridid});
	
		$self->{Params} = $p;
	}
	
	$self->{Params}->{store_model} 	= $self->store_model;
	$self->{Params}->{column_model}	= $self->column_model;
	
	return $self->{Params};
}

sub ext_config { return (shift)->Params; }
sub field_list { return @{ (shift)->{Params}->{field_list} }; }


sub insert_field {
	my $self = shift;
	my $pos = shift;
	my $field = shift;
	
	return undef unless (
		ref($field) eq 'HASH' and
		$pos =~ /^\d+$/
	);
	
	splice @{$self->Params->{field_list}}, $pos, 0, $field;
}


sub delete_field {
	my $self = shift;
	my $field_name = shift;
	
	my $pos = $self->field_pos_by_name($field_name);
	return undef unless (defined $pos);
	return splice @{$self->Params->{field_list}}, $pos, 1;
}


sub field_pos_by_name {
	my $self = shift;
	my $field_name = shift;
	
	my $i = 0;
	foreach my $field ($self->field_list) {
		return $i if ($field->{name} eq $field_name);
		$i++;
	}
	return undef;
}

sub grid_rows {
	my $self = shift;
	$self->{grid_rows} = [] unless (ref($self->{grid_rows}) eq 'ARRAY');
	
	if (scalar @_ > 0) {
		foreach my $row (@_) {
			next unless (ref($row) eq 'HASH');
			
			my $h = {};
			foreach my $k (keys %{$row}) {
				$h->{$k} = '<span>' . $row->{$k} . '</span>';
			}
			push @{$self->{grid_rows}}, $row;
		}
		
	}
	return $self->{grid_rows};
}

sub store_model {
	my $self = shift;
	
	my $a = [];
	
	foreach my $field ($self->field_list) {
		my $h = {};
		
		$h->{name} 		= $field->{name};
		
		push @{$a}, $h;
	}

	return $a;
}





sub column_model {
	my $self = shift;
	
	my $a = [];
	
	foreach my $field ($self->field_list) {
		
		my $h = Clone::clone($field);
		$h->{header} 			= $field->{name} unless (defined $h->{header});
		$h->{dataIndex} 		= $field->{name} unless (defined $h->{dataIndex});
		$h->{sortable}			= 1 unless (defined $h->{sortable});
		
		
		#my $h = {};
		
		#$h->{header} 			= $field->{name};
		#$h->{header} 			= $field->{header} if (defined $field->{header});
		#$h->{width} 			= $field->{width};
		#$h->{dataIndex}		= $field->{name};
		#$h->{sortable}			= 1;
		#$h->{sortable}			= $field->{sortable} if (defined $field->{sortable});
		#$h->{menuDisabled}	= $field->{menuDisabled} if (defined $field->{menuDisabled});
		#$h->{tooltip} 			= $field->{tooltip} if (defined $field->{tooltip});
		#$h->{id}					= $field->{id} if (defined $field->{id});

		
		
		# ---- Shouldn't be doing this here, bad:
		if ($h->{id} eq 'PRI_KEY') {
			$h->{header} =  $h->{header} . '<img class="icon-bullet_key" src="/static/extjs/resources/images/default/s.gif">' ;
		}
		# ----
		
		push @{$a}, $h;
	}

	return $a;

}

1;