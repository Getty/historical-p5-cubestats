package CubeStats::Web::MasterController;
our $VERSION = '0.1';

use CubeStats;

with qw(
	CubeStats::Role::Web
	CubeStats::Role::Database
);

use Socket;

sub host2ip {
	my $host = shift;
	my $packed_addr = gethostbyname( $host );
	return unless $packed_addr;
	return inet_ntoa( $packed_addr );
}

sub BUILD {
	my $self = shift;
	$self->session->expire('+6h');

	my $script = $ENV{SCRIPT_NAME};
	$script = '' if !$script;

	if ($script eq '/retrieve.do') {
		print $self->session->header();
		my @rankedservers = $self->db->select("
			SELECT Hostname, No FROM Server
				LEFT JOIN Host ON Server.Host_ID = Host.ID
				WHERE Server.Ranked = 1
				ORDER BY No
		");

		for my $server (@rankedservers) {
			$server->{Port} = no2port($server->{No});
			$server->{Hostname} = 'cubestats.net' if (!$server->{Hostname});
			print "addserver ".host2ip($server->{Hostname})." ".$server->{Port}.";\n";
		}

		return;
	}

	$self->routeby($script);

}

sub routeby {
	my $self = shift;
	my $script = shift;
	my @script_parts = split('/',$script); shift @script_parts;
	my $page_name = shift @script_parts;

	my $page;

	if ($page_name) {
		$page_name =~ s!/!::!g;
		$page_name =~ s![^a-zA-Z0-9]!!g;
	}

	my $page_class;

	$page_name = ucfirst(lc($page_name));

	$page_class = 'CubeStats::Web::Page::'.$page_name;

	if ($page_name ne 'Indexhtml') {
		eval 'use '.$page_class.';'; die $@ if $@;
	}

	if ($page_class->can('exec')) {
		$page = new $page_class({ cgi => $self->cgi });
	} else {
		eval 'use CubeStats::Web::Page::Home;'; die $@ if $@;
		$page = new CubeStats::Web::Page::Home({ cgi => $self->cgi });
	}

	if ($self->cgi->param('lang')) {
		$page->lang($self->cgi->param('lang'));
	}
	$page->script(join('/',@script_parts));
	$page->exec;
	if ($page->reroute) {
		my $reroute = $page->reroute;
		$page->reroute("");
		return $self->routeby($reroute);
	}
	if ($page->can('header') && $page->header) {
		print $self->session->header(%{$page->header});
	} else {
		print $self->session->header();
	}
	print $page->view();
}

__PACKAGE__->meta->make_immutable;

1;
