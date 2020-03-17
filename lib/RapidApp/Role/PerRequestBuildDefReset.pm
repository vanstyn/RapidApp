package RapidApp::Role::PerRequestBuildDefReset;

use Moose::Role;

# Role used as attribute traits. All attributes with this role will have
# their value saved on the very first request after object construction,
# and then reset back to that default value on every subsequent request
# for the life of the object

1;
