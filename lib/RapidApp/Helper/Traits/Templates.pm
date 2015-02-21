package RapidApp::Helper::Traits::Templates;
use Moose::Role;

use strict;
use warnings;

around _ra_catalyst_configs => sub {
  my ($orig,$self,@args) = @_;
  
  return (
    $self->$orig(@args),
<<END,
    # Customize the behaviors of the built-in "Template Controller" which is used
    # to serve template files application-wide. Locally defined Templates, if present,
    # are served from 'root/templates' (relative to the application home directory)
    'Controller::RapidApp::Template' => {
      # Templates ending in *.html can be accessed without the extension:
      default_template_extension => 'html',

      # Params to be supplied to the Template Access class:
      access_params => {
        # Make all template paths under site/ (root/templates/site/) editable:
        writable_regex      => '^site\/',
        creatable_regex     => '^site\/',
        deletable_regex     => '^site\/',

        ## To declare templates under site/public/ (root/templates/site/public/)
        ## to be 'external' (will render in an iframe in the TabGui):
        #external_tpl_regex  => '^site\/public\/',
      },

      ## To declare a custom template access class instead of the default (which 
      ## is RapidApp::Template::Access). The Access class is used to determine
      ## exactly what type of access is allowed for each template/user, as well as
      ## which template variables should be available when rendering each template
      ## (Note: the access_params above are still supplied to ->new() ):
      #access_class => '$self->{name}::Template::Access',

      ## To directly serve templates from the application root (/) namespace for
      ## easy, public-facing content:
      #root_template_prefix  => 'site/public/page/',
      #root_template         => 'site/public/page/home',
    },
END
);

};

1;
