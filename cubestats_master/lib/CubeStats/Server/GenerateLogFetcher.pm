package CubeStats::Server::GenerateLogFetcher;

use CubeStats;
use CubeStats::DB;

with 'MooseX::Getopt';

has db => (
    isa => 'CubeStats::DB',
    is => 'rw',
    default => sub { new CubeStats::DB },
);

sub BUILD {
	my $self = shift;
	my @result = $self->db->select('SELECT * FROM Host WHERE Prepared = 1');
	die('cant find any prepared host') if (!@result);
	print "#!/bin/sh\n";
	for my $host (@result) {
		my $sshdata = $host->{SSH_User}." ".$host->{Hostname}." ".$host->{SSH_Port};
		print "scripts/logs/fetch.sh ".$sshdata."\n";
	}
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
