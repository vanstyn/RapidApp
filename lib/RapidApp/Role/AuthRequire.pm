package RapidApp::Role::AuthRequire;

use Moose::Role;

requires 'c';
requires 'Controller';
requires 'render_data';
requires 'content';
#with 'RapidApp::Role::Controller';

use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';


has 'non_auth_content' => ( is => 'rw', default => '' );
has 'auto_prompt'      => ( is => 'rw', default => 0 );
has 'auth_module_path' => ( is => 'rw', default => undef );


around 'Controller' => sub {
	my $orig = shift;
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	#$self->c->res->status(205);
	
	unless ($self->c->session_is_valid and $self->c->user_exists) {
		$self->c->res->header('X-RapidApp-Authenticated' => 0);
		
		if ($self->auto_prompt && $self->c->stash->{requestContentType} ne 'JSON') {
			my $authPath= $self->auth_module_path;
			my $authModule;
			defined $authPath && length($authPath) > 1 && ($authModule= $c->rapidApp->module($authPath))
				or die "Misconfigured auth_module_path";
			return $authModule->viewport;
		}
		
		return $self->render_data($self->non_auth_content);
	}
	
	$self->c->res->header('X-RapidApp-Authenticated' => $self->c->user->get('username'));
	return $self->$orig(@_);
};

1;