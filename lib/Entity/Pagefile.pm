package Entity::Pagefile;

use Carp qw(carp croak);
use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'ctl' => (
    is       => 'ro',
    required => 1,
);

has 'id' => (
    is      => 'rw',
    default => undef,
);

has 'page_id' => (
    is      => 'rw',
    default => undef,
);

has 'lang_id' => (
    is      => 'rw',
    default => undef,
);

has 'name' => (
    is      => 'rw',
    default => undef,
);

has 'path' => (
    is      => 'rw',
    default => undef,
);

sub list {
    my ( $self, $h_filters ) = @_;

    # extract filters
    my %filters;
    foreach my $k ( keys %{$h_filters} ) {
        if ( $k =~ /^fltr/i ) {
            my @k_parts = split /\_/, $k;
            shift @k_parts;
            my $field = join q{_}, @k_parts;

            $filters{$field} = $h_filters->{$k};
        }
    }

    my $page_id = $filters{page_id} || 1;
    my $lang_id = $filters{lang_id} || 1;

    my ( $h_page, $err_str2 ) = $self->ctl->sh->one( 'page', $page_id );
    my ( $h_lang, $err_str3 ) = $self->ctl->sh->one( 'lang', $lang_id );

    # my $app       = $self->ctl->sh->app;
    # my $html_dir  = $app->root_dir . $app->config->{path}->{html};
    # my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};
    # my $dir       = $html_dir . $lang_path . $h_page->{path};

    # WTF am i doing?
    #
    #
    # my ( $h_table, $err_str ) = $app->file_list( dir => $dir );
    # if ($err_str) {
    #     return {
    #         err => $err_str,
    #     };
    # }
    my $h_table = {};

    return {
        action => 'list',
        data   => $h_table,
    };
}

sub one {
    return {
        err => 'not implemented for files',
    };
}

sub add {
    my ($self) = @_;

    if ( !$self->page_id ) {
        return {
            err => 'page_id is required to add pagefile',
        };
    }

    if ( !$self->lang_id ) {
        return {
            err => 'lang_id is required to add pagefile',
        };
    }

    if ( !$self->name ) {
        return {
            err => 'name is required to add pagefile',
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/pagefile?do=list';
    $url .= '&fltr_page_id=' . $self->page_id;
    $url .= '&fltr_lang_id=' . $self->lang_id;

    return {
        url => $url,
    };
}

sub upd {
    return {
        err => 'not implemented for files',
    };
}

sub del {
    my ($self) = @_;

    if ( !$self->id ) {
        return {
            err => 'id is required to delete pagefile',
        };
    }

    my $app = $self->ctl->sh->app;
    my $url = $app->config->{site}->{host} . '/admin/pagefile?do=list';
    $url .= '&fltr_page_id=' . $self->page_id;
    $url .= '&fltr_lang_id=' . $self->lang_id;

    return {
        url => $url,
    };
}

1;
