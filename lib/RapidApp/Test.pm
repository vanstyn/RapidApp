package RapidApp::Test;
use base 'Catalyst::Test';

use strict;
use warnings;
use Import::Into;

use Time::HiRes qw(gettimeofday tv_interval);
use HTTP::Request::Common;
use JSON::MaybeXS qw(decode_json);
use Catalyst::Utils;
use RapidApp::Test::Client;

my $target;
my $app_class;

sub import {
  $target = caller;
  my ($self, $class, @args) = @_;
  
  # Since apps might take a while to start-up:
  pass("[RapidApp::Test]: loading testapp '$class'...");
  
  my $start = [gettimeofday];
  
  require_ok($class);
  Catalyst::Test->import::into($target,$class,@args);
  
  my @funcs = grep { 
    $_ ne 'import' && $_ ne 'AUTOLOAD'
  } Class::MOP::Class->initialize(__PACKAGE__)->get_method_list;
  
  # Manually export our functions:
  {
    no strict 'refs';
    *{ join('::',$target,$_) } = \*{ $_ } for (@funcs);
  }
  
  ok(
    $class->setup_finished || $class->setup,
    sprintf("$class loaded/started (%0.4f seconds)",tv_interval($start))
  );
  
  $app_class = $class;
};

our $AUTOLOAD;
sub AUTOLOAD {
  my $method = (reverse(split('::',$AUTOLOAD)))[0];
  $target->can($method)->(@_);
}

## Setup the "client" object
my $Client; sub client { $Client }
$Client = RapidApp::Test::Client->new({ request_caller => sub { 
  my $req = shift;
  ok(
    my $res = client->record_response( request($req) ),
    client->describe_request
  );
  return $res;
}});
##

sub app_class   { $app_class }
sub app_version { eval(join('','$',app_class(),'::VERSION')) }
sub app_prefix  { Catalyst::Utils::appprefix(app_class()) }

# These are tests which should pass for all RapidApp applications:
# TODO: refactor into Test::Client
sub run_common_tests {

  ok($RapidApp::VERSION, 'RapidApp $VERSION ('.$RapidApp::VERSION.')');
  
  my $ver = app_version;
  ok($ver, 'App (' . app_class(). ') $VERSION ('.$ver.')');

  action_ok(
    '/assets/rapidapp/misc/static/images/rapidapp_powered_logo_tiny.png',
    "Fetched RapidApp logo from the Misc asset controller"
  );
  
  action_ok(
    '/any/prefix/path/_ra-rel-mnt_/assets/rapidapp/misc/static/images/rapidapp_powered_logo_tiny.png',
    "Fetched RapidApp logo from the Misc asset controller (via _ra-rel-mnt_)"
  );

  action_notfound(
    '/assets/rapidapp/misc/static/some/bad/file.txt',
    "Invalid asset path not found as expected"
  );
  
  action_notfound(
    '/any/prefix/path/_ra-rel-mnt_/assets/rapidapp/misc/static/some/bad/file.txt',
    "Invalid asset path not found as expected (via _ra-rel-mnt_)"
  );

}


1;
