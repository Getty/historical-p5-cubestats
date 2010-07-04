##
##    THIS CLASS GETS DEPRECATED ON FULL START OF THE DAEMONCONTROLLER
##    DONT MODIFY ANY CODE HERE OR MODIFY IT ALSO IN
##		CubeStats::Host::GenerateConfig [see cubestats_master]
##
package CubeStats::Server::GenerateStarter;

use CubeStats;
use CubeStats::DB;

with 'MooseX::Getopt';

has no => (
	isa => 'Int',
	is => 'ro',
	required => 1,
);

has db => (
    isa => 'CubeStats::DB',
    is => 'rw',
    default => sub { new CubeStats::DB },
);

sub BUILD {
	my $self = shift;
	my @result = $self->db->select('SELECT * FROM Server WHERE No = ?',$self->no);
	die('cant start CubeStats Server #'.$self->no) if (!@result);
	my $server = pop @result;
	@result = $self->db->select('SELECT * FROM Clan WHERE ID = ?',$server->{Clan_ID});
	die('cant find Clan with ID #'.$server->{Clan_ID}) if (!@result);
	my $clan = pop @result;
	my $string = "#!/bin/sh\n";
	my $serverroot = $ENV{CUBESTATS_ROOT};
	if ($server->{Host_ID}) {
		@result = $self->db->select('SELECT * FROM Host WHERE ID = ?',$server->{Host_ID});
		die('cant find Host with ID #'.$server->{Host_ID}) if (!@result);
		my $host = pop @result;
		$string .= "#\n# generated for ".$host->{SSH_User}."@".$host->{Hostname}."\n#\n";
		$serverroot = $host->{SSH_Serverroot};
	}
	$string .= "\n";
	$string .= "scripts/start_cubestats_server.pl \\\n";
	$string .= " --no ".$self->no." \\\n";
	$string .= " --name '".$server->{Name}."' \\\n";
	$string .= " --clantag '".$clan->{Name_Server}."' \\\n";
	if ( $server->{Ranked} ) {
		$string .= " --ranked\\\n";
	} else {
		$string .= " --noranked\\\n";
	}
	if ( $server->{Official} ) {
		$string .= " --official\\\n";
	} else {
		$string .= " --noofficial\\\n";
	}
	if ( $server->{IRC} ) {
		$string .= " --irc\\\n";
	} else {
		$string .= " --noirc\\\n";
	}
	$string .= " --voteyourmaprot\\\n" if $server->{VoteYourMaprot};
	$string .= " --api_console 1\\\n";
	$string .= ' --serverroot "${HOME}/cubestats/assaultcube" '."\\\n";
	$string .= " --serverbin '../bin/ac_server_cubestats' \\\n";
	$string .= " --limit ".$server->{Limit}." \\\n";
	$string .= " --maprot '".$server->{Maprot}."' \\\n";
	$string .= " --password 'fuckitoff' \\\n";
	$string .= " --version 'bs0.7' \n\n";

	print $string;

}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
