package CubeStats::Web::Page::Game;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'game.tpl' }

with qw(
	CubeStats::Role::Database
);

sub exec {
	my $self = shift;

	my $game_id = $self->script;

	my @players = $self->db->select("
	SELECT Log_Nick.ID AS ID, Nick, Map, Gamemode, Filename,
		CAST( Kills + ( Gibs * 2 ) - ( Teamkills - Teamgibs ) AS SIGNED ) AS Frags,
		Killed + Gibbed AS Deaths,
		Teamkilled + Teamgibbed AS Teamdeaths
		FROM Log_Game_Nick
		INNER JOIN Log_Game ON Log_Game.ID = Log_Game_Nick.Log_Game_ID
		INNER JOIN Log_Nick ON Log_Nick.ID = Log_Game_Nick.Log_Nick_ID
		INNER JOIN Log ON Log.ID = Log_Game.Log_ID
		INNER JOIN Gamemode ON Gamemode.ID = Log_Game.Gamemode_ID
		INNER JOIN Map ON Map.ID = Log_Game.Map_ID
		WHERE Log_Game.ID = ?
		AND Log_Game.ID >731
		ORDER BY Frags DESC
	",$game_id);

	return if !@players;

	$self->assign('players',\@players);	
	$self->assign('game_id',$game_id);

}

__PACKAGE__->meta->make_immutable;

1;
