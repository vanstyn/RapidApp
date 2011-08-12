package RapidApp::DbicAppGridSelector;
use strict;
use Moose;

extends 'RapidApp::AppGridSelector';
with 'RapidApp::Role::DbicLink';

1;