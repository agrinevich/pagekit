package Generator::Standard;

#
# generate static page of default type
#

use strict;
use warnings;

use Carp qw(croak carp);

use App::Files;
use Generator::Renderer;

our $VERSION = '0.2';

sub gen {
    my ( undef, %args ) = @_;

    my $sh = $args{sh};

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $html_path = $args{html_path} // q{};
    my $lang_path = $args{lang_path} // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $page_path = $args{page_path} // q{};
    my $page_id   = $args{page_id}   // 0;

    my %marks = ();

    $marks{site_host}     = $args{site_host};
    $marks{desktop_navi}  = $args{d_navi};
    $marks{mobile_navi}   = $args{m_navi};
    $marks{lang_links}    = $args{lang_links};
    $marks{lang_metatags} = $args{lang_metatags};

    my ( $h_pagemarks, $err_str ) = $sh->list(
        'pagemark', {
            page_id => $page_id,
            lang_id => $lang_id,
        },
    );
    while ( my ( $mark_id, $h_mark ) = each( %{$h_pagemarks} ) ) {
        my $markname  = $h_mark->{name};
        my $markvalue = $h_mark->{value};
        $marks{$markname} = $markvalue;
    }

    my $out_dir = $root_dir . $html_path . $lang_path . $page_path;
    if ( !-d $out_dir ) {
        App::Files::make_path(
            path => $out_dir,
        );
    }
    my $out_file = $out_dir . '/index.html';

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

1;
