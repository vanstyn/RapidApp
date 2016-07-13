package RapidApp::DBIC::Component::VirtualColumnsExt;
use base 'DBIx::Class';

use strict;
use warnings;

use RapidApp::Util qw(:all);

# Load the vanilla/original DBIx::Class::VirtualColumns component:
__PACKAGE__->load_components('+RapidApp::DBIC::Component::VirtualColumns');

__PACKAGE__->mk_classdata( '_virtual_columns_order' );

sub init_vcols_class_data {
	my $self = shift;
	
	$self->_virtual_columns( {} )
        unless defined $self->_virtual_columns();
     
    $self->_virtual_columns_order( [] )
        unless defined $self->_virtual_columns_order();
}

# extend add_virtual_columns to also track column order
sub add_virtual_columns {
	my $self = shift;
    my @columns = @_;
	
	$self->init_vcols_class_data;
	
	foreach my $column (@columns) {
		next if (
			ref $column or
			$self->has_column($column) or 
			exists $self->_virtual_columns->{$column} #<-- redundant since we override 'has_column'
		);
		
		push @{$self->_virtual_columns_order}, $column;
	}
	
	return $self->next::method(@_);
}

sub virtual_columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return @{$self->_virtual_columns_order};
}

# Take-over has_column to include virtual columns
sub has_column {
    my $self = shift;
    my $column = shift;
	$self->init_vcols_class_data;
    return ($self->_virtual_columns->{$column} ||
        $self->next::method($column)) ? 1:0;
}

# Take-over columns to include virtual columns:
sub columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return ($self->next::method(@_),$self->virtual_columns);
}


sub get_column {
    my ($self, $column) = @_;

    return $self->next::method($column) unless (
		defined $self->_virtual_columns &&
        exists $self->_virtual_columns->{$column}
	);
	
	$self->init_virtual_column_value($column);
	
	return $self->next::method($column);
}

# TODO/FIXME: 
#  here we are loading/appending all defined virtual columns during the call
#  to get_columns(), which is slow/expensive. What we should be doing is 
#  hooking into 'inflate_result' to *preload* the values into the row object 
#  ('_column_data' attr) in the same location as ordinary columns which should
#  then allow the native get_columns() to work as-is...
sub get_columns {
    my $self = shift;
    
    return $self->next::method(@_) unless $self->in_storage;
    my %data = $self->next::method(@_);
    
    if (defined $self->_virtual_columns) {
        foreach my $column (keys %{$self->_virtual_columns}) {
            my $value = undef;
			$data{$column} = $value
				if($self->init_virtual_column_value($column,\$value));
        }
    }
    return %data;
}


# ---
# Get the safe "select" string for any column. For virtual columns,
# this will be a special SQLT-style reference, for normal columns
# just the column name. TODO/FIXME: this code is not complete as
# it is currently hard-coded for 'me' -- which means it will break
# if 'me' isn't the alias, or if joined. This is just partial/demo
# code for now... Need to actually learn the right DBIC way to do
# this. This is a BUG. This code has been added for 2 reasons:
#   1. As a reminder to fix this
#   2. As a stop-gap for RapidApp::Module::DbicCombo (sort), which is also
#      in a tmp/in-flux state. Otherwise, this code would just be
#      there, but it is here as a reminder. No other code should be
#      calling this **private** method which WILL change when this
#      is actually addressed for real.
sub _virtual_column_select {
	my ($self, $column) = @_;
  if ($self->has_virtual_column($column)) {
    my $rel = 'me';
    return $self->_get_virtual_column_select_statement($column, $rel);
  }
  elsif($self->has_column($column)) {
    return "me.$column";
  }
  die "_virtual_column_select(): Unknown column '$column'";
}
# ---

sub _get_virtual_column_select_statement {
  my ($self, $column, $rel) = @_;
  my $info = $self->column_info($column);
  my $sql = $info->{sql}
    or die "Missing virtual column 'sql' attr in info";
  # also see RapidApp::TableSpec::Role::DBIC
  $sql = $info->{sql}->($self, $column) if ref $sql eq 'CODE';
  $sql =~ s/self\./${rel}\./g;
  $sql =~ s/\`self\`\./\`${rel}\`\./g; #<-- also support backtic quoted form (quote_sep)
  return \"($sql)";
}

sub init_virtual_column_value {
	my ($self, $column,$valref) = @_;
	return if (exists $self->{_virtual_values}{$column});
	my $rel = 'me';
  my $sql = $self->_get_virtual_column_select_statement($column, $rel);
	my $Source = $self->result_source;
	my $cond = { map { $rel . '.' . $_ => $self->get_column($_) } $Source->primary_columns };
	my $attr = {
		select => [{ '' => $sql, -as => $column }],
		as => [$column],
		result_class => 'DBIx::Class::ResultClass::HashRefInflator'
	};
  my $info = $self->column_info($column);
	$attr->{join} = $info->{join} if (exists $info->{join});
	
	my $row = $Source->resultset->search_rs($cond,$attr)->first or return undef;
	
	# optionally update a supplied reference, passed by argument:
	$$valref = $row->{$column} if (ref($valref) eq 'SCALAR');
	
  local $self->{_virtual_columns_no_prepare_set} = 1;
  return $self->store_column($column,$row->{$column});
}


# Prepares any set_functions, if applicable, for the supplied col/vals
# ('set_functions' are custom coderefs optionally defined in the attributes
# of a virtaul column. Similar concept to the 'sql' attribute but for update/insert
# instead of select. Also, 'set_function' is a Perl coderef which calls
# DBIC methods while 'sql' is raw SQL code passed off to the DB)
sub prepare_set {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  # Check special flag to abort preparing set functions
  return if ($self->{_virtual_columns_no_prepare_set});
  
	return unless (defined $self->_virtual_columns);
	$self->{_virtual_columns_pending_set_function} ||= {};
	foreach my $column (keys %opt) {
		next unless (exists $self->_virtual_columns->{$column});
		my $coderef = try{$self->column_info($column)->{set_function}} or next;
		$self->{_virtual_columns_pending_set_function}{$column} = {
			coderef	=> $coderef,
			value	=> $opt{$column}
		};
	}
}

sub execute_pending_set_functions {
	my $self = shift;
	my $pend = $self->{_virtual_columns_pending_set_function} or return;
	foreach my $column (keys %$pend) {
		my $h = delete $pend->{$column}; #<-- fetch and clear
		$h->{coderef}->($self,$h->{value});
	}
}

sub store_column {
   my ($self, $column, $value) = @_;
   $self->prepare_set($column,$value);
   return $self->next::method($column, $value);
}

sub set_column {
  my ($self, $column, $value) = @_;
  $self->prepare_set($column,$value);
  return $self->next::method($column, $value);
}

sub update {
  my $self = shift;
  $self->prepare_set(@_);
  
  # Disable preparing any more set functions. We need to do this
  # because update() will call store_column() on every column (which
  # in turn calls prepare_set). We only want to prepare_set for 
  # virtual columns which are actually being changed, and that has
  # already happened by this point.
  local $self->{_virtual_columns_no_prepare_set} = 1;
  
  # Do regular update
  $self->next::method(@_);
    
  $self->execute_pending_set_functions;
  
  # NEW: if any of the set functions have left the row dirty, update again:
  # (principal of least astonishment)
  my %dirty = $self->get_dirty_columns;
  $self->next::method if(scalar(keys %dirty) > 0);
  
  return $self;
}

sub insert {
  my $self = shift;
  $self->prepare_set(@_);
 
  # Do regular insert
  $self->next::method(@_);
    
  $self->execute_pending_set_functions;
  return $self;
}


1;
