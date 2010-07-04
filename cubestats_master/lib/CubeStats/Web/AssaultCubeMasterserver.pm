package CubeStats::Web::AssaultCubeMasterserver;
our $VERSION = '0.1';

use CubeStats;

with qw(
        CubeStats::Role::Web
        CubeStats::Role::Database
);

use Socket;
use Net::Netmask qw( quad2int int2quad );
use Games::AssaultCube::ServerQuery;

sub host2ip {
    my $host = shift;
    my $packed_addr = gethostbyname( $host );
    return unless $packed_addr;
    return inet_ntoa( $packed_addr );
}

sub BUILD {
	my $self = shift;

	print $self->cgi->cgi->header('text/plain');

	my $port = $self->cgi->param('port');
	my $item = $self->cgi->param('item');

	my $masterserver_url = $ENV{'SERVER_NAME'}.'/';

	my ($masterserver_row) = $self->db->select("
		SELECT * FROM Masterserver_URL WHERE URL = ?
	",$masterserver_url);

	my $masterserver_id = $masterserver_row->{ID};

	if (!$masterserver_id) {
		$masterserver_id = $self->db->insert("Masterserver_URL",{
			URL => $masterserver_url,
		});
	}

	if ($port) {

		$port = $port+0;
		my $host = $ENV{'REMOTE_ADDR'};
		my $ip = host2ip($host);
		my $ip_int = quad2int($ip);

		my @servers = $self->db->select("
			SELECT * FROM MasterserverCache WHERE Masterserver_URL_ID = ? AND Port = ? AND IP = ?
		",$masterserver_id,$port,$ip_int);

		my $serverquery = new Games::AssaultCube::ServerQuery({
			server => $host,
			port => $port,
        });
        my $result = {};
        eval {
            $result = $serverquery->run;
        };

		if (@servers) {
			my $server = shift @servers;
			if (!$result) {
				$self->db->execute("DELETE FROM MasterserverCache WHERE ID = ?",$server->{ID});
			} else {
				$self->db->execute("UPDATE MasterserverCache SET Modified = NOW() WHERE ID = ?",$server->{ID});
			}
		} elsif ($result) {
			$self->db->insert("MasterserverCache",{
				Port => $port,
				IP => $ip_int,
				Masterserver_URL_ID => $masterserver_id,
			});
		}

		if (keys %{$result}) {
			print "Registration successful. Due to caching it might take a few minutes to see the your server in the serverlist\n\n";
			print "you are using the alternative masterserver '".$masterserver_url."' - sponsored by http://cubestats.net/\n\n";
		} else {
			print "You're registration has __FAILED__. We suggest that you check if you forwarded your server port correctly,\n";
			print "if you are sitting behind a router. Hint: checkout http://portforward.com/ for hints about forwarding ports.\n\n";
			print "you are using the alternative masterserver '".$masterserver_url."' - sponsored by http://cubestats.net/\n\n";
		}

	} else {

		my @servers = $self->db->select("
			SELECT * FROM MasterserverCache
				WHERE Modified > DATE_SUB(NOW(),INTERVAL 2 DAY)
					AND Masterserver_URL_ID = ? AND Port > 0
				ORDER BY Modified DESC
		",$masterserver_id);

		for my $server (@servers) {
			if ($item) {
				print "addserver ".int2quad($server->{IP})." ".$server->{Port}.";\n";
			} else {
				print int2quad($server->{IP})." ".$server->{Port}." ".$server->{Modified}." ".$server->{Masterserver_URL_ID}."\n";
			}
		}

	}

}

1;
