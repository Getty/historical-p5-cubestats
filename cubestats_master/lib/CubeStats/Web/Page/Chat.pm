package CubeStats::Web::Page::Chat;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'chat.tpl' }

sub exec {
	my $self = shift;
}

__PACKAGE__->meta->make_immutable;

1;
