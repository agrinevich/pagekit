package Entity::Lang;

use Carp qw(croak);
use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'ctl' => (
    is       => 'ro',
    required => 1,
);

has 'id' => (
    is      => 'rw',
    default => undef,
);

has 'isocode' => (
    is      => 'rw',
    default => undef,
);

has 'nick' => (
    is      => 'rw',
    default => undef,
);

sub list {
    my ( $self, $h_params ) = @_;

    my ( $h_table, $err_str ) = $self->ctl->sh->list('lang');
    if ($err_str) {
        return {
            err => $err_str,
        };
    }

    return {
        action => 'list',
        data   => $h_table,
    };
}

sub one {
    my ( $self, $h_params ) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to fetch one lang',
        };
    }

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'lang', $self->id );
    if ($err_str) {
        return {
            err => $err_str,
        };
    }

    $h_data->{ctl} = $self->ctl;

    return {
        action => 'one',
        data   => $h_data,
    };
}

sub add {
    my ($self) = @_;

    if ( !$self->isocode ) {
        return {
            err => 'aborted adding lang: isocode is required',
        };
    }

    my ( $h_duplicates, $err_str ) = $self->ctl->sh->list( 'lang', { isocode => $self->isocode } );
    if ( scalar keys %{$h_duplicates} ) {
        return {
            err => 'lang ' . $self->isocode . ' exists already',
        };
    }

    my ( $id, $err_str2 ) = $self->ctl->sh->add(
        'lang', {
            isocode => $self->isocode,
            nick    => $self->nick,
        },
    );
    if ($err_str2) {
        return {
            err => 'failed to add lang: ' . $err_str2,
        };
    }
    $self->id($id);

    # copy all pagemarks from primary lang version
    my ( $h_marks, $err3 ) = $self->ctl->sh->list( 'pagemark', { lang_id => 1 } );
    if ($err3) {
        return $err3;
    }
    foreach my $mark_id ( keys %{$h_marks} ) {
        my $h_mark = $h_marks->{$mark_id};

        my ( $id, $err_str21 ) = $self->ctl->sh->add(
            'pagemark', {
                page_id => $h_mark->{page_id},
                lang_id => $id,
                name    => $h_mark->{name},
                value   => $h_mark->{value},
            },
        );
        if ($err_str21) {
            return {
                err => 'failed to copypaste pagemark: ' . $err_str21,
            };
        }

    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . q{/admin/lang?do=list};

    return {
        url => $url,
    };
}

sub upd {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to upd lang',
        };
    }

    if ( !$self->isocode ) {
        return {
            err => 'isocode is required to upd lang',
        };
    }

    my $err_str = $self->ctl->sh->upd(
        'lang', {
            id      => $self->id,
            isocode => $self->isocode,
            nick    => $self->nick,
        },
    );
    if ($err_str) {
        return {
            err => 'failed to upd lang: ' . $err_str,
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . q{/admin/lang?do=one&id=} . $self->id;

    return {
        url => $url,
    };
}

sub del {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to delete lang',
        };
    }

    if ( $self->id == 1 ) {
        return {
            err => 'do not delete primary lang',
        };
    }

    # TODO: delete all note versions and files/dirs
    # TODO: delete all page versions files/dirs

    # delete all dependent pagemarks first
    # my $err_str2 = $self->ctl->sh->del( 'pagemark', { lang_id => $self->id } );
    # if ($err_str2) {
    #     return {
    #         err => $err_str2,
    #     };
    # }

    # my $err_str = $self->ctl->sh->del( 'lang', { id => $self->id } );
    # if ($err_str) {
    #     return {
    #         err => $err_str,
    #     };
    # }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . q{/admin/lang?do=list};

    return {
        url => $url,
    };
}

1;
