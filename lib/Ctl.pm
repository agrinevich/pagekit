package Ctl;

use Carp qw(carp croak);
use Entity::Page;
use Entity::Pagemark;
use Entity::Pagefile;
use Entity::Lang;

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

    my ( $entity, $params ) = $self->uih->parse_request($o_request);

    my $h_entity_response = $self->ask_entity( $entity, $params );

    my $h_result = $self->uih->build_response( $entity, $params, $h_entity_response );

    return $h_result;
}

sub ask_entity {
    my ( $self, $entity, $o_params ) = @_;

    my $class  = 'Entity::' . ucfirst($entity);
    my $action = $o_params->{do};

    if ( !$class->can($action) ) {
        return {
            err => "Ctl failed to ask_entity: '$class' cannot '$action'",
        };
    }

    delete $o_params->{do};

    $o_params->{ctl} = $self;
    return $class->new( %{$o_params} )->$action($o_params);
}

1;
