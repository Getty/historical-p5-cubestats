#!/bin/sh

# does the PAR exist? if so, use that as the launcher instead

# launch the server!
perl -Iperl/lib perl/lib/CubeStats/Server.pm \
	--no 99 \
	--name "Apocalypse House of Pain" \
	--clantag "\f7BS" \
	--ranked 0 \
	--irc 1 \
	--serverroot 'assaultcube' \
	--serverbin 'bin/ac_server_102_bs0.7' \
	--limit 23 \
	--maprot test \
	--password fuckitoff \
	--version 'bs0.7'
