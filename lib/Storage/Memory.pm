package Storage::Memory;

use Carp qw(carp croak);
use List::Util qw(max);

use Moo;
use namespace::clean;

has 'app' => (
    is       => 'ro',
    required => 1,
);

our $VERSION = '0.2';

my %db = ();

sub list {
    my ( $self, $entity ) = @_;

    if ( !exists $db{$entity} ) {
        my $h_data = $self->app->ctl->dispatch(
            lc($entity),
            { do => 'get_default_row' },
        );
        my $h_table = {
            1 => $h_data,
        };
        my $err_str = $self->_save( $entity, $h_table );
        if ($err_str) {
            return ( undef, 'failed to init: ' . $err_str );
        }
    }

    my $h_table = $db{$entity};

    return ( $h_table, undef );
}

sub one {
    my ( $self, $entity, $id ) = @_;

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return ( undef, $err_str );
    }

    my $h_data = exists $h_table->{$id} ? $h_table->{$id} : undef;
    if ( !$h_data ) {
        return ( undef, "$entity $id does not exist" );
    }

    return ( $h_data, undef );
}

sub add {
    my ( $self, $entity, $h_data ) = @_;

    if ( !exists $db{$entity} ) {
        return ( undef, '"' . $entity . '" doesnt exist in storage' );
    }

    my $h_table = $db{$entity};

    my $id = 1 + max( keys %{$h_table} );
    $h_data->{id} = $id;
    $h_table->{$id} = $h_data;

    my $err_str = $self->_save( $entity, $h_table );

    return ( $id, undef );
}

sub upd {
    my ( $self, $entity, $h_data ) = @_;

    if ( !exists $db{$entity} ) {
        return '"' . $entity . '" doesnt exist in storage';
    }

    my $h_table = $db{$entity};

    my $id = $h_data->{id};
    if ( !$id > 0 ) {
        return 'id is required';
    }

    $h_table->{$id} = $h_data;

    my $err_str = $self->_save( $entity, $h_table );

    return;
}

sub del {
    my ( $self, $entity, $id ) = @_;

    if ( !exists $db{$entity} ) {
        return '"' . $entity . '" doesnt exist in storage';
    }

    if ( !$id > 0 ) {
        return 'id is required';
    }

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return $err_str;
    }

    delete $h_table->{$id};

    $err_str = $self->_save( $entity, $h_table );

    return;
}

sub _save {
    my ( $self, $entity, $h_table ) = @_;

    $db{$entity} = $h_table;

    return;
}

1;
