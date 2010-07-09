#!/bin/sh

echo Installing CubeStats Server...
${SSH} cd "${CUBESTATS_DEPLOY}" \; chmod 700 ./scripts/server/install.sh \; ./scripts/server/install.sh
