package RapidApp::BgTask::TaskPool;
use strict;
use warnings;
use Params::Validate ':all';
use Storable 'freeze', 'thaw';
use Try::Tiny;
use RapidApp::Debug 'DEBUG';
use IO::File;
use RapidApp::BgTask::Task;
use RapidApp::BgTask::Supervisor;

=head1 NAME

RapidApp::BgTask::TaskPool

=head1 SYNOPSIS

  my $pool= RapidApp::BgTask::TaskPool->new( path => '/tmp/foo', mkdirIfMissing => [ 0755, undef, undef ] );
  my $task= $pool->spawn(cmd => 'while sleep 1; do date; done', lockfile => '/tmp/countdate.lock', meta => { name => 'foo' });
  print Dumper($task->info);
  
  my @tasks= $pool->search( { meta => { name => 'foo' } } );
  $_->kill('INT') for @tasks;
  sleep 1;
  $_->terminate_supervisor() for @tasks;

=head1 DESCRIPTION

Organizes a group of tasks via a directory, providing methods to search existing tasks
and create new ones.

TaskPool is really nothing more than a view of a directory, and methods to search
and create tasks.

=head1 ATTRIBUTES

=head2 path

Base directory for a pool of jobs.  The directory must be writeable by users wishing
to create jobs, and readable by users withing to interact with existing jobs.
-or- the directory must be readable or writeable by the set-gid feature of the
specified supervisorScript.

=head2 sockdir

The directory where job supervisor sockets are created.  Currently the same as "path"
of the task pool.

=cut

sub path {
	return (shift)->{path};
}
sub sockdir {
	return (shift)->{path};
}

=head1 METHODS

=head2 outputPath( $pid ||= $$ )

The path and filename of the file the given supervisor process will use for its STDOUT.

=cut
sub outputPath {
	my ($self, $pid)= @_;
	$pid ||= $$;
	return $self->sockdir."/$pid.out";
}

=head2 socketPath( $pid ||= $$ )

The path and filename of the unix socket the given supervisor will listen on.

=cut
sub socketPath {
	my ($self, $pid)= @_;
	$pid ||= $$;
	return $self->sockdir."/$pid.sock";
}

=head2 $args = $pool->supervisorCmd( \@execParams )

Get or set the array of arguments that will be passed to exec to start the supervisor

=cut
sub supervisorCmd {
	my $self= shift;
	if (@_) {
		ref($_[0]) eq 'ARRAY' or die "Expected array of exec arguments";
		$self->{supervisorCmd}= $_[0];
	}
	return $self->{supervisorCmd} ||= [ 'perl', '-e', 'use RapidApp::BgTask::Supervisor; RapidApp::BgTask::Supervisor->script_main' ];
}

=head2 $envHash= $pool->supervisorEnv( \%envHash )

Get or set the environment variables for the supervisor.

Beware that setting this will voerwrite the defaults of PERLLIB and BGTASK_TASKPOOL_PATH,
which are important to the implementation of the default supervisor.

Consider using ->applySupervisorEnv to merge in additional values.

=cut
sub supervisorEnv {
	my $self= shift;
	if (@_) {
		ref($_[0]) eq 'HASH' or die "Expected hashref of environment vars";
		$self->{supervisorEnv}= $_[0];
	}
	return $self->{supervisorEnv} || {
		PERLLIB => join(':',@INC), # preserve perl include path
		BGTASK_TASKPOOL_PATH => $self->path,
	};
}

=head2 $envHash= $pool->applySupervisorEnv( key => $value, ... )

Apply new environment variables to the environment hash for the supervisor process

=cut
sub applySupervisorEnv {
	my $self= shift;
	my $newEnv= ref($_[0])? $_[0] : { @_ };
	use Hash::Merge;
	$self->{supervisorEnv}= Hash::Merge::merge($self->supervisorEnv, $newEnv);
}

=head2 $cls= $pool->taskClass( $newClassName )

Get or set the class name used to represent tasks.

This class should have a constructor of the form
  $class->new($pool, $pid);

=cut
sub taskClass {
	my $self= shift;
	if (@_) {
		$self->{taskClass}= $_[0];
	}
	return $self->{taskClass} || 'RapidApp::BgTask::Task';
}

=head2 $pool= $class->new( %params );

Create a new task pool.

Required parameters:
 * path => $scalar || Path::Class::Dir
Optional parameters:
 * mkdirIfMissing => [ $mode, $uid, $gid ]
 * supervisorCmd  => \@execArgs
 * supervisorEnv  => \%envOverrides
=cut
sub new {
	my $class= shift;
	my %p= validate(@_, {
		path => 1,
		supervisorCmd => 0,
		supervisorEnv => 0,
		taskClass => 0,
		mkdirIfMissing => { type=>ARRAYREF, optional=>1 }},
	);
	my $mkdirOpts= delete $p{mkdirIfMissing};
	if (!-d $p{path}) {
		if ($mkdirOpts) {
			$class->_createSockDir($p{path}, @$mkdirOpts);
		} else {
			die "$p{path} does not exist.  Either create it, or specify the mkdirIfMissing argument.";
		}
	}
	return bless \%p, $class;
}

sub _createSockDir {
	my ($class, $path, $mode, $uid, $gid)= @_;
	my $d;
	for (split('/', $path)) {
		$d= defined($d)? $d . '/' . $_ : $_;
		if (length $d && !-d $d) {
			mkdir $d or die "While creating $d: $!";
		}
	}
	defined $mode
		and chmod($mode, $path) || die "Failed to set proper permissions on $path: $!";
	defined $uid && defined $gid
		and chown($uid,$gid,$path) || die "Failed to set proper permissions on $path: $!";
}


=head2 $task= $pool->spawn( %params );

This method creates a new background task, using the supplied parameters.
It returns a controller for the new process, which can be used to construct RapidApp::BgTask::Control objects.

Supported parameters:
 * cmd  => $scalar          - the string which should be passed to the shell
 * exec => [ $prog, @args ] - an array of parameters which will be passed to the exec() syscall
 * env  => %environment     - a hash of environment variables to set for the child
 * behavior =>  foreground: run as a plain console program.
				background: redirect stdout and stderr to a file, and double-fork to kill parent and be owned by init, but still exit with current process group.
				daemon:     same as background, but also start a new session to disassociate with the caller's process group.
 * meta => %freeForm        - a hash of free-form metadata to be associated with the process
 * maxReadBufSize => $int   - the maximum bytes of the job's output which will be held for client requests
 * lockfile => $filename    - path of a file which must be able to be locked, or the job exits

=cut
sub spawn {
	my $self= shift;
	my %p= validate(@_, {
		cmd            => { type => SCALAR,   optional => 1 },
		exec           => { type => ARRAYREF, optional => 1 },
		env            => { type => HASHREF,  optional => 1 },
		behavior       => { type => SCALAR,   optional => 1 },
		meta           => { type => HASHREF,  optional => 1 },
		maxReadBufSize => { type => SCALAR,   optional => 1 },
		lockfile       => { type => SCALAR,   optional => 1 },
	});
	$p{cmd} || $p{exec} or die "Require one of 'cmd' or 'exec'";
	
	# use {exec} instead of {cmd}
	$p{exec} ||= [ 'sh', '-c', $p{cmd} ];
	delete $p{cmd};
	
	# default behavior is "background"
	$p{behavior} ||= 'background';
	
	# Serialize the parameters
	my $serializedParams= freeze \%p;
	if ($ENV{DEBUG_BGTASK}) { IO::File->new("> /tmp/bgtask_serialized_params.sto")->print($serializedParams); }
	
	# start the supervisor
	my ($pid, $childIn, $childOut, $childErr)= System::Command->spawn(
		@{ $self->supervisorCmd },
		{ env => $self->supervisorEnv }
		#	input => $serializedParams,
	);
	defined $pid
		or die "Failed to start ".join(' ',@{ $self->supervisorCmd });
	
	# The child is now running.  It redirects STDOUT, so we don't bother watching it.
	close $childOut;
	
	# give the supervisor its parameters
	my $wrote= $childIn->syswrite( $serializedParams );
	DEBUG(bgtask => "wrote=$wrote");
	close $childIn;
	
	if ($wrote ne length($serializedParams)) {
		close $childErr;
		kill KILL => $pid;
		waitpid($pid, 0);
		die "Failed to write params: wrote = $wrote, errno = $!";
	}
	
	if ($p{behavior} ne 'foreground') {
		# The child daemonizes after receiving its parameters.
		# We reap the temporary process.
		DEBUG(bgtask => "# collecting intermediate child $pid");
		waitpid($pid, 0)
	}
	
	# This will wait until the supervisor either dies, or starts successfully
	my @response= <$childErr>;
	close $childErr;
	
	if ($ENV{DEBUG_BGTASK}) {
		DEBUG(bgtask => "response=\n\t".join("\t",@response));
	}
	
	if (scalar @response and $response[-1] =~ /DAEMON_PID=([0-9]+)\n/) {
		return $self->taskClass->new($self, $1);
	} else {
		chomp(@response);
		die "Task supervisor failed: \n\t".join("\t",@response);
	}
}

=head2 @tasks= $pool->search( %infoPattern | sub {$bool} );

This method searches for an existing background task.  Every task has a hash called "info".
The pattern specifies keys and values that should exist in the desired task's info hash.

Note that the anonymous sub that you pass will be "evaled", so you are free to use
code that will die on missing info keys.  The anonymous sub will be given the info
hash as the first and only parameter.

Example:
  Proc1: info => { a => 1, meta => { name => 'CoolProgram' }, c => [ 1, 2, 3 ] }
  Proc2: info => { a => 5, b => 5, c => 5 }
  
  BgTask->search( { meta => { name => 'CoolProgram' } } );       # returns Proc1
  BgTask->search( sub { (shift)->{meta}{name} eq 'CoolProgram' ) # returns Proc1
  BgTask->search( sub { (shift)->{c}[0] == 1 } ); # returns Proc1

=cut
sub search {
	my $self= shift;
	my $pattern= scalar(@_) > 1? { @_ } : $_[0];
	
	my $sockdir= $self->sockdir;
	my @sockets= <$sockdir/*.sock>;
	#print Dumper(@sockets)."\n";
	
	my @result;
	for my $sock (@sockets) {
		$sock =~ /[^0-9]*([0-9]+).sock/ or next;
		my $pid= $1 or next;
		unless (kill 0, $pid) { unlink($sock); next; }
		my $task= $self->taskClass->new($self, $pid);
		if ($pattern) {
			my $info;
			try { $info= $task->info } catch { warn "Can't connect to bgtask $pid: $_" };
			next unless $info;
			if (ref($pattern) eq 'CODE') {
				next unless try { $pattern->($info) };
			} else {
				next unless _hashCheck($info, $pattern);
			}
		}
		push @result, $task;
	}
	return @result;
}

=head2 $pool->taskByPid($pid)

Returns a task object for the specified pid, if that pid is a supervisor process
and listening on its socket.  Returns undef if the process doesn't exist or
isn't listening.

=cut
sub taskByPid {
	my ($self, $pid)= @_;
	my $sockFname= $self->socketPath($pid);
	-e $sockFname or return undef;
	unless (kill 0, $pid) { unlink($sockFname); return undef; }
	return $self->taskClass->new($self, $pid);
}

sub _hashCheck {
	my ($node, $pattern)= @_;
	return 1 if !defined($node) && !defined($pattern);
	return 0 unless defined($node) && defined($pattern);
	return 0 unless ref($node) eq ref($pattern);
	if (ref($pattern) eq 'HASH') {
		for (keys %$pattern) {
			return 0 unless exists($node->{$_}) && _hashCheck($node->{$_}, $pattern->{$_});
		}
	} elsif (ref($pattern) eq 'ARRAY') {
		return 0 unless scalar(@$pattern) eq scalar(@$node);
		for (my $i= 0; $i < $#$pattern; $i++) {
			return 0 unless _hashCheck($pattern->[$i], $node->[$i]);
		}
	} elsif (!ref $pattern) {
		return 0 unless $pattern eq $node;
	} else {
		die "Unsupported reftype in pattern match: ".ref($pattern);
	}
	return 1;
}

1;