package RapidApp::Column;
#
# -------------------------------------------------------------- #
#

use Term::ANSIColor qw(:constants);

use strict;
use warnings;
use Moose;

our $VERSION = '0.1';


has 'name' => ( 
	is => 'ro', required => 1, isa => 'Str', 
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'sortable' => ( 
	is => 'rw', 
	default => sub {\1},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'hidden' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'header' => ( 
	is => 'rw', lazy => 1, isa => 'Str', 
	default => sub { (shift)->name },
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'dataIndex' => ( 
	is => 'rw', lazy => 1, isa => 'Str', 
	default => sub { (shift)->name },
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'width' => ( 
	is => 'rw', lazy => 1, 
	default => 70,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'tpl' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'xtype' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'data_type'	=> ( is => 'rw', default => undef );

has 'filter'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'field_cnf'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'render_fn' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ],
	trigger => \&_set_render_fn,
);

sub _set_render_fn {
	my ($self,$new,$old) = @_;
	return unless ($new);
	
	#use Data::Dumper;
	#print STDERR YELLOW . BOLD . Dumper
	
	$self->xtype('templatecolumn');
	$self->tpl('{[' . $new . '(values.' . $self->name . ',values)]}');
}





sub apply_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (defined $new{$attr->name});
		$attr->set_value($self,$new{$attr->name});
		delete $new{$attr->name};
	}
	
	#There should be nothing left over in %new:
	if (scalar(keys %new) > 0) {
		#die "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes";
		use Data::Dumper;
		die  "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes :\n" . Dumper(\%new);
	}
}


sub get_grid_config {
	my $self = shift;
	return $self->get_config_for_traits('RapidApp::Role::GridColParam');
}


# returns hashref for all attributes with defined values that 
# match any of the list of passed traits
sub get_config_for_traits {
	my $self = shift;
	my @traits = @_;
	@traits = @{ $_[0] } if (ref($_[0]) eq 'ARRAY');
	
	my $config = {};
	
	foreach my $attr ($self->meta->get_all_attributes) {
		foreach my $trait (@traits) {
			if ($attr->does($trait)) {
				my $val = $attr->get_value($self);
				last unless (defined $val);
				$config->{$attr->name} = $val;
				last;
			}
		}
	}
		
	return $config;
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;
