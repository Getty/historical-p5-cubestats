package CubeStats::Role::Web::Template;

use CubeStats::Role;
use MooseX::AttributeHelpers;

with qw(
	CubeStats::Role::Web
);

has file => (
	isa => 'Str',
	is => 'rw',
);

has lang => (
	isa => 'Str',
	is => 'rw',
);

has assigns => (
	metaclass => 'Collection::Hash',
	is        => 'rw',
	isa       => 'HashRef[Any]',
	default   => sub { {} },
	provides  => {
		exists    => 'assign_exists',
		keys      => 'assign_keys',
		get       => 'get_assign',
		set       => 'assign',
	},
);

sub BUILD {
	my $self = shift;
	if ($self->cgi->current_assigns) {
		$self->assigns($self->cgi->current_assigns);
	}
}

sub view {
	my $self = shift;
	my $output = '';
	if ($self->file) {
		my $session = $self->session->dataref;
		$self->assign('session',$session);
		if ($session->{user}) {
			$self->assign('user',$session->{user});
		}
		if ($self->lang) {
			$self->assign('lang',$self->lang);
		}
		$self->tt->process($self->file,$self->assigns,\$output) || die $self->tt->error(), "\n";
	}
	return $output;
}

1;
