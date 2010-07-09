#!/usr/bin/perl

use CubeStats::Bot;
use CubeStats::Bot::Control;

my $control = new CubeStats::Bot::Control;

new CubeStats::Bot({
	_server => 'underworld.no.quakenet.org',
	_port => 6668,
	name => 'QuakeNet',
	control => $control,
	roc => '#roc',
	battlecube => '#battlecube',
});

new CubeStats::Bot({
	_server => 'ClanShells.DE.EU.GameSurge.net',
	_port => 6668,
	name => 'GameSurge',
	control => $control,
});

new CubeStats::Bot({
	_server => 'kornbluth.freenode.net',
	_port => 6667,
	name => 'FreeNode',
	control => $control,
});

new CubeStats::Bot({
	_server => 'irc.cubestats.net',
	_port => 6667,
	name => 'CubeStatsNet',
	control => $control,
	roc => '#roc',
	battlecube => '#battlecube',
	battlecube_rss => 1,
});

new CubeStats::Bot({
	_server => 'irc.perl.org',
	_port => 6667,
	name => 'Perl',
	control => $control,
});

POE::Kernel->run;
