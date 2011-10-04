package RapidApp::Functions;

require Exporter;
use Class::MOP::Class;

use Term::ANSIColor qw(:constants);
use Data::Dumper;
use RapidApp::RootModule;

sub scream {
	scream_color(YELLOW . BOLD,@_);
}

sub scream_color {
	my $color = shift;
	print STDERR $color . "\n" . Dumper(\@_) . CLEAR . "\n";
}


# Takes a list and returns a HashRef. List can be a mixed Hash/List:
#(
#	item1 => { opt1 => 'foo' },
#	item2 => { key => 'data', foo => 'blah' },
#	'item3',
#	'item4',
#	item1 => { opt2 => 'foobar', opt3 => 'zippy do da' }
#)
# Bare items like item3 and item4 become {} in the returned hashref.
# Repeated items like item1 and merged
# also handles the first arg as a hashref or arrayref
sub get_mixed_hash_args {
	my @args = @_;
	return $args[0] if (ref($args[0]) eq 'HASH');
	@args = @{ $args[0] } if (ref($args[0]) eq 'ARRAY');
	
	my $hashref = {};
	my $last;
	foreach my $item (@args) {
		if (ref($item)) {
			die "Error in arguments" unless (ref($item) eq 'HASH' and defined $last and not ref($last));
			$hashref->{$last} = { %{$hashref->{$last}}, %$item };
			next;
		}
		$last = $item;
		$hashref->{$item} = {} unless (defined $hashref->{$item});
	}
	return $hashref;
}

# The coderefs supplied here get called immediately after the
# _load_root_module method in RapidApp/RapidApp.pm
sub rapidapp_add_global_init_coderef {
	foreach my $ref (@_) {
		ref($ref) eq 'CODE' or die "rapidapp_add_global_init_coderef: argument is not a CodeRef: " . Dumper($ref);
		push @RapidApp::RootModule::GLOBAL_INIT_CODEREFS, $ref;
	}
}

# Automatically export all functions defined above:
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = Class::MOP::Class->initialize(__PACKAGE__)->get_method_list;
}

1;