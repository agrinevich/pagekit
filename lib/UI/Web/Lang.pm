package UI::Web::Lang;

use Const::Fast;
use Carp qw(carp croak);

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

const my $_ENTITY => 'lang';

sub list {
    my ( $self, %args ) = @_;

    my $h_table = $args{data};
    # my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = $self->_build_list(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_item => 'list-item.html',
        # req_params => $req_params,
        h_table => $h_table,
    );

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'list.html',
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

sub one {
    my ( $self, %args ) = @_;

    my $h_data = $args{data};
    # my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'edit.html',
        h_vars   => {
            %{$h_data},
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

sub _build_list {
    my ( $self, %args ) = @_;

    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $tpl_item = $args{tpl_item} // q{};
    my $h_table  = $args{h_table}  // {};

    my $result = q{};

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => $tpl_item,
            h_vars   => $h,
        );
    }

    return $result;
}

1;
