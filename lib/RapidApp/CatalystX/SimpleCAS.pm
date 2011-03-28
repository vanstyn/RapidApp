package RapidApp::CatalystX::SimpleCAS;

our $VERSION = '0.01';
use Moose::Role;
use namespace::autoclean;

use CatalystX::InjectComponent;


after 'setup_components' => sub {
    my $class = shift;
    CatalystX::InjectComponent->inject(
        into => $class,
        component => 'RapidApp::CatalystX::SimpleCAS::Controller',
        as => 'Controller::SimpleCAS'
    );
};

1;


__END__

