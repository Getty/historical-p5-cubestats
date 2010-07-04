package CubeStats::Web::Page::Nick;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'nick.tpl' }

with qw(
    CubeStats::Role::Database
);

my @statscfg = (
	{
		'name' => 'KillsGibs',
		'text' => 'Kills + Gibs = Totals',
		'sql' => 'CONCAT(SUM( Kills )," + ",SUM( Gibs )," = ",SUM( Gibs ) + SUM( Kills))',
	},
	{
		'name' => 'Frags',
		'text' => 'Frags as ( Kills + ( Gibs * 2 ) - ( Teamkills + Teamgibs ) )',
		'sql' => 'SUM( Kills ) + ( SUM( Gibs ) * 2 ) - ( SUM( Teamkills ) - SUM( Teamgibs ) )',
	},
	{
		'name' => 'Gibs',
		'text' => 'Gibs',
		'sql' => 'SUM( Gibs )',
	},
	{
		'name' => 'Teamkills',
		'text' => 'Teamkills + Teamgibs',
		'sql' => 'SUM( Teamkills ) + SUM( Teamgibs )',
	},
	{
		'name' => 'Killed',
		'text' => 'Killed + Gibbed (all Deaths, no Teamdeaths)',
		'sql' => 'SUM( Killed ) + SUM( Gibbed )',
	},
);

sub exec {
	my $self = shift;

	if ($self->script) {
		my @scriptparams = split('/',$self->script);
		my @given_nick_ids = split('\+',$scriptparams[0]);
		my( @nick_ids, $nick_ids_ph );
		for my $given_nick_id (@given_nick_ids) {
			my $nick_id = $given_nick_id+0;
			if ($nick_id) {
				push @nick_ids, $nick_id;
			}
		}
		$nick_ids_ph = ( '?, ' x scalar @nick_ids );
		$nick_ids_ph = substr( $nick_ids_ph, 0, length( $nick_ids_ph ) - 2 );
		my @nicks = $self->db->select_cached( 60 * 60 * 24, "SELECT * FROM Log_Nick WHERE ID IN ($nick_ids_ph)", @nick_ids );
		$self->assign('log_nicks',\@nicks);
		$self->assign('scriptparams',\@scriptparams);
		$self->assign('statscfg',\@statscfg);

		if ($scriptparams[1] eq 'History') {

			my $page = 1;
			$page = $scriptparams[2] if $scriptparams[2];
			my $limit = 20;
			my $offset = ( $page - 1 ) * $limit;

			my @historycount = $self->db->select_cached( 60 * 5, "
				SELECT COUNT(*) AS Count FROM Log_Game_Nick
				WHERE Log_Nick_ID IN ($nick_ids_ph)
					AND Log_Game_ID >731
			", @nick_ids );

			$self->assign('historycount',\@historycount);

			my $pagecount = int($historycount[0]->{Count}/$limit)+1;

			my @history = $self->db->select_cached( 60 * 5, "
			SELECT * FROM Log_Nick_History 
				WHERE Log_Nick_ID IN ($nick_ids_ph)
				LIMIT $offset,$limit;
			", @nick_ids );

			for my $game (@history) {
				if ($game->{Filename} =~ m/csn\.(\d+)\.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.log/i) {
					$game->{No} = $1;
					$game->{Year} = $2;
					$game->{Month} = $3;
					$game->{Day} = $4;
					$game->{Hour} = $5;
					$game->{Minute} = $6;
				}
				if ($game->{Filename} =~ m/csn\.(\d+)\.(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})_GMT.log/i) {
					$game->{No} = $1;
					$game->{Year} = $2;
					$game->{Month} = $3;
					$game->{Day} = $4;
					$game->{Hour} = $5;
					$game->{Minute} = $6;
					$game->{GMT} = 1;
				}
			}

			$self->assign('limit',$limit);
			$self->assign('offset',$offset);
			$self->assign('page',$page);
			$self->assign('pagecount',$pagecount);
			$self->assign('history',\@history);
			$self->assign('history_page',$page);

		} elsif ($scriptparams[1]) { ########################################################################

		my $stats;

		for my $statstype (@statscfg) {
			if ($statstype->{name} eq $scriptparams[1]) {
				$stats = $statstype;
				last;
			}
		}

		return if !$stats;

		$self->assign('stats',$stats);

		my $select = $stats->{sql};

		my @killsbymap_sql = $self->db->select_cached( 60, "
			SELECT Map, $select AS Kills
				FROM `Log_Game_Nick`
				INNER JOIN Log_Nick ON Log_Game_Nick.Log_Nick_ID = Log_Nick.ID
				INNER JOIN Log_Game ON Log_Game_Nick.Log_Game_ID = Log_Game.ID
				INNER JOIN Gamemode ON Log_Game.Gamemode_ID = Gamemode.ID
				INNER JOIN Map ON Log_Game.Map_ID = Map.ID
				WHERE Log_Nick.ID IN ($nick_ids_ph)
				GROUP BY Map
		", @nick_ids );

		my %killsbymap;
		for my $killsbymap_row (@killsbymap_sql) {
			$killsbymap{$killsbymap_row->{Map}} = $killsbymap_row->{Kills};
		}
		$self->assign('killsbymap',\%killsbymap);

		my @killsbymode_sql = $self->db->select_cached( 60, "
			SELECT Gamemode, $select AS Kills
				FROM `Log_Game_Nick`
				INNER JOIN Log_Nick ON Log_Game_Nick.Log_Nick_ID = Log_Nick.ID
				INNER JOIN Log_Game ON Log_Game_Nick.Log_Game_ID = Log_Game.ID
				INNER JOIN Gamemode ON Log_Game.Gamemode_ID = Gamemode.ID
				INNER JOIN Map ON Log_Game.Map_ID = Map.ID
				WHERE Log_Nick.ID IN ($nick_ids_ph)
				GROUP BY Gamemode
		", @nick_ids );

		my %killsbymode;
		for my $killsbymode_row (@killsbymode_sql) {
			$killsbymode{$killsbymode_row->{Gamemode}} = $killsbymode_row->{Kills};
		}
		$self->assign('killsbymode',\%killsbymode);

		my @killsbymapmode_sql = $self->db->select_cached( 60, "
			SELECT Gamemode, Map, $select AS Kills
				FROM `Log_Game_Nick`
				INNER JOIN Log_Nick ON Log_Game_Nick.Log_Nick_ID = Log_Nick.ID
				INNER JOIN Log_Game ON Log_Game_Nick.Log_Game_ID = Log_Game.ID
				INNER JOIN Gamemode ON Log_Game.Gamemode_ID = Gamemode.ID
				INNER JOIN Map ON Log_Game.Map_ID = Map.ID
				WHERE Log_Nick.ID IN ($nick_ids_ph)
				GROUP BY Gamemode, Map
				ORDER BY Kills DESC
		", @nick_ids );

		my %killsbymapmode;
		for my $map (keys %killsbymap) {
			for my $mode (keys %killsbymode) {
				$killsbymapmode{$map}->{$mode} = '';
				for my $kmm (@killsbymapmode_sql) {
					if ($kmm->{Gamemode} eq $mode and
					    $kmm->{Map} eq $map) {
						$killsbymapmode{$map}->{$mode} = $kmm->{Kills};
					}
				}
			}
		}
		$self->assign('killsbymapmode',\%killsbymapmode);

		my @killstotal_sql = $self->db->select_cached( 60, "
			SELECT $select AS Kills
				FROM `Log_Game_Nick`
				INNER JOIN Log_Nick ON Log_Game_Nick.Log_Nick_ID = Log_Nick.ID
				WHERE Log_Nick.ID IN ($nick_ids_ph)
		", @nick_ids );

		for my $killstotal (@killstotal_sql) {
			$self->assign('killstotal',$killstotal->{Kills});
		}

		} ##############################################################################

		return;
	}

	my $nicksearch = $self->cgi->param('nick');

	if ($nicksearch) {
		$self->assign('nicksearch',$nicksearch);

		my @results = $self->db->select_cached( 60 * 5, "SELECT * FROM Log_Nick WHERE Nick LIKE ? ORDER BY Nick",'%'.$nicksearch.'%');

		if (@results) {
			$self->assign('nick_results',\@results);
		} else {
			$self->assign('nick_notfound',1);
		}
	}

}

__PACKAGE__->meta->make_immutable;

1;
