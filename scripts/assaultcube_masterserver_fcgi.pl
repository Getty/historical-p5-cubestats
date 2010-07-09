#!/usr/bin/perl

use CGI::Fast;

use CubeStats::Web::CGI;
use CubeStats::Web::AssaultCubeMasterserver;

use CubeStats::Web;
use CubeStats::DB;

use Sys::Load qw( getload );

while (my $cgi = new CGI::Fast) {

	my $cubestats_cgi = new CubeStats::Web::CGI({
		cgi => $cgi,
	});
	$cubestats_cgi->init;
	new CubeStats::Web::AssaultCubeMasterserver({
		cgi => $cubestats_cgi,
	});

}
