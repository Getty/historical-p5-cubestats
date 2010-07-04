package CubeStats::Web::Page::About;

use CubeStats;
extends 'CubeStats::Web::Page';

use CubeStats::History;

sub content_template { 'about.tpl' }

sub exec {
	my $self = shift;

	my $history = new CubeStats::History({
		log_nick_ids => [ 1 ],
		
	});

	$self->assign('history',$history->assigns);

}

1;
