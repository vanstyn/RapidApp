package RapidApp::DBIC::AuditAny::AuditContext;
use Moose;

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;

sub SchemaObj { (shift)->AuditObj->schema };
sub schema { ref (shift)->AuditObj->schema };
sub primary_key_separator { (shift)->AuditObj->primary_key_separator };
sub get_context_datapoints { (shift)->AuditObj->get_context_datapoints(@_) };

1;