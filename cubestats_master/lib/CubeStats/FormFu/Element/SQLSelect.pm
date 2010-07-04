package CubeStats::FormFu::Element::SQLSelect;

use CubeStats;

extends 'HTML::FormFu::Element::Select';

with qw(
	CubeStats::Role::Database
);

has element_sqlquery => (
	isa => 'Str',
	is => 'rw',
	lazy => 1,
	builder => 'default_element_sqlquery',
);

sub default_element_sqlquery { '' }

has element_sqllabel => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	lazy => 1,
	builder => 'default_element_sqllabel',
);

sub formfu_element_sqllabel { 'Name' }

has element_sqlvalue => (
	isa => 'Str',
	is => 'rw',
	required => 1,
	lazy => 1,
	builder => 'default_element_sqlvalue',
);

sub default_element_sqlvalue { 'ID' }

has element_sqlwhere => (
	isa => 'Str',
	is => 'rw',
	lazy => 1,
	builder => 'default_element_sqlwhere',
);

sub default_element_sqlwhere { '' }

sub new {
	my $self = shift->SUPER::new(@_);
	if (!$self->element_sqlquery && $self->can('element_sqltable')) {
		my $sqlquery = "
			SELECT ".$self->element_sqllabel." AS `Label`, ".$self->element_sqlvalue." AS `Value` FROM ".$self->element_sqltable;
		$sqlquery .= " WHERE ".$self->element_sqlwhere." " if $self->element_sqlwhere;
		$self->element_sqlquery($sqlquery);
	}
	return if !$self->element_sqlquery;
	my @results = $self->db->select($self->element_sqlquery);
	my @options;
	for my $result (@results) {
		my %option;
		$option{label} = $result->{Label};
		$option{value} = $result->{Value};
		push @options, \%option;
	}
	$self->options(\@options);
	return $self;
}

__PACKAGE__->meta->make_immutable;

1;
