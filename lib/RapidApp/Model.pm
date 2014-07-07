package RapidApp::Model;
#
# -------------------------------------------------------------- #
#


use strict;
use warnings;
use Moose;
extends 'Catalyst::Model';

# Don't think this class is being used

# This is gone:
#with 'RapidApp::Role::TopController';


our $VERSION = '0.1';


#### --------------------- ####




no Moose;
__PACKAGE__->meta->make_immutable;
1;
