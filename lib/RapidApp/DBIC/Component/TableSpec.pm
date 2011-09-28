package RapidApp::DBIC::Component::TableSpec;
use base 'DBIx::Class';

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;

__PACKAGE__->mk_classdata( 'TableSpec' );

sub apply_TableSpec {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$self->TableSpec(RapidApp::TableSpec->new( 
		name => $self->table,
		%opt
	));
	
	foreach my $col ($self->columns) {
		$self->TableSpec->add_columns( { name => $col } ); 
	}
}

	
sub TableSpec_add_columns_from_related {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
	
		my $info = $self->relationship_info($rel);
		my $TableSpec = $info->{class}->TableSpec or next;
		
		foreach my $Column ($TableSpec->column_list_ordered) {
			my $properties = $Column->all_properties_hash;
			$properties->{name} = $rel . '_' . $properties->{name};
			
			$properties->{header} = $conf->{header_prefix} . $properties->{header} if (
				$conf->{header_prefix} and
				$properties->{header}
			);
			
			%$properties = ( %$properties, %{ $conf->{column_properties}->{$Column->name} } ) if (
				defined $conf->{column_properties} and
				defined $conf->{column_properties}->{$Column->name}
			);
			
			delete $properties->{order};
			delete $properties->{label};
			
			$self->TableSpec->add_columns($properties);
		
		}
	}

}


1;
