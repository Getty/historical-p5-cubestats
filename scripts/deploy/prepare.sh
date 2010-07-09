#!/bin/sh

echo Remove old deployment...
${SSH} rm -rf "${CUBESTATS_DEPLOY}"
echo Prepare directory for new deployment...
${SSH} mkdir "${CUBESTATS_DEPLOY}"

