package RapidApp::TableSpec::Column;
use strict;
use Moose;

use RapidApp::Include qw(sugar perlutil);


our $VERSION = '0.1';

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places


# Base profiles are applied to all columns
sub DEFAULT_BASE_PROFILES {(
	'BASE'
)}


# Default named column profiles. Column properties will be merged
# with the definitions below if supplied by name in the property 'profiles'
sub DEFAULT_PROFILES {{
		
		BASE => { 
			renderer => ['Ext.ux.showNull'] ,
			editor => { xtype => 'textfield', minWidth => 80, minHeight => 22 }
		},
		
		nullable => {
			editor => { xtype => 'textfield', plugins => [ 'emptytonull' ] }
		},
		
		notnull => {
			editor => { xtype => 'textfield', plugins => [ 'nulltoempty' ] }
		},
		
		number => {
			editor => { xtype => 'numberfield', style => 'text-align:left;' }
		},
		int => {
		
		},
		bool => {
			# Renderer *not* in arrayref makes it replace instead of append previous
			# profiles with th renderer property as an arrayref
			renderer => 'Ext.ux.RapidApp.boolCheckMark',
			editor => { xtype => 'logical-checkbox', plugins => [ 'booltoint' ] }
		},
		text => {
			editor => { xtype => 'textfield' }
		},
		bigtext => {
			renderer 	=> ['Ext.util.Format.nl2br'],
			editor		=> { xtype => 'textarea', grow => \1 },
		},
		email => {
			editor => { xtype => 'textfield' }
		},
		datetime => {
			editor => { xtype => 'xdatetime2', minWidth => 200 },
			renderer => ["Ext.ux.RapidApp.getDateFormatter('M d, Y g:i A')"]
		},
		money => {
			editor => { xtype => 'textfield' },
			renderer => 'Ext.ux.showNullusMoney'
		},
		percent => {
			 renderer => ['Ext.ux.GreenSheet.num2pct']
		},
		noedit => {
			editor => ''
		}

}};


around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %params = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $profile_defs = $class->_build_profile_definitions;
	$profile_defs = merge($profile_defs, delete $params{profile_definitions}) if ($params{profile_definitions});
	
	$params{properties_underlay} = {} unless ($params{properties_underlay});
	$params{profiles} = [ $params{profiles} ] if ($params{profiles} and not ref($params{profiles}));
	
	my @base_profiles = ( $class->DEFAULT_BASE_PROFILES );
	push @base_profiles, @{ delete $params{base_profiles} } if($params{base_profiles});
	my @profiles = @base_profiles;
	push @profiles, @{ delete $params{profiles} } if ($params{profiles});
	
	# Apply/merge profiles if defined:
	$class->collapse_apply_profiles($profile_defs,$params{properties_underlay},@profiles);
	
	$params{profile_definitions} = $profile_defs;
	$params{base_profiles} = \@base_profiles;
	return $class->$orig(%params);
};


sub collapse_apply_profiles {
	my $self = shift;
	my $profile_defs = shift;
	my $target = shift or die "collapse_apply_profiles(): missing arguments";
	my @base_profiles = @_;
	
	my $profiles = [];
	$profiles = delete $target->{profiles} if($target->{profiles});
	$profiles = [ $profiles ] unless (ref $profiles);
	@$profiles = (@base_profiles,@$profiles);
	
	return unless (scalar @$profiles > 0);
	
	my $collapsed = {};
	foreach my $profile (@$profiles) {
		my $opt = $profile_defs->{$profile} or next;
		$collapsed = merge($collapsed,$opt);
	}

	%$target = %{ merge($target,$collapsed) };
}




has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'order' => ( is => 'rw', isa => 'Maybe[Int]', default => undef, clearer => 'clear_order' );
has 'permission_roles' => ( is => 'rw', isa => 'Maybe[HashRef[ArrayRef]]', default => undef );
has '_other_properties' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has 'base_profiles' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );

has 'profile_definitions' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
sub _build_profile_definitions {
	my $self = shift;
	my $defs = $self->DEFAULT_PROFILES();
	
	# TODO collapse sub-profile defs
	return $defs;
}


# properties that get merged under actual properties - collapsed from profiles:
has 'properties_underlay' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
sub apply_profiles {
	my $self = shift;
	my @profiles = @_;
	@profiles = @{$_[0]} if (ref $_[0]);
	
	return unless (scalar @profiles > 0);
	
	$self->collapse_apply_profiles(
		$self->profile_definitions,
		$self->properties_underlay,
		@profiles
	);
}

has 'exclude_attr_property_names' => ( 
	is => 'ro', isa => 'HashRef',
	default => sub {  
		my @list = (
			'exclude_property_names',
			'properties_underlay',
			'_other_properties'
		);
		return { map {$_ => 1} @list };
});


sub get_property {
	my $self = shift;
	my $name = shift;
	
	my $attr = $self->meta->get_attribute($name);
	return $attr->get_value($self) if ($attr);
	
	return $self->_other_properties->{$name};
}

sub set_properties {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$self->apply_profiles(delete $new{profiles}) if ($new{profiles});
	
	foreach my $key (keys %new) {
		my $attr = $self->meta->get_attribute($key);
		if ($attr and $attr->has_write_method) {
			$self->$key($new{$key});
		}
		else {
			$self->_other_properties->{$key} = $new{$key};
		}
	}
}

# Only sets properties not already defined:
sub set_properties_If {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $prop (keys %new) {
		$self->get_property($prop) and delete $new{$prop};
	}
	
	return $self->set_properties(%new);
}

sub all_properties_hash {
	my $self = shift;
	
	my %hash = %{ $self->_other_properties };
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next if ($self->exclude_attr_property_names->{$attr->name});
		next unless ($attr->has_value($self));
		$hash{$attr->name} = $attr->get_value($self);
	}
	
	return { %{$self->properties_underlay},%hash };
}

# Returns a hashref of properties that match the list/hash supplied:
sub properties_limited {
	my $self = shift;
	my $map;
	
	if (ref($_[0]) eq 'HASH') 		{	$map = shift;								}
	elsif (ref($_[0]) eq 'ARRAY')	{	$map = { map { $_ => 1 } @{$_[0]} };	}
	else 									{	$map = { map { $_ => 1 } @_ };			}
	
	my $properties = $self->all_properties_hash;
	
	my @keys = grep { $map->{$_} } keys %$properties;
	
	my $set = {};
	foreach my $key (@keys) {
		$set->{$key} = $properties->{$key};
	}
	
	return $set;
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
	
	my $Copy = $self->meta->clone_object(Clone::clone($self),%attr);
		#$self,
		#%attr, 
		# This shouldn't be required, but is. The clone doesn't clone _other_properties!
		#_other_properties => { %{ $self->_other_properties } }
	#);
	
	$Copy->set_properties(%other);

	return $Copy;
}


has 'rapidapp_init_coderef' => ( is => 'rw', isa => 'Maybe[CodeRef]', default => undef );
sub call_rapidapp_init_coderef {
	my $self = shift;
	return unless ($self->rapidapp_init_coderef);
	
	### Call ###
	$self->rapidapp_init_coderef->($self,@_);
	############

	# Clear:
	$self->rapidapp_init_coderef(undef);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;