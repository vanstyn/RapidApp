package RapidApp::Template::Access;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

use Moo;

=pod

=head1 DESCRIPTION

Base class for access permissions for templates. Designed to work with
RapidApp::Template::Controller and RapidApp::Template::Provider

=cut

# The RapidApp::Template::Controller instance
has 'Controller', is => 'ro', required => 1;

# $c - localized by RapidApp::Template::Controller specifically for use 
# in this (or derived) class:
sub catalyst_context { (shift)->Controller->{_current_context} }

# Global setting - all editing turned off by default for safety:
# (this setting is queried by the Provider)
has 'writable', is => 'ro', default => sub{0};

# Global setting required to allow any read access
has 'readable', is => 'ro', default => sub{1};

# normalized function interface (pass through to coderef)
# DO NOT OVERRIDE
sub _template_writable { 
  my $self = shift;
  return $self->writable ? #<-- check global writable setting
    $self->template_writable_coderef->($self,@_) : 0;
}

# CodeRef to determine if a given template is allowed to be updated:
has 'template_writable_coderef', is => 'ro', default => sub {
  return sub {
    my $self = shift;
    # default pass-through to class method:
    return $self->template_writable(@_);
  };
};

# optional class/method function to override 
# (instead of supplying template_writable_coderef)
sub template_writable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  # Default allows all
  return 1;
}


# normalized function interface (pass through to coderef)
# DO NOT OVERRIDE
sub _template_readable { 
  my $self = shift;
  return $self->readable ? #<-- check global writable setting
    $self->template_readable_coderef->($self,@_) : 0;
}

# CodeRef to determine if a given template is allowed to be read:
has 'template_readable_coderef', is => 'ro', default => sub {
  return sub {
    my $self = shift;
    # default pass-through to class method:
    return $self->template_writable(@_);
  };
};

# optional class/method function to override 
# (instead of supplying template_writable_coderef)
sub template_readable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  # Default allows all
  return 1;
}

1;