package CubeStats::MCP;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

our $VERSION = '0.05';

with qw(
	CubeStats::Role::Database

	MooseX::Getopt
	MooseX::LogDispatch::Levels
);

# load our "plugins"
use Module::Pluggable require => 1, search_path => [ __PACKAGE__ ];

# other stuff
use Games::AssaultCube::Utils qw( get_gamemode_fullname );
use Sys::Load qw( getload );
use Net::Netmask qw( int2quad );

# for api_console connections
has api_console_port => ( isa => 'Int', is => 'rw',
	default => 25_000 );
has api_console => ( isa => 'Maybe[Int]', is => 'rw',
	default => undef );

# our CSN servers
has servers => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

# for the masterserver servers
has serverquery => ( isa => 'Maybe[POE::Component::AssaultCube::ServerQuery]', is => 'rw' );
has masterserver_servers => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

has do_serverquery => ( isa => 'Bool', is => 'ro',
	default => sub { 0 } );

# data
has map_id_mapping => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );
has gamemode_id_mapping => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

has log_dispatch_conf => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	required => 1,
	default => sub {
		my $self = shift;
		return {
			class     => 'Log::Dispatch::Screen',
			min_level => 'debug',
			stderr    => 1,
			format    => '[%d %P:%L - %p] %m%n',
		};
	},
);

has loaded_plugins => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

sub send_csn_server {
	my $self = shift;

	return $self->loaded_plugins->{ 'CubeStats::MCP::CSNServerConnections' }->put_server( @_ );
}

sub STARTALL {
	my $self = shift;

	$self->info( "in STARTALL" );

	# loop through our plugins
	if ($self->do_serverquery) {
		$self->loaded_plugins->{CubeStats::MCP::ServerQuery} = CubeStats::MCP::ServerQuery->new( $self );
	} else {
		foreach my $p ( __PACKAGE__->plugins() ) {	## no critic ( RequireExplicitInclusion )
			next if ($p eq 'CubeStats::MCP::ServerQuery');
			# create the object, and store it
			$self->loaded_plugins->{ $p } = $p->new( $self );
			$self->info( "loaded plugin $p" );
		}
	}

	# start the load watcher
	$poe_kernel->yield( 'check_load' );

	$poe_kernel->sig( 'INT', 'got_int' );
	$poe_kernel->sig( 'HUP', 'got_int' );
	$poe_kernel->sig( 'QUIT', 'got_int' );

	return;
}

event check_load => sub {
	my( $self ) = @_;

	# get the load!
	my @load = getload();

	# TODO make this configurable!
	if ( defined $load[0] and $load[0] >= 5 ) {
		# high load, shutdown MCP!
		$self->warning( "high load detected: $load[0], shutting down MCP!" );
		$self->shutdown;
	} else {
		$self->debug( "system load: " . join( ' ', @load ) );
	}

	# check the load every 5m
	$poe_kernel->delay( 'check_load' => 5 * 60 );

	return;
};

event analyze_serverqueries => sub {
	my( $self, $id, $data ) = @_;

	foreach my $ping ( @$data ) {
		# add the generic stuff
		$ping->{Server_ID} = $id if ! exists $ping->{Server_ID};
		$ping->{IP} = $self->servers->{ $id }->{IP} if ! exists $ping->{IP};

		# skip this if map is not set ( empty server )
		my( $mapid, $gmid );
		if ( length( $ping->{Map} ) == 0 ) {
			$mapid = $gmid = 0;
		} else {
			# is this map new?
			if ( exists $self->map_id_mapping->{ $ping->{Map} } ) {
				$mapid = $self->map_id_mapping->{ $ping->{Map} };
			} else {
				my $mapid_result = $self->db->selectref_cached("
					SELECT ID FROM Map WHERE Map = ?
				", $ping->{Map} );

				if ( defined $mapid_result->[0] ) {
					# use value already in DB
					$mapid = $mapid_result->[0]->{ID};
				} else {
					# create new mapid
					$mapid = $self->db->insert( 'Map', {
						Map	=> $ping->{Map},
					} );
				}
				$self->map_id_mapping->{ $ping->{Map} } = $mapid;
			}

			# fix up gamemode to proper gamemode_ID
			if ( exists $self->gamemode_id_mapping->{ $ping->{Gamemode} } ) {
				$gmid = $self->gamemode_id_mapping->{ $ping->{Gamemode} };
			} else {
				my $gamemode = get_gamemode_fullname( $ping->{Gamemode} );
				$gamemode = 'ctf' if $gamemode eq 'capture the flag';

				my $gmid_result = $self->db->selectref_cached("
					SELECT ID FROM Gamemode WHERE Gamemode = ?
				", $gamemode );

				if ( defined $gmid_result->[0] ) {
					# use value already in DB
					$gmid = $gmid_result->[0]->{ID};
				} else {
					# create new gmid?
#					$gmid = $self->db->insert( 'Gamemode', {
#						Gamemode	=> get_gamemode_fullname( $ping->{Gamemode} ),
#					} );
					$self->info( "unknown gamemode($gamemode) mode($ping->{Gamemode})" );
					$gmid = 0;
				}
				$self->gamemode_id_mapping->{ $ping->{Gamemode} } = $gmid;
			}
		}

		$ping->{Gamemode_ID} = $gmid;
		delete $ping->{Gamemode};
		$ping->{Map_ID} = $mapid;
		delete $ping->{Map};

		# insert this data into the DB, storing it
		$self->db->insert( 'ServerQuery', $ping );
	}

#	$self->info( "analyzed+stored " . scalar @$data . " serverquery results from ID($id)" );

	return;
};

sub registration_check {
	my( $self, $server, $player_id, $nick, $ip ) = @_;

	# TODO for now, we use a static list... yikes!
	# in the future we will use the Users DB and do some tricks to get the User ID from player nick
	my %mapping = (
		# Nick		=> User_ID in DB
		'BS-Getler'	=> 1,
		'BS-Apocalypse'	=> 33764,
	);

	if ( exists $mapping{ $nick } ) {
		# okay, lookup the IP data from the DB!
		my $ips = $self->db->selectref_cached("
			SELECT IP
			FROM User_IP
			WHERE User_IP.User_ID = ?",	# TODO add Modified=24h
		$mapping{ $nick } );

		if ( scalar @$ips ) {
			# convert each IP to a proper quad format
			my $found = 0;
			foreach my $i ( @$ips ) {
				if ( defined $i->{IP} and int2quad( $i->{IP} ) eq $ip ) {
					$found++;
					last;
				}
			}
			if ( ! $found ) {
				# this player is using an unknown IP!
				$self->info( "kicking player <$nick [$player_id]> on server ID($server) for unknown IP($ip)" );
				$self->send_csn_server( $server, "KICKID $player_id" );
			}
		} else {
			# this nick is not "active"
			$self->info( "kicking player <$nick [$player_id]> on server ID($server) for unregistered IP($ip)" );
			$self->send_csn_server( $server, "KICKID $player_id" );
		}
	}

	return;
}

event got_int => sub {
	my $self = shift;

	$self->debug('got sigINT');
	$poe_kernel->sig_handled;
	$poe_kernel->yield( 'SHUTDOWN' );
	return;
};

event _stop => sub {
	return;
};

event _child => sub {
	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event SHUTDOWN => sub {
	my $self = shift;

	$self->info( "shutting down..." );

	# kill our plugins
	foreach my $plugin ( values %{ $self->loaded_plugins } ) {
		$plugin->shutdown;
	}
	%{ $self->loaded_plugins } = ();

	# sanely shutdown
	$poe_kernel->alarm_remove_all;

	return;
};

sub STOPALL {
	my $self = shift;

	$self->info( "in STOPALL" );

	return;
}

sub import {
    $_[0]->new_with_options unless blessed $_[0];
    POE::Kernel->run;
}

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME
