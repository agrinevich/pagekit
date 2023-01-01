#!/usr/bin/perl

use strict;
use warnings;

use Carp qw(carp croak);
use FindBin qw( $Bin );
use Pod::Usage;
use Getopt::Long;

use lib "$Bin/../lib";
use App::Config;
use App::Launcher;

our $VERSION = '0.1';

#
# read input args
#

my %input = ();
GetOptions(
    \%input,
    'help',
    'command=s',
) or pod2usage('Fix arguments');

if ( $input{help} ) {
    pod2usage(
        -verbose   => 1,
        -exitval   => 1,
        -noperldoc => 1,
    );
}
elsif ( !exists $input{command} ) {
    if ( -t STDIN ) {
        pod2usage(
            -verbose   => 0,
            -exitval   => 1,
            -noperldoc => 1,
        );
    }
    else {
        carp('Abort: i need command');
        exit 1;
    }
}

#
# read config
#

my $o_conf = App::Config::get_config(
    file => $Bin . '/../launcher.conf',
);
my $o_conf2 = App::Config::get_config(
    file => $Bin . '/../main.conf',
);

#
# process data
#

my $method = lc $input{command}; # to make perl critic happy
if ( !App::Launcher->can($method) ) {
    carp( 'Abort: unexpected command "' . $input{command} . q{"} );
    exit 1;
}

App::Launcher->$method(
    {
        %{$o_conf},
        %{$o_conf2},
    },
    {
        root_dir => "$Bin/..",
    },
);

exit;

__END__

=for stopwords Launcher Oleksii Grynevych rsync

=head1 NAME

  launcher.pl - start/stop script

=head1 USAGE

  launcher.pl [options]

  Example:
  ./launcher.pl --command=start

=head1 OPTIONS

  Options:
   --help          Full help text
   --command       [REQUIRED] start | stop | rsync

=head1 ARGUMENTS

  Available arguments for command:
    start
    stop
    rsync

=head1 DESCRIPTION

This program will start or stop application as background process or rsync files after git pull

=head1 AUTHOR

Oleksii Grynevych <grinevich@gmail.com>

=cut
