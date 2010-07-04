# Declare our package
package CubeStats::Bot::MCPConnection;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::Client::TCP Filter::Line Filter::Reference );

has 'bot' => (
	isa		=> 'CubeStats::Bot::Control',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has mcp => ( isa => 'Maybe[Int]', is => 'rw' );
has mcp_connected => ( isa => 'Bool', is => 'rw', default => 0 );

sub STARTALL {
	my $self = shift;

	$self->bot->info( "in STARTALL" );

	# okay, fire up the server!
	$poe_kernel->yield( 'connect_mcp' );
}

event '_child' => sub {
	return;
};

event '_parent' => sub {
	return;
};

sub STOPALL {
	my $self = shift;

	$self->bot->info( "in STOPALL" );

	return;
}

event connect_mcp => sub {
	my $self = shift;

	$self->mcp( POE::Component::Client::TCP->new(
		RemoteAddress	=> '127.0.0.1',
		RemotePort	=> 25_000,
		ConnectTimeout	=> 60,
		Filter		=> 'POE::Filter::Line',

		InlineStates	=> {
			csn_put		=> sub {
				my( $cmd, $data, $baggage ) = @_[ ARG0 .. ARG2 ];
				return unless $_[HEAP]->{connected};
				return if $_[HEAP]->{shutdown};

#				$self->bot->debug( "sending msg to MCP: ($cmd) $data" );
				$_[HEAP]{server}->put( { cmd => $cmd, data => $data, baggage => $baggage } );
				return;
			},
			csn_pinger	=> sub {
				return unless $_[HEAP]->{connected};
				return if $_[HEAP]->{shutdown};

#				$self->bot->debug( "sending msg to MCP: (PING)" );
				$_[HEAP]{server}->put( { cmd => 'PING', data => undef, baggage => undef } );

				# ping every 60s
				$poe_kernel->delay( 'csn_pinger' => 60 );
				return;
			},
		},

		Started		=> sub {
			$self->bot->debug( "starting the connection to MCP ip(127.0.0.1) port(25_000)" );
			return;
		},
		Connected	=> sub {
			return if $_[HEAP]->{shutdown};

#			$self->bot->debug( "connected to MCP" );
			$self->mcp_connected( 1 );

			# ping every 60s
			$poe_kernel->delay( 'csn_pinger' => 60 );
			return;
		},
		ConnectError	=> sub {
			return if $_[HEAP]->{shutdown};

			# retry after 60s
#			$self->bot->debug( "error connecting to MCP" );
			$self->mcp_connected( 0 );
			$poe_kernel->delay( 'reconnect' => 60 );
			return;
		},
		Disconnected	=> sub {
			return if $_[HEAP]->{shutdown};

			# retry after 60s
#			$self->bot->debug( "disconnected from MCP" );
			$self->mcp_connected( 0 );
			$poe_kernel->delay( 'reconnect' => 60 );
			return;
		},
		ServerInput	=> sub {
			# sanity
			return if $_[HEAP]->{shutdown};
			return if ! defined $_[ARG0];

			if ( ! exists $_[HEAP]{CSN_SERIALIZE} ) {
				# what input did we get?
				if ( $_[ARG0] =~ /^MCP/ ) {
					# switch filters to filter::reference
					$_[HEAP]{server}->put( 'serialize_on' );
					$_[HEAP]{server}->set_filter( POE::Filter::Reference->new() );
					$_[HEAP]{CSN_SERIALIZE} = 1;
				} else {
					$self->bot->debug( "unknown data from MCP: $_[ARG0]" );
				}
			} else {
				if ( ref $_[ARG0] and ref( $_[ARG0] ) eq 'HASH' ) {
#					$self->bot->debug( "got data from MCP: ($_[ARG0]->{cmd}) $_[ARG0]->{data}" . ( defined $_[ARG0]->{baggage} ? ' baggage(' . $_[ARG0]->{baggage} . ')' : '' ) );

					# we got the data back
					if ( defined $_[ARG0]->{baggage} and $_[ARG0]->{baggage} =~ /^(\w+)\:(.+)$/ ) {
						# send the data back to them!
						my( $bot, $nick ) = ( $self->bot->get_bot( $1 ), $2 );
#						print Data::Dumper::Dumper( $_[ARG0] );

						if ( $_[ARG0]->{result} ) {
							my @data = @{ $self->transform_data( $bot, $nick, $_[ARG0] ) };
							foreach my $l ( @data ) {
								$bot->privmsg( $nick => $l );
							}
						} else {
							$bot->privmsg( $nick => "(" . $_[ARG0]->{cmd} . ") Error: $_[ARG0]->{data}" );
						}
					} else {
						$self->bot->debug( "unknown baggage from MCP: $_[ARG0]->{baggage}" );
					}
				} else {
					# ignore this invalid data
				}
			}

			return;
		},
		ServerError	=> sub {
			my( $operation, $errnum, $errstr ) = @_[ ARG0 .. ARG2 ];
			return if $_[HEAP]->{shutdown};

#			$self->bot->info( "error from MCP $operation: $errnum $errstr" );
			$self->mcp_connected( 0 );

			# retry after 60s
			$poe_kernel->delay( 'reconnect' => 60 );
			return;
		},
	) );

	return;
};

sub transform_data {
	my( $self, $bot, $nick, $data ) = @_;
	my $isop = $self->bot->get_bot( 'QuakeNet' )->irc->is_channel_operator( $nick );

	# setup the data!
	my $r = [];
	if ( $data->{cmd} eq 'playerlist' ) {
		#$VAR1 = {
		#          '34' => {
		#                    'nick' => 'y(Ita)blindico',
		#                    'welcome' => 1,
		#                    'host' => '79.32.244.109'
		#                  }
		#        };

		if ( scalar keys %{ $data->{data} } ) {
			push( @$r, "Connected Players (" . ( scalar keys %{ $data->{data} } ) . ")" );
			my $datastring;
			my $line = "";
			foreach my $id ( sort keys %{ $data->{data} } ) {
				if ( $isop ) {
					$datastring = " [ $id | " . $data->{data}->{$id}->{nick} . ' | ' . $data->{data}->{$id}->{host} . ' ]';
				} else {
					$datastring = " [ $id | " . $data->{data}->{$id}->{nick} . ' ]';
				}

				# arbitrary number chosen but at least it's less than XChat's max of 432 :)
				if ( length( $line ) + length( $datastring ) > 400 ) {
					push( @$r, $line );
					$line = $datastring;
				} else {
					$line .= $datastring;
				}
			}
			push( @$r, $line ) if length $line;
		} else {
			push( @$r, "Connected Players: NONE" );
		}
	} else {
		# huh, just return the data...
		push( @$r, $data->{data} );
	}

	return $r;
}
sub put_mcp {
	my( $self, $cmd, $data, $baggage ) = @_;

	if ( $self->mcp_connected ) {
		$poe_kernel->post( $self->mcp, 'csn_put', $cmd, $data, $baggage );
	}
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->bot->info( "shutting down..." );

	if ( defined $self->mcp ) {
		$poe_kernel->post( $self->mcp, 'shutdown' );
		$self->mcp( undef );
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