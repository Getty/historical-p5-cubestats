# Declare our package
package CubeStats::MCP::API_Console;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::Server::TCP Filter::Line Filter::Reference );
use Socket qw( INADDR_ANY );

has 'mcp' => (
	isa		=> 'CubeStats::MCP',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has 'server' => (
	isa		=> 'Maybe[Int]',
	is		=> 'rw',
	default		=> undef,
);

has 'clients' => (
	isa		=> 'HashRef',
	is		=> 'ro',
	default		=> sub { {} },
);

has 'baggage_cache' => (
	isa		=> 'HashRef',
	is		=> 'ro',
	default		=> sub { {} },
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

	$self->mcp->info( "starting api_console server port(" . $self->mcp->api_console_port . ")..." );

	if ( defined $self->server ) {
		$poe_kernel->call( $self->server, "shutdown" );
		$self->server( undef );
	}

	$self->server( POE::Component::Server::TCP->new(
		Address		=> INADDR_ANY,	# TODO add bindaddr as options
		Port		=> $self->mcp->api_console_port,
		Alias		=> __PACKAGE__,
		ClientFilter	=> 'POE::Filter::Line',

		InlineStates		=> {
			client_timeout	=> sub {
				return if $_[HEAP]{shutdown};

				# client timed out
				$self->mcp->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} timed out" );
				$_[KERNEL]->yield( "shutdown" );
				return;
			},
			csn_playerlist	=> sub {
				return if $_[HEAP]{shutdown};
				my( $id, $data ) = @_[ ARG0, ARG1 ];

				if ( ! exists $_[HEAP]->{CSN_SERIALIZED} ) {
					$_[HEAP]->{client}->put("got playerlist data...");
				} else {
					# do we have baggage?
					if ( exists $self->baggage_cache->{ $id } ) {
						my $baggage = shift @{ $self->baggage_cache->{ $id } };
						$_[HEAP]->{client}->put({ result => 1, cmd => 'playerlist', baggage => $baggage, data => $data });
					} else {
						$_[HEAP]->{client}->put({ result => 1, cmd => 'playerlist', baggage => undef, data => $data });
					}
				}
				return;
			},
		},

		ClientConnected		=> sub {
			return if $_[HEAP]{shutdown};

			# TODO add ip-based filtering via file
			if ( ! ( $_[HEAP]{remote_ip} eq '127.0.0.1' or $_[HEAP]{remote_ip} eq '88.198.60.15' ) ) {
				$_[KERNEL]->yield( "shutdown" );
				$self->mcp->info( "rejecting client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port}" );
			} else {
#				$self->mcp->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} connected" );
				$_[HEAP]->{client}->put("MCP v" . $CubeStats::MCP::VERSION . ": You shouldn't have come back, Flynn." ); # Tron

				# timeout client after 2m of inactivity
				$_[KERNEL]->delay( 'client_timeout' => 120 );

				# cache the client
				$self->clients->{ $_[SESSION]->ID } = 1;
			}

			return;
		},
		ClientDisconnected	=> sub {
			# cleanup the client
			delete $self->clients->{ $_[SESSION]->ID };
#			$self->mcp->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} disconnected" );
			return;
		},
		ClientInput		=> sub {
			my $input = $_[ARG0];
			return if $_[HEAP]{shutdown};

			# process the input
			$self->process_input( $_[HEAP], $input );

			# timeout client after 2m of inactivity
			$_[KERNEL]->delay( 'client_timeout' => 120 );

			return;
		},
		ClientError		=> sub {
			my( $syscall_name, $err_num, $err_str ) = @_[ARG0..ARG2];
			return if $_[HEAP]{shutdown};

#			$self->mcp->info( "api_console client error: $syscall_name ($err_num) $err_str" );

			return;
		},

		Error			=> sub {
			my ($syscall_name, $err_num, $err_str) = @_[ARG0..ARG2];

			$self->mcp->info( "api_console server error: $syscall_name ($err_num) $err_str" );

			# retry after 60s
			$poe_kernel->delay( 'create_server' => 60 );
		},
	) );

	return;
};

my %cmds = (
	quit		=> {
		args	=> 0,
		help	=> 'disconnects the connection',
	},
	help		=> {
		args	=> undef,
		help	=> 'lists commands or a command\'s help ( command )',
	},
	serverlist	=> {
		args	=> 0,
		help	=> 'lists connected CSN servers',
	},
	playerlist	=> {
		args	=> 1,
		help	=> 'lists connected players ( server ID )',
	},
	raw		=> {
		args	=> 2,
		help	=> 'sends RAW text to the ac_server STDIN ( server ID, text )',
	},
	rawall		=> {
		args	=> 2,
		help	=> 'sends RAW text to the ac_server STDIN of ALL servers ( text )',
	},
	serialize_on	=> {
		args	=> 0,
		help	=> 'turns on SERIALIZE mode, use with caution!',
	},
	serialize_off	=> {
		args	=> 0,
		help	=> 'turns off SERIALIZE mode, use with caution!',
	},
	ping		=> {
		args	=> 0,
		help	=> 'sends a keep-alive packet to the server',
	},
#	shutdown	=> {
#		args	=> 0,
#		help	=> 'shuts down the MCP server, use with caution!',
#	},
);
$cmds{'exit'} = $cmds{bye} = $cmds{quit};

sub process_input {
	my( $self, $heap, $input ) = @_;

	# serialized or not?
	if ( ! exists $heap->{CSN_SERIALIZED} ) {
		$input =~ s/\s+$//g;
		return if ! length $input;

#		$self->mcp->info( "got api_console input from $heap->{remote_ip}:$heap->{remote_port} -> '$input'" );

		# what is it?
		if ( $input =~ /(\w+)\s?(.*)$/ ) {
			my( $cmd, $data ) = ( lc( $1 ), $2 );
			if ( exists $cmds{ $cmd } ) {
				# enough arguments?
				my @args;
				if ( ! defined $cmds{ $cmd }->{args} or $cmds{ $cmd }->{args} > 0) {
					if ( defined $data and length $data ) {
						@args = split( ' ', $data );
						if ( defined $cmds{ $cmd }->{args} and scalar @args < $cmds{ $cmd }->{args} ) {
							$heap->{client}->put( "Error: '$cmd' needs $cmds{ $cmd }->{args} arguments" );
							return;
						}
					} else {
						if ( defined $cmds{ $cmd }->{args} ) {
							$heap->{client}->put( "Error: '$cmd' needs $cmds{ $cmd }->{args} arguments" );
							return;
						}
					}
				}

				# do it!
				$cmd = 'do_' . $cmd;
				eval {
					my $result = $self->$cmd( $heap, \@args );
					if ( $result->{r} ) {
						if ( defined $result->{d} ) {
							$heap->{client}->put( $result->{d} );
						}
					} else {
						$heap->{client}->put( "Error: $result->{d}" );
					}
				};
				if ( $@ ) {
					$self->mcp->info( "internal error: $@" );
					$heap->{client}->put( "Error: internal error" );
				}
			} else {
				$heap->{client}->put( "Error: unknown command: $cmd" );
			}
		} else {
			$heap->{client}->put( "Error: unknown command: $input" );
		}
	} else {
		# serialized data, process it!
		if ( defined $input and ref $input and ref( $input ) eq 'HASH' ) {
			$input->{cmd} = lc( $input->{cmd} );

#			if ( defined $input->{data} ) {
#				$self->mcp->info( "got api_console input from $heap->{remote_ip}:$heap->{remote_port} -> ($input->{cmd}) $input->{data}" );
#			} else {
#				$self->mcp->info( "got api_console input from $heap->{remote_ip}:$heap->{remote_port} -> ($input->{cmd})" );
#			}

			if ( defined $input->{cmd} and exists $cmds{ $input->{cmd} } ) {
				# enough arguments?
				my @args;
				if ( ! defined $cmds{ $input->{cmd} }->{args} or $cmds{ $input->{cmd} }->{args} > 0) {
					if ( defined $input->{data} and length $input->{data} ) {
						@args = split( ' ', $input->{data} );
						if ( defined $cmds{ $input->{cmd} }->{args} and scalar @args < $cmds{ $input->{cmd} }->{args} ) {
							$heap->{client}->put( { result => 0, cmd => $input->{cmd}, baggage => $input->{baggage}, data => "'$input->{cmd}' needs $cmds{ $input->{cmd} }->{args} arguments" } );
							return;
						}
					} else {
						if ( defined $cmds{ $input->{cmd} }->{args} ) {
							$heap->{client}->put( { result => 0, cmd => $input->{cmd}, baggage => $input->{baggage}, data => "'$input->{cmd}' needs $cmds{ $input->{cmd} }->{args} arguments" } );
							return;
						}
					}
				}

				# do it!
				my $cmd = 'do_' . $input->{cmd};
				eval {
					my $result = $self->$cmd( $heap, \@args );
					if ( $result->{r} ) {
						if ( defined $result->{d} ) {
							$heap->{client}->put( { result => 1, cmd => $input->{cmd}, baggage => $input->{baggage}, data => $result->{d} } );
						}
					} else {
						$heap->{client}->put( { result => 0, cmd => $input->{cmd}, baggage => $input->{baggage}, data => $result->{d} } );
					}
				};
				if ( $@ ) {
					$self->mcp->info( "internal error: $@" );
					$heap->{client}->put( { result => 0, cmd => $input->{cmd}, baggage => $input->{baggage}, data => "internal error" } );
				}
			} else {
				$heap->{client}->put( { result => 0, cmd => $input->{cmd}, baggage => $input->{baggage}, data => "unknown command" } );
			}
		} else {
			# just discard this request
		}
	}

	return;
}

sub do_ping {
	my( $self, $heap, $args ) = @_;

	# hmpf we do nothing...

	return { r => 1, d => undef };
}

sub do_serialize_on {
	my( $self, $heap, $args ) = @_;

	if ( ! exists $heap->{CSN_SERIALIZED} ) {
		$heap->{client}->set_filter( POE::Filter::Reference->new() );
		$heap->{CSN_SERIALIZED} = 1;
	}
	return { r => 1, d => undef };
}

sub do_serialize_off {
	my( $self, $heap, $args ) = @_;

	if ( exists $heap->{CSN_SERIALIZED} ) {
		$heap->{client}->set_filter( POE::Filter::Line->new() );
		delete $heap->{CSN_SERIALIZED};
	}
	return { r => 1, d => undef };
}

sub do_quit {
	my( $self, $heap, $args ) = @_;

	$poe_kernel->yield( 'shutdown' );

	return { r => 1, d => "Goodbye, Flynn." };	# Tron
}

sub do_exit {
	goto \&do_quit;
}

sub do_bye {
	goto \&do_quit;
}

sub do_help {
	my( $self, $heap, $args ) = @_;

	if ( defined $args->[0] ) {
		# command help
		if ( exists $cmds{ $args->[0] } ) {
			return { r => 1, d => "$args->[0]: " . $cmds{ $args->[0] }->{help} . " args(" . ( defined $cmds{ $args->[0] }->{args} ? $cmds{ $args->[0] }->{args} : '0 or more' ) . ")" };
		} else {
			return { r => 0, d => "unknown command: $args->[0]" };
		}
	} else {
		my $commands = join( ' ', sort { $a cmp $b } keys %cmds );
		return { r => 1, d => "Available commands: $commands" };
	}
}

sub do_serverlist {
	my( $self, $heap, $args ) = @_;

	my $servers = join( ' ', sort { $a <=> $b } map { $self->mcp->servers->{ $_ }->{No} } grep { $self->mcp->servers->{ $_ }->{connected} } keys %{ $self->mcp->servers } );
	my $failed = join( ' ', sort { $a <=> $b } map { $self->mcp->servers->{ $_ }->{No} } grep { ! $self->mcp->servers->{ $_ }->{connected} } keys %{ $self->mcp->servers } );
	return { r => 1, d => "Connected server CSNs: " . ( length $servers ? $servers : 'NONE' ) . ( length $failed ? " failed( $failed )" : '' ) };
}

sub do_playerlist {
	my( $self, $heap, $args ) = @_;

	# ok, we got the server CSN
	my $id;
	foreach my $server ( keys %{ $self->mcp->servers } ) {
		if ( $self->mcp->servers->{ $server }->{No} eq $args->[0] ) {
			$id = $server;
			last;
		}
	}
	if ( defined $id ) {
		# send it off to the server!
		if ( $self->mcp->servers->{ $id }->{connected} ) {
			$self->mcp->send_csn_server( $id, "CSN-PLAYERLIST", $poe_kernel->get_active_session->ID );

			# store it in the baggage
			if ( defined $args->[1] ) {
				push( @{ $self->baggage_cache->{ $id } }, $args->[1] );
			}

			return { r => 1, d => undef };
		} else {
			return { r => 0, d => "Unable to retrieve: not connected to server" };
		}
	} else {
		return { r => 0, d => "Unknown CSN ID: $args->[0]" };
	}
}

sub do_raw {
	my( $self, $heap, $args ) = @_;

	# ok, we got the server CSN
	my $id;
	foreach my $server ( keys %{ $self->mcp->servers } ) {
		if ( $self->mcp->servers->{ $server }->{No} eq $args->[0] ) {
			$id = $server;
			last;
		}
	}
	if ( defined $id ) {
		# send it off to the server!
		if ( $self->mcp->servers->{ $id }->{connected} ) {
			shift @$args;
			my $text = join( ' ', @$args );
			$self->mcp->send_csn_server( $id, $text );
			return { r => 1, d => undef };
		} else {
			return { r => 0, d => "Unable to send: not connected to server" };
		}
	} else {
		return { r => 0, d => "Unknown CSN ID: $args->[0]" };
	}
}

sub do_rawall {
	my( $self, $heap, $args ) = @_;
	my $text = join( ' ', @$args );

	foreach my $id ( keys %{ $self->mcp->servers } ) {
		# send it off to the server!
		$self->mcp->send_csn_server( $id, $text );
	}

	return { r => 1, d => undef };
}

#sub do_shutdown {
#	my( $self, $heap, $args ) = @_;
#
#	# shutdown the MCP server!
#	$self->mcp->shutdown;
#}

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->mcp->info( "shutting down..." );

	# kill all of our clients
	foreach my $client ( keys %{ $self->clients } ) {
		$poe_kernel->post( $client, 'shutdown' );
	}
	%{ $self->clients } = ();

	if ( defined $self->server ) {
		$poe_kernel->post( $self->server, 'shutdown' );
		$self->server( undef );
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