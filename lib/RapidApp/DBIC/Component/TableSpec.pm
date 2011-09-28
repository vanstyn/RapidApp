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
		$conf = {} unless (ref($conf) eq 'HASH');
		$conf->{column_property_transforms}->{name} = sub { $rel . '_' . (shift) };
	
		my $info = $self->relationship_info($rel) or next;
		my $TableSpec = $info->{class}->TableSpec->copy($conf) or next;
		
		$self->TableSpec->add_columns_from_TableSpec($TableSpec);
	}
}


sub TableSpec_setup_editor_dropdowns {
	my $self = shift;
	foreach my $colspec (@_) { 
	
		my ($rel,$col) = split(/\./,$colspec,2);
		
		die "Invalid colspec '$colspec'" unless ($col);
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		scream($info);
		
		#print STDERR CYAN . BOLD . Dumper
	
	
	
	}
}



1;
