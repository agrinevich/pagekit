package UI::Web::Page;

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

const my $_ENTITY => 'page';

sub list {
    my ( $self, %args ) = @_;

    my $h_table = $args{data};
    # my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my $list = $self->_build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'list-item.html',
        a_items   => $h_table,
        parent_id => 0,
        level     => 0,
    );

    my $options = $self->_build_list(
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

    my $h_page = $args{data};
    # my $req_params = $args{req_params};

    my $root_dir = $self->app->root_dir;
    my $tpl_path = $self->app->config->{path}->{templates};

    my ( $h_table, $err_str ) = $self->app->ctl->sh->list('page');

    my ( $h_mods, $err_str2 ) = $self->app->ctl->sh->list('mod');
    $h_mods->{0} = {
        id   => 0,
        app  => 'admin',
        name => 'page',
    };

    # parent can be anyone except itself
    my %filtered = %{$h_table};
    my $id       = $h_page->{id};
    delete $filtered{$id};

    my $options = $self->_build_list(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path . q{/} . $_ENTITY,
        tpl_item  => 'option.html',
        a_items   => \%filtered,
        parent_id => 0,
        level     => 0,
    );

    my $mod_options = _build_list2(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_item => 'mod-option.html',
        a_items  => $h_mods,
        id_sel   => $h_page->{mod_id},
    );

    my $html_body = UI::Web::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $_ENTITY,
        tpl_name => 'edit.html',
        h_vars   => {
            %{$h_page},
            options     => $options,
            mod_options => $mod_options,
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
    my ( $self, %args ) = @_;

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

        my $mod_link = q{};
        if ( $h->{mod_id} ) {
            my ( $h_mod, $err_str ) = $self->app->ctl->sh->one( 'mod', $h->{mod_id} );
            $mod_link = UI::Web::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path,
                tpl_name => 'mod-link.html',
                h_vars   => {
                    page_id => $id,
                    %{$h_mod}
                },
            );
        }
        $h->{mod_link} = $mod_link;

        $h->{attr} = $attr{$id};
        $h->{dash} = $dash;

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => $tpl_item,
            h_vars   => $h,
        );

        $result .= $self->_build_list(
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

sub _build_list2 {
    my (%args) = @_;

    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $tpl_item = $args{tpl_item} // q{};
    my $h_table  = $args{a_items}  // {};
    my $id_sel   = $args{id_sel}   // 0;

    my $result = q{};
    my %attr   = ( $id_sel => ' selected' );

    foreach my $id ( sort keys %{$h_table} ) {
        my $h = $h_table->{$id};

        $h->{attr} = $attr{$id};

        $result .= UI::Web::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => $tpl_item,
            h_vars   => $h,
        );
    }

    return $result;
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
