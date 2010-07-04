package MooseX::DaemonController::Daemon;

use Moose;

with qw(
	MooseX::Daemonize
);

has daemon => ( isa => 'Maybe[Object]', is => 'rw' );
has attributes => ( isa => 'HashRef', is => 'rw' );
has run => ( isa => 'Str', is => 'rw',
	default => sub { 'run' } );
has package => ( isa => 'Str', is => 'rw', required => 1 );

after start => sub {
	my $self = shift;
	return unless $self->is_daemon;
	my $package = $self->package;
	eval 'use '.$package.';'; die $@ if $@;
	$self->daemon(new $package($self->attributes));
	if ($self->run && $self->daemon->can($self->run)) {
		my $method = $self->run;
		$self->daemon->$method;
	}
};

no Moose;

1;
__END__

