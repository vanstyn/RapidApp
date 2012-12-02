package RapidApp::DBIC::AuditAny::Collector::DBIC;
use Moose;
extends 'RapidApp::DBIC::AuditAny::Collector';

use RapidApp::Include qw(sugar perlutil);

has 'AuditObj', is => 'ro', required => 1;
has 'log_schema', is => 'ro', lazy => 1, default => sub { (shift)->AuditObj->schema };
has 'change_log_source', is => 'ro', isa => 'Str', required => 1;

sub uses_schema { (shift)->log_schema }
sub uses_sources { ( (shift)->change_log_source ) }


sub record_change {
	my $self = shift;
	my $Context = shift;
	
	
	scream($Context->all_datapoint_values,$Context->column_datapoint_values);
	
	
}




1;