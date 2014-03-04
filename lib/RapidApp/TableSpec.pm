package RapidApp::TableSpec;
use strict;
use Moose;
with 'MooseX::Traits';

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places

use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::Column;

our $VERSION = '0.1';

sub BUILD {
	my $self = shift;
	$self->add_onrequest_columns_mungers( $self->column_permissions_roles_munger );
}

has 'ResultClass' => ( is => 'ro', isa => 'Str' );

has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'title' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'iconCls' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );


has 'header_prefix' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

# Hash of CodeRefs to programatically change Column properties
has 'column_property_transforms' => ( is => 'ro', isa => 'Maybe[HashRef[CodeRef]]', default => undef );

# Hash of static changes to apply to named properties of all Columns
has 'column_properties' => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

# Hash of static properties initially applied to all Columns (if not already set)
has 'default_column_properties' => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

has 'profile_definitions' => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

has 'column_order' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );

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
		 num_columns		=> 'count',
		 delete_column		=> 'delete'
	}
);
around 'apply_columns' => sub { 
	my $orig = shift;
	my $self = shift;
	my %cols = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

	my $def = $self->default_column_properties;
	if ($def) {
		foreach my $Column (values %cols) {
			$Column->set_properties_If($def);
		}
	}
	
	push @{$self->column_order}, grep { ! $self->columns->{$_} } keys %cols;

	$self->$orig(%cols);
	$self->prune_invalid_columns;
};
around 'column_list' => sub {
	my $orig = shift;
	my $self = shift;
	# Force column_list to go through get_column so its logic gets called:
	return grep { $_ = $self->get_column($_) } $self->updated_column_order;
};
around 'get_column' => sub {
	my $orig = shift;
	my $self = shift;
	my $name = shift;
	my $Column = $self->$orig($name) || return undef;
	
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
		local $_ = $cur_props->{$prop};
		$change_props{$prop} = $trans->{$prop}->($cur_props);
		delete $change_props{$prop} unless (defined $change_props{$prop});
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
	
	$self->updated_column_order;
}

sub updated_column_order {
	my $self = shift;
	my %seen = ();
	# Prune out duplciates and columns not in $self->columns
	@{$self->column_order} = grep { !$seen{$_}++ and $self->columns->{$_} } @{$self->column_order};
	# Append any missing columns to the end (shouldn't be any)
	push @{$self->column_order}, grep { !$seen{$_} } keys %{$self->columns};
	return @{$self->column_order};
}


sub get_column_order_index {
	my $self = shift;
	my $column = shift;
	my $i = 0;
	for my $col ($self->updated_column_order) {
		return $i if ($col eq $column);
		$i++;
	}
	die "get_column_order_index(): column name '$column' not found";
}

sub set_column_order_before {
	my $self = shift;
	my $colname = shift;
	my @cols = @_;
	my $offset = $self->get_column_order_index($colname);
	return $self->set_column_order($offset,@cols);
}

sub set_column_order_after {
	my $self = shift;
	my $colname = shift;
	my @cols = @_;
	my $offset = $self->get_column_order_index($colname);
	return $self->set_column_order(++$offset,@cols);
}

sub set_column_orderIf {
	my $self = shift;
	my $offset = shift;
	my @cols = @_;
	@cols = @{$_[0]} if (scalar @_ == 1 and ref($_[0]) eq 'ARRAY');
	return $self->set_column_order($offset, grep { exists $self->columns->{$_} } @cols);
}

sub set_column_order {
	my $self = shift;
	my $offset = shift;
	die "First argument to set_column_order must be an index/offset" unless ($offset =~ /^\d+$/);
	my @cols = @_;
	@cols = @{$_[0]} if (scalar @_ == 1 and ref($_[0]) eq 'ARRAY');
	
	my %seen = ();
	!$seen{$_}++ or die "set_column_order(): column name specified more than once ($_)" for (@cols);
	$self->has_column($_) or die "set_column_order(): cannot set the order of non-existant columns ($_)" for (@cols);
	
	my %cols_map = map { $_ => 1 } @cols;
	
	#prune out the new columns from the current order:
	@{$self->column_order} = grep { !$cols_map{$_} } @{$self->column_order};
	
	if ($offset < scalar @{$self->column_order}) {
		# Add them back in at the new offset/index:
		splice(@{$self->column_order},$offset,0,@cols);
	}
	else {
		# offset is at or past the end of the array, ignore it and just append:
		push @{$self->column_order}, @cols;
	}
	
	# Just to be safe:
	$self->updated_column_order;
}

sub column_names { (shift)->column_names_ordered }
sub column_names_ordered {
	my $self = shift;
	return map { $_->name } $self->column_list;
}


sub columns_properties_limited {
	my $self = shift;
	my @props = @_;
	$self->updated_column_order;
	return { map { $_->name => $_->properties_limited(@props) } $self->column_list };
}


sub add_columns {
	my $self = shift;
	my @cols = (@_);
	
	my @added = ();
	
	foreach my $col (@cols) {
		my $Column;
		$Column = $col if (ref($col) eq 'RapidApp::TableSpec::Column');
		unless ($Column) {
			$col->{profile_definitions} = $self->profile_definitions if ($self->profile_definitions);
			$Column = RapidApp::TableSpec::Column->new($col);
			$Column->set_properties($col);
		}
		
		#die "A column named " . $Column->name . ' already exists.' if (defined $self->has_column($Column->name));
		
		$self->apply_columns( $Column->name => $Column );
		push @added, $Column;
	}
	
	$self->update_column_permissions_roles_code;
	return @added;
}


sub applyIf_column_properties {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	my $hash = \%new;

	my $pruned = { map { $_ => $hash->{$_} } grep { $self->get_column($_) } keys %$hash };
	
	return $self->apply_column_properties($pruned);
}

sub apply_column_properties { 
	my $self = shift;
	
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	my $hash = \%new;
	
	foreach my $col (keys %$hash) {
		my $Column = $self->get_column($col) or die "apply_column_properties failed - no such column '$col'";
		$Column->set_properties($hash->{$col});
	}
	
	$self->update_column_permissions_roles_code;
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
	
	# Need to use Clone::clone to ensure a deep copy. Discovered that with
	# clone_object alone, deeper data scructures, such as 'columns' attribute,
	# were only copied by reference, and not be deep data
	my $Copy = $self->meta->clone_object(Clone::clone($self),%attr);
	
	foreach my $key (keys %other) {
		$Copy->$key($other{$key}) if ($Copy->can($key));
	}
	
	# If column property transforms (name) was supplied, use it to transform
	# limit/exclude columns:
	if($opts{column_property_transforms} and $opts{column_property_transforms}{name}) {
		my $sub = $opts{column_property_transforms}{name};
		
		if($Copy->limit_columns) {
			my @limit = map { $sub->() } @{ $Copy->limit_columns };
			$Copy->limit_columns(\@limit) if (scalar @limit > 0);
		}
		
		if ($Copy->exclude_columns) {
			my @exclude = map { $sub->() } @{ $Copy->exclude_columns };
			$Copy->exclude_columns(\@exclude) if (scalar @exclude > 0);
		}
	}
	
	return $Copy;
}

sub add_columns_from_TableSpec {
	my $self = shift;
	my $TableSpec = shift;
	
	my @added = ();
	push @added, $self->add_columns($_) for ($TableSpec->column_list);
	
	# Apply foreign TableSpec's limit/exclude columns:
	my %seen = ();
	my @limit = ();
	push @limit, @{ $self->limit_columns } if ($self->limit_columns);
	push @limit, @{ $TableSpec->limit_columns } if ($TableSpec->limit_columns);
	@limit = grep { not $seen{$_}++ } @limit;
	$self->limit_columns(\@limit) if (scalar @limit > 0);
	
	%seen = ();
	my @exclude = ();
	push @exclude, @{ $self->exclude_columns } if ($self->exclude_columns);
	push @exclude, @{ $TableSpec->exclude_columns } if ($TableSpec->exclude_columns);
	@exclude = grep { not $seen{$_}++ } @exclude;
	$self->exclude_columns(\@exclude) if (scalar @exclude > 0);
	
	$self->updated_column_order;
	return @added;
}


# Designed to work with DataStore2: if defined, gets added as an
# onrequest_columns_munger to DataStore2-based modules that are
# configured to use this TableSpec:
has 'onrequest_columns_mungers' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_onrequest_columns_mungers		=> 'uniq',
		add_onrequest_columns_mungers		=> 'push',
		insert_onrequest_columns_mungers	=> 'unshift',
		has_no_onrequest_columns_mungers => 'is_empty',
	}
);


has 'column_permissions_roles_munger' => (
	is => 'ro',
	isa => 'RapidApp::Handler',
	default => sub { RapidApp::Handler->new( code => sub {} ) }
);


has 'roles_permissions_columns_map' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

sub update_column_permissions_roles_code {
	my $self = shift;
	
	# NOT IN USE
	return;
	
	my $roles = {};
	
	foreach my $Column ($self->column_list) {
		$Column->permission_roles or next;
		
		foreach my $perm ( keys %{ $Column->permission_roles } ) {
			foreach my $role ( @{ $Column->permission_roles->{$perm} } ) {
				die "Role names cannot contain spaces ('$role')" if (not ref($role) and $role =~ /\s+/);
				my $rolespec = $role;
				$rolespec = join(' ',@$role) if (ref($role) eq 'ARRAY');
				$roles->{$rolespec} = {} unless ($roles->{$rolespec});
				$roles->{$rolespec}{$perm} = [] unless ($roles->{$rolespec}{$perm});
				push @{ $roles->{$rolespec}{$perm} }, $Column->name;
			}
		}
	}
	
	$self->roles_permissions_columns_map($roles);
	
	return $self->column_permissions_roles_munger->code(sub {}) unless (scalar(keys %$roles) > 0);
	return $self->column_permissions_roles_munger->code(sub {
		my $columns = shift;
		return $self->apply_permission_roles_to_datastore_columns($columns);
	});
}


# This code not in use - 
sub apply_permission_roles_to_datastore_columns {
	my $self = shift;
	my $columns = shift;
	
	my $c = RapidApp->active_request_context;
	#delete $columns->{creator}->{editor} unless ($c->check_user_roles('admin'));
	
	my $map = $self->roles_permissions_columns_map;
	
	foreach my $role (keys %$map) {
		if ($c->check_user_roles(split(/\s+/,$role))) {
			# Any code that would need to be called for the positive condition would go here
		
		}
		else {
		
			#CREATE:
			if ($map->{$role}->{create}) {
			
			
			}
			#READ:
			elsif ($map->{$role}->{read}) {
			
			
			}
			#UPDATE:
			elsif ($map->{$role}->{update}) {
				my $list = $map->{$role}->{update};
				$list = [ $list ] unless (ref($list));
				foreach my $colname (@$list) {
					delete $columns->{$colname}->{editor};
				}
			}
			#DESTROY
			elsif ($map->{$role}->{destroy}) {
			
			
			}
		
		
		}
	
	
	}
	
	# TODO
	
	#scream($self->roles_permissions_columns_map);
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;