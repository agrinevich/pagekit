package UI::Web::Page;

use Const::Fast;
use Carp qw(carp croak);

use UI::Web::Renderer;
use UI::Web::Page::Standard;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

const my $_ENTITY => 'page';

sub list {
    my ( $self, %args ) = @_;

    my $h_table    = $args{data};
    my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = _build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'list-item.html',
        a_items   => $h_table,
        parent_id => 0,
        level     => 0,
    );

    my $options = _build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'option.html',
        a_items   => $h_table,
        parent_id => 0,
        level     => 0,
    );

    my $html_body = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'list.html',
        h_vars   => {
            list    => $list,
            options => $options,
            # msg_text    => $msg_text,
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

sub one {
    my ( $self, %args ) = @_;

    my $h_page     = $args{data};
    my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my ( $h_table, $err_str ) = $self->app->ctl->sh->list('page');

    # parent can be anyone except itself
    my %filtered = %{$h_table};
    my $id       = $h_page->{id};
    delete $filtered{$id};

    my $options = _build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'option.html',
        a_items   => \%filtered,
        parent_id => 0,
        level     => 0,
    );

    my $html_body = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'edit.html',
        h_vars   => {
            %{$h_page},
            options => $options,
            # msg_text    => $msg_text,
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

#
# recursion - to build as tree
#
sub _build_list {
    my (%args) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_item  = $args{tpl_item}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $h_table   = $args{a_items}   // {};
    my $parent_id = $args{parent_id} // 0;
    my $id_sel    = $args{id_sel}    // 0;
    my $level     = $args{level}     // 0;

    if ( $level > 5 ) {
        carp 'recursion level > 5';
        return;
    }

    my $result = q{};
    my %attr   = ( $id_sel => ' selected' );
    my $dash   = sprintf q{&nbsp;-} x $level;

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        if ( $h->{parent_id} != $parent_id ) {
            next;
        }

        $h->{attr} = $attr{$id};
        $h->{dash} = $dash;

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => $tpl_item,
            h_vars   => $h,
        );

        $result .= _build_list(
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            tpl_item  => $tpl_item,
            a_items   => $h_table,
            parent_id => $id,
            level     => $level + 1,
            id_sel    => $id_sel,
        );
    }

    return $result;
}

sub gen_pages {
    my ($self) = @_;

    my $root_dir  = $self->app->root_dir;
    my $html_path = $self->app->config->{path}->{html};
    my $tpl_path  = $self->app->config->{path}->{templates};

    my ( $h_langs, $err_str )  = $self->app->ctl->sh->list('lang');
    my ( $h_pages, $err_str2 ) = $self->app->ctl->sh->list('page');

    foreach my $id ( sort keys %{$h_langs} ) {
        my $h = $h_langs->{$id};

        my $lang_path = $h->{nick} ? q{/} . $h->{nick} : q{};

        $self->go_tree(
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            lang_id   => $id,
            lang_path => $lang_path,
            parent_id => 0,
            level     => 0,
            items     => $h_pages,
        );
    }

    return;
}

sub go_tree {
    my ( $self, %args ) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $html_path = $args{html_path} // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $parent_id = $args{parent_id} // 0;
    my $level     = $args{level}     // 0;
    my $h_pages   = $args{items}     // {};

    if ( $level > 5 ) {
        carp 'recursion level > 5';
        return;
    }

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        if ( $h->{parent_id} != $parent_id ) {
            next;
        }

        # TODO: add another page types (plugins)
        my $page_type = 'Standard';
        my $gen_class = 'UI::Web::Page::' . $page_type;

        my %marks = ();
        my ( $h_pagemarks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $id,
                lang_id => $lang_id,
            },
        );
        # why not using %{$h_pagemarks} ?
        while ( my ( $mark_id, $h_mark ) = each( %{$h_pagemarks} ) ) {
            my $markname  = $h_mark->{name};
            my $markvalue = $h_mark->{value};
            $marks{$markname} = $markvalue;
        }

        my ( $d_navi, $m_navi ) = $self->_build_navi(
            root_dir        => $root_dir,
            tpl_path        => $tpl_path . q{/} . $_ENTITY,
            lang_id         => $lang_id,
            lang_path       => $lang_path,
            id_cur          => $id,
            parent_id       => $parent_id,
            page_name_inner => $h->{name},
            # child_qty => $child_qty,
        );
        $marks{desktop_navi} = $d_navi;
        $marks{mobile_navi}  = $m_navi;

        $gen_class->gen(
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            lang_path => $lang_path,
            page_path => $h->{path},
            h_data    => {%marks},
        );

        $self->go_tree(
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            lang_id   => $lang_id,
            lang_path => $lang_path,
            parent_id => $id,
            level     => $level + 1,
            items     => $h_pages,
        );
    }

    return;
}

#
# navigation link text is built from special marks for given language
#
sub _build_navi {
    my ( $self, %args ) = @_;

    my $root_dir        = $args{root_dir}        // q{};
    my $tpl_path        = $args{tpl_path}        // q{};
    my $lang_id         = $args{lang_id}         // 0;
    my $lang_path       = $args{lang_path}       // q{};
    my $id_cur          = $args{id_cur}          // 0;
    my $parent_id       = $args{parent_id}       // 0;
    my $page_name_inner = $args{page_name_inner} // q{};
    # my $child_qty = $args{child_qty} // 0;

    my $d_links = q{};
    my $m_links = q{};

    my ( $h_pages, $err_str ) = $self->app->ctl->sh->list(
        'page', {
            parent_id => $parent_id,
        },
    );

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        my $page_name;
        my ( $h_marks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $id,
                lang_id => $lang_id,
                name    => 'page_name',
            },
        );
        my @mark_ids = keys %{$h_marks};
        if ( scalar @mark_ids ) {
            my $mark_id = $mark_ids[0];
            $page_name = $h_marks->{$mark_id}->{value};
        }
        else {
            $page_name = $page_name_inner;
        }

        my $page_path = $h->{path};
        my $suffix    = q{};

        my ( $d_child_links, $m_child_links );
        if ( $h->{id} == $id_cur ) {
            $suffix = '-cur';
            ( $d_child_links, $m_child_links ) = $self->_child_links(
                root_dir  => $root_dir,
                tpl_path  => $tpl_path,
                lang_id   => $lang_id,
                lang_path => $lang_path,
                parent_id => $id,
            );
        }

        $d_links .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "page-dnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $lang_path . $page_path,
                child_links => $d_child_links,
            },
        );

        $m_links .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "page-mnavi-item$suffix.html",
            h_vars   => {
                name        => $page_name,
                path        => $lang_path . $page_path,
                child_links => $m_child_links,
            },
        );
    }

    return ( $d_links, $m_links );
}

sub _child_links {
    my ( $self, %args ) = @_;

    my $root_dir  = $args{root_dir}  // q{};
    my $tpl_path  = $args{tpl_path}  // q{};
    my $lang_id   = $args{lang_id}   // 0;
    my $lang_path = $args{lang_path} // q{};
    my $parent_id = $args{parent_id} // 0;

    my $d_links = q{};
    my $m_links = q{};

    my ( $h_pages, $err_str ) = $self->app->ctl->sh->list(
        'page', {
            parent_id => $parent_id,
        },
    );

    foreach my $id ( sort keys %{$h_pages} ) {
        my $h = $h_pages->{$id};

        my ( $h_marks, $err_str ) = $self->app->ctl->sh->list(
            'pagemark', {
                page_id => $id,
                lang_id => $lang_id,
                name    => 'page_name',
            },
        );
        my @mark_ids  = keys %{$h_marks};
        my $mark_id   = $mark_ids[0];
        my $page_name = $h_marks->{$mark_id}->{value};

        my $page_path = $h->{path};

        $d_links .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "page-dnavi-child.html",
            h_vars   => {
                name => $page_name,
                path => $lang_path . $page_path,
            },
        );

        $m_links .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => "page-mnavi-child.html",
            h_vars   => {
                name => $page_name,
                path => $lang_path . $page_path,
            },
        );
    }

    return ( $d_links, $m_links );
}

# sub _build_msg {
#     my (%args) = @_;

#     my $root_dir = $args{root_dir};
#     my $tpl_path = $args{tpl_path};
#     my $tpl_name = $args{tpl_name};
#     my $msg      = $args{msg};

#     return q{} if !$msg;

#     my $html = parse_html(
#         root_dir => $root_dir,
#         tpl_path => $tpl_path,
#         tpl_name => $tpl_name,
#         h_vars   => {
#             text => $MSG_TEXT{$msg},
#         },
#     );

#     return $html;
# }

1;
