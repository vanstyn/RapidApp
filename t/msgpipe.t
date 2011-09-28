use strict;
use warnings;
use Test::More;
use Socket;
use AnyEvent;
use Try::Tiny;
use Scalar::Util 'weaken';

BEGIN { use_ok 'RapidApp::StructuredIO::Reader' }
BEGIN { use_ok 'RapidApp::StructuredIO::Writer' }
BEGIN { use_ok 'RapidApp::StructuredIO::ReaderNB' }
BEGIN { use_ok 'RapidApp::StructuredIO::WriterNB' }
BEGIN { use_ok 'RapidApp::BgTask::MsgPipe' }
BEGIN { use_ok 'RapidApp::BgTask::MsgPipeNB' }

BEGIN{ AnyEvent::detect(); }

sub simple_child_main {
	my ($in, $out)= @_;
	my $reader= RapidApp::StructuredIO::Reader->new(in => $in);
	my $writer= RapidApp::StructuredIO::Writer->new(out=>$out);
	
	while (my $msg= $reader->read) {
		last if (ref $msg eq 'HASH') && $msg->{exit};
		$writer->write($msg);
	}
	0;
}
sub simple_eventIO_child_main {
	my ($in, $out)= @_;
	my $reader= RapidApp::StructuredIO::ReaderNB->new(in => $in);
	my $writer= RapidApp::StructuredIO::WriterNB->new(out=>$out);
	
	my $cv= AE::cv;
	$reader->onData(sub {
		my $msg= shift;
		if ((ref $msg eq 'HASH') && $msg->{exit}) {
			$cv->send(1);
		} else {
			$writer->pushWrite($msg);
		}
	});
	$cv->recv;
	0;
}
sub msgpipe_child_main {
	my ($in, $out)= @_;
	my $pipe= RapidApp::BgTask::MsgPipe->new(socket => $in);
	
	while (my $msg= $pipe->recvMessage) {
		last if (ref $msg eq 'HASH') && $msg->{exit};
		$pipe->sendMessage($msg);
	}
	0;
}

sub nonblock_msgpipe_child_main {
	my ($in, $out)= @_;
	my $pipe= RapidApp::BgTask::MsgPipeNB->new(socket => $in);
	my $exit= AE::cv;
	eval 'use IO::File';
	my $target= IO::File->new();
	$pipe->rmiTargetObj( $target );
	$pipe->autoRMI( 1 );
	$pipe->onMessage( sub {
		my ($pipe, $msg)= @_;
		return $exit->send if $msg->{exit};
		$msg->{got_it}= 1;
		$pipe->pushMessage($msg);
	} );
	$exit->recv;
	0;
}

sub spawn_child_process {
	my $mainProc= shift;
	pipe my $readFromParent, my $writeToChild or die "pipe failed: $!";
	pipe my $readFromChild, my $writeToParent or die "pipe failed: $!";
	defined(my $childPid= fork) or die "fork failed $!";
	if ($childPid) {
		close $writeToParent;
		close $readFromParent;
		
		return ($childPid, $readFromChild, $writeToChild);
	} else {
		my $v= try {
			close $writeToChild;
			close $readFromChild;
			$mainProc->($readFromParent, $writeToParent);
		} catch {
			print STDERR $_."\n";
		};
		exit $v;
	}
}
sub spawn_child_process_with_socket {
	my $mainProc= shift;
	socketpair(my $s1, my $s2, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair failed: $!";
	defined(my $childPid= fork) or die "fork failed $!";
	if ($childPid) {
		close $s1;
		
		return ($childPid, $s2, $s2);
	} else {
		my $v= try {
			close $s2;
			$mainProc->($s1, $s1);
		} catch {
			print STDERR $_."\n";
		};
		exit $v;
	}
}

my $largeScalar= '0123456789';
for (my $i=0; $i<17; $i++) {
	$largeScalar.= $largeScalar;
}

sub data_samples {
	return [ 'testing', 'simple scalar' ],
		[ substr($largeScalar, 0, 1000000), 'large scalar (1000000 bytes)' ],
		[ { a => 1, b => 2, c => 3 }, 'simple hash' ],
		[ { complex => { hash => [1, 2, 3, { 5 => 6 } ], 4 => 0, undef => 12 }, a => { b => 'c' } }, 'complex hash' ],
		#[ '', 'empty string' ]
}

sub msg_samples {
	return 
		[ { a => 1, b => 2, c => 3 }, 'simple hash' ],
		[ { complex => { hash => [1, 2, 3, { 5 => 6 } ], 4 => 0, undef => 12 }, a => { b => 'c' } }, 'complex hash' ],
}

sub test_structured_io {
	my $format= shift;
	ok( my ($childPid, $in, $out)= spawn_child_process(\&simple_child_main), "spawn child" );
	isa_ok( my $reader= RapidApp::StructuredIO::Reader->new(in => $in), 'RapidApp::StructuredIO::Reader', 'create reader' );
	isa_ok( my $writer= RapidApp::StructuredIO::Writer->new(out=>$out, format => $format), 'RapidApp::StructuredIO::Writer', 'create writer' );
	
	for (data_samples()) {
		my ($sent, $descrip)= @$_;
		$writer->write($sent);
		my $got= $reader->read;
		is_deeply( $got, $sent, "round trip - $descrip");
	}
	
	$writer->write({ exit => 1 });
	ok( waitpid($childPid, 0), 'wait for child exit' );
	is( $?, 0, 'child exit status' );
	done_testing;
}

sub test_structured_event_io {
	my $format= shift;
	ok( my ($childPid, $in, $out)= spawn_child_process(\&simple_eventIO_child_main), "spawn child" );
	isa_ok( my $reader= RapidApp::StructuredIO::Reader->new(in => $in), 'RapidApp::StructuredIO::Reader', 'create reader' );
	isa_ok( my $writer= RapidApp::StructuredIO::Writer->new(out=>$out, format => $format), 'RapidApp::StructuredIO::Writer', 'create writer' );
	
	for (data_samples()) {
		my ($sent, $descrip)= @$_;
		$writer->write($sent);
		my $got= $reader->read;
		is_deeply( $got, $sent, "round trip - $descrip");
	}
	
	$writer->write({ exit => 1 });
	ok( waitpid($childPid, 0), 'wait for child exit' );
	is( $?, 0, 'child exit status' );
	done_testing;
}

sub test_msgpipe {
	ok( my ($childPid, $sock)= spawn_child_process_with_socket(\&msgpipe_child_main), "spawn child" );
	isa_ok( my $pipe= RapidApp::BgTask::MsgPipe->new(socket => $sock), 'RapidApp::BgTask::MsgPipe', 'create pipe');
	
	for (msg_samples()) {
		my ($sent, $descrip)= @$_;
		$pipe->sendMessage($sent);
		my $got= $pipe->recvMessage;
		is_deeply( $got, $sent, "round trip - $descrip");
	}
	
	my ($sent, $got);
	$sent= { ping => 1 };
	ok( $pipe->sendMessage($sent), 'wrote ping' );
	$got= $pipe->recvMessage;
	is_deeply( $got, { pong => $sent->{ping} }, 'ping reply' );
	
	$pipe->sendMessage({ exit => 1 });
	ok( waitpid($childPid, 0), 'wait for child exit' );
	is( $?, 0, 'child exit status' );
	done_testing;
}

sub test_nonblock_msgpipe {
	ok( my ($childPid, $sock)= spawn_child_process_with_socket(\&msgpipe_child_main), "spawn child" );
	isa_ok( my $pipe= RapidApp::BgTask::MsgPipeNB->new(socket => $sock), 'RapidApp::BgTask::MsgPipe', 'create pipe');
	
	my @todo= msg_samples();
	my $numTests= scalar(@todo) + 5;
	my $sent_ping= 0;
	my $cv= AE::cv;
	my $next;
	weaken( my $wpipe= $pipe );
	$next= sub {
		if (my $trial= shift @todo) {
			my ($sent, $descrip)= @$trial;
			$wpipe->pushMessage($sent);
			$wpipe->onMessage( sub { 
				my ($pipe, $got)= @_;
				is_deeply( $got, $sent, "round trip - $descrip");
				$next->();
			});
		} elsif (!$sent_ping) {
			$wpipe->pushMessage(my $sent= { ping => 12 });
			$sent_ping= 1;
			$wpipe->onMessage( sub { 
				my ($pipe, $got)= @_;
				is_deeply( $got, { pong => $sent->{ping} }, 'ping reply' );
				$next->();
			});
		} else {
			$wpipe->pushMessage({ exit => 1 });
			$cv->send;
		}
	};
	$next->();
	$cv->recv;
	
	ok( waitpid($childPid, 0), 'wait for child exit' );
	is( $?, 0, 'child exit status' );
	done_testing($numTests);
}

sub test_blocking_rmi_to_nonblock_server {
	ok( my ($childPid, $sock)= spawn_child_process_with_socket(\&nonblock_msgpipe_child_main), 'spawn child' );
	isa_ok( my $pipe= RapidApp::BgTask::MsgPipe->new(socket => $sock), 'RapidApp::BgTask::MsgPipe', 'create pipe');
	
	my $fname= '/tmp/msgpipe_testdata.tmp';
	my $calls= [
		[ 'open',  [ $fname, 'w' ], 1, 'open' ],
		[ 'print', [ 'a', 'b', "cde\n" ], 1, 'print' ],
		[ 'close', [], 1, 'close' ],
	];
	for (@$calls) {
		my ($method, $params, $expect, $descrip)= @$_;
		my $got= $pipe->callRemoteMethod($method, $params);
		is_deeply($got, $expect, $descrip);
	}

	eval 'use IO::File;';
	my $file_contents= IO::File->new("< $fname")->getline;
	is( $file_contents, "abcde\n", 'file contents of remote written file' );
	
	$pipe->sendMessage({ exit => 1 });
	ok( waitpid($childPid, 0), 'wait for child exit' );
	is( $?, 0, 'child exit status' );
	done_testing;
}

subtest 'Structured IO (storable)' => sub { test_structured_io('storable') };
subtest 'Structured IO (json)' => sub { test_structured_io('json'); };
subtest 'Blocking MsgPipe' => \&test_msgpipe;
subtest 'Structured Event-IO (storable)' => sub { test_structured_event_io('storable') };
subtest 'Structured Event-IO (json)' => sub { test_structured_event_io('json') };
subtest 'Nonblocking MsgPipe' => \&test_nonblock_msgpipe;
subtest 'Blocking calls to nonblocking server' => \&test_blocking_rmi_to_nonblock_server;

done_testing;
