package RapidApp::DBIC::EngineBase;

use Moose;

use RapidApp::Debug 'DEBUG';

has schema => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

with 'RapidApp::DBIC::SchemaAnalysis';

use Module::Find;

sub BUILD {
	my $self= shift;
	$self->_loadCustomPortableItems(ref $self->schema);
}

sub _loadCustomPortableItems {
	my ($self, $schemaCls)= @_;
	
	DEBUG('import', 'Loading custom import-item modules...');
	
	my @tryLoad= grep { $_ =~ /::ImportItem$/ } findsubmod( $schemaCls );
	push @tryLoad, findsubmod $schemaCls.'::ImportItem';
	push @tryLoad, findsubmod $schemaCls.'::PortableItem';
	foreach my $m (@tryLoad) {
		DEBUG('import', '   ', $m);
		eval " require $m; import $m ; ";
		die $@ if $@;
	}
}

1;