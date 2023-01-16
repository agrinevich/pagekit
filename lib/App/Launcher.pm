package App::Launcher;

use strict;
use warnings;
use feature qw( say );

use Carp qw( croak );
use English qw( -no_match_vars );
use POSIX qw( strftime );
use Scalar::Util qw( reftype );
use FileHandle;
use Data::Dumper;

use constant {
    EXECFAIL => -1,
    CHILDSIG => 127,
};

our $VERSION = '0.2';

sub start {
    my ( undef, $o_conf ) = @_;

    _starman(
        port      => $o_conf->{starman}->{aport},
        workers   => $o_conf->{starman}->{workers},
        dir       => $o_conf->{starman}->{dir},
        pidfile   => '/tmp/admin.pid',
        errorlog  => '/log/admin-error.log',
        accesslog => '/log/admin-access.log',
        appfile   => '/bin/admin.psgi',
    );

    return 1;
}

sub rsync {
    my ( undef, $o_conf ) = @_;

    my $srcdir   = $o_conf->{rsync}->{src};
    my $dstdir   = $o_conf->{rsync}->{dst};
    my $exclfile = $o_conf->{rsync}->{exclude};

    my $call = "rsync -av --exclude-from='$exclfile' $srcdir $dstdir";
    _tellme($call);

    my $err = _call_system(
        call => $call,
    );
    my $msg = $err ? $err : 'rsync done';
    _tellme($msg);

    return 1;
}

sub stop {
    my ( undef, $o_conf ) = @_;

    my $dir = $o_conf->{starman}->{dir};

    _kill_process(
        pidfile => $dir . '/tmp/admin.pid',
    );

    return 1;
}

sub init {
    my ( undef, $o_conf, $h_args ) = @_;

    my $root_dir = $h_args->{root_dir};

    App::Files::make_path( path => $root_dir . $o_conf->{path}->{bkp} );
    App::Files::make_path( path => $root_dir . $o_conf->{path}->{html} );
    App::Files::make_path( path => $root_dir . $o_conf->{path}->{tpl} );
    App::Files::make_path( path => $root_dir . '/log' );

    my $strg_type = $o_conf->{storage}->{type};

    if ( $strg_type eq 'sqlite' ) {
        my $strg_path = $o_conf->{storage}->{path};
        my $strg_name = $o_conf->{storage}->{name};

        my $db_file  = $root_dir . $strg_path . q{/} . $strg_name;
        my $sql_file = $root_dir . $strg_path . q{/} . 'init.sql';

        if ( !-f $sql_file ) {
            _tellme( 'Aborted init: no sql file - ' . $sql_file );
            return;
        }

        my $call = "sqlite3 ${db_file} < ${sql_file}";
        _tellme($call);

        my $err = _call_system(
            call => $call,
        );

        my $msg = $err ? $err : 'init done';
        _tellme($msg);

    }

    return 1;
}

sub _starman {
    my (%args) = @_;

    my $p   = $args{port};
    my $w   = $args{workers};
    my $dir = $args{dir};
    my $pf  = $dir . $args{pidfile};
    my $el  = $dir . $args{errorlog};
    my $al  = $dir . $args{accesslog};
    my $af  = $dir . $args{appfile};

    my $err = _call_system(
        call =>
            "starman --daemonize --port $p --workers $w --pid $pf --error-log $el --access-log $al $af",
    );

    my $msg = $err ? $err : $af . ' started';
    _tellme($msg);

    return;
}

sub _kill_process {
    my (%args) = @_;

    my $pidfile = $args{pidfile};

    if ( !-e $pidfile ) {
        return "File $pidfile - not found, skip";
    }

    my $fh = FileHandle->new;
    my $pid;
    if ( $fh->open("< $pidfile") ) {
        my @lines = $fh->getlines;
        $fh->close;
        $pid = $lines[0];
    }

    if ( !$pid ) {
        return "Failed to read PID from file - $pidfile, skip";
    }

    chomp $pid;

    my $err = _call_system(
        call    => "kill -s QUIT $pid",
        purpose => 'kill ' . $pid,
    );
    my $msg = $err ? $err : $pidfile . ' killed';
    _tellme($msg);

    return;
}

sub _call_system {
    my (%args) = @_;

    system $args{call};

    if ( $CHILD_ERROR == EXECFAIL ) {
        return "failed to execute: $OS_ERROR\n";
    }
    elsif ( $CHILD_ERROR & CHILDSIG ) {
        my $sig = $CHILD_ERROR & CHILDSIG;
        return "child died with signal $sig\n";
    }

    return;
}

#
# some helpers
#

sub _tellme {
    my ($input) = @_;

    my $str;
    if   ( !reftype $input ) { $str = $input; }
    else                     { $str = Dumper($input); }

    say _fmt4log($str) or croak 'Abort: failed to say';

    return;
}

sub _fmt4log {
    my ($str) = @_;

    return sprintf '%s - %s', _timenow(), $str;
}

sub _timenow {
    return strftime '%Y-%b-%e %H:%M:%S', localtime;
}

1;
