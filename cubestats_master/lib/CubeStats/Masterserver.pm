package CubeStats::Masterserver;

use Moose;
use CubeStats::DB;
use Data::Dumper;
use CGI;

sub import {

	my $cgi = new CGI;
	print $cgi->header('text/plain');

	my $port = $cgi->param('port');
	my $item = $cgi->param('item');

	if ($port) {

		$port = $port+0;
		my $host = $ENV{'REMOTE_ADDR'};
		my $masterserver_url = $ENV{'SERVER_NAME'}.'/';

		// that needs to be replaced to make it in masterserver_URL
		// btw: URL _without_ the params and without the retrieve.do

		// so like if you have http://cubestats.net/retrieve.do the URL would be:
		// cubestats.net/ the retrieve.do is part of AC engine thats the URL you can give via -m	

		my $db = new CubeStats::DB;

		my @servers = CubeStats::DB->select("
			SELECT * FROM MasterserverCache WHERE Server = ? AND Port = ? AND Host = ?
		",$masterserver,$port,$host);

		if (@servers) {
			my $server = shift @servers;
			CubeStats::DB->execute("UPDATE MasterserverCache SET Modified = NOW(), From = '' WHERE ID = ?",$server->{ID});
		} else {
			CubeStats::DB->insert("MasterserverCache",{
				Port => $port,
				Host => $host,
				Server => $masterserver,
			});
		}

		print "Registration successful. Due to caching it might take a few minutes to see the your server in the serverlist\n\n";
		print "you are using the alternative masterserver '".$masterserver."' - sponsored by http://cubestats.net/\n\n";

	} else {

		my @servers = CubeStats::DB->select("
			SELECT * FROM MasterserverCache
				WHERE Modified > DATE_SUB(NOW(),INTERVAL 1 DAY)
				ORDER BY Modified DESC
		");

		for my $server (@servers) {
			if ($item) {
				print "addserver ".$server->{IP}." ".$server->{Port}.";\n";
			} else {
				print $server->{IP}." ".$server->{Port}." ".$server->{Modified}." ".$server->{Masterserver_URL_ID}."\n";
			}
		}

	}

}

1;
