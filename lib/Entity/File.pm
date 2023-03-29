# TODO: rename to Filemanager
package Entity::File;

use Carp qw(carp croak);
use POSIX ();
use POSIX qw(strftime);

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

#
# TODO: create a way to add more 'global' templates via WebUI (upload or form adding)
#
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

sub backups {
    my ( $self, $params ) = @_;

    my $app = $self->ctl->gh->app;

    my $bkps_path = $app->config->{path}->{bkp};

    my $a_bkps = $self->ctl->gh->get_files(
        path       => $bkps_path,
        files_only => 1,
    );

    #
    # TODO: sort by file name
    #

    return {
        action => 'backups',
        data   => $a_bkps,
    };
}

#
# TODO: add configs to backup
# TODO: check for errors at every stage
#
sub bkpcreate {
    my ( $self, $params ) = @_;

    my $app         = $self->ctl->gh->app;
    my $root_dir    = $app->root_dir;
    my $bkps_path   = $app->config->{path}->{bkp};
    my $site_domain = $app->config->{site}->{domain};

    my $bkp_name = strftime( '%Y%m%d-%H%M%S', localtime );
    my $bkp_path = $bkps_path . q{/} . $bkp_name;

    # 1. create templates backup
    {
        my $tpl_path = $app->config->{path}->{templates} . '/g';

        my $tplbkp_path = $bkp_path . '/tpl';
        $self->ctl->gh->make_path( path => $tplbkp_path );

        $self->ctl->gh->copy_dir(
            src_path => $tpl_path,
            dst_path => $tplbkp_path,
        );
    }

    # 2. create database backup
    {
        # $self->ctl->gh->make_path( path => $bkp_path );
        $self->ctl->sh->backup_create( path => $bkp_path );
    }

    # 3. create html dir backup
    {
        my $html_path = $app->config->{path}->{html};

        my $htmlbkp_path = $bkp_path . '/html';
        $self->ctl->gh->make_path( path => $htmlbkp_path );

        $self->ctl->gh->copy_dir(
            src_path => $html_path,
            dst_path => $htmlbkp_path,
        );
    }

    # 4. archive
    {
        my $bkp_result = $self->ctl->gh->create_zip(
            src_path => $bkp_path,
            dst_path => $bkps_path,
            name     => $site_domain . q{_} . $bkp_name,
        );

        $self->ctl->gh->empty_dir( path => $bkp_path );

        rmdir $root_dir . $bkp_path;
    }

    return {
        url => $app->config->{site}->{host} . '/admin/file?do=backups&msg=success',
    };
}

sub bkpdelete {
    my ( $self, $params ) = @_;

    my $fname = $params->{name};

    my $app       = $self->ctl->gh->app;
    my $bkps_path = $app->config->{path}->{bkp};

    $self->ctl->gh->delete_file(
        file_path => $bkps_path . q{/} . $fname,
    );

    return {
        url => $app->config->{site}->{host} . '/admin/file?do=backups&msg=success',
    };
}

sub bkpdownload {
    my ( $self, $params ) = @_;

    my $fname = $params->{name};

    my $app       = $self->ctl->gh->app;
    my $bkps_path = $app->config->{path}->{bkp};

    my $fh = $self->ctl->gh->get_fh(
        file_path => $bkps_path . q{/} . $fname,
        mode      => q{<},
        binmode   => q{:raw},
    );

    if ( !$fh ) {
        return {
            url => $app->config->{site}->{host} . '/admin/file?do=backups&msg=error',
        };
    }

    return {
        action => 'bkpdownload',
        data   => {
            fhandle => $fh,
            fname   => $fname,
        },
    };
}

sub bkpupload {
    my ( $self, $params, $uploads ) = @_;

    if ( !$uploads->{file} ) {
        return {
            err => 'file is required',
        };
    }

    $self->ctl->gh->upload_bkpfile(
        uploads => $uploads,
    );

    my $app = $self->ctl->gh->app;

    return {
        url => $app->config->{site}->{host} . '/admin/file?do=backups&msg=success',
    };
}

sub bkprestore {
    my ( $self, $params ) = @_;

    my $fname = $params->{name} || q{-};

    my $app       = $self->ctl->gh->app;
    my $root_dir  = $app->root_dir;
    my $bkps_path = $app->config->{path}->{bkp};

    my $err = $self->ctl->gh->extract_bkp(
        src_path => $bkps_path . q{/} . $fname,
        dst_path => $bkps_path,
    );
    if ($err) {
        return {
            err => $err,
        };
    }

    # backup is extracted here
    my ( $bkp_name, undef ) = split /\./, $fname;
    my $tmp_path = $bkps_path . q{/} . $bkp_name;

    # restore templates
    {
        my $src_path = $tmp_path . '/tpl';
        my $dst_path = $app->config->{path}->{templates} . '/g';

        $self->ctl->gh->copy_dir(
            src_path => $src_path,
            dst_path => $dst_path,
        );
    }

    # restore html
    {
        my $src_path = $tmp_path . '/html';
        my $dst_path = $app->config->{path}->{html};

        if ( -d $root_dir . $src_path && -d $root_dir . $dst_path ) {
            $self->ctl->gh->empty_dir(
                path => $app->config->{path}->{html},
            );

            $self->ctl->gh->copy_dir(
                src_path => $src_path,
                dst_path => $dst_path,
            );
        }
    }

    # restore storage
    {
        my $src_path = $tmp_path;
        $self->ctl->sh->backup_restore( path => $src_path );
    }

    $self->ctl->gh->empty_dir(
        path => $tmp_path,
    );
    rmdir( $root_dir . $tmp_path );

    return {
        url => $app->config->{site}->{host} . '/admin/file?do=backups&msg=success',
    };
}

# note image delete
sub nidelete {
    my ( $self, $params ) = @_;

    if ( !$params->{note_id} ) {
        return {
            err => 'note_id is required',
        };
    }

    if ( !$params->{id} ) {
        return {
            err => 'id is required',
        };
    }

    my ( $h_note,  $err_str1 ) = $self->ctl->sh->one( 'note',       $params->{note_id} );
    my ( $h_image, $err_str2 ) = $self->ctl->sh->one( 'note_image', $params->{id} );

    my $app       = $self->ctl->gh->app;
    my $html_path = $app->config->{path}->{html};

    # delete from disk
    $self->ctl->gh->delete_file( file_path => $html_path . $h_image->{path_la} );
    $self->ctl->gh->delete_file( file_path => $html_path . $h_image->{path_sm} );

    # delete from storage
    my $rv = $self->ctl->sh->del( 'note_image', { id => $params->{id} } );

    my $url = $app->config->{site}->{host} . '/admin/note?do=one';
    $url .= '&id=' . $params->{note_id};
    $url .= '&page_id=' . $h_note->{page_id};

    return {
        url => $url,
    };
}

# note image upload
sub niupload {
    my ( $self, $params, $uploads ) = @_;

    if ( !$params->{page_id} ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$params->{id} ) {
        return {
            err => 'id is required',
        };
    }

    # insert to storage, get ID
    my ( $img_id, $err_str ) = $self->ctl->sh->add(
        'note_image',
        {
            note_id => $params->{id},
        },
    );

    # we need to know width and height limits from mod config to scale image
    my ( $h_page, $err_str1 ) = $self->ctl->sh->one( 'page', $params->{page_id} );
    if ($err_str1) {
        return {
            err => $err_str1,
        };
    }
    my $o_mod_config = $self->ctl->gh->get_mod_config(
        mod       => 'note',
        page_id   => $params->{page_id},
        page_path => $h_page->{path},
    );

    # process/scale file
    my $h_result = $self->ctl->gh->upload_img(
        entity_name => 'note',
        entity_id   => $params->{id},
        img_id      => $img_id,
        uploads     => $uploads,
        maxh_la     => $o_mod_config->{note}->{img_maxh_la},
        maxw_la     => $o_mod_config->{note}->{img_maxw_la},
        maxh_sm     => $o_mod_config->{note}->{img_maxh_sm},
        maxw_sm     => $o_mod_config->{note}->{img_maxw_sm},
    );

    # update img path in storage
    $self->ctl->sh->upd(
        'note_image',
        {
            id      => $img_id,
            path_la => $h_result->{path_la},
            path_sm => $h_result->{path_sm},
        },
    );

    my $app = $self->ctl->uih->app;
    my $url = $app->config->{site}->{host} . '/admin/note?do=one';
    $url .= '&id=' . $params->{id};
    $url .= '&page_id=' . $params->{page_id};

    return {
        url => $url,
    };
}

# page file upload
sub pfupload {
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

    my $err_str3 = $self->ctl->gh->upload_file(
        dir     => $page_dir,
        uploads => $uploads,
    );
    if ($err_str3) {
        return {
            err => 'Failed to pfupload: ' . $err_str3,
        };
    }

    my $url = $app->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $params->{page_id};
    $url .= '&fltr_lang_id=' . $params->{lang_id};

    return {
        url => $url,
    };
}

sub pfremove {
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
