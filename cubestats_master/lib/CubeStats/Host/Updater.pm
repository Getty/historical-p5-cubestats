package CubeStats::Host::Updater;

use CubeStats;
use CubeStats::DB;
use Net::SSH2;
use File::Util;
use File::Find::Rule;

with qw(
	MooseX::Getopt
	CubeStats::Role::Database
);

has _dirs => (
	isa => 'ArrayRef[Str]',
	is => 'rw',
	default => sub { [ qw(
		assaultcube/config/
		assaultcube/packages/maps/
	) ] }
);

sub dirs {
	my $self = shift;
	my @dirs;
	for my $dir (@{$self->_dirs}) {
		push @dirs, $ENV{'CUBESTATS_ROOT'}.'/'.$dir;
	}
	return \@dirs;
}

has statefile => (
	isa => 'Str',
	is => 'rw',
	default => sub {
		$ENV{'CUBESTATS_ROOT'}."/.host_updater_statefile";
	},
);

has private_key => (
	isa => 'Str',
	is => 'rw',
	default => sub { '/home/acube/.ssh/id_rsa' },
);

has public_key => (
	isa => 'Str',
	is => 'rw',
	default => sub { '/home/acube/.ssh/id_rsa.pub' },
);

sub BUILD {
	my $self = shift;
	my $mtime = ( stat($self->statefile) )[9];
	$mtime = 0 if !$mtime;
	File::Util->touch($self->statefile);
	print $mtime."\n";
	my @files = File::Find::Rule->file()->mtime('>'.$mtime)->in(@{$self->dirs});
	print Dumper \@files;
	return;
	$self->update_all_hosts;
}

sub update_all_hosts {
	my $self = shift;
	my @files = @{+shift};
	my @hosts = $self->db->select('
		SELECT * FROM Host WHERE Prepared = 1
	');
	die('cant find any host') if (!@hosts);
	for my $host (@hosts) {
		$self->update_host($host,\@files);
	}
}

sub update_host {
	my $self = shift;
	my $host = shift;
	my @files = @{+shift};
	return if !@files;
	my $ssh = new Net::SSH2;
	warn "updating ".$host->{Hostname}." ".$host->{SSH_Port};
	$ssh->connect($host->{Hostname},$host->{SSH_Port});
	$ssh->auth_publickey($host->{SSH_User},$self->public_key,$self->private_key);
	for my $file (@files) {
		warn "putting on ".$file;
		$ssh->scp_put($ENV{'CUBESTATS_ROOT'}.'/'.$file,'cubestats/'.$file);
	}
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
