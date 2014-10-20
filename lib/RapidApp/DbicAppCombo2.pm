package RapidApp::DbicAppCombo2;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCombo2';

use RapidApp::Include qw(sugar perlutil);
use List::Util;

### TODO: Bring this into the fold with DbicLink. For now, it is simple enough this isn't really needed

has 'ResultSet' => ( is => 'rw', isa => 'Object', required => 1 );
has 'RS_condition' => ( is => 'ro', isa => 'Ref', default => sub {{}} );
has 'RS_attr' => ( is => 'ro', isa => 'Ref', default => sub {{}} );
has 'record_pk' => ( is => 'ro', isa => 'Str', required => 1 );

# We don't need datastore-plus because we're not a CRUD interface, etc...
# the standard Ext.data.JsonStore API is all we need:
has '+no_datastore_plus_plugin', default => 1;

=head2 user_editable

Boolean. If true, the combo field will allow the user to enter arbitrary text in
addition to selecting an existing item from the list. Defaults to false.
=cut
has 'user_editable', is => 'ro', isa => 'Bool', default => sub{0};

=head2 type_ahead

Boolean. If true, the combo field will allow the user to type in arbitrary text to filter the list
of results. Defaults to false unless user_editable is true.
=cut
has 'type_ahead', is => 'ro', isa => 'Bool', lazy => 1, default => sub{ (shift)->user_editable };


has 'result_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $Source = $self->ResultSet->result_source;
  $Source->schema->class($Source->source_name);
}, isa => 'Str', init_arg => undef;

sub BUILD {
	my $self = shift;
  
 # record_pk and valueField are almost always the the same
  my @cols = uniq(
    $self->record_pk,
    $self->valueField,
    $self->displayField
  );
  
  # Update the ResultSet to select only the columns we need:
  $self->ResultSet( $self->ResultSet
    ->search_rs(undef,{
      select => [map {$self->_resolve_select($_)} @cols],
      as     => \@cols
    })
  );
	
	# Remove the width hard coded in AppCombo2 (still being left in AppCombo2 for legacy
	# but will be removed in the future)
	$self->delete_extconfig_param('width');
	
	$self->apply_extconfig(
		itemId	=> $self->name . '_combo',
		forceSelection => \1,
		editable => \0,
	);
  
  # type_ahead overrides:
  $self->apply_extconfig(
    editable      => \1,
    typeAhead     => \1,
    minChars      => 0,
    queryParam    => 'type_ahead_query',
    selectOnFocus => \0,
    emptyText     => 'Type to Find',
    emptyClass    => 'field-empty-text',
    listEmptyText => join("\n",
                          '<div style="padding:5px;" class="field-empty-text">',
                            '(No matches found)',
                          '</div>'
                     ),
  ) if ($self->type_ahead);
  
  # user_editable overrides:
  $self->apply_extconfig(
    editable       => \1,
    forceSelection => \0,
    typeAhead      => \0, #<-- do not auto-complete
  ) if ($self->user_editable);
  
}


sub read_records {
  my $self = shift;
  my $p = $self->c->req->params;
  
  # Discard type_ahead queries if type_ahead is not enabled:
  delete $p->{type_ahead_query} if ($p->{type_ahead_query} && ! $self->type_ahead);

  # Start by applying the optional RS_condition/RS_attr
  my $Rs = $self->ResultSet->search_rs(
    $self->RS_condition,
    $self->RS_attr
  );
  
  # Set the default order_by so the list is sorted alphabetically:
  $Rs = $Rs->search_rs(undef,{
    order_by => { 
      '-asc' => $self->_resolve_select($self->displayField) 
    }
  }) unless (exists $Rs->{attrs}{order_by});
  
  # And set a fail-safe max number of rows:
  $Rs = $Rs->search_rs(undef,{ rows => 500 }) unless (exists $Rs->{attrs}{rows});
  
  # Filter for type_ahead
  $Rs = $Rs->search_rs({
    $self->_resolve_select($self->displayField)
      => { 'like' => $p->{type_ahead_query} . '%' }
  }) if ($p->{type_ahead_query});
  
  # Finally, chain through the custom 'AppComboRs' ResultSet method if defined:
  $Rs = $Rs->AppComboRs if ($Rs->can('AppComboRs'));

  my $rows = [ $Rs
    ->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' })
    ->all
  ];

  # Handle the 'valueqry' separately because it supercedes the rest of the
  # query, and applies to only 1 row. However, we don't expect both a valueqry
  # and a type_ahead_query together. The valueqry is sent to obtain the display
  # value for an existing value in the combo, and we support the case of
  # properly displaying an existing value even if it does not show up (i.e. 
  # cannot be selected) in the dropdown list.
  $self->_apply_valueqry($rows,$p->{valueqry}) if (
    $p->{valueqry} &&
    ! $p->{type_ahead_query}
  );

  return {
    rows    => $rows,
    results => scalar(@$rows)
  };
}


sub _apply_valueqry {
  my ($self, $rows, $valueqry) = @_;
  
  # If the valueqry row is already present, we don't need to do anything:
  return if ( List::Util::first {
    $_->{$self->record_pk} eq $valueqry
  } @$rows );
  
  my $Row = $self->ResultSet
    ->search_rs({ $self->record_pk => { '=' => $valueqry }})
    ->first
  or return;
  
  unshift @$rows, { $Row->get_columns };
}

sub _resolve_select {
  my ($self, $col) = @_;
  
  $self->{_resolve_select_cache}{$col} ||= do {
    my $Source = $self->ResultSet->result_source;
    my $class = $Source->schema->class($Source->source_name);
    $class->can('has_virtual_column') && $class->has_virtual_column($col)
      ? $class->_virtual_column_select($col)
      : join('.','me',$col)
  };
}


1;


