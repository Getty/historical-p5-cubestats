package CubeStats::Role::Database;

use CubeStats::Role;
use CubeStats::DB;

has db => (
	isa => 'CubeStats::DB',
	is => 'rw',
	lazy => 1,
	default => sub { new CubeStats::DB },
);

no CubeStats::Role;

1;
