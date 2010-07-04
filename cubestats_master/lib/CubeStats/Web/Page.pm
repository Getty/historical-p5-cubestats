package CubeStats::Web::Page;

use CubeStats;

with qw(
	CubeStats::Role::Web::Template
);

has script => (
    isa => 'Str',
    is => 'rw',
);

has '+file' => (
	default => sub { 'structure.tpl' },
);

has 'reroute' => (
	isa => 'Str',
	is => 'rw',
	default => sub { '' },
);

sub exec {}

before 'view' => sub {
	my $self = shift;
	if ($self->can('content_template')) {
		$self->assign('content_template',$self->content_template);
	}
};

__PACKAGE__->meta->make_immutable;

1;
