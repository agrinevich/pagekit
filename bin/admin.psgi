#!/usr/bin/perl

use strict;
use warnings;

use Plack;
use Plack::Builder;
use FindBin qw($Bin);

use lib "$Bin/../lib";
use App::Admin;
use App::Config;

our $VERSION = '0.2';

my $app = sub {
    my $env = shift;

    my $o_response = App::Admin->new(
        root_dir  => "$Bin/..",
        conf_file => 'main.conf',
        # log_file  => 'admin-error.log',
    )->run($env);

    return $o_response->finalize();
};

builder {
    enable 'Auth::Basic', authenticator => \&authen_cb;
    $app;
};

sub authen_cb {
    my ( $username, $password, $env ) = @_;

    my $config = App::Config::get_config(
        file => "$Bin/.." . '/main.conf',
    );

    my $user = $config->{admin}->{user};
    my $pass = $config->{admin}->{pass};

    return $username eq $user && $password eq $pass;
}
