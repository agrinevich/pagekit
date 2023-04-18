package UI::Web::Renderer;

use strict;
use warnings;

# use Const::Fast;
use Carp qw(croak carp);
use Path::Tiny; # path, spew_utf8
use Text::Xslate qw(mark_raw html_escape);
# use Data::Dumper;

use App::Files;

our $VERSION = '0.2';

# const my %MSG_TEXT     => (
#     success => 'Success',
#     error   => 'Error',
# );

sub parse_html {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $tpl_name = $args{tpl_name};
    my $h_vars   = $args{h_vars};

    my $h_gmarks = _global( dir => $root_dir . $tpl_path . '/snippet' );

    my %merged = ();
    if ( scalar keys %{$h_gmarks} ) {
        %merged = %{$h_gmarks};

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

    return $tx->render( $tpl_name, \%merged ) || croak __PACKAGE__ . ' failed to parse_html';
}

sub _global {
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
        my ( $gmarkname, $fext ) = split /[.]/, $fname;
        $result{$gmarkname} = $fbody;
    }

    return \%result;
}

# sub build_msg {
#     my (%args) = @_;

#     my $root_dir = $args{root_dir};
#     my $tpl_path = $args{tpl_path};
#     my $tpl_name = $args{tpl_name};
#     my $msg      = $args{msg};

#     return q{} if !$msg;

#     my $html = parse_html(
#         root_dir => $root_dir,
#         tpl_path => $tpl_path,
#         tpl_name => $tpl_name,
#         h_vars   => {
#             text => $MSG_TEXT{$msg},
#         },
#     );

#     return $html;
# }

sub do_escape {
    my ($str) = @_;
    return html_escape($str);
}

1;
