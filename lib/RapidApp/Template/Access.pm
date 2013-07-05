package RapidApp::Template::Access;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

use Moo;
use MooX::Types::MooseLike::Base 0.23 qw(:all);

=pod

=head1 DESCRIPTION

Base class for access permissions for templates. Designed to work with
RapidApp::Template::Controller and RapidApp::Template::Provider

Provides 3 access types:

=over 4

=item * view (compiled)
=item * read (raw)
=item * write (update)

=back

=cut

# The RapidApp::Template::Controller instance
has 'Controller', is => 'ro', required => 1, isa => InstanceOf['RapidApp::Template::Controller'];

# $c - localized by RapidApp::Template::Controller specifically for use 
# in this (or derived) class:
sub catalyst_context { (shift)->Controller->{_current_context} }

# -----
# Optional *global* settings to toggle access across the board

# Normal viewing of compiled/rendered templates. It doesn't make
# much sense for this to ever be false.
has 'viewable', is => 'ro', isa => Bool, default => sub{1};

has 'readable', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  # 'read' is mainly used for updating templates. Default to off
  # unless an express read/write option has been supplied
  return (
    $self->readable_coderef ||
    $self->readable_regex ||
    $self->writable_coderef ||
    $self->writable_regex ||
    $self->writable
  ) ? 1 : 0;
}, isa => Bool;

has 'writable', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  # Defaults to off unless an express writable option is supplied:
  return (
    $self->writable_coderef ||
    $self->writable_regex
  ) ? 1 : 0;
}, isa => Bool;
# -----


# Optional CodeRef interfaces:
has 'viewable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'readable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'writable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};

# Optional Regex interfaces:
has 'viewable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'readable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'writable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};


# Compiled regexes:
has '_viewable_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->viewable_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_readable_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->readable_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_writable_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->writable_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];



# Class/method interfaces to override in derived class when additional
# calculations are needed beyond the simple, built-in options (i.e. 
# user/role based checks. Note: get '$c' via $self->catalyst_context :
sub template_viewable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'viewable',1);
}

sub template_readable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'readable',1);
}

sub template_writable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'writable',1);
}


sub _access_test {
  my ($self,$template,$perm,$default) = @_;
  
  my ($global,$regex,$code) = (
    $perm,
    '_' . $perm . '_regexp',
    $perm . '_coderef',
  );
  
   #check global setting
  return 0 unless ($self->$perm);
  
  # Check regex, if supplied:
  return 0 if (
    $self->$regex &&
    ! ($template =~ $self->$regex)
  );
  
  # defer to coderef, if supplied:
  return $self->$code->($self,$template)
    if ($self->$code);
  
  # Default:
  return $default;
}

1;