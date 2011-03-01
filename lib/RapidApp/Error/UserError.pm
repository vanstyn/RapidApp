package RapidApp::Error::UserError;
use RapidApp::Responder::UserError;
sub new {
	my $cls= shift;
	RapidApp::ScopedGlobals->log->warn("Use RapidApp::Responder::UserError instead of RapidApp::Error::UserError");
	RapidApp::Responder::UserError->new(@_);
}

1;