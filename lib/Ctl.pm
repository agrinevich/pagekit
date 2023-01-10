package Ctl;

use Carp qw(carp croak);
use Entity::Page;
use Entity::Pagemark;
use Entity::Lang;
use Entity::File;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

# When you run /bin/launcher.pl
# App::Admin starts and creates Controller with adapters:
#
# uih - User Interface Handler (web, cli, api)
# sh  - Storage Handler (memory, file, database)
# gh  - Generator Handler (writing pages on disk)
#

has 'uih' => (
    is       => 'ro',
    required => 1,
);

has 'sh' => (
    is       => 'ro',
    required => 1,
);

has 'gh' => (
    is       => 'ro',
    required => 1,
);

sub process_ui {
    my ( $self, $o_request ) = @_;

    my ( $entity, $params, $uploads ) = $self->uih->parse_request($o_request);

    my $h_response;
    if ($entity) { $h_response = $self->ask_entity( $entity, $params, $uploads ); }
    else         { $h_response = $self->ask_app( $params, $uploads ); }

    my $h_result = $self->uih->build_response( $entity, $params, $h_response );

    return $h_result;
}

sub ask_entity {
    my ( $self, $entity, $o_params, $o_uploads ) = @_;

    my $class  = 'Entity::' . ucfirst($entity);
    my $action = $o_params->{do};

    if ( !$class->can($action) ) {
        return {
            err => "Ctl failed to ask_entity: '$class' cannot '$action'",
        };
    }

    delete $o_params->{do};

    $o_params->{ctl} = $self;
    return $class->new( %{$o_params} )->$action( $o_params, $o_uploads );
}

sub ask_app {
    my ( $self, $o_params, $o_uploads ) = @_;

    my $app    = $self->gh->app;
    my $action = $o_params->{do};

    if ( $action eq 'run' ) {
        return {
            err => "Ctl cannot 'run' app: admin app already running",
        };
    }

    if ( !$app->can($action) ) {
        return {
            err => "Ctl failed to ask_app: admin app cannot '$action'",
        };
    }

    delete $o_params->{do};

    $o_params->{ctl} = $self;
    return $app->$action( $o_params, $o_uploads );
}

1;
