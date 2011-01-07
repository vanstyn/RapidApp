package RapidApp::Role::SystemAccount;
use Moose::Role;

#requires 'get_session_data';
#requires 'store_session_data';
#requires 'user';
#requires 'find_user';
#requires 'persist_user';

use String::Random 'random_string';

# called once per request, to dispatch the request on a newly constructed $c object
around 'dispatch' => \&_apply_system_account_user_masquerade;

sub _apply_system_account_user_masquerade {
	my ($orig, $c, @args)= @_;
	my $authKey= $c->request->headers->header('X-SystemAccountAuthKey');
	if (defined $authKey) {
		if ($authKey ne $c->get_system_account_auth_key) {
			$c->response->status(401);
			return;
		}
		
		if (!$c->session->{isSystemAccount}) {
			$c->delete_session('System account cannot use existing session');
			$c->session->{isSystemAccount}= 1; # create a new one
		}
		
		my $masqUser= $c->request->headers->header('X-SystemAccountMasqueradeAs');
		if (defined $masqUser) {
			if (!($c->user_exists && $c->user->id == $masqUser)) {
				my $userObj= $c->find_user({ id => $masqUser, sysAcctAuthKey => $authKey });
				defined $userObj or die "No such user $masqUser";
				$c->user($userObj);
				$c->persist_user;
			}
		}
	}
	$c->$orig(@args);
};

sub get_masquerade_headers_for_user {
	my ($app, $uid)= @_;
	return {
		'X-SystemAccountAuthKey' => $app->get_system_account_auth_key,
		'X-SystemAccountMasqueradeAs' => $uid,
	};
}

after 'setup_finalize' => \&init_system_account;

sub init_system_account {
	my $app= shift;
	# Slight race condition here, on catalyst startup, but would only affect a
	#  system request being processed immediately by the very first catalyst
	#  worker thread while additional worker threads were still loading.
	if (!defined $app->get_system_account_auth_key) {
		$app->log->info("Initializing the system account auth key");
		my $key= random_string('....................');
		$app->set_system_account_auth_key($key);
	}
	else {
		$app->log->info("System account auth key is already set");
	}
}

sub get_system_account_auth_key {
	my $app= shift;
	return $app->get_session_data('global:SystemAccountAuthKey');
}

sub set_system_account_auth_key {
	my ($app, $key)= @_;
	$app->store_session_data('global:SystemAccountAuthKey', $key);
}

1;