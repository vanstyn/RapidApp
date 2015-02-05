package RapidApp::Module::Combo;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::StorCmp';

use RapidApp::Include qw(sugar perlutil);

has 'name'           => ( is => 'ro', required => 1, isa => 'Str' );
has 'displayField'   => ( is => 'ro', required => 1, isa => 'Str' );
has 'valueField'     => ( is => 'ro', required => 1, isa => 'Str' );
has 'fieldLabel'     => ( is => 'ro', lazy => 1, default => sub { (shift)->name } );

# New custom 'allowSelectNone' feature. If true '(None)' will be the first choice
# in the dropdown to be able to unset (null/empty) the value by selection. Specific
# to 'appcombo2' (see Ext.ux.RapidApp.AppCombo2)
has 'allowSelectNone', is => 'ro', isa => 'Bool', default => 0;

sub BUILD {
  my $self = shift;
  
  $self->apply_extconfig(
    xtype            => 'appcombo2',
    typeAhead        => \0,
    mode             => 'remote',
    triggerAction    => 'all',
    selectOnFocus    => \1,
    editable         => \0,
    #allowBlank      => \0,
    width            => 337,
    name             => $self->name,
    fieldLabel       => $self->fieldLabel,
    displayField     => $self->displayField,
    valueField       => $self->valueField,
    allowSelectNone  => $self->allowSelectNone ? \1 : \0
  );
}



no Moose;
#__PACKAGE__->meta->make_immutable;
1;