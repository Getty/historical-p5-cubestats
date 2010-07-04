package CubeStats::Web;

use CubeStats;
use CGI::State;
use CubeStats::Web::Session;
use CubeStats::Web::CGI;
use CubeStats::Template;

has session => (
	isa => 'CubeStats::Web::Session',
	is => 'rw',
);

has state => (
	isa => 'HashRef',
	is => 'rw',
);

has cgi => (
#	isa => 'CubeStats::Web::CGI',
	isa => 'CGI::Fast',
	is => 'rw',
	required => 1,
);

has tt => (
	isa => 'CubeStats::Template',
	is => 'rw',
);

sub BUILD {
	my $self = shift;
	if (!$self->session) {
		my $_session = new CubeStats::Web::Session($self->cgi);
		$self->session($_session);
	}
	if ($self->cgi->param('logout')) {
		$self->session->clear('user');
	}
	if (!$self->tt) {
		my $templatedir = $ENV{'CUBESTATS_ROOT'}.'/templates';
		$templatedir = '/home/acube/svn.cubestats.net/trunk/templates' if $ENV{'SERVER_NAME'} eq 'dev.cubestats.net';
		my $_tt = CubeStats::Template->new({
			INCLUDE_PATH => $templatedir,
			INTERPOLATE  => 0,           
			PLUGIN_BASE => 'CubeStats::Template::Plugin',
			COMPILE_EXT => 'tplc',
			COMPILE_DIR => '/tmp',
		}) or die "$CubeStats::Template::ERROR\n";
		$self->tt($_tt);
	}
	if (!$self->state) {
		my $_state = CGI::State->state($self->cgi);
		my $current_assigns = $self->cgi->current_assigns;
		$current_assigns->{'ENV'} = \%ENV;
		for my $key (keys %{$_state}) {
			if (!$current_assigns->{$key}) {
				$current_assigns->{$key} = $_state->{$key};
			}
		}
		$self->cgi->current_assigns($current_assigns);
		$self->state($_state);
	}
}

__PACKAGE__->meta->make_immutable;

1;
