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

. ${ROOT}/scripts/deploy/dircheck.sh
. ${ROOT}/scripts/deploy/packages_serverconfig.sh
