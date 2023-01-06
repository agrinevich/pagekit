package App::Admin;

use Const::Fast;
use Plack::Request;
use Encode qw(decode encode);

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
const my $_RESPONSE_404   => 404;
const my $_RESPONSE_500   => 500;
const my $NOT_FOUND       => 'not_found';

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
        if ( $h_result->{err} eq $NOT_FOUND ) {
            # entity module not found
            my $o_response = $o_request->new_response($_RESPONSE_404);
            $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
            $o_response->body(q{404: not found});
            return $o_response;
        }
        else {
            my $o_response = $o_request->new_response($_RESPONSE_500);
            $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
            $o_response->body( $h_result->{err} );
            return $o_response;
        }
    }

    if ( $h_result->{url} ) {
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

1;
