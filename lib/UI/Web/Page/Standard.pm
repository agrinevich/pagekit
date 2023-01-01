package UI::Web::Page::Standard;

use strict;
use warnings;

use Carp qw(croak carp);
use Data::Dumper;

use App::Files;
use UI::Web::Renderer;

our $VERSION = '0.2';

sub gen {
    my ( undef, %args ) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $html_path = $args{html_path} // q{};
    my $lang_path = $args{lang_path} // q{};
    my $h_data    = $args{h_data}    // {};

    my $out_dir = $root_dir . $html_path . $lang_path . $h_data->{page_path};
    if ( !-d $out_dir ) {
        App::Files::make_path(
            path => $out_dir,
        );
    }
    my $out_file = $out_dir . '/index.html';
    # carp( Dumper($h_data) );
    # carp( 'out=' . $out_file );

    UI::Web::Renderer::write_html(
        $h_data,
        {
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_file => 'page_layout.html',
            out_file => $out_file,
        },
    );

    return;
}

1;
