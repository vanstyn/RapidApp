# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';

use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";
use Path::Class qw(file dir);

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

{
  package TestApp1::Model::DB;
  use Moose;
  extends 'TestRA::ChinookDemo::Model::DB';
  $INC{'TestApp1/Model/DB.pm'} = __FILE__;
  1;
}

{
  package TestApp1;
  use Moose;

  use RapidApp;
  use Catalyst qw/RapidApp::RapidDbic/;

  extends 'Catalyst';

  our $VERSION = '0.01';

  __PACKAGE__->config(
    name => 'TestApp1',

    # ------
    # This RapidDbic config was been copied verbatim from RA::ChinookDemo (02_rapiddbic_basics)
    # https://github.com/IntelliTree/RA-ChinookDemo/blob/02_rapiddbic_basics/lib/RA/ChinookDemo.pm
    # ------
    'Plugin::RapidApp::RapidDbic' => {
      # Only required option:
      dbic_models => ['DB'],
      configs => { # Model Configs
         DB => { # Configs for the model 'DB'
            grid_params => {
               '*defaults' => { # Defaults for all Sources
                  updatable_colspec => ['*'],
                  creatable_colspec => ['*'],
                  destroyable_relspec => ['*']
               }, # ('*defaults')
               Album => {
                  include_colspec => ['*','artistid.name'] 
               },
               Genre => {
                  # Leave persist_immediately on without the add form
                  # (inserts blank/default rows immediately):
                  use_add_form => 0,
                  # No delete confirmations:
                  confirm_on_destroy => 0
               },
               Invoice => {
                  # Delete invoice_lines with invoice (cascade):
                  destroyable_relspec => ['*','invoice_lines']
               },
               InvoiceLine => {
                  # join all columns of all relationships (first-level):
                  include_colspec => ['*','*.*'],
                  updatable_colspec => [
                     'invoiceid','unitprice',
                     'invoiceid.billing*'
                  ],
               },
               MediaType => {
                  # Use the grid itself to set new row values:
                  use_add_form => 0, #<-- also disables autoload_added_record
                  persist_immediately => {
                     create  => 0,
                     update  => 1,
                     destroy => 1
                  },
                  # No delete confirmations:
                  confirm_on_destroy => 0
               },
               Track => {
                  include_colspec => ['*','albumid.artistid.*'],
                  # Don't persist anything immediately:
                  persist_immediately => {
                     # 'create => 0' changes these defaults:
                     #   use_add_form => '0' (normally 'tab')
                     #   autoload_added_record => 0 (normally '1')
                     create  => 0,
                     update  => 0,
                     destroy => 0
                  },
                  # Use the add form in a window:
                  use_add_form => 'window'
               },
            }, # (grid_params)
            TableSpecs => {
               Album => {
                  display_column => 'title'
               },
               Artist => {
                  display_column => 'name'
               },
               Employee => {
                  # Use virtual column 'full_name' as the display column:
                  display_column => 'full_name'
               },
               Genre => {
                  display_column => 'name',
                  auto_editor_type => 'combo'
               },
               MediaType => {
                  display_column => 'name',
                  auto_editor_type => 'combo'
               },
               Track => {
                  columns => {
                     bytes => {
                        renderer => 'Ext.util.Format.fileSize'
                     },
                     unitprice => {
                        renderer => 'Ext.util.Format.usMoney',
                        header   => 'Price',
                        width    => 50
                     },
                     name => {
                        header => 'Name', width => 140
                     },
                     albumid => {
                        header => 'Album', width => 130
                     },
                     mediatypeid => {
                        header => 'Media Type', width => 165
                     },
                     genreid => {
                        header => 'Genre', width => 110
                     },
                     playlist_tracks => {
                        sortable  => 0
                     },
                     milliseconds => {
                        hidden   => 1
                     },
                     composer => {
                        hidden   => 1,
                        no_quick_search => 1,
                        no_multifilter  => 1
                     },
                     trackid => {
                        #allow_add  => 1,
                        #allow_edit => 1
                        no_column   => 1,
                        no_quick_search => 1,
                        no_multifilter  => 1
                     },
                  },
               },
            }, # (TableSpecs)
            virtual_columns => {
               Employee => {
                  full_name => {
                     data_type => "varchar",
                     is_nullable => 0,
                     size => 255,
                     sql => 'SELECT self.firstname || " " || self.lastname',
                     set_function => sub {
                        my ($row, $value) = @_;
                        my ($fn, $ln) = split(/\s+/,$value,2);
                        $row->update({ firstname=>$fn, lastname=>$ln });
                     },
                  },
               },
            }, # (virtual_columns)
         }, # (DB)
      }, # (configs)
    }, # ('Plugin::RapidApp::RapidDbic')
  );

  __PACKAGE__->setup();
  $INC{'TestApp1.pm'} = __FILE__;
  1;
}

# ----------------
# This is a development option to be able to run this test app
# interactively (i.e. just like the test server script) instead
# of actually running the tests
if($ENV{RA_INTERACTIVE}) {
  use Catalyst::ScriptRunner;
  Catalyst::ScriptRunner->run('TestApp1', 'Server');
  # the above line never returns...
  exit;
}
# ----------------


use Test::More;
use Catalyst::Test 'TestApp1';

action_ok(
  '/assets/rapidapp/misc/static/images/rapidapp_powered_logo_tiny.png',
  "Fetched RapidApp logo from the Misc asset controller"
);

done_testing;