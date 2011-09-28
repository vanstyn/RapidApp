package RapidApp::Functions;

require Exporter;

use Term::ANSIColor qw(:constants);
use Data::Dumper;

BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = qw(scream scream_color);
}


sub scream {
	scream_color(YELLOW,@_);
}

sub scream_color {
	my $color = shift;
	print STDERR YELLOW . BOLD . "\n" . Dumper(\@_) . CLEAR . "\n";
}


1;