package RapidApp::Util;

# ABSTRACT: Misc util and sugar functions for RapidApp

use strict;
use warnings;

use Scalar::Util qw(blessed weaken reftype);
use Clone qw(clone);
use Carp qw(carp croak confess cluck longmess shortmess);
use Try::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper::Concise qw(Dumper);
use Term::ANSIColor qw(:constants);
use RapidApp::JSON::MixedEncoder qw(
  encode_json decode_json encode_json_utf8 decode_json_utf8 encode_json_ascii decode_json_ascii
);

use RapidApp::Util::Hash::Merge qw( merge );
RapidApp::Util::Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );

use Data::Printer;

our $DEBUG_AROUND_COUNT = 0;
our $DEBUG_AROUND_CALL_NO = 0;

BEGIN {
  use Exporter;
  use parent 'Exporter';

  use vars qw (@EXPORT_OK %EXPORT_TAGS);

  # These are *extra* exports which came to us via other packages. Note that
  # all functions defined directly in the class will also be added to the
  # @EXPORT_OK and setup with the :all tag (see the end of the file)
  @EXPORT_OK = qw(
    blessed weaken reftype
    clone
    carp croak confess cluck longmess shortmess
    try catch finally
    gettimeofday tv_interval
    Dumper
    encode_json decode_json encode_json_utf8 decode_json_utf8 encode_json_ascii decode_json_ascii
    merge
  );

  push @EXPORT_OK, @{$Term::ANSIColor::EXPORT_TAGS{constants}};

  %EXPORT_TAGS = (
    all => \@EXPORT_OK
  );
}

use RapidApp::Responder::UserError;
use RapidApp::Responder::CustomPrompt;
use RapidApp::Responder::InfoStatus;
use RapidApp::JSONFunc;
use RapidApp::JSON::MixedEncoder;
use RapidApp::JSON::RawJavascript;
use RapidApp::JSON::ScriptWithData;

use RapidApp::HTML::RawHtml;
use RapidApp::Handler;
use HTML::Entities;
use RapidApp::RootModule;


########################################################################

sub scream {
  local $_ = caller_data(3);
  scream_color(YELLOW . BOLD,@_);
}

sub scream_color {
  my $color = shift;
  no warnings 'uninitialized';

  my $maxdepth = $Data::Dumper::Maxdepth || 4;
  local $Data::Dumper::Maxdepth = $maxdepth;

  local $_ = caller_data(3) unless (
    $_ eq 'no_caller_data' or (
      ref($_) eq 'ARRAY' and
      scalar(@$_) == 3 and
      ref($_->[0]) eq 'HASH' and
      defined $_->[0]->{package}
    )
  );

  my $data = $_[0];
  $data = \@_ if (scalar(@_) > 1);
  $data = Dumper($data) if (ref $data);
  $data = '  ' . UNDERLINE . 'undef' unless (defined $data);

  my $pre = '';
  $pre = BOLD . ($_->[2]->{subroutine} ? $_->[2]->{subroutine} . '  ' : '') .
    '[line ' . $_->[1]->{line} . ']: ' . CLEAR . "\n" unless ($_ eq 'no_caller_data');

  print STDERR $pre . $color . $data . CLEAR . "\n";

  return @_;
}


# Takes a list and returns a HashRef. List can be a mixed Hash/List:
#(
#  item1 => { opt1 => 'foo' },
#  item2 => { key => 'data', foo => 'blah' },
#  'item3',
#  'item4',
#  item1 => { opt2 => 'foobar', opt3 => 'zippy do da' }
#)
# Bare items like item3 and item4 become {} in the returned hashref.
# Repeated items like item1 and merged
# also handles the first arg as a hashref or arrayref
sub get_mixed_hash_args {
  my @args = @_;
  return $args[0] if (ref($args[0]) eq 'HASH');
  @args = @{ $args[0] } if (ref($args[0]) eq 'ARRAY');

  my $hashref = {};
  my $last;
  foreach my $item (@args) {
    if (ref($item)) {
      die "Error in arguments" unless (ref($item) eq 'HASH' and defined $last and not ref($last));
      $hashref->{$last} = { %{$hashref->{$last}}, %$item };
      next;
    }
    $last = $item;
    $hashref->{$item} = {} unless (defined $hashref->{$item});
  }
  return $hashref;
}


# Takes a list and returns a Hash. Like get_mixed_hash_args, but
# list order is preserved
sub get_mixed_hash_args_ordered {
  my @args = @_;
  return $args[0] if (ref($args[0]) eq 'HASH');
  @args = @{ $args[0] } if (ref($args[0]) eq 'ARRAY');

  my $hashref = {};
  my @list = ();
  my $last;
  foreach my $item (@args) {
    if (ref($item)) {
      die "Error in arguments" unless (ref($item) eq 'HASH' and defined $last and not ref($last));
      $hashref->{$last} = { %{$hashref->{$last}}, %$item };
      push @list, $last, $hashref->{$last};
      next;
    }
    $hashref->{$item} = {} unless (defined $hashref->{$item});
    push @list,$item,$hashref->{$item} unless (ref $last);
    $last = $item;
  }
  return @list; # <-- preserve order
}


# returns \0 and \1 as 0 and 1, and returns 0 and 1 as 0 and 1
sub jstrue {
  my $v = shift;
  ref($v) && ref($v) eq 'SCALAR' ? $$v : $v;
}


# The coderefs supplied here get called immediately after the
# _load_root_module method in RapidApp/RapidApp.pm
sub rapidapp_add_global_init_coderef {
  foreach my $ref (@_) {
    ref($ref) eq 'CODE' or die "rapidapp_add_global_init_coderef: argument is not a CodeRef: " . Dumper($ref);
    push @RapidApp::RootModule::GLOBAL_INIT_CODEREFS, $ref;
  }
}

# Returns an arrayref of hashes containing standard 'caller' function data
# with named properties:
sub caller_data {
  my $depth = shift || 1;

  my @list = ();
  for(my $i = 0; $i < $depth; $i++) {
    my $h = {};
    ($h->{package}, $h->{filename}, $h->{line}, $h->{subroutine}, $h->{hasargs},
      $h->{wantarray}, $h->{evaltext}, $h->{is_require}, $h->{hints}, $h->{bitmask}) = caller($i);
    push @list,$h if($h->{package});
  }

  return \@list;
}

sub caller_data_brief {
  my $depth = shift || 1;
  my $list = caller_data($depth + 1);
  my $regex = shift;

  shift @$list;
  shift @$list;

  my @inc_parms = qw(subroutine line filename);

  my %inc = map { $_ => 1 } @inc_parms;

  my @new = ();
  my $seq = 0;
  foreach my $item (@$list) {
    if($regex and ! eval('$item->{subroutine} =~ /' . $regex . '/')) {
      $seq++;
      next;
    }
    push @new, ' . ' x $seq if ($seq);
    $seq = 0;
    push @new, { map { $_ => $item->{$_} } grep { $inc{$_} } keys %$item };
  }

  return \@new;
}


# TODO: replace this with uniq from List::Utils
# Returns a list with duplicates removed. If passed a single arrayref, duplicates are
# removed from the arrayref in place, and the new list (contents) are returned.
sub uniq {
  my %seen = ();
  return grep { !$seen{ defined $_ ? $_ : '___!undef!___'}++ } @_ unless (@_ == 1 and ref($_[0]) eq 'ARRAY');
  return () unless (@{$_[0]} > 0);
  # we add the first element to the end of the arg list to prevetn deep recursion in the
  # case of nested single element arrayrefs
  @{$_[0]} = uniq(@{$_[0]},$_[0]->[0]);
  return @{$_[0]};
}

sub deref {
  my $ref = shift;
  my $type = ref $ref || return $ref,@_;
  die 'deref(): more than 1 argument not supported' if (@_ > 0);
  return $$ref if ($type eq 'SCALAR');
  return @$ref if ($type eq 'ARRAY');
  return %$ref if ($type eq 'HASH');
  die "deref(): invalid ref type '$type' - supported types: SCALAR, ARRAY and HASH";
}

# Generic function returns a short display string of a supplied value/values
# This is like a lite version of Dumper meant more for single values
# Accepts optional CodeRef as first argument for custom handling, for example,
# this would allow you to use Dumper instead for all ref values:
# print disp(sub{ ref $_ ? Dumper($_) : undef },$_) for (@vals);
sub disp {
  my $recurse = (caller(1))[3] eq __PACKAGE__ . '::disp' ? 1 : 0; #<-- true if called by ourself

  local $_{code} = $recurse ? $_{code} : undef;
  $_{code} = shift if(ref($_[0]) eq 'CODE' && @_>1 && $recurse == 0);
  if($_{code}) {
    local $_ = $_[0];
    my $cust = $_{code}->(@_);
    return $cust if (defined $cust);
  }

  return join(',',map {disp($_)} @_) if(@_>1);
  my $val = shift;
  return 'undef' unless (defined $val);
  if(ref $val) {
    return '[' . disp(@$val) . ']' if (ref($val) eq 'ARRAY');
    return '\\' . disp($$val) if (ref($val) eq 'SCALAR');
    return '{ ' . join(',',map { $_ . ' => ' . disp($val->{$_}) } keys %$val) . ' }' if (ref($val) eq 'HASH');
    return "$val" #<-- generic fall-back for other references
  }
  return "'" . $val . "'";
}


sub print_trunc($$) {
  my $max_length = shift;
  my $str = shift;

  die "Invalid max length '$max_length'" unless (
    defined $max_length &&
    $max_length =~ /^\d+$/ &&
    $max_length > 0
  );

  return 'undef' unless (defined $str);
  if (ref $str) {
    $str = disp($str);
    $str =~ s/^\'//;
    $str =~ s/\'$//;
  }

  # escape single quotes:
  $str =~ s/'/\\'/g;

  # convert tabs:
  $str =~ s/\t/   /g;

  my $length = length $str;
  return "'" . $str . "'" if ($length <= $max_length);
  return "'" . substr($str,0,$max_length) . "'...<$length" . " bytes> ";
}

our $debug_arounds_set = {};
our $debug_around_nest_level = 0;
our $debug_around_last_nest_level = 0;
our $debug_around_stats = {};
our $debug_around_nest_elapse = 0;

sub debug_around($@) {
  my ($pkg,$filename,$line) = caller;
  my $method = shift;
  my @methods = ( $method );
  @methods = @$method if (ref($method) eq 'ARRAY');

  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

  %opt = (
    pkg      => $pkg,
    filename    => $filename,
    line      => $line,
    %opt
  );

  $pkg = $opt{pkg};

  foreach my $method (@methods) {

    my $package = $pkg;
    my @namespace = split(/::/,$method);
    if(scalar @namespace > 1) {
      $method = pop @namespace;
      $package = join('::',@namespace);
    }

    next if ($debug_arounds_set->{$package . '->' . $method}++); #<-- if its already set

    eval "require $package;";
    my $around = func_debug_around($method, %opt, pkg => $package);

    # It's a Moose class or otherwise already has an 'around' class method:
    if($package->can('around')) {
      $package->can('around')->($method => $around);
      next;
    }

    # The class doesn't have an around method, so we'll setup manually with Class::MOP:
    my $meta = Class::MOP::Class->initialize($package);
    $meta->add_around_method_modifier($method => $around)
  }
}

# Returns a coderef - designed to be a Moose around modifier - that will
# print useful debug info about the given function to which it is attached
sub func_debug_around {
  my $name = shift;
  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

  my $Id = $DEBUG_AROUND_COUNT++;


  %opt = (
    track_stats    => 1,
    time      => 1,
    verbose      => 0,
    verbose_in    => undef,
    verbose_out    => undef,
    newline      => 0,
    list_args    => 0,
    list_out    => 0,
    dump_maxdepth  => 3,
    use_json    => 0,
    stack      => 0,
    instance    => 0,
    color      => GREEN,
    ret_color    => RED.BOLD,
    arg_ignore    => sub { 0 }, # <-- no debug output prited when this returns true
    return_ignore  => sub { 0 },# <-- no debug output prited when this returns true
    %opt
  );

  # around wrapper in %opt to allow the user to pass a different one to use:
  $opt{around} ||= sub {
    my $orig = shift;
    my $self = shift;
    print STDERR "\n" if ($opt{newline});
    return $self->$orig(@_);
  };

  $opt{verbose_in} = 1 if ($opt{verbose} and not defined $opt{verbose_in});
  $opt{verbose_out} = 1 if ($opt{verbose} and not defined $opt{verbose_out});

  $opt{dump_func} = sub {
    my $verbose = shift;
    return UNDERLINE . 'undef' . CLEAR unless (@_ > 0 and defined $_[0]);

    # if list_out is false, return the number of items in the return, underlined
    return $opt{list_out} ? join(',',map { ref $_ ? "$_" : "'$_'" } @_) : UNDERLINE . @_ . CLEAR
      unless ($verbose);

    local $Data::Dumper::Maxdepth = $opt{dump_maxdepth};
    return Dumper(@_) unless ($opt{use_json});
    #return RapidApp::JSON::MixedEncoder->new->allow_blessed->convert_blessed->allow_nonref->encode(\@_);
    return encode_json(\@_);
  } unless ($opt{dump_func});

  return sub {
    my $orig = shift;
    my $self = shift;
    my @args = @_;

    my $printed_newlines = 0;

    my $_PRINTER = sub {
      for my $text (@_) {
        my $char = "\n";
        my $newlines = () = $text =~ /\Q$char/g;
        $printed_newlines = $printed_newlines + $newlines;
        print STDERR $text
      }
    };

    my $Count = $DEBUG_AROUND_CALL_NO++;
    my $is_odd = $Count % 2 == 1;

    my $label_color = $is_odd ? CLEAR.CYAN.BOLD : CLEAR.MAGENTA.BOLD;

    my $nest_level = $debug_around_nest_level;
    local $debug_around_nest_level = $debug_around_nest_level + 1;

    my $new_nest = $debug_around_last_nest_level < $nest_level ? 1 : 0;
    my $leave_nest = $debug_around_last_nest_level > $nest_level ? 1 : 0;
    $debug_around_last_nest_level = $nest_level;

    $debug_around_nest_elapse = 0 if ($nest_level == 0);

    my $indent = $nest_level > 0 ? ('  ' x $nest_level) : '';
    my $newline = "\n$indent";

    my $has_refs = 0;

    my $class = $opt{pkg};

    my $oneline = ! $leave_nest || ! $nest_level;

    $_PRINTER->($newline) if ($new_nest);

    $_PRINTER->(join('',
      $label_color,"[$Id/$Count]",'==> ',CLEAR,$opt{color},$class,CLEAR,'->',
      $opt{color},BOLD,$name,CLEAR,
      '( ' . MAGENTA . 'args in: ' . BOLD . scalar(@args) .  CLEAR . ' ) '
    ));

    if($opt{list_args}) {
      $oneline = 0;
      my @plines = split(/\r?\n/,np(@args, colored => 0));
      $plines[0] = "Supplied arguments: $plines[0]";
      my $max = 0;
      $max < $_ and $max = $_ for (map { length($_) } @plines);

      for my $line (@plines) {
        my $pad = $max - length($line);
        $_PRINTER->(join('',$newline,(' ' x ($nest_level+6)), ON_CYAN,'  ', $line,ON_CYAN, (' ' x ($pad+3)),'  ',CLEAR));
      }
      $_PRINTER->($newline);



    }




    #my $in = '( ' . MAGENTA . 'args in: ' . BOLD . scalar(@args) .  CLEAR . ' ): ';
    #if($opt{list_args}) {
    #  my @print_args = map { (ref($_) and ++$has_refs) ? "$_" : MAGENTA . "'$_'" . CLEAR } @args;
    #  $in = '(' . join(',',@print_args) . '): ';
    #}


    if($opt{stack}) {
      $oneline = 0;
      my $stack = caller_data_brief($opt{stack} + 3);
      shift @$stack;
      shift @$stack;
      shift @$stack;
      @$stack = reverse @$stack;
      my $i = scalar @$stack;
      #my $i = $opt{stack};
      $_PRINTER->($newline);

      my $max_fn = 0;
      foreach my $data (@$stack) {
        my ($fn) = split(/\s+/,(reverse split(/\//,$data->{filename}))[0]);
        $max_fn = length($fn) if (length($fn) > $max_fn);
        $data->{fn} = $fn;
      }

      my $pfx = ' ';
      foreach my $data (@$stack) {
        $_PRINTER->($label_color,'|'.$pfx . CLEAR . sprintf("%3s",$i--) . ' | ' . CYAN . sprintf("%".$max_fn."s",$data->{fn}) . ' ' .
        BOLD . sprintf("%-5s",$data->{line}) . CLEAR . CYAN . '-> ' . CLEAR .
          GREEN . $data->{subroutine} . CLEAR . $newline);
        $pfx = '^';
      }


      #print STDERR '((stack  0)) ' .  sprintf("%7s",'[' . $opt{line} . ']') . ' ' .
      #  GREEN . $class . '::' . $name . $newline . CLEAR;
      #$class = "$self";
    }
    #else {
    #  print STDERR $newline and $oneline = 0 if ($new_nest);
    #}

    if($opt{stack}) {
      $_PRINTER->(CLEAR . $label_color . "|^" .CLEAR . BOLD "  -->" . CLEAR);
    }

    unless($oneline) {
      $_PRINTER->($label_color . "[$Id/$Count]",'^^  ' . CLEAR) unless ($opt{stack});
      $_PRINTER->(' ',$opt{color}  . $class . CLEAR . '->' . $opt{color} . BOLD . $name . ' ' . CLEAR);
    }












    my $spaces = ' ' x (2 + length($opt{line}));
    my $in_func = sub {
      $_PRINTER->($newline . ON_WHITE.BOLD . BLUE . "$spaces Supplied arguments dump: " .
        $opt{dump_func}->($opt{verbose_in},\@args) . CLEAR . $newline . ": ")
          if($has_refs && $opt{verbose_in});
    };







    my $res;
    my @res;
    my @res_copy = ();

    # before timestamp:
    my $t0 = [gettimeofday];
    my $current_nest_elapse;
    {
      local $debug_around_nest_elapse = 0;
      if(wantarray) {
        try {
          @res = $opt{around}->($orig,$self,@args);
        } catch { $in_func->(); die (shift);};
        push @res_copy, @res;
      }
      else {
        try {
          $res = $opt{around}->($orig,$self,@args);
        } catch { $in_func->(); die (shift);};
        push @res_copy,$res;
      }
      # How much of the elapsed time was in nested funcs below us:
      $current_nest_elapse = $debug_around_nest_elapse;
    }



    if($opt{list_out}) {
      $oneline = 0;
      my @plines = split(/\r?\n/,np(@res_copy, colored => 0));
      $plines[0] = "Returned values: $plines[0]";
      my $max = 0;
      $max < $_ and $max = $_ for (map { length($_) } @plines);

      for my $line (@plines) {
        my $pad = $max - length($line);
        $_PRINTER->(join('',$newline,(' ' x ($nest_level+6)), ON_GREEN,'  ', $line,ON_GREEN, (' ' x ($pad+3)),'  ',CLEAR));
      }
      $_PRINTER->($newline);
    }





    # after timestamp, calculate elapsed (to the millisecond):
    my $elapsed_raw = tv_interval($t0);
    my $adj_elapsed = $elapsed_raw - $current_nest_elapse;
    $debug_around_nest_elapse += $elapsed_raw; #<-- send our elapsed time up the chain

    if($opt{list_out}) {
      $_PRINTER->($label_color . $label_color . "[$Id/$Count]", '^^^ ' . CLEAR . $opt{color}  . $class . CLEAR . '->' .
        $opt{color} . BOLD . $name . ' ');
    }

    $_PRINTER->($opt{ret_color} . 'Ret itms: ' . scalar(@res_copy) . CLEAR);
    $_PRINTER->(CLEAR . ' in ' . ON_WHITE.RED . sprintf('%.5fs',$elapsed_raw) . ' (' . sprintf('%.5fs',$adj_elapsed) . ' exclusive)' . CLEAR);


    # -- Track stats in global %$RapidApp::Util::debug_around_stats:
    if($opt{track_stats}) {
      no warnings 'uninitialized';
      my $k = $class . '->' . $name;
      $debug_around_stats->{$k} = $debug_around_stats->{$k} || {};
      my $stats = $debug_around_stats->{$k};
      %$stats = (
        class => $class,
        sub => $name,
        line => $opt{line},
        calls => $stats->{calls} + 1,
        real_total => $stats->{real_total} + $elapsed_raw,
        total => $stats->{total} + $adj_elapsed,
        min => exists $stats->{min} ? $stats->{min} : $adj_elapsed,
        max => exists $stats->{max} ? $stats->{max} : $adj_elapsed,
      );
      $stats->{avg} = $stats->{total}/$stats->{calls};
      $stats->{min} = $adj_elapsed if ($adj_elapsed < $stats->{min});
      $stats->{max} = $adj_elapsed if ($adj_elapsed > $stats->{max});
    }
    # --

    local $_ = $self;
    if(!$opt{arg_ignore}->(@args) && !$opt{return_ignore}->(@res_copy)) {

      $in_func->();

      #my $elapsed_short = '[' . sprintf("%.3f", $elapsed_raw ) . 's]';

      my @a = map { sprintf('%.3f',$_) } ($elapsed_raw,$adj_elapsed);
      my $elapsed_long = '[' . join('|',@a) . ']';

      my $result = $opt{ret_color} . $opt{dump_func}->($opt{verbose_out},@res_copy) . CLEAR;
      $result = "\n" . ON_WHITE.BOLD . "$spaces Returned: " . $result . "\n" if ($opt{verbose_out});
      $result .= ' ' . ON_WHITE.RED . $elapsed_long . CLEAR if ($opt{time});

      $result =~ s/\n/${newline}/gm;

      # Reset cursor position if nesting happened:
      $_PRINTER->("\r$indent") unless ($RapidApp::Util::debug_around_last_nest_level == $nest_level);

      #print STDERR $result . $newline;
      $_PRINTER->($newline);

    }
    else {
      # 'arg_ignore' and/or 'return_ignore' returned true, so we're not
      # supposed to print anything... but since we already have, in case
      # the function would have barfed, we'll print a \r to move the cursor
      # to the begining of the line so it will get overwritten, which is
      # almost as good as if we had not printed anything in the first place...
      # (note if the function printed something too we're screwed)
      $_PRINTER->("\r");
    }

    if($printed_newlines > 5) {
      $_PRINTER->($label_color,"[$Id/$Count]", ('-' x 80), '^^^^', "\n\n",CLEAR);

    }

    return wantarray ? @res : $res;
  };
}

# Lets you create a sub and set debug_around on it at the same time
sub debug_sub($&) {
  my ($pkg,$filename,$line) = caller;
  my ($name,$code) = @_;

  my $meta = Class::MOP::Class->initialize($pkg);
  $meta->add_method($name,$code);

  return debug_around $name, pkg => $pkg, filename => $filename, line => $line;
}

sub debug_around_all {
  my $pkg = shift || caller;
  my $meta = Class::MOP::Class->initialize($pkg);
  debug_around($_, pkg => $pkg) for ($meta->get_method_list);
}

# Returns a stat in a hash with named keys
sub xstat {
  my $file = shift;
  return undef unless (-e $file);
  my $h = {};

  ($h->{dev},$h->{ino},$h->{mode},$h->{nlink},$h->{uid},$h->{gid},$h->{rdev},
       $h->{size},$h->{atime},$h->{mtime},$h->{ctime},$h->{blksize},$h->{blocks})
              = stat($file);

  return $h;
}


##### From RapidApp::Sugar #####

sub asjson {
  scalar(@_) == 1 or die "Expected single argument";
  return RapidApp::JSON::MixedEncoder::encode_json($_[0]);
}

# Bless a string as RawJavascript so that it doesn't get encoded as JSON data during asjson
sub rawjs {
  scalar(@_) == 1 && ref $_[0] eq '' or die "Expected single string argument";
  return RapidApp::JSON::RawJavascript->new(js=>$_[0]);
}

# Works like rawjs but accepts a list of arguments. Each argument should be a function defintion,
# and will be stacked together, passing each function in the chain through the first argument
sub jsfunc {
  my $js = shift or die "jsfunc(): At least one argument is required";

  return jsfunc(@$js) if (ref($js) eq 'ARRAY');

  blessed $js and not $js->can('TO_JSON_RAW') and
    die "jsfunc: arguments must be JavaScript function definition strings or objects with TO_JSON_RAW methods";

  $js = $js->TO_JSON_RAW if (blessed $js);

  # Remove undef arguments:
  @_ = grep { defined $_ } @_;

  $js = 'function(){ ' .
    'var args = arguments; ' .
    'args[0] = (' . $js . ').apply(this,arguments); ' .
    'return (' . jsfunc(@_) . ').apply(this,args); ' .
  '}' if (scalar @_ > 0);

  return RapidApp::JSON::RawJavascript->new(js=>$js)
}

# Encode a mix of javascript and data into appropriate objects that will get converted
#  to JSON properly during "asjson".
#
# Example:  mixedjs "function() { var data=", { a => $foo, b => $bar }, "; Ext.msg.alert(data); }";
# See ScriptWithData for more details.
#
sub mixedjs {
  return RapidApp::JSON::ScriptWithData->new(@_);
}

# Take a string of text/plain and convert it to text/html.  This handles "RawHtml" objects.
sub ashtml {
  my $text= shift;
  return "$text" if ref($text) && ref($text)->isa('RapidApp::HTML::RawHtml');
  return undef unless defined $text;
  return join('<br />', map { encode_entities($_) } split("\n", "$text"));
}

# Bless a scalar to indicate the scalar is already html, and doesn't need converted.
sub rawhtml {
  my $html= shift;
  # any other arguments we were given, we pass back in hopes that we're part of a function call that needed them.
  return RapidApp::HTML::RawHtml->new($html), @_;
}

=head2 usererr $message, key => $value, key => $value

Shorthand notation to create a UserError, to inform the user they did something wrong.
First argument is a scalar of text (or a RawHtml scalar of html)
Second through N arguments are hash keys to apply to the UserError constructor.

Examples:
  # To throw a message to the user with no data and no error report:
  die usererr "Hey you moron, don't do that";

  # To specify that your message is html already:
  die usererr rawhtml "<h2>Hell Yeah</h2>";

=cut

my %keyAliases = (
  msg => 'message',
  umsg => 'userMessage',
  title => 'userMessageTitle',
);
sub usererr {
  my %args= ();

  # First arg is always the message.  We stringify it, so it doesn't matter if it was an object.
  my $msg= shift;
  defined $msg or die "userexception requires at least a first message argument";

  # If the passed arg is already a UserError object, return it as-is:
  return $msg if ref($msg) && ref($msg)->isa('RapidApp::Responder::UserError');

  $args{userMessage}= ref($msg) && ref($msg)->isa('RapidApp::HTML::RawHtml')? $msg : "$msg";

  # pull in any other args
  while (scalar(@_) > 1) {
    my ($key, $val)= (shift, shift);
    $key = $keyAliases{$key} || $key;
    RapidApp::Responder::UserError->can($key)
      or warn "Invalid attribute for UserError: $key";
    $args{$key}= $val;
  }

  # userexception is allowed to have a payload at the end, but this would be meaningless for usererr,
  #  since usererr is not saved.
  if (scalar(@_)) {
    my ($pkg, $file, $line)= caller;
    warn "Odd number of arguments to usererr at $file:$line";
  }

  return RapidApp::Responder::UserError->new(\%args);
}

=head2 userexception $message, key => $value, key => $value, \%data

Shorthand notation for creating a RapidApp::Error which also informs the user about why the error occured.
First argument is the message displayed to the user (can be a RawHtml object).
Last argument is a hash of data that should be saved for the error report.
( the last argument is equivalent to a value for an implied hash key of "data" )

Examples:

  # Die with a custom user-facing message (in plain text), and a title made of html.
  die userexception "Description of what shouldn't have happened", title => rawhtml "<h1>ERROR</h1>";

  # Capture some data for the error report, as we show this message to the user.
  die userexception "Description of what shouldn't have happened", $some_debug_info;

=cut

sub userexception {
  my %args= ();

  # First arg is always the message.  We stringify it, so it doesn't matter if it was an object.
  my $msg= shift;
  defined $msg or die "userexception requires at least a first message argument";
  $args{userMessage}= ref($msg) && ref($msg)->isa('RapidApp::HTML::RawHtml')? $msg : "$msg";
  $args{message}= $args{userMessage};

  # pull in any other args
  while (scalar(@_) > 1) {
    my ($key, $val)= (shift, shift);
    $key = $keyAliases{$key} || $key;
    RapidApp::Error->can($key)
      or warn "Invalid attribute for RapidApp::Error: $key";
    $args{$key}= $val;
  }

  # userexception is allowed to have a payload as the last argument
  if (scalar(@_)) {
    $args{data}= shift;
  }

  return RapidApp::Error->new(\%args);
}



# Suger function sets up a Native Trait ArrayRef attribute with useful
# default accessor methods
#sub hasarray {
#  my $name = shift;
#  my %opt = @_;
#
#  my %defaults = (
#    is => 'ro',
#    isa => 'ArrayRef',
#    traits => [ 'Array' ],
#    default => sub {[]},
#    handles => {
#      'all_' . $name => 'uniq',
#      'add_' . $name => 'push',
#      'insert_' . $name => 'unshift',
#      'has_no_' . $name => 'is_empty',
#      'count_' . $name    => 'count'
#    }
#  );
#
#  my $conf = merge(\%defaults,\%opt);
#  return caller->can('has')->($name,%$conf);
#}

# Suger function sets up a Native Trait HashRef attribute with useful
# default accessor methods
#sub hashash {
#  my $name = shift;
#  my %opt = @_;
#
#  my %defaults = (
#    is => 'ro',
#    isa => 'HashRef',
#    traits => [ 'Hash' ],
#    default => sub {{}},
#    handles => {
#      'apply_' . $name    => 'set',
#      'get_' . $name      => 'get',
#      'has_' . $name      => 'exists',
#      'all_' . $name      => 'values',
#      $name . '_names'    => 'keys',
#    }
#  );
#
#  my $conf = merge(\%defaults,\%opt);
#  return caller->can('has')->($name,%$conf);
#}


sub infostatus {
  my %opt = @_;
  %opt = ( msg => $_[0] ) if (@_ == 1);
  return RapidApp::Responder::InfoStatus->new(%opt);
}


# -----
# New sugar automates usage of CustomPrompt for the purposes of a simple
# message with Ok/Cancel buttons. Returns the string name of the button
# after the prompt round-trip. Example usage:
#
# if(throw_prompt_ok("really blah?") eq 'Ok') {
#   # do blah ...
# }
#
sub throw_prompt_ok {
  my $msg;
  $msg = shift if (scalar(@_) % 2 && ! (ref $_[0])); # argument list is odd, and first arg not a ref

  my %opt = (ref($_[0]) && ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

  $msg ||= $opt{msg};
  $msg or die 'throw_prompt_ok(): must supply a "msg" as either first arg or named in hash key';

  my $c = RapidApp->active_request_context or die join(' ',
    'throw_prompt_ok(): this sugar function can only be called from',
    'within the context of an active request'
  );

  $c->is_ra_ajax_req or die die join(' ',
    'throw_prompt_ok(): this sugar function can only be called from',
    'within the context of a RapidApp-generated Ajax request'
  );

  my %cust_prompt = (
    title	=> 'Confirm',
    items	=> {
      html => $msg
    },
    formpanel_cnf => {
      defaults => {}
    },
    validate => \1,
    noCancel => \1,
    buttons	=> [ 'Ok', 'Cancel' ],
    EnterButton => 'Ok',
    EscButton => 'Cancel',
    height	=> 175,
    width	=> 350,
    %opt
  );

  if (my $button = $c->req->header('X-RapidApp-CustomPrompt-Button')){
    # $button should contain 'Ok' or 'Cancel' (or whatever values were set in 'buttons')
    return $button;
  }

  die RapidApp::Responder::CustomPrompt->new(\%cust_prompt);
}
# -----




##########################################################################################
##########################################################################################
#
# Automatically export all functions defined above:

use Class::MOP::Class;

my @pkg_methods = grep { ! ($_ =~ /^_/) } ( # Do not export funcs that start with '_'
  Class::MOP::Class
    ->initialize(__PACKAGE__)
    ->get_method_list
);

push @EXPORT_OK, @pkg_methods;

#
##########################################################################################
##########################################################################################

# The same as Catalyst::Utils::home but just a little bit more clever:
sub find_app_home {
  $_[0] && $_[0] eq __PACKAGE__ and shift;

  require Catalyst::Utils;
  require Module::Locate;

  my $class = shift or die "find_app_home(): expected app class name argument";

  my $path = Catalyst::Utils::home($class);

  unless($path) {
    # make an $INC{ $key } style string from the class name
    (my $file = "$class.pm") =~ s{::}{/}g;
    unless ($INC{$file}) {
      if(my $pm_path = Module::Locate::locate($class)) {
        local $INC{$file} = $pm_path;
        $path = Catalyst::Utils::home($class);
      }
    }
  }

  return $path;
}


1;
