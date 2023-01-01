package Ctl;

use Carp qw(carp croak);
use Entity::Page;
use Entity::Pagemark;
use Entity::Lang;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

# When you run /bin/launcher.pl
# App::Admin starts and gives Controller 2 adapters:
#
# uih - User Interface Handler (web, cli, api)
# sh  - Storage Handler (memory, file, database)
#
# Request from UI passes via Controller to Entities (Page, Lang, etc)
# and then response goes from Entities via Controller to UI.
# Entities and UI read/write to Storage via Controller.

has 'uih' => (
    is       => 'ro',
    required => 1,
);

has 'sh' => (
    is       => 'ro',
    required => 1,
);

sub dispatch {
    my ( $self, $entity, $o_params ) = @_;

    my $class  = 'Entity::' . ucfirst($entity);
    my $action = $o_params->{do};

    if ( !$class->can($action) ) {
        return {
            err => "Ctl failed to dispatch: '$class' cannot '$action'",
        };
    }

    delete $o_params->{do};

    $o_params->{ctl} = $self;
    return $class->new( %{$o_params} )->$action($o_params);
}

1;
