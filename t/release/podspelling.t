#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

plan skip_all => 'set RELEASE_TESTING to enable this test' unless $ENV{RELEASE_TESTING};

eval "use Test::Spelling 0.19";
plan skip_all => 'Test::Spelling 0.19 required' if $@;

add_stopwords(qw(

  SimpleCAS CAS DBIC sha MHTML Addl checksum fh filelink imglink
  mimetype deduplicates resize resized Cas refactored Filedata
  RapidApp IntelliTree Styn llc

  adm ajaxy AnnoCPAN AppDV appname ashtml atomatically attr Auth AUTH
  AuthCore AuthRequire AutoAsset AutoAssets autofield autoinc
  autosizeColumns AutosizeColumns bashrc bigtext calleruse chacter
  checkbox CMS codebases codepaths colspec ColSpec colspecs ColSpecs
  compatable conatins CoreSchema CoreSchemaAdmin curRow customizable
  customizations DataStore DataStores dbi DbicLink DbicLnk DefaultView
  defintions depricated dmap Domm dropdown dsn DSN dsns equivelent
  excelColIdxToLetter ExcelTableWriter existance exmaples extjs ExtJS
  filelinks fk FK gridadd GUIs hashnav headerFormat html HtmlEditor
  iconCls IconSet inteligent introducting inversed JS ketstroke Koki
  Kollár litte logout Maroš minChars ModuleDispatcher monotext
  MultiFilter MultiFilters multiIconCls Multple MyApp MyModule naamed
  nav navable NavCore Navicat navtree Navtree navtrees necesarily noadd
  noedit notnull nullability nullable occured param params Params
  PARAMS perlbrew Perlbrew PhpMyAdmin PLACK plaintext png PostgreSQL
  programatically ra Rapi rapidapp RapidDbic rawhtml RawHtml rdbic
  rDbic relcol relnames rels relspec renderer responder Responder
  RESTful Revdev ro RootModule sctructure seprated sortable sql Str
  stylesheets TabGui TableSpec TableSpecs TabPanel TDB tmpdir TODO
  TopController tradeoff tt typeAhead unfeature unscrolled upgr
  usererr UserError userexception validator viewport Viewport
  walkthrough webapp webapps WHEREclause workdir writeheaders
  writeHeaders writeHeadrs writePreamble writeRow xtype Zedeler zipcode

));

set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok();

done_testing();
