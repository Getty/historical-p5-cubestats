#!/bin/sh
#
# Used to deploy the cubestats_server required equipment (fresh) to a remote host
#

# halt on errors
set +e
# debug
set +x

ROOT=$(pwd)

export CUBESTATS_ROOT="~/cubestats/"

. ${ROOT}/scripts/deploy/sshenv.sh

echo Prepare remote logs
${SSH} mv ${CUBESTATS_ROOT}/transferlogs ${CUBESTATS_ROOT}/transferlogs-$( date +%y%m%d%H%M%S )
${SSH} mkdir ${CUBESTATS_ROOT}/transferlogs
${SSH} mv ${CUBESTATS_ROOT}/assaultcube/finished_logs/\* ${CUBESTATS_ROOT}/transferlogs/
${SSH} cd "${CUBESTATS_ROOT}/transferlogs" \; tar cvzf ${CUBESTATS_ROOT}/transferlogs.tgz ./\*

echo Fetching Logfiles...
${SCP} "${REMOTE}:${CUBESTATS_ROOT}/transferlogs.tgz" ~/cubestats/assaultcube/finished_logs/

cd ~/cubestats/assaultcube/finished_logs/
tar xvzf transferlogs.tgz
rm transferlogs.tgz
