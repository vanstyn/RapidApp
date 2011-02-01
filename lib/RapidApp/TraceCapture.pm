package RapidApp::TraceCapture;

use strict;
use warnings;
use DateTime;
use RapidApp::ScopedGlobals 'sEnv';
use Devel::StackTrace;
use Devel::StackTrace::AsHTML;
use IO::File;
use Try::Tiny;
use Scalar::Util 'weaken';

=head1 NAME

RapidApp::TraceCapture

=head1 DESCRIPTION

This module contains a number of useful functions for capturing stack traces.

The writeQuickTrace and writeFullTrace functions send their output to the file specified by
the environment variable TRACE_OUT_FILE, or default to /tmp/RapidApp_Error_Traces if unset.

=head1 SYNOPSIS

  try {
    local $SIG{__DIE__}= \&RapidApp::TraceCapture::captureTrace;
    
    # do stuff
    do->stuff();
    
    # clear any stack traces we might have picked up, since none were fatal
    RapidApp::TraceCapture::collectTraces;
  }
  catch {
    my $err= $_;
    my @traces= RapidApp::TraceCapture::collectTraces;
    for my $trace (@traces) {
      RapidApp::TraceCapture::writeFullTrace($trace);
    }
  };


=cut

sub initTraceOutputFile {
	my $fname= $ENV{TRACE_OUT_FILE} || '/tmp/RapidApp_Error_Traces';
	my $fd= IO::File->new("> $fname");
	my $now= DateTime->now;
	$fd->print("<html><body><h2>RapidApp Application started at ".$now->ymd.' '.$now->hms."</h2>\n\n");
	$fd->close;
	return $fname;
}

our $TRACE_OUT_FILE= initTraceOutputFile;
our @TRACES= ();
our $LAST_THROWN_OBJ_STR;

sub emitMessage {
	my $msg= shift;
	my $log= sEnv->get("log");
	if ($log) {
		$log->info($msg);
		$log->flush if $log->can('flush');
	} else {
		STDERR->print($msg."\n");
		STDERR->flush();
	}
}

sub writeQuickTrace {
	my $trace= shift || Devel::StackTrace->new;
	try {
		my $fd= IO::File->new(">> $TRACE_OUT_FILE");
		my @frames= $trace->frames;
		$fd->print("<div style='margin:0.2em 1em 2em 1em; font-size:10pt'>\n");
		for my $frame (@frames) {
			my $fname= $frame->filename;
			$fname =~ s|.*?/lib/perl[^/]+/([^A-Z][^/]*/)*||;
			$fname =~ s|.*?/lib/||;
			my $loc= sprintf('<font color="blue">%s</font> line <font color="blue">%d</font>', $fname, $frame->line);
			
			my $call= sprintf('<b>%s</b>', $frame->subroutine);
			my $args= '<span style="font-size: 8pt">'.join('<br />', map { defined $_? $_ : "<undef>" } $frame->args).'</span>';
			#$call =~ s/([^ ]+)=HASH[^ ,]+/\\%$1/g;
			
			$fd->print("<div> $loc <table style='padding-left:2em'><tr><td valign='top'>$call".'&nbsp;'."(</td><td> $args </td></tr></table></div>\n");
		}
		$fd->print("\n</div><hr width='70%' />\n\n\n");
		$fd->close();
	}
	catch {
		emitMessage "Error while saving trace: $_";
	};
}

sub writeFullTrace {
	my $trace= shift || Devel::StackTrace->new;
	try {
		my $fd= IO::File->new(">> $TRACE_OUT_FILE");
		$fd->print($trace->as_html."\n<br/><br/><br/>\n");
		$fd->close();
	}
	catch {
		emitMessage "Error while saving trace: $_";
	};
}

sub captureTrace {
	my $errStr= "".$_[0];
	
	# do not record multiple stack traces for an error which is getting re-thrown frm a catch
	return unless !defined $LAST_THROWN_OBJ_STR or $errStr ne $LAST_THROWN_OBJ_STR;
	$LAST_THROWN_OBJ_STR= $errStr;
	
	push @TRACES, Devel::StackTrace->new;
	emitMessage "Exception trace captured";
}

sub collectTraces {
	my @result= @TRACES;
	@TRACES= ();
	$LAST_THROWN_OBJ_STR= undef;
	return @result;
}

END {
	if (scalar(@TRACES)) {
		emitMessage "Unexpected call to exit... Dumping traces to $TRACE_OUT_FILE";
		for my $trace (@TRACES) { writeFullTrace($trace); }
		@TRACES= ();
	}
}

1;
