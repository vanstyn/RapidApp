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
		$_ eq 'no_caller_data' or (
			ref($_) eq 'ARRAY' and
			scalar(@$_) == 3 and
			ref($_->[0]) eq 'HASH' and 
			defined $_->[0]->{package}
		)
	);
	
	my $data = $_[0];
	$data = \@_ if (scalar(@_) > 1);
	$data = Dumper($data) if (ref $data);
	$data = '  ' . UNDERLINE . 'undef' unless (defined $data);

	my $pre = '';
	$pre = BOLD . ($_->[2]->{subroutine} ? $_->[2]->{subroutine} . '  ' : '') .
		'[line ' . $_->[1]->{line} . ']: ' . CLEAR . "\n" unless ($_ eq 'no_caller_data');
	
	print STDERR $pre . $color . $data . CLEAR . "\n";
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


# Takes a list and returns a Hash. Like get_mixed_hash_args, but
# list order is preserved
sub get_mixed_hash_args_ordered {
	my @args = @_;
	return $args[0] if (ref($args[0]) eq 'HASH');
	@args = @{ $args[0] } if (ref($args[0]) eq 'ARRAY');
	
	my $hashref = {};
	my @list = ();
	my $last;
	foreach my $item (@args) {
		if (ref($item)) {
			die "Error in arguments" unless (ref($item) eq 'HASH' and defined $last and not ref($last));
			$hashref->{$last} = { %{$hashref->{$last}}, %$item };
			push @list, $last, $hashref->{$last};
			next;
		}
		$hashref->{$item} = {} unless (defined $hashref->{$item});
		push @list,$item,$hashref->{$item} unless (ref $last);
		$last = $item;
	}
	return @list; # <-- preserve order
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

sub caller_data_brief {
	my $depth = shift || 1;
	my $list = caller_data($depth + 1);
	my $regex = shift;
	
	shift @$list;
	shift @$list;
	
	my @inc_parms = qw(subroutine line filename);
	
	my %inc = map { $_ => 1 } @inc_parms;
	
	my @new = ();
	my $seq = 0;
	foreach my $item (@$list) {
		if($regex and ! eval('$item->{subroutine} =~ /' . $regex . '/')) {
			$seq++;
			next;
		}
		push @new, ' . ' x $seq if ($seq);
		$seq = 0;
		push @new, { map { $_ => $item->{$_} } grep { $inc{$_} } keys %$item };
	}
	
	return \@new;
}

# Returns a list with duplicates removed. If passed a single arrayref, duplicates are
# removed from the arrayref in place, and the new list (contents) are returned.
sub uniq {
	my %seen = ();
	return grep { !$seen{$_}++ } @_ unless (@_ == 1 and ref($_[0]) eq 'ARRAY');
	return () unless (@{$_[0]} > 0);
	# we add the first element to the end of the arg list to prevetn deep recursion in the
	# case of nested single element arrayrefs
	@{$_[0]} = uniq(@{$_[0]},$_[0]->[0]);
	return @{$_[0]};
}


sub debug_around {
	my ($pkg,$filename,$line) = caller;
	my $method = shift;
	my @methods = ( $method );
	@methods = @$method if (ref($method) eq 'ARRAY');
	
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%opt = (
		pkg			=> $pkg,
		filename		=> $filename,
		line			=> $line,
		%opt
	);
	
	foreach my $method (@methods) {
		my $around = func_debug_around($method, %opt);
		
		# It's a Moose class or otherwise already has an 'around' class method:
		if($pkg->can('around')) {
			$pkg->can('around')->($method => $around);
			next;
		}
		
		# The class doesn't have an around method, so we'll setup manually with Class::MOP:
		my $meta = Class::MOP::Class->initialize($pkg);
		$meta->add_around_method_modifier($method => $around)
		
	}
}

# Returns a coderef - designed to be a Moose around modifier - that will
# print useful debug info about the given function to which it is attached
sub func_debug_around {
	my $name = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%opt = (
		color				=> GREEN,
		ret_color		=> RED.BOLD,
		arg_ignore		=> sub { 0 }, # <-- no debug output prited when this returns true
		return_ignore	=> sub { 0 },# <-- no debug output prited when this returns true
		around			=> sub { # around wrapper to allow the user to pass a different one to use:
									my $orig = shift;
									my $self = shift;
									return $self->$orig(@_);
								},
		%opt
	);

	return sub {
		my $orig = shift;
		my $self = shift;
		my @args = @_;
		
		my $in;
		my $has_refs = 0;
		my @print_args = map { ref $_ and ++$has_refs ? ref $_ : $_ } @args;
		my $in = '(' . join(',',@args) . '): ';
		
		print STDERR '[' . $opt{line} . '] ' . CLEAR . $opt{color} . $opt{pkg} . CLEAR . '->' . 
				$opt{color} . BOLD . $name . CLEAR . $in;
		
		my @res = $opt{around}->($orig,$self,@args);

		local $_ = $self;
		if(!$opt{arg_ignore}->(@args) && !$opt{return_ignore}->(@res)) {
			
			print STDERR "\n  args: " . Dumper(\@args) . "\n: " if($has_refs);
			
			my $result = $res[0];
			
			$has_refs = 0;
			ref $_ and $has_refs++ for (@res);
			if($has_refs) {
				$result = Dumper(\@res);
			}
			elsif (@res > 1) {
				$result = '(' . join(',',@res) . ')';
			}
			
			my $out = $result;
			$out = UNDERLINE . 'undef' unless (defined $out);
			
			print STDERR $opt{ret_color} . $out . CLEAR . "\n";
		}
		else {
			# 'arg_ignore' and/or 'return_ignore' returned true, so we're not
			# supposed to print anything... but since we already have, in case
			# the function would have barfed, we'll print a \r to move the cursor
			# to the begining of the line so it will get overwritten, which is
			# almost as good as if we had not printed anything in the first place...
			# (note if the function printed something too we're screwed)
			print STDERR "\r";
		}
		
		return wantarray ? @res : "@res";
	};
}



# Automatically export all functions defined above:
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = Class::MOP::Class->initialize(__PACKAGE__)->get_method_list;
}

1;