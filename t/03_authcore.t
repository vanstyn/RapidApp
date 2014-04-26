# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';

use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";
use Path::Class qw(file dir);
use RapidApp::Include qw(sugar perlutil);

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

BEGIN {
  package TestApp2::Model::DB;
  use Moose;
  extends 'TestRA::ChinookDemo::Model::DB';
  $INC{'TestApp2/Model/DB.pm'} = __FILE__;
  1;
}

BEGIN {
  package TestApp2;
  use Moose;

  use RapidApp;
  use Catalyst qw/
    RapidApp::RapidDbic 
    RapidApp::AuthCore
    RapidApp::CoreSchemaAdmin
  /;

  extends 'Catalyst';

  our $VERSION = '0.01';

  __PACKAGE__->config(
    name => 'TestApp2',

    'Plugin::RapidApp::RapidDbic' => {
      # Only required option:
      dbic_models => ['DB']
    }
  );

  # Let RapidApp::Test call setup() for us so we can get accurate load time:
  #__PACKAGE__->setup();
  
  $INC{'TestApp2.pm'} = __FILE__;
  1;
}


# ----------------
# This is a development option to be able to run this test app
# interactively (i.e. just like the test server script) instead
# of actually running the tests
if($ENV{RA_INTERACTIVE}) {
  use Catalyst::ScriptRunner;
  Catalyst::ScriptRunner->run('TestApp2', 'Server');
  # the above line never returns...
  exit;
}
# ----------------

use Test::More;
use Test::HTML::Content;
use HTTP::Headers::Util qw(split_header_words);

use RapidApp::Test 'TestApp2';
  
run_common_tests();


sub login {
  my $msg = shift || "Successfully logged in as 'admin'";
  my $login_res = client->post_request('/auth/login',{
    username => 'admin', password => 'pass'
  });
  
  is(
    $login_res->header('X-RapidApp-Authenticated'),
    'admin',
    $msg
  );
}

sub logout {
  my $msg = shift || "Logged out (and logout redirects to '/')";
  my $res = client->get_request('/auth/logout');
  ok(
    client->lres->is_redirect && client->lres->header('Location') eq '/',
    $msg
  );
}

sub users_store_read {
  # This simulates what a DataStore read currently looks like:
  client->ajax_post_decode(
    '/main/db/rapidapp_coreschema_user/store/read', [
       columns => '["id","username","password","set_pw","roles","saved_states","user_to_roles"]',
       fields  => '["id","username","password","full_name","last_login_ts"]',
       limit   => '25',
       query   => '',
  quicksearch_mode => 'like',
       start   => '0'
    ]
  ) || {};
}

sub users_read_allowed {
  my $msg = shift || "DataStore read returned expected users rows";
  my $users_read = users_store_read();

  # This is the user row setup automatically by AuthCore:
  my $def_user_rows = {
    'roles' => 'administrator',
    '___record_pk' => '1',
    'set_pw' => undef,
    'username' => 'admin',
    'password' => '{CRYPT}$2a$09$0W2Bxv/o3HHEzq.cftHh.O93QLRm41ecLL2QNgzqUY1PIJDc9.E.K',
    'saved_states' => 0,
    'user_to_roles' => 1,
    'id' => 1
  };

  is_deeply(
    $users_read->{rows},
    [ $def_user_rows ],
    $msg
  );
}

sub users_read_denied {
  my $msg = shift || "DataStore read of users denied as expected";
  my $users_read = users_store_read();
  is_deeply(
    {
      rows => $users_read->{rows},
      msg  => $users_read->{msg}
    },
    {
      rows => [],
      msg  => "Permission denied"
    },
    $msg
  );
}


my $root_cnt = client->browser_get_raw('/');
title_ok (
  $root_cnt => "TestApp2 v$TestApp2::VERSION - Login", 
  "root document has expected HTML <title> (login page)"
);

users_read_denied("Users grid read denied without logging in");

login();

ok(
  client->lres->is_redirect && client->lres->header('Location') eq '/',
  "Login redirects to '/'"
);

my $users_grid = client->ajax_get_raw('/main/db/rapidapp_coreschema_user');
ok(
  $users_grid =~ qr!/main/db/rapidapp_coreschema_user/store/read!,
  "Saw expected string within returned users grid content"
);

users_read_allowed();


logout();
users_read_denied("Users grid read denied after logout");

login("Logged back in");
users_read_allowed("Users grid read allowed again");

client->cookie( undef );
users_read_denied("Users grid read denied after clearing session cookie");



done_testing;
__END__

#For debugging:
scream_color(GREEN.BOLD,join("\n",
  "REQUEST:\n\n" .  client->lreq->as_string . "\n", 
  "RESPONSE:\n\n" . client->lres->as_string . "\n"
));