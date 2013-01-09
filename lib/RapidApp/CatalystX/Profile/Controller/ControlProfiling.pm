package RapidApp::CatalystX::Profile::Controller::ControlProfiling;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Devel::NYTProf;

sub start_profiling : Local {
    my ($self, $c) = @_;
	DB::enable_profile();
    $c->log->debug('Profiling has now been started');
    $c->res->body('Profiling started');
}

sub stop_profiling : Local {
    my ($self, $c) = @_;
    DB::finish_profile();
    $c->log->debug('Profiling has now been disabled');
    $c->res->body('Profiling finished');
}

1;
