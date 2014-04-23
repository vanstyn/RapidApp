use strict;
use warnings;

use TestRA::ChinookDemo;

my $app = TestRA::ChinookDemo->apply_default_middlewares(TestRA::ChinookDemo->psgi_app);
$app;

