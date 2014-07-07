package RapidApp::TableSpec::Column;

use strict;
use warnings;

# This class must declare the version because we declared it before (and PAUSE knows)
our $VERSION = '0.99301';

use Moose;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec::Column::Profile qw( get_set );


around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %params = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  # These options were never published/used and are being removed to
  # be able to implement a new design with better performance. But,
  # just in case they are out in the wild, catch and throw and error:
  my @bad_opts = qw(profile_definitions base_profiles);
  exists $params{$_} and die "Param '$_' no longer supported" for (@bad_opts);
  
	#my $profile_defs = $class->_build_profile_definitions;
	#$profile_defs = merge($profile_defs, delete $params{profile_definitions}) if ($params{profile_definitions});
	
	$params{properties_underlay} = {} unless ($params{properties_underlay});
	$params{profiles} = [ $params{profiles} ] if ($params{profiles} and not ref($params{profiles}));
	
	#my @base_profiles = ( $class->DEFAULT_BASE_PROFILES );
	#push @base_profiles, @{ delete $params{base_profiles} } if($params{base_profiles});
	#my @profiles = @base_profiles;
	#push @profiles, 
	
  my @profiles = $params{profiles} ? @{ delete $params{profiles} } : ();
  
	# Apply/merge profiles if defined:
	$class->collapse_apply_profiles($params{properties_underlay},@profiles);
	
	#$params{profile_definitions} = $profile_defs;
	#$params{base_profiles} = \@base_profiles;
	return $class->$orig(%params);
};


sub collapse_apply_profiles {
	my $self = shift;
	my $target = shift or die "collapse_apply_profiles(): missing arguments";
	my @base_profiles = @_;
	
	my $profiles = [];
	$profiles = delete $target->{profiles} if($target->{profiles});
	$profiles = [ $profiles ] unless (ref $profiles);
	@$profiles = (@base_profiles,@$profiles);
	
	return unless (scalar @$profiles > 0);
  
  my $collapsed = get_set(@$profiles);
	
	#my $collapsed = {};
	#foreach my $profile (@$profiles) {
	#	my $opt = $profile_defs->{$profile} or next;
	#	$collapsed = merge($collapsed,$opt);
	#}

	%$target = %{ merge($target,$collapsed) };
}




has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
#has 'order' => ( is => 'rw', isa => 'Maybe[Int]', default => undef, clearer => 'clear_order' );
has 'permission_roles' => ( is => 'rw', isa => 'Maybe[HashRef[ArrayRef]]', default => undef );
has '_other_properties' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

#has 'base_profiles' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );
#
#has 'profile_definitions' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
#sub _build_profile_definitions {
#	my $self = shift;
#	my $defs = $self->DEFAULT_PROFILES();
#	
#	# TODO collapse sub-profile defs
#	return $defs;
#}


# properties that get merged under actual properties - collapsed from profiles:
has 'properties_underlay' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
sub apply_profiles {
	my $self = shift;
	my @profiles = @_;
	@profiles = @{$_[0]} if (ref $_[0]);
	
	return unless (scalar @profiles > 0);
	
	$self->collapse_apply_profiles(
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
			'_other_properties',
			'extra_properties'
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

has 'extra_properties', is => 'ro', isa => 'HashRef', default => sub {{}};
sub all_properties_hash {
	my $self = shift;
	
	my %hash = %{ $self->_other_properties };
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next if ($self->exclude_attr_property_names->{$attr->name});
		next unless ($attr->has_value($self));
		$hash{$attr->name} = $attr->get_value($self);
	}
	
	my $props = { %{$self->properties_underlay},%hash };
	
	# added 'extra_properties' for extra properties that can be merged (past the first
	# level), specifically, for 'editor'. Notice above that the merge with 'properties_underlay'
	# is one-layer. This has gotten complicated and ugly and needs refactoring...
	return merge($self->extra_properties,$props); 
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