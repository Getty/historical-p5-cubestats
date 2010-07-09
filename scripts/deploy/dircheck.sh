#!/bin/sh
#
# Check for correct current directory
#
if [ ! -f scripts/deploy/dircheck.sh ]; then
    echo $0: Please execute in cubestats directory
    exit 1
fi
