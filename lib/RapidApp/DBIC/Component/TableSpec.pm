package RapidApp::DBIC::Component::TableSpec;
use base 'DBIx::Class::Core';

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;

__PACKAGE__->mk_classdata( 'TableSpec' );

my $PKG;

# Find the package that loaded us:
for(my $i = 0; $i<10; $i++) {
	my $cur = caller($i);
	next if ($cur =~ /^Class\:\:C3/);
	if ($cur->can('table')) {
		$PKG = $cur;
		last;
	}
}

__PACKAGE__->TableSpec(RapidApp::TableSpec->new( name => $PKG->table ));
	
foreach my $col ($PKG->columns) {
	__PACKAGE__->TableSpec->add_columns( { name => $col } ); 
}

	



1;
