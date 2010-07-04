package CubeStats::AssaultCubeMasterserver::Cron;

use CubeStats;
use Games::AssaultCube::ServerQuery;
use Net::Netmask qw( quad2int int2quad );
use Data::Dumper;

with qw(
    CubeStats::Role::Database
	MooseX::Getopt
);

has ac_masterserver_command => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has cleanup => (
	isa => 'Bool',
	is => 'rw',
	default => sub { 0 },
);

has fetch => (
	isa => 'Bool',
	is => 'rw',
	default => sub { 1 },
);

my $masterserver_id = 1;

sub host2ip {
	my $host = shift;
	my $packed_addr = gethostbyname( $host );
	return unless $packed_addr;
	return inet_ntoa( $packed_addr );
}

sub BUILD {
	my $self = shift;
	if ($self->fetch) {
		my $command = $self->ac_masterserver_command;
		my $result = `$command`;
		open(ACMASTER, "<", \$result);
		my @servers;
		while(<ACMASTER>) {
			if ($_ =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) (\d+)/) {
				my $port = $2;
				my $ipint = quad2int($1);
				my @servers = $self->db->select("
					SELECT * FROM MasterserverCache WHERE Masterserver_URL_ID = ? AND Port = ? AND IP = ?
				",$masterserver_id,$port,$ipint);
				if (@servers) {
					my $server = shift @servers;
					$self->db->execute("UPDATE MasterserverCache SET Modified = NOW() WHERE ID = ?",$server->{ID});
				} else {
					$self->db->insert("MasterserverCache",{
						Port => $port,
						IP => $ipint,
						Masterserver_URL_ID => $masterserver_id,
					});
				}
			}
		}
	}
	if ($self->cleanup) {
		my @servers = $self->db->select("
			SELECT * FROM MasterserverCache WHERE Masterserver_URL_ID = ?
		",$masterserver_id);
		for my $server (@servers) {
			my $serverquery = new Games::AssaultCube::ServerQuery({
				server => $server->{IP},
				port => $server->{Port},
				timeout => 15,
			});
			my $result = {};
			if ($server->{Port}) {
				eval {
					$result = $serverquery->run;
				};
				if (!keys %{$result}) {
					eval {
						$result = $serverquery->run;
					};
				}
			}
			if (!keys %{$result}) {
				$self->db->execute("DELETE FROM MasterserverCache WHERE ID = ?",$server->{ID});
			} else {
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;

1;
