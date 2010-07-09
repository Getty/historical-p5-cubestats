#!/usr/bin/perl

use lib "/home/acube/svn.cubestats.net/trunk/assaultcube_perl/lib";
use lib "/home/acube/svn.cubestats.net/trunk/cubestats_common/lib";
use lib "/home/acube/svn.cubestats.net/trunk/cubestats_master/lib";
use lib "/home/acube/svn.cubestats.net/trunk/cubestats_server/lib";

use CubeStats::Host::GenerateConfig;
print CubeStats::Host::GenerateConfig->new_with_options->config;
