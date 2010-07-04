package CubeStats::Web::CGI;

use CubeStats;

use CGI::State;
use CubeStats::Web::Session;
use CubeStats::Template;

has 'cgi' => (
	is => 'ro',
	required => 1,
	isa => 'CGI::Fast',
);

sub param {
	my $self = shift;
	return $self->cgi->param(@_);
}

has 'current_assigns' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub {{}},
);

has session => (
	isa => 'CubeStats::Web::Session',
	is => 'rw',
);

has state => (
	isa => 'HashRef',
	is => 'rw',
);

has tt => (
	isa => 'CubeStats::Template',
	is => 'rw',
);

sub init {
	my $self = shift;
	if (!$self->session) {
		my $_session = new CubeStats::Web::Session($self->cgi);
		$self->session($_session);
	}
	if ($self->param('logout')) {
		$self->session->clear('user');
	}
	if (!$self->tt) {
		my $templatedir = $ENV{'CUBESTATS_ROOT'}.'/templates';
		$templatedir = '/home/cubestats/svn.cubestats.net/trunk/templates' if $ENV{'SERVER_NAME'} eq 'dev.cubestats.net';
		$templatedir = '/home/pascal/svn.cubestats.net/trunk/templates'
			if $ENV{'SERVER_NAME'} eq 'pascal.cubestats.net';
		my $_tt = CubeStats::Template->new({
			INCLUDE_PATH => $templatedir,
			INTERPOLATE  => 0,           
			PLUGIN_BASE => 'CubeStats::Template::Plugin',
			COMPILE_EXT => 'c',
			COMPILE_DIR => '/tmp/'.$ENV{SERVER_NAME}.'-cache',
		}) or die "$CubeStats::Template::ERROR\n";
		$self->tt($_tt);
	}
	my $_state = CGI::State->state($self->cgi);
	my $current_assigns = $self->current_assigns;
	$current_assigns->{'ENV'} = \%ENV;
	for my $key (keys %{$_state}) {
		if (!$current_assigns->{$key}) {
			$current_assigns->{$key} = $_state->{$key};
		}
	}
	$self->current_assigns($current_assigns);
	$self->state($_state);
}

1;
