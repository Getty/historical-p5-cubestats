# Declare our package
package CubeStats::Server::Plugins::ServerQuery;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use Games::AssaultCube::ServerQuery;

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has 'failures' => (
	isa		=> 'Int',
	is		=> 'rw',
	default		=> 0,
);

has cache => ( isa => 'ArrayRef[HashRef]', is => 'ro',
	default => sub { [] } );

sub BUILDARGS {
	my $class = shift;

	# Normally, we would be created by CubeStats::Server and contain 1 arg
	if ( @_ == 1 && ref $_[0] ) {
		if ( ref( $_[0] ) eq 'CubeStats::Server' ) {
			return {
				server	=> $_[0],
			};
		} else {
			die "unknown arguments";
		}
	} else {
		return $class->SUPER::BUILDARGS(@_);
	}
}

sub STARTALL {
	my $self = shift;

	$self->server->info( "in STARTALL" );

	#$poe_kernel->delay( 'ping_ac_server' => 60 );
}

event '_child' => sub {
	return;
};

event '_parent' => sub {
	return;
};

sub STOPALL {
	my $self = shift;

	$self->server->info( "in STOPALL" );

	return;
}

event 'ping_ac_server' => sub {
	my $self = shift;

	# okay, ping our localhost server!
	# TODO we could have used PoCo::Generic but since this is localhost it should be fast...
	my $query = Games::AssaultCube::ServerQuery->new({
		server		=> 'localhost',
		port		=> $self->server->loaded_plugins->{ 'CubeStats::Server::Plugins::AssaultCube' }->server_port,
		timeout		=> 2,
		get_players	=> 1,
	});
	my $response;
	eval {
		$response = $query->run();
	};
	if ( $@ or ! defined $response ) {
		$self->server->info( "unable to ServerQuery local ac_server" );
		$self->failures( $self->failures + 1 );

		# TODO make this configurable!
		if ( $self->failures == 3 ) {
			$self->server->ac_server->restart_ac;
		}
	} else {
		# save the data for MCP
		# MCP itself generates Server_ID, IP
		my $data = {
			Modified	=> time(),
			Port		=> $self->server->loaded_plugins->{ 'CubeStats::Server::Plugins::AssaultCube' }->server_port,
			Pingtime	=> $response->pingtime,
			Protocol	=> $response->protocol,
			Gamemode	=> $response->gamemode,
			Player_Count	=> $response->players,
			Minutes_left	=> $response->minutes_left,
			Map		=> $response->map,
			ServerDesc	=> $response->desc_nocolor,
			Player_Max	=> $response->max_players,
			Player_List	=> join( ' ', @{ $response->player_list } ),
		};
		push( @{ $self->cache }, $data );
		#$self->server->info( "successfully ServerQuery ac_server" );
	}

	# redo it every 60s
	$poe_kernel->delay( 'ping_ac_server' => 60 );

	return;
};

sub reset_failures {
	my $self = shift;

	$self->failures( 0 );

	# override the previous delay
	$poe_kernel->delay( 'ping_ac_server' => 60 );

	return;
}

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->server->info( "shutting down..." );

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME
