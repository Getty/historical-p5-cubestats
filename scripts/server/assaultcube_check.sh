#!/bin/sh

if ( ps ux | grep "bin/[a]c_server" ); then
	echo "====================================================================="
	echo $0: no ac_server is allowed to run
	echo "====================================================================="
	exit 1
fi
