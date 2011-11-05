package RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);

unshift @UNIVERSAL::ISA, __PACKAGE__;

use Attribute::Handlers;

# Note: This doesn't work on DBIC classes with use base, but does work
# with use MooseX::NonMoose

sub Debug :ATTR(CODE,BEGIN) {

	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	
	my %opt = (pkg => $package, filename => $filename, line => $linenum);
	%opt = ( %opt, @$data ) if (ref($data) eq 'ARRAY');

	return debug_around(*{$symbol}{NAME},%opt);
}


=pod
use Sub::Attribute;

# Automatically setup 'debug_around' on methods with the 'Debug' attribute:
sub Debug :ATTR_SUB {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	
	scream(join('',
		ref($referent), " ",
		*{$symbol}{NAME}, " ",
		"($referent) ", "was just declared ",
		"and ascribed the ${attr} attribute ",
		"with data ($data)\n",
		"in phase $phase\n",
		"in file $filename at line $linenum\n"
	));
	
	
	return debug_around(*{$symbol}{NAME}, pkg => $package, filename => $filename, line => $linenum);
}


=cut

1;