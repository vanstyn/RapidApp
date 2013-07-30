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

has 'creatable', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  # Defaults to off unless an express writable option is supplied:
  return (
    $self->creatable_coderef ||
    $self->creatable_regex
  ) ? 1 : 0;
}, isa => Bool;

has 'deletable', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  # Defaults to off unless an express deletable option is supplied:
  return (
    $self->deletable_coderef ||
    $self->deletable_regex
  ) ? 1 : 0;
}, isa => Bool;

# By default, all templates are considered 'admin' templates. Admin templates
# are templates which are provided with admin template vars (most notably, [% c %])
# when they are rendered. It is very important that only admins have access to
# write to admin templates because only admins should be able to access the
# Catalyst CONTEXT object $c. It is safe to allow all templates to be admin
# templates as long as there is no write access provided (which is the default)
#  TODO: consider defaulting admin_tpl off when any create/write options are
#  enabled...
has 'admin_tpl', is => 'ro', isa => Bool, default => sub{1};


# By default, all templates are considered 'admin' templates... option to specify
# via exclude rather than include. For example, to safely provide editable templates
# to non-admin or anonymous users you might specify these options together:
#
#   writable_regex      => '^wiki',
#   creatable_regex     => '^wiki',
#   non_admin_tpl_regex => '^wiki',
#
has 'non_admin_tpl', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  # Defaults to off unless an express non_admin_tpl option is supplied:
  return (
    $self->non_admin_tpl_coderef ||
    $self->non_admin_tpl_regex
  ) ? 1 : 0;
}, isa => Bool;
# -----


# 'External' templates are those designed to be viewed outside of RapidApp and
# are by default publically accessible (i.e. don't require a logged-in session)
# These templates cannot be safely viewed within the context of the RapidApp
# styles, even when wrapped with 'ra-scoped-reset', and thus must be viewed
# in an iframe tab when viewed within the RapidApp/ExtJS interface
has 'external_tpl', is => 'ro', lazy => 1, default => sub {
  my $self = shift;

  # Defaults to off unless an express external_tpl option is supplied:
  return (
    $self->external_tpl_coderef ||
    $self->external_tpl_regex
  ) ? 1 : 0;
}, isa => Bool;


# Optional CodeRef interfaces:
has 'get_template_vars_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'get_template_format_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};

# common handling for specific bool 'permissions':
has 'viewable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'readable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'writable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'creatable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'deletable_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'admin_tpl_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'non_admin_tpl_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};
has 'external_tpl_coderef', is => 'ro', isa => Maybe[CodeRef], default => sub {undef};

# Optional Regex interfaces:
has 'viewable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'readable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'writable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'creatable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'deletable_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'admin_tpl_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'non_admin_tpl_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};
has 'external_tpl_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};


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

has '_creatable_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->creatable_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_deletable_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->deletable_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_admin_tpl_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->admin_tpl_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_non_admin_tpl_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->non_admin_tpl_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

has '_external_tpl_regexp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $str = $self->external_tpl_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];

# Class/method interfaces to override in derived class when additional
# calculations are needed beyond the simple, built-in options (i.e. 
# user/role based checks. Note: get '$c' via $self->catalyst_context :

# NOTE: if non-admins are granted access to write templates in a production
# system a custom get_template_vars should be supplied because the default
# provides full access to the Catalyst Context object ($c) - or, the supplied
# 'admin_tpl' or 'non_admin_tpl' permissions need to be configured accordingly
sub get_template_vars {
  my ($self,@args) = @_;
  
  # Note that the default get_template_vars() doesn't care about the 
  # template (all of them get the same vars) but the API accpets the
  # template as an arg so derived classes can apply template-specific
  # rules/permissions to the vars supplied to the template
  my $template = join('/',@args);
  
  # defer to coderef, if supplied:
  return $self->get_template_vars_coderef->($self,$template)
    if ($self->get_template_vars_coderef);
  
  return $self->template_admin_tpl($template)
    ? $self->_get_admin_template_vars($template)
    : $self->_get_default_template_vars($template);
}

sub _get_default_template_vars {
  my ($self, $template) = @_;
  my $c = $self->catalyst_context;
  my $Provider = $self->Controller->get_Provider;
  my $vars = {};
  $vars = {
    # TODO: figure out what other variables would be safe to provide to
    # non-admin templates
    template_name => $template,
    rapidapp_version => $RapidApp::VERSION,
    
    list_templates => sub { $Provider->list_templates(@_) },
    
    # Return the url for the supplied template, 
    # relative to the current request action:
    template_url => sub { 
      my $tpl = shift;
      return join('','/',$c->req->action,"/$tpl");
    },
    
    template_link => sub {
      my $tpl = shift;
      my $url = $vars->{template_url}->($tpl);
      return join('','<a href="#!',$url,'">',$tpl,'</a>');
    }
  };
  
  return $vars;
}

# Admin templates get access to the context object. Only admin users
# should be able to write admin templates for obvious reasons
sub _get_admin_template_vars {
  my $self = shift;
  return {
    %{ $self->_get_default_template_vars(@_) },
    c => $self->catalyst_context,
  };  
}




# Simple bool permission methods:

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

sub template_creatable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'creatable',1);
}

sub template_deletable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'deletable',1);
}

sub template_admin_tpl {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->template_non_admin_tpl($template)
    ? 0 : $self->_access_test($template,'admin_tpl',1);
}

sub template_non_admin_tpl {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'non_admin_tpl',1);
}

sub template_external_tpl {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  return $self->_access_test($template,'external_tpl',1);
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


# New: returns a format string to be included in the template metadata
sub get_template_format {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  # defer to coderef, if supplied:
  return $self->get_template_format_coderef->($self,$template)
    if ($self->get_template_format_coderef);
  
  # By default we treat any *.md templates as markdown
  return 'markdown' if ($template =~ /\.md$/i);
  
  # TODO: add other formats here ...
  
  # The default format should always be 'html':
  return 'html';
}



1;