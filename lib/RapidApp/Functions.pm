package RapidApp::Functions;

require Exporter;
use Class::MOP::Class;

use Term::ANSIColor qw(:constants);
use Data::Dumper;
use RapidApp::RootModule;

sub scream {
	local $_ = caller_data(3);
	scream_color(YELLOW . BOLD,@_);
}

sub scream_color {
	my $color = shift;
	local $_ = caller_data(3) unless (
		ref($_) eq 'ARRAY' and
		scalar(@$_) == 3 and
		ref($_->[0]) eq 'HASH' and 
		defined $_->[0]->{package}
	);
	
	my $data = $_[0];
	$data = \@_ if (scalar(@_) > 1);

	my $sub = $_->[2]->{subroutine} ? $_->[2]->{subroutine} . '  ' : '';
	
	print STDERR 
		BOLD . $sub . '[line ' . $_->[1]->{line} . ']: ' . CLEAR . "\n" .
		$color . Dumper($data) . CLEAR . "\n";
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

# returns \0 and \1 and 0 and 1, and returns 0 and 1 as 0 and 1
sub jstrue {
	my $v = shift;
	ref($v) eq 'SCALAR' and return $$v;
	return $v;
}


# The coderefs supplied here get called immediately after the
# _load_root_module method in RapidApp/RapidApp.pm
sub rapidapp_add_global_init_coderef {
	foreach my $ref (@_) {
		ref($ref) eq 'CODE' or die "rapidapp_add_global_init_coderef: argument is not a CodeRef: " . Dumper($ref);
		push @RapidApp::RootModule::GLOBAL_INIT_CODEREFS, $ref;
	}
}

# Returns an arrayref of hashes containing standard 'caller' function data
# with named properties:
sub caller_data {
	my $depth = shift || 1;
	
	my @list = ();
	for(my $i = 0; $i < $depth; $i++) {
		my $h = {};
		($h->{package}, $h->{filename}, $h->{line}, $h->{subroutine}, $h->{hasargs},
			$h->{wantarray}, $h->{evaltext}, $h->{is_require}, $h->{hints}, $h->{bitmask}) = caller($i);
		push @list,$h;
	}
	
	return \@list;
}


# Automatically export all functions defined above:
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = Class::MOP::Class->initialize(__PACKAGE__)->get_method_list;
}

1;