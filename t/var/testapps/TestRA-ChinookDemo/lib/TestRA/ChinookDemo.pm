package # hide from PAUSE
     TestRA::ChinookDemo;
use Moose;
use namespace::autoclean;

# ----------
# Dynamically set a local TMPDIR to be relative to our
# expected directory structure within the RapidApp t/
# directory. We want to always end up with 't/var/tmp'
BEGIN {
  use Path::Class qw(dir);
  use FindBin '$Bin';
  
  my $dir = dir($Bin);
  while(-d $dir->parent) {
    if (-d $dir->subdir('testapps')) {
      # we're done
      last;
    }
    elsif(-d $dir->subdir('var') && -d $dir->subdir('var')->subdir('testapps')) {
      # This code path happens when we're called from a .t script
      $dir = $dir->subdir('var');
      last;
    }
    else {
      # keep walking up parent directories (this code path happens when we're
      # being called from a script within the test app)
      $dir = $dir->parent;
    }
  }
  
  die "Unable to resolve test tmp dir" unless (-d $dir->subdir('testapps'));
  
  my $tmpdir = $dir->subdir('tmp')->absolute;
  $tmpdir->mkpath unless (-d $tmpdir);
  
  # Make sure it actually exists/was created:
  die "Error resolving/creating test tmp dir '$tmpdir'" unless (-d $tmpdir);
  
  # Now, set the TMPDIR env variable (used by Catalyst::Utils::class2tempdir)
  $ENV{TMPDIR} = $tmpdir->stringify;
}
# ----------


use Catalyst::Runtime 5.80;

use RapidApp;

use Catalyst qw/
    -Debug
    RapidApp::RapidDbic
/;

extends 'Catalyst';

our $VERSION = '0.01';


__PACKAGE__->config(
    name => 'TestRA::ChinookDemo',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

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

# Start the application
__PACKAGE__->setup();



1;
