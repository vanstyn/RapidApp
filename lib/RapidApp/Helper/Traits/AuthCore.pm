package RapidApp::Helper::Traits::AuthCore;

use strict;
use warnings;

use Moose::Role;

requires '_ra_catalyst_plugins';
requires '_ra_catalyst_configs';

around _ra_catalyst_plugins => sub {
  my ($orig,$self,@args) = @_;
  
  my @list = $self->$orig(@args);
  
  return grep { 
    $_ ne 'RapidApp' #<-- Base plugin redundant
  } @list, 'RapidApp::AuthCore', 'RapidApp::CoreSchemaAdmin';
};

around _ra_catalyst_configs => sub {
  my ($orig,$self,@args) = @_;
  
  my @list = $self->$orig(@args);
  
  # Make the TabGui config come first:
  return ( @list,
<<END,
    # The AuthCore plugin automatically configures standard Catalyst Authentication,
    # Authorization and Session plugins, using the RapidApp::CoreSchema database
    # to store session and user databases. Opon first initialization, the default
    # user 'admin' is created with default password 'pass'. No options are required
    'Plugin::RapidApp::AuthCore' => {
      #passphrase_class => 'Authen::Passphrase::BlowfishCrypt',
      #passphrase_params => {
      #  cost        => 14,
      #  salt_random => 1,
      #}
    },
END
,
<<END,
    # The CoreSchemaAdmin plugin automatically configures RapidDbic to provide access
    # the system CoreSchema database. No options are required
    'Plugin::RapidApp::CoreSchemaAdmin' => {
      #
    },
END
  );

};

1;
