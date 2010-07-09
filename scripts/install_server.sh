#!/bin/sh

set +e
# debug
set +x

CACHE="${HOME}/.cubestatsserver_cache"

ASSAULTCUBE_VERSION=1.0.2
ASSAULTCUBE_VERSION_INT=1002
ASSAULTCUBE_URL=http://heanet.dl.sourceforge.net/sourceforge/actiongame/AssaultCube_v${ASSAULTCUBE_VERSION}.tar.bz2
ASSAULTCUBE_DIR=AssaultCube_v${ASSAULTCUBE_VERSION}

CUBESTATS_ROOT=$HOME/cubestats

#
# Check for correct current directory
#
if [ ! -f scripts/install_server.sh ]; then
	echo $0: Please execute in cubestats directory
	exit 1
fi

#
# Check for cache directory
#
if [ ! -d ${CACHE} ]; then
	mkdir ${CACHE}
fi

#
# Checking for installed local-lib
#
if [ "${MODULEBUILDRC}" == "" ]; then
	echo Missing local-lib... Installing now...
	chmod 700 scripts/install_locallib.sh
	scripts/install_locallib.sh
	echo You need to relogin
	exit 1
fi

cpan YAML::Tiny
cpan inc::Module::Install

#
# Check for server source
#
if [ ! -f cubestats_assaultcube_source.tar.gz ]; then
	echo $0: Need cubestats_assaultcube_source.tar.gz
	exit 1
fi

#
# Download AssaultCube
#
if [ ! -f "${CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2" ]; then
	echo Downloading AssaultCube ${ASSAULTCUBE_VERSION}...
	wget -q -O ${CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2 ${ASSAULTCUBE_URL}
fi
echo Extracting AssaultCube ${ASSAULTCUBE_VERSION}...
tar xjf "${CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2"
mv ${ASSAULTCUBE_DIR} assaultcube

#
# Extract ac_server Source
#
echo Extracting ac_server Source...
cd assaultcube/source
mkdir src_cubestats
cd src_cubestats
tar xzf ../../../cubestats_assaultcube_source.tar.gz
cd ../../..
rm cubestats_assaultcube_source.tar.gz

#
# Compile ac_server Source
#
echo Compiling enet lib...
cd assaultcube/source/enet
./configure
make
cd ../../..
echo Compiling ac_server Source...
cd assaultcube/source/src_cubestats
make server SIGNAL=1
cd ../../..
mkdir bin
mv assaultcube/source/src_cubestats/ac_server bin/ac_server_${ASSAULTCUBE_VERSION_INT}_cubestats
rm -rf assaultcube/source/src_cubestats

#
# make the logdirs
#
echo Creating log directories...
mkdir assaultcube/logs
mkdir assaultcube/finished_logs
mkdir assaultcube/archive_logs

#
# Install adam-bot-framework
#
cd adam-bot-framework
perl ./Makefile.PL
make install
cd ..
rm -rf adam-bot-framework

#
# Install cubestats_common
#
cd cubestats_common
perl ./Makefile.PL
make install
cd ..
rm -rf cubestats_common

#
# Install cubestats_server
#
cd cubestats_server
perl ./Makefile.PL
make install
cd ..
rm -rf cubestats_server
