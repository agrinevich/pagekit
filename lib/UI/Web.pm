package UI::Web;

use Carp qw(carp croak);

use UI::Web::Page;
use UI::Web::Pagemark;
# use UI::Web::Pagefile;
use UI::Web::Lang;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

sub parse_request {
    my ( $self, $o_request ) = @_;

    my $entity = _parse_path( $o_request->path_info() );

    my $o_params = $o_request->parameters();

    if ( !scalar keys %{$o_params} && !$entity ) {
        $entity = 'page';
    }

    if ( !exists $o_params->{do} ) {
        $o_params->{do} = 'list';
    }

    my $o_uploads = $o_request->uploads();

    return ( $entity, $o_params, $o_uploads );
}

# /admin/something
sub _parse_path {
    my ($path_info) = @_;

    my @path_chunks = split m{\/}, $path_info;

    # if we have empty first chunk - drop it
    if ( !length $path_chunks[0] ) {
        shift @path_chunks;
    }

    # first part is always 'admin' (its Admin application)
    # drop it
    shift @path_chunks;

    my $entity = shift @path_chunks;

    return $entity;
}

#
# result can contain one of:
#   url   - will be redirected
#   err   - will be rendered as page
#   body  - will be rendered as page
#
sub build_response {
    my ( $self, $entity, $o_params, $h_entity_response ) = @_;

    if ( exists $h_entity_response->{err} ) {
        return {
            err => $h_entity_response->{err},
        };
    }

    if ( exists $h_entity_response->{url} ) {
        return {
            url => $h_entity_response->{url},
        };
    }

    my $adapter_class  = 'UI::Web::' . ucfirst($entity);
    my $adapter_method = $h_entity_response->{action};
    if ( !$adapter_class->can($adapter_method) ) {
        return {
            err => "$adapter_class can not '$adapter_method'",
        };
    }

    my $h_result = $adapter_class->new( app => $self->app )->$adapter_method(
        req_params => $o_params,
        data       => $h_entity_response->{data},
    );

    return $h_result;
}

#
# returns to Controller
#
sub generate {
    my ($self) = @_;

    return UI::Web::Page->new( app => $self->app )->gen_pages();
}

1;
