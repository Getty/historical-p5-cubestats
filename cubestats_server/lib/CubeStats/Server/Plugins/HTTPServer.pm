# Declare our package
package CubeStats::Server::Plugins::HTTPServer;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use POE qw( Component::Server::SimpleHTTP Component::Server::SimpleContent );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has 'http' => (
	isa		=> 'Bool',
	is		=> 'rw',
	default		=> 0,
);

has 'swf' => (
	isa		=> 'Maybe[POE::Component::Server::SimpleContent]',
	is		=> 'rw',
	default		=> undef,
);

has 'maps' => (
	isa		=> 'Maybe[POE::Component::Server::SimpleContent]',
	is		=> 'rw',
	default		=> undef,
);

has server_port => ( isa => 'Int', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->ac_server->server_port() + 6 } );

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

event start_server => sub {
	my $self = shift;

	# create the SWF processor
	$self->swf( POE::Component::Server::SimpleContent->spawn(
		root_dir	=> $self->server->serverroot . '/config/EventMap/SWF',
		auto_index	=> 0,
		alias_path	=> '/EventMap/SWF/',
	) );

	# <CiD-> also, amke the map dir: "http://"+SERVER_IP+":"+SERVER_PORT+"/EventMap/maps/"+dataValues['mapname']
	# <ap0cal> don't forget ".jpg" at the end :)
	$self->maps( POE::Component::Server::SimpleContent->spawn(
		root_dir	=> $self->server->serverroot . '/config/EventMap/MiniMap',
		auto_index	=> 0,
		alias_path	=> '/EventMap/maps/',
	) );

	# okay, fire up SimpleHTTP!
	POE::Component::Server::SimpleHTTP->new(
		'ALIAS'         =>      'HTTPServer',
		'PORT'          =>      $self->server_port,
		'HOSTNAME'      =>      $self->server->clantag . ' - ' . $self->server->name,
		'HANDLERS'      =>      [
			{
				'DIR'		=> '^/EventMap/SWF/',
				'SESSION'	=> $self->swf->session_id,
				'EVENT'		=> 'request',
			},
			{
				'DIR'		=> '^/EventMap/maps/',
				'SESSION'	=> $self->maps->session_id,
				'EVENT'		=> 'request',
			},
			{
				'DIR'		=> '^/EventMap/?$',
				'SESSION'	=> $self->get_session_id,
				'EVENT'		=> 'http_EventMap',
			},
			{
				'DIR'		=> '.*',
				'SESSION'	=> $self->get_session_id,
				'EVENT'		=> 'http_Error',
			},
		],
	) or die 'Unable to create the HTTP Server';

	$self->server->info( "started the server on port: " . $self->server_port );

	# Server loaded ok
	$self->http( 1 );

	return;
};

event http_Error => sub {
	my( $self, $request, $response, $dir ) = @_;

	if ( defined $request ) {
		# return the basic error html!

		$response->code( 404 );
		$response->content( 'Unknown page' );
		$response->content_type( "text/html" );
	}

	# send the reply back!
	$poe_kernel->post( 'HTTPServer', 'DONE', $response );
	return;
};

event http_EventMap => sub {
	my( $self, $request, $response, $dir ) = @_;

	if ( defined $request ) {
		# return the basic html to load the swf!
		my $html = '<html><head><title>' . $self->server->name . '</title></head><body style="padding:0px;margin:0px"><div>';
		$html .= '<object width="512" height="512"><param name="movie" value="EventMap.swf"></param><embed src="http://' .
			$response->connection->local_ip() . ':' . $response->connection->local_port() .
			'/EventMap/SWF/EventMap.swf?SERVER_IP=' . $response->connection->local_ip() .
			'&SERVER_PORT=' . $self->server->xmlserver->server_port .
			'" width="512" height="512"></embed></object>';
		$html .= '</div></body></html>';

		$response->code( 200 );
		$response->content( $html );
		$response->content_type( "text/html" );
	}

	# send the reply back!
	$poe_kernel->post( 'HTTPServer', 'DONE', $response );
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

	if ( $self->http ) {
		$poe_kernel->post( 'HTTPServer', 'SHUTDOWN' );
		$self->http( 0 );
	}

	if ( defined $self->swf ) {
		$self->swf->shutdown;
		$self->swf( undef );
	}
	if ( defined $self->maps ) {
		$self->maps->shutdown;
		$self->maps( undef );
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
