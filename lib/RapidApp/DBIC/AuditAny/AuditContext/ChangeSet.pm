package RapidApp::DBIC::AuditAny::AuditContext::ChangeSet;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'changes', is => 'ro', isa => 'ArrayRef', default => sub {[]};

sub add_changes { push @{(shift)->changes}, @_ }

sub all_changes { @{(shift)->changes} }

1;