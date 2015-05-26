package RapidApp::Module::DbicDV;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::AppDV';
with 'RapidApp::Module::StorCmp::Role::DbicLnk';

use RapidApp::Util qw(:all);

sub BUILD {
  my $self = shift;
  
  my $title  = $self->ResultClass->TableSpec_get_conf('title');
  my $titles = $self->ResultClass->TableSpec_get_conf('title_multi');
  
  $self->apply_extconfig(
    # this should be set to whatever wraps each row in the tt template, it can be anything
    itemSelector => 'div.ra-appdv-item-select',
    autoHeight => \0,
    autoScroll => \1,
    # -- Set a border for AutoPanel, and allow the template content to set:
    #  position:absolute;
    #  top: 0; right: 0; bottom: 0; left: 0;
    # ^^ and have it work as expected... OR postion 'relative' and scroll as expected:
    style => 'border: 1px solid #D0D0D0; position:relative;',
    # --
    
    # Sane defaults for the store buttons:
    store_button_cnf => {
      add => {
        text    => "Add $title",
        iconCls => 'ra-icon-add'
      },
      edit => {
        text    => "Edit $title",
        iconCls => 'ra-icon-application-form-edit'
      },
      delete => {
        text    => "Delete $titles",
        iconCls => 'ra-icon-delete'
      },
      reload => {
        text    => "Reload Data",
        iconCls => 'x-tbar-loading'
      },
      save => {
        text    => "Save",
        iconCls => 'ra-icon-save-ok'
      },
      undo => {
        text    => "Undo",
        iconCls => 'ra-icon-arrow-undo'
      },
    }
  );
  
}



1;

__END__

=head1 NAME

RapidApp::Module::DbicDV - DataView module for DBIC


=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<RapidApp::Manual::DbicRowDV>

=item *

L<RapidApp::Module::AppDV>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

