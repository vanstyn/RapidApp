package RapidApp::CatalystX::AutoAssets;

our $VERSION = '0.01';
use Moose::Role;
use namespace::autoclean;

use CatalystX::InjectComponent;


after 'setup_components' => sub {
    my $class = shift;
    CatalystX::InjectComponent->inject(
        into => $class,
        component => 'RapidApp::CatalystX::AutoAssets::Controller',
        as => 'Controller::Asset'
    );
};

sub autoasset_include_tags {
	my $c = shift;
	return $c->controller('Asset')->html_head_includes;
}

1;


__END__

