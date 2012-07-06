package RapidApp::DBIC::Component::VirtualColumnsExt;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class');

use RapidApp::Include qw(sugar perlutil);

# Load the vanilla/original DBIx::Class::VirtualColumns component:
__PACKAGE__->load_components(qw/VirtualColumns/);

__PACKAGE__->mk_classdata( '_virtual_columns_order' );

sub init_vcols_class_data {
	my $self = shift;
	
	$self->_virtual_columns( {} )
        unless defined $self->_virtual_columns();
     
    $self->_virtual_columns_order( [] )
        unless defined $self->_virtual_columns_order();
}

# extend add_virtual_columns to also track column order
sub add_virtual_columns {
	my $self = shift;
    my @columns = @_;
	
	$self->init_vcols_class_data;
	
	foreach my $column (@columns) {
		next if (
			ref $column or
			$self->has_column($column) or 
			exists $self->_virtual_columns->{$column} #<-- redundant since we override 'has_column'
		);
		
		push @{$self->_virtual_columns_order}, $column;
	}
	
	return $self->next::method(@_);
}

sub virtual_columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return @{$self->_virtual_columns_order};
}

# Take-over has_column to include virtual columns
sub has_column {
    my $self = shift;
    my $column = shift;
	$self->init_vcols_class_data;
    return ($self->_virtual_columns->{$column} ||
        $self->next::method($column)) ? 1:0;
}

# Take-over columns to include virtual columns:
sub columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return ($self->next::method(@_),$self->virtual_columns);
}

1;
