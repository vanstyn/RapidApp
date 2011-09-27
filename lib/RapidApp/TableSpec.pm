package RapidApp::TableSpec;
use strict;
use Moose;

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places

use RapidApp::TableSpec::Column;

our $VERSION = '0.1';


has 'name' => ( is => 'ro', isa => 'Str', required => 1 );

has 'columns'  => (
	traits	=> ['Hash'],
	is        => 'ro',
	isa       => 'HashRef[RapidApp::TableSpec::Column]',
	default   => sub { {} },
	handles   => {
		 apply_columns		=> 'set',
		 get_column			=> 'get',
		 has_column			=> 'exists',
		 column_list		=> 'values'
	}
);


sub add_columns {
	my $self = shift;
	my @cols = (@_);
	
	foreach my $col (@cols) {
		my $Column;
		$Column = $col if (ref($col) eq 'RapidApp::TableSpec::Column');
		$Column = RapidApp::TableSpec::Column->new($col) unless ($Column);
		
		#die "A column named " . $Column->name . ' already exists.' if (defined $self->has_column($Column->name));
		
		$self->apply_columns( $Column->name => $Column );
	}
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;