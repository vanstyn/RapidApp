package RapidApp::Util::MetaKeys::FK;
use strict;
use warnings;


use Moo;
use Types::Standard qw(:all);


# Aliases:
sub local_column { (shift)->column(@_) }
sub local_table  { (shift)->table(@_)  }
sub local_schema { (shift)->schema(@_) }

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift;
  my $args = $_[0];

  if(ref($args) && ref($args) eq 'HASH') {
    my @locs = qw(local_column local_table local_schema);
    my %locs = map {$_=>1} @locs;
    return $class->$orig({ map {
      $_ =~ s/^local_// if ($locs{$_});
      ( $_ => $args->{$_} )
    } keys %$args })
  }
  else {
    return $class->$orig(@_)
  }
};


has 'lhs', is => 'ro', isa => Maybe[HashRef], default => sub { undef };
has 'rhs', is => 'ro', isa => Maybe[HashRef], default => sub { undef };

has 'column', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  my $lhs = $self->lhs or die "Either 'column' or 'lhs' must be supplied";
  $lhs->{column}
};

has 'table', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  my $lhs = $self->lhs or die "Either 'table' or 'lhs' must be supplied";
  $lhs->{table}
};

has 'schema', is => 'ro', isa => Maybe[Str], lazy => 1, default => sub {
  my $self = shift;
  my $lhs = $self->lhs or return undef;
  $lhs->{schema}
};




has 'remote_column', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  my $rhs = $self->rhs or die "Either 'remote_column' or 'rhs' must be supplied";
  $rhs->{column}
};

has 'remote_table', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  my $rhs = $self->rhs or die "Either 'remote_table' or 'rhs' must be supplied";
  $rhs->{table}
};

has 'remote_schema', is => 'ro', isa => Maybe[Str], lazy => 1, default => sub {
  my $self = shift;
  my $rhs = $self->rhs or return undef;
  $rhs->{schema}
};



1;


__END__

=head1 NAME

RapidApp::Util::MetaKeys::FK - External FK declarations, fk obj (EXPERIMENTAL)


=head1 DESCRIPTION

Experimental external definitions of foreign keys. Used internally by L<RapidApp::Util::MetaKeys>


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
