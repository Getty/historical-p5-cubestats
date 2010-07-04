# Declare our package
package CubeStats::MCP::Masterserver;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::Generic );
use Games::AssaultCube::MasterserverQuery;
#use Data::Dumper;

# TODO LIST
#
# - create POE::Component::AssaultCube::MasterserverQuery so we skip this PoCo::Generic crap :(

has 'mcp' => (
	isa		=> 'CubeStats::MCP',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has ms => ( isa => 'Maybe[POE::Component::Generic]', is => 'rw' );
has data => ( isa => 'Maybe[POE::Component::Generic::Object]', is => 'rw' );

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

	$self->ms( POE::Component::Generic->spawn(
		package		=> 'Games::AssaultCube::MasterserverQuery',
		alt_fork	=> 1,
		#verbose		=> 1,
		#debug		=> 1,
		factories	=> [ 'run' ],
	) );

	# taken from PoCo::Generic - best to give child some time
	$poe_kernel->delay( 'ping' => 1 );

	return;
};

event ping => sub {
	my $self = shift;

	$self->ms->run( { event => 'got_data', wantarray => 0 } );

	return;
};

event got_data => sub {
	my( $self, $resp, $data ) = @_;

	if ( $resp->{error} ) {
		$self->info( "error in Masterserver: $resp->{error}" );
	} else {
		# now we have a proxy object for the G::AC::M::Response object
		$self->data( $data );
		$data->servers( { event => 'got_list', wantarray => 0 } );
	}

	# ping every 15m
	$poe_kernel->delay( 'ping' => 15 * 60 );

	return;
};

event got_list => sub {
	my( $self, $resp, $data ) = @_;

	if ( $resp->{error} ) {
		$self->mcp->info( "error in Masterserver: $resp->{error}" );
	} else {
		#use Data::Dumper;
		#$self->mcp->info( Dumper( $data ) );

		# get rid of CSN servers
		# TODO this is inefficient... im lazy for now :(
		foreach my $csn ( keys %{ $self->mcp->servers } ) {
			$data = [ grep { ! ( $self->mcp->servers->{ $csn }->{IP} eq $_->{ip} and
					$self->mcp->servers->{ $csn }->{Port} eq $_->{port} ) } @$data ];
		}
		$self->mcp->info( "got " . scalar @$data . " servers from Masterserver (excluding CSN)" );

		# check to see if this ip/port combo is "known" to us or not
		foreach my $server ( @$data ) {
			$server->{ID} = $server->{ip} . ':' . $server->{port};

			if ( ! exists $self->mcp->masterserver_servers->{ $server->{ip} . ':' . $server->{port} } ) {
				# okay, add it after some delay to "spread the load"
				$poe_kernel->delay_set( 'addserver' => 5 + int( rand( 30 ) ), $server );
			}
		}

		# Was any servers removed?
		foreach my $server ( keys %{ $self->mcp->masterserver_servers } ) {
			my( $ip, $port ) = split( ':', $server );
			if ( ! grep { $_->{ip} eq $ip and $_->{port} eq $port } @$data ) {
				# remove this server!
				#$self->mcp->info( "stopping ServerQuery pinger on server($server)" );
				my $s = delete $self->mcp->masterserver_servers->{ $server };
				$self->mcp->serverquery->delserver( $s->{ip}, $s->{port} );
			}
		}
	}

	# we're done with the data
	$self->data( undef );

	return;
};

event addserver => sub {
	my( $self, $server ) = @_;

	# new server!
	$self->mcp->masterserver_servers->{ $server->{ID} } = $server;

#	$self->mcp->info( "starting ServerQuery pinger on server( $server->{ID})" );
	$self->mcp->serverquery->addserver( {
		server		=> $server->{ip},
		port		=> $server->{port},
		get_players	=> 1,
		frequency	=> ( 5 * 60 ) + int( rand( 30 ) ),
	} );

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

	# kill the masterserver query subprocess
	$self->data( undef );
	if ( defined $self->ms ) {
		$poe_kernel->post( $self->ms->session_id, 'shutdown' );
		$self->ms( undef );
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