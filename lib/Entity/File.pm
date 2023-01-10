package Entity::File;

use Carp qw(carp croak);
use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'ctl' => (
    is       => 'ro',
    required => 1,
);

has 'name' => (
    is      => 'rw',
    default => undef,
);

has 'size' => (
    is      => 'rw',
    default => undef,
);

# sub list {
#     my ( $self, $h_filters ) = @_;

#     # extract filters
#     my %filters;
#     foreach my $k ( keys %{$h_filters} ) {
#         if ( $k =~ /^fltr/i ) {
#             my @k_parts = split /\_/, $k;
#             shift @k_parts;
#             my $field = join q{_}, @k_parts;

#             $filters{$field} = $h_filters->{$k};
#         }
#     }

#     my ( $h_table, $err_str ) = $self->ctl->sh->list( 'page', \%filters );
#     if ($err_str) {
#         return {
#             err => $err_str,
#         };
#     }

#     return {
#         action => 'list',
#         data   => $h_table,
#     };
# }

# sub one {
#     my ($self) = @_;

#     if ( !$self->id ) {
#         return {
#             err => 'id is required to fetch one page',
#         };
#     }

#     my ( $h_data, $err_str ) = $self->ctl->sh->one( 'page', $self->id );
#     if ($err_str) {
#         return {
#             err => $err_str,
#         };
#     }

#     $h_data->{ctl} = $self->ctl;

#     return {
#         action => 'one',
#         data   => $h_data,
#     };
# }

sub upload {
    my ( $self, $params, $uploads ) = @_;

    if ( !$params->{page_id} ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$params->{lang_id} ) {
        return {
            err => 'lang_id is required',
        };
    }

    my ( $h_page, $err_str ) = $self->ctl->sh->one( 'page', $params->{page_id} );

    my ( $h_lang, $err_str2 ) = $self->ctl->sh->one( 'lang', $params->{lang_id} );
    my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};

    my $app = $self->ctl->uih->app;

    my $html_path = $app->config->{path}->{html};
    my $page_dir  = $app->root_dir . $html_path . $lang_path . $h_page->{path};

    my $file = $uploads->{file};

    my $file_name = $file->basename;
    my @chunks    = split /[.]/, $file_name;
    my $ext       = pop @chunks;
    my $name      = join q{}, @chunks;
    $name =~ s/[^\w\-\_]//g;
    if ( !$name ) {
        $name = time;
    }

    my $file_tmp = $file->path();
    my $new_file = $page_dir . q{/} . $name . q{.} . $ext;
    rename $file_tmp, $new_file;

    my $mode_readable = oct '644';
    chmod $mode_readable, $new_file;

    my $url = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $params->{page_id};
    $url .= '&fltr_lang_id=' . $params->{lang_id};

    return {
        url => $url,
    };
}

sub remove {
    my ( $self, $params ) = @_;

    if ( !$params->{page_id} ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$params->{lang_id} ) {
        return {
            err => 'lang_id is required',
        };
    }

    if ( !$params->{name} ) {
        return {
            err => 'file name is required',
        };
    }

    my ( $h_page, $err_str ) = $self->ctl->sh->one( 'page', $params->{page_id} );

    my ( $h_lang, $err_str2 ) = $self->ctl->sh->one( 'lang', $params->{lang_id} );
    my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};

    my $app = $self->ctl->uih->app;

    my $html_path = $app->config->{path}->{html};
    my $page_dir  = $app->root_dir . $html_path . $lang_path . $h_page->{path};
    my $file      = $page_dir . q{/} . $params->{name};

    unlink($file);

    my $url = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $params->{page_id};
    $url .= '&fltr_lang_id=' . $params->{lang_id};

    return {
        url => $url,
    };
}

#
# recursive
#
# sub _build_path {
#     my ( $self, %args ) = @_;

#     my $id = $args{id};

#     my ( $h_data, $err_str ) = $self->ctl->sh->one( 'page', $id );
#     if ( !$h_data ) {
#         return q{};
#     }

#     my $parent_id = $h_data->{parent_id} // 0;
#     my $nick      = $h_data->{nick};

#     my $path = $nick ? q{/} . $nick : q{};

#     if ( $parent_id > 0 ) {
#         $path = $self->_build_path(
#             id => $parent_id,
#         ) . $path;
#     }

#     return $path;
# }

# sub generate {
#     my ($self) = @_;

#     my $err_str = $self->ctl->gh->gen_pages();
#     if ($err_str) {
#         return {
#             err => $err_str,
#         };
#     }

#     my $app = $self->ctl->uih->app;
#     my $url = $app->config->{site}->{host} . q{/admin/page?do=list&msg=success};

#     return {
#         url => $url,
#     };
# }

1;
