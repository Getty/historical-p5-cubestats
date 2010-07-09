#!/bin/sh

cd ~/cubestats
. scripts/server/env.sh
touch ~/perl5/lib/perl5/XML/SAX/ParserDetails.ini
scripts/start_daemoncontroller.pl >~/cubestats/logs/daemoncontroller_error.log
