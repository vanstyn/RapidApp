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
		 column_list		=> 'values',
		 num_columns		=> 'count'
	}
);

sub column_list_ordered {
	my $self = shift;
	return sort { $a->order <=> $b->order } $self->column_list; 
}

sub column_names_ordered {
	my $self = shift;
	my @list = ();
	
	foreach my $Column ($self->column_list_ordered) {
		push @list, $Column->name;
	}
	return @list;
}


sub columns_properties_limited {
	my $self = shift;
	my $hash = {};
	foreach my $Column ($self->column_list) {
		$hash->{$Column->name} = $Column->properties_limited(@_);
	}
	return $hash;
}


sub add_columns {
	my $self = shift;
	my @cols = (@_);
	
	foreach my $col (@cols) {
		my $Column;
		$Column = $col if (ref($col) eq 'RapidApp::TableSpec::Column');
		$Column = RapidApp::TableSpec::Column->new($col) unless ($Column);
		
		$Column->order($self->num_columns + 1) unless (defined $Column->order);
		
		#die "A column named " . $Column->name . ' already exists.' if (defined $self->has_column($Column->name));
		
		$self->apply_columns( $Column->name => $Column );
	}
}


sub apply_column_properties { 
	my $self = shift;
	
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	my $hash = \%new;
	
	foreach my $col (keys %$hash) {
		my $Column = $self->get_column($col) or die "apply_column_properties failed - no such column '$col'";
		$Column->set_properties($hash->{$col});
	}
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;