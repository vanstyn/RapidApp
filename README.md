# RapidApp

RapidApp is an open-source application framework that is currently under development for quickly building dynamic Web 2.0/AJAX interfaces for various data models. It is based on the following open-source technologies:

- Perl
- Catalyst
- ExtJS
- DBIx::Class

This is a development release and the API is not yet complete and likely to change. Documentation is also still lacking.

## INSTALLATION

First, clone the repo:

```
  cd /some/path
  git clone https://github.com/vanstyn/RapidApp
  cd RapidApp
```

RapidApp can either be installed as a module or simply ran directly out of a local directory. To install as a module:

```
  dzil build
  cpanm RapidApp-0.99004.tar.gz  # or whatever the current version is
```

Alternatively, to just run out of the local directory, you just need to add the lib directory to your @INC and also set the environment variable for the share_dir. For example:

```
  export PERLLIB="/some/path/RapidApp/lib"
  export RAPIDAPP_SHARE_DIR="/some/path/RapidApp/share"
```

You also need ExtJS 3.4:

```
  cd /some/path
  wget http://cdn.sencha.com/ext/gpl/ext-3.4.1.1-gpl.zip
  unzip ext-3.4.1.1-gpl.zip  # will extract to something like 'ext-3.4.1'
```

## SETUP AN APPLICATION

RapidApp is an extension to Catalyst. To enable RapidApp in an Catalyst application, you simply consume the role 'Catalyst::Plugin::RapidApp' (i.e. Moose/with) in the main application class. You can then build your app by creating RapidApp 'Module' classes (special Controllers) which automatically provide various ExtJS-based interfaces (panels, trees, grids, etc).

The documentation for how to build these Modules is still in-progress (and the Module API is being refactored), however, several higher-level plugins are available to automatically build Modules around pre-determined application paradigms which are documented (partially) below:

## RapidDbic

RapidDbic is a RapidApp/Catalyst plugin to automatically generate a complete RapidApp application around one or more DBIC::Schema models with the following features:

- ExtJS "explorer" interface (banner, navigation tree and tabbed content panel)
- Full CRUD access via grid (table) and page (row) interfaces for each schema/source
- Grid views can be customized (columns, sorts, filters, etc), saved and organized as new nodes in the tree (via optional NavCore plugin)
- Automatic authentication/authorization (via optional AuthCore plugin)

### Quick Setup

Create a new Catalyst application:

```
  catalyst.pl MyApp
  cd MyApp
```

Delete the auto generated Root controller:

```
  rm -f lib/MyApp/Controller/Root.pm
```

Create a DBIC database model. Here is an example for how to do this automatically from an existing database (read the docs for Catalyst::Model::DBIC::Schema for more info):

```
  script/myapp_create.pl model MyDB \
    DBIC::Schema MyApp::MyDB \
    create=static dbi:mysql:some_db dbuser dbpass \
    quote_names=1
```

Note that RapidApp requires 'quote_names' to be enabled.

Setup lib/MyApp.pm:

```perl
  package MyApp;
  use Moose;
  use namespace::autoclean;
  
  use Catalyst::Runtime 5.80;
  use RapidApp;
  
  extends 'Catalyst';
  our $VERSION = '0.01';
  
  my @plugins = (
    '-Debug',
    
    # The RapidDbic Plugin. Enables RapidApp
    'RapidApp::RapidDbic',
    
    # Optional extra plugin to setup authentication/sessions
    # default username/password: admin/pass
    'RapidApp::AuthCore',
    
    # Optional extra plugin to enable saved views and customizable nav tree
    'RapidApp::NavCore'
  );
  
  __PACKAGE__->config(
      name => 'MyApp',
      # Disable deprecated behavior needed by old applications
      disable_component_resolution_regex_fallback => 1,
      
      extjs_dir => '/some/path/ext-3.4.1',
      
      'Plugin::RapidApp::RapidDbic' => {
        dbic_models => [
          'MyDB', # access the DBIC model MyApp::Model::MyDB
          'RapidApp::CoreSchema' # optional - access the AuthCore/NavCore data
        ]
        
        # More options  ...
      }
  );
  
  # Start the application
  __PACKAGE__->setup(@plugins);
  
  1;
```

The above is a fully working application. Start the test server:

```
  script/myapp_server.pl
```

The above is just the barebones configuration, is read-only, etc. There are many more options that can be passed to the 'Plugin::RapidApp::RapidDbic' config to control all aspects of the CRUD, grid display, columns, and so on. I'm still working on documenting these, but for now, see MimeCas for a running example with lots of example options.

### Optional plugins

The plugins 'RapidApp::AuthCore' and 'RapidApp::NavCore' are optional which add extra turn-key functionality. These modules persist data in the 'RapidApp::CoreSchema' model which creates an sqlite database file in the app home directory.

#### RapidApp::AuthCore

This plugin turns on simple authentication and sessions with a user database. Currently this is just a plaintext authentication realm. It also has a Roles table but it doesn't do anything yet. This plugin's primary function right now is more for demonstration purposes than anything else but it will be expanded shortly (note that you can alternatively setup normal Catalyst authentication/authorization/sessions).

#### RapidApp::NavCore

This plugin enables saved views and the ability to customize the nav tree. When used with AuthCore users have their own private views in addition to public views that show up for all users. After customizing a grid view with filters, sorts, columns, etc, you can save it by selecting "Save Search" from the Options menu in the grid toolbar. You can then click "Organize Tree" to drag/drop customize the nav tree.

## IN PROGRESS

This doc is very much in progress....

## SUPPORT

This is a brand new project and is still in the process of getting organized. If you are interested in learning more or getting involved, or just have questions, you can find me in the new channel #rapidapp I started on irc.perl.org or via E-Mail at vanstyn@cpan.org.

## AUTHOR

Henry Van Styn <vanstyn@cpan.org>

## COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


