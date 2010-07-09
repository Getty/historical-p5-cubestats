#!/bin/bash

set +e
# debug
set +x

ROOT=$(pwd)

. ${ROOT}/scripts/server/env.sh

. ${ROOT}/scripts/server/cache.sh
. ${ROOT}/scripts/server/cpan_config.sh
. ${ROOT}/scripts/server/locallib.sh
. ${ROOT}/scripts/server/cpan.sh
# . ${ROOT}/scripts/server/assaultcube_check.sh
. ${ROOT}/scripts/server/assaultcube.sh
. ${ROOT}/scripts/server/assaultcube_cubestats.sh
. ${ROOT}/scripts/server/perl.sh
. ${ROOT}/scripts/server/switch.sh
