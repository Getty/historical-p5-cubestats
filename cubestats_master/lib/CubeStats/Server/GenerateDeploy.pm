package CubeStats::Server::GenerateDeploy;

use CubeStats;
use CubeStats::DB;

with 'MooseX::Getopt';

has db => (
    isa => 'CubeStats::DB',
    is => 'rw',
    default => sub { new CubeStats::DB },
);

has full => (
	isa => 'Bool',
	is => 'rw',
	default => sub { 0 },
);

sub BUILD {
	my $self = shift;
	my @result = $self->db->select('SELECT * FROM Host WHERE Prepared = 1');
	die('cant find any prepared host') if (!@result);
	print "#!/bin/sh\n";
	for my $host (@result) {
		my $sshdata = $host->{SSH_User}." ".$host->{Hostname}." ".$host->{SSH_Port};
		print "scripts/deploy/server.sh ".$sshdata."\n" if $self->full;
		print "scripts/deploy/serverconfig.sh ".$sshdata."\n";
		print "scripts/deploy/clear_serverstarter.sh ".$sshdata."\n";
		my @servers = $self->db->select('SELECT * FROM Server WHERE Host_ID = ?',$host->{ID});
		for my $server (@servers) {
			print "scripts/deploy/serverstarter.sh ".$sshdata." ".$server->{No}."\n";
		}
	}
	my @servers = $self->db->select('SELECT * FROM Server WHERE Host_ID = 0');
	print "rm -rf server_starter/\n";
	print "mkdir server_starter/\n";
	for my $server (@servers) {
		print "scripts/generate/starter.pl --no ".$server->{No}." >server_starter/csn.".$server->{No}.".sh\n";
	}
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
