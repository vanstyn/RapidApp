package Catalyst::Helper::Model::DBIC::Schema::ForRapidDbic;

use strict;
use warnings;

use namespace::autoclean;
use Moose;
extends 'Catalyst::Helper::Model::DBIC::Schema';

=head1 NAME

Catalyst::Helper::Model::DBIC::Schema::ForRapidDbic - Helper for DBIC Schema Models

=head1 SYNOPSIS

  rapidapp.pl --helpers RapidDbic My::App -- --from-sqlite /path/to/existing/sqlt.db

=head1 DESCRIPTION

This helper class extends L<Catalyst::Helper::Model::DBIC::Schema>, adding support
for munging SQLite dsns to use runtime paths relative to the Catalyst app root.
It is otherwise exactly the same as the parent class.

This class is used internally by the RapidDbic helper trait for L<RapidApp::Helper>
(L<rapidapp.pl>) and is not meant to be used directly.

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use Try::Tiny;
use Path::Class qw/file dir/;
use Module::Runtime;

use RapidApp::Util qw(:all);

# This is ugly/temporary -- mechanism to pull in additional configs from the
# RapidDbic helper trait. Currently this is only exposed in rdbic.pl (--crud-profile)
sub _ra_rapiddbic_opts {
  my $self = shift;
  $self->{_ra_rapiddbic_opts} ||= (
    $RapidApp::Helper::Traits::RapidDbic::_ra_rapiddbic_opts || {}
  )
}

sub crud_profile {
  my $self = shift;
  my $prof = ($self->{_crud_profile} ||= (
    $self->_ra_rapiddbic_opts->{crud_profile} || 'read-only'
  ));
  
  my @valid = qw(read-only editable edit-instant edit-gridadd ed-inst-gridadd);
  my %valid = map {$_=>1} @valid;
  
  die join('',
    "Unknown crud_profile '$prof' -- must be one of (",
    join(', ',@valid),")"
  ) unless ($valid{$prof});
  
  $prof
}

sub _get_grid_params_section {
    my $self = shift;
    
    # Default/original 'read-only'
    return q~
       grid_params => {
          # The special '*defaults' key applies to all sources at once
          '*defaults' => {
             include_colspec      => ['*'], #<-- default already ['*']
             ## uncomment these lines to turn on editing in all grids
             #updatable_colspec   => ['*'],
             #creatable_colspec   => ['*'],
             #destroyable_relspec => ['*'],
          }
       },
    ~ if ($self->crud_profile eq 'read-only');
    
    my $inner = '';
    if ($self->crud_profile eq 'editable') {
      $inner = q~
             persist_immediately => {
               create  => 1,
               update  => 0,
               destroy => 0
             },~;
    }
    elsif ($self->crud_profile eq 'edit-gridadd') {
      $inner = q~
             persist_immediately => {
               create  => 0,
               update  => 0,
               destroy => 0
             },~;
    }
    elsif ($self->crud_profile eq 'edit-instant') {
      $inner = q~
             persist_immediately => {
               create  => 1,
               update  => 1,
               destroy => 1
             },~;
    }
    elsif ($self->crud_profile eq 'ed-inst-gridadd') {
      $inner = q~
             persist_immediately => {
               create  => 0,
               update  => 1,
               destroy => 1
             },~;
    }
    else {
      die "unexpected error";
    }

    q~
       grid_params => {
          # The special '*defaults' key applies to all sources at once
          '*defaults' => {
             include_colspec     => ['*'], #<-- default already ['*']
             updatable_colspec   => ['*'],
             creatable_colspec   => ['*'],
             destroyable_relspec => ['*'],~ .
             $inner . q~
             extra_extconfig => {
               store_button_cnf => {
                 save => { showtext => 1 },
                 undo => { showtext => 1 }
               }
             }
          }
       },
    ~
}


sub _gen_model {
    my $self = shift;
    my $helper = $self->helper;

    $helper->{grid_params_section} = $self->_get_grid_params_section;

    my @sources = $self->_get_source_list;
    $helper->{source_names} = \@sources;
    
    try {
      my $nfo = $self->{connect_info};
      
      if($nfo && $nfo->{dsn} && $nfo->{dsn} =~ /\:sqlite\:/i) {
        my ($dbi,$drv,$db) = split(/\:/,$nfo->{dsn},3);
        
        my $db_file = file($db)->resolve->absolute;
        my $base_dir = dir($helper->{base})->resolve->absolute;
        
        if($base_dir->contains($db_file)) {
          my $rel = $db_file->relative($base_dir);
          
          $helper->{pre_config_perl_code} = join('',
            q{use Path::Class qw(file);},"\n",
            q{use Catalyst::Utils;},"\n",
            q{my $db_path = file(Catalyst::Utils::home('},
              $helper->{app},q{'),'},$rel->stringify,q{');},"\n",
            q|sub _sqlt_db_path { "$db_path" }; # exposed for use by the regen devel script|
          );
          
          $helper->{post_config_perl_code} = join("\n",
            q!## ------!,
            q!## Uncomment these lines to have the schema auto-deployed during!,
            q!## application startup when the sqlite db file is missing:!,
            q!#before 'setup' => sub {!,
            q!#  my $self = shift;!,
            q!#  return if (-f $db_path);!,
            q!#  $self->schema_class->connect($self->connect_info->{dsn})->deploy;!,
            q!#};!,
            q!## ------!,''
          );
          
          $helper->{connect_info}{dsn} = join('','"',$dbi,':',$drv,':','$db_path','"');
        }
      
      }
    };
    
    $helper->render_file('compclass', $helper->{file} );
}

# Must be called *after* _gen_static_schema() is called
sub _get_source_list {
  my $self = shift;
  
  my $class = $self->{schema_class} or die "No schema class!";
  Module::Runtime::require_module($class) or die "Error loading schema class!";
  
  # Connect to a one-off SQLite memory database just so we can get the sources
  my $schema = $class->connect('dbi:SQLite::memory:');
  
  return sort ($schema->sources);
}

# This is the cleanest way to munge the arguments passed to make_schema_at (in parent)
# to inject our custom loader_class option(s). 
#  -- See Catalyst::Helper::Model::DBIC::Schema::_gen_static_schema to understand why
around '_gen_static_schema' => sub {
  my ($orig,$self,@args) = @_;
  
  my @keys = qw/metakeys limit_schemas_re exclude_schemas_re limit_tables_re exclude_tables_re/;
  my $extra = { map {
    $self->_ra_rapiddbic_opts->{$_} 
      ? ( $_ => $self->_ra_rapiddbic_opts->{$_} )
      : ()
  } @keys };

  my $connect_info = $self->connect_info;
  my $loader_args  = $self->loader_args;
  
  no warnings 'redefine';

  local *connect_info = sub {
    $connect_info, { loader_class => 'RapidApp::Util::MetaKeys::Loader' }
  };

  local *loader_args = sub {
    keys %$extra > 0
      ? { %$loader_args, %$extra }
      : $loader_args
  };

  $self->$orig(@args)
};



1;


__DATA__

=begin pod_to_ignore

__schemaclass__
package [% schema_class %];

use strict;
use base qw/DBIx::Class::Schema::Loader/;

__PACKAGE__->loader_options(
    [%- FOREACH key = loader_args.keys %]
    [% key %] => [% loader_args.${key} %],
    [%- END -%]

);

=head1 NAME

[% schema_class %] - L<DBIx::Class::Schema::Loader> class

=head1 SYNOPSIS

See L<[% app %]>

=head1 DESCRIPTION

Dynamic L<DBIx::Class::Schema::Loader> schema for use in L<[% class %]>

=head1 GENERATED BY

[% generator %] - [% generator_version %]

=head1 AUTHOR

[% author.replace(',+$', '') %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__compclass__
package [% class %];
use Moo;
extends 'Catalyst::Model::DBIC::Schema';

use strict;
use warnings;

[% pre_config_perl_code %]

__PACKAGE__->config(
    schema_class => '[% schema_class %]',
    [% IF traits %]traits => [% traits %],[% END %]
    [% IF setup_connect_info %]connect_info => {
       [%- FOREACH key = connect_info.keys %]
       [% key %] => [% connect_info.${key} %],
       [%- END -%]

    },[% END %]

    # Configs for the RapidApp::RapidDbic Catalyst Plugin:
    RapidDbic => {

       # use only the relationship column of a foreign-key and hide the 
       # redundant literal column when the names are different:
       hide_fk_columns => 1,

       # grid_params are used to configure the grid module which is 
       # automatically setup for each source in the navtree
[% grid_params_section %]
       [% IF source_names %]
       # TableSpecs define extra RapidApp-specific metadata for each source
       # and is used/available to all modules which interact with them
       TableSpecs => {
          [%- FOREACH name IN source_names %]
          '[% name %]' => {
          },
          [%- END -%]

       },[% END %]
    }

);

[% post_config_perl_code %]

=head1 NAME

[% class %] - Catalyst/RapidApp DBIC Schema Model

=head1 SYNOPSIS

See L<[% app %]>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<[% schema_class %]>

=head1 GENERATED BY

[% generator %] - [% generator_version %]

=head1 AUTHOR

[% author.replace(',+$', '') %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__END__
# vim:sts=4 sw=4: