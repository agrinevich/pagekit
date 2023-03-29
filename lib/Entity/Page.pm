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

    my $parent_path = $self->_build_path( id => $self->parent_id );
    my $path        = $parent_path . q{/} . $self->nick;
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

    #
    # TODO: copy marks from parent page
    #

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

    # FIXME: if parent_id changed - move all dirs and files

    # FIXME: if nick changed - move all dirs and files

    my $parent_path = $self->_build_path( id => $self->parent_id );
    my $path        = $parent_path . q{/} . $self->nick;
    $self->path($path);

    my ( $h_found, $err_str ) = $self->ctl->sh->list( 'page', { path => $path } );
    my %found = %{$h_found};
    delete $found{ $self->id };
    if ( scalar keys %found ) {
        return {
            err => "page $path exists already",
        };
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

    my $app = $self->ctl->sh->app;
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

#
# recursive
#
sub _build_path {
    my ( $self, %args ) = @_;

    my $id = $args{id};

    my ( $h_data, $err_str ) = $self->ctl->sh->one( 'page', $id );
    if ( !$h_data ) {
        return q{};
    }

    my $parent_id = $h_data->{parent_id} // 0;
    my $nick      = $h_data->{nick};

    #
    # TODO: fix redundant slash for some cases
    #
    my $path = $nick ? q{/} . $nick : q{};

    if ( $parent_id > 0 ) {
        $path = $self->_build_path(
            id => $parent_id,
        ) . $path;
    }

    return $path;
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
