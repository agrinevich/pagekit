package UI::Web::Renderer;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);
use Path::Tiny; # path, spew_utf8
use Text::Xslate qw(mark_raw);

use App::Files;

our $VERSION = '0.2';

sub parse_html {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $tpl_name = $args{tpl_name};
    my $h_vars   = $args{h_vars};

    # gmarks are global marks with 'default' values
    my $h_gmarks = _gmarks( root_dir => $root_dir );

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
    );

    return $tx->render( $tpl_name, \%merged ) || croak __PACKAGE__ . ' failed to parse_html';
}

sub _gmarks {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $dir      = $root_dir . '/tpl/gmark';
    my %result   = ();

    my $a_files = App::Files::get_files(
        dir        => $dir,
        files_only => 1,
    );

    foreach my $h_file ( @{$a_files} ) {
        my $fname = $h_file->{name};
        my $fbody = App::Files::read_file( file => $dir . q{/} . $fname );
        my ( $gmarkname, $fext ) = split /[.]/, $fname;
        $result{$gmarkname} = $fbody;
    }

    return \%result;
}

sub write_html {
    my ( $h_vars, $h_args ) = @_;

    my $root_dir = $h_args->{root_dir};
    my $tpl_path = $h_args->{tpl_path};
    my $tpl_file = $h_args->{tpl_file};
    my $out_file = $h_args->{out_file};

    my $html = parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => $tpl_file,
        h_vars   => $h_vars,
    );

    path($out_file)->spew_utf8($html);

    return;
}

1;
