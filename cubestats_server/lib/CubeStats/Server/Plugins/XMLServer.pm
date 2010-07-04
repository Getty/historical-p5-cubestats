# Declare our package
package CubeStats::Server::Plugins::XMLServer;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Wheel::SocketFactory Wheel::ReadWrite Filter::Line );
use Socket qw( inet_ntoa sockaddr_in );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has 'rw' => (
	isa		=> 'HashRef',
	is		=> 'ro',
	default		=> sub { {} },
);

has 'sf' => (
	isa		=> 'Maybe[POE::Wheel::SocketFactory]',
	is		=> 'rw',
	default		=> undef,
);

has server_port => ( isa => 'Int', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->ac_server->server_port() + 7 } );

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
	$poe_kernel->yield( 'start_server' );

	return;
}

event start_server => sub {
	my $self = shift;

	# okay, create the SF wheel!
	$self->server->info( "started the server on port: " . $self->server_port );
	$self->sf( POE::Wheel::SocketFactory->new(
		BindPort	=> $self->server_port,
		SuccessEvent	=> 'sf_connect',
		FailureEvent	=> 'sf_failure',
		Reuse		=> 1,
	) );
	if ( ! defined $self->sf ) {
		$self->server->info( "unable to create SocketFactory wheel" );
		$poe_kernel->delay( 'start_server' => 60 );
	}

	return;
};

event sf_connect => sub {
	my( $self, $socket, $ip, $port, $wheel ) = @_;
	$ip = inet_ntoa( $ip );

	# TODO add ip filtering/blacklist/DDOS protection/etc
#	$self->server->debug( "got connection from $ip:$port" );

	# convert it to RW!
	my $rw = POE::Wheel::ReadWrite->new(
		Handle		=> $socket,
		InputEvent	=> 'rw_input',
		ErrorEvent	=> 'rw_failure',
		Filter		=> POE::Filter::Line->new( Literal => chr(0) ),
	);

	# store it!
	$self->rw->{ $rw->ID } = {
		ID	=> $rw->ID,
		RW	=> $rw,
		IP	=> $ip,
		PORT	=> $port,
		LOCALIP	=> inet_ntoa( ( sockaddr_in( getsockname( $socket ) ) )[1] ),
	};
	return;
};

event sf_failure => sub {
	my( $self, $operation, $errnum, $errstr, $wheel_id ) = @_;

	$self->server->info( "SocketFactory error($operation): $errnum $errstr" );
	$self->sf( undef );

	$poe_kernel->delay( 'start_server' => 60 );
	return;
};

event rw_input => sub {
	my( $self, $input, $id ) = @_;

#	$self->server->debug( "received input from RW($id): $input" );

	# process it!
	if ( $input eq '<EventMap/>' ) {
		# register this client!
		$self->rw->{ $id }->{EVENTMAP} = 1;

		# send the basic LOAD info
		$self->send_packet( $id, 'load', $self->server->ac_server->gamedata );
	} elsif ( $input eq '<policy-file-request/>' ) {
		my $policy_file = '<?xml version="1.0"?><!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd"><cross-domain-policy><site-control permitted-cross-domain-policies="master-only"/>';
		$policy_file .= '<allow-access-from domain="localhost" to-ports="' . $self->server_port . '"/>';
		$policy_file .= '<allow-access-from domain="' . $self->rw->{ $id }->{LOCALIP} . '" to-ports="' . $self->server_port . '"/>';
		$policy_file .= '</cross-domain-policy>';

#		$self->server->debug( "sending to RW($id): $policy_file" );
		$self->rw->{ $id }->{RW}->put( $policy_file );
	} else {
		# ignore invalid input
	}

	return;
};

event rw_failure => sub {
	my( $self, $operation, $errnum, $errstr, $id ) = @_;

#	$self->server->info( "ReadWrite($id) error($operation): $errnum $errstr" );

	delete $self->rw->{ $id } if exists $self->rw->{ $id };
	return;
};

sub send_packet {
	my( $self, $id, $type, $data ) = @_;

	if ( exists $self->rw->{ $id } and exists $self->rw->{ $id }->{EVENTMAP} ) {
		# build the xml
		my $xml;
		if ( ref $data ) {
			$xml = '<Event Type="' . $type . '" TimeStamp="' . time() . '"><Data';
			foreach my $k ( keys %$data ) {
				$xml .= " $k=\"" . xmlEncode( $data->{$k} ) . "\"";
			}
			$xml .= ' /></Event>';
		} else {
			$xml = $data;
		}

#		$self->server->debug( "sending to RW($id): $xml" );
		$self->rw->{ $id }->{RW}->put( $xml );
	}

	return;
};

sub eventmap {
	my( $self, $type, $data ) = @_;

	# build the XML once
	my $xml = '<Event Type="' . $type . '" TimeStamp="' . time() . '"><Data';
	foreach my $k ( keys %$data ) {
		$xml .= " $k=\"" . xmlEncode( $data->{$k} ) . "\"";
	}
	$xml .= ' /></Event>';

	# send it to all interested clients!
	foreach my $id ( keys %{ $self->rw } ) {
		$self->send_packet( $id, $type, $xml );
	}

	return;
}

{
	# global lookup hash
	my %ESCAPES = (
		'&'	=>	'&amp;',
		'<'	=>	'&lt;',
		'>'	=>	'&gt;',
		'"'	=>	'&quot;',
	);

	# Escapes XML text in a string
	sub xmlEncode {
		# Get the string
		my $string = shift;

		# Check for definedness
		if ( ! defined $string ) { return undef }

		# Do the actual conversion!
		$string =~ s/([&<>"])/$ESCAPES{ $1 }/ge;

		# Return the string
		return $string;
	}
}

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

	$self->sf( undef ) if defined $self->sf;

	foreach my $id ( keys %{ $self->rw } ) {
		if ( defined $self->rw->{$id}->{RW} ) {
			$self->rw->{$id}->{RW}->shutdown_input;
			$self->rw->{$id}->{RW}->shutdown_output;
		}
	}
	%{ $self->rw } = ();

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME
