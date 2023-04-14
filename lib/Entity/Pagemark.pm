package Entity::Pagemark;

use Carp qw(carp croak);
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

has 'page_id' => (
    is      => 'rw',
    default => undef,
);

has 'lang_id' => (
    is      => 'rw',
    default => undef,
);

has 'name' => (
    is      => 'rw',
    default => undef,
);

has 'value' => (
    is      => 'rw',
    default => undef,
);

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
    my $lang_id = $filters{lang_id} || 1;

    my ( $h_table, $err_str ) = $self->ctl->sh->list(
        'pagemark', {
            'page_id' => $page_id,
            'lang_id' => $lang_id,
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
            err => 'id is required to fetch one pagemark',
        };
    }

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'pagemark', $self->id );
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
            err => 'page_id is required to add pagemark',
        };
    }

    if ( !$self->lang_id ) {
        return {
            err => 'lang_id is required to add pagemark',
        };
    }

    if ( !$self->name ) {
        return {
            err => 'name is required to add pagemark',
        };
    }

    my ( $h_duplicates, $err_str ) = $self->ctl->sh->list(
        'pagemark',
        {
            name    => $self->name,
            page_id => $self->page_id,
            lang_id => $self->lang_id,
        },
    );
    if ( scalar keys %{$h_duplicates} ) {
        return {
            err => 'pagemark ' . $self->name . ' exists already',
        };
    }

    # copy mark for all langs
    my ( $h_langs, $err_str4 ) = $self->ctl->sh->list('lang');
    foreach my $lang_id ( keys %{$h_langs} ) {
        my ( $id, $err_str2 ) = $self->ctl->sh->add(
            'pagemark', {
                page_id => $self->page_id,
                lang_id => $lang_id,
                name    => $self->name,
                value   => $self->value,
            },
        );
        if ($err_str2) {
            return {
                err => 'failed to add pagemark: ' . $err_str2,
            };
        }
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $self->page_id;
    $url .= '&fltr_lang_id=' . $self->lang_id;

    return {
        url => $url,
    };
}

sub upd {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to upd pagemark',
        };
    }

    if ( !$self->name ) {
        return {
            err => 'name is required to upd pagemark',
        };
    }

    if ( !$self->page_id ) {
        return {
            err => 'page_id is required to upd pagemark',
        };
    }

    if ( !$self->lang_id ) {
        return {
            err => 'lang_id is required to upd pagemark',
        };
    }

    my ( $h_found, $err_str ) = $self->ctl->sh->list(
        'pagemark',
        {
            name    => $self->name,
            page_id => $self->page_id,
            lang_id => $self->lang_id,
        },
    );
    my %found = %{$h_found};
    delete $found{ $self->id };
    if ( scalar keys %found ) {
        return {
            err => 'pagemark ' . $self->name . ' exists already',
        };
    }

    my $err_str2 = $self->ctl->sh->upd(
        'pagemark', {
            id      => $self->id,
            page_id => $self->page_id,
            lang_id => $self->lang_id,
            name    => $self->name,
            value   => $self->value,
        },
    );
    if ($err_str2) {
        return {
            err => 'failed to upd pagemark: ' . $err_str2,
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $self->page_id;
    $url .= '&fltr_lang_id=' . $self->lang_id;

    return {
        url => $url,
    };
}

sub del {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to delete pagemark',
        };
    }

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'pagemark', $self->id );
    if ($err_str) {
        return {
            err => 'failed to read pagemark: ' . $err_str,
        };
    }
    if ( !$h_data ) {
        return {
            err => 'pagemark ' . $self->id . ' does not exist',
        };
    }

    $err_str = $self->ctl->sh->del( 'pagemark', { id => $self->id } );
    if ($err_str) {
        return {
            err => $err_str,
        };
    }

    my $app     = $self->ctl->sh->app;
    my $page_id = $h_data->{page_id};
    my $lang_id = $h_data->{lang_id};
    my $url     = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $page_id;
    $url .= '&fltr_lang_id=' . $lang_id;

    return {
        url => $url,
    };
}

1;
