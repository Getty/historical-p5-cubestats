package CubeStats::DaemonController;

use CubeStats;

extends 'MooseX::DaemonController';

has root => ( isa => 'Str', is => 'ro', required => 1,
    default => sub { $ENV{CUBESTATS_ROOT} } );

has '+pidbase' => (
	lazy => 1,
	default => sub { my $self = shift; $self->root.'/run/' }
);

has '+statefile' => (
	lazy => 1,
	default => sub { my $self = shift; $self->root.'/run/daemoncontroller.state' }
);

has '+configfile' => (
	lazy => 1,
	default => sub { my $self = shift; $self->root.'/localconf/daemoncontroller.xml' }
);

1;
