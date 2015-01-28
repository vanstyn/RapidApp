package RapidApp::Util::MetaKeys::Loader;

use strict;
use warnings;
use base 'DBIx::Class::Schema::Loader::DBI';
use mro 'c3';
require Module::Runtime;

use RapidApp::Include qw(sugar perlutil);

use Data::Printer;

sub new {
  my ($class, %args) = @_;
  
  my $meta_fks = exists $args{meta_fks} ? delete $args{meta_fks} : undef;
  
  my $self = $class->next::method(%args);
  $self->{_meta_fks} = $meta_fks;

  # Logic duplicated from DBIx::Class::Schema::Loader::DBI
  my $driver = $self->dbh->{Driver}->{Name};
  my $subclass = 'DBIx::Class::Schema::Loader::DBI::' . $driver;
  Module::Runtime::require_module($subclass);
  
  # Create a new, runtime class for this specific driver
  unless($self->isa($subclass)) {
    my $newclass = join('::',$class,'__FOR__',$driver);
    
    no strict 'refs';
    @{$newclass."::ISA"} = ($subclass);
    $newclass->load_components('+'.$class);
    bless $self, $newclass;
    
    $self->_rebless;
    Class::C3::reinitialize() if $] < 5.009005;
  }

  return $self;
}


sub _table_fk_info {
  my ($self, $table) = @_;
  
  my $fks = $self->next::method($table);
  
  # Here is where we can simulate fks ...
  
  

  #my $print_data = { 
  #  _table => $table->name, 
  #  fks => $fks 
  #};
  #scream_color(MAGENTA,$print_data);
    
    
  $fks
}



1;


__END__

=head1 NAME

RapidApp::Util::MetaKeys::Loader - DBIC::S::L-compatable loader_class


=head1 DESCRIPTION

...


=head1 SEE ALSO

=over

=item *

L<RapidApp::Util::MetaKeys>

=item * 

L<RapidApp>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
