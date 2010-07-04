package CubeStats::Meta::Attribute::Trait::Formfield;

use CubeStats::Role;

has field_id => (
	is			=> 'rw',
	isa			=> 'Str',
	predicate	=> 'has_field_id',
);

has field_name => (
	is        => 'rw',
	isa       => 'Str',
	predicate => 'has_field_name',
);

has field_desc => (
	is        => 'rw',
	isa       => 'Str',
	predicate => 'has_field_desc',
);

has field_type => (
	is        => 'rw',
	isa       => 'Str',
	predicate => 'has_field_type',
);

has field_attributes => (
	is		=> 'rw',
	isa		=> 'HashRef',
	default	=> sub {{}},
);

has field_template => (
	is        => 'rw',
	isa       => 'Str',
	predicate => 'has_field_template',
);

no CubeStats::Role;

package Moose::Meta::Attribute::Custom::Trait::Formfield;
sub register_implementation {'CubeStats::Meta::Attribute::Trait::Formfield'}

1;
