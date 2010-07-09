#!/bin/sh

if [ $# -lt 3 ]; then
    echo $0 username hostname port
    exit 1
fi

export USERNAME=$1
export HOSTNAME=$2
export PORT=$3

export REMOTE="$1@$2"
export SSH="ssh -o ConnectTimeout=10 -p $3 $REMOTE "
export SCP="scp -o ConnectTimeout=10 -P $3 "

if ${SSH} true
then
    echo Successful connected to $1@$2...
else
    echo $0: Cant connect to $1@$2 on Port $3...
    exit 1
fi
