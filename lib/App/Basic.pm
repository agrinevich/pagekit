package App::Basic;

#
# Basic app class
#

use App::Config;

use Moo;
use namespace::clean;

our $VERSION = '0.2';

has 'root_dir' => (
    is       => 'ro',
    required => 1,
);

has 'conf_file' => (
    is       => 'ro',
    required => 1,
);

has 'config' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return App::Config::get_config(
            file => $self->root_dir . q{/} . $self->conf_file,
        );
    },
);

1;
