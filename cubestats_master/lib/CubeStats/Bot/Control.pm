package CubeStats::Bot::Control;
our $VERSION = '0.1';

use Moose;
use CubeStats::Bot;
use CubeStats::Bot::MCPConnection;
use MooseX::AttributeHelpers;

with 'MooseX::LogDispatch::Levels';

has bots => (
	metaclass	=> 'Collection::Hash',
	is		=> 'rw',
	isa		=> 'HashRef[CubeStats::Bot]',
	default		=> sub { {} },
	provides  => {
		keys	=> 'all_bots',
		get	=> 'get_bot',
		set	=> 'set_bot',
	},
);

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

has mcp_connection => (
	isa	=> 'CubeStats::Bot::MCPConnection',
	is	=> 'ro',
	default	=> sub {
		my $self = shift;
		return CubeStats::Bot::MCPConnection->new( { bot => $self } );
	},
);

# limited to "word" characters as defined by perlre \w!
my %cmds = (
	msg		=> {
		args	=> 2,
		help	=> 'PrivMsg a person on another network -> !msg ap0cal@QuakeNet hey fool',
	},
	help		=> {
		args	=> undef,
		help	=> 'Lists the help commands and info per command -> !help msg',
	},
	online		=> {
		args	=> 0,
		help	=> 'Lists the online users in the channels -> !online',
	},
	networks	=> {
		args	=> 0,
		help	=> 'Lists the networks the bot is on -> !networks',
	},
	playerlist	=> {
		args	=> 1,
		help	=> 'Lists the players on a server -> !playerlist 8',
	},
	serverlist	=> {
		args	=> 0,
		help	=> 'Lists the connected CSN servers -> !serverlist',
	},
	kick		=> {
		args	=> 2,
		help	=> '( ops only ) Kicks a player from a CSN server -> !kick 8 18',
	},
	ban		=> {
		args	=> 2,
		help	=> '( ops only ) Bans a player from a CSN server -> !ban 2 5',
	},
	says		=> {
		args	=> 2,
		help	=> '( ops only ) Sends text to the console of the CSN server -> !says 17 Hello all!',
	},
	saysall		=> {
		args	=> 1,
		help	=> '( ops only ) Sends text to the console to all CSN servers -> !saysall Today\'s a good day to die!',
	},
	mcpraw		=> {
		args	=> 2,
		help	=> '( ops only ) Sends a raw command to the CSN server -> !mcpraw 23 SERVERDESC The 1337 Server',
	},
	mcprawall		=> {
		args	=> 1,
		help	=> '( ops only ) Sends a raw command to all CSN servers ( use with caution! ) -> !mcprawall SERVERMSG HELLO from admin!',
	},
);

sub process_command {
	my( $self, $ispriv, $bot, $nick, $input ) = @_;

	$input =~ s/\s+$//g;
	return if ! length $input;

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
						$bot->privmsg( $nick => "Error: '$cmd' needs $cmds{ $cmd }->{args} arguments" );
						return;
					}
				} else {
					if ( defined $cmds{ $cmd }->{args} ) {
						$bot->privmsg( $nick => "Error: '$cmd' needs $cmds{ $cmd }->{args} arguments" );
						return;
					}
				}
			}

			# do it!
			$cmd = 'do_' . $cmd;
			eval { $self->$cmd( $bot, $ispriv, $nick, \@args ) };
			if ( $@ ) {
				$self->info( "internal error: $@" );
				$bot->privmsg( $nick => "Error: internal error" );
			}
		} else {
			if ( $ispriv ) {
				$bot->privmsg( $nick => "Error: unknown command: $cmd - please type !help for more information" );
			}
		}
	} else {
		if ( $ispriv ) {
			$bot->privmsg( $nick => "Error: Unknown command - please type !help for more information" );
		}
	}

	return;
}

sub do_serverlist {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# send the serverlist to MCP
	$self->mcp_connection->put_mcp( 'SERVERLIST', undef, $bot->name . ':' . $nick );
	return;
}

sub do_playerlist {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# send the playerlist to MCP
	$self->mcp_connection->put_mcp( 'PLAYERLIST', $args->[0] . ' ' . $bot->name . ':' . $nick, $bot->name . ':' . $nick );
	return;
}

sub do_kick {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# basically do this in terms of MCPRAW
	$self->do_mcpraw( $bot, $ispriv, $nick, [(shift @$args ) . ' KICKID ' . CORE::join( ' ', @$args )] );

	return;
}

sub do_says {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# basically do this in terms of MCPRAW
	$self->do_mcpraw( $bot, $ispriv, $nick, [(shift @$args ) . ' SERVERMSG ' . CORE::join( ' ', @$args )] );

	return;
}

sub do_saysall {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# basically do this in terms of MCPRAW
	$self->do_mcprawall( $bot, $ispriv, $nick, ['SERVERMSG ' . CORE::join( ' ', @$args )] );

	return;
}

sub do_ban {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# basically do this in terms of MCPRAW
	$self->do_mcpraw( $bot, $ispriv, $nick, [(shift @$args ) . ' BANID ' . CORE::join( ' ', @$args )] );

	return;
}

sub do_mcpraw {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# only ops on QuakeNet #cubestats can do this
	if ( $bot->name eq 'QuakeNet' and $bot->irc->is_channel_operator( '#cubestats', $nick ) ) {
		# send the command to MCP
		$self->mcp_connection->put_mcp( 'RAW', CORE::join( ' ', @$args ), $bot->name . ':' . $nick );
	} else {
		$bot->privmsg( $nick => "You must be an op on #cubestats\@QuakeNet to use this." );
	}
	return;
}

sub do_mcprawall {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# only ops on QuakeNet #cubestats can do this
	if ( $bot->name eq 'QuakeNet' and $bot->irc->is_channel_operator( '#cubestats', $nick ) ) {
		# send the command to MCP
		$self->mcp_connection->put_mcp( 'RAWALL', CORE::join( ' ', @$args ), $bot->name . ':' . $nick );
	} else {
		$bot->privmsg( $nick => "You must be an op on #cubestats\@QuakeNet to use this." );
	}
	return;
}

sub do_help {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	if ( defined $args->[0] ) {
		# command help
		if ( exists $cmds{ $args->[0] } ) {
			$bot->privmsg( $nick => "$args->[0]: " . $cmds{ $args->[0] }->{help} . " args(" . ( defined $cmds{ $args->[0] }->{args} ? $cmds{ $args->[0] }->{args} : '0 or more' ) . ")" );
		} else {
			$bot->privmsg( $nick => "Error: unknown command '$args->[0]'" );
		}
	} else {
		my $commands = CORE::join( ' ', sort { $a cmp $b } keys %cmds );
		$bot->privmsg( $nick => "Available commands: $commands" );
	}
}

sub do_networks {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# send the network list to the nick
	my $netlist = "Available Networks: " . CORE::join( ", ", $self->all_bots );
	$bot->privmsg( $nick => $netlist );
}

sub do_online {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# Okay, retrieve the list of all networks + users on them
	$bot->privmsg( $nick => "Online Users:" );
	foreach my $net ( $self->all_bots ) {
		# FIXME if the userlist gets too long...
		my $netbot = $self->get_bot( $net );
		if ($netbot->cubestats) {
			my $userlist = " [".$net."] [".$netbot->cubestats."]: ";
			foreach my $user ( $netbot->irc->channel_list( $netbot->cubestats ) ) {
				$userlist .= ' ' . $user;
			}
			$bot->privmsg( $nick => $userlist );
		}
		if ($netbot->roc) {
			my $userlist = " [".$net."] [".$netbot->roc."]: ";
			foreach my $user ( $netbot->irc->channel_list( $netbot->roc ) ) {
				$userlist .= ' ' . $user;
			}
			$bot->privmsg( $nick => $userlist );
		}
		if ($netbot->battlecube) {
			my $userlist = " [".$net."] [".$netbot->battlecube."]: ";
			foreach my $user ( $netbot->irc->channel_list( $netbot->battlecube ) ) {
				$userlist .= ' ' . $user;
			}
			$bot->privmsg( $nick => $userlist );
		}
	}
}

sub do_msg {
	my ( $self, $bot, $ispriv, $nick, $args ) = @_;

	# we expect nick@network as first argument
	if ( (shift @$args) =~ /^([^\@]+)\@(\w+)$/ ) {
		my $destnick = $1;
		my $destnet = $2;
		my $desttext = CORE::join( ' ', @$args );

		# does the network exist?
		if ( ! grep { $_ eq $destnet } $self->all_bots ) {
			$bot->privmsg( $nick => "Network $destnet is not recognized" );
		} else {
			# does the user exist?
			$destnet = $self->get_bot( $destnet );
			if ( $destnet->irc->is_channel_member( '#cubestats', $destnick ) ) {
				$destnet->privmsg( $destnick => "MSG FROM $nick" . '@' . $bot->name . " > $desttext" );
				$bot->privmsg( $nick => "Message sent to $destnick" );
			} else {
				$bot->privmsg( $nick => "User $destnick is not online on $destnet" );
			}
		}
	} else {
		$bot->privmsg( $nick => 'Error: Invalid arguments - please supply something like !msg ap0cal@QuakeNet hey fool' );
	}
}

sub msg {
	my ( $self, $bot, $nick, $text ) = @_;
	return if $nick =~ /^CSN/;

	$self->process_command( 1, $bot, $nick, $text );

	return;
}

sub pubmsg {
	my ( $self, $bot, $nick, $chans, $text ) = @_;
	return if $nick =~ /^CSN/;

	if ( $text =~ /^!(.+)$/ ) {
		$self->process_command( 0, $bot, $nick, $1 );
	}

	for my $chan (@{$chans}) {
		for my $botname ($self->all_bots) {
			next if $botname eq $bot->name;
			my $otherbot = $self->get_bot($botname);
			if ($chan eq $bot->cubestats and $otherbot->cubestats) {
				$otherbot->privmsg( $otherbot->cubestats => "<".$nick."> ".$text );
			} elsif ($chan eq $bot->roc and $otherbot->roc) {
				$otherbot->privmsg( $otherbot->roc => "<".$nick."> ".$text );
			} elsif ($chan eq $bot->battlecube and $otherbot->battlecube) {
				$otherbot->privmsg( $otherbot->battlecube => "<".$nick."> ".$text );
			}
		}
	}

}

sub new_battlecube_rss {
	my ( $self, $rss ) = @_;
	for my $botname ($self->all_bots) {
		my $otherbot = $self->get_bot($botname);
		if ($otherbot->battlecube) {
			$otherbot->privmsg( $otherbot->battlecube => "[battlecube] ".$rss );
		}
		if ($otherbot->roc) {
			$otherbot->privmsg( $otherbot->roc => "[battlecube] ".$rss );
		}
	}
}

sub join {
	my ( $self, $bot, $nickstr, $chan ) = @_;

	my ($nick) = split /!/, $nickstr;
	return if $nick =~ /^CSN/;

	for my $botname ($self->all_bots) {
		next if $botname eq $bot->name;
		my $otherbot = $self->get_bot($botname);
		if ($chan eq $bot->cubestats and $otherbot->cubestats) {
			$otherbot->privmsg( $otherbot->cubestats => $nickstr." joined [".$bot->name."]" );
		} elsif ($chan eq $bot->roc and $otherbot->roc) {
			$otherbot->privmsg( $otherbot->roc => $nickstr." joined [".$bot->name."]" );
		} elsif ($chan eq $bot->battlecube and $otherbot->battlecube) {
			$otherbot->privmsg( $otherbot->battlecube => $nickstr." joined [".$bot->name."]" );
		}
	}

}

sub part {
	my ( $self, $bot, $nick, $chan, $text ) = @_;
	return if $nick =~ /^CSN/;

	for my $botname ($self->all_bots) {
		next if $botname eq $bot->name;
		my $otherbot = $self->get_bot($botname);
		if ($chan eq $bot->cubestats and $otherbot->cubestats) {
			$otherbot->privmsg( $otherbot->cubestats => $nick." left (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		} elsif ($chan eq $bot->roc and $otherbot->roc) {
			$otherbot->privmsg( $otherbot->roc => $nick." left (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		} elsif ($chan eq $bot->battlecube and $otherbot->battlecube) {
			$otherbot->privmsg( $otherbot->battlecube => $nick." left (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		}
	}

}

sub kick {
	my ( $self, $bot, $kicker, $chan, $nick, $text ) = @_;

	for my $botname ($self->all_bots) {
		next if $botname eq $bot->name;
		my $otherbot = $self->get_bot($botname);
		if ($chan eq $bot->cubestats and $otherbot->cubestats) {
			$otherbot->privmsg( $otherbot->cubestats => $kicker." kicked ".$nick." (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		} elsif ($chan eq $bot->roc and $otherbot->roc) {
			$otherbot->privmsg( $otherbot->roc => $kicker." kicked ".$nick." (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		} elsif ($chan eq $bot->battlecube and $otherbot->battlecube) {
			$otherbot->privmsg( $otherbot->battlecube => $kicker." kicked ".$nick." (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		}
	}

}

sub quit {
	my ( $self, $bot, $nick, $text ) = @_;
	return if $nick =~ /^CSN/;

	for my $botname ($self->all_bots) {
		if ($botname ne $bot->name) {
			my $destbot = $self->get_bot($botname);
			$destbot->privmsg( '#cubestats' => $nick." quit (".(defined $text ? $text : "" ).") [".$bot->name."]" );
		}
	}

}

sub nick {
	my ( $self, $bot, $nick, $newnick ) = @_;
	return if $nick =~ /^CSN/;

	for my $botname ($self->all_bots) {
		if ($botname ne $bot->name) {
			my $destbot = $self->get_bot($botname);
			$destbot->privmsg( '#cubestats' => $nick." changed his nick to ".$newnick." [".$bot->name."]" );
		}
	}
}

sub action {
	my ( $self, $bot, $nick, $chans, $text ) = @_;
	return if $nick =~ /^CSN/;

	for my $chan (@{$chans}) {
		for my $botname ($self->all_bots) {
			next if $botname eq $bot->name;
			my $otherbot = $self->get_bot($botname);
			if ($chan eq $bot->cubestats and $otherbot->cubestats) {
				$otherbot->privmsg( $otherbot->cubestats => "* ".$nick." ".$text );
			} elsif ($chan eq $bot->roc and $otherbot->roc) {
				$otherbot->privmsg( $otherbot->roc => "* ".$nick." ".$text );
			} elsif ($chan eq $bot->battlecube and $otherbot->battlecube) {
				$otherbot->privmsg( $otherbot->battlecube => "* ".$nick." ".$text );
			}
		}
	}

}

# from Moose::Manual::BestPractices
no Moose;
__PACKAGE__->meta->make_immutable;

1;
