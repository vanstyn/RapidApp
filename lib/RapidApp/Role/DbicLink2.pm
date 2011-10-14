package RapidApp::Role::DbicLink2;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::ColSpec;

#sub BUILDARGS {}
around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$opt{init_colspec_data} = {};
	# Attributes ending in '_colspec' have a special meaning:
	/_colspec$/ and $opt{init_colspec_data}{$_} = delete $opt{$_} for (keys %opt);
	
	return $class->$orig(%opt);
};

has 'init_colspec_data' => ( is => 'ro', isa => 'HashRef' );

sub BUILD {}
around 'BUILD' => sub { &DbicLink_around_BUILD(@_) };
sub DbicLink_around_BUILD {
	my $orig = shift;
	my $self = shift;
	
	$self->init_colspec_attributes;
	
	$self->$orig(@_);
	
}

has '_init_colspec_attributes_completed' => ( is => 'rw', isa => 'Bool', default => 0 );
sub init_colspec_attributes {
	my $self = shift;
	my $hash = $self->init_colspec_data;
	
	die "colspec attributes have already been initialized, init_colspec_attributes should only be called once"
		if ($self->_init_colspec_attributes_completed);
	
	$hash->{include_colspec} = '*' unless (defined $hash->{include_colspec});
	
	foreach my $attr_name (keys %$hash) {
		my $attr = $self->meta->find_attribute_by_name($attr_name) or die "Invalid colspec attribute supplied: '$attr_name'";
		$attr->set_value($self, $self->create_ColSpec(delete $hash->{$attr_name}) );
	}
	return $self->_init_colspec_attributes_completed(1);
}

sub create_ColSpec {
	my $self = shift;
	my $spec = shift;
	$spec = $spec->spec if (ref($spec) eq 'RapidApp::ColSpec');
	return RapidApp::ColSpec->new( 
		spec => $spec,
		ResultSource => $self->ResultSource
	);
}



# Colspec attrs can be specified as simple arrayrefs
has 'include_colspec' => ( is => 'ro', isa => 'RapidApp::ColSpec' );


has 'ResultSource' => (
	is => 'ro',
	isa => 'DBIx::Class::ResultSource',
	required => 1
);






1;