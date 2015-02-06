package RapidApp::Util::MetaKeys;
use strict;
use warnings;

# ABSTRACT: External FK declarations (EXPERIMENTAL)

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw(blessed);

use RapidApp::Util::MetaKeys::FK;
use JSON::DWIW;
use Path::Class qw( file dir );
use Try::Tiny;

sub load {
  my ($self, $data) = @_;
  
  # Transparent passthrough when supplied an already 
  # constructed MetaKeys object
  return $data if (
    blessed($data) &&
    $data->isa(__PACKAGE__)
  );
  
  my $can_be_file = ! (
    ref($data) ||
    length($data) > 1024 ||
    $data =~ /\n/
  );

  unless (ref $data) {
    $data = $can_be_file && -f file($data)
      ? $self->data_from_file($data)
      : $self->data_from_string($data)
  }
  
  $self->new({ data => $data });
}


sub data_from_file {
  my $self = shift;
  my $File = file(shift)->resolve;
  
  # Common-sense size check/limit
  die "File '$File' too big - probably not the right file" if ($File->stat->size > 65536);
  
  $self->data_from_string( scalar $File->slurp )
}

sub data_from_string {
  my ($self, $string) = @_;
  
  my $data = scalar(
    # Assume JSON as the first format
    try{ JSON::DWIW->from_json($string) } ||
    
    # free-form key/value text fallback
    try{ $self->parse_key_vals($string) }
    
    # Parse from other possible formats
    # ...
  );


  die "Failed to parse data from string using any support formats" unless ($data);

  $data
}

sub parse_key_vals {
  my ($self, $string) = @_;
  
  my @data = ();
  for my $line (split(/\r?\n/,$string)) {
  
    # Handle/strip comments:
    if($line =~ /\#/) {
      my ($active,$comment) = split(/\s*\#/,$line,2);
      $line = $active;
    }

    # strip leading/trailing whitespace
    $line =~ s/^\s+//; $line =~ s/\s+$//;
    
    # Ignore commas at the end of the line:
    $line =~ s/\s*\,\s*$//;
  
    # Ignore blank/empty lines:
    next if (!$line || $line eq '');
    
    # Split on a variety of delim chars/sequences:
    my @parts = split(/\s*[\s\=\:\,\>\/\|]+\s*/,$line);
    
    unless (scalar(@parts) == 2) {
      warn "Bad key/val format - expected exactly one key and one value - got: (".join('|',@parts);
      return undef;
    }
    
    push @data, \@parts;
  }
  
  return \@data
}


has 'data', is => 'ro', isa => ArrayRef[
  InstanceOf['RapidApp::Util::MetaKeys::FK']
], required => 1, coerce => \&_coerce_data;

has '_table_ndx', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $ndx = {};
  for my $FK (@{ $self->data }) {
    push @{ $ndx
      ->{ $FK->schema || '' }
      ->{ $FK->table }
    }, $FK
  }
  
  $ndx

}, init_arg => undef, isa => HashRef;

sub table_fks {
  my ($self, $table, $schema) = @_;
  $schema //= '';
  
  $self->_table_ndx->{$schema}{$table} || undef
}


sub _coerce_data {
  my $data = $_[0];
  
  return $data if blessed($data);
  
  if(my $ref_type = ref($data)) {
    if($ref_type eq 'ARRAY') {
    
      $data = [ map {
        my $itm = $_;
        
        if(ref($itm) && ! blessed($itm)) {
          if(ref($itm) eq 'ARRAY') {
            die join(' ',
              "Bad fk definition - must be ArrayRef with 2 elements:",
              Dumper($_)
            ) unless (scalar(@$_) == 2);
            
            $itm = RapidApp::Util::MetaKeys::FK->new({
              lhs => &_coerce_element($_->[0]), 
              rhs => &_coerce_element($_->[1])
            })
          }
          elsif(ref($itm) eq 'HASH') {
            $itm = RapidApp::Util::MetaKeys::FK->new($itm)
          }
        }
        
        $itm
      } @$data ]
    }
    elsif ($ref_type eq 'HASH') {
      die "coerce HashRef TODO...";
    
    }
  }

  $data
}

sub _coerce_element {
  my $el = $_[0];
  
  unless (ref $el) {
    my $new = {};
    my @parts = split(/\./,$el);
    die "Failed to parse/coerce element '$el'" unless (
      scalar(@parts) == 2 ||
      scalar(@parts) == 3
    );
    
    $new->{column} = pop(@parts) or die "Failed to parse/coerce element '$el'";
    $new->{table}  = pop(@parts) or die "Failed to parse/coerce element '$el'";
    $new->{schema} = $parts[0] if (scalar(@parts) > 0);
    
    return $new;
  }
  
  die "Bad element - must be a dot(.) delimited string or a HashRef" unless (ref($el) eq 'HASH');
  
  $el->{column} or die "Bad element - 'column' key missing: " . Dumper($el);
  $el->{table}  or die "Bad element - 'table' key missing: "  . Dumper($el);
  
  $el
}


1;


__END__

=head1 NAME

RapidApp::Util::MetaKeys - External FK declarations (EXPERIMENTAL)

=head1 SYNOPSIS

 use RapidApp::Util::MetaKeys;


=head1 DESCRIPTION

Experimental external definitions of foreign keys


=head1 METHODS

=head2 new

Create a new RapidApp::Util::MetaKeys instance. The following build options are supported:

=over 4

=item file

Path to ...

=back


=head1 SEE ALSO

=over

=item *

L<DBIx::Class>

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
