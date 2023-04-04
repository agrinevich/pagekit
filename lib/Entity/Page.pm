package Entity::Page;

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

has 'parent_id' => (
    is      => 'rw',
    default => undef,
);

has 'mod_id' => (
    is      => 'rw',
    default => 0,
);

has 'hidden' => (
    is      => 'rw',
    default => 0,
);

has 'prio' => (
    is      => 'rw',
    default => 0,
);

has 'nick' => (
    is      => 'rw',
    default => undef,
);

has 'name' => (
    is      => 'rw',
    default => undef,
);

has 'path' => (
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

    my ( $h_table, $err_str ) = $self->ctl->sh->list( 'page', \%filters );
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
            err => 'id is required to fetch one page',
        };
    }

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'page', $self->id );
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

    if ( !$self->parent_id ) {
        return {
            err => 'parent_id is required to add page',
        };
    }

    if ( !$self->nick ) {
        return {
            err => 'nick is required to add page',
        };
    }

    my ( $h_parent, $err_str1 ) = $self->ctl->sh->one( 'page', $self->parent_id );
    my $path;
    if ( $h_parent->{path} eq q{/} ) {
        $path = $h_parent->{path} . $self->nick;
    }
    else {
        $path = $h_parent->{path} . q{/} . $self->nick;
    }
    $self->path($path);

    my ( $h_duplicates, $err_str ) = $self->ctl->sh->list( 'page', { path => $path } );
    if ( scalar keys %{$h_duplicates} ) {
        return {
            err => "page $path exists already",
        };
    }

    if ( !$self->name ) {
        $self->name = $self->nick;
    }

    my ( $id, $err_str2 ) = $self->ctl->sh->add(
        'page', {
            parent_id => $self->parent_id,
            nick      => $self->nick,
            name      => $self->name,
            path      => $self->path,
        },
    );
    if ($err_str2) {
        return {
            err => 'failed to add page: ' . $err_str2,
        };
    }
    $self->id($id);

    # copy marks from parent page
    my ( $h_marks, $err3 ) = $self->ctl->sh->list( 'pagemark', { page_id => $self->parent_id } );
    if ($err3) {
        return $err3;
    }
    foreach my $mark_id ( keys %{$h_marks} ) {
        my $h_mark = $h_marks->{$mark_id};

        my ( $id, $err_str21 ) = $self->ctl->sh->add(
            'pagemark', {
                page_id => $id,
                lang_id => $h_mark->{lang_id},
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
    my $url = $app->config->{site}->{host} . q{/admin/page?do=list};

    return {
        url => $url,
    };
}

sub upd {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to upd page',
        };
    }

    if ( !$self->nick && $self->id > 1 ) {
        return {
            err => 'nick is required to upd page',
        };
    }

    if ( !$self->parent_id ) {
        $self->parent_id(0);
    }
    if ( !$self->parent_id && $self->id > 1 ) {
        return {
            err => 'parent_id is required to upd page',
        };
    }

    my $app = $self->ctl->sh->app;

    my ( $h_page,   $err_str1 ) = $self->ctl->sh->one( 'page', $self->id );
    my ( $h_parent, $err_str3 ) = $self->ctl->sh->one( 'page', $self->parent_id );

    # if path changed - move all dirs and files
    if ( $h_page->{parent_id} != $self->parent_id || $h_page->{nick} ne $self->nick ) {
        my $old_path = $h_page->{path};

        my $new_path;
        if ( $h_parent->{path} eq q{/} ) {
            $new_path = $h_parent->{path} . $self->nick;
        }
        else {
            $new_path = $h_parent->{path} . q{/} . $self->nick;
        }
        $self->path($new_path);

        my ( $h_found, $err_str ) = $self->ctl->sh->list( 'page', { path => $new_path } );
        my %found = %{$h_found};
        delete $found{ $self->id };
        if ( scalar keys %found ) {
            return {
                err => "page $new_path exists already",
            };
        }

        # move all dirs and files
        my $err_str4 = $self->ctl->gh->move_dir(
            src_path => $app->config->{path}->{html} . $old_path,
            dst_path => $app->config->{path}->{html} . $new_path,
        );
        if ($err_str4) {
            return {
                err => 'failed to move_dir: ' . $err_str4,
            };
        }
    }
    else {
        $self->path( $h_page->{path} );
    }

    if ( !$self->name ) {
        $self->name = $self->nick;
    }

    my $err_str2 = $self->ctl->sh->upd(
        'page', {
            id        => $self->id,
            parent_id => $self->parent_id,
            hidden    => $self->hidden,
            prio      => $self->prio,
            mod_id    => $self->mod_id,
            nick      => $self->nick,
            name      => $self->name,
            path      => $self->path,
        },
    );
    if ($err_str2) {
        return {
            err => 'failed to upd page: ' . $err_str2,
        };
    }

    my $url = $app->config->{site}->{host} . q{/admin/page?do=one&id=} . $self->id;

    return {
        url => $url,
    };
}

sub del {
    my ($self) = @_;

    my $err_str = $self->_go_del( { page_id => $self->id } );
    if ($err_str) {
        return {
            err => $err_str,
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . q{/admin/page?do=list};

    return {
        url => $url,
    };
}

#
# recursive
#
sub _go_del {
    my ( $self, $h_args ) = @_;

    my $page_id = $h_args->{page_id};

    return 'positive page_id required!' if !$page_id;

    return 'do not delete root page!' if $page_id == 1;

    my ( $h_page, $err_str1 ) = $self->ctl->sh->one( 'page', $page_id );
    if ($err_str1) {
        return $err_str1;
    }

    if ( $h_page->{mod_id} == 1 ) {
        return 'Delete notes for page ' . $h_page->{nick} . ' then try again.';
    }

    my ( $h_children, $err_str3 ) = $self->ctl->sh->list( 'page', { parent_id => $page_id } );
    if ($err_str3) {
        return $err_str3;
    }

    foreach my $child_id ( keys %{$h_children} ) {
        my $err = $self->_go_del( { page_id => $child_id } );
        croak($err) if $err;
    }

    my $err_str2 = $self->ctl->sh->del( 'pagemark', { page_id => $page_id } );
    if ($err_str2) {
        return $err_str2;
    }

    # del files and dir for each language
    my ( $h_langs, $err_str5 ) = $self->ctl->sh->list('lang');
    foreach my $lang_id ( keys %{$h_langs} ) {
        my $h_lang = $h_langs->{$lang_id};

        my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};
        my $page_path = $lang_path . $h_page->{path};

        $self->ctl->gh->empty_dir( path => $page_path );

        rmdir( $self->ctl->gh->app->root_dir . $page_path );
    }

    my $err_str4 = $self->ctl->sh->del( 'page', { id => $page_id } );
    if ($err_str4) {
        return $err_str4;
    }

    return;
}

sub generate {
    my ($self) = @_;

    my $err_str = $self->ctl->gh->gen_pages();
    if ($err_str) {
        return {
            err => $err_str,
        };
    }

    my $app = $self->ctl->uih->app;
    my $url = $app->config->{site}->{host} . q{/admin/page?do=list&msg=success};

    return {
        url => $url,
    };
}

1;
