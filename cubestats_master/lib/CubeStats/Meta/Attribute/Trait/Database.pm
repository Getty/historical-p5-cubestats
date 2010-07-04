package CubeStats::Meta::Attribute::Trait::Database;

use CubeStats::Role;

has db_col => (
	is        => 'rw',
	isa       => 'Str',
	predicate => 'has_db_col',
);

no CubeStats::Role;

package Moose::Meta::Attribute::Custom::Trait::Database;
sub register_implementation { 'CubeStats::Meta::Attribute::Trait::Database' }

1;
