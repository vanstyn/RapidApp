package RapidApp::TraceCapture;

use strict;
use warnings;
use DateTime;
use RapidApp::ScopedGlobals 'sEnv';
use Devel::StackTrace;
use Devel::StackTrace::AsHTML;
use IO::File;
use Try::Tiny;

sub initTraceOutputFile {
	my $fname= $ENV{TRACE_OUT_FILE} || '/tmp/RapidApp_Error_Traces';
	my $fd= IO::File->new("> $fname");
	my $now= DateTime->now;
	$fd->print("<html><body><h2>RapidApp Application started at ".$now->ymd.' '.$now->hms."</h2>\n\n");
	$fd->close;
	return $fname;
}

our $TRACE_OUT_FILE= initTraceOutputFile;
our $LAST_TRACE= undef;

sub writeQuickTrace {
	my $msg= shift;
	my $trace= shift;
	my $fd= IO::File->new(">> $TRACE_OUT_FILE");
	$fd->print("<p>Exception: $msg\n</p>\n<pre style='margin:0.2em 1em 2em 1em; font-size:10pt'>".$trace->as_string."\n</pre>\n\n\n");
	$fd->close();
}

sub writeFullTrace {
	my $msg= shift;
	my $trace= shift;
	open my $fd, '>>', $TRACE_OUT_FILE;
	$fd->print("<p>Exception: $msg\n</p><br/>\n".$trace->as_html."\n<br/><br/><br/>\n");
	close $fd;
}

sub collectTrace {
	$LAST_TRACE= Devel::StackTrace->new;
	writeQuickTrace(join(' ', @_), $LAST_TRACE);
	my $log= sEnv->get("log");
	my $msg= "Exception trace saved to $TRACE_OUT_FILE\n";
	if ($log) {
		$log->info($msg);
		$log->flush if $log->can('flush');
	} else {
		print STDERR $msg;
	}
}

sub collectTracesWithin {
	my ($code)= @_;
	
	try {
		print STDERR "Setting collector error-trap\n";
		local $SIG{__DIE__}= \&collectTrace;
		&$code;
	}
	catch {
		writeFullTrace("$_", $LAST_TRACE) if defined($LAST_TRACE);
		$LAST_TRACE= undef;
		die $_;
	};
	print STDERR (defined $LAST_TRACE? "No exceptions were fatal.\n" : "No Exceptions encountered\n");
}

END {
	writeFullTrace("Unexpected call to exit... Last trace:", $LAST_TRACE) if defined($LAST_TRACE);
}

1;
