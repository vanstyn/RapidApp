#!/usr/bin/perl

# -- GitHub Issue #75 "Convert from Moose to Moo"
#    https://github.com/vanstyn/RapidApp/issues/75
#
# Preliminary/experimental script performs in-place conversions
# on RapidApp *.pm files to convert from current Moose to Moo ...
#
#
#   git checkout lib/* && devel/convert_to_moo.pl lib/
#

use strict;
use warnings;

use FindBin;
my $start_dir = dir( $ARGV[0] || "$FindBin::Bin/../lib/RapidApp/" )->resolve;

use Path::Class qw( file dir );
use Try::Tiny;
use Term::ANSIColor qw(:constants);

use Type::Parser qw( eval_type );
use Type::Registry;
 
my $reg = Type::Registry->for_me;
$reg->add_types("Types::Standard");

print "Working on $start_dir/...\n";

$start_dir->recurse(
  preorder => 1,
  callback => sub {
    my $File = shift;
    if (-f $File && $File =~ /.pm$/) {
      my @lines = $File->slurp(iomode => '<:encoding(UTF-8)');
      my @nlines = ();
      my $nl = "\n";
      my $ch = 0;
      for my $line (@lines) {
      
        $line =~ s/\r?\n$//;
        my $orig = $line;
     
        # Removals:
        $ch++ and next if (
          $line =~ /^use MooseX::MarkAsMethods/ ||
          $line =~ /^use MooseX::NonMoose/ ||
          $line =~ /^no Moose/ ||
          $line =~ /^__PACKAGE__\-\>meta\-\>make_immutable/ ||
          $line =~ /^subtype 'TableSpec'/ ||
          $line =~ /^subtype 'ColSpec'/ ||
          $line =~ /^coerce 'ColSpec'/
        );
        
        if($line =~ /^use Moose\;/) {
          $line = join("\n",
            'use Moo;',
            'use Types::Standard qw(:all);'
          );
        }
        elsif($line =~ /^use Moose::Role\;/) {
          $line = join("\n",
            'use Moo::Role;',
            'use Types::Standard qw(:all);'
          );
        }
        elsif($line =~ /^use MooseX::Traits\;/) {
          $line = 'use MooX::Traits;';
        }
        elsif($line =~ /^require MooseX::Traits\;/) {
          $line = 'require MooX::Traits;';
        }
        elsif($line =~ /^with \'MooseX::Traits\'\;/) {
          $line = 'with \'MooX::Traits\';';
        }
        
        
        # Convert types (isa => 'ArrayRef' becomes isa => ArrayRef, etc)
        if($line =~ /\s+isa\s+\=\>\s+\'([^\']+)\'/) {
          my $type = $1;
          my $new = $type;
          
          $new =~ s/(RapidApp::[\w\:]+)/InstanceOf\[\'$1\'\]/;
          
          
          if($new eq 'Maybe[TableSpec]') {
            $new = 'Maybe[InstanceOf[\'RapidApp::TableSpec\']]';
          }
          elsif($new eq 'ColSpec') {
            $new = 'InstanceOf[\'RapidApp::TableSpec::ColSpec\']';
          }
          elsif($new eq 'DBIx::Class::ResultSource') {
            $new = 'InstanceOf[\'DBIx::Class::ResultSource\']';
          }
          
          try {
            my $Type = eval_type($new,$reg);
            $new = $Type->display_name;
          }
          catch { 
          
            # TODO ...
          
            #if ($type =~ /\|/) {
            #  $new = 'AnyOf['.join(', ',split(/\|/,$type)).']';
            #}
            #elsif($type =~ /::/) {
            #  $new = "InstanceOf['$type']";
            #}
          
          };
        
          
          $line =~ s/\'\Q${type}\E\'/${new}/;
        }
        
        # Convert scalar defaults (default => 'foo' becomes default => sub {'foo'}, etc)
        if(
          $line =~ /\s+default\s+\=\>\s+(\'[^\']*\')/ || 
          $line =~ /\s+default\s+\=\>\s+(\"[^\"]*\")/ ||
          $line =~ /\s+default\s+\=\>\s+(\d+)/
        ){
          my $def = $1;
          unless ($def =~ /sub\s*\{/) {
            $line =~ s/\s+default\s+\=\>\s+\Q${def}\E/ default \=\> sub \{ ${def} \}/;
          }
        }
        
        
        unless ($line eq $orig) {
          $ch++;
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

