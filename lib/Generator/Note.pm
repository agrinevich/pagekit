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

    my %marks = ();

    my $out_dir = $root_dir . $html_path . $lang_path . $page_path;
    if ( !-d $out_dir ) {
        App::Files::make_path(
            path => $out_dir,
        );
    }

    # my ( $h_pagemarks, $err_str ) = $sh->list(
    #     'pagemark', {
    #         page_id => $page_id,
    #         lang_id => $lang_id,
    #     },
    # );
    # while ( my ( $mark_id, $h_mark ) = each( %{$h_pagemarks} ) ) {
    #     my $markname  = $h_mark->{name};
    #     my $markvalue = $h_mark->{value};
    #     $marks{$markname} = $markvalue;
    # }

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
    my $tpl_path      = $args{tpl_path}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $out_dir       = $args{out_dir}       // q{};
    my $page_id       = $args{page_id}       // 0;
    my $lang_id       = $args{lang_id}       // 0;
    my $page_path     = $args{page_path}     // q{};

    my $sh           = $args{sh};
    my $gh           = $args{gh};
    my $o_mod_config = $args{o_mod_config};

    my %marks = (
        site_host     => $args{site_host},
        lang_metatags => $args{lang_metatags},
        lang_links    => $args{lang_links},
        desktop_navi  => $args{d_navi},
        mobile_navi   => $args{m_navi},
    );

    $marks{page_title} = _build_page_title(
        page_id => $page_id,
        lang_id => $lang_id,
        p       => $p,
    );

    $marks{page_main} = _build_page_main(
        sh            => $sh,
        o_mod_config  => $o_mod_config,
        root_dir      => $root_dir,
        skin_tpl_path => $skin_tpl_path,
        page_id       => $page_id,
        lang_id       => $lang_id,
        page_path     => $page_path,
        p             => $p,
        p_qty         => $p_qty,
        npp           => $npp,
        total_qty     => $total_qty,
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

sub _build_page_title {
    my (%args) = @_;

    my $p       = $args{p}       // 0;
    my $page_id = $args{page_id} // 0;
    my $lang_id = $args{lang_id} // 0;

    return 'Page title here';
}

sub _build_page_main {
    my (%args) = @_;

    my $sh           = $args{sh};
    my $o_mod_config = $args{o_mod_config};

    my $root_dir      = $args{root_dir}      // q{};
    my $skin_tpl_path = $args{skin_tpl_path} // q{};
    my $p             = $args{p}             // 0;
    my $p_qty         = $args{p_qty}         // 0;
    my $npp           = $args{npp}           // 0;
    my $total_qty     = $args{total_qty}     // 0;
    my $page_id       = $args{page_id}       // 0;
    my $lang_id       = $args{lang_id}       // 0;
    my $page_path     = $args{page_path}     // q{};

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

    my $list = _build_list(
        sh       => $sh,
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_item => 'f-list-item.html',
        a_items  => $h_notes,
        h_vars   => {
            page_id   => $page_id,
            lang_id   => $lang_id,
            page_path => $page_path,
        },
    );

    my $paging = _build_paging(
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

sub _build_list {
    my (%args) = @_;

    my $sh = $args{sh};

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
            my ( $h_nvs, $err_str ) = $sh->list(
                'note_version', {
                    note_id => $id,
                    lang_id => $h_vars->{lang_id},
                },
            );
            foreach my $nv_id ( keys %{$h_nvs} ) {
                my $h_nv = $h_nvs->{$nv_id};
                $name = $h_nv->{name};
                last;
            }
        }
        $h->{name} = $name;

        $h->{path} = $h_vars->{page_path} . '/' . $id . '.html';

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
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

1;
