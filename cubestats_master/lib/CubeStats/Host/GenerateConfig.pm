package CubeStats::Host::GenerateConfig;

use CubeStats;
use XML::Simple;

with qw(
	MooseX::Getopt
	CubeStats::Role::Database
);

has no => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has config => (
	isa => 'Str',
	is => 'rw',
);

sub generate_serverattributes {
	my $self = shift;
	my %server = %{+shift};
	my %attributes;
	$attributes{no} = $server{No};
	$attributes{name} = $server{Name};
	$attributes{clantag} = $server{Clantag};
	$attributes{ranked} = ( $server{Ranked} ? 1 : 0 );
	$attributes{official} = ( $server{Official} ? 1 : 0 );
	$attributes{irc} = ( $server{IRC} ? 1 : 0 );
	$attributes{voteyourmaprot} = ( $server{VoteYourMaprot} ? 1 : 0 );
	$attributes{serverroot} = '~/cubestats/assaultcube';
	$attributes{serverbin} = '../bin/ac_server_cubestats';
	$attributes{limit} = $server{Limit};
	$attributes{maprot} = $server{Maprot};
	return \%attributes;
}

sub BUILD {
	my $self = shift;
	my @servers = $self->db->select('
		SELECT
			Server.No AS No,
			Clan.Name_Server AS Clantag,
			Server.Name AS Name,
			Server.IRC AS IRC,
			Server.`Limit` AS `Limit`,
			Server.Maprot AS Maprot,
			Server.Serverpwd AS Serverpwd,
			Server.Serverblacklist AS Serverblacklist,
			Server.Official AS Official,
			Server.VoteYourMaprot AS VoteYourMaprot
			FROM Server
			INNER JOIN Host ON Host.ID = Server.Host_ID
			INNER JOIN Clan ON Clan.ID = Server.Clan_ID
			WHERE Host_ID = ?
	',$self->no);
	die('cant find any server for host') if (!@servers);
	my %xml;
	for my $server (@servers) {
		my %subxml;
		$subxml{attributes} = $self->generate_serverattributes($server);
		$subxml{package} = 'CubeStats::Server';
		$subxml{name} = $server->{No};
		push @{$xml{daemon}}, \%subxml;
	}
	$self->config(XMLout(\%xml, rootname => 'moosex'));
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
