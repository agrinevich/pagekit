package Storage::File;

#
# DEPRECATED
# Storable compatibility is version dependent!
#

use Carp qw(carp croak);
use List::Util qw(max);
use Storable qw(nstore retrieve);

use Moo;
use namespace::clean;

has 'app' => (
    is       => 'ro',
    required => 1,
);

has 'dir' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->app->root_dir . $self->app->config->{storage}->{path};
    },
);

our $VERSION = '0.2';

sub list {
    my ( $self, $entity, $h_filters ) = @_;

    my $entity_file = $self->dir . q{/} . lc($entity);

    # init if storage is empty
    if ( !-f $entity_file ) {
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

    my $h_table = retrieve($entity_file);
    if ( !defined $h_table ) {
        return ( undef, "failed to retrieve list from $entity_file" );
    }

    $h_filters //= {};
    my $h_filtered = $self->_filter_by_int( $h_table, $h_filters );

    return ( $h_filtered, undef );
}

sub _filter_by_int {
    my ( $self, $h_table, $h_filters, $level ) = @_;

    $level //= 0;
    return $h_table if $level > 3;

    my %filters = %{$h_filters};
    my @fkeys   = keys %filters;
    if ( !scalar @fkeys ) {
        return $h_table;
    }

    my $fkey   = $fkeys[0];
    my $fval   = $h_filters->{$fkey};
    my %table2 = ();

    foreach my $id ( keys %{$h_table} ) {
        my $h_data = $h_table->{$id};

        if ( $h_data->{$fkey} == $fval ) {
            $table2{$id} = $h_data;
        }
    }

    delete $filters{$fkey};

    return $self->_filter_by_int( \%table2, \%filters, $level + 1 );
}

sub one {
    my ( $self, $entity, $id ) = @_;

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return ( undef, $err_str );
    }

    my $h_data = exists $h_table->{$id} ? $h_table->{$id} : undef;
    if ( !defined $h_data ) {
        return ( undef, "$entity $id does not exist" );
    }

    return ( $h_data, undef );
}

sub add {
    my ( $self, $entity, $h_data ) = @_;

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return ( undef, $err_str );
    }

    my $max_id = max( keys %{$h_table} ) || 0;
    my $id     = 1 + $max_id;
    $h_data->{id} = $id;
    $h_table->{$id} = $h_data;

    $err_str = $self->_save( $entity, $h_table );

    return ( $id, $err_str );
}

sub upd {
    my ( $self, $entity, $h_data ) = @_;

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return $err_str;
    }

    my $id = $h_data->{id};
    if ( !$id > 0 ) {
        return 'id is required';
    }

    $h_table->{$id} = $h_data;

    $err_str = $self->_save( $entity, $h_table );

    return $err_str;
}

sub del {
    my ( $self, $entity, $id ) = @_;

    if ( !$id > 0 ) {
        return 'id is required';
    }

    my ( $h_table, $err_str ) = $self->list($entity);
    if ($err_str) {
        return $err_str;
    }

    delete $h_table->{$id};

    $err_str = $self->_save( $entity, $h_table );

    return $err_str;
}

sub _save {
    my ( $self, $entity, $h_table ) = @_;

    my $entity_file = $self->dir . q{/} . lc($entity);

    my $success = nstore( $h_table, $entity_file );
    if ( !$success ) {
        return 'failed to save ' . $entity_file;
    }

    return;
}

1;
