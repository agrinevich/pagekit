package Generator::Base;

use Carp qw(carp croak);
use English qw( -no_match_vars );
use POSIX ();
use POSIX qw(strftime);
use Path::Tiny; # path, spew_utf8
use Text::Xslate qw(mark_raw html_escape);
# use Data::Dumper;

use Generator::Standard;
use Generator::Note;
use App::Files;
use App::Config;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

has 'snippets' => (
    is => 'rw',
);

# pre-cache html snippets
sub BUILD {
    my ( $self, $h_args ) = @_;

    my $app          = $h_args->{app};
    my $root_dir     = $self->app->root_dir;
    my $snippet_path = $self->app->config->{path}->{templates} . '/g/snippet';

    my $h_snippets = _get_snippets( dir => $root_dir . $snippet_path );

    $self->snippets($h_snippets);

    return;
}

sub _get_snippets {
    my (%args) = @_;

    my $dir = $args{dir};

    my $a_files = App::Files::get_files(
        dir        => $dir,
        files_only => 1,
    );

    my %result = ();

    foreach my $h_file ( @{$a_files} ) {
        my $fname = $h_file->{name};
        my $fbody = App::Files::read_file( file => $dir . q{/} . $fname );
        my ( $basename, $fext ) = split /[.]/, $fname;
        $result{$basename} = $fbody;
    }

    return \%result;
}

sub render {
    my ( $self, %args ) = @_;

    my $tpl_path = $args{tpl_path};
    my $tpl_name = $args{tpl_name};
    my $h_vars   = $args{h_vars};

    my $root_dir = $self->app->root_dir;

    my $h_global = $self->snippets();

    my %merged = ();
    if ( scalar keys %{$h_global} ) {
        %merged = %{$h_global};

        # override it if you have another mark value for current page
        while ( my ( $k, $v ) = each( %{$h_vars} ) ) {
            $merged{$k} = $v;
        }
    }
    else {
        %merged = %{$h_vars};
    }

    foreach my $k ( keys %merged ) {
        $merged{$k} = mark_raw( $merged{$k} );
    }

    my $tx = Text::Xslate->new(
        path        => [ $root_dir . $tpl_path ],
        syntax      => 'TTerse',
        input_layer => ':utf8',
        cache       => 0,
    );

    return $tx->render( $tpl_name, \%merged ) || croak __PACKAGE__ . ' failed to render template';
}

sub write_html {
    my ( $self, $h_vars, $h_args ) = @_;

    my $tpl_path = $h_args->{tpl_path};
    my $tpl_file = $h_args->{tpl_file};
    my $out_file = $h_args->{out_file};

    my $html = $self->render(
        tpl_path => $tpl_path,
        tpl_name => $tpl_file,
        h_vars   => $h_vars,
    );

    path($out_file)->spew_utf8($html);

    return;
}

sub do_escape {
    my ( $self, $str ) = @_;
    return html_escape($str);
}

sub gen_pages {
    my ($self) = @_;

    my $root_dir  = $self->app->root_dir;
    my $site_host = $self->app->config->{site}->{host};
    my $html_path = $self->app->config->{path}->{html};
    my $tpl_path  = $self->app->config->{path}->{templates} . '/g';

    my ( $h_langs, $err_str )  = $self->app->ctl->sh->list('lang');
    my ( $h_pages, $err_str2 ) = $self->app->ctl->sh->list('page');
    my ( $h_mods,  $err_str3 ) = $self->app->ctl->sh->list('mod');

    my $cur_date = strftime( '%Y-%m-%d', localtime );
    my $a_map    = [];

    foreach my $id ( sort keys %{$h_langs} ) {
        my $h = $h_langs->{$id};

        my $lang_path = $h->{nick} ? q{/} . $h->{nick} : q{};

        $self->go_tree(
            site_host => $site_host,
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            lang_id   => $id,
            lang_path => $lang_path,
            parent_id => 0,
            level     => 0,
            items     => $h_pages,
            langs     => $h_langs,
            mods      => $h_mods,
            a_map     => $a_map,
            cur_date  => $cur_date,
        );
    }

    my $map_items = join q{}, @{$a_map};
    my $map_file  = $root_dir . $html_path . '/sitemap.xml';
    $self->write_html(
        {
            items => $map_items,
        },
        {
            tpl_path => $tpl_path,
            tpl_file => 'sitemap.xml',
            out_file => $map_file,
        },
    );

    return;
}

sub go_tree {
    my ( $self, %args ) = @_;

    my $site_host = $args{site_host} // q{};
    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $html_path = $args{html_path} // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $parent_id = $args{parent_id} // 0;
    my $level     = $args{level}     // 0;
    my $h_pages   = $args{items}     // {};
    my $h_langs   = $args{langs}     // {};
    my $h_mods    = $args{mods}      // {};
    my $a_map     = $args{a_map}     // [];
    my $cur_date  = $args{cur_date}  // q{};

    if ( $level > 5 ) {
        carp('recursion level > 5');
        return;
    }

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        if ( $h->{parent_id} != $parent_id ) {
            next;
        }

        my ( $d_navi, $m_navi ) = $self->_navi_links(
            root_dir  => $root_dir,
            tpl_path  => $tpl_path . '/page',
            lang_id   => $lang_id,
            lang_path => $lang_path,
            id_cur    => $id,
            parent_id => $parent_id,
        );

        my ( $lang_links, $meta_tags ) = $self->_lang_links(
            site_host => $site_host,
            root_dir  => $root_dir,
            tpl_path  => $tpl_path . '/page',
            page_path => $h->{path},
            lang_id   => $lang_id,
            lang_path => $lang_path,
            langs     => $h_langs,
        );

        my $breadcrumbs = $self->_breadcrumbs(
            page_id   => $id,
            lang_id   => $lang_id,
            lang_path => $lang_path,
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
        );

        if ( !$h->{hidden} ) {
            my $map_item = $self->render(
                tpl_path => $tpl_path,
                tpl_name => "sitemap-item.xml",
                h_vars   => {
                    path      => $lang_path . $h->{path},
                    site_host => $site_host,
                    cur_date  => $cur_date,
                },
            );
            push @{$a_map}, $map_item;
        }

        my $mod_id    = $h->{mod_id};
        my $page_type = 'Standard';
        if ( $mod_id > 0 && exists $h_mods->{$mod_id} ) {
            $page_type = ucfirst $h_mods->{$mod_id}->{name};
        }
        my $gen_class = 'Generator::' . $page_type;

        $gen_class->gen(
            sh            => $self->app->ctl->sh,
            gh            => $self->app->ctl->gh,
            site_host     => $site_host,
            root_dir      => $root_dir,
            tpl_path      => $tpl_path,
            html_path     => $html_path,
            lang_path     => $lang_path,
            lang_id       => $lang_id,
            page_path     => $h->{path},
            page_id       => $id,
            lang_links    => $lang_links,
            lang_metatags => $meta_tags,
            'd_navi'      => $d_navi,
            'm_navi'      => $m_navi,
            breadcrumbs   => $breadcrumbs,
        );

        $self->go_tree(
            site_host => $site_host,
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            lang_id   => $lang_id,
            lang_path => $lang_path,
            parent_id => $id,
            level     => $level + 1,
            items     => $h_pages,
            langs     => $h_langs,
            mods      => $h_mods,
            a_map     => $a_map,
            cur_date  => $cur_date,
        );
    }

    return;
}

sub _breadcrumbs {
    my ( $self, %args ) = @_;

    my $page_id   = $args{page_id}   // 0;
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};

    if ( !$page_id || !$lang_id ) {
        return q{};
    }

    my $breadcrumbs = q{};

    my $a_chain = [];
    $self->_bread_chain(
        {
            lang_id => $lang_id,
            page_id => $page_id,
        },
        $a_chain
    );

    my $h0        = shift @{$a_chain};
    my $home_path = $lang_path . $h0->{path} || q{/};
    $breadcrumbs .= $self->render(
        tpl_path => $tpl_path,
        tpl_name => 'bread-home.html',
        h_vars   => {
            path => $home_path,
            name => $h0->{name},
        },
    );

    foreach my $h ( @{$a_chain} ) {
        $breadcrumbs .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => 'bread-item.html',
            h_vars   => {
                path => $lang_path . $h->{path},
                name => $h->{name},
            },
        );
    }

    return $breadcrumbs;
}

sub _bread_chain {
    my ( $self, $h_args, $a_chain ) = @_;

    my $lang_id = $h_args->{lang_id};
    my $page_id = $h_args->{page_id};

    my ( $h_page, $err_str1 ) = $self->app->ctl->sh->one( 'page', $page_id );

    my $page_name;
    my ( $h_marks, $err_str2 ) = $self->app->ctl->sh->list(
        'pagemark', {
            page_id => $page_id,
            lang_id => $lang_id,
            name    => 'page_name',
        },
    );
    my @mark_ids = keys %{$h_marks};
    if ( scalar @mark_ids ) {
        my $mark_id = $mark_ids[0];
        $page_name = $h_marks->{$mark_id}->{value};
    }
    else {
        $page_name = $h_page->{nick};
    }

    unshift @{$a_chain}, {
        id        => $page_id,
        parent_id => $h_page->{parent_id},
        nick      => $h_page->{nick},
        path      => $h_page->{path},
        name      => $page_name,
    };

    if ( $h_page->{parent_id} > 0 ) {
        $self->_bread_chain(
            {
                lang_id => $lang_id,
                page_id => $h_page->{parent_id},
            },
            $a_chain
        );
    }

    return;
}

#
# navigation link text is built from special mark 'page_name'
#
sub _navi_links {
    my ( $self, %args ) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $id_cur    = $args{id_cur}    // 0;
    my $parent_id = $args{parent_id} // 0;

    my $d_links = q{};
    my $m_links = q{};
    my ( $d_child_links, $m_child_links );

    my ( $h_pages, $err_str ) = $self->app->ctl->sh->list(
        'page', {
            parent_id => $parent_id,
            hidden    => 0,
        },
    );

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        my $page_name;
        my ( $h_marks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $id,
                lang_id => $lang_id,
                name    => 'page_name',
            },
        );
        my @mark_ids = keys %{$h_marks};
        if ( scalar @mark_ids ) {
            my $mark_id = $mark_ids[0];
            $page_name = $h_marks->{$mark_id}->{value};
        }
        else {
            $page_name = $h->{name};
        }

        my $page_path = $h->{path};
        my $suffix    = q{};

        if ( $h->{id} == $id_cur ) {
            $suffix = '-cur';
            ( $d_child_links, $m_child_links ) = $self->_child_links(
                root_dir  => $root_dir,
                tpl_path  => $tpl_path,
                lang_id   => $lang_id,
                lang_path => $lang_path,
                parent_id => $id,
            );
        }

        my $path = $lang_path . $page_path;
        if ( !$path ) {
            $path = q{/};
        }

        $d_links .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "dnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $path,
                child_links => $d_child_links,
            },
        );

        $m_links .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "mnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $path,
                child_links => $m_child_links,
            },
        );
    }

    # add parent page link at head
    my $parent_link = q{};
    if ( !$d_child_links ) {
        my ( $h_parent, $err_str1 ) = $self->app->ctl->sh->one( 'page', $parent_id );

        my $parent_path = $lang_path . $h_parent->{path};
        if ( !$parent_path ) {
            $parent_path = q{/};
        }

        my $parent_name;
        my ( $h_marks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $parent_id,
                lang_id => $lang_id,
                name    => 'page_name',
            },
        );
        my @mark_ids = keys %{$h_marks};
        if ( scalar @mark_ids ) {
            my $mark_id = $mark_ids[0];
            $parent_name = $h_marks->{$mark_id}->{value};
        }
        else {
            $parent_name = $h_parent->{name};
        }

        $parent_link = $self->render(
            tpl_path => $tpl_path,
            tpl_name => "dnavi-item.html",
            h_vars   => {
                name => $parent_name,
                path => $parent_path,
            },
        );

        $d_links = $parent_link . $d_links;
    }

    return ( $d_links, $m_links );
}

sub _child_links {
    my ( $self, %args ) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $parent_id = $args{parent_id} // 0;

    my $d_links = q{};
    my $m_links = q{};

    my ( $h_pages, $err_str ) = $self->app->ctl->sh->list(
        'page', {
            parent_id => $parent_id,
            hidden    => 0,
        },
    );

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        my ( $h_marks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $id,
                lang_id => $lang_id,
                name    => 'page_name',
            },
        );
        my @mark_ids  = keys %{$h_marks};
        my $mark_id   = $mark_ids[0] // 0;
        my $page_name = $h_marks->{$mark_id}->{value} // q{};

        my $page_path = $h->{path};

        $d_links .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "dnavi-child.html",
            h_vars   => {
                name => $page_name,
                path => $lang_path . $page_path,
            },
        );

        $m_links .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "mnavi-child.html",
            h_vars   => {
                name => $page_name,
                path => $lang_path . $page_path,
            },
        );
    }

    return ( $d_links, $m_links );
}

sub _lang_links {
    my ( $self, %args ) = @_;

    my $site_host     = $args{site_host} // q{};
    my $root_dir      = $args{root_dir}  // q{};
    my $tpl_path      = $args{tpl_path}  // q{};
    my $page_path     = $args{page_path} // q{};
    my $lang_id_cur   = $args{lang_id}   // 0;
    my $lang_path_cur = $args{lang_path} // q{};
    my $h_langs       = $args{langs}     // {};

    my $meta_tags  = q{};
    my $lang_links = q{};

    # canonical
    $meta_tags .= $self->render(
        tpl_path => $tpl_path,
        tpl_name => "lang-metatag-c.html",
        h_vars   => {
            site_host => $site_host,
            path      => $lang_path_cur . $page_path,
        },
    );

    foreach my $id ( sort keys %{$h_langs} ) {
        my $h = $h_langs->{$id};

        my $lang_path = $h->{nick} ? q{/} . $h->{nick} : q{};
        my $link_path = $lang_path . $page_path;

        $lang_links .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "lang-link.html",
            h_vars   => {
                site_host => $site_host,
                path      => $link_path,
                isocode   => $h->{isocode},
            },
        );

        $meta_tags .= $self->render(
            tpl_path => $tpl_path,
            tpl_name => "lang-metatag.html",
            h_vars   => {
                site_host => $site_host,
                path      => $link_path,
                hreflang  => $h->{isocode},
            },
        );
    }

    return ( $lang_links, $meta_tags );
}

sub copy_file {
    my ( $self, %args ) = @_;

    my $src = $self->app->root_dir . $args{src_path};
    my $dst = $self->app->root_dir . $args{dst_path};

    return App::Files::copy_file(
        src => $src,
        dst => $dst,
    );
}

sub make_path {
    my ( $self, %args ) = @_;

    my $path = $self->app->root_dir . $args{path};

    return App::Files::make_path( path => $path );
}

sub copy_dir {
    my ( $self, %args ) = @_;

    my $src_dir = $self->app->root_dir . $args{src_path};
    my $dst_dir = $self->app->root_dir . $args{dst_path};

    return App::Files::copy_dir_recursive(
        src_dir => $src_dir,
        dst_dir => $dst_dir,
    );
}

sub move_dir {
    my ( $self, %args ) = @_;

    my $src_dir = $self->app->root_dir . $args{src_path};
    my $dst_dir = $self->app->root_dir . $args{dst_path};

    return App::Files::move_dir(
        src_dir => $src_dir,
        dst_dir => $dst_dir,
    );
}

sub empty_dir {
    my ( $self, %args ) = @_;

    my $dir = $self->app->root_dir . $args{path};

    return App::Files::empty_dir_recursive( dir => $dir );
}

sub create_zip {
    my ( $self, %args ) = @_;

    return App::Files::create_zip(
        src_dir => $self->app->root_dir . $args{src_path},
        dst_dir => $self->app->root_dir . $args{dst_path},
        name    => $args{name},
    );
}

sub get_files {
    my ( $self, %args ) = @_;

    my $path = $args{path};
    my $dir  = $self->app->root_dir . $path;

    return App::Files::get_files(
        dir => $dir,
        %args
    );
}

sub get_fh {
    my ( $self, %args ) = @_;

    my $file = $self->app->root_dir . $args{file_path};
    if ( !-e $file ) {
        return;
    }

    return App::Files::file_handle(
        file    => $file,
        mode    => $args{mode},
        binmode => $args{binmode},
    );
}

sub read_file {
    my ( $self, %args ) = @_;

    my $file = $self->app->root_dir . $args{path} . q{/} . $args{file};

    return App::Files::read_file( file => $file );
}

sub write_file {
    my ( $self, %args ) = @_;

    my $file = $self->app->root_dir . $args{path} . q{/} . $args{file};

    return App::Files::write_file(
        file => $file,
        body => $args{f_body},
    );
}

sub delete_file {
    my ( $self, %args ) = @_;

    my $file = $self->app->root_dir . $args{file_path};

    unlink $file;

    return;
}

sub upload_bkpfile {
    my ( $self, %args ) = @_;

    my $uploads = $args{uploads};

    my $file = $uploads->{file};

    my ( $fname, $ext );
    {
        # not required for backups but who knows
        my @chunks = split /[.]/, $file->basename;
        $ext   = pop @chunks;
        $fname = join q{}, @chunks;
        $fname =~ s/[^\w\-\_]//g;
        if ( !$fname ) {
            $fname = time;
        }
    }

    my $file_tmp = $file->path();

    my $root_dir  = $self->app->root_dir;
    my $bkps_path = $self->app->config->{path}->{bkp};
    my $file_dst  = $root_dir . $bkps_path . q{/} . $fname . q{.} . $ext;
    rename $file_tmp, $file_dst;

    return;
}

sub extract_bkp {
    my ( $self, %args ) = @_;

    my $root_dir = $self->app->root_dir;

    return App::Files::extract_zip(
        file    => $root_dir . $args{src_path},
        dst_dir => $root_dir . $args{dst_path},
    );
}

sub upload_img {
    my ( $self, %args ) = @_;

    my $entity_name = $args{entity_name};
    my $entity_id   = $args{entity_id};
    my $img_id      = $args{img_id};
    my $uploads     = $args{uploads};
    my $maxh_la     = $args{maxh_la};
    my $maxw_la     = $args{maxw_la};
    my $maxh_sm     = $args{maxh_sm};
    my $maxw_sm     = $args{maxw_sm};

    my $app         = $self->app;
    my $html_path   = $app->config->{path}->{html};
    my $images_path = $app->config->{path}->{img};

    my $web_path     = $images_path . q{/} . $entity_name;
    my $disk_path    = $html_path . $web_path;
    my $disk_path_la = $disk_path . '/la';
    my $disk_path_sm = $disk_path . '/sm';

    if ( !-d $app->root_dir . $disk_path_la ) {
        $self->make_path( path => $disk_path_la );
    }
    if ( !-d $app->root_dir . $disk_path_sm ) {
        $self->make_path( path => $disk_path_sm );
    }

    my $o_file    = $uploads->{file};
    my $file_src  = $o_file->path();
    my $base_name = $o_file->basename();
    # my @files  = $o_uploads->get_all('file');
    my @chunks = split /[.]/, $base_name;
    my $ext    = pop @chunks;

    my $img_name     = $entity_id . q{-} . $img_id . q{.} . $ext;
    my $file_orig    = $app->root_dir . $disk_path . q{/} . $img_name;
    my $file_path_la = $disk_path_la . '/' . $img_name;
    my $file_path_sm = $disk_path_sm . '/' . $img_name;
    my $file_la      = $app->root_dir . $file_path_la;
    my $file_sm      = $app->root_dir . $file_path_sm;

    rename $file_src, $file_orig;

    # scale to la
    my $success = App::Files::scale_image(
        file_src => $file_orig,
        file_dst => $file_la,
        width    => $maxw_la,
        height   => $maxh_la,
    );
    if ( !$success ) {
        carp( 'Failed to scale to large image: ' . $file_orig );
    }

    # scale to sm
    my $success2 = App::Files::scale_image(
        file_src => $file_orig,
        file_dst => $file_sm,
        width    => $maxw_sm,
        height   => $maxh_sm,
    );
    if ( !$success2 ) {
        carp( 'Failed to scale to small image: ' . $file_orig );
    }

    unlink $file_orig;

    return {
        path_la => $web_path . '/la/' . $img_name,
        path_sm => $web_path . '/sm/' . $img_name,
    };
}

sub upload_file {
    my ( $self, %args ) = @_;

    my $page_dir = $args{dir};
    my $uploads  = $args{uploads};

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
    my $file_dst = $page_dir . q{/} . $name . q{.} . $ext;
    my $success  = rename $file_tmp, $file_dst;
    return $OS_ERROR if !$success;

    my $mode_readable = oct '644';
    chmod $mode_readable, $file_dst;

    return;
}

sub get_note_path {
    my ( undef, %args ) = @_;

    my $lang_path = $args{lang_path};
    my $page_path = $args{page_path};
    my $id        = $args{id};

    return $lang_path . $page_path . '/' . $id . '.html';
}

sub set_mod_config {
    my ( $self, %args ) = @_;

    my $mod      = $args{mod};
    my $page_id  = $args{page_id};
    my $h_params = $args{h_params};

    my $root_dir  = $self->app->root_dir;
    my $html_path = $self->app->config->{path}->{html};
    my $tpl_path  = $self->app->config->{path}->{templates};

    my ( $h_page, $err_str1 ) = $self->app->ctl->sh->one( 'page', $page_id );

    my $o_config = $self->get_mod_config(
        mod       => $mod,
        page_id   => $page_id,
        page_path => $h_page->{path},
    );

    my $old_skin = $o_config->{$mod}->{skin};

    # update config values (in memory)
    foreach my $param ( keys %{ $o_config->{$mod} } ) {
        $o_config->{$mod}->{$param} = $h_params->{$param};
    }

    # if skin name changed
    my $err_str2;
    if ( $old_skin ne $o_config->{$mod}->{skin} ) {
        my $new_skin_dir = $root_dir . $tpl_path . '/g/' . $o_config->{$mod}->{skin};
        if ( -d $new_skin_dir ) {
            # if new skin dir exists already (duplicated)
            # then fall back to old name
            $o_config->{$mod}->{skin} = $old_skin;
            $err_str2 = "skin name duplicated - fall back to previous value";
        }
        else {
            # otherwise move templates to dir with new name
            $err_str2 = $self->move_dir(
                src_path => $tpl_path . '/g/' . $old_skin,
                dst_path => $tpl_path . '/g/' . $o_config->{$mod}->{skin},
            );
        }
    }

    # save config values (in file)

    my $mod_dir   = $root_dir . $html_path . $h_page->{path};
    my $conf_file = $mod_dir . '/' . $mod . '-' . $page_id . '.conf';

    App::Config::save_config(
        file   => $conf_file,
        o_conf => $o_config,
    );

    return $err_str2;
}

sub get_mod_config {
    my ( $self, %args ) = @_;

    my $mod       = $args{mod};
    my $page_id   = $args{page_id};
    my $page_path = $args{page_path};

    my $root_dir  = $self->app->root_dir;
    my $html_path = $self->app->config->{path}->{html};

    my $mod_dir   = $root_dir . $html_path . $page_path;
    my $conf_file = $mod_dir . '/' . $mod . '-' . $page_id . '.conf';

    my $o_config;

    if ( !-e $conf_file ) {
        $o_config = $self->_create_mod_config(
            mod       => $mod,
            page_id   => $page_id,
            page_path => $page_path,
            conf_file => $conf_file,
        );
    }
    else {
        $o_config = $self->_check_mod_config(
            mod       => $mod,
            conf_file => $conf_file,
        );
    }

    return $o_config;
}

sub _create_mod_config {
    my ( $self, %args ) = @_;

    my $mod       = $args{mod};
    my $page_id   = $args{page_id};
    my $page_path = $args{page_path};
    my $conf_file = $args{conf_file};

    my $root_dir  = $self->app->root_dir;
    my $html_path = $self->app->config->{path}->{html};

    my $mod_dir = $root_dir . $html_path . $page_path;
    if ( !-d $mod_dir ) {
        App::Files::make_path( path => $mod_dir );
    }

    my $o_config = App::Config::get_config(
        file => $root_dir . q{/} . $mod . '-default.conf',
    );

    if ( $o_config->{$mod}->{skin} eq 'AUTOREPLACE' ) {
        $o_config->{$mod}->{skin} = $mod . '-skin-' . $page_id;
    }

    App::Config::save_config(
        file   => $conf_file,
        o_conf => $o_config,
    );

    return $o_config;
}

# read config, augment with missing params and return
sub _check_mod_config {
    my ( $self, %args ) = @_;

    my $mod       = $args{mod};
    my $conf_file = $args{conf_file};

    my $root_dir = $self->app->root_dir;
    # my $html_path = $self->app->config->{path}->{html};

    my $o_default_config = App::Config::get_config(
        file => $root_dir . q{/} . $mod . '-default.conf',
    );

    my $o_config = App::Config::get_config(
        file => $conf_file,
    );

    my $is_changed = 0;
    foreach my $param ( keys %{ $o_default_config->{$mod} } ) {
        if ( !exists $o_config->{$mod}->{$param} ) {
            $o_config->{$mod}->{$param} = $o_default_config->{$mod}->{$param};
            $is_changed = 1;
        }
    }

    if ($is_changed) {
        App::Config::save_config(
            file   => $conf_file,
            o_conf => $o_config,
        );
    }

    return $o_config;
}

1;
