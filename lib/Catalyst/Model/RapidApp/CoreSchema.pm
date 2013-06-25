package Catalyst::Model::RapidApp::CoreSchema;
use Moose;

use strict;
use warnings;

extends 'Catalyst::Model::DBIC::Schema';

use Catalyst::Model::DBIC::Schema::Types
    qw/ConnectInfo LoadedClass SchemaClass Schema/;
 
use MooseX::Types::Moose qw/ArrayRef Str ClassName Undef/;

use Module::Runtime;
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Path::Class qw(file dir);
use FindBin;

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

has 'db_file', is => 'ro', isa => 'Str', default => 'rapidapp_coreschema.db';
has 'dsn', is => 'ro', isa => 'Str', lazy => 1, default => sub { 
  my $self = shift;
  my $db_file = file($self->db_file);
  # Convert relative to absolute path:
  # TODO: get the actual $c->config->{home}
  $db_file = file(dir("$FindBin::Bin/../")->resolve,$db_file) if ($db_file->is_relative);
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
	
	die "\n\n" . join("\n",
	 "  The selected CoreSchema database '$dsn' ",
	 "  already has a deployed schema but it does not match ",
   "  the current schema.\n",
   "    deployed checksum  : $exist_md5",
   "    expected checksum  : $md5\n"
	) . "\n\n";
}

# Need to strip out comments and blank lines to make sure the md5s will be consistent
sub get_clean_md5 {
	my $self = shift;
	my $deploy_statements = shift;
	my $clean = join("\n", grep { ! /^\-\-/ && ! /^\s*$/ } split(/\r?\n/,$deploy_statements) );
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
    password => 'pass'
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


1;
