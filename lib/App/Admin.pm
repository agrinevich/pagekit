package App::Admin;

use Const::Fast;
use Plack::Request;
use Encode qw(decode encode);
use Carp qw(carp croak);

use UI::Web;
use Storage::Sqlite;
use Generator::Base;
use Ctl;

use Moo;
extends 'App::Basic';
use namespace::clean;

has 'ctl' => (
    is => 'rw',
);

our $VERSION = '0.2';

const my $_RESPONSE_OK    => 200;
const my $_RESPONSE_REDIR => 302;
const my $_RESPONSE_500   => 500;

sub run {
    my ( $self, $env ) = @_;

    my $o_request = Plack::Request->new($env);

    my $storage_type  = $self->config->{storage}->{type};
    my $storage_class = 'Storage::' . ucfirst($storage_type);

    my $ctl = Ctl->new(
        uih => UI::Web->new( app => $self ),
        sh  => $storage_class->new( app => $self ),
        gh  => Generator::Base->new( app => $self ),
    );
    $self->ctl($ctl);

    my $h_result = $self->ctl->process_ui($o_request);

    if ( exists $h_result->{err} ) {
        my $o_response = $o_request->new_response($_RESPONSE_500);
        $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
        $o_response->body( $h_result->{err} );
        return $o_response;
    }

    if ( exists $h_result->{url} ) {
        my $o_response = $o_request->new_response($_RESPONSE_REDIR);
        $o_response->redirect( $h_result->{url} );
        return $o_response;
    }

    # now we know we have $h_result->{body}

    my $o_response = $o_request->new_response($_RESPONSE_OK);

    if ( $h_result->{content_length} ) {
        $o_response->content_length( $h_result->{content_length} );
    }

    if ( $h_result->{content_encoding} ) {
        $o_response->content_encoding( $h_result->{content_encoding} );
    }

    if ( $h_result->{file_name} ) {
        $o_response->header(
            'Content-Disposition' => 'attachment;filename=' . $h_result->{file_name},
        );
    }

    my $content_type;
    if   ( $h_result->{content_type} ) { $content_type = $h_result->{content_type}; }
    else                               { $content_type = 'text/html'; }
    $o_response->header( 'Content-Type' => $content_type, charset => 'Utf-8' );

    my $octets;
    if ( !$h_result->{is_encoded} ) { $octets = encode( 'UTF-8', $h_result->{body} ); }
    else                            { $octets = $h_result->{body} }

    $o_response->body($octets);

    return $o_response;
}

sub upload {
    my ( $self, $params, $uploads ) = @_;

    if ( !$params->{page_id} ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$params->{lang_id} ) {
        return {
            err => 'lang_id is required',
        };
    }

    my ( $h_page, $err_str ) = $self->ctl->sh->one( 'page', $params->{page_id} );

    my ( $h_lang, $err_str2 ) = $self->ctl->sh->one( 'lang', $params->{lang_id} );
    my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};

    my $html_path = $self->config->{path}->{html};
    my $page_dir  = $self->root_dir . $html_path . $lang_path . $h_page->{path};

    my $file = $uploads->{file};

    my $file_name = $file->basename;
    my @chunks    = split /[.]/, $file_name;
    my $ext       = pop @chunks;
    my $name      = join q{}, @chunks;
    $name =~ s/[^\w\-\_]//g;
    if ( !$name ) {
        $name = time;
    }

    my $file_tmp = $file->path();
    my $new_file = $page_dir . q{/} . $name . q{.} . $ext;
    rename $file_tmp, $new_file;

    my $mode_readable = oct '644';
    chmod $mode_readable, $new_file;

    my $url = $self->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $params->{page_id};
    $url .= '&fltr_lang_id=' . $params->{lang_id};

    return {
        url => $url,
    };
}

sub rmfile {
    my ( $self, $params ) = @_;

    if ( !$params->{page_id} ) {
        return {
            err => 'page_id is required',
        };
    }

    if ( !$params->{lang_id} ) {
        return {
            err => 'lang_id is required',
        };
    }

    if ( !$params->{name} ) {
        return {
            err => 'file name is required',
        };
    }

    my ( $h_page, $err_str ) = $self->ctl->sh->one( 'page', $params->{page_id} );

    my ( $h_lang, $err_str2 ) = $self->ctl->sh->one( 'lang', $params->{lang_id} );
    my $lang_path = $h_lang->{nick} ? q{/} . $h_lang->{nick} : q{};

    my $html_path = $self->config->{path}->{html};
    my $page_dir  = $self->root_dir . $html_path . $lang_path . $h_page->{path};
    my $file      = $page_dir . q{/} . $params->{name};
    # carp( 'file=' . $file );

    unlink($file);

    my $url = $self->config->{site}->{host} . '/admin/pagemark?do=list';
    $url .= '&fltr_page_id=' . $params->{page_id};
    $url .= '&fltr_lang_id=' . $params->{lang_id};

    return {
        url => $url,
    };
}

1;
