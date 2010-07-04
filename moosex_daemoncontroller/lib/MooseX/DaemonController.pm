package MooseX::DaemonController;
our $VERSION = '0.01';

use Moose;
use XML::Simple;
use Data::Dumper;
use MooseX::DaemonController::Daemon;
use Storable;
use Struct::Compare;

with qw(
	MooseX::Getopt
);

has pidbase => ( isa => 'Str', is => 'ro', required => 1 );

has statefile => ( isa => 'Str', is => 'ro', required => 1 );
has state => ( isa => 'HashRef', is => 'rw',
	reader => 'state',
	writer => 'write_state',
	default => sub {{}} );

has configfile => ( isa => 'Str', is => 'ro' );

has daemons => ( isa => 'ArrayRef', is => 'rw', predicate => 'has_daemons_set' );

has mission => ( isa => 'Str', is => 'ro',
	default => sub { 'checkstate' } );

has foreground => ( isa => 'Bool', is => 'ro',
	default => sub { 0 } );

after 'write_state' => sub {
	my $self = shift;
	$self->write_statefile;
};

sub read_statefile {
	my $self = shift;
	if ( ! -f $self->statefile ) {
		open STATEFILE, '>', $self->statefile and close STATEFILE or die "Failed to create empty: $!\n";
		store($self->state,$self->statefile);
	} else {
		$self->write_state(retrieve($self->statefile));
	}
}

sub write_statefile {
	my $self = shift;
	store($self->state,$self->statefile);
}

sub BUILD {
	my $self = shift;
	$self->read_configfile if $self->configfile;
	$self->read_statefile;
	die "no daemons set, give --configfile or give daemons over constructor" if !$self->has_daemons_set;
}

sub execute_mission {
	my $self = shift;
	if (grep {$_ eq $self->mission} qw( start stop restart )) {
		for my $daemon (@{$self->daemons}) {
			$self->execute_ondaemon($daemon,$self->mission);
		}
	}
	if ($self->can($self->mission)) {
		my $method = $self->mission;
		$self->$method;
	}
}

sub daemon_progname {
	my $self = shift;
	my $daemon = shift;
	die "daemon has no package" if !$daemon->{package};
	my $package = $daemon->{package};
	my $name = $daemon->{name};
	$name = 1 if !$name;
	$package =~ s/::/_/g;
	return $package.'_'.$name;	
}

sub daemon_obj {
	my $self = shift;
	my $daemon = shift;
	my %attributes; %attributes = %{$daemon->{attributes}} if ref $daemon->{attributes} eq 'HASH';
	return MooseX::DaemonController::Daemon->new({
		foreground => $self->foreground,
		package => $daemon->{package},
		attributes => \%attributes,
		progname => $self->daemon_progname($daemon),
		pidbase => $self->pidbase,
		stop_timeout => 15,
	});
}

sub execute_ondaemon {
	my $self = shift;
	my $daemon = shift;
	my $method = shift;
	my $progname = $self->daemon_progname($daemon);
	print "executing: ".$method." on ".$progname."\n";
	my $daemonize = $self->daemon_obj($daemon);
	$daemonize->$method;
	my $state = $self->state;
	if ($method eq 'start' or $method eq 'restart') {
		$state->{$progname} = $daemon;
	} elsif ($method eq 'stop') {
		delete $state->{$progname};
	}
	$self->write_state($state);
}

sub checkstate {
	my $self = shift;
	my %state = %{$self->state};
	for my $daemon (@{$self->daemons}) {
		my $progname = $self->daemon_progname($daemon);
		if ($state{$progname}) {
			my $state_daemon = $state{$progname};
			if (!compare($state_daemon,$daemon)) {
				$self->execute_ondaemon($daemon,'restart');
			}
		}
		if (!$self->daemon_obj($daemon)->pidfile->is_running) {
			$self->execute_ondaemon($daemon,'start');
		}
		$state{$progname}->{checked} = 1;
	}
	for my $key (keys %state) {
		if (!$state{$key}->{checked}) {
			$self->execute_ondaemon($state{$key},'stop');
		}
	}
}

sub read_configfile {
	my $self = shift;
	my $data = XMLin($self->configfile, KeepRoot => 1, ForceArray => 1, KeyAttr => [ 'id' ]);
	my @daemons;
	if ($data->{moosex}) {
		my @moosex_data = @{$data->{moosex}};
		for my $subdata (@moosex_data) {
			if (ref $subdata->{daemon} eq 'ARRAY') {
				for my $daemon (@{$subdata->{daemon}}) {
					if (ref $daemon->{attributes} eq 'ARRAY') {
						$daemon->{attributes} = $daemon->{attributes}->[0];
					}
					push @daemons, $daemon;
				}
			}
		}
	}
	$self->daemons(\@daemons);
}

sub run {
    $_[0]->new_with_options->execute_mission unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
