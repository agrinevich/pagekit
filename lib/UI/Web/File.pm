package UI::Web::File;

use Carp qw(carp croak);

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

sub snippets {
    my ( $self, %args ) = @_;

    my $h_data = $args{data};

    my $a_files = $h_data->{a_files};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = $self->_snippet_list(
        tpl_path => $tpl_path . '/file',
        a_items  => $a_files,
    );

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . '/file',
        tpl_name => 'snippets.html',
        h_vars   => {
            list => $list,
        },
    );

    my $res = $self->app->ctl->gh->render(
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $html_body,
        },
    );

    return {
        body => $res,
    };
}

sub _snippet_list {
    my ( $self, %args ) = @_;

    my $tpl_path = $args{tpl_path} // q{};
    my $a_files  = $args{a_items}  // {};

    my $result = q{};

    foreach my $h_file ( @{$a_files} ) {
        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => 'snippets-item.html',
            h_vars   => {
                name => $h_file->{name},
            },
        );

    }

    return $result;
}

sub templates {
    my ( $self, %args ) = @_;

    my $h_data = $args{data};

    my $h_files = $h_data->{h_files};
    my $f_cur   = $h_data->{f_cur};
    my $f_body  = $h_data->{f_body};

    $f_body = $self->app->ctl->gh->do_escape($f_body);

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = $self->_tpl_list(
        tpl_path => $tpl_path . '/file',
        a_items  => $h_files,
    );

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . '/file',
        tpl_name => 'templates.html',
        h_vars   => {
            list   => $list,
            f_cur  => $f_cur,
            f_body => $f_body,
        },
    );

    my $res = $self->app->ctl->gh->render(
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $html_body,
        },
    );

    return {
        body => $res,
    };
}

sub _tpl_list {
    my ( $self, %args ) = @_;

    my $tpl_path = $args{tpl_path} // q{};
    my $h_files  = $args{a_items}  // {};

    my $result = q{};

    foreach my $dname ( sort keys %{$h_files} ) {
        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => 'templates-dir.html',
            h_vars   => {
                dname => ( $dname || q{root} ),
            },
        );

        my $fpath   = $dname ? $dname . q{/} : q{};
        my $a_files = $h_files->{$dname};

        foreach my $h_file ( @{$a_files} ) {
            $result .= $self->app->ctl->gh->render(
                tpl_path => $tpl_path,
                tpl_name => 'templates-file.html',
                h_vars   => {
                    fpath => $fpath,
                    %{$h_file},
                },
            );
        }
    }

    return $result;
}

sub backups {
    my ( $self, %args ) = @_;

    my $a_bkps = $args{data};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = $self->_bkp_list(
        tpl_path => $tpl_path . '/file',
        a_items  => $a_bkps,
    );

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . '/file',
        tpl_name => 'backups.html',
        h_vars   => {
            list => $list,
        },
    );

    my $res = $self->app->ctl->gh->render(
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $html_body,
        },
    );

    return {
        body => $res,
    };
}

sub _bkp_list {
    my ( $self, %args ) = @_;

    my $tpl_path = $args{tpl_path} // q{};
    my $a_bkps   = $args{a_items}  // {};

    my $result   = q{};
    my $tpl_item = q{};

    foreach my $h_bkp ( @{$a_bkps} ) {
        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => 'backups-item.html',
            h_vars   => {
                name => $h_bkp->{name},
                size => $h_bkp->{size},
            },
        );
    }

    return $result;
}

sub bkpdownload {
    my ( $self, %args ) = @_;

    my $fhandle = $args{data}->{fhandle};
    my $fname   = $args{data}->{fname};

    return {
        body             => $fhandle,
        file_name        => $fname,
        is_encoded       => 1,
        content_type     => 'application/zip',
        content_encoding => 'zip',
    };
}

1;
