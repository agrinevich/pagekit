package Generator::Note;

#
# generate pages of Note mod (plugin)
#

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);
use POSIX qw( strftime );

use App::Files;
use Generator::Renderer;
use Generator::Base;

our $VERSION = '0.2';

const my $ROUND_NUMBER => 0.999999;

sub gen {
    my ( undef, %args ) = @_;

    my $sh = $args{sh};
    my $gh = $args{gh};

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $html_path = $args{html_path} // q{};
    my $lang_path = $args{lang_path} // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $page_path = $args{page_path} // q{};
    my $page_id   = $args{page_id}   // 0;

    my $out_dir = $root_dir . $html_path . $lang_path . $page_path;
    if ( !-d $out_dir ) {
        App::Files::make_path(
            path => $out_dir,
        );
    }

    my %pagemarks = ();
    my ( $h_pagemarks, $err_str ) = $sh->list(
        'pagemark', {
            page_id => $page_id,
            lang_id => $lang_id,
        },
    );
    while ( my ( $mark_id, $h_mark ) = each( %{$h_pagemarks} ) ) {
        my $markname  = $h_mark->{name};
        my $markvalue = $h_mark->{value};
        $pagemarks{$markname} = $markvalue;
    }

    my $o_mod_config = $gh->get_mod_config(
        mod       => 'note',
        page_id   => $page_id,
        page_path => $page_path,
    );

    my $npp           = $o_mod_config->{note}->{npp};
    my $skin_tpl_path = $tpl_path . q{/} . $o_mod_config->{note}->{skin};

    my $total_qty = $sh->count(
        'note',
        {
            page_id => $page_id,
            hidden  => 0,
        },
    );
    my $p_qty  = int( $total_qty / $npp + $ROUND_NUMBER );
    my $p_last = $p_qty - 1;

    foreach my $p ( 0 .. $p_last ) {
        _gen_list(
            p             => $p,
            p_qty         => $p_qty,
            npp           => $npp,
            total_qty     => $total_qty,
            sh            => $sh,
            gh            => $gh,
            o_mod_config  => $o_mod_config,
            root_dir      => $root_dir,
            tpl_path      => $tpl_path,
            skin_tpl_path => $skin_tpl_path,
            out_dir       => $out_dir,
            lang_links    => $args{lang_links},
            lang_metatags => $args{lang_metatags},
            'd_navi'      => $args{d_navi},
            'm_navi'      => $args{m_navi},
            page_id       => $page_id,
            lang_id       => $lang_id,
            page_path     => $page_path,
            lang_path     => $lang_path,
            html_path     => $html_path,
            pagemarks     => \%pagemarks,
        );
    }

    return;
}

sub _gen_list {
    my (%args) = @_;

    my $p             = $args{p}             // 0;
    my $p_qty         = $args{p_qty}         // 0;
    my $npp           = $args{npp}           // 0;
    my $total_qty     = $args{total_qty}     // 0;
    my $root_dir      = $args{root_dir}      // q{};
    my $html_path     = $args{html_path}     // q{};
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $out_dir       = $args{out_dir}       // q{};
    my $page_id       = $args{page_id}       // 0;
    my $lang_id       = $args{lang_id}       // 0;
    my $page_path     = $args{page_path}     // q{};
    my $lang_path     = $args{lang_path}     // q{};

    my $sh           = $args{sh};
    my $gh           = $args{gh};
    my $o_mod_config = $args{o_mod_config};
    my $h_pagemarks  = $args{pagemarks};

    my %marks = (
        site_host     => $args{site_host},
        lang_metatags => $args{lang_metatags},
        lang_links    => $args{lang_links},
        desktop_navi  => $args{d_navi},
        mobile_navi   => $args{m_navi},
    );

    my $p_suffix = $p > 0 ? sprintf( '%d', $p + 1 ) : q{};
    $marks{page_title} = $h_pagemarks->{page_title} . q{ } . $p_suffix;

    $marks{page_main} = _build_list_main(
        sh            => $sh,
        o_mod_config  => $o_mod_config,
        root_dir      => $root_dir,
        html_path     => $html_path,
        tpl_path      => $tpl_path,
        skin_tpl_path => $skin_tpl_path,
        page_id       => $page_id,
        lang_id       => $lang_id,
        page_path     => $page_path,
        lang_path     => $lang_path,
        lang_links    => $args{lang_links},
        lang_metatags => $args{lang_metatags},
        'd_navi'      => $args{d_navi},
        'm_navi'      => $args{m_navi},
        p             => $p,
        p_qty         => $p_qty,
        npp           => $npp,
        total_qty     => $total_qty,
        pagemarks     => $h_pagemarks,
    );

    my $suffix   = $p > 0 ? $p : q{};
    my $out_file = $out_dir . '/index' . $suffix . '.html';

    Generator::Renderer::write_html(
        \%marks,
        {
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_file => 'layout.html',
            out_file => $out_file,
        },
    );

    return;
}

sub _build_list_main {
    my (%args) = @_;

    my $sh           = $args{sh};
    my $o_mod_config = $args{o_mod_config};
    my $h_pagemarks  = $args{pagemarks};

    my $root_dir      = $args{root_dir}      // q{};
    my $html_path     = $args{html_path}     // q{};
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $p             = $args{p}             // 0;
    my $p_qty         = $args{p_qty}         // 0;
    my $npp           = $args{npp}           // 0;
    my $total_qty     = $args{total_qty}     // 0;
    my $page_id       = $args{page_id}       // 0;
    my $lang_id       = $args{lang_id}       // 0;
    my $page_path     = $args{page_path}     // q{};
    my $lang_path     = $args{lang_path}     // q{};

    my $offset = $p * $npp;

    my ( $h_notes, $err_str ) = $sh->list(
        'note',
        {
            page_id => $page_id,
            hidden  => 0,
        },
        [
            {
                orderby  => $o_mod_config->{note}->{order_by},
                orderhow => $o_mod_config->{note}->{order_how},
            },
        ],
        {
            qty    => $npp,
            offset => $offset,
        },
    );

    my $list = _build_list_items(
        sh            => $sh,
        root_dir      => $root_dir,
        html_path     => $html_path,
        tpl_path      => $tpl_path,
        skin_tpl_path => $skin_tpl_path,
        tpl_item      => 'f-list-item.html',
        a_items       => $h_notes,
        pagemarks     => $h_pagemarks,
        h_vars        => {
            page_id       => $page_id,
            lang_id       => $lang_id,
            page_path     => $page_path,
            lang_path     => $lang_path,
            lang_metatags => $args{lang_metatags},
            lang_links    => $args{lang_links},
            desktop_navi  => $args{d_navi},
            mobile_navi   => $args{m_navi},
        },
    );

    my $paging = _build_list_paging(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        qty      => $total_qty,
        npp      => $npp,
        p        => $p,
        path     => '/admin/note?do=list&fltr_page_id=' . $page_id . '&p=',
    );

    my $page_main = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_name => 'f-list.html',
        h_vars   => {
            page_id => $page_id,
            # page_name => $h_page->{name},
            list   => $list,
            paging => $paging,
            qty    => $total_qty,
        },
    );

    return $page_main;
}

sub _build_list_items {
    my (%args) = @_;

    my $sh          = $args{sh};
    my $h_pagemarks = $args{pagemarks};

    my $root_dir      = $args{root_dir}      // q{};
    my $html_path     = $args{html_path}     // q{};
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $tpl_item      = $args{tpl_item}      // q{};
    my $h_table       = $args{a_items}       // {};
    my $h_vars        = $args{h_vars}        // {};

    my $result = q{};

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        $h->{added_dt} = strftime( "%Y-%m-%d %H:%M:%S", localtime( $h->{added} ) );

        # lang specific fields
        my ( $h_nvs, $err_str ) = $sh->list(
            'note_version', {
                note_id => $id,
                lang_id => $h_vars->{lang_id},
            },
        );
        foreach my $nv_id ( keys %{$h_nvs} ) {
            my $h_nv = $h_nvs->{$nv_id};
            $h->{name}    = $h_nv->{name};
            $h->{descr}   = $h_nv->{descr};
            $h->{p_title} = $h_nv->{p_title};
            $h->{p_descr} = $h_nv->{p_descr};
            last;
        }

        # images
        my ( $h_nis, $err_str2 ) = $sh->list(
            'note_image', {
                note_id => $id,
            },
        );

        my $one_path = Generator::Base->get_note_path(
            lang_path => $h_vars->{lang_path},
            page_path => $h_vars->{page_path},
            id        => $id,
        );
        $h->{path} = $one_path;

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $skin_tpl_path,
            tpl_name => $tpl_item,
            h_vars   => {
                %{$h},
                %{$h_vars},
            },
        );

        _gen_one(
            root_dir      => $root_dir,
            html_path     => $html_path,
            tpl_path      => $tpl_path,
            skin_tpl_path => $skin_tpl_path,
            one_path      => $one_path,
            h_vars        => {
                %{$h},
                %{$h_vars},
            },
            h_nis     => $h_nis,
            pagemarks => $h_pagemarks,
        );
    }

    return $result;
}

sub _build_list_paging {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $qty      = $args{qty};
    my $npp      = $args{npp};
    my $p_cur    = $args{p};
    my $path     = $args{path};

    my $result   = q{};
    my $tpl_name = q{};
    my $suffix   = q{};

    my $p_qty = int( $qty / $npp + $ROUND_NUMBER );

    return q{} if $p_qty < 2;

    my $p_last = $p_qty - 1;
    foreach my $p ( 0 .. $p_last ) {
        if   ( $p == $p_cur ) { $tpl_name = 'f-paging-item-cur.html'; }
        else                  { $tpl_name = 'f-paging-item.html'; }

        $suffix = $p ? $p : q{};

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
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

sub _gen_one {
    my (%args) = @_;

    my $root_dir      = $args{root_dir}      // q{};
    my $html_path     = $args{html_path}     // q{};
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $one_path      = $args{one_path}      // q{};
    my $page_id       = $args{page_id}       // 0;
    my $lang_id       = $args{lang_id}       // 0;

    my $h_vars      = $args{h_vars};
    my $h_nis       = $args{h_nis};
    my $h_pagemarks = $args{pagemarks};

    $h_vars->{page_title} = $h_vars->{p_title} || $h_vars->{name};
    $h_vars->{page_descr} = $h_vars->{p_descr};

    $h_vars->{page_main} = _build_one_main(
        root_dir      => $root_dir,
        html_path     => $html_path,
        tpl_path      => $tpl_path,
        skin_tpl_path => $skin_tpl_path,
        h_vars        => $h_vars,
        h_nis         => $h_nis,
    );

    my $out_file = $root_dir . $html_path . $one_path;

    Generator::Renderer::write_html(
        $h_vars,
        {
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_file => 'layout.html',
            out_file => $out_file,
        },
    );

    return;
}

sub _build_one_main {
    my (%args) = @_;

    my $h_vars = $args{h_vars};
    my $h_nis  = $args{h_nis};

    my $root_dir      = $args{root_dir}      // q{};
    my $html_path     = $args{html_path}     // q{};
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    # my $page_id       = $args{page_id}       // 0;
    # my $lang_id       = $args{lang_id}       // 0;
    # my $page_path     = $args{page_path}     // q{};
    # my $lang_path     = $args{lang_path}     // q{};

    # images
    my $img_list_la = q{};
    foreach my $ni_id ( sort keys %{$h_nis} ) {
        my $h_ni = $h_nis->{$ni_id};

        $img_list_la .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $skin_tpl_path,
            tpl_name => 'f-one-img-la.html',
            h_vars   => {
                name    => $h_vars->{name},
                id      => $h_ni->{id},
                num     => $h_ni->{num},
                path_la => $h_ni->{path_la},
            },
        );
    }
    $h_vars->{img_list_la} = $img_list_la;

    my $page_main = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_name => 'f-one.html',
        h_vars   => $h_vars,
    );

    return $page_main;
}

1;
