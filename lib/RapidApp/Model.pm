package RapidApp::Model;
#
# -------------------------------------------------------------- #
#


use strict;
use warnings;
use Moose;
extends 'Catalyst::Model';
with 'RapidApp::Role::TopController';


our $VERSION = '0.1';


#### --------------------- ####




no Moose;
__PACKAGE__->meta->make_immutable;
1;
