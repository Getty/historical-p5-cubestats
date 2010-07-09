#!/bin/sh
# halt on errors
set +e
# debug
set +x

ROOT=$(pwd)

export CUBESTATS_ROOT="~/cubestats/"

. ${ROOT}/scripts/deploy/sshenv.sh

. ${ROOT}/scripts/deploy/dircheck.sh

if [ $# -lt 4 ]; then
    echo $0 username hostname port no
    exit 1
fi

NO=$4

${ROOT}/scripts/generate/starter.pl --no ${NO} >/tmp/csn.${NO}.sh
${SCP} /tmp/csn.${NO}.sh "${REMOTE}:${CUBESTATS_ROOT}/server_starter/csn.${NO}.sh"
${SSH} chmod 700 "${CUBESTATS_ROOT}/server_starter/csn.${NO}.sh"
