package UI::Web::File;

use Const::Fast;
use Carp qw(carp croak);

use UI::Web::Renderer;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

const my $_ENTITY => 'file';

sub templates {
    my ( $self, %args ) = @_;

    my $h_data = $args{data};

    my $h_files = $h_data->{h_files};
    my $f_cur   = $h_data->{f_cur};
    my $f_body  = $h_data->{f_body};

    $f_body = UI::Web::Renderer::do_escape($f_body);

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = _tpl_list(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        a_items  => $h_files,
    );

    my $html_body = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'templates.html',
        h_vars   => {
            list   => $list,
            f_cur  => $f_cur,
            f_body => $f_body,
        },
    );

    my $res = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
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
    my (%args) = @_;

    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $h_files  = $args{a_items}  // {};

    my $result = q{};

    foreach my $dname ( sort keys %{$h_files} ) {
        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => 'templates-dir.html',
            h_vars   => {
                dname => ( $dname || q{root} ),
            },
        );

        my $fpath   = $dname ? $dname . q{/} : q{};
        my $a_files = $h_files->{$dname};

        foreach my $h_file ( @{$a_files} ) {
            $result .= UI::Web::Renderer::parse_html(
                root_dir => $root_dir,
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

    my $list = _bkp_list(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        a_items  => $a_bkps,
    );

    my $html_body = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'backups.html',
        h_vars   => {
            list => $list,
        },
    );

    my $res = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
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
    my (%args) = @_;

    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $a_bkps   = $args{a_items}  // {};

    my $result   = q{};
    my $tpl_item = q{};

    foreach my $h_bkp ( sort @{$a_bkps} ) {
        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
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
