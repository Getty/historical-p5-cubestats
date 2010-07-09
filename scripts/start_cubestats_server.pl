#!/usr/bin/perl

use CubeStats::Server;
my $server = CubeStats::Server->new_with_options;
$server->run;

1;
