package RapidApp::Error::CustomPrompt;
use RapidApp::Responder::CustomPrompt;

sub new {
	my $class= shift;
	RapidApp::ScopedGlobals->log->warn("Use RapidApp::Responder::CustomPrompt instead of RapidApp::Error::CustomPrompt");
	return RapidApp::Responder::CustomPrompt->new(@_);
}

1;
