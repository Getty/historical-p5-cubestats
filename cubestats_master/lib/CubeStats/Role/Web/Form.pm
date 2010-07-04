package CubeStats::Role::Web::Form;
our $VERSION = "0.01";

use CubeStats::Role;
use CubeStats::Meta::Attribute::Trait::Formfield;
use MooseX::AttributeHelpers;
use Moose::Util::TypeConstraints;

with qw(
	CubeStats::Role::Web::Template
);

has '+file' => (
	default => sub { 'form/structure.tpl' },
);

has 'form_id' => (
	isa => 'Str',
	is => 'rw',
	lazy    => 1,
	builder => '_build_form_id',
);

has 'form_name' => (
	isa => 'Str',
	is => 'rw',
);

has 'form_hash_fields' => (
	isa => 'HashRef',
	is => 'rw',
	predicate => 'has_form_hash_fields',
);

has 'init' => (
	isa => 'Bool',
	is => 'rw',
	default => sub { 0 },
);

role_type 'CubeStats::Role::Web::Form::Field';

has 'form_fields' => (
	metaclass => 'Collection::Hash',
	isa => 'HashRef[CubeStats::Role::Web::Form::Field]',
	is => 'rw',
	default => sub {{}},
	provides  => {
		'set'		=> 'set_form_field',
		'get'		=> 'get_form_field',
		'empty'		=> 'has_form_fields',
		'exists'	=> 'has_form_field',
		'count'		=> 'count_form_fields',
		'delete'	=> 'delete_form_field',
		'keys'		=> 'form_field_ids',
	}
);

has 'form_attributes' => (
	metaclass => 'Collection::Hash',
	isa => 'HashRef[Value]',
	is => 'rw',
	default => sub {{}},
	provides  => {
		'set'		=> 'set_form_attribute',
		'get'		=> 'get_form_attribute',
		'empty'		=> 'has_form_attributes',
		'exists'	=> 'has_form_attribute',
		'count'		=> 'count_form_attributes',
		'delete'	=> 'delete_form_attribute',
		'keys'		=> 'form_attribute_keys',
	}
);

has 'form_field_template_prefix' => (
	isa => 'Str',
	is => 'rw',
	default => sub { 'form/field/' },
);

has qw( form_is_prepared form_is_loaded ) => (
	isa => 'Bool',
	is => 'rw',
	default => sub {0},
);

sub _form_to {
	my $self = shift;
	my $hash = $self->_default_form;
	$hash->{'fields'} = {};
	for my $field_id (@{$self->form_field_ids}) {
		my $form_field = $self->get_form_field($field_id);
		$hash->{'fields'}->{$field_id} = $form_field->_form_field_to;
	}
}

sub _form_from {
	my $self = shift;
	my $hash = shift;
	$self->form_id($hash->{'id'});
	$self->form_name($hash->{'name'});
	$self->form_attributes($hash->{'attributes'});
	for my $field_id (keys %{$hash->{'fields'}}) {
		my $type = $hash->{'fields'}->{$field_id}->{'type'};
		delete $hash->{'fields'}->{$field_id}->{'type'};
		my $type_package = _get_form_type_package($type);
		eval "use $type_package"; die $@ if $@;
		$self->set_form_field($field_id, new $type_package($hash->{'fields'}->{$field_id}));
	}
}

sub _form_hash_fields {
	my $self = shift;
	return if $self->has_form_hash_fields;
	my $form_hash_fields = {};
	my %attributes = %{ $self->meta->get_attribute_map };
	for my $name ( keys %attributes ) {
		my $attribute = $attributes{$name};
		if ($attribute->does('CubeStats::Meta::Attribute::Trait::Formfield') && ( $attribute->has_field_name || $attribute->has_field_id ) ) {
			if (!$attribute->has_field_id) {
				my $field_name = $attribute->field_name;
				$field_name =~ tr/[^a-zA-Z0-9]//;
				$attribute->field_id(lc($field_name));
			}
			my $form_field = $form_fields_hash{$attribute->field_id} = $attribute->field_attributes;
			$form_field->{'id'} = $attribute->field_id;
			$form_field->{'name'} = $attribute->field_name if $attribute->has_field_name;
			$form_field->{'param'} = $self->form_name.'_'.$attribute->field_id;
			$form_field->{'desc'} = $attribute->field_desc if $attribute->has_field_desc;
			$form_field->{'type'} = $attribute->has_field_type ? $attribute->field_type : 'text';
			$form_field->{'template'} = $self->form_field_template_prefix.(
				$attribute->has_field_template ? $attribute->field_template : $form_field->{'type'}.'.tpl'
			);
			$form_hash_fields->{$attribute->field_id} = $form_field;
        }
   	}
	$self->form_hash_fields($form_hash_fields);
}

sub _form_save {
	my $self = shift;
	$self->session->param($self->form_id,$self->_form_to);
}

sub _form_load {
	my $self = shift;
	return if $self->form_is_loaded;
	my $form_hash = $self->session->param($self->form_id);
	if ($form_hash) {
		$self->_form_from($form_hash);
	} else {
		$self->_form_from($self->_default_form_hash);
	}
	$self->form_is_loaded(1);
}

sub BUILD {
	my $self = shift;
	$self->_form_load;
	$self->_form_hash_fields;
}

sub _default_form_hash {
	my $self = shift;
	my $hash;
	$hash->{'id'} = $self->form_id;
	$hash->{'name'} = $self->form_name;
	$hash->{'attributes'} = $self->form_attributes;
	return $hash;
}

sub _build_form_id {
	my $self = shift;
	if (!$self->form_name) {
		my $pkg = ref $self;
		$pkg =~ s/::/ /g;
		$self->form_name($pkg);
	}
	my $name = $self->form_name;
	$name =~ s/[^a-zA-Z0-9]/_/g;
	my $id = lc($name);
	return $id;
}

sub _get_form_type_package {
	my $type = shift;
	return 'CubeStats::Web::Form::Field::'.ucfirst($type);
}

sub prepare {
	my $self = shift;
	my $session = $self->session;
	my $form_id = $self->form_id;
	if (!$self->form_is_prepared) {
		for my $field_id (@{$self->form_field_ids}) {
			my $form_field = $self->get_form_field($field_id);
			$hash->{'fields'}->{$field_id} = $form_field->_form_field_to;
		}
		$self->form_is_prepared(1);
	}
}

sub done {
	my $self = shift;
	$self->prepare;
	0;
}

1;
