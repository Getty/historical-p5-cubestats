package CubeStats::Role::Web::Form::Field;

use CubeStats::Role;

has 'form_field_id' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has 'form_field_param' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has 'form_field_name' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has 'form_field_desc' => (
	isa => 'Str',
	is => 'ro',
);

has 'form_field_template' => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has 'form_field_value' => (
	isa => 'Str',
	is => 'rw',
);

has 'form_field_validate' => (
	isa => 'CodeRef',
	is => 'rw',
	required => 1,
);

1;
