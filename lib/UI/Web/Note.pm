package UI::Web::Note;

use Const::Fast;
use Carp qw(carp croak);
use POSIX qw( strftime );

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

const my $_ENTITY      => 'note';
const my $ROUND_NUMBER => 0.999999;

sub list {
    my ( $self, %args ) = @_;

    my $h_table      = $args{data};
    my $o_mod_config = $args{mod_config};
    my $req_params   = $args{req_params};

    my $root_dir  = $self->app->root_dir;
    my $tpl_path  = $self->app->config->{path}->{templates};
    my $html_path = $self->app->config->{path}->{html};

    my $page_id = $req_params->{fltr_page_id} || 0;
    my $p       = $req_params->{p}            || 0;

    my ( $h_page, $err_str ) = $self->app->ctl->sh->one( 'page', $page_id );

    my $skin_tpl_path = $self->_sync_templates(
        mod      => $_ENTITY,
        skin     => $o_mod_config->{$_ENTITY}->{skin},
        root_dir => $root_dir,
        tpl_path => $tpl_path,
    );

    my $config_html = $self->_build_config_html(
        mod_name  => $_ENTITY,
        tpl_path  => $skin_tpl_path,
        html_path => $html_path,
        o_config  => $o_mod_config,
    );

    my $total_qty = $self->app->ctl->sh->count(
        $_ENTITY,
        {
            page_id => $page_id,
        },
    );
    my $npp = $o_mod_config->{note}->{npp};

    my $list = $self->_build_list(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_item => 'a-list-item.html',
        a_items  => $h_table,
        h_vars   => {
            page_id => $page_id,
            # page_path => $h_page->{path},
        },
    );

    my $paging = $self->_build_paging(
        tpl_path => $skin_tpl_path,
        qty      => $total_qty,
        npp      => $npp,
        p        => $p,
        path     => '/admin/note?do=list&fltr_page_id=' . $page_id . '&p=',
    );

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $skin_tpl_path,
        tpl_name => 'a-list.html',
        h_vars   => {
            page_id     => $page_id,
            page_name   => $h_page->{name},
            list        => $list,
            config_html => $config_html,
            paging      => $paging,
            qty         => $total_qty,
        },
    );

    my $res = $self->app->ctl->gh->render(
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $html_body,
        },
    );

    return {
        body => $res,
    };
}

sub _build_list {
    my ( $self, %args ) = @_;

    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $tpl_item = $args{tpl_item} // q{};
    my $h_table  = $args{a_items}  // {};
    my $h_vars   = $args{h_vars}   // {};

    my $result = q{};

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        $h->{added_dt} = strftime( "%Y-%m-%d %H:%M:%S", localtime( $h->{added} ) );

        my $name;
        {
            my ( $h_nvs, $err_str ) = $self->app->ctl->sh->list(
                'note_version', {
                    note_id => $id,
                    lang_id => 1,
                },
            );
            foreach my $nv_id ( keys %{$h_nvs} ) {
                my $h_nv = $h_nvs->{$nv_id};
                $name = $h_nv->{name};
                last;
            }
        }
        $h->{name} = $name;

        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => $tpl_item,
            h_vars   => {
                %{$h},
                %{$h_vars},
            },
        );
    }

    return $result;
}

sub _build_paging {
    my ( $self, %args ) = @_;

    my $tpl_path = $args{tpl_path};
    my $qty      = $args{qty};
    my $npp      = $args{npp};
    my $p_cur    = $args{p};
    my $path     = $args{path};

    my $result   = q{};
    my $tpl_name = q{};
    my $suffix   = q{};

    my $p_qty  = int( $qty / $npp + $ROUND_NUMBER );
    my $p_last = $p_qty - 1;
    foreach my $p ( 0 .. $p_last ) {
        if   ( $p == $p_cur ) { $tpl_name = 'a-paging-item-cur.html'; }
        else                  { $tpl_name = 'a-paging-item.html'; }

        $suffix = $p ? $p : q{};

        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => $tpl_name,
            h_vars   => {
                p      => $p,
                num    => ( $p + 1 ),
                path   => $path,
                suffix => $suffix,
            },
        );
    }

    return $result;
}

sub _build_config_html {
    my ( $self, %args ) = @_;

    my $tpl_path  = $args{tpl_path};
    my $html_path = $args{html_path};
    my $o_config  = $args{o_config};
    my $mod_name  = $args{mod_name};

    my $result = q{};

    foreach my $param_name ( sort keys %{ $o_config->{$mod_name} } ) {
        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => 'a-config-item.html',
            h_vars   => {
                name  => $param_name,
                value => $o_config->{$mod_name}->{$param_name},
            },
        );
    }

    return $result;
}

sub _sync_templates {
    my ( $self, %args ) = @_;

    my $mod      = $args{mod};
    my $skin     = $args{skin};
    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};

    my $skin_tpl_path = $tpl_path . q{/g/} . $skin;

    if ( !-d $root_dir . $skin_tpl_path ) {
        $self->app->ctl->gh->make_path( path => $skin_tpl_path );
    }

    # copy missing admin templates from default dir
    my $a_adm_tpls = $self->app->ctl->gh->get_files(
        path       => $tpl_path . q{/} . $mod,
        files_only => 1,
    );
    foreach my $h_tpl ( @{$a_adm_tpls} ) {
        my $dst_path = $skin_tpl_path . '/a-' . $h_tpl->{name};

        if ( !-e ( $root_dir . $dst_path ) ) {
            $self->app->ctl->gh->copy_file(
                src_path => $tpl_path . q{/} . $mod . q{/} . $h_tpl->{name},
                dst_path => $dst_path,
            );
        }
    }

    # copy missing front-end templates from default dir
    my $a_front_tpls = $self->app->ctl->gh->get_files(
        path       => $tpl_path . q{/g/} . $mod,
        files_only => 1,
    );
    foreach my $h_tpl ( @{$a_front_tpls} ) {
        my $dst_path = $skin_tpl_path . '/f-' . $h_tpl->{name};

        if ( !-e ( $root_dir . $dst_path ) ) {
            $self->app->ctl->gh->copy_file(
                src_path => $tpl_path . q{/g/} . $mod . q{/} . $h_tpl->{name},
                dst_path => $dst_path,
            );
        }
    }

    return $skin_tpl_path;
}

sub one {
    my ( $self, %args ) = @_;

    my $h_note       = $args{data};
    my $o_mod_config = $args{mod_config};
    my $req_params   = $args{req_params};

    my $root_dir  = $self->app->root_dir;
    my $tpl_path  = $self->app->config->{path}->{templates};
    my $html_path = $self->app->config->{path}->{html};

    my $page_id = $req_params->{page_id} || 0;

    my ( $h_page, $err_str ) = $self->app->ctl->sh->one( 'page', $page_id );

    my $skin_tpl_path = $self->_sync_templates(
        mod      => $_ENTITY,
        skin     => $o_mod_config->{$_ENTITY}->{skin},
        root_dir => $root_dir,
        tpl_path => $tpl_path,
    );

    my $h_images = $h_note->{images};
    my $images   = q{};
    foreach my $id ( sort keys %{$h_images} ) {
        my $h = $h_images->{$id};

        $images .= $self->app->ctl->gh->render(
            tpl_path => $skin_tpl_path,
            tpl_name => 'a-img-item.html',
            h_vars   => $h,
        );
    }

    my $h_versions = $h_note->{versions};
    my $versions   = q{};
    foreach my $id ( sort keys %{$h_versions} ) {
        my $h = $h_versions->{$id};

        $h->{page_id} = $page_id;

        my ( $h_lang, $err_str2 ) = $self->app->ctl->sh->one( 'lang', $h->{lang_id} );
        $h->{lang_isocode} = $h_lang->{isocode};

        $versions .= $self->app->ctl->gh->render(
            tpl_path => $skin_tpl_path,
            tpl_name => 'a-version-item.html',
            h_vars   => $h,
        );
    }

    my ( $h_langs, $err_str3 ) = $self->app->ctl->sh->list('lang');
    my $lang_options = q{};
    foreach my $id ( sort keys %{$h_langs} ) {
        my $h = $h_langs->{$id};

        $lang_options .= $self->app->ctl->gh->render(
            tpl_path => $skin_tpl_path,
            tpl_name => 'a-lang-option.html',
            h_vars   => $h,
        );
    }

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $skin_tpl_path,
        tpl_name => 'a-edit.html',
        h_vars   => {
            %{$h_note},
            images       => $images,
            versions     => $versions,
            lang_options => $lang_options,
        },
    );

    my $res = $self->app->ctl->gh->render(
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $html_body,
        },
    );

    return {
        body => $res,
    };
}

1;
