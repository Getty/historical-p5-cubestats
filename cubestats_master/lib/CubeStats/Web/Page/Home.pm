package CubeStats::Web::Page::Home;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'home.tpl' }

with qw(
    CubeStats::Role::Database
);

sub exec {
}

__PACKAGE__->meta->make_immutable;

1;
