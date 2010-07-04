# Declare our package
package CubeStats::Server::Plugins::API_Console;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::Server::TCP );
use Socket qw( INADDR_ANY );

use Storable qw( nfreeze );
use MIME::Base64 qw( encode_base64 );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has 'tcp' => (
	isa		=> 'Maybe[Int]',
	is		=> 'rw',
	default		=> undef,
);

has 'clients' => (
	isa		=> 'HashRef',
	is		=> 'ro',
	default		=> sub { {} },
);

has server_port => ( isa => 'Int', is => 'rw', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->ac_server->server_port + 5 } );
has allowedips_file => ( isa => 'Str', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->serverroot . '/config/api_console_ips.cfg' } );
has allowedips_ts => ( isa => 'Int', is => 'rw',
	default => 0 );
has allowedips => ( isa => 'ArrayRef[Str]', is => 'ro',
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

	# okay, fire up the server!
	$poe_kernel->yield( 'create_server' );
	$poe_kernel->yield( 'check_allowedips' );

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

	$self->server->info( "in STOPALL" );

	return;
}

event 'create_server' => sub {
	my $self = shift;

	$self->server->info( "starting api_console server port(" . $self->server_port . ")..." );

	if ( defined $self->tcp ) {
		$poe_kernel->call( $self->tcp, "shutdown" );
		$self->tcp( undef );
	}

	$self->tcp( POE::Component::Server::TCP->new(
		Address		=> INADDR_ANY,	# TODO add bindaddr as options
		Port		=> $self->server_port,
		Alias		=> __PACKAGE__,
		ClientFilter	=> 'POE::Filter::Line',

		InlineStates		=> {
			client_timeout	=> sub {
				return if $_[HEAP]{shutdown};

				# client timed out
#				$self->server->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} timed out" );
				$_[KERNEL]->yield( "shutdown" );
				return;
			},
			csn_put		=> sub {
				my( $data ) = $_[ ARG0 ];
				return unless $_[HEAP]->{connected};
				return if $_[HEAP]->{shutdown};

#				$self->server->debug( "sending msg to (" . $_[SESSION]->ID . "): $data" );
				$_[HEAP]{server}->put( $data );
				return;
			},
		},

		ClientConnected		=> sub {
			return if $_[HEAP]->{shutdown};

			# is the addr on the whitelist?
			if ( grep( $_ eq $_[HEAP]->{remote_ip}, @{ $self->allowedips } ) == 0 ) {
				# not allowed
				$self->server->info( "rejecting api_console connection from: $_[HEAP]{remote_ip}:$_[HEAP]{remote_port}" );
				$_[KERNEL]->yield( "shutdown" );
			} else {
#				$self->server->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} connected" );

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
			$_[KERNEL]->delay( 'client_timeout' => undef );
#			$self->server->info( "client from $_[HEAP]{remote_ip}:$_[HEAP]{remote_port} disconnected" );
			return;
		},
		ClientInput		=> sub {
			my $input = $_[ARG0];
			$input =~ s/\s+$//g;
			return if ! length $input;
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

#			$self->server->info( "api_console client error: $syscall_name ($err_num) $err_str" );

			return;
		},

		Error			=> sub {
			my ($syscall_name, $err_num, $err_str) = @_[ARG0..ARG2];

			$self->server->info( "api_console server error: $syscall_name ($err_num) $err_str" );

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
	playerlist	=> {
		args	=> 0,
		help	=> 'lists the players on the server',
	},
	serverquery	=> {
		args	=> 0,
		help	=> 'returns the cached serverquery results',
	},
	ping		=> {
		args	=> 0,
		help	=> 'sends a keep-alive packet to the server',
	},
	shutdown	=> {
		args	=> 1,
		help	=> 'shuts down the server, use with caution! ( style, text ) - style: NOW, num_players ( 5 ), num_seconds ( 60s )',
	},
);
$cmds{'exit'} = $cmds{bye} = $cmds{quit};

sub process_input {
	my( $self, $heap, $input ) = @_;

	#$self->server->info( "got api_console input from $heap->{remote_ip}:$heap->{remote_port} -> '$input'" );

	# is it CSN stuff?
	if ( $input eq 'CSN-MCP' ) {
		# this is the MCP connection!
		$heap->{'CSN-MCP'} = 1;
	} elsif ( $input =~ /^CSN\-(.+)$/ ) {
		my $command = $1;
		# what is it?
		if ( $command =~ /(\w+)\s?(.*)$/ ) {
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
				eval { $self->$cmd( $heap, \@args ) };
				if ( $@ ) {
					$self->server->debug( "execute cmd( $cmd ) error: $@" );
					$heap->{client}->put( "Error: internal error" );
				}
			} else {
				$heap->{client}->put( "Error: unknown command: $cmd" );
			}
		} else {
			$heap->{client}->put( "Error: unknown command: $input" );
		}
	} else {
		# Pass it on to ac_server raw
		$self->server->ac_server->put( $input );
	}

	return;
}

sub send_MCP {
	my( $self, $text ) = @_;

	# do we have MCP connected to us?
	foreach my $id ( keys %{ $self->clients } ) {
		my $heap = $poe_kernel->ID_id_to_session( $id )->get_heap;
		if ( defined $heap and exists $heap->{'CSN-MCP'} ) {
			$poe_kernel->post( $id, 'csn_put', $text );
			last;
		}
	}

	return;
}

sub do_ping {
	my( $self, $heap, $args ) = @_;

	# hmpf we do nothing...

	return;
}

sub do_shutdown {
	my( $self, $heap, $args ) = @_;

	my $style = shift @$args;
	my $text = undef;
	if ( scalar @$args ) {
		$text = join( ' ', @$args );
	}


	my $ret = $self->server->ac_server->set_shutdown( $style, $text );
	if ( ! defined $ret ) {
		$heap->{client}->put( "Shutdown initiated..." );
	} else {
		$heap->{client}->put( "Error: $ret" );
	}

	return;
}

sub do_quit {
	my( $self, $heap, $args ) = @_;

	$poe_kernel->yield( 'shutdown' );
	return;
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
			$heap->{client}->put( "$args->[0]: " . $cmds{ $args->[0] }->{help} . " args(" . ( defined $cmds{ $args->[0] }->{args} ? $cmds{ $args->[0] }->{args} : '0 or more' ) . ")" );
		} else {
			$heap->{client}->put( "unknown command: $args->[0]" );
		}
	} else {
		my $commands = join( ' ', keys %cmds );
		$heap->{client}->put( "Available commands: $commands" );
	}

	return;
}

sub do_serverquery {
	my( $self, $heap, $args ) = @_;

	# return our list of serverquery objects
	my $frozen = encode_base64( nfreeze( $self->server->serverquery->cache ), '' );
	$heap->{client}->put( $frozen );
	@{ $self->server->serverquery->cache } = ();

	return;
}

sub do_playerlist {
	my( $self, $heap, $args ) = @_;

	# return our list of players
	my $frozen = encode_base64( nfreeze( $self->server->connected_players ), '' );
	$heap->{client}->put( $frozen );

	return;
}

my $allowedips_printedwarning = 0;

event check_allowedips => sub {
	my $self = shift;

	my $file = $self->allowedips_file;

	if ( -e $file ) {
		my $mtime = ( stat( _ ) )[9];
		if ( $mtime > $self->allowedips_ts ) {
			# load it in!
			$self->server->debug( "reloading api_console allowedips file: $file" );
			$self->allowedips_ts( $mtime );
			open( my $fh, '<', $file );
			if ( defined $fh ) {
				my @data = <$fh>;
				close( $fh );
				@{ $self->allowedips } = ();
				foreach my $l ( @data ) {
					chomp $l;
					next if length( $l ) == 0;
					next if $l =~ /^\s?\#/;

					push( @{ $self->allowedips }, $l );
				}

				# load the "defaults"
				push( @{ $self->allowedips }, "127.0.0.1", "88.198.60.15" );

				$self->server->debug( "reloaded '$file' with " . scalar @{ $self->allowedips } . " ips" );
			} else {
				$self->server->info( "unable to open api_console file: $!" );
			}
		}
	} else {
		# reset to empty, for security
		if ( $allowedips_printedwarning++ == 0 ) {
			$self->server->debug( "api_console allowedips config(" . $self->server->allowedips_file . ") not found" );
		}
		@{ $self->allowedips } = ();

		# load the "defaults"
		push( @{ $self->allowedips }, "127.0.0.1", "88.198.60.15" );
	}

	# TODO Make sure all "existing" connections is legit

	# recheck every minute
	$poe_kernel->delay( 'check_allowedips' => 60 );

	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->server->info( "shutting down..." );

	# kill all of our clients
	foreach my $client ( keys %{ $self->clients } ) {
		$poe_kernel->post( $client, 'shutdown' );
	}
	%{ $self->clients } = ();

	if ( defined $self->tcp ) {
		$poe_kernel->post( $self->tcp, "shutdown" );
		$self->tcp( undef );
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
