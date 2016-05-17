package RapidApp::Util::RapidDbic::CfgWriter;
use strict;
use warnings;

# ABSTRACT: Updates RapidDbic model configs using PPI

use Moo;
use Types::Standard qw(:all);
use Path::Class qw(file dir);
use Scalar::Util qw(blessed);
use List::Util;
use Module::Runtime;

use RapidApp::Util ':all';
require Data::Dumper;

use PPI;
use Perl::Tidy;

sub BUILD {
  my $self = shift;
  $self->TableSpecs_stmt; # init early
}

sub _update_incs {
  my $self = shift;
  
  my $next = file( $self->pm_file )->resolve->absolute->parent;
  
  until ($next->basename eq 'lib') {
    $next = $next->parent or return undef;
    return undef if ("$next" eq '/' or "$next" eq '.');
  }
  
  eval "use lib '$next'";
}

has 'pm_file', is => 'ro', required => 1, isa => Str;
has 'use_perltidy', is => 'ro', isa => Bool, default => 1;

has 'ppi_document', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  PPI::Document->new( file( $self->pm_file )->resolve->stringify )
}, isa => InstanceOf['PPI::Document'];

has 'config_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $m = $self->ppi_document->find( sub {
    $_[1]->isa('PPI::Statement') or return undef;
    
    my @c = $_[1]->children;
    $c[2] && $c[2]->content eq 'config' && 
    $c[0]->content eq '__PACKAGE__' && 
    $c[1]->content eq '->' ? 1 : undef
  }) || [];

  scalar(@$m) == 0 and die '__PACKAGE__->config statement not found';
  scalar(@$m) > 1  and die 'Multiple __PACKAGE__->config statements found';
  
  my $stmt = $m->[0]
    ->child(3)
    ->find_first('PPI::Statement::Expression');
  
  # -- Make sure there is a trailing comma (,) ... this will keep perltidy from
  # getting confused about the indentation of the last }
  my $Last = (reverse $stmt->children)[0];
  unless($Last->isa('PPI::Token::Operator') && $Last->content eq ',') {
    $Last->insert_after(PPI::Token::Operator->new(','));
  }
  # --
  
  return $stmt;

}, isa => InstanceOf['PPI::Statement::Expression'];


has 'schema_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $tok = $self->_first_kval(
    $self->config_stmt,
    'schema_class'
  ) or die "'schema_class' config key not found!";
  
  my $class = $tok->content;
  $class =~ s/^('|")//;
  $class =~ s/('|")$//;
  
  $self->_update_incs;
  Module::Runtime::require_module( $class );
  
  $class

}, isa => ClassName;


has 'source_names', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  [ sort $self->schema_class->sources ]
}, isa => ArrayRef[Str];

has 'rapiddbic_struct', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_kval(
    $self->config_stmt,
    'RapidDbic'
  ) or die "RapidDbic config key not found!";
}, isa => InstanceOf['PPI::Structure::Constructor'];


has 'rapiddbic_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_stmt( $self->rapiddbic_struct )
}, isa => InstanceOf['PPI::Statement::Expression'];

has 'grid_params_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_stmt( $self->_first_kval($self->rapiddbic_stmt,'grid_params') )
}, isa => InstanceOf['PPI::Statement::Expression'];

has 'TableSpecs_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $struct = $self->_first_kval(
    $self->rapiddbic_stmt,
    'TableSpecs'
  ) or die "TableSpecs config key not found!";
  
  $self->_find_or_make_inner_stmt( $struct )
  
}, isa => InstanceOf['PPI::Statement'];

has 'virtual_columns_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_stmt( $self->_first_kval($self->rapiddbic_stmt,'virtual_columns') )
}, isa => Maybe[InstanceOf['PPI::Statement::Expression']];

has 'virtual_columns_hash', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $Stmt = $self->virtual_columns_stmt or return {};
  return try{ eval(join('','{',$Stmt->content,'}')) } || {};
}, isa => HashRef;


sub _process_TableSpecs {
  my $self = shift;
  
  my $Stmt = $self->TableSpecs_stmt;

  for my $source (@{$self->source_names}) {
    my $SnStmt = $self->_find_or_make_inner_stmt( 
      $self->_find_or_make_kval( $Stmt, $source )
    );
    
    
    # ...
    
    my $colsStmt = $self->_find_or_make_inner_stmt(
      $self->_find_or_make_kval( $SnStmt, 'columns' )
    );
    
    my $Source = $self->schema_class->source($source);
    my @cols = sort $Source->columns;
    push @cols, sort $Source->relationships;
    
    if(my $vcols = $self->virtual_columns_hash->{$source}) {
      push @cols, sort (keys %$vcols) if (ref($vcols)||'' eq 'HASH');
    }
    
    for my $col (uniq @cols) {
      my $cStmt = $self->_find_or_make_inner_stmt( 
        $self->_find_or_make_kval( $colsStmt, $col )
      );
      

      
      $self->_find_or_add_entry( $cStmt, header => "$col" );
      $self->_find_or_add_entry( $cStmt, width => 100, 1 );
      $self->_find_or_add_entry( $cStmt, sortable => 1);
      
      $self->_find_or_add_entry( $cStmt, profiles => [], 1);
    
    }
    
    # ...
    
  
  }
  
}

has 'perltidy_argv', is => 'ro', isa => Str, default => sub { '-i=2 -l=100 -nbbc' };

sub _save_to {
  my ($self, $path) = @_;
  
  $self->use_perltidy    
    ? Perl::Tidy::perltidy(
      source      => \$self->ppi_document->serialize,
      destination => $path,
      argv        => $self->perltidy_argv
    ) 
    : $self->ppi_document->save($path)
}


sub _find_or_make_inner_stmt {
  my ($self, $Node) = @_;
  
  my $Stmt = $self->_first_stmt( $Node );
  return $Stmt if ($Stmt);
  
  scalar($Node->schildren) == 0 or die "unexepted inner value";
  
  $Stmt = PPI::Statement::Expression->new;
  $Node->add_element( $Stmt );
  
  return $Stmt
}
  

sub _find_or_make_kval {
  my ($self, $Node, $key) = @_;
  
  my $Tok = $self->_first_kword($Node, $key);  
  return $self->_first_kval($Node,$Tok) if ($Tok);
  
  my $kVal = bless( {
    children => [
      bless( {
        children => []
      }, 'PPI::Statement::Expression' )
    ],
    finish => bless( {
      content => "}"
    }, 'PPI::Token::Structure' ),
    start => bless( {
      content => "{"
    }, 'PPI::Token::Structure' )
  }, 'PPI::Structure::Constructor' );
  
  my @els = $self->_els_for_next_kv(
    $Node,
    $self->_create_kword_tok($key),
    $kVal
  );
  
  $self->_push_children( $Node, @els );
  
  return $kVal
}

sub _create_kword_tok {
  my ($self, $key) = @_;
  
  $key =~ /^\w+$/ 
    ? PPI::Token::Word->new($key)
    : bless( { content => "'$key'", separator => "'" }, 'PPI::Token::Quote::Single' );
}

sub _create_value_tok {
  my ($self, $val) = @_;
  
  local $Data::Dumper::Terse = 1;
  my $value = Data::Dumper::Dumper($val);
  chomp $value;
  
  @{ PPI::Tokenizer->new( \$value )->all_tokens }
}


sub _find_or_add_entry {
  my ($self, $Node, $key, $val, $as_comment) = @_;
  
  my $El = $self->_first_kword($Node,$key) 
    || $self->_first_cmt_kword($Node,$key)
    # needed when comments are the first lines within the {} block -- these will
    # not show up as a child of the Statement::Expression, but of the parent structure
    || $self->_first_cmt_kword($Node->parent,$key); 
  
  return $El if ($El);
  
  my @els = $self->_els_for_next_kv(
    $Node,
    $self->_create_kword_tok($key),
    $self->_create_value_tok($val)
  );
  
  if($as_comment) {
    shift @els if($els[0]->isa('PPI::Token::Operator'));
    my $str = join('',"\n   #",(map { $_->content } @els),"\n" );
    @els = ( PPI::Token::Comment->new($str) );
  }

  $self->_push_children( $Node, @els );
}

sub _els_for_next_kv {
  my ($self, $Node, $Keytok, @Valtoks) = @_;

  my @els = ();
  
  my @schld = $Node->schildren;
  if(scalar(@schld) > 0) {
    my $Last = pop @schld;
    unless($Last->content eq ',') {
      push @els, PPI::Token::Operator->new(',');
    }
  }
  
  push @els, (
    $Keytok,
    PPI::Token::Whitespace->new(' '),
    PPI::Token::Operator->new('=>'),
    PPI::Token::Whitespace->new(' '),
    @Valtoks,
    PPI::Token::Operator->new(',')
  );
  
  return @els
}


sub _push_children {
  my ($self, $Node, @els) = @_;
  $Node->add_element($_) for @els
}


sub _first_kword {
  my ($self, $Node, $key) = @_;
  
  List::Util::first {
    $_->content eq $key ||
    $_->content =~ /^('|"){1}${key}('|"){1}$/
  } grep { $_->isa('PPI::Token') } $Node->children
}


sub _first_cmt_kword {
  my ($self, $Node, $key) = @_;
  return undef unless ($Node);
  
  List::Util::first {
    $_->content =~ /^\s*\#+\s*('|")??${key}('|")??\s+/
  } grep { $_->isa('PPI::Token::Comment') } $Node->children;
}

sub _first_kval {
  my ($self, $Node, $key) = @_;
  
  my $kWord = blessed($key) ? $key : $self->_first_kword($Node, $key) or return undef;
  
  my $Op = $kWord->snext_sibling;
  $Op && $Op->content eq '=>' or return undef;
  
  $Op->snext_sibling
}

sub _first_stmt {
  my ($self,$El) = @_;
  List::Util::first { $_->isa('PPI::Statement') } $El->children
}



1;


__END__

=head1 NAME

RapidApp::Util::RapidDbic::CfgWriter - Updates RapidDbic model configs using PPI

=head1 SYNOPSIS

 use RapidApp::Util::RapidDbic::CfgWriter;


=head1 DESCRIPTION

Experimental external definitions of foreign keys


=head1 METHODS

=head2 new

Create a new RapidApp::Util::RapidDbic::CfgWriter instance. The following build options are supported:

=over 4

=item pm_file

Path to Model pm file

=back


=head1 SEE ALSO

=over

=item * 

L<RapidApp>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
