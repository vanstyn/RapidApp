use strict;
use warnings;
use Test::More;
use Socket;
use AnyEvent;
use Try::Tiny;
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
	push @{ $taskPool->supervisorCmd }, '--', '-f'; # stay in foreground
	done_testing;
}

sub basic_functionality_test {
	my $inFname= $taskPool->sockdir.'/input';
	{ my $f= IO::File->new($inFname, 'w');
		$f->binmode;
		$f->print( freeze( { exec => [ "/usr/bin/cat" ], meta => { name => "Hello World" } } ) );
		$f->close();
	}
	if (fork == 0) {
		$ENV{BGTASK_TASKPOOL_PATH}= $taskPool->path;
		my $cmd= join(' ', map { "'".$_."'" } @{$taskPool->supervisorCmd})." < $inFname";
		diag "exec $cmd";
		exec 'sh', '-c', $cmd;
	}
	
	sleep 1;
	my @tasks= $taskPool->search();
	is( scalar(@tasks), 1, 'successfully created one supervisor' );
	try { $tasks[0]->terminate_supervisor };
}

sub start_stop {
	isa_ok( my $task= $taskPool->spawn(cmd => 'cat /etc/fstab'), 'RapidApp::BgTask::Task', 'create task' );
	$task->info;
	is( $task->terminate_supervisor(), 1, 'terminate succeeded');
	$task->disconnect;
	$task= undef;
	done_testing;
}

subtest 'Create Task Pool' => \&create_task_pool;
subtest 'Launch supervisor process' => \&basic_functionality_test;
subtest 'Start/Stop Supervisor' => \&start_stop;

done_testing;
