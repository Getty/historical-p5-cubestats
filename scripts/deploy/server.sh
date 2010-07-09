#!/bin/bash
#
# Used to deploy the cubestats_server required equipment (fresh) to a remote host
#

# halt on errors
set +e
# debug
set +x

ROOT=$(pwd)

export CUBESTATS_DEPLOY="~/deploy_cubestats/"

. ${ROOT}/scripts/deploy/sshenv.sh

. ${ROOT}/scripts/deploy/dircheck.sh
. ${ROOT}/scripts/deploy/prepare.sh
. ${ROOT}/scripts/deploy/packages_core.sh
. ${ROOT}/scripts/deploy/install_server.sh
