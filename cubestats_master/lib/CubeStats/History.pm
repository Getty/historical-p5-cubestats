package CubeStats::History;

use CubeStats;
use Cache::File;

use Data::Dumper;

BEGIN {
	use Storable qw( nfreeze thaw );
}

with qw(
	CubeStats::Role::Database
);

has limit => (
	is => 'ro',
	isa => 'Int',
	default => sub { 20 },
);

has log_nick_ids => (
	is => 'ro',
	isa => 'ArrayRef',
);

has page => (
	is => 'ro',
	isa => 'Int',
	default => sub { 1 },
);

my $cache;

sub BUILD {
	my $self = shift;
    $cache = Cache::File->new(
        cache_root      => '/tmp/' . ( defined $ENV{SERVER_NAME} ? $ENV{SERVER_NAME} : 'dev' ) . '-cache',
        size_limit      => 1024 * 1024 * 10,    # in bytes...
        removal_strategy    => 'Cache::RemovalStrategy::LRU',
		lock_level      => Cache::File::LOCK_LOCAL(),
	) if !$cache;
}

sub assigns {
	my $self = shift;

	my @entries;

	for my $log_nick_id (@{$self->log_nick_ids}) {

		my $cachestate_cacheparam = 'Log_Nick_History_'.$log_nick_id.'_State';
		my %cachestate;

		if (my $cachestate_cache = thaw( $cache->get( $cachestate_cacheparam ) ) ) {
			%cachestate = %{$cachestate_cache};
		}

		$cachestate{known_game_ids} = [] if !$cachestate{known_game_ids};
		$cachestate{log_game_nick_ids} = [] if !$cachestate{log_game_nick_ids};

		my $latest_game_id = $self->db->selectref_cached( 60, "
			SELECT Game_ID FROM Log_Nick_History
				WHERE Log_Nick_ID = ?
				ORDER BY Game_ID DESC
				LIMIT 0,1
		", $log_nick_id )->[0]->{Game_ID};

		next if !$latest_game_id;

		if ($cachestate{latest_game_id} < $latest_game_id) {
			my @new_histories = $self->fetch_history($log_nick_id, $cachestate{latest_game_id});
			for my $new_history (@new_histories) {
				push @{$cachestate{known_game_ids}}, $new_history->{Game_ID};
				push @{$cachestate{log_game_nick_ids}}, $new_history->{Log_Game_Nick_ID};
				$cachestate{latest_game_id} = $new_history->{latest_game_id};
			}
		}

		$cache->set( $cachestate_cacheparam, nfreeze( \%cachestate ) );

		push @entries, @{$cachestate{log_game_nick_ids}};

	}

	####### @entries = sort { $a <=> $b } @entries;

	my @history;

	for my $entry (@entries) {
		push @history, $self->get_history($entry);
	}

	return \@history;
}

sub fetch_history {
	my $self = shift;
	my $log_nick_id = shift;
	my $from_game_id = shift;
	$from_game_id = 0 if !$from_game_id;
	my @histories = $self->db->select_cached( 60 * 5, "
		SELECT * FROM Log_Nick_History
			WHERE Log_Nick_ID = ?
				AND Game_ID > ?
	", $log_nick_id, $from_game_id );

	my $i = 0;

	for my $game (@histories) {
		$i++;
		last if $i > 30;
		if ($game->{Filename} =~ m/csn\.(\d+)\.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.log/i) {
			$game->{No} = $1; $game->{Year} = $2; $game->{Month} = $3; $game->{Day} = $4; $game->{Hour} = $5; $game->{Minute} = $6;
		}
		if ($game->{Filename} =~ m/csn\.(\d+)\.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})_GMT.log/i) {
			$game->{No} = $1; $game->{Year} = $2; $game->{Month} = $3; $game->{Day} = $4; $game->{Hour} = $5; $game->{Minute} = $6; $game->{GMT} = 1;
		}
		$self->cache_history($game);
	}

	return @histories;
}

sub cache_history {
	my $self = shift;
	my %history = %{+shift};
	my $log_game_nick_id = $history{Log_Game_Nick_ID};
	my $cacheparam = 'Log_Nick_History_'.$log_game_nick_id;
	$cache->set( $cacheparam, nfreeze( \%history ) );
}

sub get_history {
	my $self = shift;
	my $log_game_nick_id = shift;
	my $cacheparam = 'Log_Nick_History_'.$log_game_nick_id;
	return thaw( $cache->get( $cacheparam ) );
}

1;
