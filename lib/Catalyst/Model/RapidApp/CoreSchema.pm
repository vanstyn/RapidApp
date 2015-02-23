package Catalyst::Model::RapidApp::CoreSchema;
use Moose;
extends 'Catalyst::Model::DBIC::Schema';

use strict;
use warnings;

use RapidApp::Util qw(:all);

use Types::Standard qw(:all);

use Catalyst::Utils;
use Module::Runtime;
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Path::Class qw(file dir);

use DBIx::Class::Schema::Loader;
use DBIx::Class::Schema::Diff;

BEGIN {
  require DBIx::Class::Optional::Dependencies;
  unless ( DBIx::Class::Optional::Dependencies->req_ok_for('deploy') ) {
    die(
      "Required DBIx::Class 'deploy' dependencies missing: "
     . ( values %{ DBIx::Class::Optional::Dependencies->req_errorlist_for('deploy') } )[0] 
    );
  }
}

# --------------------
# User can set their own sqlite file/path by doing this in main app class:
#
#  __PACKAGE__->config(
#   'Model::RapidApp::CoreSchema' => {
#     sqlite_file => '/path/to/coreschema.db'
#   }
# );
#
# OR, relative path is local to the app home dir:
#  __PACKAGE__->config(
#   'Model::RapidApp::CoreSchema' => {
#     sqlite_file => 'my_coreschema.db'
#   }
# );
#
# They can also set/override 'schema_class' and 'connect_info'
# in the same place
#
# --------------------

# New: this needs to be outside like this to avoid running afoul of
# nasty/complex load order problems with Model::DBIC
before 'COMPONENT' => sub {
  my $class = shift;
  my $app_class = ref $_[0] || $_[0];
  
  my $home = Catalyst::Utils::home($app_class) || Catalyst::Utils::class2tempdir($app_class,1);
  my $cust_cnf = try{$app_class->config->{'Model::RapidApp::CoreSchema'}} || {};
  
  $cust_cnf->{sqlite_file} ||= 'rapidapp_coreschema.db';
  my $db_file = file($cust_cnf->{sqlite_file});
  $db_file = file(dir($home),$db_file) if ($db_file->is_relative);
  
  $class->config(
    schema_class => 'RapidApp::CoreSchema',
    
    connect_info => {
        dsn => join('','dbi:SQLite:dbname=',$db_file),
        sqlite_unicode => q{1},
        on_connect_call => q{use_foreign_keys},
        quote_names => q{1},
    },
    
    # Allow user-defined config overrides:
    %$cust_cnf
  );
};

sub BUILD {
  my $self = shift;
  $self->_auto_deploy_schema( $self->schema );
}

has 'init_admin_password', is => 'ro', isa => Str, default => 'pass';

sub dsn {
  my $self = shift;
  return $self->config->{connect_info}{dsn};
}

# dsn for the "reference" coreschema database/file. This is used only for the
# purposes of schema comparison
has 'ref_dsn', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
  my $self = shift;
  my $path = file(
    dir(RapidApp->share_dir)->subdir('coreschema'),
    'ref_sqlite.db'
  )->resolve;
  return join('','dbi:SQLite:dbname=',$path);
};

sub _auto_deploy_schema {
	my $self = shift;
	my $schema = shift;
  
	my $deploy_statements = $schema->deployment_statements;
	my $md5 = $self->get_clean_md5($deploy_statements);
	my $Rs = $schema->resultset('DeployInfo');
	my $Source = $Rs->result_source;
	my $table = $schema->class($Source->source_name)->table;
	$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
	my $deployRow;
	
	try {
		$deployRow = $Rs->find($md5);
	}
	catch {
		# Assume exception is due to not being deployed yet and try to deploy:
		$schema->deploy;
    
		$Rs->create({
			md5					=> $md5,
      schema_class => $self->schema_class,
      schema_version  => (eval '$' . $self->schema_class . '::VERSION'),
			comment				=> 'DO NOT REMOVE THIS ROW',
			deployed_ddl		=> $deploy_statements,
			deployed_ts			=> DateTime->now( time_zone => 'local' ),
		});
    
    $self->_insert_default_rows($schema);
	};
	
	# If we've already been deployed and the ddl checksum matches:
	return 1 if ($deployRow);
	
	my $count = $Rs->count;
	my $dsn = $self->dsn;
	
	die "Database error; deploy_info table ('$table') exists but is empty in CoreSchema database '$dsn'"
		unless ($count > 0);
		
	die "Database error; multiple rows in deploy_info table ('$table') in CoreSchema database '$dsn'"
		if ($count > 1);
	
	my $exist_md5 = $Rs->first->md5 or die "Database error; found deploy_info row in table '$table' " .
	 "in CoreSchema database '$dsn', but it appears to be corrupt (no md5 checksum).";
	 
	return 1 if ($md5 eq $exist_md5);
  
  # If we're here, it means the md5 of the existing coreschema didn't match, but 
  # that doesn't mean that the differences make it unsafe to use. Any change in
  # the generated deploy statements, even trivial things like quotes/whitespace,
  # will come out as a different checksum. So, we'll perform an actual diff to
  # compare to see what the actual, effective differences are, using the reference
  # sqlite database file. We're doing this instead of using the actual CoreSchema
  # classes we already have because we're not interested in differences that can
  # be caused by specific loaded components, and other code-level changes that
  # might show up. (See also GitHub Issue #47)
  
  my $Differ = DBIx::Class::Schema::Diff->new(
    old_schema => $self->_load_connect_schema_ref,
    new_schema => $self->_load_connect_schema
  );
  
  unless( $Differ->diff ) {
    # If there are no changes at all, then we're already done...
    
    # Future:
    #
    # It is fully expected that in later versions of RapidApp there will be
    # changes to the CoreSchema. Once that happens, these will be handled
    # either dynamically or via Migrations/DeploymentHandler to alter the 
    # schema from known older versions to the latest. This code isn't present
    # because it hasn't happened yet -- we're still on Version 1 of the
    # schema...
    # 
    # But, the larger plan is to *dynamically* handle schema changes, including
    # support for merging of user defined schemas with the CoreSchema as well
    # as user-supplied databases to be used as the CoreSchema. Obviously, 
    # neither checksum or version checks are useful for these dynamic scenarios,
    # which is why the plan is to define a set of specific rules and tests
    # that will be required for a schema to be determined as suitable as the
    # CoreSchema. It is expected that DBIx::Class::Schema::Diff will do the 
    # heavy lifting for this.
    #
    # None of this is happening yet, as this is a big subproject on its own,
    # but the code has been structured with this in mind. For now, the only
    # check we're doing with Schema::Diff is "all or nothing", but it supports
    # fine-grained filtering (and, in fact, this planned RapidApp feature is
    # the entire reason I wrote DBIx::Class::Schema::Diff in the first place,
    # so in that sense a lot of the work for this has already been done, just
    # not yet within the RapidApp code base itself).
    
    
    # TODO: for faster startup next time, add/save the new md5 so we can skip
    # all this diff work...
  
  
    return 1;
  }
  
  
	die join("\n",'','',
	 "  The selected CoreSchema database '$dsn' ",
	 "  already has a deployed schema but it does not match ",
   "  the current schema.",'',
   "    deployed checksum  : $exist_md5",
   "    expected checksum  : $md5",'','',
   "  Differences from the reference schema (detected by DBIx::Class::Schema::Diff):",
   '','',
   Dumper( $Differ->diff ),'','',''
  );
}


# Need to strip out comments and blank lines to make sure the md5s will be consistent
sub clean_deploy_statements {
  my ($self, $deploy_statements) = @_;
  return join("\n", grep { 
    ! /^\-\-/ && 
    ! /^\s*$/ 
  } split(/\r?\n/,$deploy_statements) );
}

sub get_clean_md5 {
  my ($self, $deploy_statements) = @_;
	my $clean = $self->clean_deploy_statements($deploy_statements); 
	return md5_hex($clean);
}

sub _insert_default_rows {
  my $self = shift;
  my $schema = shift;
  
  $schema->resultset('NavtreeNode')->create({
    id => 0,
    pid => undef,
    text => 'DUMMY ROOT NODE',
    ordering => 0
  });
  
  $schema->resultset('User')->create({
    username => 'admin',
    set_pw => $self->init_admin_password
  });
  
  $schema->resultset('Role')->create({
    role => 'administrator',
    description => 'Full Control'
  });
  
  $schema->resultset('UserToRole')->create({
    username => 'admin',
    role => 'administrator',
  });

}


# TODO: clean up these package namespaces after we're done with them...
sub _load_connect_schema {
  my $self = shift;
  my $class = shift || 'RapidApp::CoreSchemaLoad';
  my $dsn = shift || $self->dsn;
  return DBIx::Class::Schema::Loader::make_schema_at(
    $class => {
      naming => { ALL => 'v7'},
      use_namespaces => 1,
      use_moose => 1,
      debug => 0,
    },[ $dsn ]
  );
}
sub _load_connect_schema_ref {
  my $self = shift;
  $self->_load_connect_schema('RapidApp::CoreSchemaLoadRef',$self->ref_dsn);
}


1;

__END__

=head1 NAME

Catalyst::Model::RapidApp::CoreSchema - DBIC model for the CoreSchema database

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp::CoreSchema /;

=head1 DESCRIPTION

This is the Catalyst model which is automatically injected by the 
L<RapidApp::CoreSchema|Catalyst::Plugin::RapidApp::CoreSchema> plugin and is not
intended to be loaded directly.

With the default configuration, this model automatically initializes and deploys itself
to an SQLite database file in the root of the application named C<rapidapp_coreschema.db>.

The CoreSchema database is a common location used for persistence by multiple optional
"Core" plugins, such as L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> and 
L<NavCore|Catalyst::Plugin::RapidApp::NavCore>

=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchema>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchemaAdmin>

=item * 

L<Catalyst>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
