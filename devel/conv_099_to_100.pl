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
  'RapidApp::DataStore2'      => 'RapidApp::Module::DatStor',
  'RapidApp::AppBase'         => 'RapidApp::Module',
  'RapidApp::AppCmp'          => 'RapidApp::Module::ExtComponent',
  'RapidApp::AppGrid2'        => 'RapidApp::Module::Grid',
  'RapidApp::DbicAppGrid3'    => 'RapidApp::Module::DbicGrid',
  'RapidApp::AppTree'         => 'RapidApp::Module::Tree',
  'RapidApp::AppNavTree'      => 'RapidApp::Module::NavTree',
  'RapidApp::AppTemplateTree' => 'RapidApp::Module::TemplateTree',
  'RapidApp::AppExplorer'     => 'RapidApp::Module::Explorer',
  'RapidApp::AppHtml'         => 'RapidApp::Module::HtmlContent',
  'RapidApp::AppDbicTree'     => 'RapidApp::Module::DbicNavTree',
  'RapidApp::DbicSchemaGrid'  => 'RapidApp::Module::DbicSchemaGrid',

  # Roles:
  'RapidApp::Role::DbicLink2'               => 'RapidApp::Module::StorCmp::Role::DbicLnk',
  'RapidApp::AppGrid2::Role::ExcelExport'   => 'RapidApp::Module::Grid::Role::ExcelExport',
  'RapidApp::Role::DataStore2::SavedSearch' => 'RapidApp::Module::StorCmp::Role::SavedSearch',

);

# longest first
my @convs = sort { length($b) <=> length($a) } keys %class_map;


my $start_dir = dir( $ARGV[0] )->resolve;

use Path::Class qw( file dir );
use Try::Tiny;
use Term::ANSIColor qw(:constants);

print "Working on $start_dir/...\n";

$start_dir->recurse(
  preorder => 1,
  callback => sub {
    my $File = shift;
    if (-f $File && $File =~ /.pm$/) {
      my @lines = $File->slurp(iomode => '<:encoding(UTF-8)');
      my @nlines = ();
      my $ch = 0;
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

