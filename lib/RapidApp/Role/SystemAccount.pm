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
			$c->delete_session('Attempt to use system account with invalid key');
			$c->response->status(401);
			return;
		}
		
		my $masqUser= $c->request->headers->header('X-SystemAccountMasqueradeAs');
		my $userObj= $c->find_user({ id => $masqUser, sysAcctAuthKey => $authKey });
		if (!defined $userObj) {
			$c->delete_session('No such user $masqUser');
			$c->response->status(401);
			return;
		}
		
		# if we have a session, is it set up correctly?  If not, delete it and start a new one.
		if ($c->session_is_valid) {
			$c->delete_session('System account cannot use existing session')
				unless $c->session->{isSystemAccount} && $c->user_exists && $c->user->id == $masqUser;
		}
		
		# else create a new session
		if (!$c->session_is_valid) {
			$c->session->{isSystemAccount}= 1;
			$c->set_authenticated($userObj);
			$c->session->{RapidApp_username}= $userObj->get("username");
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