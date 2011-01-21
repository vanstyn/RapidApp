package RapidApp::Column;
use Moose;

use Term::ANSIColor qw(:constants);

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

has 'id' => ( 
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
	my $config= {};
	for my $attrName (@{&meta_gridColParam_attr_names($self->meta)}) {
		my $val= $self->$attrName();
		$config->{$attrName}= $val if defined $val;
	}
	return $config
	#return $self->get_config_for_traits('RapidApp::Role::GridColParam');
}

=pod
These were intended to be Meta role methods, but that feature is broken, so they are slightly
unusual functions so that they can be converted back when Moose people fix the feature.

function meta_gridColParam_attr_names returns a ArrayRef of attribute names which have the trait
'GridColParam', and caches this list in the metaclass object.  Thus, one cache gets created per
subclass, which is what we want, because each subclass might define new grid attributes.
=cut
sub meta_gridColParam_attr_names {
	my $meta= shift;
	$meta->{gridColParam_attr_names} ||= &meta__build_gridColParam_attr_names($meta);
}
sub meta__build_gridColParam_attr_names {
	my $meta= shift;
	return [ map { $_->does('RapidApp::Role::GridColParam')? $_->name : () } $meta->get_all_attributes ];
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

## -- vvv -- new parameters for Forms:
has 'field_readonly' => ( 
	is => 'rw', 
	traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
	isa => 'Bool', 
	default => 0 
);

has 'field_readonly_config' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_field_readonly_config			=> 'set',
		 get_field_config_readonly_param		=> 'get',
		 has_field_config_readonly_param		=> 'exists',
		 has_no_field_readonly_config 		=> 'is_empty',
		 delete_field_readonly_config_param	=> 'delete'
	},
);

has 'field_config' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_field_config			=> 'set',
		 get_field_config_param		=> 'get',
		 has_field_config_param		=> 'exists',
		 has_no_field_config 		=> 'is_empty',
		 delete_field_config_param	=> 'delete'
	},
);

sub get_field_config {
	my $self = shift;
	
	my $cnf = { 
		name		=> $self->name,
		%{ $self->field_config } 
	};
	
	$cnf = { %$cnf, %{$self->field_readonly_config} } if ($self->field_readonly);
	
	return $cnf;
}
## -- ^^^ --

no Moose;
__PACKAGE__->meta->make_immutable;
1;
