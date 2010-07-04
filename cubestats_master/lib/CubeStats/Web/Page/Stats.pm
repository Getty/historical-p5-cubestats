package CubeStats::Web::Page::Stats;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'stats.tpl' }

with qw(
    CubeStats::Role::Database
);

sub exec {
	my $self = shift;

	$self->assign('mostkills50',$self->db->selectref_cached( 60 * 5, "
		SELECT Log_Nick.ID AS Nick_ID, Nick, SUM( Kills ) + SUM( Gibs ) AS Kills, SUM( Teamkills ) + SUM( Teamgibs ) AS Teamkills
			FROM `Log_Game_Nick`
			INNER JOIN Log_Nick ON Log_Game_Nick.Log_Nick_ID = Log_Nick.ID
			GROUP BY Nick
			ORDER BY Kills DESC
			LIMIT 0 , 50
	"));

	$self->assign('killsbymap',$self->db->selectref_cached( 60 * 5, "
		SELECT Map, SUM( Kills ) + SUM( Gibs ) AS AllKills
			FROM `Log_Game_Nick`
			INNER JOIN Log_Game ON Log_Game_Nick.Log_Game_ID = Log_Game.ID
			INNER JOIN Map ON Log_Game.Map_ID = Map.ID
			GROUP BY Map
			ORDER BY AllKills DESC
			LIMIT 0 , 50
	"));

	my @totals = $self->db->select_cached( 60 * 5, "
		SELECT SUM( Kills ) + SUM( Gibs ) AS Kills FROM `Log_Game_Nick`
	");

	for my $total (@totals) {
		$self->assign('KillsTotal',$total->{Kills});
	}
}

__PACKAGE__->meta->make_immutable;

1;
