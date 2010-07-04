package CubeStats::DB::Log::Game::Nick;

use CubeStats;
use CubeStats::DB;
use CubeStats::DB::Log::Game;
use MooseX::AttributeHelpers;
use Data::Dumper;

with 'MooseX::Getopt';

has nick_id => (
	isa => 'Int',
	is => 'ro',
	required => 1,
);

has game => (
	isa => 'CubeStats::DB::Log::Game',
	is => 'ro',
	required => 1,
);

has db => (	
	isa => 'CubeStats::DB',
	is => 'rw',
	default => sub { new CubeStats::DB },
);

has [qw(kills gibs teamkills teamgibs killed gibbed teamkilled teamgibbed flag_score flag_return)] => (
	isa => 'Int',
	is => 'rw',
	default => sub { 0 },
);

sub frag {
	my $self = shift;
	if (shift) {
		if (shift) {
			$self->{teamgibs}++;
		} else {
			$self->{teamkills}++;
		}
	} else {
		if (shift) {
			$self->{gibs}++;
		} else {
			$self->{kills}++;
		}
	}
}

sub victim {
	my $self = shift;
	if (shift) {
		if (shift) {
			$self->{teamgibbed}++;
		} else {
			$self->{teamkilled}++;
		}
	} else {
		if (shift) {
			$self->{gibbed}++;
		} else {
			$self->{killed}++;
		}
	}
}

sub BUILD {
	my $self = shift;
	$self->db($self->game->db);
}

sub save {
	my $self = shift;
	$self->db->insert("Log_Game_Nick",{
		Log_Game_ID => $self->game->id,
		Log_Nick_ID => $self->nick_id,
		Kills => $self->kills,
		Gibs => $self->gibs,
		Teamgibs => $self->teamgibs,
		Teamkills => $self->teamkills,
		Killed => $self->killed,
		Gibbed => $self->gibbed,
		Teamgibbed => $self->teamgibbed,
		Teamkilled => $self->teamkilled,
	},'DELAYED');
}

1;
