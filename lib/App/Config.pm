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
    my (%args) = @_;

    my $file   = $args{file};
    my $o_conf = $args{o_conf};

    $o_conf->write($file)
        or croak( "Failed to write $file - " . Config::Tiny->errstr() );

    return;
}

1;
