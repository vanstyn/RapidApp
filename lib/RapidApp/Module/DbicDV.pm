package RapidApp::Module::DbicDV;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::AppDV';
with 'RapidApp::Module::StorCmp::Role::DbicLnk';

# Default this newly available option to true for DV Modules. This turns off
# the very old behavior of appending relationship paths to column headers,
# which makes more sense for grids, since grids support custom headers. AppDV
# has never used header before just now, since we're exposing all column attrs
# via the new TTController method [% r.column_info.<COLUMN_NAME>.<ATTR> %]
has '+no_header_transform', default => 1;

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
    # -- allow the template content to set:
    #  position:absolute;
    #  top: 0; right: 0; bottom: 0; left: 0;
    # ^^ and have it work as expected... OR postion 'relative' and scroll as expected:
    style => 'position:relative;',
    # --
    
    # Set a border when rendered within an AutoPanel (TODO: consider moving up to AppDV):
    cls => 'ra-ap-borders',
    
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

