#!/bin/sh

CUBESTATS_SERVERCONFIG=cubestats_serverconfig.tar.gz

echo Generating ${CUBESTATS_SERVERCONFIG}...
tar czf ${CUBESTATS_SERVERCONFIG} \
	assaultcube/packages/maps \
	assaultcube/config

echo Transfer ${CUBESTATS_SERVERCONFIG}...
${SCP} ${CUBESTATS_SERVERCONFIG} "${REMOTE}:${CUBESTATS_ROOT}"

echo Extracting ${CUBESTATS_SERVERCONFIG}...
${SSH} cd "${CUBESTATS_ROOT}" \; tar xzf ${CUBESTATS_SERVERCONFIG}
echo Deleting cubestats_core.tar.gz...
${SSH} cd "${CUBESTATS_ROOT}" \; rm ${CUBESTATS_SERVERCONFIG}
