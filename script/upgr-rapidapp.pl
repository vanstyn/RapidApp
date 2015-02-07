#!/usr/bin/perl
#
#  upgr-rapidapp.pl [DIR]
#
# -- GitHub Issue #74 "Consolidate and move Module classes to RapidApp::Module::"
#    https://github.com/vanstyn/RapidApp/issues/74
#
# Script will perform a recursive find/replace on a directory to make
# changes from older/known configurations to newer conventions expected
# by the current version of RapidApp
#

use strict;
use warnings;

use RapidApp::Util qw(:all);


my %class_map = (
  # Module classes:
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
  
  # Other pkg/classes:
  'RapidApp::Functions'   => 'RapidApp::Util',

);

# longest first
my @convs = sort { length($b) <=> length($a) } keys %class_map;

my @pkg_skips = (@convs, qw(
  RapidApp::Role::DataStore2
  RapidApp::Include
  RapidApp::Sugar
));


die "Must supply a start dir as argument!\n" unless ($ARGV[0]);
my $start_dir = dir( $ARGV[0] )->resolve;


use Path::Class qw( file dir );

use List::Util;

my @skipped_pkg_files = ();

print "Working on $start_dir/...\n";

$start_dir->recurse(
  preorder => 1,
  callback => sub {
    my $File = shift;
    if (-f $File && $File =~ /\.(pm|t|pod)$/) {
      my @lines = $File->slurp(iomode => '<:encoding(UTF-8)');
      my @nlines = ();
      my $ch = 0;

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
          
          # Convert to RapidApp::Util:
          if ($line =~ /^use RapidApp\:\:(Include|Sugar)/) {
            $line = 'use RapidApp::Util qw(:all);';
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


__END__

=head1 NAME

upgr-rapidapp.pl - Update codebases for latest version of RapidApp

=head1 SYNOPSIS

 upgr-rapidapp.pl /path/to/app/lib

=head1 DESCRIPTION

This script performs updates on existing code to reflect changes in the L<RapidApp> API. This can
be used to bring code written for an older version of RapidApp up to date. This primarily consists
of simple re-mapping of class names from v0.99x to their new v1.00x names, but in the future if
larger API changes are made that can be safely converted via an automated script, this is where
they will go.

Use this script at your own risk, and make sure to backup your code first!


=head1 SEE ALSO

L<RapidApp>

=head1 SUPPORT
 
IRC:
 
    Join #rapidapp on irc.perl.org.

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


