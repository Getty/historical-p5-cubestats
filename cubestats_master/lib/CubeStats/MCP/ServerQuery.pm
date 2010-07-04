# Declare our package
package CubeStats::MCP::ServerQuery;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::AssaultCube::ServerQuery );

has 'mcp' => (
	isa		=> 'CubeStats::MCP',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

sub BUILDARGS {
	my $class = shift;

	# Normally, we would be created by CubeStats::MCP and contain 1 arg
	if ( @_ == 1 && ref $_[0] ) {
		if ( ref( $_[0] ) eq 'CubeStats::MCP' ) {
			return {
				mcp	=> $_[0],
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

	$self->mcp->info( "in STARTALL" );

	# okay, fire up the server!
	$poe_kernel->yield( 'create_server' );
}

event '_child' => sub {
	return;
};

event '_parent' => sub {
	return;
};

sub STOPALL {
	my $self = shift;

	$self->mcp->info( "in STOPALL" );

	return;
}

event 'create_server' => sub {
	my $self = shift;

	# init the serverquery object
	$self->mcp->serverquery( POE::Component::AssaultCube::ServerQuery->new );

	# register with the serverquery session
	$self->mcp->serverquery->register;

	return;
};

event ac_ping => sub {
	my( $self, $server, $response ) = @_;

	if ( defined $response ) {
		# massage it into a format for our DB
		my $ping = {
			Server_ID	=> 0,
			Modified	=> $response->timestamp,
			IP		=> $server->server,
			Port		=> $server->port,
			Pingtime	=> $response->pingtime,
			Protocol	=> $response->protocol,
			Gamemode	=> $response->gamemode,
			Player_Count	=> $response->players,
			Minutes_Left	=> $response->minutes_left,
			Map		=> $response->map,
			ServerDesc	=> $response->desc,
			Player_Max	=> $response->max_players,
			Player_List	=> join( ' ', @{ $response->player_list } ),
		};

		# Send it off to the analyzer
		$poe_kernel->post( $self->mcp->get_session_id, 'analyze_serverqueries', $server->ID, [ $ping ] );

		# do we need to tune the frequency?
		if ( $response->players == 0 ) {
			$server->frequency( 30 * 60 );
		} else {
			# reset back to normal?
			if ( $server->frequency == 30 * 60 ) {
				$server->frequency( ( 5 * 60 ) + int( rand( 30 ) ) );
			}
		}
	} else {
		$self->mcp->info( "unable to ServerQuery server " . $server->ID );

		# tune the frequency
		$server->frequency( 30 * 60 );
	}

	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->mcp->info( "shutting down..." );

	# kill the ServerQuery subprocess
	$self->mcp->serverquery->shutdown;

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME