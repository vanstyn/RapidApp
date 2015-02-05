#!/usr/bin/perl

# -- GitHub Issue #74 "Consolidate and move Module classes to RapidApp::Module::"
#    https://github.com/vanstyn/RapidApp/issues/74
#
# Preliminary/experimental script does find and replace to remap module class 
# names from v0.99* to their new names under RapidApp::Module::* for v1.0
#


use strict;
use warnings;

my %class_map = (
  'RapidApp::DataStore2'              => 'RapidApp::Module::DatStor',
  'RapidApp::AppBase'                 => 'RapidApp::Module',
  'RapidApp::AppCmp'                  => 'RapidApp::Module::ExtComponent',
  'RapidApp::AppGrid2'                => 'RapidApp::Module::Grid',
  'RapidApp::DbicAppGrid3'            => 'RapidApp::Module::DbicGrid',
  'RapidApp::AppTree'                 => 'RapidApp::Module::Tree',
  'RapidApp::AppNavTree'              => 'RapidApp::Module::NavTree',
  'RapidApp::AppTemplateTree'         => 'RapidApp::Module::TemplateTree',
  'RapidApp::AppExplorer'             => 'RapidApp::Module::Explorer',
  'RapidApp::AppHtml'                 => 'RapidApp::Module::HtmlContent',
  'RapidApp::AppDbicTree'             => 'RapidApp::Module::DbicNavTree',
  'RapidApp::DbicSchemaGrid'          => 'RapidApp::Module::DbicSchemaGrid',
  'RapidApp::AppCombo2'               => 'RapidApp::Module::Combo',
  'RapidApp::DbicAppCombo2'           => 'RapidApp::Module::DbicCombo',
  'RapidApp::AppDV'                   => 'RapidApp::Module::AppDV',
  'RapidApp::AppDV::HtmlTable'        => 'RapidApp::Module::AppDV::HtmlTable',
  'RapidApp::AppDV::RecAutoload'      => 'RapidApp::Module::AppDV::RecAutoload',
  'RapidApp::AppDV::TTController'     => 'RapidApp::Module::AppDV::TTController',
  'RapidApp::AppMimeIframe'           => 'RapidApp::Module::MimeIframe',
  'RapidApp::DbicAppPropertyPage'     => 'RapidApp::Module::DbicPropPage',
  'RapidApp::DbicTemplate'            => 'RapidApp::Module::DbicTmplPage',
  'RapidApp::AppDataStore2'           => 'RapidApp::Module::StorCmp',

  # Roles:
  'RapidApp::Role::DbicLink2'               => 'RapidApp::Module::StorCmp::Role::DbicLnk',
  'RapidApp::AppGrid2::Role::ExcelExport'   => 'RapidApp::Module::Grid::Role::ExcelExport',
  'RapidApp::Role::DataStore2::SavedSearch' => 'RapidApp::Module::StorCmp::Role::SavedSearch',
  'RapidApp::Role::DbicRowPage'             => 'RapidApp::Module::StorCmp::Role::DbicLnk::RowPg',

);

# longest first
my @convs = sort { length($b) <=> length($a) } keys %class_map;

my @pkg_skips = (@convs, qw(
  RapidApp::Role::DataStore2
  
));


my $start_dir = dir( $ARGV[0] )->resolve;

use Path::Class qw( file dir );
use Try::Tiny;
use Term::ANSIColor qw(:constants);
use List::Util;

my @skipped_pkg_files = ();

print "Working on $start_dir/...\n";

$start_dir->recurse(
  preorder => 1,
  callback => sub {
    my $File = shift;
    if (-f $File && $File =~ /\.(pm|pl|t|pod)$/) {
      my @lines = $File->slurp(iomode => '<:encoding(UTF-8)');
      my @nlines = ();
      my $ch = 0;
      my $is_pkg;
      
      # Ignore if we're dealing with one of the old packages itself
      my $is_pkg = List::Util::first { $lines[0] =~ /^package $_/ } @pkg_skips;
      
      if($is_pkg) {
        push @skipped_pkg_files, "$File";
      }
      else {
        for my $line (@lines) {
        
          $line =~ /(\r?\n)$/;
          my $nl = $1;
          $line =~ s/\r?\n$//;
          my $orig = $line;
          
          for my $old (@convs) {
            my $new = $class_map{$old};
            $line =~ s/\Q${old}\E/${new}/g;
          }
          
          unless ($line eq $orig) {
            $ch++;
            $nl = "\n";
          }
          push @nlines, $line, $nl;
        }
      }
        
      print join('','  ',$File->relative($start_dir)->stringify);
      if($ch) {
        no warnings 'uninitialized';
        $File->spew( join('',@nlines) );
        print join('',GREEN," ($ch changes)",CLEAR);
      }
      else {
        print ' (no changes)';
      }
      print "\n";
      
    }
  }
);

print "\n";

if(scalar(@skipped_pkg_files) > 0) {
  print join("\n",'',
    "Skipped Package Files (old/original classes):",
    '',
    @skipped_pkg_files,
    '',''
  );
}



