package RapidApp::Helper::Traits::NavCore;

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
  } @list, 'RapidApp::NavCore';
};

around _ra_catalyst_configs => sub {
  my ($orig,$self,@args) = @_;

  my @list = $self->$orig(@args);

  # Make the TabGui config come first:
  return ( @list,
<<END,
    # The NavCore plugin automatically configures saved searches/views for
    # RapidDbic sources. When used with AuthCore, each user has their own saved
    # views in addition to system-wide saved views. No options are required.
    'Plugin::RapidApp::NavCore' => {
      #
    },
END
  );

};

1;
