package App::Config;

use strict;
use warnings;

use Carp qw(croak);
use Config::Tiny;

use App::Files;

our $VERSION = '0.2';

sub get_config {
    my (%args) = @_;

    my $file = $args{file};

    if ( !-e $file ) {
        croak("Config '$file' not found");
    }

    my $o_conf = Config::Tiny->read($file)
        or croak( "Failed to read $file - " . Config::Tiny->errstr() );

    return $o_conf;
}

sub save_config {
    my ( $h_args, $o_config ) = @_;

    my $file = $h_args->{file};

    $o_config->write($file)
        or croak( "Failed to write $file - " . Config::Tiny->errstr() );

    return;
}

sub get_mode_config {
    my (%args) = @_;

    my $root_dir   = $args{root_dir};
    my $page_id    = $args{page_id};
    my $html_path  = $args{html_path};
    my $base_path  = $args{base_path};
    my $mode_name  = $args{mode_name};
    my $replace_cb = $args{replace_cb};

    my $config_name = $mode_name . q{-} . $page_id . '.conf';
    my $mode_dir    = $root_dir . $html_path . $base_path;

    if ( !-d $mode_dir ) {
        App::Files::make_path( path => $mode_dir );
    }

    my $o_default_config = get_config(
        file => $root_dir . q{/} . $mode_name . '-default.conf',
    );

    if ( !-e "$mode_dir/$config_name" ) {

        # auto-replace default params
        if ($replace_cb) {
            $replace_cb->(
                o_config  => $o_default_config,
                mode_name => $mode_name,
                page_id   => $page_id,
            );
        }

        save_config(
            { file => "$mode_dir/$config_name" },
            $o_default_config,
        );
    }
    else {
        my $o_mode_config = get_config(
            file => "$mode_dir/$config_name",
        );

        # compare and add missing params
        foreach my $param ( keys %{ $o_default_config->{$mode_name} } ) {
            next if exists $o_mode_config->{$mode_name}->{$param};

            my $value_to_add = $o_default_config->{$mode_name}->{$param};
            $o_mode_config->{$mode_name}->{$param} = $value_to_add;
        }

        save_config(
            { file => "$mode_dir/$config_name" },
            $o_mode_config,
        );
    }

    my $o_config = get_config(
        file => $mode_dir . q{/} . $config_name,
    );

    return $o_config;
}

1;
