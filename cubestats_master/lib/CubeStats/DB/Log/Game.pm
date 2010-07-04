package CubeStats::DB::Log::Game;

use CubeStats;
use CubeStats::DB;
use CubeStats::DB::Log;
use CubeStats::DB::Log::Game::Nick;
use MooseX::AttributeHelpers;
use Data::Dumper;

with 'MooseX::Getopt';

has map => (
	isa => 'Str',
	is => 'rw',
);

has map_id => (
	isa => 'Int',
	is => 'rw',
);

has mode => (
	isa => 'Str',
	is => 'rw',
);

has mode_id => (
	isa => 'Int',
	is => 'rw',
);

has id => (
	isa => 'Int',
	is => 'rw',
);

has db => (
    isa => 'CubeStats::DB',
    is => 'rw',
    default => sub { new CubeStats::DB },
);

has log => (	
	isa => 'CubeStats::DB::Log',
	is => 'rw',
	required => 1,
);

has 'game_nicks' => (
    metaclass => 'Collection::Hash',
    is        => 'rw',
    isa       => 'HashRef[CubeStats::DB::Log::Game::Nick]',
    default   => sub { {} },
    provides  => {
        exists		=> 'nick_id_exists',
        keys		=> 'get_nick_ids',
        get			=> 'get_game_nick',
        set			=> 'set_game_nick',
    },
);

sub BUILD {
	my $self = shift;
	$self->db($self->log->db);
}

sub frag {
	my $self = shift;
	my $nick_id = shift;
	my $victim_id = shift;
	my $teamkill = shift;
	my $gib = shift;
	$self->check_nick_id($nick_id);
	$self->check_nick_id($victim_id);
	$self->get_game_nick($nick_id)->frag($teamkill,$gib);
	$self->get_game_nick($victim_id)->victim($teamkill,$gib);
}

sub check_nick_id {
	my $self = shift;
	my $nick_id = shift;
	if (!$self->nick_id_exists($nick_id)) {
		my $game_nick = new CubeStats::DB::Log::Game::Nick({
			game => $self,
			nick_id => $nick_id,
		});
		$self->set_game_nick($nick_id, $game_nick);
	}
}

sub save {
	my $self = shift;
	if (!$self->mode or !$self->map) {
		print $self->log->filename.": unknown map/mode cant save game\n";
		return;
	}
	my $map = $self->{map};
	my ($dbmap) = $self->db->select("SELECT * FROM Map WHERE Map = ?",$map);
	if ($dbmap) {
		$self->map_id($dbmap->{ID});
	} else {
		$self->map_id($self->db->insert("Map",{
			Map => $map,
		}));
	}
	my $mode = $self->{mode};
	my ($dbmode) = $self->db->select("SELECT * FROM Gamemode WHERE Gamemode = ?",$mode);
	if ($dbmode) {
		$self->mode_id($dbmode->{ID});
	} else {
		$self->mode_id($self->db->insert("Gamemode",{
			Gamemode => $mode,
		}));
	}
	$self->id($self->db->insert("Log_Game",{
		Log_ID => $self->log->id,
		Map_ID => $self->map_id,
		Gamemode_ID => $self->mode_id,
	}));
	for my $nick_id ($self->get_nick_ids) {
		$self->get_game_nick($nick_id)->save();
	}
}

sub finish {
	my $self = shift;
	$self->save();
}

1;
