package RapidApp::Util::RapidDbic::CfgWriter;
use strict;
use warnings;

# ABSTRACT: Updates RapidDbic model configs using PPI

use Moo;
use Types::Standard qw(:all);
use Path::Class qw(file dir);
use Scalar::Util qw(blessed);
use List::Util;

use RapidApp::Util ':all';

use PPI;

sub BUILD {
  my $self = shift;
  $self->TableSpecs_stmt; # init early
}


has 'pm_file', is => 'ro', required => 1, isa => Str;


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

  $m->[0]
    ->child(3)
    ->find_first('PPI::Statement::Expression');

}, isa => InstanceOf['PPI::Statement::Expression'];


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
}, isa => InstanceOf['PPI::Statement'];

has 'grid_params_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_stmt( $self->_first_kval($self->rapiddbic_stmt,'grid_params') )
}, isa => InstanceOf['PPI::Statement'];


has 'TableSpecs_kword', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->_first_kword($self->rapiddbic_stmt,'TableSpecs') 
    or die "'TableSpecs' config key not found!";
}, isa => InstanceOf['PPI::Token::Word'];

has 'TableSpecs_stmt', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $struct = $self->_first_kval(undef,$self->TableSpecs_kword);
  #$self->_ensure_indents($struct);
  
 
  
  #my $F = $self->_last_next_ws( (       $struct->children)[0] );
  #my $L = $self->_last_prev_ws( (reverse $struct->children)[0] );
  
  #my $F = $self->_last_next_ws( $struct->first_element );
  #my $L = $self->_last_prev_ws( $struct->last_element );
  
  scream_color(GREEN,$struct);
  
  
  #my $ind = $self->_cur_line_indent( $self->TableSpecs_kword );
  

  my $is_new = 0;
  my $Stmt = $self->_first_stmt( $struct );
  
  unless($Stmt) {
    $is_new = 1;
    $Stmt = PPI::Statement::Expression->new();
  }
  
  $self->_push_kv({
    node => $Stmt, 
    key => 'blarb', value => 'SOMETHING'
  
  });
  
  
  if($is_new) {
    
    
    my $sWs = $self->_ws_factory($struct,2);
    my $lWs = $self->_ws_factory($struct);
    
    $struct->{children} = [
      $sWs->(\"\n"),
      $Stmt,
      $lWs->(\"\n")
    
    ];
    
    
    
    #$struct->remove_child($_) for ($struct->children);
    #
    #$struct->add_element($sWs->(\"\n"));
    #$struct->add_element($Stmt);
    #$struct->add_element($lWs->(\"\n"));
    
    
    #$_->delete for ($struct->elements);
    
    #$struct->finish->remove;
    
    scream($struct);
    
    #my $F = $struct->finish;
    #$F->insert_before($sWs->(\"\n"));
    #$F->insert_before($Stmt);
    #$F->insert_before($lWs->(\"\n"));
    
    
    #$_->delete for ($struct->elements);
    
    #$struct->add_element($sWs->(\"\n"));
    #$struct->add_element($Stmt);
    #$struct->add_element($lWs->(\"\n"));
    
    #$self->_ensure_indents($struct);
    #my $F = $self->_last_next_ws( $struct->child(0) );
    #$F->insert_after($Stmt);
  }
  
  
  
  #scream_color(MAGENTA,$Stmt);
  
  ##unless($Stmt) {
  ##  #$struct->remove_child($_) for ($struct->children);
  ##  
  ##  my @chld = $struct->children;
  ##  
  ##  #
  ##  $self->_ensure_indents($struct);
  ##  my $F = $self->_last_next_ws( $struct->child(0) );
  ##  
  ##  #scream($F);
  ##  
  ##  $Stmt = PPI::Statement::Expression->new();
  ##  $F->insert_after($Stmt);
  ##  
  ##  $_->delete for (@chld);
  ##}
  ##
  ##$self->_push_kv({
  ##  node => $Stmt, 
  ##  key => 'blarb', value => 'SOMETHING'
  ##
  ##});
  ##
  ##scream_color(MAGENTA.BOLD,$Stmt);
  ##
  ##scream_color(GREEN,$struct);
  
  #scream_color(GREEN.BOLD,$struct->elements);
  
  
  
  #unless($Stmt) {
  #  $Stmt = ;
  #  
  #  
  #  
  #  my $Ws = $self->TableSpecs_kword->previous_sibling;
  #  
  #  if($Ws && $Ws->isa('PPI::Token::Whitespace')) {
  #    $Stmt->add_element( bless( { content => "\n" }, 'PPI::Token::Whitespace' ) );
  #    $Stmt->add_element( bless( { content => $Ws->content }, 'PPI::Token::Whitespace' ) );
  #  }
  # 
  #  $Stmt->add_element( bless( { content => "  " }, 'PPI::Token::Whitespace' ) );
  #  $Stmt->add_element( bless( { content => "blarbie" }, 'PPI::Token::Word' ) );
  #  $Stmt->add_element( bless( { content => " " }, 'PPI::Token::Whitespace' ) );
  #  $Stmt->add_element( bless( { content => "=>" }, 'PPI::Token::Operator' ) );
  #  $Stmt->add_element( bless( { content => " " }, 'PPI::Token::Whitespace' ) );
  #  $Stmt->add_element( bless( { content => "'SOMETHING'", separator => "'" }, 'PPI::Token::Quote::Single' ) );
  #  #
  #  
  #  
  #  
  #  
  #  
  #  if($Ws && $Ws->isa('PPI::Token::Whitespace')) {
  #    $Stmt->add_element( bless( { content => "\n" }, 'PPI::Token::Whitespace' ) );
  #    $Stmt->add_element( bless( { content => $Ws->content }, 'PPI::Token::Whitespace' ) );
  #  }
  #  
  #  
  #  
  #  
  #  
  #  #scream($struct);
  #  
  #}
  #
  #my $ind = $self->_cur_line_indent( $Stmt );
  #scream_color(RED.BOLD, $ind, length($ind) );
  
  $Stmt
  
}, isa => InstanceOf['PPI::Statement'];


sub _last_next_ws {
  my ($self, $Ws) = @_;
  my $Next = $Ws->next_sibling;
  return $self->_last_next_ws($Next) if ($Next && $Next->isa('PPI::Token::Whitespace'));
  
  $Ws->isa('PPI::Token::Whitespace') ? $Ws : undef
}

sub _last_prev_ws {
  my ($self, $Ws) = @_;
  my $Next = $Ws->previous_sibling;
  return $self->_last_next_ws($Next) if ($Next && $Next->isa('PPI::Token::Whitespace'));
  
  $Ws->isa('PPI::Token::Whitespace') ? $Ws : undef
}


sub _push_kv {
  my ($self, $cfg) = @_;
  $cfg->{$_} or die "'$_' opt missing" for qw/node key value/;
  
  my $Node = $cfg->{node};
  my $indWs = $self->_ws_factory($Node);
  
  my @els = (
    #PPI::Token::Word->new($cfg->{key}),
    bless( { content => "'$cfg->{key}'", separator => "'" }, 'PPI::Token::Quote::Single' ),
    $indWs->(' '),
    PPI::Token::Operator->new('=>'),
    $indWs->(' '),
    bless( { content => "'$cfg->{value}'", separator => "'" }, 'PPI::Token::Quote::Single' )
    #PPI::Token::Quote::Single->new("'$cfg->{value}'")
  );
  
  
  
  my $Last = $Node->last_element;
  if($Last) {
    scream($Last);
    unshift @els, $indWs->("\n"), $indWs->();
    $Last->insert_after( $_ ) and $Last = $_ for @els;
  }
  else {
    $_->delete for ($Node->children);
    $Node->add_element( $_ ) for @els;
    #$Last = shift @els;
    #$Node->add_element($Last);

  }
  
  #$Last = $Node->last_element;
  #
  #scream_color(CYAN.BOLD,$Last);
  #
  #
  #$Last->insert_after( $_ ) and $Last = $_ for @els;
  #
  scream_color(CYAN,$Node);
  
}


sub _first_kword {
  my ($self, $Node, $key) = @_;
  
  List::Util::first {
    $_->isa('PPI::Token::Word') && 
    $_->content eq $key
  } $Node->children;
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

sub _ws_factory {
  my ($self, $El, $addl) = @_;
  my $ind = $self->_cur_line_indent($El);
  $ind .= (' ' x $addl) if ($addl);
  return sub { 
    my $cnt = $_[0] || $ind;
    # accept extra prefix content via scalarref:
    $cnt = $$cnt . $ind if (ref($cnt));
    PPI::Token::Whitespace->new($cnt) 
  }
}

sub _ensure_indents {
  my ($self, $Stmt) = @_;
  
  my $sWs = $self->_ws_factory($Stmt,2);
  my $lWs = $self->_ws_factory($Stmt);
  
  if(my $First = $Stmt->child(0)) {
    $First->insert_before($sWs->(\"\n")) unless($self->_ws_has_newline($First));
  }
  else {
    $Stmt->add_element($sWs->(\"\n"));
  }
  
  my $Last = (reverse $Stmt->children)[0];
  
  $Last->insert_after($lWs->(\"\n")) if (
    scalar($Stmt->children) == 1 ||
    ! $self->_ws_has_newline($Last)
  );
}


sub _ws_has_newline {
  my ($self, $Ws) = @_;

  while($Ws && $Ws->isa('PPI::Token::Whitespace')) {
    return 1 if ($Ws->content =~ /\n/);
    $Ws = $Ws->next_sibling;
  }
  return 0;
}



sub _backup_kword {
  my ($self,$El) = @_;
  
  my $Op = $El->sprevious_sibling;
  $Op && $Op->content eq '=>' or return undef;

  my $kWord = $Op->sprevious_sibling;
  $kWord && $kWord->isa('PPI::Token::Word') ? $kWord : undef
}


sub _backup_nl_ws {
  my $self = shift;
  my $El = shift or return undef;
  my $recur = shift || 0;
  
  $El = $El->previous_sibling if ($El->previous_sibling && !$recur);
  
  return $self->_backup_nl_ws($El->previous_sibling || $El->parent,1) unless (
    $El->content =~ /\n/
  );
  
  $El = $El->next_sibling if ($recur && $El->content =~ /\r?\n$/);
  
  #scream_color(YELLOW,$El);
  
  #$El = $El->find_first('PPI::Token::Whitespace') if ($El->isa('PPI::Node'));
  #
  #scream_color(YELLOW,$El);
  
  return $El
}

sub _cur_line_indent {
  my $self = shift;
  my $El = shift;
  $El = $self->_backup_nl_ws($El) or return '';

  my $spc = (reverse split(/\r?\n/,$El->content))[0] || '';
  while($spc =~ /^\s+$/) {
    $El = $El->next_sibling;
    last unless ($El && $El->isa('PPI::Token::Whitespace'));
    my @p = split(/\S/,$El->content);
    $spc .= shift(@p);
    last unless (scalar(@p) == 0);
  }

  return $spc
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
