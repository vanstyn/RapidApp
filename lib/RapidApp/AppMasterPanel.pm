package RapidApp::AppMasterPanel;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS master app object
#
#
# 2010-02-18:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::AppBase';



our $VERSION = '0.1';

use SBL::Web::ExtJS;
use Try::Tiny;

use Term::ANSIColor qw(:constants);

#### --------------------- ####



###########################################################################################




no Moose;
__PACKAGE__->meta->make_immutable;
1;