package Catalyst::Plugin::RapidApp::RapidDbic;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
use Catalyst::Utils;

#use Schema::Sakila;
#for my $class (keys %{Schema::Sakila->class_mappings}) {
#  $class->load_components('+RapidApp::DBIC::Component::TableSpec');
#  $class->apply_TableSpec;
#}


before 'setup_component' => sub {
    my( $c, $component ) = @_;
		
		my $suffix = Catalyst::Utils::class2classsuffix( $component );
    my $config = $c->config->{ $suffix } || {};
		my $cmp_config = try{$component->config} || {};
		
		my $cnf = { %$cmp_config, %$config };
		
		# Look for the 'schema_class' key, and if found assume this is a
		# DBIC model. This is currently overly broad by design
		my $schema_class = $cnf->{schema_class} or return;
		
		# We have to make sure the TableSpec component has been loaded on
		# each Result class *early*, before 'Catalyst::Model::DBIC::Schema'
		# gets ahold of it. Otherwise problems will happen if we try to
		# load it later:
		Module::Runtime::require_module($schema_class);
		for my $class (keys %{$schema_class->class_mappings}) {
			next if ($class->can('TableSpec_cnf'));
			$class->load_components('+RapidApp::DBIC::Component::TableSpec');
			$class->apply_TableSpec;
		}


};

1;


