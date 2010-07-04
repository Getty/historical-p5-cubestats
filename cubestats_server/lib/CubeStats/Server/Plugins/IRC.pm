# Declare our package
package CubeStats::Server::Plugins::IRC;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has bot => (
	isa => 'Maybe[CubeStats::Server::Bot]',
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

sub STARTALL {
	my $self = shift;

	$self->server->info( "in STARTALL" );

	# okay, fire up the bot!
	if ( $self->server->irc ) {
		require CubeStats::Server::Bot;
		CubeStats::Server::Bot->import;
		$self->server->info('start bot');
		$self->bot( CubeStats::Server::Bot->new(
			_nickname	=> 'CSN-'.$self->server->no,
			_server		=> 'irc.cubestats.net',
			_port		=> 7666,
			ownchannel	=> '#cubestats.'.$self->server->no,
			csn		=> $self->server,
		) );
		$self->server->debug('started bot');
	}

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

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->server->info( "shutting down..." );

	# kill the bot
	if ( $self->server->irc ) {
		$self->bot->shutdown;
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
