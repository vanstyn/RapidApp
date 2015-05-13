package RapidApp::Module::DbicRowDV;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::AppDV';
with 'RapidApp::Module::StorCmp::Role::DbicLnk::RowPg';

use RapidApp::Util qw(:all);
use Path::Class qw(file dir);

has 'template', is => 'ro', isa => 'Str', required => 1;
has 'selector_class', is => 'ro', isa => 'Str', default => 'ra-rowdv-select';

has '+allow_restful_queries', default => 1;

sub BUILD {
  my $self = shift;
  $self->apply_extconfig( itemSelector => join('.','div',$self->selector_class) );
  $self->_template_file; # init
}

has '_template_file', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $File = file( $self->tt_include_path, $self->template );
  -e $File ? $File : die "RowDV template not found ($File)";
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

=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<RapidApp::Manual::Modules>

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

