package RapidApp::Util::Rau::ModelUpdate;
use strict;
use warnings;

# ABSTRACT: Rau module for RapidApp::Util::RapidDbic::CfgWriter

use Moo;
extends 'RapidApp::Util::Rau';

use RapidApp::Util::RapidDbic::CfgWriter;
use Path::Class qw(file dir);

use RapidApp::Util ':all';

sub call {
  my $class = shift;
  my $path = shift || $ARGV[0];
  
  $class->usage unless ($path);
  file($path)->resolve;
  
  print "==> Processing $path ...\n";
  
  my $CfgW = RapidApp::Util::RapidDbic::CfgWriter->new({ pm_file => "$path" })
    or die "error processing pm file";
    
  $CfgW->save_to( "$path" ) or die "Error saving file";
  
  print "==> File updated.\n";
}



1;


__END__

=head1 NAME

RapidApp::Util::Rau::ModelUpdate - TableSpecs config updater script

=head1 SYNOPSIS

 rau.pl model-update [MODAL_PATH]
 
 Examples:
   rau.pl model-update MyApp/lib/Modal/DB.pm

=head1 DESCRIPTION

This module exposes L<RapidApp::Util::RapidDbic::CfgWriter> on the command-line. Expects
a path to a RapidDbic-based model (pm file) and will perform an in-place update of its
TableSpecs config section.

=head1 SEE ALSO

=over

=item * 

L<RapidApp::Util::RapidDbic::CfgWriter>

=item * 

L<rau.pl>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
