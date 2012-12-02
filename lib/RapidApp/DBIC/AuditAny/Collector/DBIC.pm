package RapidApp::DBIC::AuditAny::Collector::DBIC;
use Moose;
extends 'RapidApp::DBIC::AuditAny::Collector';

use RapidApp::Include qw(sugar perlutil);

has 'AuditObj', is => 'ro', required => 1;
has 'log_schema', is => 'ro', lazy => 1, default => sub { (shift)->AuditObj->schema };
has 'change_log_source', is => 'ro', isa => 'Str', required => 1;

sub uses_schema { (shift)->log_schema }
sub uses_sources { ( (shift)->change_log_source ) }


sub record_changes {
	my $self = shift;
	my $ChangeSet = shift;
	
	scream_color(MAGENTA,'record changes');
	
	my @Changes = $ChangeSet->all_changes;
	
	scream([ map {
		[ $_->all_datapoint_values,$_->column_datapoint_values ]
	} @Changes ], scalar(@Changes));
	
}




1;