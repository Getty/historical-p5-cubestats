package CubeStats::Server;

use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

our $VERSION = '0.5';

# TODO list
# add flag capturing hackers
#  - watch for 2 flags in 1s then KICKID

use CubeStats;
use Getopt::Long qw(:config pass_through);
use CubeStats::Server::Log::Dispatcher;

# load our "plugins"
use Module::Pluggable require => 1, search_path => [ __PACKAGE__ . '::Plugins' ];

with qw(
	MooseX::Getopt
	MooseX::LogDispatch::Levels
);

has loaded_plugins => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

# the BS clantag protection
has bs_clanlist => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );

# the nickban regexp
has nickban => ( isa => 'Maybe[Regexp]', is => 'rw',
	default => undef );

has connected_players => ( isa => 'HashRef', is => 'ro',
	default => sub { {} } );
has is_shutdown => ( isa => 'HashRef', is => 'ro',
	default => sub {
		return {
			shutdown	=> undef,
			text		=> undef,
		} } );

has no => ( isa => 'Int', is => 'ro', required => 1, );
has name => ( isa => 'Str',	is => 'ro', required => 1, );
has clantag => ( isa => 'Str', is => 'ro', required => 1, );
has ranked => ( isa => 'Bool', is => 'ro', required => 1, );
has official => ( isa => 'Bool', is => 'ro', required => 1, );
has irc => ( isa => 'Bool', is => 'ro', required => 1, );
has masterserver => ( isa => 'ArrayRef[Str]', is => 'rw',
	default => sub { [ 'masterserver.cubestats.net/' ] }, );
has motd => ( isa => 'Str', is => 'rw', );
has serverbin => ( isa => 'Str', is => 'ro',
	default => sub { '../bin/ac_server_cubestats' } );
has maprot => ( isa => 'Str', is => 'rw', required => 1, );
has serverroot => ( isa => 'Str', is => 'rw', required => 1,
	default => sub { $ENV{CUBESTATS_ROOT}.'/assaultcube' } );
has root => ( isa => 'Str', is => 'ro', required => 1,
	default => sub { $ENV{CUBESTATS_ROOT} } );
has serverflags => ( isa => 'Str', is => 'rw',
	default => sub { 'kbMFasRCDXP' } );
has limit => ( isa => 'Int', is => 'ro', required => 1, );
has log_path => ( isa => 'Str', is => 'rw',
	default => sub { 'logs' } );
has log_archive_path => ( isa => 'Str', is => 'rw',
	default => sub { 'archive_logs' } );
has log_finished_path => ( isa => 'Str', is => 'rw',
	default => sub { 'finished_logs' } );

has logscreen => ( isa => 'Bool', is => 'ro',
	default => sub { 0 } );

has voteyourmaprot => ( isa => 'Bool', is => 'ro',
	default => sub { 0 } );

has log_dispatcher => (
	isa => 'CubeStats::Server::Log::Dispatcher',
	is => 'rw',
);

has log_dispatch_conf => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	required => 1,
	default => sub {
		my $self = shift;
		my $format = '[%d %P:%L - %p] %m%n';
		return $self->logscreen ?
			{
				class		=> 'Log::Dispatch::Screen',
				min_level	=> 'debug',
				stderr		=> 1,
				format		=> $format,
			} : {
				class		=> 'Log::Dispatch::File',
				min_level	=> 'info',
				filename	=> $self->root.'/logs/csn_server_'.$self->no.'.log',
				mode		=> 'append',
				format		=> $format,
			};
    },
);

sub ac_server {
	my $self = shift;

	return $self->loaded_plugins->{ __PACKAGE__ . '::Plugins::AssaultCube' };
}

sub irc_bot {
	my $self = shift;

	return $self->loaded_plugins->{ __PACKAGE__ . '::Plugins::IRC' }->bot;
}

sub serverquery {
	my $self = shift;

	return $self->loaded_plugins->{ __PACKAGE__ . '::Plugins::ServerQuery' };
}

sub xmlserver {
	my $self = shift;

	return $self->loaded_plugins->{ __PACKAGE__ . '::Plugins::XMLServer' };
}

sub api_console {
	my $self = shift;

	return $self->loaded_plugins->{ __PACKAGE__ . '::Plugins::API_Console' };
}

event _stop => sub {
	return;
};

event _child => sub {
	return;
};

sub STARTALL {
	my $self = shift;

	# fix serverroot given by MooseX::DaemonController
	my $serverroot = $self->serverroot;
	my $home = $ENV{'HOME'};
	$serverroot =~ s!\~!$home!g;
	$self->serverroot($serverroot);

	$self->info('create log dispatcher');
	$self->log_dispatcher(CubeStats::Server::Log::Dispatcher->new({
		log_path => $self->serverroot.'/'.$self->log_path,
		log_finished_path => $self->serverroot.'/'.$self->log_finished_path,
		log_archive_path => $self->serverroot.'/'.$self->log_archive_path,
		no => $self->no,
	}));

	# loop through our plugins
	foreach my $p ( __PACKAGE__->plugins() ) {	## no critic ( RequireExplicitInclusion )
		# create the object, and store it
		$self->loaded_plugins->{ $p } = $p->new( $self );
		$self->info( "loaded plugin $p" );
	}

	$poe_kernel->sig( 'INT', 'got_int' );
	$poe_kernel->sig( 'HUP', 'got_int' );
	$poe_kernel->sig( 'QUIT', 'got_int' );
}

event got_int => sub {
	my $self = shift;
	$self->debug('got sigINT');
	$poe_kernel->sig_handled;
	$poe_kernel->yield( 'SHUTDOWN' );
	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event SHUTDOWN => sub {
	my $self = shift;

	$self->info( "shutting down..." );

	# kill our plugins
	foreach my $plugin ( values %{ $self->loaded_plugins } ) {
		$plugin->shutdown;
	}
	%{ $self->loaded_plugins } = ();

	$poe_kernel->alarm_remove_all();
	return;
};

sub STOPALL {
	my $self = shift;

	$self->info( "in STOPALL" );

	return;
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
    POE::Kernel->run;
}

__PACKAGE__->run unless caller;

1;
