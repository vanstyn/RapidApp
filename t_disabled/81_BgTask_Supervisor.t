#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use Socket;
use AnyEvent;
use Try::Tiny;
use POSIX ":sys_wait_h";
use Storable "freeze";

BEGIN { use_ok 'RapidApp::BgTask::TaskPool' }
BEGIN { use_ok 'RapidApp::BgTask::Supervisor' }

my $taskPool;
sub create_task_pool {
	my $dir= "/tmp/bgtask_supervisor_test";
	
	if (-d $dir) {
		try {
			$taskPool= RapidApp::BgTask::TaskPool->new(path => $dir);
			my @tasks= $taskPool->search();
			for (@tasks) { try { $_->terminate_supervisor }; }
		};
		unlink $_ or die $! for <$dir/*>;
		rmdir $dir or die $!;
	}
	
	isa_ok( $taskPool= RapidApp::BgTask::TaskPool->new(path => $dir, mkdirIfMissing => [0705, undef, undef]), 'RapidApp::BgTask::TaskPool' );
	is( $taskPool->sockdir, $dir, 'sockdir' );
	ok( -d $taskPool->sockdir, 'sockdir was created' );
	is( (stat($dir))[2] & 07777, 0705, 'sockdir permissions' );
	done_testing;
}

sub basic_functionality_test {
	my $inFname= $taskPool->sockdir.'/input';
	{ my $f= IO::File->new($inFname, 'w');
		$f->binmode;
		$f->print( freeze( { exec => [ "/usr/bin/cat" ], meta => { name => "Hello World" }, behavior => 'foreground' } ) );
		$f->close();
	}
	defined (my $pid= fork) or die "fork: $!";
	if ($pid == 0) {
		$ENV{BGTASK_TASKPOOL_PATH}= $taskPool->path;
		my $cmd= join(' ', map { "'".$_."'" } @{$taskPool->supervisorCmd})." < $inFname";
		diag "exec $cmd";
		exec 'sh', '-c', 'exec '.$cmd;
	}
	
	sleep 1;
	my @tasks= $taskPool->search();
	is( scalar(@tasks), 1, 'create one supervisor' );
	if (scalar(@tasks > 1)) {
		kill 9, ( map { $_->pid } @tasks ); # remedial action
	}
	
	is( $tasks[0]->pid, $pid, 'correct pid' );
	if ($tasks[0]->pid ne $pid) {
		kill 9, ( $tasks[0]->pid, $pid ); # remedial action
	}
	
	kill TERM => $pid;
	ok_exited($pid, 'supervisor exited');
	
	waitpid($pid, 0);
}

sub start_stop {
	isa_ok( my $task= $taskPool->spawn(cmd => 'cat /etc/fstab'), 'RapidApp::BgTask::Task', 'create task' );
	$task->info;
	is( $task->terminate_supervisor(), 1, 'terminate function succeeded');
	$task->disconnect;
	ok_exited($task->pid, 'supervisor exited');
	
	$task= undef;
	done_testing;
}

sub ok_exited {
	my ($pid, $description)= @_;
	for (my $i= 0; $i < 10; $i++) {
		last if waitpid($pid, WNOHANG) > 0;
		sleep(1);
	}
	my $died= !kill(0, $pid);
	ok($died, $description);
	kill(9, $pid) unless $died;
}

subtest 'Create Task Pool' => \&create_task_pool;
subtest 'Launch supervisor process' => \&basic_functionality_test;
subtest 'Start/Stop Supervisor' => \&start_stop;

done_testing;
