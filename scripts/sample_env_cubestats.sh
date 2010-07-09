#
# inline script for setting up a cubestats environment
#

STAGE=prod

if [ "${CUBESTATS_STAGE}" == "${STAGE}" ]; then
	echo Stage already loaded, doing nothing
else
	if [ "${CUBESTATS_STAGE}" != "" ]; then
		echo Stage collide! hard exit in 10 sec.
		sleep 10
		exit 1
	fi
	export CUBESTATS_STAGE=${STAGE}
	export PS1="\[\033[1;33m\](CUBESTATS ${STAGE})\[\033[0m $PS1"
	export CUBESTATS_ROOT=$HOME/cubestats
	export CUBESTATS_DB='cubestats'
	export CUBESTATS_DB_HOST='127.0.0.1'
	export CUBESTATS_DB_USER='cubestats'
	export CUBESTATS_DB_PASS='cubestats'
	eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
fi
