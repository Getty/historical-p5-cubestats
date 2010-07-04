package CubeStats::Web::Page::Server;

use CubeStats;
extends 'CubeStats::Web::Page';

with qw(
    CubeStats::Role::Database
);

use Games::AssaultCube::ServerQuery;
use Socket;

sub host2ip {
	my $host = shift;
	my $packed_addr = gethostbyname( $host );
	return unless $packed_addr;
	return inet_ntoa( $packed_addr );
}

sub header {
	my $self = shift;
	if ($self->script eq 'CFG') { return {
		"Content-Type" => 'application/octet-stream; name="csn.cfg"',
		"Content-Disposition" => 'attachment; filename="csn.cfg"',
	}; }
}

sub exec {
	my $self = shift;

	if ($self->script eq 'Map') {

	$self->assign('content_template','server/map.tpl');

	my @locations = $self->db->select_cached( 60 * 5, "
		SELECT Host_Location.ID AS ID, Host_Location.LL, Host_Location.Provider,
			COUNT(DISTINCT Server.ID) AS Server_Count,
			COUNT(DISTINCT Host.ID) AS Host_Count,
			GROUP_CONCAT(DISTINCT Clan.Name) AS Clans
			FROM `Host_Location`
			INNER JOIN Host ON Host.Host_Location_ID = Host_Location.ID
			INNER JOIN Server ON Server.Host_ID = Host.ID
			INNER JOIN Clan ON Server.Clan_ID = Clan.ID
			GROUP BY Host_Location.ID
	");

	$self->assign('locations',\@locations);

	} elsif ($self->script eq 'CFG') {

	$self->file('server/cfg.tpl');

	$self->assign('admin',$self->cgi->param('admin'));

    my @servers = $self->db->select_cached( 60 * 5, "
		SELECT Server.No, Host.Hostname, Server.Maprot, Clan.Name AS Clan_Name,
			Server.Name AS Server_Name, Clan.URL AS Clan_URL
		FROM Server
		INNER JOIN Host ON Server.Host_ID = Host.ID
		INNER JOIN Clan ON Server.Clan_ID = Clan.ID
		ORDER BY No
    ");

	for my $server (@servers) {
		$server->{Port} = no2port($server->{No});
	}

	$self->assign('servers',\@servers);

	} else {

	$self->assign('content_template','server.tpl');

	my @servers = $self->db->select_cached( 60 * 5, "
		SELECT Server.No, Host.Hostname, Server.Maprot, Clan.Name AS Clan_Name,
			Server.Name AS Server_Name, Clan.URL AS Clan_URL, Host_Location.Provider
		FROM Server
		INNER JOIN Host ON Server.Host_ID = Host.ID
		INNER JOIN Clan ON Server.Clan_ID = Clan.ID
		INNER JOIN Host_Location ON Host.Host_Location_ID = Host_Location.ID
		ORDER BY No
	");

	my @results;

	for my $server (@servers) {
		my $port = no2port($server->{No});
		my $host = $server->{Hostname};
		my $serverquery = new Games::AssaultCube::ServerQuery({
			server => $host,
			port => $port,
			get_players => 1,
			timeout => 2,
		});
		my $result = {};
		alarm(0);
		eval {
			$result = $serverquery->run;
		};
		$result->{no} = $server->{No};
		$result->{port} = $port;
		$result->{hostname} = $host;
		$result->{ip} = host2ip($host);
		$result->{clan} = $server->{Clan_Name};
		$result->{clan_url} = $server->{Clan_URL};
		$result->{csn_servername} = $server->{Server_Name};
		$result->{provider} = $server->{Provider};
		push @results, $result;
	}

	$self->assign('results',\@results);

	}

}

__PACKAGE__->meta->make_immutable;

1;
