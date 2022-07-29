package RapidApp::Module::DbicRowDV;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::DbicDV';
with 'RapidApp::Module::StorCmp::Role::DbicLnk::RowPg';

use RapidApp::Util qw(:all);
use Path::Class qw(file dir);

has 'template', is => 'ro', isa => 'Str', required => 1;
has 'selector_class', is => 'ro', isa => 'Str', default => 'ra-rowdv-select';

has '+allow_restful_queries', default => 1;

sub BUILD {
  my $self = shift;
  
  $self->apply_extconfig( 
    itemSelector => join('.','div',$self->selector_class),
  );
  
  $self->_template_file; # init
  
  $self->set_default_tab_icon; # same as DbicPropPage
}

sub set_default_tab_icon {
  my $self = shift;
  my $class = $self->ResultClass or return;
  my $iconCls = $class->TableSpec_get_conf('iconCls') or return;
  $self->apply_extconfig( tabIconCls => $iconCls );
}

has '_template_file', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  for my $path (split(/\:/,$self->tt_include_path)) {
    my $File = file( $path, $self->template );
    return $File if (-e $File);
  }
  die join('',
    "DbicRowDV: template '", $self->template,"' not found (looked in: '",
    $self->tt_include_path,"')"
  );
}, isa => 'Path::Class::File';

has '+tt_file', required => 0;

sub _tt_file {
  my $self = shift;
  \join("\n",
    '<div><tpl for=".">',
      '<div class="' . $self->selector_class . '">',
        $self->_template_file->slurp,
      '</div>',
    '</tpl></div>'
  )
}

around 'extra_tt_vars' => sub {
  my ($orig, $self, @args) = @_;
  return {
    %{ $self->$orig(@args) },
    Row => $self->req_Row
  }
};


1;

__END__

=head1 NAME

RapidApp::Module::DbicRowDV - DataView module for a single DBIC Row

=head1 SYNOPSIS

In the L<RapidDbic|Catalyst::Plugin::RapidApp::RapidDbic> config of a DBIC module:

  # ...
  RapidDbic => {
    grid_params => {
      '*defaults' => { # Defaults for all Sources
        updatable_colspec => ['*'],
        creatable_colspec => ['*'],
        destroyable_relspec => ['*']
      }, # ('*defaults')
      SomeSource => {
        page_class  => 'RapidApp::Module::DbicRowDV',
        page_params => {
          template => 'somesource.html',
        }
      }
      # ...
  
    },
    # ...
  }
  # ...
 

In somesource.html:

  <div>
  <b>Name:</b> [% r.autofield.column1 %]
  </div>

  <div>
  [% r.autofield.column2 %]
  </div>
  
  {column3}
  
  # ...


=head1 DESCRIPTION

This module provides a TT-driven html template for the "page" view of a DBIC source. It extends
the L<RapidApp::Module::AppDV> class, targeted for this specific (i.e. single row) case. If you
want a custom designed page for a row, with in-line editable columns, this is the module you want.

Note that the output of the Template Toolkit template is used as source for an
L<ExtJS XTemplate|https://docs.sencha.com/extjs/3.4.0/#!/api/Ext.XTemplate-method-constructor>
which gets rendered client-side any time the ExtJS row object changes.  The C<< r.autofield >>
snippets allow you to inject RapidApp's default wrapper for your fields instead of needing
to invent them from scratch.  If you want special rendering for your fields, it is better to
implement it in JavaScript and configure that in the ColSpec, rather than performing custom
rendering in the TT file.  This module is primarily intended for custom layouts.

=head1 ATTRIBUTES

This module supports all the same attributes of DbicLnk module (i.e. include_colspec, ResultSource, 
etc) plus the following extra attrs.

=head2 tt_include_path 

Defaults to C<root/templates> within your application home dir.

=head2 template

Path to the template to use under the C<tt_include_path>

The template can contain raw html. The read-only value of a given column can used inline by
supplying the column name within curly-braces:

  {some_column}

For an editable version of a column (dependent on editable perms, updatable_colspec, etc) use:

  [% r.autofield.some_column %]

This will also render the value of the column, but will also be an editable/clickable control
to set the value in-place.

=head1 Inherited from L<RowPg|RapidApp::Module::StorCmp::Role::DbicLnk::RowPg>

=over 12

=item supplied_id

The primary key of the row to be displayed

=item ResultSet

The ResultSet for this module returns a single row

=item req_Row

The DBIC row object to be dipslayed on this DataView

=back

=head1 Inherited from L<DbicDV|RapidApp::Module::DbicDV>

=over 12

=item content

The main output of the Module, which is a configuration object for the
L<ExtJS DataView|https://docs.sencha.com/extjs/3.4.0/#!/api/Ext.DataView>
component.

=back

=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<RapidApp::Manual::Modules>

=item *

L<RapidApp::Module::AppDV>

=item *

L<ExtJS DataView Documentation|https://docs.sencha.com/extjs/3.4.0/#!/api/Ext.DataView>

=item *

L<ExtJS XTemplate Documentation|https://docs.sencha.com/extjs/3.4.0/#!/api/Ext.XTemplate-method-constructor>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

