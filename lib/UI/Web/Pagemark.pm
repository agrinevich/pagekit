package UI::Web::Pagemark;

use Const::Fast;
use Carp qw(carp croak);

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

const my $_ENTITY => 'pagemark';

sub list {
    my ( $self, %args ) = @_;

    my $h_table    = $args{data};
    my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $page_id = $req_params->{fltr_page_id} || 1;
    my $lang_id = $req_params->{fltr_lang_id} || 1;

    my ( $h_page, $err_str ) = $self->app->ctl->sh->one( 'page', $page_id );

    my $list = $self->_build_list(
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_item => 'list-item.html',
        a_items  => $h_table,
        h_vars   => {
            page_id => $page_id,
            lang_id => $lang_id,
        },
    );

    my ( $h_langs, $err_str3 ) = $self->app->ctl->sh->list('lang');
    my $lang_links = $self->_build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'lang-link.html',
        tpl_slctd => 'lang-linkb.html',
        a_items   => $h_langs,
        slctd_id  => $lang_id,
        h_vars    => {
            page_id => $page_id,
        },
    );

    my $files;
    {
        my ( $h_lang, $err_str2 ) = $self->app->ctl->sh->one( 'lang', $lang_id );
        my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};
        my $page_path = $lang_path . $h_page->{path};
        my $html_path = $self->app->config->{path}->{html};

        my $a_files = $self->app->ctl->gh->get_files(
            path       => $html_path . $page_path,
            files_only => 1,
        );

        my $h_files = {};
        foreach my $h_file ( @{$a_files} ) {
            my $key = $h_file->{name};
            $h_files->{$key} = $h_file;
        }

        $files = $self->_build_list(
            root_dir => $root_dir,
            tpl_path => $tpl_path . q{/} . $_ENTITY,
            tpl_item => 'page-file.html',
            a_items  => $h_files,
            h_vars   => {
                page_path => $page_path,
                page_id   => $page_id,
                lang_id   => $lang_id,
            },
        );
    }

    my $html_body = $self->app->ctl->gh->render(
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'list.html',
        h_vars   => {
            list       => $list,
            files      => $files,
            page_id    => $page_id,
            page_name  => $h_page->{name},
            lang_links => $lang_links,
            lang_slctd => $lang_id,
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

    my $tpl_path  = $args{tpl_path}  // q{};
    my $tpl_item  = $args{tpl_item}  // q{};
    my $tpl_slctd = $args{tpl_slctd} // q{};
    my $h_table   = $args{a_items}   // {};
    my $slctd_id  = $args{slctd_id}  // 0;
    my $h_vars    = $args{h_vars}    // {};

    my $result   = q{};
    my $tpl      = '';
    my $root_dir = $self->app->root_dir;

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        if   ( $slctd_id && $id == $slctd_id ) { $tpl = $tpl_slctd; }
        else                                   { $tpl = $tpl_item; }

        $result .= $self->app->ctl->gh->render(
            tpl_path => $tpl_path,
            tpl_name => $tpl,
            h_vars   => {
                %{$h},
                %{$h_vars},
            },
        );
    }

    return $result;
}

1;
