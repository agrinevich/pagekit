package UI::Web;

use Carp qw(carp croak);

use UI::Web::Page;
use UI::Web::Pagemark;
use UI::Web::Lang;
# use Data::Dumper;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'app' => (
    is       => 'ro',
    required => 1,
);

#
# returns to App::Admin
#
sub process {
    my ( $self, $o_request ) = @_;

    my $entity = _parse_path( $o_request->path_info() );

    my $o_params = $o_request->parameters();
    if ( !exists $o_params->{do} ) {
        $o_params->{do} = 'list';
    }
    # carp Dumper($o_params);

    my $h_entity_response = $self->app->ctl->dispatch( $entity, $o_params );

    if ( exists $h_entity_response->{err} ) {
        return {
            body => $h_entity_response->{err},
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
            err => __PACKAGE__ . ": $adapter_class failed to '$adapter_method'",
        };
    }

    return $adapter_class->new( app => $self->app )->$adapter_method(
        req_params => $o_params,
        data       => $h_entity_response->{data},
    );
}

#
# returns to Controller
#
sub generate {
    my ($self) = @_;

    return UI::Web::Page->new( app => $self->app )->gen_pages();
}

sub _parse_path {
    my ($path_info) = @_;

    my @path_chunks = split m{\/}, $path_info;

    # drop empty first chunk ???
    if ( !length $path_chunks[0] ) {
        shift @path_chunks;
    }

    my $chunk2 = $path_chunks[1];
    # $chunk2 =~ s/\W//g;

    # default entity is 'page'
    if ( !$chunk2 ) {
        $chunk2 = 'page';
    }

    return $chunk2;
}

1;
