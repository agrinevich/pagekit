package Entity::File;

use Carp qw(carp croak);

use App::Files;

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

sub templates {
    my ( $self, $params ) = @_;

    my $app = $self->ctl->uih->app;

    my $tpl_path = $app->config->{path}->{templates} . '/g';
    # my $root_dir = $app->root_dir;

    my $f_cur  = $params->{f} // q{};
    my $f_body = q{};
    if ($f_cur) {
        $f_body = $self->ctl->gh->read_file(
            path => $tpl_path,
            file => $f_cur,
        );
    }

    my $h_files = {};

    my $a_rootfiles = $self->ctl->gh->get_files(
        path       => $tpl_path,
        files_only => 1,
    );
    $h_files->{''} = $a_rootfiles;

    my $a_dirs = $self->ctl->gh->get_files(
        path      => $tpl_path,
        dirs_only => 1,
    );
    foreach my $h_dir ( @{$a_dirs} ) {
        my $dname = $h_dir->{name};

        my $a_files = $self->ctl->gh->get_files(
            path       => $tpl_path . q{/} . $dname,
            files_only => 1,
        );
        $h_files->{$dname} = $a_files;
    }

    my $h_data = {
        h_files => $h_files,
        f_cur   => $f_cur,
        f_body  => $f_body,
    };

    return {
        action => 'templates',
        data   => $h_data,
    };
}

sub tplupdate {
    my ( $self, $params ) = @_;

    my $app = $self->ctl->uih->app;

    my $tpl_path = $app->config->{path}->{templates} . '/g';

    my $f_cur  = $params->{f_cur}  || q{};
    my $f_body = $params->{f_body} || q{};

    $self->ctl->gh->write_file(
        path   => $tpl_path,
        file   => $f_cur,
        f_body => $f_body,
    );

    my $url = $app->config->{site}->{host} . '/admin/file?do=templates';
    $url .= '&f=' . $f_cur;

    return {
        url => $url,
    };
}

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

    $self->ctl->gh->upload_file(
        dir     => $page_dir,
        uploads => $uploads,
    );

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
