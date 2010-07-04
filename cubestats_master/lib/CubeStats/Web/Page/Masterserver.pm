package CubeStats::Web::Page::Masterserver;

use CubeStats;
extends 'CubeStats::Web::Page';

with qw(
    CubeStats::Role::Database
);

sub exec {
	my $self = shift;

	$self->assign('content_template','masterserver.tpl');

}

__PACKAGE__->meta->make_immutable;

1;
