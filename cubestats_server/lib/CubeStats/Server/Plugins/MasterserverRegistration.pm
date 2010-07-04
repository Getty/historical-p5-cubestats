# Declare our package
package CubeStats::Server::Plugins::MasterserverRegistration;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use LWP::UserAgent;
use HTTP::Request;

use POE qw( Component::Client::HTTP );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
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

	# TODO make the agent string smarter ( autoconfiguring )
	POE::Component::Client::HTTP->spawn(
		'Agent'	=> "AssaultCube Server 1002",
		'Alias'	=> 'httpclient',
	);

	# okay, fire up the server!
	$poe_kernel->yield( 'register' );

	return;
}

event register => sub {
	my $self = shift;
	for my $masterserver (@{$self->server->masterserver}) {
		#$self->register_masterserver($masterserver);
		$self->register_masterserver_async($masterserver);
	}
	if ($self->server->official and $self->server->limit <= 20) {
		$self->register_masterserver_async('masterserver.cubers.net/cgi-bin/AssaultCube.pl/');
	}
	$poe_kernel->delay( 'register' => 60*45 );

	return;
};

sub register_masterserver_async {
	my $self = shift;
	my $masterserver = shift;

	# fire off the request!
	my $req = HTTP::Request->new(GET => 'http://'.$masterserver.'register.do?action=add&port='.$self->server->loaded_plugins->{ 'CubeStats::Server::Plugins::AssaultCube' }->server_port );
	$req->referer("assaultcubeserver");
	$req->protocol("HTTP/1.0");
	$poe_kernel->post( 'httpclient', 'request', 'register_done', $req, $masterserver );

	return;
}

event register_done => sub {
	my ($self, $request_packet, $response_packet) = @_;

	# HTTP::Request
	my $request_object  = $request_packet->[0];
	my $masterserver = $request_packet->[1];

	# HTTP::Response
	my $response_object = $response_packet->[0];

	# print a short status
	if ( $response_object->is_success ) {
		$self->server->info( "successfully registered with masterserver: $masterserver" );
	} else {
		# TODO should we print more info?
		$self->server->info( "failed to register with masterserver: $masterserver" );
	}

	return;
};

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

	# cleanup the HTTP client
	$poe_kernel->post( 'httpclient', 'shutdown' );

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME
