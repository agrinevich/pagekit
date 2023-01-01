package Storage::Sqlite;

use Carp qw(carp croak);
use DBI;

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
    my ( $self, $entity, $h_filters ) = @_;

    my $sel = qq{SELECT * FROM $entity};

    my @fields = keys %{$h_filters};
    if ( scalar @fields ) {
        my @pairs;
        foreach my $k (@fields) {
            my $v = $self->dbh->quote( $h_filters->{$k} );
            push @pairs, "$k = $v";
        }
        my $pairs = join ' AND ', @pairs;
        $sel .= " WHERE $pairs";
    }

    my $h_rows = $self->dbh->selectall_hashref( $sel, 'id' );

    return ( $h_rows, undef );
}

sub one {
    my ( $self, $entity, $id ) = @_;

    my $sel   = qq{SELECT * FROM $entity WHERE id = $id};
    my $h_row = $self->dbh->selectrow_hashref($sel);

    return ( $h_row, undef );
}

sub add {
    my ( $self, $entity, $h_data ) = @_;

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

    my $ins = qq{INSERT INTO $entity ($fields) VALUES ($placeholders)};
    my $sth = $self->dbh->prepare($ins) or croak $self->dbh->errstr;
    my $rv  = $sth->execute(@values) or croak $self->dbh->errstr;
    my $id  = $self->dbh->last_insert_id();

    return ( $id, undef );
}

sub upd {
    my ( $self, $entity, $h_data ) = @_;

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

    my $upd = qq{UPDATE $entity SET $pairs WHERE id = $id};
    my $sth = $self->dbh->prepare($upd) or croak $self->dbh->errstr;
    my $rv  = $sth->execute(@values) or croak $self->dbh->errstr;

    return;
}

sub del {
    my ( $self, $entity, $h_filters ) = @_;

    my $del = qq{DELETE FROM $entity};

    my @fields = keys %{$h_filters};
    if ( scalar @fields ) {
        my @pairs;
        foreach my $k (@fields) {
            my $v = $self->dbh->quote( $h_filters->{$k} );
            push @pairs, "$k = $v";
        }
        my $pairs = join ' AND ', @pairs;
        $del .= " WHERE $pairs";
    }

    my $rv = $self->dbh->do($del) or croak $self->dbh->errstr;

    return;
}

1;
