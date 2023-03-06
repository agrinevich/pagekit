package Storage::Sqlite;

use Carp qw(carp croak);
use DBI;
use DBD::SQLite;

use Moo;
use namespace::clean;

has 'app' => (
    is       => 'ro',
    required => 1,
);

has 'dbh' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        my $db_file
            = $self->app->root_dir
            . $self->app->config->{storage}->{path} . q{/}
            . $self->app->config->{storage}->{name};

        ## no critic (Variables::ProhibitPackageVars)
        my $dbh = DBI->connect(
            'DBI:SQLite:uri=file:' . $db_file . '?mode=rwc', q{}, q{},
            {
                AutoCommit => 1,
                RaiseError => 1,
            },
        ) or croak $DBI::errstr;
        ## use critic

        return $dbh;
    },
);

our $VERSION = '0.2';

sub list {
    my ( $self, $table, $h_where, $a_order, $h_limit ) = @_;

    my $sel = qq{SELECT * FROM $table};

    # WHERE page_id =2 AND type = 'note'
    my @wheres = keys %{ $h_where // {} };
    if ( scalar @wheres ) {
        my @pairs;
        foreach my $k (@wheres) {
            my $v = $self->dbh->quote( $h_where->{$k} );
            push @pairs, "$k = $v";
        }
        my $pairs = join ' AND ', @pairs;
        $sel .= " WHERE $pairs";
    }

    # ORDER BY time DESC, name ASC
    {
        my @pairs;
        foreach my $h ( @{ $a_order // [] } ) {
            my $ord_str = $h->{orderby} . q{ } . $h->{orderhow};
            push @pairs, $ord_str;
        }
        if ( scalar @pairs ) {
            my $pairs = join ', ', @pairs;
            $sel .= ' ORDER BY ' . $pairs;
        }
    }

    # LIMIT qty OFFSET offset;
    if ( exists $h_limit->{qty} ) {
        $sel .= ' LIMIT ' . $h_limit->{qty};
        if ( exists $h_limit->{offset} ) {
            $sel .= ' OFFSET ' . $h_limit->{offset};
        }
    }

    my $h_rows = $self->dbh->selectall_hashref( $sel, 'id' );

    return ( $h_rows, undef );
}

sub count {
    my ( $self, $table, $h_where ) = @_;

    my $sel = qq{SELECT COUNT(*) FROM $table};

    # WHERE page_id =2 AND type = 'note'
    my @wheres = keys %{ $h_where // {} };
    if ( scalar @wheres ) {
        my @pairs;
        foreach my $k (@wheres) {
            my $v = $self->dbh->quote( $h_where->{$k} );
            push @pairs, "$k = $v";
        }
        my $pairs = join ' AND ', @pairs;
        $sel .= " WHERE $pairs";
    }

    my ($count) = $self->dbh->selectrow_array($sel);

    return $count;
}

sub one {
    my ( $self, $table, $id ) = @_;

    my $err;

    my $sel   = qq{SELECT * FROM $table WHERE id = $id};
    my $h_row = $self->dbh->selectrow_hashref($sel);

    return ( $h_row, $err );
}

sub add {
    my ( $self, $table, $h_data ) = @_;

    # keys must be exactly the same as table field names
    my @fields = keys %{$h_data};
    my $fields = join q{,}, @fields;

    my @values;
    my @placeholders;
    foreach my $k (@fields) {
        push @values,       $h_data->{$k};
        push @placeholders, q{?};
    }
    my $placeholders = join q{,}, @placeholders;

    my $ins = qq{INSERT INTO $table ($fields) VALUES ($placeholders)};
    my $sth = $self->dbh->prepare($ins) or croak $self->dbh->errstr;
    my $rv  = $sth->execute(@values) or croak $self->dbh->errstr;
    my $id  = $self->dbh->last_insert_id();

    return ( $id, undef );
}

sub upd {
    my ( $self, $table, $h_data ) = @_;

    my %data = %{$h_data};

    my $id = $data{id};
    delete $data{id};

    my @fields = keys %data;

    my @values;
    my @pairs;
    foreach my $k (@fields) {
        push @values, $data{$k};
        push @pairs,  "$k = ?";
    }
    my $pairs = join q{,}, @pairs;

    my $upd = qq{UPDATE $table SET $pairs WHERE id = $id};
    my $sth = $self->dbh->prepare($upd) or croak $self->dbh->errstr;
    my $rv  = $sth->execute(@values) or croak $self->dbh->errstr;

    return $rv;
}

sub del {
    my ( $self, $table, $h_where ) = @_;

    my $del = qq{DELETE FROM $table};

    my @fields = keys %{$h_where};
    if ( scalar @fields ) {
        my @pairs;
        foreach my $k (@fields) {
            my $v = $self->dbh->quote( $h_where->{$k} );
            push @pairs, "$k = $v";
        }
        my $pairs = join ' AND ', @pairs;
        $del .= " WHERE $pairs";
    }

    my $rv = $self->dbh->do($del) or croak $self->dbh->errstr;

    return $rv;
}

sub backup_create {
    my ( $self, %args ) = @_;

    my $root_dir = $self->app->root_dir();

    my $bkp_file = $root_dir . $args{path} . '/backup.sql';

    $self->dbh->sqlite_backup_to_file($bkp_file);

    return;
}

sub backup_restore {
    my ( $self, %args ) = @_;

    my $root_dir = $self->app->root_dir();

    my $bkp_file = $root_dir . $args{path} . '/backup.sql';

    $self->dbh->sqlite_backup_from_file($bkp_file);

    return;
}

1;
