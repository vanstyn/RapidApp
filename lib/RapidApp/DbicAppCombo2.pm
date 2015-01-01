package RapidApp::DbicAppCombo2;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCombo2';

use RapidApp::Include qw(sugar perlutil);
use List::Util;

has 'ResultSet' => ( is => 'ro', isa => 'Object', required => 1 );
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

=head2 type_filter

Boolean. If true, the combo field will allow the user to type in arbitrary text to filter the list
of results. Defaults to false unless user_editable is true.
=cut
has 'type_filter', is => 'ro', isa => 'Bool', lazy => 1, default => sub{ (shift)->user_editable };

=head2 min_type_filter_chars

Setting passed to the 'minChars' ExtJS combo config. Defaults to '0' which causes filter/query
to fire with every user ketstroke. For large tables where matching on as little as a single character 
will be too slow, or to reduce the number/rate of queries fired, set this to a higher value.
=cut
has 'min_type_filter_chars', is => 'ro', isa => 'Int', default => 0;

=head2 auto_complete

Boolean. True to enable 'typeAhead' in the ExtJS combo, meaning that text from the filtered results
will be auto-completed in the box. This only makes sense when type_filter is on and will auto enable 
filter_match_start. This is an "unfeature" (very annoying) if used inappropriately. Defaults to false.
=cut
has 'auto_complete', is => 'ro', isa => 'Bool', default => sub{0};


=head2 filter_match_start

Boolean. True for the LIKE query generated for the type_filter to match only the start of the display
column. This defaults to true if auto_complete is enabled because it wouldn't make sense otherwise.
=cut
has 'filter_match_start', is => 'ro', isa => 'Bool', lazy => 1, default => sub{ (shift)->auto_complete };


has 'result_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $Source = $self->ResultSet->result_source;
  $Source->schema->class($Source->source_name);
}, isa => 'Str', init_arg => undef;

sub BUILD {
  my $self = shift;
  
  # Remove the width hard coded in AppCombo2 (still being left in AppCombo2 for legacy
  # but will be removed in the future)
  $self->delete_extconfig_param('width');
  
  # base config:
  $self->apply_extconfig(
    itemId         => $self->name . '_combo',
    forceSelection => \1,
    editable       => \0,
    typeAhead      => \0,
    selectOnFocus  => \0,
  );
  
  # type_filter overrides:
  $self->apply_extconfig(
    editable      => \1,
    queryParam    => 'type_filter_query',
    minChars      => $self->min_type_filter_chars,
    emptyText     => 'Type to Find',
    emptyClass    => 'field-empty-text',
    listEmptyText => join("\n",
                          '<div style="padding:5px;" class="field-empty-text">',
                            '(No matches found)',
                          '</div>'
                     ),
  ) if ($self->type_filter);
  
  # auto_complete overrides:
  $self->apply_extconfig(
    typeAhead     => \1 
  ) if ($self->auto_complete);
  
  # user_editable overrides:
  $self->apply_extconfig(
    editable         => \1,
    forceSelection   => \0,
    emptyText        => undef,
    listEmptyText    => '',
    triggerClass     => 'x-form-search-trigger',
    no_click_trigger => \1,
    is_user_editable => \1,
    autoSelect       => \0
  ) if ($self->user_editable); 
}


sub read_records {
  my $self = shift;
  my $p = $self->c->req->params;
  
  delete $p->{type_filter_query} if ( $p->{type_filter_query} && (
    # Discard type_filter queries if type_filter is not enabled:
    ! $self->type_filter ||
    # As well as empty/only whitespace
    $p->{type_filter_query} =~ /^\s*$/
  ));
  
  # record_pk and valueField are almost always the the same
  my @cols = uniq(
    $self->record_pk,
    $self->valueField,
    $self->displayField
  );
  
  # Start with a select on only the columns we need:
  my $Rs = $self->ResultSet->search_rs(undef,{
    select => [map {$self->_resolve_select($_)} @cols],
    as     => \@cols
  });

  # Then apply the optional RS_condition/RS_attr
  $Rs = $Rs->search_rs(
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
  
  # Filter for type_filter
  $Rs = $Rs->search_rs(
    $self->_like_type_filter_for($p->{type_filter_query})
  ) if ($p->{type_filter_query});
  
  # Finally, chain through the custom 'AppComboRs' ResultSet method if defined:
  $Rs = $Rs->AppComboRs if ($Rs->can('AppComboRs'));
  
  my $rows = [ $Rs
    ->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' })
    ->all
  ];

  # Sort results into groups according to the kind of match (#83)
  $rows = $self->_apply_type_filter_row_order(
    $rows,$p->{type_filter_query}
  ) if ($p->{type_filter_query});

  # Handle the 'valueqry' separately because it supercedes the rest of the
  # query, and applies to only 1 row. However, we don't expect both a valueqry
  # and a type_filter_query together. The valueqry is sent to obtain the display
  # value for an existing value in the combo, and we support the case of
  # properly displaying an existing value even if it does not show up (i.e. 
  # cannot be selected) in the dropdown list.
  $self->_apply_valueqry($rows,$p->{valueqry}) if (
    $p->{valueqry} &&
    ! $p->{type_filter_query}
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
    ->search_rs({ join('.','me',$self->record_pk) => { '=' => $valueqry }})
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

require RapidApp::Role::DbicLink2;
sub _binary_op_fuser { RapidApp::Role::DbicLink2::_binary_op_fuser(@_) }

sub _like_type_filter_for {
  my ($self,$str) = @_;
  
  my $like_arg = $self->filter_match_start 
    ? join('',    $str,'%')  # <-- start of the column
    : join('','%',$str,'%'); # <-- anywhere in the column
  
  my $sel = $self->_resolve_select($self->displayField);
  
  my $sm = $self->ResultSet->result_source->schema->storage->sql_maker;
  return &_binary_op_fuser($sm,$sel => { like => $like_arg });

  # Manual alternative to _binary_op_fuser above:
  #$sel = $$sel if (ref $sel);
  #return \[join(' ',$sel,'LIKE ?'),$like_arg];
}


# Orders the rows by the kind of match: exact, start, then everything else (#83)
sub _apply_type_filter_row_order {
  my ($self, $rows, $str) = @_;

  my @exact = ();
  my @start = ();
  my @other = ();

  $str = lc($str); # case-insensitive

  for my $row (@$rows) {
    exists $row->{$self->displayField} or die "Bad data -- row doesn't contain displayField key";

    my $dval = lc($row->{$self->displayField}); # case-insensitive

    if ($dval eq $str) {
      push @exact, $row;
    }
    elsif ($dval =~ /^$str/) {
      push @start, $row;
    }
    else {
      push @other, $row;
    }
  }

  @$rows = (@exact,@start,@other);

  $rows
}


1;


