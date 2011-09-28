package RapidApp::Functions;

require Exporter;
use Class::MOP::Class;

use Term::ANSIColor qw(:constants);
use Data::Dumper;
use RapidApp::RapidApp;

sub scream {
	scream_color(YELLOW,@_);
}

sub scream_color {
	my $color = shift;
	print STDERR YELLOW . BOLD . "\n" . Dumper(\@_) . CLEAR . "\n";
}

# The coderefs supplied here get called immediately after the
# _load_root_module method in RapidApp/RapidApp.pm
sub rapidapp_add_global_init_coderef {
	foreach my $ref (@_) {
		ref($ref) eq 'CODE' or die "rapidapp_add_global_init_coderef: argument is not a CodeRef: " . Dumper($ref);
		push @RapidApp::RapidApp::GLOBAL_INIT_CODEREFS, $ref;
	}
}

# Automatically export all functions defined above:
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = Class::MOP::Class->initialize(__PACKAGE__)->get_method_list;
}

1;