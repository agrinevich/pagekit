package Entity::Note;

use Carp qw(carp croak);

use Moo;
use namespace::clean;

has 'ctl' => (
    is       => 'ro',
    required => 1,
);

has 'id' => (
    is      => 'rw',
    default => undef,
);

has 'page_id' => (
    is      => 'rw',
    default => undef,
);

has 'hidden' => (
    is      => 'rw',
    default => 0,
);

has 'prio' => (
    is      => 'rw',
    default => 0,
);

has 'added' => (
    is      => 'rw',
    default => 0,
);

has 'nick' => (
    is      => 'rw',
    default => undef,
);

has 'price' => (
    is      => 'rw',
    default => 0,
);

has 'name' => (
    is      => 'rw',
    default => undef,
);

our $VERSION = '0.2';

sub list {
    my ( $self, $h_filters ) = @_;

    # extract filters
    my %filters;
    foreach my $k ( keys %{$h_filters} ) {
        if ( $k =~ /^fltr/i ) {
            my @k_parts = split /\_/, $k;
            shift @k_parts;
            my $field = join q{_}, @k_parts;

            $filters{$field} = $h_filters->{$k};
        }
    }

    my $page_id = $filters{page_id} || 1;

    my ( $h_table, $err_str ) = $self->ctl->sh->list(
        'note', {
            'page_id' => $page_id,
        },
    );
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
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required',
        };
    }

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'note', $self->id );
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

    if ( !$self->page_id ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$self->name ) {
        return {
            err => 'name in primary lang is required',
        };
    }

    my $added = time;

    my ( $id, $err_str ) = $self->ctl->sh->add(
        'note', {
            page_id => $self->page_id,
            added   => $added,
        },
    );
    if ($err_str) {
        return {
            err => 'failed to add note: ' . $err_str,
        };
    }
    $self->id($id);

    $self->nick($id);
    my $err_str2 = $self->ctl->sh->upd(
        'note', {
            id   => $self->id,
            nick => $self->nick,
        },
    );
    if ($err_str2) {
        return {
            err => 'failed to upd note: ' . $err_str2,
        };
    }

    my ( $nv_id, $err_str3 ) = $self->ctl->sh->add(
        'note_version', {
            note_id => $self->id,
            lang_id => 1,
            name    => $self->name,
        },
    );
    if ($err_str3) {
        return {
            err => 'failed to add note_version: ' . $err_str3,
        };
    }

    #
    # TODO: copy note_version for all langs
    #

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/note?do=list';
    $url .= '&fltr_page_id=' . $self->page_id;

    return {
        url => $url,
    };
}

sub upd {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required',
        };
    }

    # TODO: clear nick
    # TODO: clear prio
    # TODO: clear price

    if ( !$self->nick ) {
        return {
            err => 'nick is required',
        };
    }

    my $err_str = $self->ctl->sh->upd(
        'note', {
            id    => $self->id,
            nick  => $self->nick,
            prio  => $self->prio,
            price => $self->price,
        },
    );
    if ($err_str) {
        return {
            err => 'failed to upd note: ' . $err_str,
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/note?do=one';
    $url .= '&id=' . $self->id;
    $url .= '&page_id=' . $self->page_id;

    return {
        url => $url,
    };
}

# sub del {
#     my ($self) = @_;

#     if ( !$self->id ) {
#         return {
#             err => 'id is required',
#         };
#     }

#     my ( $h_data, $err_str ) = $self->ctl->sh->one( 'note', $self->id );
#     if ($err_str) {
#         return {
#             err => 'failed to read note: ' . $err_str,
#         };
#     }
#     if ( !$h_data ) {
#         return {
#             err => 'note ' . $self->id . ' does not exist',
#         };
#     }

#     $err_str = $self->ctl->sh->del( 'note', { id => $self->id } );
#     if ($err_str) {
#         return {
#             err => $err_str,
#         };
#     }

#     #
#     # FIXME: delete from note_version, note_image
#     #

#     my $app     = $self->ctl->sh->app;
#     my $page_id = $h_data->{page_id};
#     my $url     = $app->config->{site}->{host} . '/admin/note?do=list';
#     $url .= '&fltr_page_id=' . $page_id;

#     return {
#         url => $url,
#     };
# }

1;
