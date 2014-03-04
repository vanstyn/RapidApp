package RapidApp::Debug;
use strict;
use warnings;
use RapidApp;

# DEPRECATED - will be removed - refs #41


use Exporter qw( import );
our @EXPORT_OK = 'DEBUG';

# Emulate legacy calls to 'DEBUG' for now:
sub DEBUG {
  my @args = @_;
  my $c = RapidApp->active_request_context;
  if($c) {
    $c->log->debug(join(' ',@args));
  }
  else {
    warn '[RapidApp::Debug]: ' . join(' ',@args) . "\n";
  }
}

1;
