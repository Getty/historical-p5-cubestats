package CubeStats::AC::Maprot::Map;

use CubeStats;

has map => (
	is => 'ro',
	isa => 'Str',
);

has mode => (
	is => 'ro',
	isa => 'Int',
);

has minutes => (
	is => 'ro',
	isa => 'Int',
);

has allowvote => (
	is => 'ro',
	isa => 'Int',
);

has minplayer => (
	is => 'ro',
	isa => 'Int',
	predicate => 'has_minplayer',
);

has maxplayer => (
	is => 'ro',
	isa => 'Int',
	predicate => 'has_maxplayer',
);

has skiplines => (
	is => 'ro',
	isa => 'Int',
	predicate => 'has_skiplines',
);

1;
