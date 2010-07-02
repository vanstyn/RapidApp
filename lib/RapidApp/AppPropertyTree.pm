package RapidApp::AppPropertyTree;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Tree checkbox property app object
#
#
# 2010-02-18:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::AppBase';


use Try::Tiny;
use Term::ANSIColor qw(:constants);

use SBL::Web::ExtJS;

use RapidApp::Tree;

our $VERSION = '0.1';


#### --------------------- ####

has 'get_properties_coderef' 		=> ( is => 'ro',	required		=> 1,		isa => 'CodeRef'			);
has 'save_properties_coderef' 	=> ( is => 'ro',	required 	=> 0,		isa => 'CodeRef'			);
has 'Tree' 								=> ( is => 'ro',	lazy_build	=> 1										);
has 'TreeConfig' 						=> ( is => 'ro',	lazy_build	=> 1										);

has 'title' 							=> ( is => 'ro',	lazy_build 	=> 1,	isa => 'Str'					);


has 'TreePanel' 						=> ( is => 'ro',	lazy_build	=> 1										);




sub _build_TreeConfig {
	my $self = shift;
	my $TreeConfig = $self->get_properties_coderef->();
	die "get_properties_coderef must return an ArrayRef" unless (ref($TreeConfig) eq 'ARRAY');
	return $TreeConfig;
}


sub _build_Tree {
	my $self = shift;
	
	return RapidApp::Tree->new(
		treepanel_id			=> 'foooooo',
		TreeConfig				=> $self->TreeConfig,
	);
}


sub _build_default_action { 
	my $self = shift;
	sub { $self->JSON_encode($self->Tree->TreePanel_cfg); } 
}



###########################################################################################




no Moose;
__PACKAGE__->meta->make_immutable;
1;