package CubeStats::Server::Log::Dispatcher;

use CubeStats;
use CubeStats::Server::Log;
use CubeStats::AC::Log::Line;

with 'MooseX::LogDispatch::Levels';

has no => (
    isa => 'Int',
    is => 'ro',
    required => 1,
);

has log => (
	isa => 'Maybe[CubeStats::Server::Log]',
	is => 'rw',
);

has archive_log => (
	isa => 'Maybe[CubeStats::Server::Log]',
	is => 'rw',
);

has log_path => ( isa => 'Str', is => 'ro', required => 1, );
has log_archive_path => ( isa => 'Str', is => 'ro', required => 1, );
has log_finished_path => ( isa => 'Str', is => 'ro', required => 1, );

has have_game => ( isa => 'Bool', is => 'rw', default => sub { 0 } );
has finished_game => ( isa => 'Bool', is => 'rw', default => sub { 0 } );

sub new_line {
	my ( $self, $line ) = @_;
	if (!$line && $self->finished_game) {
		$self->restartlog;
	}
	return if (!$line);
	if (!$self->log) {
		$self->restartlog;
	}
	my $hash = CubeStats::AC::Log::Line->new({ text => $line })->hash();
	my $event = $hash->{event};
	if ($event eq 'GameStart') {
		if ($self->have_game) {
			$self->restartlog;
		}
		$self->have_game(1);
	} elsif ($event eq 'GameStatus') {
		$self->have_game(1);
		if ($hash->{finished}) {
			$self->finished_game(1);
		}
	}
	$self->write($line);
	if ($event eq 'Status') {
		if ($hash->{clientcount} eq '0' && $self->have_game) {
			$self->restartlog;
		}
	}
}

sub write {
	my $self = shift;
	my $line = shift;
	$self->log->write($line);
	$self->archive_log->write($line);
}

sub restartlog {
	my $self = shift;
	if ($self->log) {
		$self->log->mv($self->log_finished_path);
	}
	$self->log(CubeStats::Server::Log->new({
		path => $self->log_path,
		no => $self->no,
	}));
	$self->archive_log(CubeStats::Server::Log->new({
		path => $self->log_archive_path,
		no => $self->no,
	}));
	$self->have_game(0);
	$self->finished_game(0);
}

1;
