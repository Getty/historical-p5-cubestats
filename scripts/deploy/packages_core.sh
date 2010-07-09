#!/bin/sh

AC_SERVER_VERSION=1030

CUBESTATS_SERVER_CORE=cubestats_server_core.tar.gz
CUBESTATS_ASSAULTCUBE_SOURCE=cubestats_assaultcube_source.tar.gz

echo Generating ${CUBESTATS_SERVER_CORE}...
tar czf ${CUBESTATS_SERVER_CORE} \
	scripts/server \
	scripts/launcher.pl \
	scripts/start_daemoncontroller.pl \
	scripts/start_cubestats_server.pl \
	config/CPAN_MyConfig.pm \
	moosex_daemoncontroller \
	assaultcube_perl \
	adam-bot-framework \
	cubestats_common \
	cubestats_server

echo Transfer server core package...
${SCP} ${CUBESTATS_SERVER_CORE} "${REMOTE}:${CUBESTATS_DEPLOY}"

echo Extracting cubestats_core.tar.gz...
${SSH} cd "${CUBESTATS_DEPLOY}" \; tar xzf ${CUBESTATS_SERVER_CORE}
echo Deleting cubestats_core.tar.gz...
${SSH} cd "${CUBESTATS_DEPLOY}" \; rm ${CUBESTATS_SERVER_CORE}

echo Generating cubestats_assaultcube_source.tar.gz...
tar czf ${CUBESTATS_ASSAULTCUBE_SOURCE} \
	-C source/ac_server_${AC_SERVER_VERSION} .

echo Transfer cubestats assaultcube package...
${SCP} ${CUBESTATS_ASSAULTCUBE_SOURCE} "${REMOTE}:${CUBESTATS_DEPLOY}"
