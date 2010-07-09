#!/bin/sh
#
# Check for cache directory
#
if [ ! -d ${CUBESTATS_CACHE} ]; then
    mkdir ${CUBESTATS_CACHE}
fi
