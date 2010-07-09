#!/usr/bin/perl

use CGI::Fast;

use CubeStats::Web::CGI;
use CubeStats::Web::MasterController;

use CubeStats::Web;
use CubeStats::DB;

use Sys::Load qw( getload );

while (my $cgi = new CGI::Fast) {

	my $maxload = 8;
	my $load = (getload())[0];
	if ($load > $maxload) {
		print $cgi->header;
		print "Our systems are overloaded right now, please hit reload (F5) in some minutes again. We are working on these issues.\n";
		print "(Load: ".$load.", Maximum Load is ".$maxload.")";
		next;
	}

	my $cubestats_cgi = new CubeStats::Web::CGI({
		cgi => $cgi,
	});

	$cubestats_cgi->init;

	new CubeStats::Web::MasterController({
		cgi => $cubestats_cgi,
	});

}
