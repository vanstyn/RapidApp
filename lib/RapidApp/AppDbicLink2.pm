package RapidApp::AppDbicLink2;
use Moose;
extends 'RapidApp::AppDataStore2';
with 'RapidApp::Role::DbicLink2';

1;