package RapidApp::TableSpec;
use strict;
use Moose;

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places

use RapidApp::Include qw(sugar perlutil);

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
after 'apply_columns' => sub { (shift)->prune_invalid_columns };

has 'limit_columns' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef );
has 'exclude_columns' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef );

sub prune_invalid_columns {
	my $self = shift;
	
	my @remove_cols = ();
	
	if (defined $self->limit_columns and scalar @{ $self->limit_columns } > 0) {
		my %map = map { $_ => 1 } @{ $self->limit_columns };
		push @remove_cols, grep { not defined $map{$_} } keys %{ $self->columns };
	}
	
	if (defined $self->exclude_columns and scalar @{ $self->exclude_columns } > 0) {
		my %map = map { $_ => 1 } @{ $self->exclude_columns };
		push @remove_cols, grep { defined $map{$_} } keys %{ $self->columns };
	}
	
	foreach my $remove (@remove_cols) {
		delete $self->columns->{$remove};
	}
}

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
		unless ($Column) {
			$Column = RapidApp::TableSpec::Column->new($col);
			$Column->set_properties($col);
		}
		
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


sub copy {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

}


no Moose;
__PACKAGE__->meta->make_immutable;
1;