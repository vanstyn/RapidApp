# We extend the metaclass here to hold a list of attributes which are "grid config" parameters.
# Note that to properly handle dynamic package modifications we would need to  invalidate this cache in many
#    circumstances, which would add a lot of complexity to this class.
# As long as we define attributes at compile-time, and call grid_config_attr_names at runtime, we can keep things simple.
package RapidApp::Column::Meta::Class;
use Moose;
BEGIN {
	extends 'Moose::Meta::Class';
	
	has '_grid_config_attr_names' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
	sub _build__grid_config_attr_names {
		my $self= shift;
		return [ map { $_->name } grep { $_->does('RapidApp::Role::GridColParam') } $self->get_all_attributes ];
	}
	
	sub grid_config_attr_names { return @{(shift)->_grid_config_attr_names} }
	
	__PACKAGE__->meta->make_immutable;
}

#-----------------------------------------------------------------------
#  And now, for the main package.
#
package RapidApp::Column;

BEGIN{ Moose->init_meta(for_class => __PACKAGE__, metaclass => 'RapidApp::Column::Meta::Class'); }

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


has 'editor' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
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

has 'no_column' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'no_multifilter' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'no_quick_search' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'data_type'	=> ( is => 'rw', default => undef );

has 'filter'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'field_cnf'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );
has 'rel_combo_field_cnf'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'field_cmp_config'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

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

sub applyIf_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (defined $new{$attr->name});
		$attr->set_value($self,$new{$attr->name}) unless ($attr->get_value($self)); # <-- only set attrs that aren't already set
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
	my $val;
	return { map { defined($val= $self->$_)? ($_ => $val)  :  () } $self->meta->grid_config_attr_names };
	
	#for my $attrName (@{&meta_gridColParam_attr_names($self->meta)}) {
	#	my $val= $self->$attrName();
	#	$config->{$attrName}= $val if defined $val;
	#}
	#return $config
	
	#return $self->get_config_for_traits('RapidApp::Role::GridColParam');
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
	
	$self->field_cmp_config($cnf);
	
	return $cnf;
}
## -- ^^^ --

no Moose;
__PACKAGE__->meta->make_immutable;
1;
