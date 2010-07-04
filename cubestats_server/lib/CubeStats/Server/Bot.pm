package CubeStats::Server::Bot;
our $VERSION = '0.1';

use Moses;
use POE::Component::IRC::Plugin::AutoJoin;

use List::Compare::Functional qw( get_intersection );

sub default_channels { return ['#cubestats.allserver',$_[0]->ownchannel,@{$_[0]->ownchannel_says}] };
sub default_owner { 'Getty!torsten@metaluna4.de' };
sub default_flood { 1 };

has ownchannel => ( isa => 'Str', is => 'ro', required => 1, );
has ownchannel_says => ( isa => 'ArrayRef', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return [ $self->ownchannel . '.says', '#cubestats.allserver.says' ];
	} );
has csn => ( isa => 'Maybe[CubeStats::Server]', is => 'rw', weaken => 1,
	default => undef );

sub tell {
	my $self = shift;
	my $text = shift;
	for ( $self->_channels ) {
		next if $_ =~ /\.says$/;
		$self->privmsg( $_ => $text );
	}
}

sub send_says {
	my( $self, $text ) = @_;

	# send it off!
	foreach my $chan ( @{ $self->ownchannel_says } ) {
		$self->privmsg( $chan, $text );
	}
}

## shut up the IRC numeric messages!
#event '_default' => sub {
#	return;
#};

event 'irc_msg' => sub {
	my( $self, $nickstr, $text ) = @_[ OBJECT, ARG0, ARG2 ];
	my $nick = (split( /!/, $nickstr ) )[0];

	# TODO copy command concept from API_Console

	return;
};

event 'irc_public' => sub {
	my( $self, $nickstr, $chan, $text ) = @_[ OBJECT, ARG0 .. ARG2 ];
	my $nick = (split( /!/, $nickstr ) )[0];
	return if $nick =~ /^CSN/;

	# for says
	if ( scalar get_intersection( [ $chan, $self->ownchannel_says ] ) ) {
		# TODO do irc -> AC color conversions

		# send it off to ac_server!
		if ( ! grep { $_ eq '#cubestats.allserver.says' } @$chan ) {
			$self->csn->ac_server->put( "SERVERMSG <$nick> \f0$text" );
			$self->csn->info( "$nickstr said from IRC: '$text'" );
		}
	}

	return;
};

event irc_nick => sub {
	my( $self, $nickstr, $newnick, $chan ) = @_[ OBJECT, ARG0 .. ARG2 ];
	my $nick = (split( /!/, $nickstr ) )[0];
	return if $nick =~ /^CSN/;

	# for says
	if ( scalar get_intersection( [ $chan, $self->ownchannel_says ] ) ) {
		$self->csn->ac_server->put( "SERVERMSG IRC client <$nick> changed nick to $newnick" );
	}

	return;
};

event irc_join => sub {
	my( $self, $nickstr, $channel ) = @_[ OBJECT, ARG0, ARG1 ];
	my $nick = (split( /!/, $nickstr ) )[0];
	return if $nick =~ /^CSN/;

	# for says
	if ( grep { $_ eq $channel } @{ $self->ownchannel_says } ) {
		# is this the first channel?
		my $common = 0;
		foreach my $s ( @{ $self->ownchannel_says } ) {
			if ( $self->irc->is_channel_member( $s, $nick ) ) {
				$common++;
			}
		}
		if ( $common == 1 ) {
			$self->csn->ac_server->put( "SERVERMSG IRC client <$nick> connected" );
		}
	}

	return;
};

event irc_kick => sub {
	my( $self, $kickstr, $channel, $kicked, $reason ) = @_[ OBJECT, ARG0 .. ARG3 ];
	my $kicknick = (split( /!/, $kickstr ) )[0];
	return if $kicknick =~ /^CSN/;

	# for says
	if ( grep { $_ eq $channel } @{ $self->ownchannel_says } ) {
		$reason = 'none' if ! defined $reason;
		if ( $channel !~ /^\#cubestats\.allserver\.says/ ) {
			$self->csn->ac_server->put( "SERVERMSG IRC client <$kicked> was kicked ( $reason )" );
		}
	}

	return;
};

event irc_part => sub {
	my( $self, $nickstr, $channel, $reason ) = @_[ OBJECT, ARG0 .. ARG2 ];
	my $nick = (split( /!/, $nickstr ) )[0];
	return if $nick =~ /^CSN/;

	# for says
	if ( grep { $_ eq $channel } @{ $self->ownchannel_says } ) {
		$reason = 'none' if ! defined $reason;
		if ( $channel =~ /\.says$/i ) {
			# is this the last channel?
			my $common = 0;
			foreach my $s ( @{ $self->ownchannel_says } ) {
				if ( $self->irc->is_channel_member( $s, $nick ) ) {
					$common++;
				}
			}
			if ( $common == 0 ) {
				$self->csn->ac_server->put( "SERVERMSG IRC client <$nick> left ( $reason )" );
			}
		}
	}

	return;
};

event irc_quit => sub {
	my( $self, $nickstr, $reason, $chan ) = @_[ OBJECT, ARG0 .. ARG2 ];
	my $nick = (split( /!/, $nickstr ) )[0];
	return if $nick =~ /^CSN/;

	# for says
	if ( scalar get_intersection( [ $chan, $self->ownchannel_says ] ) ) {
		$reason = 'none' if ! defined $reason;
		$self->csn->ac_server->put( "SERVERMSG IRC client <$nick> quit ( $reason )" );
	}

	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = $_[ OBJECT ];

	$self->csn->info( "shutting down..." );
	return if defined $_[HEAP]->{shutdown};
	$_[HEAP]->{shutdown} = 1;

	# cleanup
	$poe_kernel->post( $self->irc_session_id, 'shutdown', 'shutdown' );
	$poe_kernel->alarm_remove_all;

	return;
};

sub STOPALL {
	my $self = shift;

	$self->csn->info( "in STOPALL" );

	return;
}

no Moses;
1;
__END__

