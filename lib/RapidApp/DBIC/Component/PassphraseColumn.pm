use strict;
use warnings;

package # hide from PAUSE
  RapidApp::DBIC::Component::PassphraseColumn;
  
# Temp copy of DBIx::Class::PassphraseColumn with fix for null columns.
# will stop using this as soon as the real module merges that fix
# https://github.com/rafl/dbix-class-passphrasecolumn/pull/3

use Class::Load 'load_class';
use Sub::Name 'subname';
use namespace::clean;

use parent 'DBIx::Class';


__PACKAGE__->load_components(qw(InflateColumn::Authen::Passphrase));

__PACKAGE__->mk_classdata('_passphrase_columns');

sub register_column {
    my ($self, $column, $info, @rest) = @_;

    if (my $encoding = $info->{passphrase}) {
        $info->{inflate_passphrase} = $encoding;

        $self->throw_exception(q['passphrase_class' is a required argument])
            unless exists $info->{passphrase_class}
                && defined $info->{passphrase_class};

        my $class = 'Authen::Passphrase::' . $info->{passphrase_class};
        load_class $class;

        my $args = $info->{passphrase_args} || {};
        $self->throw_exception(q['passphrase_args' must be a hash reference])
            unless ref $args eq 'HASH';

        my $encoder = sub {
            my ($val) = @_;
            $class->new(%{ $args }, passphrase => $val)->${\"as_${encoding}"};
        };

        $self->_passphrase_columns({
            %{ $self->_passphrase_columns || {} },
            $column => $encoder,
        });

        if (defined(my $meth = $info->{passphrase_check_method})) {
            my $checker = sub {
                my ($row, $val) = @_;
                my $ppr = $row->get_inflated_column($column) or return 0;
                return $ppr->match($val);
            };

            my $name = join q[::] => $self->result_class, $meth;

            {
                no strict 'refs';
                *$name = subname $name => $checker;
            }
        }
    }

    $self->next::method($column, $info, @rest);
}

sub set_column {
    my ($self, $col, $val, @rest) = @_;

    my $ppr_cols = $self->_passphrase_columns;
    return $self->next::method($col, $ppr_cols->{$col}->($val), @rest)
        if exists $ppr_cols->{$col};

    return $self->next::method($col, $val, @rest);
}

sub new {
    my ($self, $attr, @rest) = @_;

    my $ppr_cols = $self->_passphrase_columns;
    for my $col (keys %{ $ppr_cols }) {
        next unless exists $attr->{$col} && !ref $attr->{$col};
        $attr->{$col} = $ppr_cols->{$col}->( $attr->{$col} );
    }

    return $self->next::method($attr, @rest);
}


1;
