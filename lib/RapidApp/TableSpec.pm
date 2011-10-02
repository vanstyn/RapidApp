package RapidApp::TableSpec;
use strict;
use Moose;

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places

use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::Column;

our $VERSION = '0.1';


has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'header_prefix' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

# Hash of CodeRefs to programatically change Column properties
has 'column_property_transforms' => ( is => 'ro', isa => 'Maybe[HashRef[CodeRef]]', default => undef );

# Hash of static changes to apply to named properties of all Columns
has 'column_properties' => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

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
		 column_names		=> 'keys',
		 num_columns		=> 'count'
	}
);
after 'apply_columns' => sub { (shift)->prune_invalid_columns };
around 'column_list' => sub {
	my $orig = shift;
	my $self = shift;
	my @names = $self->column_names;
	my @list = ();
	foreach my $name (@names) {
		# Force column_list to go through get_column so its logic gets called:
		push @list, $self->get_column($name);
	}
	return @list;
};
around 'get_column' => sub {
	my $orig = shift;
	my $self = shift;
	my $Column = $self->$orig(@_);
	
	return $Column unless (
		defined $self->column_property_transforms or (
			defined $self->column_properties and
			defined $self->column_properties->{$Column->name}
		)
	);
	
	my $trans = $self->column_property_transforms;
	my $cur_props = $Column->all_properties_hash;
	my %change_props = ();
	
	foreach my $prop (keys %$trans) {
		next unless (defined $cur_props->{$prop});
		$change_props{$prop} = $trans->{$prop}->($cur_props->{$prop});
	}
	
	%change_props = ( %change_props, %{ $self->column_properties->{$Column->name} } ) if (
		defined $self->column_properties and
		defined $self->column_properties->{$Column->name}
	);
	
	return $Column->copy(%change_props);
};



has 'limit_columns' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef, trigger => \&prune_invalid_columns );
has 'exclude_columns' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef, trigger => \&prune_invalid_columns );

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
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my %attr = ();
	my %other = ();
	
	foreach my $opt (keys %opts) {
		if ($self->meta->find_attribute_by_name($opt)) {
			$attr{$opt} = $opts{$opt};
		}
		else {
			$other{$opt} = $opts{$opt};
		}
	}
	
	my $Copy = $self->meta->clone_object($self,%attr);
	
	foreach my $key (keys %other) {
		$Copy->$key($other{$key}) if ($Copy->can($key));
	}
	
	return $Copy;
}

sub add_columns_from_TableSpec {
	my $self = shift;
	my $TableSpec = shift;
	
	foreach my $Column ($TableSpec->column_list_ordered) {
		$Column->clear_order;
		$self->add_columns($Column);
	}
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;