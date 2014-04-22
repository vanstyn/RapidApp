package Catalyst::Model::RapidApp::CoreSchema;
use Moose;

use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

extends 'Catalyst::Model::DBIC::Schema';

use Catalyst::Model::DBIC::Schema::Types
    qw/ConnectInfo LoadedClass SchemaClass Schema/;
 
use MooseX::Types::Moose qw/ArrayRef Str ClassName Undef/;

use Module::Runtime;
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Path::Class qw(file dir);
use FindBin;
use DBIx::Class::Schema::Loader;
use DBIx::Class::Schema::Diff;

has schema_class => (
    is => 'ro',
    isa => SchemaClass,
    coerce => 1,
    default => 'RapidApp::CoreSchema'
);

has connect_info => (
  is => 'rw', 
  isa => ConnectInfo, 
  coerce => 1,
  lazy => 1,
  default => sub {
    my $self = shift;
    $self->_prepare_db_file;
    return {
      dsn => $self->dsn,
      quote_names => 1,
      on_connect_call => 'use_foreign_keys'
    };
  }
);

has 'init_admin_password', is => 'ro', isa => Str, default => 'pass';

has 'db_file', is => 'ro', isa => 'Str', default => 'rapidapp_coreschema.db';
has 'dsn', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
  my $self = shift;
  my $db_file = file($self->db_file);
  # Convert relative to absolute path:
  # TODO: get the actual $c->config->{home}
  $db_file = file(dir("$FindBin::Bin/../")->resolve,$db_file) if ($db_file->is_relative);
  return 'dbi:SQLite:dbname=' . $db_file;
};

# dsn for the "reference" coreschema database/file. This is used only for the
# purposes of schema comparison
has 'ref_dsn', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
  my $self = shift;
  my $db_file = file(RapidApp->share_dir,'coreschema/ref_sqlite.db')->resolve;
  return 'dbi:SQLite:dbname=' . $db_file;
};

sub _prepare_db_file {
  my $self = shift;
  my $class = $self->schema_class;
  Module::Runtime::require_module($class);
  my $schema = $class->connect($self->dsn);
  $self->_auto_deploy_schema($schema);
}

sub _auto_deploy_schema {
	my $self = shift;
	my $schema = shift;
  
	my $deploy_statements = $schema->deployment_statements;
	my $md5 = $self->get_clean_md5($deploy_statements);
	my $Rs = $schema->resultset('DeployInfo');
	my $table = $Rs->result_source->from;
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
