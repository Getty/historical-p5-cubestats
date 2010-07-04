# Declare our package
package CubeStats::MCP::CSNServerConnections;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Wheel::SocketFactory Wheel::ReadWrite Component::Client::DNS );

use CubeStats;
use Storable qw( thaw );
use MIME::Base64 qw( decode_base64 );
use Regexp::Common qw( net );

has mcp => (
	isa		=> 'CubeStats::MCP',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has dnsc => ( isa => 'Maybe[POE::Component::Client::DNS]', is => 'rw' );

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

sub servers {
	return $_[0]->mcp->servers;
}

sub STARTALL {
	my $self = shift;

	$self->mcp->info( "in STARTALL" );

	# create the poco-dns session
	$self->dnsc( POE::Component::Client::DNS->spawn() );

	# load the server list
	$poe_kernel->yield( "load_servers" );

	return;
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

event load_servers => sub {
	my $self = shift;

	# for testing, we filter all except for testserver
#	my $data = $self->db->selectref("
#		SELECT ID, No FROM Server WHERE Host_ID = 0
#	");
#	foreach my $r ( @$data ) {
#		$r->{Hostname} = 'cubestats.net';
#	}

	# Okay, get the serverlist from the db
	my $data = $self->mcp->db->selectref("
		SELECT Server.ID AS ID, Server.No AS No, Host.Hostname AS Hostname
		FROM Server
		INNER JOIN Host ON Host.ID = Server.Host_ID
	");

	# experimental data for localhost
#	my $data = [
#		{
#			ID		=> 99,
#			No		=> 99,
#			Hostname	=> '10.0.83.163',
#		},
#	];

	#$self->debug( Dumper( $data ) );

	# do we know about this server?
	foreach my $server ( @$data ) {
		if ( ! exists $self->servers->{ $server->{ID} } ) {
			# new server!
			$self->servers->{ $server->{ID} } = $server;
			$server->{Port} = no2port( $server->{No} );

			# Start monitoring it!
			$poe_kernel->yield( 'new_server', $server->{ID} );
		}
	}

	# Was any servers removed?
	foreach my $server ( keys %{ $self->servers } ) {
		if ( ! grep { $_->{ID} eq $server } @$data ) {
			$self->delete_server( $server );
		}
	}

	# recheck every 5 minutes
	$poe_kernel->delay( 'load_servers' => 60 * 5 );

	return;
};

sub delete_server {
	my( $self, $id, $nodel ) = @_;

	return if ! defined $id;
	return if ! exists $self->servers->{ $id };

	my $s;
	if ( ! $nodel ) {
		$s = delete $self->servers->{ $id };
	} else {
		$s = $self->servers->{ $id };
	}

#	$self->mcp->info( "deleting server CSN($s->{No})" );

	delete $s->{sf} if exists $s->{sf};

	if ( exists $s->{rw} ) {
		$s->{rw}->shutdown_input;
		$s->{rw}->shutdown_output;
		delete $s->{rw};
	}

	if ( exists $s->{sf_timer} ) {
		$poe_kernel->alarm_remove( delete $s->{sf_timer} );
	}

	return;
}

event new_server => sub {
	my( $self, $id ) = @_;

#	$self->mcp->info( "found new server to monitor ID($id)" );

	# do we need to dns resolve this host?
	if ( $self->servers->{ $id }->{Hostname} !~ /^$RE{net}{IPv4}$/ ) {
		# resolve the host into IP
		my $response = $self->dnsc->resolve(
			event	=> 'got_dns',
			host	=> $self->servers->{ $id }->{Hostname},
			context	=> $id,
		);
		if ( defined $response ) {
			$poe_kernel->yield( 'got_dns', $response );
		}
	} else {
		$self->servers->{ $id }->{IP} = $self->servers->{ $id }->{Hostname};
		$poe_kernel->yield( 'connect_server', $id );
	}
	return;
};

event got_dns => sub {
	my( $self, $response ) = @_;
	my $id = $response->{context};

	if ( defined $response->{response} ) {
		my @answers = $response->{response}->answer();
		foreach my $answer (@answers) {
			next if $answer->type ne 'A';
			$self->servers->{ $id }->{IP} = $answer->address;
#			$self->mcp->info( "dns resolved $response->{host} to: " . $answer->address );
			$poe_kernel->yield( 'connect_server', $id );
			return;
		}

		# got here, did not find any dns result!
		$self->mcp->info( "unable to dns resolve(" . $response->{host} . "): no A records found" );
	} else {
		$self->mcp->info( "unable to dns resolve(" . $response->{host} . "): " . $response->{error} );
	}
};

event connect_server => sub {
	my( $self, $id ) = @_;
	my $server = $self->servers->{$id};

#	$self->mcp->debug( "initiating api_console connection to CSN($server->{No}) IP($server->{IP}) Port(" . ( $server->{Port} + 5 ) . ")" );

	# okay, fire up the api_console connection to the server!
	$server->{sf} = POE::Wheel::SocketFactory->new(
		RemoteAddress	=> $server->{IP},
		RemotePort	=> $server->{Port} + 5,

		SuccessEvent	=> 'sf_connected',
		FailureEvent	=> 'sf_failure',
	);

	# setup the timeout
	$poe_kernel->alarm_remove( delete $server->{sf_timer} ) if exists $server->{sf_timer};
	$server->{sf_timer} = $poe_kernel->delay_set( 'sf_timeout' => 60, $id );

	return;
};

event sf_connected => sub {
	my( $self, $fh, $ip, $port, $id ) = @_;
	my $server;
	foreach my $s ( keys %{ $self->servers } ) {
		if ( exists $self->servers->{ $s }->{sf} and $self->servers->{ $s }->{sf}->ID eq $id ) {
			$server = $self->servers->{$s};
			last;
		}
	}
	return if ! defined $server;

#	$self->mcp->info( "api_console connected to CSN($server->{No})" );

	# clear the timer!
	delete $server->{sf} if exists $server->{sf};
	$poe_kernel->alarm_remove( delete $server->{sf_timer} ) if exists $server->{sf_timer};
	$server->{connected} = 1;

	# convert to RW
	$server->{rw} = POE::Wheel::ReadWrite->new(
		Handle		=> $fh,
		Filter		=> POE::Filter::Line->new,
		InputEvent	=> 'rw_input',
		ErrorEvent	=> 'rw_failure',
	);
	$server->{rw_last_put} = [];

	# let them know the MCP is here!
	$server->{rw}->put( 'CSN-MCP' );

	# send off the serverquery!
	$poe_kernel->yield( 'send_serverquery', $server->{ID} );

	return;
};

event sf_failure => sub {
	my( $self, $operation, $errnum, $errstr, $wheel_id ) = @_;
	my $server;
	foreach my $s ( keys %{ $self->servers } ) {
		if ( exists $self->servers->{ $s }->{sf} and $self->servers->{ $s }->{sf}->ID eq $wheel_id ) {
			$server = $self->servers->{$s};
			last;
		}
	}
	return if ! defined $server;

#	$self->mcp->info( "api_console connection to CSN($server->{No}) SF error($operation): $errnum $errstr" );

	# clear the timer!
	$poe_kernel->alarm_remove( delete $server->{sf_timer} ) if exists $server->{sf_timer};
	delete $server->{sf} if exists $server->{sf};
	$server->{connected} = 0;

	# retry after 60s
	$poe_kernel->delay_set( 'connect_server' => 60, $server->{ID} );

	return;
};

event sf_timeout => sub {
	my( $self, $server ) = @_;
	$server = $self->servers->{ $server };

#	$self->mcp->debug( "api_console connection to CSN($server->{No}) timed out" );

	delete $server->{sf} if exists $server->{sf};
	delete $server->{sf_timer} if exists $server->{sf_timer};
	$server->{connected} = 0;

	# retry after 60s
	$poe_kernel->delay_set( 'connect_server' => 60, $server->{ID} );

	return;
};

event rw_input => sub {
	my( $self, $input, $id ) = @_;
	my $server;
	foreach my $s ( keys %{ $self->servers } ) {
		if ( exists $self->servers->{ $s }->{rw} and $self->servers->{ $s }->{rw}->ID eq $id ) {
			$server = $self->servers->{$s};
			last;
		}
	}
	return if ! defined $server;
	return if ! length $input;

	# what data?
	my $cmd = shift @{ $server->{rw_last_put} };
	my $cmd_arg;
	if ( defined $cmd and ref $cmd ) {
		$cmd_arg = $cmd->[1];
		$cmd = $cmd->[0];
	}

#	$self->mcp->debug( "received input from CSN($server->{No}): $input ($cmd)" );

	if ( $input =~ /^CSN-REGISTRATIONCHECK\s+(\d+)\s+([^\s]+)\s+(.+)$/ ) {
		# we let the MCP check this nick ( $player_id, $nick, $ip )
		$self->mcp->registration_check( $server->{ID}, $1, $2, $3 );
	} elsif ( $cmd eq 'CSN-SERVERQUERY' ) {
		# It's the complete serverquery array
		return if length( $input ) < 8;
		my $data = thaw( decode_base64( $input ) );

		# Send it off to the master session for processing
		if ( defined $data and ref $data and ref( $data ) eq 'ARRAY' and scalar @$data ) {
			$poe_kernel->post( $self->mcp->get_session_id, 'analyze_serverqueries', $server->{No}, $data );
		}

		# wait another minute before re-polling
		$poe_kernel->alarm_remove( delete $server->{sf_timer} ) if exists $server->{sf_timer};
		$server->{sf_timer} = $poe_kernel->delay_set( 'send_serverquery' => 60, $server->{ID} );
	} elsif ( $cmd eq 'CSN-PLAYERLIST' ) {
		# its the playerlist data
		return if length( $input ) < 12;
		my $data = thaw( decode_base64( $input ) );

		# now we have the session id to post the data back
		$poe_kernel->post( $cmd_arg, 'csn_playerlist', $server->{No}, $data );
	} else {
		$self->mcp->info( "unknown input from CSN($server->{No}): $input ($cmd)" );
	}

	return;
};

event rw_failure => sub {
	my( $self, $operation, $errnum, $errstr, $id ) = @_;
	my $server;
	foreach my $s ( keys %{ $self->servers } ) {
		if ( exists $self->servers->{ $s }->{rw} and $self->servers->{ $s }->{rw}->ID eq $id ) {
			$server = $self->servers->{$s};
			last;
		}
	}
	return if ! defined $server;

#	$self->mcp->info( "api_console connection to CSN($server->{No}) RW error($operation): $errnum $errstr" );

	delete $server->{rw} if exists $server->{rw};
	delete $server->{sf} if exists $server->{sf};
	$poe_kernel->alarm_remove( delete $server->{sf_timer} ) if exists $server->{sf_timer};
	$server->{connected} = 0;

	# retry after 60s
	$poe_kernel->delay_set( 'connect_server' => 60, $server->{ID} );

	return;
};

event send_serverquery => sub {
	my( $self, $id ) = @_;
	my $server = $self->servers->{$id};

	if ( ! grep { $_ eq 'CSN-SERVERQUERY' } @{ $server->{rw_last_put} } ) {
#		$self->mcp->debug( "sending msg to CSN($server->{No}): CSN-SERVERQUERY" );

		$server->{rw}->put( "CSN-SERVERQUERY" );
		push( @{ $server->{rw_last_put} }, "CSN-SERVERQUERY" );
	}
	return;
};

sub put_server {
	my( $self, $server, $args, $session ) = @_;

	if ( defined $server and exists $self->servers->{ $server } and $self->servers->{ $server }->{connected} ) {
#		$self->mcp->debug( "sending msg to CSN(" . $self->servers->{ $server }->{No} . "): $args" );

		$self->servers->{ $server }->{rw}->put( $args );
		if ( $args =~ /^CSN\-/ ) {
			if ( defined $session ) {
				push( @{ $self->servers->{ $server }->{rw_last_put} }, [ $args, $session ] );
			} else {
				push( @{ $self->servers->{ $server }->{rw_last_put} }, $args );
			}
		}
	}

	return;
}

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->mcp->info( "shutting down..." );

	# kill our api_console connections
	foreach my $id ( keys %{ $self->servers } ) {
		$self->delete_server( $id, 1 );
	}
	%{ $self->servers } = ();

	# kill the poco-dns session
	if ( $self->dnsc ) {
		$self->dnsc->shutdown;
		$self->dnsc( undef );
	}

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME