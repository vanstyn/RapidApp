# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

require_ok('RapidApp::Util::MetaKeys::FK');
require_ok('RapidApp::Util::MetaKeys');

my @formats = &_formats;

my $i = 0;
for my $text (@formats) {
  $i++;
  my $Obj;

  ok(
    $Obj = RapidApp::Util::MetaKeys->load( $text ),
    "Parses to RapidApp::Util::MetaKeys object from load() [$i]"
  );

  is_deeply(
    $Obj->data,
    [
      bless( {
        lhs => {
          column => "assignee_id",
          table => "task"
        },
        rhs => {
          column => "id",
          table => "user"
        }
      }, 'RapidApp::Util::MetaKeys::FK' ),
      bless( {
        lhs => {
          column => "creator_id",
          table => "task"
        },
        rhs => {
          column => "id",
          table => "user"
        }
      }, 'RapidApp::Util::MetaKeys::FK' ),
      bless( {
        lhs => {
          column => "task_id",
          table => "comment"
        },
        rhs => {
          column => "id",
          table => "task"
        }
      }, 'RapidApp::Util::MetaKeys::FK' )
    ],
    "  expected data structure ($i)"
  );

}


done_testing;

# All of these strings should parse into the same MetaKeys object/config:
sub _formats {(

###################################
#### Dynamic/flexible key-vals ####
###################################

q{task.assignee_id => user.id
task.creator_id  => user.id
comment.task_id  => task.id
},

# blank lines
q{

task.assignee_id => user.id
task.creator_id  => user.id
comment.task_id  => task.id
},

# mixed comments
q{

task.assignee_id => user.id

# Comment 1:
task.creator_id  => user.id
comment.task_id  => task.id # <-- comment 2
},

# space delim
q{
task.assignee_id   user.id
task.creator_id    user.id
comment.task_id    task.id
},

# mixed delims
q{
task.assignee_id,  } . "\t\t" . q{      user.id #### <-- mixed tabs/spaces
task.creator_id  :::  user.id, #<-- rouge hanging comma
comment.task_id  >>>>  task.id
},

##############
#### JSON ####
##############

# Simple
q{[
  ['task.assignee_id', 'user.id'],
  ['task.creator_id',  'user.id'],
  ['comment.task_id',  'task.id']
]},

# JSON - mixed formats
q{[
  [{ table: 'task', column: 'assignee_id'}, { table: 'user', column: 'id'}],
  ['task.creator_id',  'user.id'],
  {
    lhs: {
      column: "task_id",
      table : "comment"
    },
    rhs: {
      column: "id",
      table : "task"
    }
  }
]},


)}
