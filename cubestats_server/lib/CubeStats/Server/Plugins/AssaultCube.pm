# Declare our package
package CubeStats::Server::Plugins::AssaultCube;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use CubeStats;
use Net::IP::Match::Regexp qw( match_ip );
use Games::AssaultCube::Log::Line;
use CubeStats::Log::Line;
use Games::AssaultCube::Utils qw( htmlcolors );
use File::Copy;
use CubeStats::AC::Maprot;
use CubeStats::AC::Maprot::Map;

use POE qw( Wheel::Run );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has ac_server => (
	isa => 'Maybe[POE::Wheel::Run]',
	is => 'rw',
);

has server_port => ( isa => 'Int', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return no2port( $self->server->no ) } );
has server_cmdline => ( isa => 'ArrayRef[Str]', is => 'rw', );

has gamedata => (
	isa	=> 'HashRef',
	is	=> 'ro',
	default	=> sub { {} },
);

has csnlog => (
	isa	=> 'CubeStats::Log::Line',
	is	=> 'ro',
	default	=> sub {
		return CubeStats::Log::Line->new();
	},
);

has voteyourmaprot_maps => (
	isa => 'ArrayRef[CubeStats::AC::Maprot::Map]',
	is => 'rw',
);

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

sub voteyourmaprot_start {
	my $self = shift;

	if ($self->server->voteyourmaprot) {
		my $newmaprot_file = $self->server->serverroot.'/config/maprot/voteyourmaprot'.$self->server->no.'.cfg';
		my $oldmaprot_file = $self->server->serverroot.'/config/'.$self->server->maprot.'.cfg';
		unless (-e $newmaprot_file) {
			my $oldmaprot = new CubeStats::AC::Maprot({
				filename => $oldmaprot_file,
			});
			$oldmaprot->load_file;
			my @maps = @{$oldmaprot->maps}[0..2];
			my $newmaprot = new CubeStats::AC::Maprot({
				maps => \@maps,
				filename => $newmaprot_file,
			});
			$newmaprot->save_file;
		}
		my $newmaprot = new CubeStats::AC::Maprot({
			filename => $newmaprot_file,
		});
		$newmaprot->load_file;
		my @maps = @{$newmaprot->maps};
		$self->voteyourmaprot_maps(\@maps);
		$self->server->maprot('maprot/voteyourmaprot'.$self->server->no);
	}

}

sub voteyourmaprot_addmap {
	my $self = shift;
	my $log = shift;

	my $newmap = new CubeStats::AC::Maprot::Map({
		map => $log->map,
		mode => $log->mode,
		minutes => 12,
		allowvote => 1,
	});
	my $maprot_file = $self->server->serverroot.'/config/'.$self->server->maprot.'.cfg';
	pop @{$self->voteyourmaprot_maps};
	unshift @{$self->voteyourmaprot_maps}, $newmap;
	my @maps = @{$self->voteyourmaprot_maps};
	my $newmaprot = new CubeStats::AC::Maprot({
		maps => \@maps,
		filename => $maprot_file,
	});
	$newmaprot->save_file;

}

sub STARTALL {
	my $self = shift;

	$self->server->info( "in STARTALL" );

	$self->voteyourmaprot_start;

	# init some configs
	$self->server->debug('ac_server_port: '.$self->server_port);

	my $prefix = '\f2';
	$prefix = $self->server->clantag.$prefix.' ' if $self->server->clantag;
	my $suffix = ' \f1CSN #'.$self->server->no.'\f3';

	my $servername = $prefix.$self->server->name.$suffix;

	$self->gamedata->{desc} = $servername;
	my $tmpname = $servername;
	$tmpname =~ s/\\f/\f/g;
	$self->gamedata->{desc_html} = htmlcolors( $tmpname );
	$self->gamedata->{max_players} = $self->server->limit;
	$self->gamedata->{startup_ts} = time();

	$self->server_cmdline( [ $self->server->serverroot, $self->server->serverbin,
		'-k-2', '-f'.$self->server_port, '-c'.$self->server->limit,
		'-rconfig/'.$self->server->maprot.'.cfg', '-P'.$self->server->serverflags, '-mlocalhost/',
		'-n1'.$prefix, '-n2'.$suffix,
		'-n'.$servername,
	] );
	$self->server->debug('ac_server_cmdline: '.join(' ',@{$self->server_cmdline}));

	$poe_kernel->yield( 'create_server' );

	return;
}

event '_child' => sub {
	return;
};

event '_parent' => sub {
	return;
};

event server_closed => sub {
	my $self = shift;

	$self->server->warning( "ac_server process unexpectedly died" );
	$self->ac_server( undef );
	$poe_kernel->yield( 'create_server' );
	return;
};

event create_server => sub {
	my $self = shift;

	# sanity
	if (defined $self->ac_server) {
		$self->server->warning("create_server called when we already have a server running!");
		return;
	}

	$self->server->info('starting ac_server...');
	$self->ac_server(POE::Wheel::Run->new(
		Program		=> [ $^X, $ENV{CUBESTATS_ROOT}.'/scripts/launcher.pl', @{$self->server_cmdline} ],
		StdoutEvent	=> 'server_stdout',
		CloseEvent	=> 'server_closed',
		StderrFilter => POE::Filter::Line->new(),
		StdioFilter => POE::Filter::Line->new(),
		#NoSetSid	=> 1,
		#NoSetPgrp	=> 1,
	));
	$self->server->debug('started ac_server with pid '.$self->ac_server->PID);

	# smart CHLD handling
	if ( $poe_kernel->can( "sig_child" ) ) {
		$poe_kernel->sig_child( $self->ac_server->PID => 'got_chld' );
	} else {
		$poe_kernel->sig( 'CHLD', 'got_chld' );
	}

	# clear the id <-> host mapping
	%{ $self->server->connected_players } = ();

	# inform ServerQuery pinger to reset it's "failure" counter
	$self->server->serverquery->reset_failures;

	return;
};

# use with caution!
sub restart_ac {
	my $self = shift;

	# make sure our goddamn server is DEAD, KTHXBYE!
	if (defined $self->ac_server) {
		$self->server->info( "automatically restarting ac_server" );
		$self->ac_server->kill(9);
	}

	return;
}

event got_chld => sub {
	$poe_kernel->sig_handled;
	return;
};

sub analyze_gamedata {
	my( $self, $log ) = @_;

	my $result = eval { $log->csn };
	if ( ! $@ and defined $result and $result ) {
		# analyze CSN events

		if ( $log->event eq 'GameStart' and $self->server->voteyourmaprot and $log->minutes eq 15 ) {
			$self->voteyourmaprot_addmap($log);
		} elsif ( $log->event =~ /^(?:Frag|Gib)(?:Team)?$/ ) {
			$self->server->xmlserver->eventmap( lc( $log->event ), {
				Killer_ID	=> $log->killer->id,
				Killer_Nick	=> ( exists $self->server->connected_players->{ $log->killer->id }->{nick} ? $self->server->connected_players->{ $log->killer->id }->{nick} : "unarmed" ),
				Killer_X	=> $log->killer->pos_x,
				Killer_Y	=> $log->killer->pos_y,
				Killer_HP	=> $log->killer->hp,
				Killer_Armor	=> $log->killer->armor,
				Killer_Team	=> $log->killer->team_name,
				Killer_Weapon	=> $log->gun_name,
				Victim_ID	=> $log->victim->id,
				Victim_Nick	=> ( exists $self->server->connected_players->{ $log->victim->id }->{nick} ? $self->server->connected_players->{ $log->victim->id }->{nick} : "unarmed" ),
				Victim_X	=> $log->victim->pos_x,
				Victim_Y	=> $log->victim->pos_y,
				Victim_Team	=> $log->victim->team_name,
			} );
		} elsif ( $log->event =~ /^Flag(.+)$/ ) {
			$self->server->xmlserver->eventmap( lc( $log->event ), {
				Player_ID	=> $log->id,
				Player_Nick	=> ( exists $self->server->connected_players->{ $log->id }->{nick} ? $self->server->connected_players->{ $log->id }->{nick} : "unarmed" ),
				Player_X	=> $log->pos_x,
				Player_Y	=> $log->pos_y,
				( $log->can( 'team_name' ) ? ( Player_Team => $log->team_name ) : () ),
				( $log->can( 'score' ) ? ( Score => $log->score ) : () ),
				( $log->can( 'time' ) ? ( Time => $log->time ) : () ),
			} );
		} elsif ( $log->event eq 'Suicided' ) {
			$self->server->xmlserver->eventmap( lc( $log->event ), {
				Player_ID	=> $log->id,
				Player_Nick	=> ( exists $self->server->connected_players->{ $log->id }->{nick} ? $self->server->connected_players->{ $log->id }->{nick} : "unarmed" ),
				Player_X	=> $log->pos_x,
				Player_Y	=> $log->pos_y,
				Player_Team	=> $log->team_name,
			} );
		}
	} else {
		# analyze regular AC events

		# get map + gamemode
		if ( $log->event eq 'GameStart' ) {
			$self->gamedata->{map} = $log->map;
			$self->gamedata->{gamemode} = $log->gamemode_fullname;
			$self->gamedata->{minutes_left} = $log->minutes;
			$self->gamedata->{minutes_left_ts} = time();	# TODO use gmtime somehow?

			$self->server->xmlserver->eventmap( lc( $log->event ), $self->gamedata );
		} elsif ( $log->event eq 'Status' ) {
			if ( $log->players == 0 ) {
				# no players, game over!
				foreach my $t ( qw( map gamemode minutes_left minutes_left_ts ) ) {
					delete $self->gamedata->{ $t };
				}

				$self->server->xmlserver->eventmap( 'gameend', {} );
			}
		}
	}

	return;
}

event server_stdout => sub {
	my ( $self, $line ) = @_;
	chomp $line;
	return if ! length $line;

	$self->server->debug("ac_server_stdout: $line");
	if ($self->server->log_dispatcher) {
		$self->server->log_dispatcher->new_line($line);
	}

	# determine event type
	my $logline;
	eval { $logline = Games::AssaultCube::Log::Line->new( $line, $self->csnlog ) };
	if ( $@ ) {
		$self->server->debug( "error in parsing: $@" );
	}
	if ( ! $@ and defined $logline ) {
		# our analytic code for various data
		$self->analyze_gamedata( $logline );

		# argh, damn Getty!
		foreach my $accessor ( qw( nick victim ) ) {
			if ( $logline->can( $accessor ) ) {
				foreach my $id ( keys %{ $self->server->connected_players } ) {
					if ( exists $self->server->connected_players->{ $id }->{nick} and $self->server->connected_players->{ $id }->{nick} eq $logline->$accessor() ) {
						$logline->{$accessor} = $logline->$accessor() . " [$id]";
						last;
					}
				}
			}
		}

		if ( $logline->event =~ /^(?:Killed|Client(?:\w+)|Flag(?:\w+)|CallVote|Suicide|TeamStatus|Game(\w+))$/ ) {
			# skip known events that have IPs
			if ( $logline->event !~ /^(?:ClientWelcome|ClientAdmin|ClientChangeRole|ClientConnected|ClientVersion)$/ ) {
				# okay, send it off to irc!
				if ($self->server->irc) {
					$self->server->irc_bot->tell( $logline->tostr );
				}
			}
		} elsif ( $logline->event eq 'FatalError' ) {
			# automatically restart ac_server
			$self->server->info( "Detected Fatal Error: " . $logline->error );

			# make sure our goddamn server is DEAD, KTHXBYE!
			if (defined $self->ac_server) {
				$self->ac_server->kill(9);
			}
		} elsif ( $logline->event eq 'CallVote' ) {
			if ( $self->server->irc ) {
				$self->server->irc_bot->send_says( $logline->tostr );
			}
		}

#		if ($line =~ m/^\[\d+\.\d+\.\d+\.\d+\] (.*)$/ or
#			$line =~ m/^(Game .*)$/) {
#
#			$self->server->irc_bot->tell( $1 );
#		}
	}

	# TODO replace all this log crap with G::AC::Log::Line :)

	# for the BS- clantag support
	if ( $line =~ /^\<AC\s+\d+\s+\d+\>\s+ClientWelcome\s+\'(-?\d+)\'\s+\'([^\s]+)\'\s+\'(-?\d+)\'$/ ) {
		my( $id, $nick, $cn ) = ( $1, $2, $3 );

		$self->server->connected_players->{ $id }->{nick} = $nick;
		$self->server->connected_players->{ $id }->{welcome}++;

		if ( $self->server->connected_players->{ $id }->{welcome} == 1 ) {
			$self->check_nick( $nick, $id );

			if ($self->server->irc) {
				$self->server->irc_bot->send_says( "client <$nick [$id]> connected" );
			}
		}
	} elsif ( $line =~ /^\<AC\s+\d+\s+\d+\>\s+ClientNickChange\s+\'(-?\d+)\'\s+\'([^\s]+)\'$/ ) {
		my( $id, $nick ) = ( $1, $2 );

		if ($self->server->irc) {
			$self->server->irc_bot->send_says( "client <" . $self->server->connected_players->{ $id }->{nick} . " [$id]> changed nick to <$nick [$id]>" );
		}
		$self->server->connected_players->{ $id }->{nick} = $nick;
		$self->check_nick( $nick, $id );
	} elsif ( $line =~ /^\<AC\s+\d+\s+\d+\>\s+ClientConnected\s+\'(-?\d+)\'\s+\'([^\s]+)\'\s+\'(-?\d+)\'$/ ) {
		my( $id, $host, $cn ) = ( $1, $2, $3 );

		# are we shutting down?
		if ( defined $self->server->is_shutdown->{shutdown} ) {
			$self->put( "KICKID $id" );
		}

		# cache the host and id
		$self->server->connected_players->{ $id } = { host => $host };
	} elsif ( $line =~ /^\<AC\s+\d+\s+\d+\>\s+ClientDisconnected\s+\'(-?\d+)\'\s+\'(-?\d+)\'$/ ) {
		my( $id, $reason ) = ( $1, $2 );

		if ( exists $self->server->connected_players->{ $id } ) {
			if ($self->server->irc and defined $self->server->connected_players->{ $id }->{nick} and exists $self->server->connected_players->{ $id }->{welcome} and defined $self->server->connected_players->{ $id }->{welcome} and $self->server->connected_players->{ $id }->{welcome} > 0) {
				$self->server->irc_bot->send_says( "client <" . $self->server->connected_players->{ $id }->{nick} . " [$id]> disconnected" );
			}
			delete $self->server->connected_players->{ $id };

			$self->check_shutdown;
		}

	# for the says stuff
	} elsif ( $line =~ m!^\[[^\]]+\]\s+([^\s]+)\s+says:\s+\'(.*)\'$! ) {
		# nick, text
		if ($self->server->irc) {
			# argh, damn Getty!
			foreach my $id ( keys %{ $self->server->connected_players } ) {
				if ( $self->server->connected_players->{ $id }->{nick} eq $1 ) {
					$self->server->irc_bot->send_says( "<$1 [$id]> $2" );
					last;
				}
			}
		}
	}
	return;
};

# TODO move this to CubeStats::Common
# check_nick( $configstr, $nick )
sub check_nick {
	my( $self, $nick, $id ) = @_;

	# okay, is this player using the BS clantag?
	if ( $nick =~ /^bs\-(.+)$/i ) {
		my $name = lc( $1 );

		if ( ! exists $self->server->bs_clanlist->{ $name } ) {
			$self->server->info( "kicking <$nick [$id]> for clanlist failure" );
			$self->put( "KICKID $id" );
			return;
		} else {
			# does the player have ip protection?
			if ( defined $self->server->bs_clanlist->{ $name } ) {
				# do we know the host of this player?
				if ( exists $self->server->connected_players->{ $id } ) {
					if( ! match_ip( $self->server->connected_players->{ $id }->{host}, $self->server->bs_clanlist->{ $name } ) ) {
						$self->server->info( "kicking <$nick [$id]> for clanlist failure ( ip failure: " . $self->server->connected_players->{ $id }->{host} . " )" );
						$self->put( "KICKID $id" );
						return;
					}
				} else {
					# hmpf?
					$self->server->info( "did not have cached IP entry for player <$nick [$id]>" );
					$self->put( "KICKID $id" );
					return;
				}
			}
		}
	}

	# okay, is this player using a banned "nick" ?
	if ( defined $self->server->nickban and $nick =~ $self->server->nickban ) {
		$self->server->info( "kicking <$nick [$id]> for nickban match" );
		$self->put( "KICKID $id" );
		return;
	}

	# TODO is the player using an "ip-alike" nick that's IPv4 or IPv6? If so, kick them!

	# check the "IP list for registered" users
	$self->check_iplist( $nick, $id );

	return;
}

sub check_iplist {
	my( $self, $nick, $id ) = @_;
return;	# do nothing for now, we want to deploy...
	# TODO for now, we use a static list... yikes!
	# in the future we simply send it off to MCP without looking
	my %mapping = (
		# Nick		=> User_ID in DB
		'BS-Getler'	=> 1,
		'BS-Apocalypse'	=> 33764,
	);

	# send it off to MCP!
	if ( exists $mapping{ $nick } ) {
		$self->server->api_console->send_MCP( "CSN-REGISTRATIONCHECK $id $nick " . $self->server->connected_players->{ $id }->{host} );
	}

	return;
}

# sends text to ac_server STDIN
sub put {
	my( $self, $text ) = @_;

	$self->server->debug( "sending to ac_server: $text" );
	$self->ac_server->put( $text );
	return;
}

sub set_shutdown {
	my( $self, $style, $text ) = @_;

	# already shutdown?
	if ( defined $self->server->is_shutdown->{shutdown} ) {
		return "Shutdown already set";
	}

	# valid data?
	if ( $style !~ /^(?:NOW|\d+(s?))$/ ) {
		return "Unknown style: $style";
	}
	if ( ! defined $text or ! length $text ) {
		$text = 'The server is shutting down, please reconnect to the same IP/Port soon!';
	}

	$self->server->is_shutdown->{shutdown} = $style;
	$self->server->is_shutdown->{text} = $text;

	$self->check_shutdown;
	return;
}

sub check_shutdown {
	my $self = shift;

	if ( defined $self->server->is_shutdown->{shutdown} and ! exists $self->server->is_shutdown->{is_shutdown} ) {
		# okay, what style?
		if ( $self->server->is_shutdown->{shutdown} eq 'NOW' ) {
			# do it!
			$self->start_shutdown;
		} elsif ( $self->server->is_shutdown->{shutdown} =~ /^\d+$/ ) {
			# number of players
			my $diff = ( scalar keys %{ $self->server->connected_players } ) - $self->server->is_shutdown->{shutdown};
			if ( $diff <= 0 ) {
				$self->start_shutdown;
			} else {
				if ( $diff == -1 or $diff == -5 or $diff == -10 or $diff == -20 ) {
					# print the announce!
					$self->put( "SERVERMSG ( less than " . $self->server->is_shutdown->{shutdown} . " players ) " . $self->server->is_shutdown->{text} );
				}
			}
		} elsif ( $self->server->is_shutdown->{shutdown} =~ /^(\d+)s$/ ) {
			# delayed shutdown
			$self->start_shutdown( $1 );
		} else {
			die "unknown shutdown style: " . $self->server->is_shutdown->{shutdown};
		}
	}

	return;
}

sub start_shutdown {
	my( $self, $delay ) = @_;

	if ( exists $self->server->is_shutdown->{is_shutdown} ) {
		return;
	} else {
		$self->server->is_shutdown->{is_shutdown} = 1;
	}

	# do the shutdown!
	if ( defined $delay ) {
		# do it via delay
		$poe_kernel->post( $self->get_session_id, 'delayed_shutdown', $delay );
	} else {
		# do it now!
		$poe_kernel->post( $self->get_session_id, 'init_shutdown' );
	}

	return;
}

event delayed_shutdown => sub {
	my( $self, $delay ) = @_;

	# print the announce!
	$self->put( "SERVERMSG ( in $delay seconds ) " . $self->server->is_shutdown->{text} );

	# loop over and over?
	if ( $delay < 10 ) {
		$poe_kernel->delay( 'init_shutdown' => $delay );
	} else {
		$poe_kernel->delay( 'delayed_shutdown' => int( $delay / 2 ), int( $delay / 2 ) );
	}

	return;
};

event init_shutdown => sub {
	my( $self ) = @_;

	# okay, send off the announce text!
	$self->put( "SERVERMSG ( NOW ) " . $self->server->is_shutdown->{text} );

	# give the server a sec to do it's stuff
	$poe_kernel->delay( 'actual_shutdown' => 1 );

	return;
};

event actual_shutdown => sub {
	my $self = shift;

	$self->server->shutdown;

	return;
};

sub STOPALL {
	my $self = shift;

	$self->server->info( "in STOPALL" );

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

	# make sure our goddamn server is DEAD, KTHXBYE!
	if (defined $self->ac_server) {
		$self->ac_server->kill(9);
		$self->ac_server( undef );
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
