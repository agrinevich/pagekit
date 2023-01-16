package Generator::Base;

use Carp qw(carp croak);
use POSIX ();
use POSIX qw(strftime);

use Generator::Renderer;
use Generator::Standard;
use App::Files;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

sub gen_pages {
    my ($self) = @_;

    my $root_dir  = $self->app->root_dir;
    my $site_host = $self->app->config->{site}->{host};
    my $html_path = $self->app->config->{path}->{html};
    my $tpl_path  = $self->app->config->{path}->{templates} . '/g';

    my ( $h_langs, $err_str )  = $self->app->ctl->sh->list('lang');
    my ( $h_pages, $err_str2 ) = $self->app->ctl->sh->list('page');

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
            a_map     => $a_map,
            cur_date  => $cur_date,
        );
    }

    my $map_items = join q{}, @{$a_map};
    my $map_file  = $root_dir . $html_path . '/sitemap.xml';
    Generator::Renderer::write_html(
        {
            items => $map_items,
        },
        {
            root_dir => $root_dir,
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
    my $a_map     = $args{a_map}     // [];
    my $cur_date  = $args{cur_date}  // q{};

    if ( $level > 5 ) {
        carp 'recursion level > 5';
        return;
    }

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        if ( $h->{parent_id} != $parent_id ) {
            next;
        }

        my ( $d_navi, $m_navi ) = $self->_navi_links(
            root_dir        => $root_dir,
            tpl_path        => $tpl_path . '/page',
            lang_id         => $lang_id,
            lang_path       => $lang_path,
            id_cur          => $id,
            parent_id       => $parent_id,
            page_name_inner => $h->{name},
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

        my $map_item = Generator::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "sitemap-item.xml",
            h_vars   => {
                path      => $lang_path . $h->{path},
                site_host => $site_host,
                cur_date  => $cur_date,
            },
        );
        push @{$a_map}, $map_item;

        {
            # TODO: add another page types (plugins)
            my $page_type = 'Standard';
            my $gen_class = 'Generator::' . $page_type;

            $gen_class->gen(
                sh            => $self->app->ctl->sh,
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
            );
        }

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
            a_map     => $a_map,
            cur_date  => $cur_date,
        );
    }

    return;
}

#
# navigation link text is built from special mark 'page_name'
#
sub _navi_links {
    my ( $self, %args ) = @_;

    my $root_dir        = $args{root_dir}        // q{};
    my $tpl_path        = $args{tpl_path}        // q{};
    my $lang_id         = $args{lang_id}         // 0;
    my $lang_path       = $args{lang_path}       // q{};
    my $id_cur          = $args{id_cur}          // 0;
    my $parent_id       = $args{parent_id}       // 0;
    my $page_name_inner = $args{page_name_inner} // q{};

    my $d_links = q{};
    my $m_links = q{};

    my ( $h_pages, $err_str ) = $self->app->ctl->sh->list(
        'page', {
            parent_id => $parent_id,
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
            $page_name = $page_name_inner;
        }

        my $page_path = $h->{path};
        my $suffix    = q{};

        my ( $d_child_links, $m_child_links );
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

        $d_links .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "dnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $lang_path . $page_path,
                child_links => $d_child_links,
            },
        );

        $m_links .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "mnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $lang_path . $page_path,
                child_links => $m_child_links,
            },
        );
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
        my $mark_id   = $mark_ids[0];
        my $page_name = $h_marks->{$mark_id}->{value};

        my $page_path = $h->{path};

        $d_links .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "dnavi-child.html",
            h_vars   => {
                name => $page_name,
                path => $lang_path . $page_path,
            },
        );

        $m_links .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
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
    $meta_tags .= Generator::Renderer::parse_html(
        root_dir => $root_dir,
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

        $lang_links .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "lang-link.html",
            h_vars   => {
                site_host => $site_host,
                path      => $link_path,
                isocode   => $h->{isocode},
            },
        );

        $meta_tags .= Generator::Renderer::parse_html(
            root_dir => $root_dir,
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

#
# TODO: rename to upload_pagefile
#
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
    rename $file_tmp, $file_dst;

    my $mode_readable = oct '644';
    chmod $mode_readable, $file_dst;

    return;
}

1;
