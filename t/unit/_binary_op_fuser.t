# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use DBIx::Class::Schema;

require_ok('RapidApp::Role::DbicLink2');

my @tests = (
  [ 'foo', { -in => [4,5,6] } ],
  [ \'(SELECT foo FROM bar)', { -in => [4,5,6] } ],
  [ \'bar', \['> ?', 2] ],
  [
    \'(SELECT COUNT( * ) FROM "film_actor" "me_alias" WHERE ( "me_alias"."actor_id" = "me"."actor_id" ))',
    { '>' => 20 }
  ],
  [ \"(SELECT CONCAT(me.dept_no,CONCAT(\" - \",me.name)))",  { 'like' => '%substring%' }],
);

my @expected = (
  \["foo  IN ( ?, ?, ? )",["\0",4],["\0",5],["\0",6]],
  \["(SELECT foo FROM bar)  IN ( ?, ?, ? )",["\0",4],["\0",5],["\0",6]],
  \["bar  > ?",2],
  \[
      "(SELECT COUNT( * ) FROM \"film_actor\" \"me_alias\" WHERE ( \"me_alias\".\"actor_id\" = \"me\".\"actor_id\" )) > ?",
      [{},20]
   ],
  \["(SELECT CONCAT(me.dept_no,CONCAT(\" - \",me.name))) LIKE ?",[{},"%substring%"]]
);


for my $q (0,1) {

  my $sm = DBIx::Class::Schema->connect(
    'dbi:SQLite::memory:', undef, undef, 
    { quote_names => $q }
  )->storage->sql_maker;

  is_deeply(
    [ map { RapidApp::Role::DbicLink2::_binary_op_fuser($sm, @$_) } @tests ],
    \@expected, 
    "_binary_op_fuser returns expected results (quote_names => $q)"
  );
  
}


done_testing;
